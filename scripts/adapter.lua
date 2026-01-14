local Engine = require 'scripts.engine'
local Queue  = require 'scripts.queue'

local Adapter = {}

---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local TILE_ENTITIES = {
    UNKNOWN  = 'minesweeper-unknown',
    FLAG     = 'minesweeper-flag',
    EMPTY    = 'minesweeper-tile-empty',
    TILE     = 'minesweeper-tile',
    EXPLODED = 'minesweeper-mine-explosion',
    MINE     = 'minesweeper-mine',

    NUMBERS = {
        [0] = 'minesweeper-tile-empty',
        [1] = 'minesweeper-1',
        [2] = 'minesweeper-2',
        [3] = 'minesweeper-3',
        [4] = 'minesweeper-4',
        [5] = 'minesweeper-5',
        [6] = 'minesweeper-6',
        [7] = 'minesweeper-7',
        [8] = 'minesweeper-8',
    }
}

-- ONE Minesweeper engine-tile = 2×2 Factorio world tiles
local TILE_SCALE = 2  

---------------------------------------------------------
-- STATE
---------------------------------------------------------

local processor_queue = Queue.new()

local function get_state()
    storage.adapter = storage.adapter or {
        debug_chunks = {},
        processor_queue = processor_queue
    }
    return storage.adapter
end

function Adapter.on_init()
    if Engine.on_init then Engine.on_init() end
    get_state()
end

function Adapter.on_load()
    if Engine.on_load then Engine.on_load() end
    processor_queue = storage.adapter.processor_queue
end

---------------------------------------------------------
-- COORD HELPERS
---------------------------------------------------------

--- ft -> et
local function factorio_to_engine_tile(pos)
    return math.floor(pos.x / TILE_SCALE),
           math.floor(pos.y / TILE_SCALE)
end

--- et -> ft
local function engine_to_factorio_tile(ex, ey)
    return {
        x = ex * TILE_SCALE + TILE_SCALE / 2,
        y = ey * TILE_SCALE + TILE_SCALE / 2
    }
end

---------------------------------------------------------
-- ENTITY HELPERS
---------------------------------------------------------

local function destroy_existing(surface, ex, ey)
    local area = {
        { ex * TILE_SCALE,              ey * TILE_SCALE },
        { ex * TILE_SCALE + TILE_SCALE, ey * TILE_SCALE + TILE_SCALE }
    }
    for _, e in ipairs(surface.find_entities_filtered{area = area, force = 'neutral'}) do
        e.destroy()
    end
end

local function place(surface, prototype, ex, ey)
    destroy_existing(surface, ex, ey)
    local fx, fy = ex * TILE_SCALE, ey * TILE_SCALE

    -- draw one entity centered on the MSW tile
    local pos = { x = fx + TILE_SCALE/2, y = fy + TILE_SCALE/2 }

    local ent = surface.create_entity{
        name = prototype,
        position = pos,
        force = 'neutral'
    }
    if ent then
        ent.destructible = false
        ent.minable = false
    end
end

---------------------------------------------------------
-- QUEUED TILE UPDATES
---------------------------------------------------------

local function on_nth_tick()
    local limit = 60
    while limit > 0 and processor_queue:size() > 0 do
        local t = processor_queue:pop()
        Adapter.update_tile_entity(t.surface, t.x, t.y)
        limit = limit - 1
    end
end

function Adapter.queue_update_tile_entity(surface, tx, ty)
    processor_queue:push{ surface = surface, x = tx, y = ty }
end

---------------------------------------------------------
-- TILE RENDER LOGIC
---------------------------------------------------------

function Adapter.update_tile_entity(surface, ex, ey)
    if Engine.is_archived(ex, ey) then
        destroy_existing(surface, ex, ey)
        return
    end

    local t = Engine.get_tile(ex, ey)
    if not t then return end

    if not t.revealed then
        if t.flagged then
            place(surface, TILE_ENTITIES.FLAG, ex, ey)
        else
            place(surface, TILE_ENTITIES.TILE, ex, ey)
        end
        return
    end

    if t.exploded then return place(surface, TILE_ENTITIES.EXPLODED, ex, ey) end
    if t.had_mine then return place(surface, TILE_ENTITIES.MINE, ex, ey) end

    local adj = t.adj or Engine.adjacent_mines(ex, ey)
    place(surface, TILE_ENTITIES.NUMBERS[adj], ex, ey)
end

---------------------------------------------------------
-- PLAYER INPUT
---------------------------------------------------------

function Adapter.reveal(surface, player_index, ex, ey)
    Engine.reveal(ex, ey, player_index)
    Adapter.update_tile_entity(surface, ex, ey)
end

function Adapter.flag(surface, player_index, ex, ey)
    Engine.flag(ex, ey, player_index)
    Adapter.update_tile_entity(surface, ex, ey)
end

function Adapter.chord(surface, player_index, ex, ey)
    local results = Engine.chord(ex, ey, player_index)
    if not results then return end
    for _, r in ipairs(results) do
        Adapter.update_tile_entity(surface, r.x, r.y)
    end
end

---------------------------------------------------------
-- AUTO REVEAL WHEN WALKING
---------------------------------------------------------

local function on_player_changed_position(event)
    local p = game.get_player(event.player_index)
    if not p or p.controller_type ~= defines.controllers.character then return end

    local ex, ey = factorio_to_engine_tile(p.position)
    local s = p.surface

    Engine.show_player_surroundings(ex, ey, p.index)

    Adapter.reveal(s, p.index, ex, ey)
    Adapter.chord(s, p.index, ex, ey)
end

---------------------------------------------------------
-- FLAG VIA STONE FURNACE
---------------------------------------------------------

local function on_built_entity(event)
    local e = event.entity
    if not e or not e.valid or e.name ~= 'stone-furnace' then return end

    local ex, ey = factorio_to_engine_tile(e.position)
    local s = e.surface
    local player_index = event.player_index

    e.destroy{ raise_destroy = false }
    Engine.flag(ex, ey, player_index)

    Adapter.queue_update_tile_entity(s, ex, ey)
    Adapter.chord(s, player_index, ex, ey)
end

---------------------------------------------------------
-- CHUNK GENERATED → RENDER ENGINE TILE GRID CORRECTLY
---------------------------------------------------------

local function on_chunk_generated(event)
    local surface = event.surface
    local state   = get_state()
    local debug   = settings.global["minesweeper-debug"].value

    -- Factorio chunk = 32×32 tiles
    -- MSW tile = 2×2 → chunk covers 16×16 MSW tiles
    local MSW_PER_CHUNK = 32 / TILE_SCALE  -- = 16

    -- MSW tile coordinate for top-left of this chunk
    local msw_cx = event.position.x * MSW_PER_CHUNK
    local msw_cy = event.position.y * MSW_PER_CHUNK

    -- Ensure integer values
    msw_cx = math.floor(msw_cx)
    msw_cy = math.floor(msw_cy)

    local ck = msw_cx .. "," .. msw_cy

    -- Tick 0 → immediate update (no queue yet)
    local updater = (game.tick == 0) and Adapter.update_tile_entity or Adapter.queue_update_tile_entity

    -- Debug mode: reveal entire chunk once
    if debug then
        state.debug_chunks[ck] = true

        for tx = msw_cx, msw_cx + MSW_PER_CHUNK - 1 do
            for ty = msw_cy, msw_cy + MSW_PER_CHUNK - 1 do
                Engine.reveal(tx, ty)
                updater(surface, tx, ty)
            end
        end

    else
        -- Normal mode: just render tiles
        for tx = msw_cx, msw_cx + MSW_PER_CHUNK - 1 do
            for ty = msw_cy, msw_cy + MSW_PER_CHUNK - 1 do
                updater(surface, tx, ty)
            end
        end
    end
end


---------------------------------------------------------
-- REGISTER EVENTS
---------------------------------------------------------

Adapter.events = {
    [defines.events.on_player_changed_position] = on_player_changed_position,
    [defines.events.on_built_entity]            = on_built_entity,
    [defines.events.on_chunk_generated]         = on_chunk_generated,
}

Adapter.on_nth_tick = {
    [2] = on_nth_tick,
}

return Adapter

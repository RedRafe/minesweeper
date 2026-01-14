-- adapter.lua
-- Full adapter between Factorio world & Minesweeper Engine

local Engine = require 'scripts.engine'

local Adapter = {}

---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

-- Entity prototypes for each tile state
local TILE_ENTITIES = {
    UNKNOWN  = 'minesweeper-unknown',
    FLAG     = 'minesweeper-flag',
    EMPTY    = 'minesweeper-tile-empty', -- revealed zero
    TILE     = 'minesweeper-tile',
    EXPLODED = 'minesweeper-exploded',
    MINE     = 'minesweeper-mine',
    NUMBERS = {
        [1] = 'minesweeper-1',
        [2] = 'minesweeper-2',
        [3] = 'minesweeper-3',
        [4] = 'minesweeper-4',
        [5] = 'minesweeper-5',
        [6] = 'minesweeper-6',
        [7] = 'minesweeper-7',
        [8] = 'minesweeper-8'
    }
}

-- 1 engine tile = 2×2 Factorio tiles
local TILE_SCALE = 2

---------------------------------------------------------
-- GLOBAL STATE MANAGEMENT
---------------------------------------------------------

local function get_game_state()
    storage.adapter = storage.adapter or {
        engine = nil,
        auto_chord = {},  -- per player toggle
        debug_chunks = {}, -- [chunk_key] = true
    }
    return storage.adapter
end

function Adapter.on_init()
    local g = get_game_state()
    local seed = game.surfaces.nauvis.map_gen_settings.seed
    g.engine = Engine.new(seed)
end

---------------------------------------------------------
-- COORDINATE CONVERSION
---------------------------------------------------------

local function world_to_tile(pos)
    return math.floor(pos.x / TILE_SCALE), math.floor(pos.y / TILE_SCALE)
end

local function tile_to_world(x, y)
    return { x = x * TILE_SCALE + 0.5, y = y * TILE_SCALE + 0.5 }
end

local function chunk_key(cx, cy)
    return cx .. ',' .. cy
end

---------------------------------------------------------
-- ENTITY PLACEMENT / UPDATES
---------------------------------------------------------

local function destroy_existing(surface, x, y)
    local area = {
        { x*TILE_SCALE, y*TILE_SCALE },
        { x*TILE_SCALE + TILE_SCALE, y*TILE_SCALE + TILE_SCALE }
    }
    for _, ent in ipairs(surface.find_entities_filtered{ area = area, force='neutral' }) do
        ent.destroy()
    end
end

local function place(surface, prototype, x, y)
    destroy_existing(surface, x, y)
    local pos = tile_to_world(x, y)
    local entity = surface.create_entity{
        name = prototype,
        position = pos,
        force = 'neutral',
        type = 'simple-entity'
    }

    if entity then
        entity.destructible = false
        entity.minable = false
    end
end

---------------------------------------------------------
-- SYNC TILE ENTITY WITH ENGINE STATE
---------------------------------------------------------

function Adapter.update_tile_entity(surface, engine, x, y)
    local key = x .. ',' .. y

    if not engine.revealed[key] then
        place(surface, TILE_ENTITIES.TILE, x, y)
        return
    end

    if engine.exploded[key] then
        place(surface, TILE_ENTITIES.EXPLODED, x, y)
        return
    end

    if Engine.has_mine(engine, x, y) then
        place(surface, TILE_ENTITIES.MINE, x, y)
        return
    end

    if engine.flagged[key] then
        place(surface, TILE_ENTITIES.FLAG, x, y)
        return
    end

    -- revealed
    local count = Engine.adjacent_mines(engine, x, y)

    if count == 0 then
        place(surface, TILE_ENTITIES.EMPTY, x, y)
    else
        place(surface, TILE_ENTITIES.NUMBERS[count], x, y)
    end
end

---------------------------------------------------------
-- REVEAL, FLAG, CHORD HANDLERS
---------------------------------------------------------

local function apply_results(surface, engine, result)
    if not result then return end

    if result.state == Engine.CellState.REVEALED then
        Adapter.update_tile_entity(surface, engine, result.x, result.y)
    elseif result.state == Engine.CellState.EXPLODED then
        Adapter.update_tile_entity(surface, engine, result.x, result.y)
    end
end

function Adapter.reveal(surface, player_index, x, y)
    local g = get_game_state()
    local engine = g.engine

    local r = Engine.reveal(engine, x, y, player_index)
    apply_results(surface, engine, r)
end

function Adapter.flag(surface, player_index, x, y)
    local g = get_game_state()
    local engine = g.engine

    Engine.toggle_flag(engine, x, y, player_index)
    Adapter.update_tile_entity(surface, engine, x, y)
end

function Adapter.chord(surface, player_index, x, y)
    local g = get_game_state()
    local engine = g.engine

    local r = Engine.chord(engine, x, y, player_index)
    if r then
        for _,entry in ipairs(r) do
            Adapter.update_tile_entity(surface, engine, entry.x, entry.y)
        end
    end
end

---------------------------------------------------------
-- AUTO-CHORDING WHEN WALKING
---------------------------------------------------------

local function on_player_changed_position(event)
    local g = get_game_state()
    local engine = g.engine
    local pindex = event.player_index
    if not g.auto_chord[pindex] then return end

    local player = game.get_player(pindex)
    if not player then return end
    local surface = player.surface

    local tx, ty = world_to_tile(player.position)

    local r = Engine.chord(engine, tx, ty, pindex)
    if r then
        for _,entry in ipairs(r) do
            Adapter.update_tile_entity(surface, engine, entry.x, entry.y)
        end
    end
end

---------------------------------------------------------
-- CLICK HANDLING
---------------------------------------------------------

local function on_built_entity(event)
    local entity = event.created_entity or event.entity
    if not entity or not entity.valid then return end

    if entity.name ~= 'stone-furnace' then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local tx, ty = world_to_tile(entity.position)
    local surface = entity.surface

    -- Clean up furnace
    entity.destroy{raise_destroy = false}

    -- Apply flag logic
    local g = get_game_state()
    local engine = g.engine

    -- toggle the flag
    Engine.toggle_flag(engine, tx, ty, event.player_index)

    -- update gfx tile
    Adapter.update_tile_entity(surface, engine, tx, ty)
end

---------------------------------------------------------
-- DEBUG: Auto-reveal chunks at generation time
---------------------------------------------------------

local function on_chunk_generated(event)
    local debug = settings.global['minesweeper-debug'].value
    local g = get_game_state()
    if not g.debug_chunks then return end

    -- chunk position in Factorio world
    local cx = event.position.x
    local cy = event.position.y

    -- convert to minesweeper coordinate chunk (scaled)
    -- 1 msw tile = 2 factorio tiles → chunk of 32 msw tiles = 64 factorio tiles
    local msw_cx = math.floor((cx * 32) / (32 * TILE_SCALE))
    local msw_cy = math.floor((cy * 32) / (32 * TILE_SCALE))
    local key = msw_cx .. ',' .. msw_cy
    local engine = g.engine
    local surface = event.surface

    if debug then
        if not g.debug_chunks[key] then
            g.debug_chunks[key] = true
        end
            -- reveal all tiles in the minesweeper chunk
        for tx = msw_cx * 32, msw_cx * 32 + 31 do
            for ty = msw_cy * 32, msw_cy * 32 + 31 do
                engine.revealed[tx .. ',' .. ty] = true
                Adapter.update_tile_entity(surface, engine, tx, ty)
            end
        end
    else
        for tx = msw_cx * 32, msw_cx * 32 + 31 do
            for ty = msw_cy * 32, msw_cy * 32 + 31 do
                Adapter.update_tile_entity(surface, engine, tx, ty)
            end
        end
    end
end

---------------------------------------------------------
-- EVENTS
---------------------------------------------------------

Adapter.events = {
    [defines.events.on_built_entity] = on_built_entity,
    [defines.events.on_player_changed_position] = on_player_changed_position,
    [defines.events.on_chunk_generated] = on_chunk_generated,
}

return Adapter

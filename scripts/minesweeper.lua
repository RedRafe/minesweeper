local Const = require 'scripts.constants'
local Queue = require 'scripts.queue'

local Msw = {}

---------------------------------------------------------
-- CONFIG / ENUMS
---------------------------------------------------------

local ADJ           = Const.ADJ
local FORCE_NAME    = Const.FORCE_NAME
local SURFACE_INDEX = Const.SURFACE_INDEX
local TILE_ENTITIES = Const.TILE_ENTITIES
local TILE_EXPLODED = Const.TILE_EXPLODED
local TILE_FLAGGED  = Const.TILE_FLAGGED
local TILE_HIDDEN   = Const.TILE_HIDDEN
local TILE_MINE     = Const.TILE_MINE
local TILE_SCALE    = Const.TILE_SCALE
local TOOL_NAME     = Const.TOOL_NAME

---------------------------------------------------------
-- STATE
---------------------------------------------------------

local UPDATE_RATE = 22 -- 5 chunks / second

--[[
    {
        id = <number>,
        queue = { {x,y}, ... },
        visited = {},
        player_index = <number>,
        surface = <LuaSurface>,
    }
]]
local flood_fill_queue = Queue.new()

--[[
    {
        surface = <LuaSurface>,
        x = <number>,
        y = <number>,
    }
]]
local entity_update_queue = Queue.new()

local tiles = {}           -- tiles['x_y'] = enum
local archived_chunks = {} -- archived chunks
local renders = {}
local this = { seed = 12345 }
local CHUNK = 32

---------------------------------------------------------
-- STORAGE
---------------------------------------------------------

function init_storage()
    storage.minesweeper = {
        this = this,
        tiles = tiles,
        archived_chunks = archived_chunks,
        global_stats = global_stats,
        player_stats = player_stats,
        renders = renders,
        flood_fill_queue = flood_fill_queue,
        entity_update_queue = entity_update_queue,
    }
end

function load_storage()
    local tbl = storage.minesweeper
    this = tbl.this
    tiles = tbl.tiles
    archived_chunks = tbl.archived_chunks
    global_stats = tbl.global_stats
    player_stats = tbl.player_stats
    renders = tbl.renders
    renders = tbl.renders
    flood_fill_queue = tbl.flood_fill_queue
    entity_update_queue = tbl.entity_update_queue
end

---------------------------------------------------------
-- UTILS
---------------------------------------------------------

local bit32_bxor = bit32.bxor
local math_abs   = math.abs
local math_floor = math.floor
local math_min   = math.min
local math_sqrt  = math.sqrt
local pairs      = pairs
local ipairs     = ipairs
local tonumber   = tonumber

local EXPLOSIONS = {
    'atomic-bomb-ground-zero-projectile',
    'atomic-bomb-wave',
    'atomic-bomb-wave-spawns-cluster-nuke-explosion',
    'atomic-bomb-wave-spawns-fire-smoke-explosion',
    'atomic-bomb-wave-spawns-nuclear-smoke',
    'atomic-bomb-wave-spawns-nuke-shockwave-explosion',
    'atomic-rocket'
}

local function tile_key(x, y) return x .. '_' .. y end
local function chunk_key(cx, cy) return cx .. ',' .. cy end
local function get_chunk_of(x, y) return math_floor(x / CHUNK), math_floor(y / CHUNK) end

local function factorio_to_engine_tile(pos)
    return math_floor(pos.x / TILE_SCALE), math_floor(pos.y / TILE_SCALE)
end

local function engine_to_factorio_tile(ex, ey)
    return { x = ex * TILE_SCALE + TILE_SCALE / 2, y = ey * TILE_SCALE + TILE_SCALE / 2 }
end

local function is_archived(x, y)
    local cx, cy = get_chunk_of(x, y)
    return archived_chunks[chunk_key(cx, cy)] == true
end

local function key_to_xy(k)
    local x, y = k:match('(%d+)_(%d+)')
    return tonumber(x), tonumber(y)
end

---------------------------------------------------------
-- TILE ENUM HELPERS
---------------------------------------------------------

local function get_tile_enum(x, y)
    if is_archived(x, y) then
        return TILE_HIDDEN
    end
    return tiles[tile_key(x, y)] or TILE_HIDDEN
end

local function set_tile_enum(x, y, val)
    if is_archived(x, y) then
        return
    end
    tiles[tile_key(x, y)] = val
end

local function has_mine(x, y)
    local val = get_tile_enum(x, y)
    if val == TILE_MINE or val == TILE_EXPLODED then
        return true
    end
    -- deterministic generation for hidden tiles
    if is_archived(x, y) then
        return false
    end
    local h = math_abs(bit32_bxor(bit32_bxor(x * 0x2D0F3E, y * 0x1F123B), this.seed))
    local d = math_min(35, 8 + math_sqrt(x * x + y * y) * 0.02)
    return h % 100 < d
end

local function is_flagged(x, y)
    return get_tile_enum(x, y) == TILE_FLAGGED
end

local function is_revealed(x, y)
    local val = get_tile_enum(x, y)
    return (val >= 0 and val <= 8) or val == TILE_MINE or val == TILE_EXPLODED
end

---------------------------------------------------------
-- EFFECTS
---------------------------------------------------------

local function explosion(surface, position)
	if surface.count_entities_filtered({ name = EXPLOSIONS, radius = 6, limit = 1 }) > 0 then return end
	surface.create_entity{
        name = 'atomic-rocket',
        position = { position.x + 1, position.y + 1 },
        target = { position.x + 1, position.y + 1 },
        speed = 1,
        force = FORCE_NAME,
    }
end

---------------------------------------------------------
-- ADJACENT MINES
---------------------------------------------------------

local function adjacent_mines(x, y)
    local val = get_tile_enum(x, y)
    if val >= 0 and val <= 8 then
        return val
    end
    local c = 0
    for _, off in ipairs(ADJ) do
        local nx, ny = x + off[1], y + off[2]
        if has_mine(nx, ny) then
            c = c + 1
        end
    end
    return c
end

---------------------------------------------------------
-- FLOOD-FILL
---------------------------------------------------------

local function flood_fill(x, y, surface, player_index)
    local revealed = {}
    local queue = {{x, y}}
    local visited = {}

    while #queue > 0 do
        local node = table.remove(queue, 1)
        local cx, cy = node[1], node[2]
        local k = tile_key(cx, cy)
        if visited[k] then goto continue end
        visited[k] = true

        if is_archived(cx, cy) then goto continue end
        if is_flagged(cx, cy) then goto continue end
        if has_mine(cx, cy) then goto continue end

        if not is_revealed(cx, cy) then
            local adj = adjacent_mines(cx, cy)
            set_tile_enum(cx, cy, adj)
            revealed[#revealed+1] = { x = cx, y = cy }
            Msw.queue_update_tile_entity(surface, cx, cy)
        end

        if adjacent_mines(cx, cy) == 0 then
            for _, off in ipairs(ADJ) do
                local nx, ny = cx + off[1], cy + off[2]
                local nk = tile_key(nx, ny)
                if not visited[nk] then queue[#queue+1] = {nx, ny} end
            end
        end

        ::continue::
    end

    return revealed
end

local function process_flood_fill_queue(limit)
    if flood_fill_queue:size() == 0 then
        return
    end

    -- Can only resolve 1 job per tick as they're player_index-based
    local job = flood_fill_queue:peek()

    local revealed = {}
    local queue = job.queue
    local visited = job.visited
    local surface = job.surface
    local player_index = job.player_index

    local count = 0

    -- Process up to N nodes this tick
    while #queue > 0 and count < limit do
        count = count + 1

        local node = table.remove(queue, 1)
        local cx, cy = node[1], node[2]
        local key = tile_key(cx, cy)

        if visited[key] then goto continue end
        visited[key] = true

        if is_archived(cx, cy) then goto continue end
        if is_flagged(cx, cy) then goto continue end
        if has_mine(cx, cy) then goto continue end

        if not is_revealed(cx, cy) then
            local adj = adjacent_mines(cx, cy)
            set_tile_enum(cx, cy, adj)
            revealed[#revealed+1] = { type = adj, position = engine_to_factorio_tile(cx, cy) }
            Msw.queue_update_tile_entity(surface, cx, cy)
        end

        if adjacent_mines(cx, cy) == 0 then
            for _, off in ipairs(ADJ) do
                local nx, ny = cx + off[1], cy + off[2]
                local nk = tile_key(nx, ny)
                if not visited[nk] then
                    queue[#queue+1] = {nx, ny}
                end
            end
        end

        ::continue::
    end

    -- Raise event for this batch of revealed tiles (if any)
    if #revealed > 0 then
        script.raise_event(defines.events.on_tile_revealed, {
            tick = game.tick,
            name = defines.events.on_tile_revealed,
            player_index = player_index,
            surface_index = surface.index,
            tiles = revealed,
        })
    end

    -- If finished, remove job
    if #queue == 0 then
        flood_fill_queue:pop()
    end
end

local function flood_fill_async(x, y, surface, player_index)
    flood_fill_queue:push {
        queue = { {x, y} },
        visited = {},
        player_index = player_index,
        surface = surface,
    }
end

---------------------------------------------------------
-- CUSTOM INPUT HANDLING
---------------------------------------------------------

local function validate_custom_input(event)
    local player = game.get_player(event.player_index)

    local cursor = player.cursor_stack
    if not (cursor and cursor.valid_for_read) then
        return
    end
    
    if cursor.name ~= TOOL_NAME then
        return
    end
    
    local selected = player.selected
    if not (selected and selected.valid) then
        return
    end

    local surface = selected.surface
    if not (surface and surface.index == SURFACE_INDEX) then
        return
    end

    local force = selected.force
    if not (force and force.name == FORCE_NAME) then
        return
    end

    return selected
end

---------------------------------------------------------
-- REVEAL
---------------------------------------------------------

function Msw.reveal(surface, ex, ey, player_index)
    if is_archived(ex, ey) then return {} end
    if is_flagged(ex, ey) or is_revealed(ex, ey) then return {} end

    local revealed_tiles = {}

    if has_mine(ex, ey) then
        set_tile_enum(ex, ey, TILE_EXPLODED)
        revealed_tiles[#revealed_tiles+1] = { x = ex, y = ey }
    else
        local adj = adjacent_mines(ex, ey)
        set_tile_enum(ex, ey, adj)
        revealed_tiles[#revealed_tiles+1] = { x = ex, y = ey }

        if adj == 0 then
            flood_fill_async(ex, ey, surface, player_index)
        end
    end

    Msw.update_tile_entity(surface, ex, ey)

    -- Broadcast event
    local tiles = {}
    for _, t in pairs(revealed_tiles) do
        tiles[#tiles + 1] = { position = engine_to_factorio_tile(t.x, t.y), type = get_tile_enum(t.x, t.y) }
    end

    script.raise_event(defines.events.on_tile_revealed, {
        tick = game.tick,
        name = defines.events.on_tile_revealed,
        player_index = player_index,
        surface_index = surface.index,
        tiles = tiles,
    })

    return revealed_tiles
end

---------------------------------------------------------
-- FLAG
---------------------------------------------------------

function Msw.flag(surface, ex, ey, player_index)
    if is_archived(ex, ey) then return end
    if is_revealed(ex, ey) then return end

    if get_tile_enum(ex, ey) == TILE_FLAGGED then
        set_tile_enum(ex, ey, TILE_HIDDEN)
    else
        set_tile_enum(ex, ey, TILE_FLAGGED)

        if has_mine(ex, ey) then
            -- do stuff???
        end
    end

    Msw.update_tile_entity(surface, ex, ey)

    -- Broadcast event
    script.raise_event(defines.events.on_tile_revealed, {
        tick = game.tick,
        name = defines.events.on_tile_revealed,
        player_index = player_index,
        surface_index = surface.index,
        tiles = {{ position = engine_to_factorio_tile(ex, ey), type = get_tile_enum(ex, ey) }},
    })
end

---------------------------------------------------------
-- CHORD
---------------------------------------------------------

function Msw.chord(surface, ex, ey, player_index)
    if not is_revealed(ex, ey) then
        return
    end
    local needed = adjacent_mines(ex, ey)
    if needed == 0 then
        return
    end

    local discovered = 0
    local hidden = {}

    for _, off in ipairs(ADJ) do
        local nx, ny = ex + off[1], ey + off[2]
        local val = get_tile_enum(nx, ny)
        if val == TILE_FLAGGED or val == TILE_EXPLODED then
            discovered = discovered + 1
        elseif not is_revealed(nx, ny) then
            hidden[#hidden + 1] = { nx, ny }
        end
    end

    if discovered ~= needed then
        return
    end

    local revealed_tiles = {}
    for _, t in ipairs(hidden) do
        local new_tiles = Msw.reveal(surface, t.nx or t[1], t.ny or t[2], player_index)
        for _, r in ipairs(new_tiles) do
            revealed_tiles[#revealed_tiles + 1] = r
        end
    end
    return revealed_tiles
end

---------------------------------------------------------
-- ARCHIVE
---------------------------------------------------------

---------------------------------------------------------
-- ENTITY DISPLAY
---------------------------------------------------------

local function destroy_existing(surface, ex, ey)
    local area = {
        { ex * TILE_SCALE, ey * TILE_SCALE },
        { ex * TILE_SCALE + TILE_SCALE, ey * TILE_SCALE + TILE_SCALE },
    }
    for _, e in ipairs(surface.find_entities_filtered{ area = area, force = FORCE_NAME, type = 'simple-entity-with-force' }) do
        e.destroy()
    end
end

function Msw.update_tile_entity(surface, ex, ey)
    local val = get_tile_enum(ex, ey)
    destroy_existing(surface, ex, ey)
    local proto = TILE_ENTITIES[val] or TILE_ENTITIES[TILE_HIDDEN]
    local pos = engine_to_factorio_tile(ex, ey)
    local entity = surface.create_entity { name = proto, position = pos, force = FORCE_NAME }
    if entity then
        entity.destructible = false
        entity.minable = false
    end
end

function Msw.queue_update_tile_entity(surface, ex, ey)
    entity_update_queue:push { surface = surface, x = ex, y = ey }
end

local function process_entity_queue(limit)
    while (limit > 0) and (entity_update_queue:size() > 0) do
        local t = entity_update_queue:pop()
        Msw.update_tile_entity(t.surface, t.x, t.y)
        limit = limit - 1
    end
end

---------------------------------------------------------
-- DEBUG RENDERING
---------------------------------------------------------

local GREEN = { 0, 255, 0, 0.05 }
local RED = { 255, 0, 0, 0.05 }
local BLACK = { 0, 0, 0 }
local r_rect = rendering.draw_rectangle
local r_text = rendering.draw_text

-- Draw debug info for one tile
local function r_couple(surface, x, y, offset, size, player_renders, text, key)
    player_renders[#player_renders + 1] = r_rect {
        color = key and GREEN or RED,
        left_top = { TILE_SCALE * x + offset[1], TILE_SCALE * y + offset[2] },
        right_bottom = { TILE_SCALE * x + size + offset[1], TILE_SCALE * y + size + offset[2] },
        filled = true,
        surface = surface,
        players = { player_index },
    }
    if text then
        player_renders[#player_renders + 1] = r_text {
            color = BLACK,
            text = text,
            target = { TILE_SCALE * x + offset[1]+ 0.4, TILE_SCALE * y+ offset[2] + 0.2 },
            surface = surface,
            players = { player_index },
        }
    end
end

-- Display tile debug info
local function display_advanced(surface, x, y, player_index)
    local val = get_tile_enum(x, y)
    local rds = renders[player_index] or {}
    local o = TILE_SCALE / 2
    r_couple(surface, x, y, { 0, 0 }, TILE_SCALE / 2, rds, 'r', is_revealed(x, y))
    r_couple(surface, x, y, { o, 0 }, TILE_SCALE / 2, rds, 'f', is_flagged(x, y))
    r_couple(surface, x, y, { 0, o }, TILE_SCALE / 2, rds, 'm', has_mine(x, y))
    r_couple(surface, x, y, { o, o }, TILE_SCALE / 2, rds, 'e', val == TILE_EXPLODED)
    renders[player_index] = rds
end

local function display_simple(surface, x, y, player_index)
    local val = get_tile_enum(x, y)
    local rds = renders[player_index] or {}
    r_couple(surface, x, y, { 0, 0 }, TILE_SCALE, rds, nil, not has_mine(x, y))
    renders[player_index] = rds
end

-- Show 8 surrounding tiles around player
local function show_player_surroundings(surface, ex, ey, player_index)
    for _, r in pairs(renders[player_index] or {}) do
        r.destroy()
    end
    renders[player_index] = {}

    local ps = settings.get_player_settings(player_index)
    local display
    if ps['minesweeper-debug-area-advanced'].value then
        display = display_advanced
    elseif ps['minesweeper-debug-area-simple'].value then
        display = display_simple
    end

    if display then
        for _, off in ipairs(ADJ) do
            display(surface, ex + off[1], ey + off[2], player_index)
        end
    end
end

---------------------------------------------------------
-- EVENT HANDLERS
---------------------------------------------------------

local function on_player_changed_position(event)
    local player = game.get_player(event.player_index)
    if not player or player.controller_type ~= defines.controllers.character then
        return
    end

    if player.physical_surface.index ~= SURFACE_INDEX then
        return
    end

    -- Engine tile coordinates
    local ex, ey = factorio_to_engine_tile(player.physical_position)
    local surface = player.physical_surface

    -- Reveal the tile the player is on
    Msw.reveal(surface, ex, ey, event.player_index)

    -- Attempt chording around the player
    Msw.chord(surface, ex, ey, event.player_index)

    -- Show debug tiles around player
    show_player_surroundings(surface, ex, ey, event.player_index)
end

local function on_chunk_generated(event)
    local surface = event.surface
    if surface.index ~= SURFACE_INDEX then
        return
    end

    local MSW_PER_CHUNK = 32 / TILE_SCALE
    local msw_cx = math_floor(event.position.x * MSW_PER_CHUNK)
    local msw_cy = math_floor(event.position.y * MSW_PER_CHUNK)
    local updater = (game.tick == 0) and Msw.update_tile_entity or Msw.queue_update_tile_entity

    for tx = msw_cx, msw_cx + MSW_PER_CHUNK - 1 do
        for ty = msw_cy, msw_cy + MSW_PER_CHUNK - 1 do
            updater(surface, tx, ty)
        end
    end
end

local function on_tick()
    process_flood_fill_queue(4*UPDATE_RATE)
    process_entity_queue(UPDATE_RATE)
end

local function on_tile_revealed(event)
    local entity = validate_custom_input(event)
    if not entity then
        return
    end

    -- Engine tile coordinates
    local ex, ey = factorio_to_engine_tile(entity.position)
    local surface = entity.surface

    -- Reveal the tile the player is on
    Msw.reveal(surface, ex, ey, event.player_index)

    -- Attempt chording around the player
    Msw.chord(surface, ex, ey, event.player_index)

    -- Show debug tiles around player
    show_player_surroundings(surface, ex, ey, event.player_index)
end

local function on_tile_flagged(event)
    local entity = validate_custom_input(event)
    if not entity then
        return
    end

    -- Engine tile coordinates
    local ex, ey = factorio_to_engine_tile(entity.position)
    local surface = entity.surface

    -- Flag the current position
    Msw.flag(surface, ex, ey, event.player_index)

    -- Show debug tiles around player
    show_player_surroundings(surface, ex, ey, event.player_index)
end

---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

Msw.on_init = function()
    init_storage()
    if not game.forces[FORCE_NAME] then
        game.create_force(FORCE_NAME)
    end
end

Msw.on_load = load_storage

Msw.events = {
    [defines.events.on_player_changed_position] = on_player_changed_position,
    [defines.events.on_chunk_generated]         = on_chunk_generated,
    [defines.events.on_tick]                    = on_tick,
    [Const.CI_REVEAL_TILE]                      = on_tile_revealed,
    [Const.CI_FLAG_TILE]                        = on_tile_flagged,
}

return Msw

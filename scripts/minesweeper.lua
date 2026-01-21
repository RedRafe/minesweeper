local Const = require 'scripts.constants'
local Queue = require 'scripts.queue'
local Terrain = require 'scripts.terrain'

local Msw = {}

---------------------------------------------------------
-- CONFIG / ENUMS
---------------------------------------------------------

local ADJ           = Const.ADJ
local FORCE_NAME    = Const.FORCE_NAME
local SURFACE_INDEX = Const.SURFACE_INDEX
local TILE_EMPTY    = Const.TILE_EMPTY
local TILE_ENTITIES = Const.TILE_ENTITIES
local TILE_EXPLODED = Const.TILE_EXPLODED
local TILE_FLAGGED  = Const.TILE_FLAGGED
local TILE_HIDDEN   = Const.TILE_HIDDEN
local TILE_MINE     = Const.TILE_MINE
local TILE_SCALE    = Const.TILE_SCALE
local TILE_ARCHIVED = Const.TILE_ARCHIVED
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

---@param ex number
---@param ey number
---@return string
local function tile_key(ex, ey)
    return ex .. '_' .. ey
end

---@param ex number
---@param ey number
---@return string
local function chunk_key(cx, cy)
    return cx .. ',' .. cy
end

---@param ex number
---@param ey number
---@return number, number
local function get_chunk_of(ex, ey)
    return math_floor(ex * TILE_SCALE / CHUNK), math_floor(ey * TILE_SCALE / CHUNK)
end

---@param position MapPosition
---@return number, number
local function factorio_to_engine_tile(position)
    return math_floor(position.x / TILE_SCALE), math_floor(position.y / TILE_SCALE)
end

---@param ex number
---@param ey number
---@return MapPosition
local function engine_to_factorio_tile(ex, ey)
    return { x = ex * TILE_SCALE + TILE_SCALE / 2, y = ey * TILE_SCALE + TILE_SCALE / 2 }
end

---@param k string
---@return number, number
local function key_to_xy(k)
    local x, y = k:match('(%d+)_(%d+)')
    return tonumber(x), tonumber(y)
end

---------------------------------------------------------
-- TILE ENUM HELPERS
---------------------------------------------------------

---@param ex number
---@param ey number
---@return boolean
local function is_chunk_archived(ex, ey)
    local cx, cy = get_chunk_of(ex, ey)
    return archived_chunks[chunk_key(cx, cy)] == true
end

---@param ex number
---@param ey number
---@return number
local function get_tile_enum(ex, ey)
    if is_chunk_archived(ex, ey) then
        return TILE_ARCHIVED
    end
    return tiles[tile_key(ex, ey)] or TILE_HIDDEN
end

---@param ex number
---@param ey number
---@return boolean
local function is_archived(ex, ey)
    return get_tile_enum(ex, ey) == TILE_ARCHIVED
end

---@param ex number
---@param ey number
local function set_tile_enum(ex, ey, val)
    if is_chunk_archived(ex, ey) then
        return
    end
    tiles[tile_key(ex, ey)] = val
end

---@param ex number
---@param ey number
---@return boolean
local function has_mine(ex, ey)
    local val = get_tile_enum(ex, ey)
    if val == TILE_MINE or val == TILE_EXPLODED then
        return true
    end
    -- deterministic generation for hidden tiles
    if val == TILE_ARCHIVED then
        return false
    end
    local h = math_abs(bit32_bxor(bit32_bxor(ex * 0x2D0F3E, ey * 0x1F123B), this.seed))
    local d = math_min(35, 8 + math_sqrt(ex * ex + ey * ey) * 0.02)
    return h % 100 < d
end

---@param x number
---@param y number
---@return boolean
local function is_flagged(ex, ey)
    return get_tile_enum(ex, ey) == TILE_FLAGGED
end

---@param ex number
---@param ey number
---@return boolean
local function is_revealed(ex, ey)
    return get_tile_enum(ex, ey) <= 10
end

---------------------------------------------------------
-- EFFECTS
---------------------------------------------------------

---@param surface LuaSurface
---@param position MapPosition
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

---@param ex number
---@param ey number
---@return number
local function adjacent_mines(ex, ey)
    local val = get_tile_enum(ex, ey)
    if val >= 0 and val <= 8 then
        return val
    end
    local count = 0
    for _, off in ipairs(ADJ) do
        local nx, ny = ex + off[1], ey + off[2]
        if has_mine(nx, ny) then
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------
-- FLOOD-FILL
---------------------------------------------------------

---@param ex number
---@param ey number
---@param surface LuaSurface
---@param player_index number
local function flood_fill(ex, ey, surface, player_index)
    local revealed = {}
    local queue = { { ex, ey } }
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
            Msw.update_tile_entity_async(surface, cx, cy)
        end

        if adjacent_mines(cx, cy) == 0 then
            for _, off in ipairs(ADJ) do
                local nx, ny = cx + off[1], cy + off[2]
                local nk = tile_key(nx, ny)
                if not visited[nk] then
                    queue[#queue+1] = { nx, ny }
                end
            end
        end

        ::continue::
    end

    return revealed
end

---@param ex number
---@param ey number
---@param surface LuaSurface
---@param player_index number
local function flood_fill_async(ex, ey, surface, player_index)
    local tile_queue = Queue.new()
    tile_queue:push { ex, ey }

    flood_fill_queue:push {
        tile_queue = tile_queue,
        visited = {},
        player_index = player_index,
        surface = surface,
    }
end

---@param limit number
local function process_flood_fill_queue(limit)
    if flood_fill_queue:size() == 0 then
        return
    end

    -- Can only resolve 1 job per tick as they're player_index-based
    local job = flood_fill_queue:peek()

    local revealed = {}
    local tile_queue = job.tile_queue
    local visited = job.visited
    local surface = job.surface

    local count = 0

    -- Process up to limit nodes this tick
    while tile_queue:size() > 0 and count < limit do
        count = count + 1

        local node = tile_queue:pop()
        local cx, cy = node[1], node[2]
        local key = tile_key(cx, cy)

        if visited[key] then goto continue end
        visited[key] = true

        if is_archived(cx, cy) then goto check_adj end
        if is_flagged(cx, cy) then goto continue end
        if has_mine(cx, cy) then goto continue end

        if not is_revealed(cx, cy) then
            local adj = adjacent_mines(cx, cy)
            set_tile_enum(cx, cy, adj)
            revealed[#revealed+1] = { type = adj, position = engine_to_factorio_tile(cx, cy) }
            Msw.update_tile_entity_async(surface, cx, cy)
        end

        ::check_adj::

        if adjacent_mines(cx, cy) == 0 then
            for _, off in ipairs(ADJ) do
                local nx, ny = cx + off[1], cy + off[2]
                local nk = tile_key(nx, ny)
                if not visited[nk] then
                    tile_queue:push { nx, ny }
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
            player_index = job.player_index,
            surface_index = surface.index,
            tiles = revealed,
        })
    end

    -- If finished, remove job
    if tile_queue:size() == 0 then
        flood_fill_queue:pop()
    end
end

---------------------------------------------------------
-- CUSTOM INPUT HANDLING
---------------------------------------------------------

---@param event defines.events.CustomInputEvent
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

---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
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

---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
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

---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
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

    for _, off in pairs(ADJ) do
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
    for _, t in pairs(hidden) do
        local new_tiles = Msw.reveal(surface, t.nx or t[1], t.ny or t[2], player_index)
        for _, r in pairs(new_tiles) do
            revealed_tiles[#revealed_tiles + 1] = r
        end
    end
    return revealed_tiles
end

---------------------------------------------------------
-- ARCHIVE
---------------------------------------------------------

---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
function Msw.archive(surface, ex, ey, player_index)
    if is_archived(ex, ey) then
        return
    end

    if get_tile_enum(ex, ey) ~= TILE_EMPTY then
        for nx = ex - 2, ex + 2, 1 do
            for ny = ey - 2, ey + 2, 1 do
                if not is_revealed(nx, ny) and not (is_flagged(nx, ny) and has_mine(nx, ny)) then
                    return
                end
            end
        end
    end

    set_tile_enum(ex, ey, TILE_ARCHIVED)
    Msw.update_tile_entity(surface, ex, ey)

    -- Attempt archiving chunk
    local cx, cy = get_chunk_of(ex, ey)
    if archived_chunks[chunk_key(cx, cy)] then
        return
    end

    if surface.count_entities_filtered{
        area = { { cx, cy }, { cx + 31, cy + 31} },
        force = FORCE_NAME,
        type = 'simple-entity-with-force',
        limit = 1,
    } > 0 then return end

    for tx = ex, ex + 16 do
        for ty = ey, ey + 16 do
            set_tile_enum(tx, ty, nil)
            Msw.update_tile_entity(surface, tx, ty)
        end
    end

    archived_chunks[chunk_key(cx, cy)] = true
end

---------------------------------------------------------
-- SOLVE (modern Minesweeper auto-solving)
---------------------------------------------------------

---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
---@return boolean progressed
function Msw.solve(surface, ex, ey, player_index)
    local progressed = false

    -- For all 8 directions around the focal tile
    for _, off in ipairs(ADJ) do
        local cx, cy = ex + off[1], ey + off[2]

        if not is_revealed(cx, cy) then
            goto continue
        end

        local number = adjacent_mines(cx, cy)

        -- Only number tiles: 1–8 matter.
        if not (number > 0) then
            goto continue
        end

        local flagged = 0
        local hidden_neighbors = {}

        -- Scan neighbors-of-neighbor
        for _, off2 in ipairs(ADJ) do
            local nx, ny = cx + off2[1], cy + off2[2]
            local state = get_tile_enum(nx, ny)

            if state == TILE_FLAGGED then
                flagged = flagged + 1
            elseif not is_revealed(nx, ny) then
                hidden_neighbors[#hidden_neighbors + 1] = { nx, ny }
            end
        end

        local hidden_count = #hidden_neighbors

        -- Rule 1: All remaining hidden tiles are SAFE → reveal them
        if flagged == number and hidden_count > 0 then
            for _, pos in ipairs(hidden_neighbors) do
                Msw.reveal(surface, pos[1], pos[2], player_index)
            end
            progressed = true
        end

        -- Rule 2: All hidden tiles MUST be mines → flag them
        if hidden_count > 0 and (flagged + hidden_count == number) then
            for _, pos in ipairs(hidden_neighbors) do
                if get_tile_enum(pos[1], pos[2]) ~= TILE_FLAGGED then
                    Msw.flag(surface, pos[1], pos[2], player_index)
                    progressed = true
                end
            end
        end

        ::continue::
    end

    return progressed
end

---------------------------------------------------------
-- ENTITY DISPLAY
---------------------------------------------------------

---@param surface LuaSurface
---@param ex number
---@param ey number
local function destroy_existing(surface, ex, ey)
    local area = {
        { ex * TILE_SCALE, ey * TILE_SCALE },
        { ex * TILE_SCALE + TILE_SCALE, ey * TILE_SCALE + TILE_SCALE },
    }
    for _, e in ipairs(surface.find_entities_filtered{ area = area, force = FORCE_NAME, type = 'simple-entity-with-force' }) do
        e.destroy()
    end
end

---@param surface LuaSurface
---@param ex number
---@param ey number
function Msw.update_tile_entity(surface, ex, ey)
    local val = get_tile_enum(ex, ey)
    destroy_existing(surface, ex, ey)

    local proto = TILE_ENTITIES[val]
    if not proto then
        return
    end

    local pos = engine_to_factorio_tile(ex, ey)
    local entity = surface.create_entity { name = proto, position = pos, force = FORCE_NAME }
    if entity then
        entity.destructible = false
        entity.minable = false
    end
end

---@param surface LuaSurface
---@param ex number
---@param ey number
function Msw.update_tile_entity_async(surface, ex, ey)
    entity_update_queue:push { surface = surface, x = ex, y = ey }
end

---@param limit number
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
---@param surface LuaSurface
---@param ex number
---@param ey number
---@param offset table<number, number>
---@param player_renders table<LuaRenderingObject>
---@param text string
---@param status boolean
local function r_couple(surface, ex, ey, offset, size, player_renders, text, status)
    player_renders[#player_renders + 1] = r_rect {
        color = status and GREEN or RED,
        left_top = { TILE_SCALE * ex + offset[1], TILE_SCALE * ey + offset[2] },
        right_bottom = { TILE_SCALE * ex + size + offset[1], TILE_SCALE * ey + size + offset[2] },
        filled = true,
        surface = surface,
        players = { player_index },
    }
    if text then
        player_renders[#player_renders + 1] = r_text {
            color = BLACK,
            text = text,
            target = { TILE_SCALE * ex + offset[1]+ 0.4, TILE_SCALE * ey + offset[2] + 0.2 },
            surface = surface,
            players = { player_index },
        }
    end
end

-- Display tile debug info
---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
local function display_advanced(surface, ex, ey, player_index)
    local val = get_tile_enum(ex, ey)
    local rds = renders[player_index] or {}
    local o = TILE_SCALE / 2
    r_couple(surface, ex, ey, { 0, 0 }, TILE_SCALE / 2, rds, 'r', is_revealed(ex, ey))
    r_couple(surface, ex, ey, { o, 0 }, TILE_SCALE / 2, rds, 'f', is_flagged(ex, ey))
    r_couple(surface, ex, ey, { 0, o }, TILE_SCALE / 2, rds, 'm', has_mine(ex, ey))
    r_couple(surface, ex, ey, { o, o }, TILE_SCALE / 2, rds, 'e', val == TILE_EXPLODED)
    renders[player_index] = rds
end

---@param surface LuaSurface
---@param x number
---@param y number
---@param player_index number
local function display_simple(surface, ex, ey, player_index)
    local val = get_tile_enum(ex, ey)
    local rds = renders[player_index] or {}
    r_couple(surface, ex, ey, { 0, 0 }, TILE_SCALE, rds, nil, not has_mine(ex, ey))
    renders[player_index] = rds
end

-- Show 8 surrounding tiles around player
---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
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

    Msw.archive(surface, ex, ey, event.player_index)
    --Msw.solve(surface, ex, ey, event.player_index)

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
    local updater = (game.tick == 0) and Msw.update_tile_entity or Msw.update_tile_entity_async

    for tx = msw_cx, msw_cx + MSW_PER_CHUNK - 1 do
        for ty = msw_cy, msw_cy + MSW_PER_CHUNK - 1 do
            updater(surface, tx, ty)
        end
    end
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

    Msw.archive(surface, ex, ey, event.player_index)
    --Msw.solve(surface, ex, ey, event.player_index)

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

    Msw.archive(surface, ex, ey, event.player_index)
    --Msw.solve(surface, ex, ey, event.player_index)

    -- Show debug tiles around player
    show_player_surroundings(surface, ex, ey, event.player_index)
end

local function on_tick()
    process_flood_fill_queue(UPDATE_RATE * 4)
    process_entity_queue(UPDATE_RATE)
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

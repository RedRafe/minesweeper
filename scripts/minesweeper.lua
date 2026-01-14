local Queue = require 'scripts.queue'

local Msw = {}

---------------------------------------------------------
-- CONFIG / ENUMS
---------------------------------------------------------

-- Tile enums
-- 0-8: revealed tile with that many adjacent mines
-- 9: hidden / unknown tile
-- 10: flagged
-- 11: revealed mine
-- 12: exploded mine

local TILE_HIDDEN   = 9
local TILE_FLAGGED  = 10
local TILE_MINE     = 11
local TILE_EXPLODED = 12

local TILE_SCALE = 2 -- 1 MSW tile = 2x2 Factorio tiles

local TILE_ENTITIES = {
    [0] = 'minesweeper-tile-empty',
    [1] = 'minesweeper-1',
    [2] = 'minesweeper-2',
    [3] = 'minesweeper-3',
    [4] = 'minesweeper-4',
    [5] = 'minesweeper-5',
    [6] = 'minesweeper-6',
    [7] = 'minesweeper-7',
    [8] = 'minesweeper-8',
    [TILE_HIDDEN]   = 'minesweeper-tile',
    [TILE_FLAGGED]  = 'minesweeper-flag',
    [TILE_MINE]     = 'minesweeper-mine',
    [TILE_EXPLODED] = 'minesweeper-mine-explosion',
}

local ADJ = {
    {-1,-1},{0,-1},{1,-1},
    {-1, 0},       {1, 0},
    {-1, 1},{0, 1},{1, 1}
}

---------------------------------------------------------
-- STATE
---------------------------------------------------------

local processor_queue = Queue.new()

local tiles = {}           -- tiles['x_y'] = enum
local archived_chunks = {} -- archived chunks
local global_stats = {
    tiles_revealed = 0,
    mines_marked   = 0,
    mines_exploded = 0,
}
local player_stats = {}    -- [player_index] = stats
local renders = {}

local this = { seed = 12345 }
local CHUNK = 32

---------------------------------------------------------
-- STORAGE
---------------------------------------------------------

function Msw.on_init()
    storage.minesweeper = {
        this = this,
        tiles = tiles,
        archived_chunks = archived_chunks,
        global_stats = global_stats,
        player_stats = player_stats,
        renders = renders,
        processor_queue = processor_queue,
    }
end

function Msw.on_load()
    local tbl = storage.minesweeper
    this = tbl.this
    tiles = tbl.tiles
    archived_chunks = tbl.archived_chunks
    global_stats = tbl.global_stats
    player_stats = tbl.player_stats
    renders = tbl.renders
    renders = tbl.renders
    processor_queue = tbl.processor_queue
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

local function tile_key(x, y) return x .. '_' .. y end
local function chunk_key(cx, cy) return cx .. ',' .. cy end
local function get_chunk_of(x, y) return math_floor(x / CHUNK), math_floor(y / CHUNK) end

local function is_archived(x, y)
    local cx, cy = get_chunk_of(x, y)
    return archived_chunks[chunk_key(cx, cy)] == true
end

local function get_player_stats(player_index)
    local ps = player_stats[player_index]
    if ps then
        return ps
    end
    ps = {
        tiles_revealed = 0,
        mines_marked   = 0,
        mines_exploded = 0,
        score          = 0,
    }
    player_stats[player_index] = ps
    return ps
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
            revealed[#revealed+1] = {x=cx, y=cy}

            global_stats.tiles_revealed = global_stats.tiles_revealed + 1
            if player_index then
                local ps = get_player_stats(player_index)
                ps.tiles_revealed = ps.tiles_revealed + 1
                ps.score = ps.score + 1
            end

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

---------------------------------------------------------
-- REVEAL
---------------------------------------------------------

function Msw.reveal(surface, ex, ey, player_index)
    if is_archived(ex, ey) then return {} end
    if is_flagged(ex, ey) or is_revealed(ex, ey) then return {} end

    local revealed_tiles = {}

    if has_mine(ex, ey) then
        set_tile_enum(ex, ey, TILE_EXPLODED)
        revealed_tiles[#revealed_tiles+1] = {x=ex, y=ey}
        global_stats.mines_exploded = global_stats.mines_exploded + 1
        if player_index then
            local ps = get_player_stats(player_index)
            ps.mines_exploded = ps.mines_exploded + 1
            ps.score = ps.score - 10
        end

        Msw.queue_update_tile_entity(surface, ex, ey)

    else
        local adj = adjacent_mines(ex, ey)
        set_tile_enum(ex, ey, adj)
        revealed_tiles[#revealed_tiles+1] = {x=ex, y=ey}
        global_stats.tiles_revealed = global_stats.tiles_revealed + 1
        if player_index then
            local ps = get_player_stats(player_index)
            ps.tiles_revealed = ps.tiles_revealed + 1
            ps.score = ps.score + 1
        end

        Msw.queue_update_tile_entity(surface, ex, ey)

        if adj == 0 then
            local ff_tiles = flood_fill(ex, ey, surface, player_index)
            for _, t in ipairs(ff_tiles) do
                revealed_tiles[#revealed_tiles+1] = t
            end
        end
    end

    return revealed_tiles
end

---------------------------------------------------------
-- FLAG
---------------------------------------------------------

function Msw.flag(surface, ex, ey, player_index)
    if is_archived(ex, ey) then
        return
    end
    if is_revealed(ex, ey) then
        return
    end

    local val = get_tile_enum(ex, ey)
    if val == TILE_FLAGGED then
        set_tile_enum(ex, ey, TILE_HIDDEN)
        return false
    else
        set_tile_enum(ex, ey, TILE_FLAGGED)
        if has_mine(ex, ey) then
            global_stats.mines_marked = global_stats.mines_marked + 1
            if player_index then
                local ps = get_player_stats(player_index)
                ps.mines_marked = ps.mines_marked + 1
                ps.score = ps.score + 5
            end
        end
        Msw.update_tile_entity(surface, ex, ey)
        return true
    end
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
-- ENTITY DISPLAY
---------------------------------------------------------

local function factorio_to_engine_tile(pos)
    return math_floor(pos.x / TILE_SCALE), math_floor(pos.y / TILE_SCALE)
end

local function engine_to_factorio_tile(ex, ey)
    return { x = ex * TILE_SCALE + TILE_SCALE / 2, y = ey * TILE_SCALE + TILE_SCALE / 2 }
end

local function destroy_existing(surface, ex, ey)
    local area = {
        { ex * TILE_SCALE, ey * TILE_SCALE },
        { ex * TILE_SCALE + TILE_SCALE, ey * TILE_SCALE + TILE_SCALE },
    }
    for _, e in ipairs(surface.find_entities_filtered{ area = area, force = 'neutral' }) do
        e.destroy()
    end
end

function Msw.update_tile_entity(surface, ex, ey)
    local val = get_tile_enum(ex, ey)
    destroy_existing(surface, ex, ey)
    local proto = TILE_ENTITIES[val] or TILE_ENTITIES[TILE_HIDDEN]
    local pos = engine_to_factorio_tile(ex, ey)
    local entity = surface.create_entity { name = proto, position = pos, force = 'neutral' }
    if entity then
        entity.destructible = false
        entity.minable = false
    end
end

function Msw.queue_update_tile_entity(surface, ex, ey)
    processor_queue:push { surface = surface, x = ex, y = ey }
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
    local p = game.get_player(event.player_index)
    if not p or p.controller_type ~= defines.controllers.character then return end

    -- Engine tile coordinates
    local ex, ey = factorio_to_engine_tile(p.position)
    local s = p.surface

    -- Reveal the tile the player is on
    Msw.reveal(s, ex, ey, p.index)

    -- Attempt chording around the player
    Msw.chord(s, ex, ey, p.index)

    -- Show debug tiles around player
    show_player_surroundings(s, ex, ey, p.index)
end


local function on_built_entity(event)
    local entity = event.entity
    if not entity or not entity.valid or entity.name ~= 'stone-furnace' then
        return
    end
    local ex, ey = factorio_to_engine_tile(entity.position)
    Msw.flag(entity.surface, ex, ey, event.player_index)
    entity.destroy { raise_destroy = false }
end

local function on_chunk_generated(event)
    local surface = event.surface
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

local function on_nth_tick()
    local limit = 40
    while (limit > 0) and (processor_queue:size() > 0) do
        local t = processor_queue:pop()
        Msw.update_tile_entity(t.surface, t.x, t.y)
        limit = limit - 1
    end
end

---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

Msw.events = {
    [defines.events.on_player_changed_position] = on_player_changed_position,
    [defines.events.on_built_entity]            = on_built_entity,
    [defines.events.on_chunk_generated]         = on_chunk_generated,
}

Msw.on_nth_tick = {
    [2] = on_nth_tick,
}

return Msw

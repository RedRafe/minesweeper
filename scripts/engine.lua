---------------------------------------------------------
-- STATE TABLES (all stored as top-level locals)
---------------------------------------------------------

-- deterministic seed
local this = { seed = 12345 }

-- tile metadata (only NON-archived tiles are stored)
-- tiles['x,y'] = {
--      revealed   = boolean,
--      flagged    = boolean,
--      exploded   = boolean,
--      had_mine   = bool,    -- nil = not generated yet
--      adj        = number,  -- nil = not calculated
-- }
local tiles = {}
local renders = {}

-- archived chunks: archived_chunks['cx,cy'] = true
local archived_chunks = {}

-- Stats
local global_stats = {
    tiles_revealed = 0,
    mines_marked   = 0,
    mines_exploded = 0,
}
local player_stats = {} -- [player_index] = stat-table

-- chunk size (Factorio standard)
local CHUNK = 32

---------------------------------------------------------
-- UTILITY
---------------------------------------------------------

local bit32_bxor = bit32.bxor
local math_abs   = math.abs
local math_floor = math.floor
local math_min   = math.min
local math_sqrt  = math.sqrt

local function key(x, y)
    return x .. ',' .. y
end

local function chunk_key(cx, cy)
    return cx .. ',' .. cy
end

local function get_chunk_of(x, y)
    return math_floor(x / CHUNK), math_floor(y / CHUNK)
end

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
        score          = 0
    }
    player_stats[player_index] = ps
    return ps
end

local function gps(x,y)
    return ('[gps=%d,%d]'):format(2*x+1,2*y+1)
end

---------------------------------------------------------
-- DETERMINISTIC MINE GENERATION
---------------------------------------------------------

local function hash2d(x, y)
    return math_abs(
        bit32_bxor(
            bit32_bxor(x * 0x2D0F3E, y * 0x1F123B),
            this.seed
        )
    )
end

local function mine_density(x, y)
    local d = math_sqrt(x*x + y*y)
    return math_min(35, 8 + d * 0.02)
end

local function generated_has_mine(x, y)
    if is_archived(x, y) then return false end
    local h = hash2d(x, y) % 100
    return h < mine_density(x, y)
end

---------------------------------------------------------
-- TILE RETRIEVAL (creates tile entry if needed)
---------------------------------------------------------

local function get_tile(x, y)
    if is_archived(x, y) then
        return {
            archived = true,
            revealed = true,
            flagged = false,
            exploded = false,
            had_mine = false,
            adj = 0
        }
    end
    local k = key(x,y)
    local t = tiles[k]
    if t then return t end

    t = {
        revealed = false,
        flagged = false,
        exploded = false,
        had_mine = nil,
        adj = nil
    }
    tiles[k] = t
    return t
end

---------------------------------------------------------
-- MINE CHECKING
---------------------------------------------------------

local function has_mine(x, y)
    if is_archived(x, y) then return false end
    local t = tiles[key(x,y)]
    if t and t.had_mine ~= nil then
        return t.had_mine
    end
    return generated_has_mine(x, y)
end

---------------------------------------------------------
-- ADJ COUNT
---------------------------------------------------------

ADJ = {
    {-1,-1},{0,-1},{1,-1},
    {-1, 0},       {1, 0},
    {-1, 1},{0, 1},{1, 1}
}

local function adjacent_mines(x, y)
    if is_archived(x, y) then return 0 end
    local t = tiles[key(x,y)]
    if t and t.adj then return t.adj end

    local c = 0
    for _, o in ipairs(ADJ) do
        local nx, ny = x + o[1], y + o[2]
        if has_mine(nx, ny) then
            c = c + 1
        end
    end

    if t then t.adj = c end
    return c
end

---------------------------------------------------------
-- FLOOD FILL
---------------------------------------------------------

local function flood_fill(x, y, player_index)
    local stack = { {x, y} }

    while #stack > 0 do
        local node = stack[#stack]
        stack[#stack] = nil

        for _, o in ipairs(ADJ) do
            local nx, ny = node[1] + o[1], node[2] + o[2]
            if not is_archived(nx, ny) then
                local t = get_tile(nx, ny)
                if not t.revealed and not t.flagged and not has_mine(nx,ny) then
                    t.revealed = true
                    global_stats.tiles_revealed = global_stats.tiles_revealed + 1
                    if player_index then
                        local ps = get_player_stats(player_index)
                        ps.tiles_revealed = ps.tiles_revealed + 1
                    end
                    if adjacent_mines(nx, ny) == 0 then
                        stack[#stack+1] = {nx, ny}
                    end
                end
            end
        end
    end
end

-- Flood-fill revealing for 0-adjacent tiles.
-- Returns an array of {x, y} tiles that became newly revealed.
local function flood_fill_new(start_x, start_y, player_index)
    local revealed = {}              -- output array
    local visited  = {}              -- set: "x,y" → true
    local queue    = { {start_x, start_y} }

    while #queue > 0 do
        -- pop front (queue behavior)
        local node = table.remove(queue, 1)
        local x, y = node[1], node[2]
        local key = x .. "," .. y

        -- already processed?
        if visited[key] then
            goto continue
        end
        visited[key] = true

        -- never expand archived tiles
        if is_archived(x, y) then
            goto continue
        end

        local tile = get_tile(x, y)

        -- never reveal flags
        if tile.flagged then
            goto continue
        end

        -- never reveal mines during flood fill
        if has_mine(x, y) then
            goto continue
        end

        local was_revealed = tile.revealed

        -- reveal if needed
        if not was_revealed then
            tile.revealed = true

            -- stats
            global_stats.tiles_revealed = global_stats.tiles_revealed + 1
            if player_index then
                local ps = get_player_stats(player_index)
                ps.tiles_revealed = ps.tiles_revealed + 1
            end

            -- record in output
            revealed[#revealed + 1] = {x, y}
        end

        -- Only expand neighbors if this is a zero-adj tile
        if adjacent_mines(x, y) == 0 then
            for _, off in ipairs(ADJ) do
                local nx = x + off[1]
                local ny = y + off[2]

                local nkey = nx .. "," .. ny
                if not visited[nkey] and not is_archived(nx, ny) then
                    queue[#queue + 1] = {nx, ny}
                end
            end
        end

        ::continue::
    end

    return revealed
end

---------------------------------------------------------
-- REVEAL
---------------------------------------------------------

local function reveal(x, y, player_index)
    if is_archived(x, y) then return nil end

    local t = get_tile(x, y)
    if t.revealed or t.flagged then return nil end

    if has_mine(x, y) then
        t.exploded = true
        t.revealed = true
        t.had_mine = true

        global_stats.mines_exploded = global_stats.mines_exploded + 1

        if player_index then
            local ps = get_player_stats(player_index)
            ps.mines_exploded = ps.mines_exploded + 1
            ps.score = ps.score - 10
        end

        return { exploded = true }
    end

    t.revealed = true
    t.had_mine = false
    global_stats.tiles_revealed = global_stats.tiles_revealed + 1

    if player_index then
        local ps = get_player_stats(player_index)
        ps.tiles_revealed = ps.tiles_revealed + 1
    end

    local adj = adjacent_mines(x, y)
    if adj == 0 then
        --flood_fill(x, y, player_index)
    end

    return { revealed = true, adj = adj }
end

local function reveal_plus_flood_fill(x, y, player_index)
    -- archived tiles cannot be interacted with
    if is_archived(x, y) then
        return { tiles = {} }
    end

    local tile = get_tile(x, y)

    -- already revealed or flagged: no change
    if tile.revealed or tile.flagged then
        return { tiles = {} }
    end

    ---------------------------------------------------------
    -- CASE 1: MINE → explosion
    ---------------------------------------------------------
    if has_mine(x, y) then
        tile.revealed = true
        tile.exploded = true
        tile.had_mine = true

        global_stats.mines_exploded = global_stats.mines_exploded + 1

        if player_index then
            local ps = get_player_stats(player_index)
            ps.mines_exploded = ps.mines_exploded + 1
            ps.score = ps.score - 10
        end

        return {
            exploded = true,
            tiles = { {x, y} }
        }
    end

    ---------------------------------------------------------
    -- CASE 2: SAFE TILE
    ---------------------------------------------------------
    tile.revealed = true
    tile.exploded = false
    tile.had_mine = false

    global_stats.tiles_revealed = global_stats.tiles_revealed + 1

    if player_index then
        local ps = get_player_stats(player_index)
        ps.tiles_revealed = ps.tiles_revealed + 1
        ps.score = ps.score + 1
    end

    local adj = adjacent_mines(x, y)

    ---------------------------------------------------------
    -- CASE 2A: zero-adjacent → flood fill
    ---------------------------------------------------------
    if adj == 0 then
        local ff_tiles = flood_fill_new(x, y, player_index)

        -- include starting tile if not in list yet
        local first = {x, y}
        local list = { first }

        for _, pos in ipairs(ff_tiles) do
            list[#list + 1] = pos
        end

        return {
            revealed = true,
            adj = 0,
            tiles = list
        }
    end

    ---------------------------------------------------------
    -- CASE 2B: normal non-zero reveal
    ---------------------------------------------------------
    return {
        revealed = true,
        adj = adj,
        tiles = { {x, y} }
    }
end

---------------------------------------------------------
-- FLAGGING
---------------------------------------------------------

local function toggle_flag(x, y, player_index)
    if is_archived(x,y) then return nil end

    local t = get_tile(x, y)
    if t.revealed then return nil end

    if t.flagged then
        t.flagged = false
        return false
    else
        t.flagged = true

        if has_mine(x, y) then
            global_stats.mines_marked = global_stats.mines_marked + 1
            if player_index then
                local ps = get_player_stats(player_index)
                ps.mines_marked = ps.mines_marked + 1
                ps.score = ps.score + 5
            end
        end

        return true
    end
end

---------------------------------------------------------
-- CHORDING (classic-safe)
---------------------------------------------------------

local function chord(x, y, player_index)
    if is_archived(x,y) then return nil end

    local t = get_tile(x,y)
    if not t.revealed then return nil end

    local needed_mines = adjacent_mines(x, y)
    if needed_mines == 0 then return nil end

    local discovered_mines = 0
    local hidden = {}

    for _, o in ipairs(ADJ) do
        local nx, ny = x + o[1], y + o[2]
        if not is_archived(nx, ny) then
            local nt = get_tile(nx, ny)
            if nt.flagged or nt.exploded then
                discovered_mines = discovered_mines + 1
            elseif not nt.revealed then
                hidden[#hidden+1] = { nx, ny }
            end
        end
    end

    if discovered_mines ~= needed_mines then
        return nil
    end

    local results = {}
    for _, c in ipairs(hidden) do        
        local r = reveal_plus_flood_fill(c[1], c[2], player_index)
        if r and r.tiles then
            for _, t in pairs(r.tiles) do
                results[#results+1] = { x = t[1], y = t[2] }
            end
        end
    end

    return results
end

---------------------------------------------------------
-- ARCHIVING CHUNKS
---------------------------------------------------------

local function archive_chunk(cx, cy)
    local ck = chunk_key(cx, cy)
    if archived_chunks[ck] then return end
    archived_chunks[ck] = true

    -- remove all tile entries inside chunk
    for x = cx*CHUNK, cx*CHUNK + CHUNK - 1 do
        for y = cy*CHUNK, cy*CHUNK + CHUNK - 1 do
            tiles[key(x,y)] = nil
        end
    end
end

---------------------------------------------------------
-- DEBUGGING
---------------------------------------------------------

local function r_couple(x, y, pid, offset, text, key)
    local rds = renders[pid] or {}
    table.insert(rds, rendering.draw_rectangle{
        color = key and { 0, 255, 0, 0.05 } or { 255, 0, 0, 0.05 },
        left_top = { 2*x+offset[1], 2*y+offset[2] },
        right_bottom = { 2*x+offset[1]+1,2*y+offset[2]+1},
        filled = true,
        surface = game.surfaces.nauvis,
    })
    table.insert(rds, rendering.draw_text{
        color = { 0, 0, 0 },
        text = text,
        target = { x = 2*x+offset[1]+0.4, y = 2*y+offset[2]+0.2},
        surface = game.surfaces.nauvis,
    })
    renders[pid] = rds
end

function display(x, y, pid)
    local nt = get_tile(x, y)
    r_couple(x, y, pid, {0, 0}, 'r', nt.revealed)
    r_couple(x, y, pid, {1, 0}, 'f', nt.flagged)
    r_couple(x, y, pid, {0, 1}, 'm', has_mine(x, y))
    r_couple(x, y, pid, {1, 1}, 'e', nt.exploded)
end

local function show_player_surroundings(ex, ey, player_index)
    for _, r in pairs(renders[player_index] or {}) do
        r.destroy()
    end
    if settings.get_player_settings(player_index)['minesweeper-debug-area'].value then
        for _, o in pairs(ADJ) do
            display(ex + o[1], ey + o[2], player_index)
        end
    end
end

---------------------------------------------------------
-- STORAGE REGISTRATION
---------------------------------------------------------

local Public = {}

Public.on_init = function()
    storage.engine = {
        this = this,
        tiles = tiles,
        archived_chunks = archived_chunks,
        global_stats = global_stats,
        player_stats = player_stats,
        renders = renders,
    }
end

Public.on_load = function()
    local engine = storage.engine
    this = engine.this
    tiles = engine.tiles
    archived_chunks = engine.archived_chunks
    global_stats = engine.global_stats
    player_stats = engine.player_stats
    renders = engine.renders
end

---------------------------------------------------------
-- MODULE EXPORTED API
---------------------------------------------------------

Public.reveal = reveal
Public.flag = toggle_flag
Public.chord = chord
Public.flood = flood_fills
Public.has_mine = has_mine
Public.is_archived = is_archived
Public.archive_chunk = archive_chunk
Public.adjacent_mines = adjacent_mines
Public.get_tile = get_tile
Public.show_player_surroundings = show_player_surroundings
Public.stats_global = function() return global_stats end
Public.stats_player = function(player_index) return get_player_stats(player_index) end

return Public

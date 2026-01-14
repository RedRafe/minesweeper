-- ======================================================================
-- MINESWEEPER ENGINE — FINAL VERSION
-- Fully integrated archived-chunk logic
-- Safe chording, safe flood fill, deterministic mines
-- ======================================================================

local Engine = {}

-- ----------------------------------------------------------------------
-- Constants
-- ----------------------------------------------------------------------
local CHUNK_SIZE = 32

local STATE_UNKNOWN   = 0
local STATE_REVEALED  = 1
local STATE_FLAGGED   = 2
local STATE_EXPLODED  = 3

-- ----------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------

local floor = math.floor

local function chunk_pos(x, y)
    return floor(x / CHUNK_SIZE), floor(y / CHUNK_SIZE)
end

local function tile_key(x, y)
    return x .. ',' .. y
end

local function chunk_key(cx, cy)
    return cx .. ',' .. cy
end

-- Deterministic hash: returns a 32-bit number
local function hash2d(x, y, seed)
    -- Bit32 required in Factorio
    return bit32.band(
        bit32.bxor(
            bit32.bxor(x * 73856093, y * 19349663),
            seed
        ),
        0xFFFFFFFF
    )
end

-- ----------------------------------------------------------------------
-- Engine.new
-- ----------------------------------------------------------------------
function Engine.new(seed, spawn_radius, mine_rate)
    return {
        seed = seed or 1,
        spawn_radius = spawn_radius or 32,
        mine_rate = mine_rate or 0.15,

        tiles = {},         -- x,y → tile state
        archived = {},      -- cx,cy → true
    }
end

-- ----------------------------------------------------------------------
-- ARCHIVED CHUNK LOGIC
-- ----------------------------------------------------------------------

local function is_archived(engine, x, y)
    local cx, cy = chunk_pos(x, y)
    return engine.archived[chunk_key(cx, cy)] == true
end

local function is_chunk_archived(engine, cx, cy)
    return engine.archived[chunk_key(cx, cy)] == true
end

function Engine.try_archive_chunk(engine, cx, cy)
    local ck = chunk_key(cx, cy)
    if engine.archived[ck] then return end

    engine.archived[ck] = true

    -- Remove tiles inside this chunk
    local x0, y0 = cx * CHUNK_SIZE, cy * CHUNK_SIZE
    for x = x0, x0 + CHUNK_SIZE - 1 do
        for y = y0, y0 + CHUNK_SIZE - 1 do
            engine.tiles[tile_key(x, y)] = nil
        end
    end
end

-- ----------------------------------------------------------------------
-- SYNTHETIC TILE for ARCHIVED CHUNK
-- ----------------------------------------------------------------------

local function synthetic_archived_tile()
    return {
        state = STATE_REVEALED,
        had_mine = false,
        adj = 0,
    }
end

local function get_tile(engine, x, y)
    if is_archived(engine, x, y) then
        return synthetic_archived_tile()
    end

    return engine.tiles[tile_key(x, y)]
end

-- Creates tile only if the chunk is not archived
local function ensure_tile(engine, x, y)
    if is_archived(engine, x, y) then
        return synthetic_archived_tile()
    end

    local k = tile_key(x, y)
    local t = engine.tiles[k]
    if t then
        return t
    end

    t = {
        state = STATE_UNKNOWN,
        had_mine = nil,    -- nil = not yet computed
        adj = nil,
    }
    engine.tiles[k] = t
    return t
end

-- ----------------------------------------------------------------------
-- MINE GENERATION
-- ----------------------------------------------------------------------

local function generated_has_mine(engine, x, y)
    if is_archived(engine, x, y) then
        return false
    end

    local cx, cy = chunk_pos(x, y)
    if cx == 0 and cy == 0 then
        -- spawn protection
        return false
    end

    local h = hash2d(x, y, engine.seed)
    local r = (h % 10000) / 10000.0
    return r < engine.mine_rate
end

function Engine.has_mine(engine, x, y)
    if is_archived(engine, x, y) then
        return false
    end

    local t = engine.tiles[tile_key(x, y)]
    if t and t.had_mine ~= nil then
        return t.had_mine
    end

    return generated_has_mine(engine, x, y)
end

-- ----------------------------------------------------------------------
-- ADJACENCY
-- ----------------------------------------------------------------------

function Engine.adjacent_mines(engine, x, y)
    if is_archived(engine, x, y) then
        return 0
    end

    local t = engine.tiles[tile_key(x, y)]
    if t and t.adj ~= nil then
        return t.adj
    end

    local count = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                if Engine.has_mine(engine, x + dx, y + dy) then
                    count = count + 1
                end
            end
        end
    end

    if t then t.adj = count end
    return count
end

-- ----------------------------------------------------------------------
-- REVEAL + FLOOD FILL
-- ----------------------------------------------------------------------

local function flood_fill(engine, x, y)
    local queue = {}
    table.insert(queue, {x = x, y = y})

    while #queue > 0 do
        local node = table.remove(queue)
        local tx, ty = node.x, node.y

        -- skip archived
        if is_archived(engine, tx, ty) then goto continue end

        local t = ensure_tile(engine, tx, ty)
        if t.state ~= STATE_UNKNOWN then goto continue end

        t.state = STATE_REVEALED
        t.had_mine = false -- guaranteed
        local adj = Engine.adjacent_mines(engine, tx, ty)

        if adj == 0 then
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        local nx = tx + dx
                        local ny = ty + dy
                        if not is_archived(engine, nx, ny) then
                            table.insert(queue, {x = nx, y = ny})
                        end
                    end
                end
            end
        end

        ::continue::
    end
end

function Engine.reveal(engine, x, y)
    if is_archived(engine, x, y) then return nil end

    local t = ensure_tile(engine, x, y)
    if t.state == STATE_REVEALED then return nil end
    if t.state == STATE_FLAGGED then return nil end

    if Engine.has_mine(engine, x, y) then
        t.state = STATE_EXPLODED
        t.had_mine = true
        return true -- exploded
    end

    flood_fill(engine, x, y)
    return false
end

-- ----------------------------------------------------------------------
-- FLAGGING
-- ----------------------------------------------------------------------

function Engine.toggle_flag(engine, x, y)
    if is_archived(engine, x, y) then return end

    local t = ensure_tile(engine, x, y)
    if t.state == STATE_REVEALED then return end

    if t.state == STATE_UNKNOWN then
        t.state = STATE_FLAGGED
    elseif t.state == STATE_FLAGGED then
        t.state = STATE_UNKNOWN
    end
end

-- ----------------------------------------------------------------------
-- SAFE CHORDING
-- ----------------------------------------------------------------------

function Engine.chord(engine, x, y)
    if is_archived(engine, x, y) then return end

    local t = engine.tiles[tile_key(x, y)]
    if not t or t.state ~= STATE_REVEALED then return end

    local adj = Engine.adjacent_mines(engine, x, y)

    -- count flags around
    local flags = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                if not is_archived(engine, x + dx, y + dy) then
                    local nt = get_tile(engine, x + dx, y + dy)
                    if nt and nt.state == STATE_FLAGGED then
                        flags = flags + 1
                    end
                end
            end
        end
    end

    if flags ~= adj then return end

    -- safe to reveal neighbors
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx = x + dx
                local ny = y + dy
                if not is_archived(engine, nx, ny) then
                    Engine.reveal(engine, nx, ny)
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------
-- EXPORT
-- ----------------------------------------------------------------------
return Engine

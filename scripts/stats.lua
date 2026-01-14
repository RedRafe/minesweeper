-- stats.lua
-- Minesweeper statistics module for global + per-player totals

local Stats = {}

---------------------------------------------------------
-- STATE MANAGEMENT
---------------------------------------------------------

local function ensure_state()
    storage.minesweeper = storage.minesweeper or {}
    storage.minesweeper.stats = storage.minesweeper.stats or {
        global = {
            tiles_revealed = 0,
            zeroes_revealed = 0,
            numbers_revealed = 0,
            mines_flagged = 0,
            flags_removed = 0,
            mines_exploded = 0,
            chords = 0,
            clusters_cleared = 0,
        },
        players = {}
    }
    return storage.minesweeper.stats
end

local function ensure_player(stats, pindex)
    stats.players[pindex] = stats.players[pindex] or {
        tiles_revealed = 0,
        zeroes_revealed = 0,
        numbers_revealed = 0,
        mines_flagged = 0,
        flags_removed = 0,
        mines_exploded = 0,
        chords = 0,
        clusters_cleared = 0,
    }
    return stats.players[pindex]
end

---------------------------------------------------------
-- INTERNAL HELPERS
---------------------------------------------------------

local function inc(tbl, key, amount)
    tbl[key] = (tbl[key] or 0) + (amount or 1)
end

---------------------------------------------------------
-- EXPORTED STAT EVENTS
--
-- Called by your adapter layer.
--
-- All functions assume tile coords x,y and engine to detect
-- mine / number / zero states.
---------------------------------------------------------


---------------------------------------------------------
-- On Reveal
---------------------------------------------------------

function Stats.on_reveal(engine, pindex, x, y)
    local stats = ensure_state()
    local p = ensure_player(stats, pindex)

    local key = x .. ',' .. y

    -- Common counters
    inc(stats.global, 'tiles_revealed')
    inc(p, 'tiles_revealed')

    -- Determine tile type
    if engine.mines[key] then
        -- reveal SHOULD be safe, explode would be via on_explode
        -- we still count the reveal as a number type event though
        inc(stats.global, 'numbers_revealed')
        inc(p, 'numbers_revealed')
        return
    end

    local c = engine.compute_number(engine, x, y) -- safe function

    if c == 0 then
        inc(stats.global, 'zeroes_revealed')
        inc(p, 'zeroes_revealed')
    else
        inc(stats.global, 'numbers_revealed')
        inc(p, 'numbers_revealed')
    end
end

---------------------------------------------------------
-- On Explosion (from reveal or chord)
---------------------------------------------------------

function Stats.on_explosion(pindex)
    local stats = ensure_state()
    local p = ensure_player(stats, pindex)

    inc(stats.global, 'mines_exploded')
    inc(p, 'mines_exploded')
end

---------------------------------------------------------
-- On Flag Toggle
---------------------------------------------------------

function Stats.on_flag(engine, pindex, x, y)
    local stats = ensure_state()
    local p = ensure_player(stats, pindex)
    local key = x .. ',' .. y

    if engine.flagged[key] then
        -- Flag was **just placed**
        if engine.mines[key] then
            inc(stats.global, 'mines_flagged')
            inc(p, 'mines_flagged')
        end
    else
        -- Flag was **just removed**
        inc(stats.global, 'flags_removed')
        inc(p, 'flags_removed')
    end
end

---------------------------------------------------------
-- On Chord
---------------------------------------------------------

function Stats.on_chord(pindex, tile_list)
    local stats = ensure_state()
    local p = ensure_player(stats, pindex)

    inc(stats.global, 'chords')
    inc(p, 'chords')

    -- tile_list is the returned auto-revealed flood fill
    if tile_list and #tile_list > 20 then
        -- arbitrary criterion for a 'cluster'
        inc(stats.global, 'clusters_cleared')
        inc(p, 'clusters_cleared')
    end
end

---------------------------------------------------------
-- Export: Query functions
---------------------------------------------------------

function Stats.get_global()
    local stats = ensure_state()
    return stats.global
end

function Stats.get_player(pindex)
    local stats = ensure_state()
    return ensure_player(stats, pindex)
end

---------------------------------------------------------
-- Export: Reset functions
---------------------------------------------------------

function Stats.reset_global()
    local stats = ensure_state()
    stats.global = {
        tiles_revealed = 0,
        zeroes_revealed = 0,
        numbers_revealed = 0,
        mines_flagged = 0,
        flags_removed = 0,
        mines_exploded = 0,
        chords = 0,
        clusters_cleared = 0,
    }
end

function Stats.reset_player(pindex)
    local stats = ensure_state()
    stats.players[pindex] = nil
end

---------------------------------------------------------
-- Export: Full Reset
---------------------------------------------------------

function Stats.reset_all()
    storage.minesweeper.stats = nil
    ensure_state()
end

return Stats

local Public = {}

-- Shared with prototypes
Public.UNIT_SPAWNER_ID = 'minesweeper-unit-spawner-death'
Public.CHORD_NAME      = 'minesweeper-chording'
Public.TOOL_NAME       = 'minesweeper-tool'
Public.KEYBIND_NAME    = 'minesweeper-give-tool'
Public.CI_REVEAL_TILE  = 'minesweeper-tile-reveal'
Public.CI_FLAG_TILE    = 'minesweeper-tile-flag'

-- Tile enums
-- 0-8: revealed tile with that many adjacent mines
-- 9: archived
-- 10: exploded
-- 11: hidden
-- 12: mine
-- 13: flagged
Public.TILE_EMPTY    = 0
Public.TILE_ARCHIVED = 9
Public.TILE_EXPLODED = 10
Public.TILE_HIDDEN   = 11
Public.TILE_MINE     = 12
Public.TILE_FLAGGED  = 13

Public.TILE_SCALE = 2 -- 1 MSW tile = 2x2 Factorio tiles
Public.SURFACE_INDEX = 1
Public.FORCE_NAME = 'minesweeper'

Public.ADJ = {
    {-1,-1},{0,-1},{1,-1},
    {-1, 0},       {1, 0},
    {-1, 1},{0, 1},{1, 1}
}

Public.TILE_ENTITIES = {
    [Public.TILE_EMPTY]    = 'minesweeper-tile-empty',
    [1] = 'minesweeper-1',
    [2] = 'minesweeper-2',
    [3] = 'minesweeper-3',
    [4] = 'minesweeper-4',
    [5] = 'minesweeper-5',
    [6] = 'minesweeper-6',
    [7] = 'minesweeper-7',
    [8] = 'minesweeper-8',
    [Public.TILE_ARCHIVED] = false,
    [Public.TILE_EXPLODED] = 'minesweeper-mine-explosion',
    [Public.TILE_HIDDEN]   = 'minesweeper-tile',
    [Public.TILE_MINE]     = 'minesweeper-mine',
    [Public.TILE_FLAGGED]  = 'minesweeper-flag',
}

Public.POINTS = {
    [0] = 1,
    [1] = 1,
    [2] = 1,
    [3] = 1,
    [4] = 1,
    [5] = 1,
    [6] = 1,
    [7] = 1,
    [8] = 1,
    [Public.TILE_HIDDEN]   =   -5, -- toggling an already flagged tile
    [Public.TILE_FLAGGED]  =    5,
    [Public.TILE_MINE]     =    0, -- cannot be 'revealed'
    [Public.TILE_EXPLODED] = -100,
}

Public.dummy_list = function()
    return {
        { name = 'George', score = 27, tiles_revealed = 12000, mines_marked = 24, mines_exploded = 27, color = { 255, 255, 255 } },
        { name = 'Alice',  score = 45, tiles_revealed = 15000, mines_marked = 30, mines_exploded =  2, color = { 255,   0,   0 } },
        { name = 'Bob',    score = 33, tiles_revealed = 13000, mines_marked = 25, mines_exploded =  5, color = {   0, 255,   0 } },
        { name = 'Carol',  score = 50, tiles_revealed = 16000, mines_marked = 35, mines_exploded =  1, color = {   0,   0, 255 } },
        { name = 'Dave',   score = 22, tiles_revealed = 12500, mines_marked = 20, mines_exploded = 10, color = { 255, 255,   0 } },
        { name = 'Eve',    score = 60, tiles_revealed = 17000, mines_marked = 40, mines_exploded =  0, color = { 255,   0, 255 } },
        { name = 'Frank',  score = 19, tiles_revealed = 11000, mines_marked = 15, mines_exploded = 15, color = {   0, 255, 255 } },
        { name = 'Grace',  score = 40, tiles_revealed = 14000, mines_marked = 28, mines_exploded =  3, color = { 128, 128, 128 } },
        { name = 'Hank',   score = 55, tiles_revealed = 16500, mines_marked = 38, mines_exploded =  2, color = {  75,   0, 130 } },
        { name = 'Ivy',    score = 28, tiles_revealed = 12800, mines_marked = 22, mines_exploded =  8, color = { 255, 165,   0 } },
        { name = 'Jack',   score = 48, tiles_revealed = 15500, mines_marked = 33, mines_exploded =  4, color = {   0, 128, 128 } },
        { name = 'Kara',   score = 35, tiles_revealed = 14500, mines_marked = 26, mines_exploded =  6, color = { 255, 192, 203 } },
        { name = 'Leo',    score = 42, tiles_revealed = 15200, mines_marked = 29, mines_exploded =  2, color = { 173, 216, 230 } },
        { name = 'Mia',    score = 25, tiles_revealed = 12050, mines_marked = 19, mines_exploded = 12, color = { 240, 230, 140 } },
        { name = 'Nina',   score = 52, tiles_revealed = 16200, mines_marked = 36, mines_exploded =  1, color = { 255, 140,   0 } },
        { name = 'Oscar',  score = 37, tiles_revealed = 14800, mines_marked = 27, mines_exploded =  7, color = {   0, 100,   0 } },
        { name = 'Paul',   score = 31, tiles_revealed = 13800, mines_marked = 23, mines_exploded =  9, color = { 139,  69,  19 } },
        { name = 'Quinn',  score = 46, tiles_revealed = 15800, mines_marked = 32, mines_exploded =  3, color = {  75,   0, 130 } },
        { name = 'Rachel', score = 29, tiles_revealed = 12400, mines_marked = 20, mines_exploded = 11, color = { 255, 105, 180 } },
        { name = 'Sam',    score = 54, tiles_revealed = 16800, mines_marked = 37, mines_exploded =  2, color = {   0,   0,   0 } },
    }
end

return Public

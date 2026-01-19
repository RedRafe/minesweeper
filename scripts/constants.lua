local Public = {}

-- Shared with prototypes
Public.TOOL_NAME      = 'minesweeper-tool'
Public.KEYBIND_NAME   = 'minesweeper-give-tool'
Public.CI_REVEAL_TILE = 'minesweeper-reveal-tile'
Public.CI_FLAG_TILE   = 'minesweeper-flag-tile'

-- Tile enums
-- 0-8: revealed tile with that many adjacent mines
-- 9: hidden / unknown tile
-- 10: flagged
-- 11: revealed mine
-- 12: exploded mine

Public.TILE_HIDDEN   = 9
Public.TILE_FLAGGED  = 10
Public.TILE_MINE     = 11
Public.TILE_EXPLODED = 12

Public.TILE_SCALE = 2 -- 1 MSW tile = 2x2 Factorio tiles
Public.FORCE_NAME = 'minesweeper'

Public.ADJ = {
    {-1,-1},{0,-1},{1,-1},
    {-1, 0},       {1, 0},
    {-1, 1},{0, 1},{1, 1}
}

Public.TILE_ENTITIES = {
    [0] = 'minesweeper-tile-empty',
    [1] = 'minesweeper-1',
    [2] = 'minesweeper-2',
    [3] = 'minesweeper-3',
    [4] = 'minesweeper-4',
    [5] = 'minesweeper-5',
    [6] = 'minesweeper-6',
    [7] = 'minesweeper-7',
    [8] = 'minesweeper-8',
    [Public.TILE_HIDDEN]   = 'minesweeper-tile',
    [Public.TILE_FLAGGED]  = 'minesweeper-flag',
    [Public.TILE_MINE]     = 'minesweeper-mine',
    [Public.TILE_EXPLODED] = 'minesweeper-mine-explosion',
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

return Public

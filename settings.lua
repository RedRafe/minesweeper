data:extend {
    {
        type = 'bool-setting',
        name = 'minesweeper-debug',
        setting_type = 'runtime-global',
        default_value = false,
    },
    {
        type = 'bool-setting',
        name = 'minesweeper-chording',
        setting_type = 'runtime-per-user',
        default_value = true,
        order = 'a',
    },
    {
        type = 'bool-setting',
        name = 'minesweeper-debug-area-simple',
        setting_type = 'runtime-per-user',
        default_value = true,
        order = 'b',
    },
    {
        type = 'bool-setting',
        name = 'minesweeper-debug-area-advanced',
        setting_type = 'runtime-per-user',
        default_value = false,
        order = 'c',
    },
}

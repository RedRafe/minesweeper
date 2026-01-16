data:extend {
    {
        type = 'noise-function',
        name = 'ms_small_areas',
        parameters = { 'x', 'y' },
        expression = [[
            (
                basis_noise{
                    x = x * 0.010,
                    y = y * 0.010,
                    seed0 = map_seed,
                    seed1 = 0
                } * 1.00
                +
                basis_noise{
                    x = x * 0.100,
                    y = y * 0.100,
                    seed0 = map_seed + 10000,
                    seed1 = 0
                } * 0.02
                +
                basis_noise{
                    x = x * 0.100,
                    y = y * 0.100,
                    seed0 = map_seed + 20000,
                    seed1 = 0
                } * 0.03
            ) / 1.05
        ]],
    },
    {
        type = 'noise-function',
        name = 'ms_cave_rivers',
        parameters = { 'x', 'y' },
        expression = [[
            (
                basis_noise{
                    x = x * 0.005,
                    y = y * 0.005,
                    seed0 = map_seed,
                    seed1 = 0
                } * 1.00
                +
                basis_noise{
                    x = x * 0.010,
                    y = y * 0.010,
                    seed0 = map_seed + 10000,
                    seed1 = 0
                } * 0.25
                +
                basis_noise{
                    x = x * 0.050,
                    y = y * 0.050,
                    seed0 = map_seed + 20000,
                    seed1 = 0
                } * 0.01
            ) / 1.26
        ]],
    },
    {
        type = 'noise-function',
        name = 'ms_tile_selector',
        parameters = { 'x', 'y' },
        expression = [[if ((bucket != 0) * (is_river == 1), -1, if (cr > 0, 1, 0))]],
        local_expressions = {
            sm = 'ms_small_areas(x, y)',
            cr = 'ms_cave_rivers(x, y)',
            bucket = 'floor((sm * 20) % 12)', -- floor((sm * 8) % 5)
            is_river = 'abs(cr) < 0.08',
        },
    },
}
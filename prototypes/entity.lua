local function entity(params)
    return {
        type = 'simple-entity',
        name = params.name,
        collision_box = {
            left_top = { -0.9, -0.9 },
            right_bottom = { 0.9, 0.9 }
        },
        selection_box = {
            left_top = { -1.0, -1.0 },
            right_bottom = { 1.0, 1.0 }
        },
        icon = '__minesweeper__/graphics/minesweeper-'..(params.icon or params.name)..'.jpg',
        icon_size = 894,
        pictures = {
            filename = '__minesweeper__/graphics/minesweeper-'..(params.icon or params.name)..'.jpg',
            size = 894,
            scale = 64 / 894,
        },
        order = 'minesweeper-'..params.name,
        subgroup = 'minesweeper',
        collision_mask = { layers = {} },
        render_layer = 'above-tiles',
        build_grid_size = 2,
    }
end

data:extend{
    {
        type = 'item-subgroup',
        name = 'minesweeper',
        group = 'other'
    },
    entity{ name = '1' },
    entity{ name = '2' },
    entity{ name = '3' },
    entity{ name = '4' },
    entity{ name = '5' },
    entity{ name = '6' },
    entity{ name = '7' },
    entity{ name = '8' },
    entity{ name = 'mine' },
    entity{ name = 'defeat' },
    entity{ name = 'mine-explosion' },
    entity{ name = 'flag' },
    entity{ name = 'smile' },
    entity{ name = 'success' },
    entity{ name = 'surprise' },
    entity{ name = 'tile-empty' },
    entity{ name = 'tile' },
    entity{ name = 'unknown' },
}
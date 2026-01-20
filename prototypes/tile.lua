---------------------------------------------------------
-- Autoplace driven by ms_tile_dictionary noise exp
---------------------------------------------------------

local mgs = data.raw.planet.nauvis.map_gen_settings
local property_expression_names = mgs.property_expression_names

-- Nuclear ground
data.raw.tile['nuclear-ground'].autoplace = {
    probability_expression = '1',
    order = 'a',
}

mgs.autoplace_settings.tile = {
    settings = {
        ['nuclear-ground'] = {},
        --['water-shallow'] = {},
        --['sand-1'] = {},
        --['sand-2'] = {},
        --['sand-3'] = {},
        --['grass-1'] = {},
        --['grass-2'] = {},
        --['grass-3'] = {},
    },
}

for i, name in pairs({
    'water-shallow',
    'sand-1',
    'sand-2',
    'sand-3',
    'grass-1',
    'grass-2',
    'grass-3'
}) do
    local expression_name = 'ms_ne_'..i
    data.raw.tile[name].autoplace = { probability_expression = expression_name }
    property_expression_names[name] = expression_name

    data:extend({{
        name = expression_name,
        type = 'noise-expression',
        expression = ('(ms_tile_dictionary(x, y) == %d)'):format(i)
    }})
end

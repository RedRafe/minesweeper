-- ================================================
-- Autoplace driven by ms_tile_selector noise func
-- ================================================

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
        --['grass-1'] = {},
        --['sand-1'] = {},
        --['grass-2'] = {},
        --['sand-2'] = {},
        --['grass-3'] = {},
        --['sand-3'] = {},
    },
}

if true then
    mgs.autoplace_settings.tile = {
        settings = {
            --['nuclear-ground'] = {},
            ['water-shallow'] = {},
            ['grass-1'] = {},
            ['grass-2'] = {},
            ['grass-3'] = {},
            ['sand-1'] = {},
            ['sand-2'] = {},
            ['sand-3'] = {},
        },
    }
end

-- Water (selector = -1)
data.raw.tile['water-shallow'].autoplace = {
    probability_expression = 'ms_tile_selector(x, y) == -1',
    order = 'a[water]-a[shallow]',
}
property_expression_names['whater-shallow'] = data.raw.tile['water-shallow'].autoplace.probability_expression

-- Sand (selector = 1)
local sand_tiles = { 'sand-1', 'sand-2', 'sand-3' }
for i, name in ipairs(sand_tiles) do
    data.raw.tile[name].autoplace = {
        probability_expression = string.format([[(ms_tile_selector(x, y) == 1) * (floor((ms_cave_rivers(x, y) * 10) %% 3 + 1)  == %d)]], i),
        order = 'b[sand]-' .. i,
    }
    property_expression_names[name] = data.raw.tile[name].autoplace.probability_expression
end

-- Grass tiles (selector = 0)
local grass_tiles = { 'grass-1', 'grass-2', 'grass-3' }
for i, name in ipairs(grass_tiles) do
    data.raw.tile[name].autoplace = {
        probability_expression = string.format([[(ms_tile_selector(x, y) == 0) * (floor((ms_cave_rivers(x, y) * 10) %% 3 + 1) == %d)]], i),
        order = 'c[grass]-' .. i,
    }
end

-- Remove ores & enemies from map gen
for name, ac in pairs(data.raw['autoplace-control']) do
    if ac.category == 'resource' or ac.category == 'enemy' then
        mgs.autoplace_controls[name] = nil
        ac.hidden = ac.category ~= 'enemy'
    end
end

for name, _ in pairs(data.raw.resource) do
    mgs.autoplace_settings.entity.settings[name] = nil
end

log(serpent.block(data.raw.planet.nauvis))

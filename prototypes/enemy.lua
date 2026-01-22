local Const = require 'scripts.constants'

---------------------------------------------------------
-- EVOLUTION RAFFLE
---------------------------------------------------------

local REPEAT_COUNT = 8

data:extend{
    {
        type = 'item-subgroup',
        name = 'minesweeper-effects',
        group = 'other',
        order = 'minesweeper-b'
    },
    {
        type = 'item-subgroup',
        name = 'minesweeper-evolution',
        group = 'other',
        order = 'minesweeper-c'
    }
}

--- Build interval dictionary from unit curves
local function create_interval_functions(result_units)
    local transformed_units = {}

    for _, unit in ipairs(result_units) do
        local name = unit[1]
        local points = unit[2]
        local intervals = {}

        for i = 1, #points - 1 do
            local left = points[i]
            local right = points[i + 1]

            local x1, y1 = left[1], left[2]
            local x2, y2 = right[1], right[2]

            local slope = (y2 - y1) / (x2 - x1)
            local intercept = y1 - slope * x1

            local function formula(x)
                return slope * x + intercept
            end

            intervals[#intervals + 1] = {
                min = x1,
                max = x2,
                formula = formula,
            }
        end

        transformed_units[name] = intervals
    end

    return transformed_units
end

--- Build evo probability lookup table, normalized per evo
local function get_evolution_dictionary(spawner)
    local interval_dictionary = create_interval_functions(spawner.result_units)
    local evos = {}

    for e = 1, 100 do
        local e0 = e / 100
        local collected = {}

        -- Collect raw probabilities
        for unit_name, intervals in pairs(interval_dictionary) do
            for _, info in ipairs(intervals) do
                if e0 >= info.min and e0 <= info.max then
                    local p = info.formula(e0)
                    if p > 0 then
                        collected[#collected + 1] = {
                            entity_name = unit_name,
                            probability = p,
                        }
                    end
                end
            end
        end

        -- Normalize so sum = 1
        local total = 0
        for _, v in ipairs(collected) do
            total = total + v.probability
        end

        if total > 0 then
            for _, v in ipairs(collected) do
                v.probability = v.probability / total
            end
        end

        evos[e] = collected
    end

    return evos
end

--- Build the created_effect source effects
local function create_source_effects(evolution_effects, repeat_count)
    local effects = {
        {
            type = 'create-explosion',
            entity_name = 'big-biter-die',
        },
        {
            type = 'create-explosion',
            entity_name = 'explosion',
        },
    }

    for _, effect in ipairs(evolution_effects) do
        effects[#effects + 1] = {
            type = 'create-entity',
            repeat_count = repeat_count,
            as_enemy = true,
            ignore_no_enemies_mode = false,
            find_non_colliding_position = true,
            entity_name = effect.entity_name,
            probability = effect.probability,
        }
    end

    return effects
end

--- Create corpse entity for evo stage
local function create_evolution_corpse(entity, evo, evolution_effects)
    data:extend({
        {
            type = 'corpse',
            name = entity.name .. '-evolution-' .. evo,
            time_before_removed = 1,
            created_effect = {
                type = 'direct',
                action_delivery = {
                    type = 'instant',
                    source_effects = create_source_effects(evolution_effects, REPEAT_COUNT),
                },
            },
            flags = {
                'placeable-enemy',
                'placeable-off-grid',
                'not-repairable',
                'not-on-map',
                'not-selectable-in-game',
            },
            icons = {
                { icon = '__mine-sweeper__/graphics/buried-tile.png' },
                { icon = entity.icon, size = entity.icon_size },
            },
            localised_name = {'', {'entity-name.' .. entity.name}, ' raffle evo: ', tostring(evo)},
            subgroup = 'minesweeper-evolution',
            order = entity.name .. string.format('-%03d', evo)
        },
    })
end

for _, spawner in pairs(data.raw['unit-spawner']) do
    --- Spawn enemies when a nest dies
    -- Trigger by control script (to feed evo value into it)
    spawner.dying_trigger_effect = {
        type = 'script',
        effect_id = Const.UNIT_SPAWNER_ID,
    }
    -- Create lookup table for evo values
    for evo, effects in pairs(get_evolution_dictionary(spawner)) do
        create_evolution_corpse(spawner, evo, effects)
    end
end

local function get_nest_probabilities()
    local effects = {}
    local count = table_size(data.raw['unit-spawner'])

    for name in pairs(data.raw['unit-spawner']) do
        effects[#effects+1] = {
            type = 'create-entity',
            entity_name = name,
            probability = 1 / count,
            as_enemy = true,
            ignore_no_enemies_mode = false,
            find_non_colliding_position = true,
        }
    end

    return table.unpack(effects)
end

data:extend({
    {
        type = 'corpse',
        name = 'minesweeper-buried-nest',
        time_before_removed = 1,
        created_effect = {
            type = 'direct',
            action_delivery = {
                type = 'instant',
                source_effects = {
                    -- iron-chest-explosion (metallic effect for tile)
                    {
                        type = 'create-entity',
                        entity_name = 'iron-chest-explosion',
                        offsets = { { -0.5, -0.5 }, { -0.5, 0.5 }, { 0.5, -0.5 }, { 0.5, 0.5 } },
                    },
                    -- steel-chest-explosion (metallic effect for tile)
                    {
                        type = 'create-entity',
                        entity_name = 'steel-chest-explosion',
                        offsets = { { -2.5, 0 }, { 2.5, 0 }, { 0, -2.5 }, { 0, 2.5 } },
                    },
                    {
                        type = 'create-explosion',
                        entity_name = 'medium-explosion',
                    },
                    get_nest_probabilities()
                },
            },
        },
        icon = '__mine-sweeper__/graphics/buried-nest.png',
        localised_name = {'entity-name.buried-nest'},
        subgroup = 'minesweeper-effects',
    },
})

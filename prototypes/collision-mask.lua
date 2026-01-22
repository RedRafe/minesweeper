local CMU = require '__core__.lualib.collision-mask-util'

local name_blacklist = {
    --['crash-site-spaceship'] = true,
}

local function add_immunity(entity, name)
    if not entity.resistances then
        entity.resistances = {}
        entity.hide_resistances = true
    end

    for _, res in pairs(entity.resistances) do
        if res.type == name then
            res.percent = 100
            return
        end
    end

    table.insert(entity.resistances, { type = name, percent = 100 })
end

local function update_entities_mask(entities)
    for _, entity in pairs(entities) do
        if name_blacklist[entity.name] then
            goto continue
        end
        if string.match(entity.name, 'crash%-site') then
            add_immunity(entity, 'explosion')
            goto continue
        end

        for _, flag in pairs(entity.flags or {}) do
            if flag == 'player-creation' then
                local mask = CMU.get_mask(entity)
                if mask.layers.car then
                    break
                end
                entity.collision_mask = mask
                mask.layers.minesweeper = true
                break
            end
        end

        ::continue::
    end
end

update_entities_mask(CMU.collect_prototypes_with_layer('object'))
update_entities_mask(CMU.collect_prototypes_with_layer('is_object'))

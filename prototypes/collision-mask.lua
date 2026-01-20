local CMU = require '__core__.lualib.collision-mask-util'

local name_blacklist = {
    ['cargo-pod-container'] = true,
    ['space-platform-hub'] = true,
}

local function update_entities_mask(entities)
    for _, entity in pairs(entities) do
        if name_blacklist[entity.name] then
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

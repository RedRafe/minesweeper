---------------------------------------------------------
-- Remove existing autoplace settings and collect resource names
---------------------------------------------------------

local frequencies = {
    sand  = {},
    grass = {},
}

local richness = {}

local switch_ore = {
    ['iron-ore']    = { frequency = 15, group = 'grass' },
    ['copper-ore']  = { frequency =  9, group = 'sand'  },
    ['coal']        = { frequency =  6, group = 'grass' },
    ['stone']       = { frequency =  4, group = 'sand'  },
    ['crude-oil']   = { frequency =  1, group = 'grass' },
    ['uranium-ore'] = { frequency =  1, group = 'sand'  },

    default         = { frequency =  1 },
}

local function choose_fallback_group()
    if #frequencies.grass < #frequencies.sand then
        return frequencies.grass
    else
        return frequencies.sand
    end
end

local function get_autoplace_control(resource_name)

end

local mgs = data.raw.planet.nauvis.map_gen_settings
local entity_settings = mgs.autoplace_settings.entity.settings
local autoplace_controls = data.raw['autoplace-control']

for name, proto in pairs(data.raw.resource) do
    if entity_settings[name] then
        -- Remove resource from map gen settings
        entity_settings[name] = nil
        mgs.autoplace_controls[name] = nil

        -- Hide autoplace
        local autoplace = proto.autoplace
        if autoplace and autoplace.control then
            autoplace_controls[autoplace.control].hidden = true
        else
            autoplace_controls[name].hidden = true
        end
        
        -- Get resource config
        local cfg = switch_ore[name] or switch_ore.default
        local group = cfg.group and frequencies[cfg.group] or choose_fallback_group()

        -- Build weighted array
        for i = 1, cfg.frequency do
            group[#group + 1] = name
        end
    end

    richness[name] = proto.normal or 0
end

mgs.autoplace_controls['enemy-base'] = nil

data.raw['mod-data'].minesweeper.data.richness = richness
data.raw['mod-data'].minesweeper.data.frequencies = frequencies

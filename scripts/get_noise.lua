local simplex_noise = require 'scripts.simplex_noise'.d2

local noises = {
    ['smol_areas'] = {
        { modifier = 0.010, weight = 1.00 },
        { modifier = 0.100, weight = 0.02 },
        { modifier = 0.100, weight = 0.03 },
    },
    ['cave_rivers'] = {
        { modifier = 0.005, weight = 1.00 },
        { modifier = 0.010, weight = 0.25 },
        { modifier = 0.050, weight = 0.01 },
    },
}

--returns a float number between -1 and 1
local function get_noise(name, pos, seed)
    local noise = 0
    local d = 0
    for i = 1, #noises[name] do
        local mod = noises[name]
        noise = noise + simplex_noise(pos.x * mod[i].modifier, pos.y * mod[i].modifier, seed) * mod[i].weight
        d = d + mod[i].weight
        seed = seed + 10000
    end
    noise = noise / d
    return noise
end

return get_noise

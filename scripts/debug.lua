local Const = require 'scripts.constants'

local Public = {}

local ADJ = Const.ADJ
local TILE_SCALE = Const.TILE_SCALE
local GREEN = { 0, 255, 0, 0.05 }
local RED = { 255, 0, 0, 0.05 }
local BLACK = { 0, 0, 0 }
local r_rect = rendering.draw_rectangle
local r_text = rendering.draw_text

local renders = {}
local query = {}

Public.register_query = function(tbl)
    for k, v in pairs(tbl) do
        query[k] = v
    end
end

Public.on_init = function()
    storage.debug = {
        renders = renders
    }
end

Public.on_load = function()
    renders = storage.debug.renders
end

-- Draw debug info for one tile
---@param surface LuaSurface
---@param ex number
---@param ey number
---@param offset table<number, number>
---@param player_renders table<LuaRenderingObject>
---@param text string
---@param status boolean
local function r_couple(surface, ex, ey, offset, size, player_renders, text, status)
    player_renders[#player_renders + 1] = r_rect {
        color = status and GREEN or RED,
        left_top = { TILE_SCALE * ex + offset[1], TILE_SCALE * ey + offset[2] },
        right_bottom = { TILE_SCALE * ex + size + offset[1], TILE_SCALE * ey + size + offset[2] },
        filled = true,
        surface = surface,
    }
    if text then
        player_renders[#player_renders + 1] = r_text {
            color = BLACK,
            text = text,
            target = { TILE_SCALE * ex + offset[1]+ 0.4, TILE_SCALE * ey + offset[2] + 0.2 },
            surface = surface,
        }
    end
end

-- Display tile debug info
---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
local function display_advanced(surface, ex, ey, player_index)
    local rds = renders[player_index] or {}
    local o = TILE_SCALE / 2
    r_couple(surface, ex, ey, { 0, 0 }, TILE_SCALE / 2, rds, 'r', query.is_revealed(ex, ey))
    r_couple(surface, ex, ey, { o, 0 }, TILE_SCALE / 2, rds, 'f', query.is_flagged(ex, ey))
    r_couple(surface, ex, ey, { 0, o }, TILE_SCALE / 2, rds, 'm', query.has_mine(ex, ey))
    r_couple(surface, ex, ey, { o, o }, TILE_SCALE / 2, rds, 'e', query.is_exploded(ex, ey))
    renders[player_index] = rds
end

---@param surface LuaSurface
---@param x number
---@param y number
---@param player_index number
local function display_simple(surface, ex, ey, player_index)
    local rds = renders[player_index] or {}
    r_couple(surface, ex, ey, { 0, 0 }, TILE_SCALE, rds, nil, not query.has_mine(ex, ey))
    renders[player_index] = rds
end

Public.destroy_renders = function(player_index)
    for _, r in pairs(renders[player_index] or {}) do
        r.destroy()
    end
    renders[player_index] = {}
end

-- Show 8 surrounding tiles around player
---@param surface LuaSurface
---@param ex number
---@param ey number
---@param player_index number
Public.show_player_surroundings = function(surface, ex, ey, player_index)
    local ps = settings.get_player_settings(player_index)
    local display
    if ps['minesweeper-debug-area-advanced'].value then
        display = display_advanced
    elseif ps['minesweeper-debug-area-simple'].value then
        display = display_simple
    end

    if display then
        for _, off in pairs(ADJ) do
            display(surface, ex + off[1], ey + off[2], player_index)
        end
    end
end

Public.add_commands = function()
    commands.add_command('minesweeper-debug', 'Toggle DEBUG mode ON/OFF [Admin only]', function(event)
        local player = game.get_player(event.player_index)
        if not player.admin then
            return player.print('[Minesweeper] selected command is Admin only')
        end

        storage._DEBUG = not storage._DEBUG
        player.print('Minesweeper DEBUG mode: '..(storage._DEBUG and 'ON' or 'OFF'))
    end)

    commands.add_command('minesweeper-solve', 'Toggle SOLVE mode ON/OFF [Admin only]', function(event)
    local player = game.get_player(event.player_index)
        if not player.admin then
            return player.print('[Minesweeper] selected command is Admin only')
        end

        storage._SOLVE = not storage._SOLVE
        player.print('Minesweeper SOLVE mode: '..(storage._SOLVE and 'ON' or 'OFF'))
    end)
end

return Public
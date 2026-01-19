--[[
    Note to self:
    - item-with-label = dummy-item to signal when player is doing something related to our logic
    - shortcut        = shortcut button that places the dummy item in player's cursor, can be linked to keybind
    - custom-input    = (w/ item_to_spawn) keybind to spawn the dummy-item declared
    - custom-input    = (w/ linked_game_control) the event name we react to when player uses the linked_game_control
]]

local Const = require 'scripts.constants'
local ARTY = table.deepcopy(data.raw.capsule['artillery-targeting-remote'])

data:extend {
    -- Dummy item
    {
        type = 'item-with-label',
        name = Const.TOOL_NAME,
        icon = '__minesweeper__/graphics/minesweeper-unknown-64.png',
        icon_size = 64,
        stack_size = 1,
        flags = { 'not-stackable', 'only-in-cursor', 'spawnable' },
        draw_label_for_cursor_render = true,
        order = Const.TOOL_NAME,
        subgroup = 'spawnables',
        inventory_move_sound = ARTY.inventory_move_sound,
        pick_sound = ARTY.pick_sound,
        drop_sound = ARTY.drop_sound,
        custom_tooltip_fields = {
            { order = 1, name = {'gui.instruction-when-in-cursor'}, value = '', show_in_tooltip = true },
            { order = 2, name = '', value = {'msw.instruction-reveal'}, show_in_tooltip = true },
            { order = 3, name = '', value = {'msw.instruction-flag'},   show_in_tooltip = true },
        }
    },
    -- Shortcut button linked to keybind
    {
        type = 'shortcut',
        name = Const.KEYBIND_NAME,
        order = Const.KEYBIND_NAME,
        action = 'spawn-item',
        item_to_spawn = Const.TOOL_NAME,
        associated_control_input = Const.KEYBIND_NAME,
        icon = '__minesweeper__/graphics/minesweeper-flag-64.png',
        icon_size = 64,
        small_icon = '__minesweeper__/graphics/minesweeper-flag-64.png',
        small_icon_size = 64,
    },
    -- Keybind
    {
        type = 'custom-input',
        name = Const.KEYBIND_NAME,
        key_sequence = 'SHIFT + M',
        alternative_key_sequence = '',
        action = 'spawn-item',
        item_to_spawn = Const.TOOL_NAME,
    },
    -- Event: reveal
    {
        type = 'custom-input',
        name = Const.CI_REVEAL_TILE,
        key_sequence = '',
        linked_game_control = 'build',
    },
    -- Event: flag
    {
        type = 'custom-input',
        name = Const.CI_FLAG_TILE,
        key_sequence = '',
        linked_game_control = 'mine',
    },
}

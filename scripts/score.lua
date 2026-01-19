local Gui = require 'scripts.gui'
local Const = require 'scripts.constants'

local Score = {}

---------------------------------------------------------
-- CONFIG / ENUMS
---------------------------------------------------------

local POINTS        = Const.POINTS
local TILE_EXPLODED = Const.TILE_EXPLODED
local TILE_FLAGGED  = Const.TILE_FLAGGED
local TILE_HIDDEN   = Const.TILE_HIDDEN
local TILE_MINE     = Const.TILE_MINE

local top_button_name = Gui.uid_name('button')
local top_frame_name  = Gui.uid_name('frame')
local left_frame_name = Gui.uid_name('leaderboard')
local sort_button_tag = Gui.uid_name('sort')

local STATS = {
    global = {
        { name = 'tiles_revealed', sprite = 'entity.minesweeper-tile',     tooltip = { 'msw.tiles_revealed' } },
        { name = 'mines_marked',   sprite = 'entity.minesweeper-flag',     tooltip = { 'msw.mines_marked' } },
        { name = 'mines_exploded', sprite = 'entity.minesweeper-exploded', tooltip = { 'msw.mines_exploded' } },
    },
    player = {
        { name = 'tiles_revealed', sprite = 'entity.minesweeper-tile',     tooltip = { 'msw.tiles_revealed' } },
        { name = 'mines_marked',   sprite = 'entity.minesweeper-flag',     tooltip = { 'msw.mines_marked' } },
        { name = 'mines_exploded', sprite = 'entity.minesweeper-exploded', tooltip = { 'msw.mines_exploded' } },
        { name = 'score',          sprite = 'entity.minesweeper-trophy',   tooltip = { 'msw.score' } },
    }
}

---------------------------------------------------------
-- STATE
---------------------------------------------------------

local global_stats = {
    tiles_revealed = 0,
    mines_marked   = 0,
    mines_exploded = 0,
}

--[[
    Player stats:
    - tiles_revealed
    - mines_marked
    - mines_exploded
    - score
]]
local player_stats = {}    -- [player_index] = stats
local player_settings = {} -- [player_index] = { advanced = true, key = 'score', descending = true }

---------------------------------------------------------
-- STORAGE
---------------------------------------------------------

local function init_storage()
    storage.score = {
        global_stats = global_stats,
        player_stats = player_stats,
        player_settings = {}
    }
end

local function load_storage()
    local tbl = storage.score
    global_stats = tbl.global_stats
    player_stats = tbl.player_stats
    player_settings = tbl.player_settings
end

---------------------------------------------------------
-- STYLE
---------------------------------------------------------

local function sort_button(parent, params, settings)
    local flow = parent.add { type = 'flow', direction = 'horizontal' }
    Gui.set_style(flow, { vertical_align = 'center', horizontal_spacing = 4 })

    local button = flow.add {
        type = 'button',
        style = 'sort_button',
        caption = params.state and '▼' or '▲',
        tags = { [Gui.tag] = sort_button_tag, key = params.key, descending = params.state },
        toggled = (params.key == settings.key)
    }

    local label = flow.add {
        type = 'label',
        style = 'minesweeper_label',
        caption = params.caption,
        tooltip = params.tooltip,
        tags = { [Gui.tag] = sort_button_tag }
    }

    return flow
end

---------------------------------------------------------
-- UTILS
---------------------------------------------------------

local function get_player_stats(player_index)
    local ps = player_stats[player_index]
    if ps then
        return ps
    end
    ps = {
        tiles_revealed = 0,
        mines_marked   = 0,
        mines_exploded = 0,
        score          = 0,
    }
    player_stats[player_index] = ps
    return ps
end

local function get_player_settings(player_index)
    local ps = player_settings[player_index]
    if ps then
        return ps
    end
    ps = {
        advanced = false,
        key = 'score',
        descending = true,
    }
    player_settings[player_index] = ps
    return ps
end

---@param element LuaGuiElement
local function get_previous_state(element)
    local state = { true, true, true, true, true }

    local children = element.children
    if #children > 0 then
        local grid = children[1]
        local grid_children = grid.children
        local max_cols = grid.column_count - 1

        for i = 1, max_cols do
            local sort_cell = grid_children[i + 1]
            if sort_cell then
                local button = sort_cell.children[1]
                if button then
                    state[i] = button.tags.descending
                end
            end
        end
    end

    return state
end

local function ascending(key)
    return function(a, b) return a[key] < b[key] end
end

local function descending(key)
    return function(a, b) return a[key] > b[key] end
end

local function get_scoreboard_data()
    local scoreboard = {
        { name = 'George', score = 27, tiles_revealed = 12000, mines_marked = 24, mines_exploded = 27, color = { 255, 255, 255 } },
        { name = 'Alice',  score = 45, tiles_revealed = 15000, mines_marked = 30, mines_exploded =  2, color = { 255,   0,   0 } },
        { name = 'Bob',    score = 33, tiles_revealed = 13000, mines_marked = 25, mines_exploded =  5, color = {   0, 255,   0 } },
        { name = 'Carol',  score = 50, tiles_revealed = 16000, mines_marked = 35, mines_exploded =  1, color = {   0,   0, 255 } },
        { name = 'Dave',   score = 22, tiles_revealed = 12500, mines_marked = 20, mines_exploded = 10, color = { 255, 255,   0 } },
        { name = 'Eve',    score = 60, tiles_revealed = 17000, mines_marked = 40, mines_exploded =  0, color = { 255,   0, 255 } },
        { name = 'Frank',  score = 19, tiles_revealed = 11000, mines_marked = 15, mines_exploded = 15, color = {   0, 255, 255 } },
        { name = 'Grace',  score = 40, tiles_revealed = 14000, mines_marked = 28, mines_exploded =  3, color = { 128, 128, 128 } },
        { name = 'Hank',   score = 55, tiles_revealed = 16500, mines_marked = 38, mines_exploded =  2, color = {  75,   0, 130 } },
        { name = 'Ivy',    score = 28, tiles_revealed = 12800, mines_marked = 22, mines_exploded =  8, color = { 255, 165,   0 } },
        { name = 'Jack',   score = 48, tiles_revealed = 15500, mines_marked = 33, mines_exploded =  4, color = {   0, 128, 128 } },
        { name = 'Kara',   score = 35, tiles_revealed = 14500, mines_marked = 26, mines_exploded =  6, color = { 255, 192, 203 } },
        { name = 'Leo',    score = 42, tiles_revealed = 15200, mines_marked = 29, mines_exploded =  2, color = { 173, 216, 230 } },
        { name = 'Mia',    score = 25, tiles_revealed = 12050, mines_marked = 19, mines_exploded = 12, color = { 240, 230, 140 } },
        { name = 'Nina',   score = 52, tiles_revealed = 16200, mines_marked = 36, mines_exploded =  1, color = { 255, 140,   0 } },
        { name = 'Oscar',  score = 37, tiles_revealed = 14800, mines_marked = 27, mines_exploded =  7, color = {   0, 100,   0 } },
        { name = 'Paul',   score = 31, tiles_revealed = 13800, mines_marked = 23, mines_exploded =  9, color = { 139,  69,  19 } },
        { name = 'Quinn',  score = 46, tiles_revealed = 15800, mines_marked = 32, mines_exploded =  3, color = {  75,   0, 130 } },
        { name = 'Rachel', score = 29, tiles_revealed = 12400, mines_marked = 20, mines_exploded = 11, color = { 255, 105, 180 } },
        { name = 'Sam',    score = 54, tiles_revealed = 16800, mines_marked = 37, mines_exploded =  2, color = {   0,   0,   0 } },
    }

    for player_index, ps in pairs(player_stats) do
        local player = game.get_player(player_index)
        table.insert(scoreboard, {
            name = player.name,
            color = player.color,
            tiles_revealed = ps.tiles_revealed,
            mines_marked = ps.mines_marked,
            mines_exploded = ps.mines_exploded,
            score = ps.score,
        })
    end

    return scoreboard
end

local function update_top_gui(player)
    local frame = Gui.get_top_element(player, top_frame_name)
    if not (frame and frame.valid and frame.visible) then
        return
    end

    do -- global stats
        local flow = frame.global
        for key, value in pairs(global_stats) do
            flow[key].number = value
        end
    end

    do -- player stats
        local flow = frame.player
        for key, value in pairs(get_player_stats(player.index)) do
            flow[key].number = value
        end
    end
end

local function draw_top_gui(player)
    local flow = Gui.get_top_flow(player)
    local button = flow.add {
        type = 'sprite-button',
        name = top_button_name,
        sprite = 'entity.minesweeper-smile',
        tooltip = {'msw.main_button_tooltip'},
    }
    local frame = flow.add {
        type = 'frame',
        name = top_frame_name,
        style = 'subheader_frame',
        direction = 'horizontal',
    }
    
    frame.visible = false
	Gui.set_style(frame, { natural_height = 40, height = 40, padding = 0 })
    Gui.set_data(button, frame)

    for group_name, group in pairs(STATS) do
        local flow = frame.add { type = 'flow', direction = 'horizontal', name = group_name }
        for _, stat in pairs(group) do
            flow.add { type = 'sprite-button', sprite = stat.sprite, name = stat.name, tooltip = stat.tooltip }
        end
    end
    frame.player.visible = false
end

local function update_left_gui(player)
    local frame = Gui.get_left_element(player, left_frame_name)
    if not frame.visible then
        return
    end

    local data     = get_scoreboard_data()
    local window   = Gui.get_data(frame)
    local state    = get_previous_state(window)
    local settings = get_player_settings(player.index)
    local advanced = settings.advanced

    ----------------------------------------------------------------------
    -- Build new scoreboard
    ----------------------------------------------------------------------
    window.clear()

    local scoreboard = window.add { type = 'table', style = 'scoreboard_table', column_count = advanced and 6 or 3 }

    -- Header row ---------------------------------------------------------
    scoreboard.add { type = 'label', style = 'minesweeper_label', caption = '#' }

    sort_button(scoreboard, { caption = 'Name',  key = 'name',  state = state[1] }, settings)
    sort_button(scoreboard, { caption = 'Score', key = 'score', state = state[2] }, settings)

    if advanced then
        sort_button(scoreboard, { caption = '[img=entity.minesweeper-tile]',     key = 'tiles_revealed', tooltip = {'msw.tiles_revealed'}, state = state[3] }, settings)
        sort_button(scoreboard, { caption = '[img=entity.minesweeper-flag]',     key = 'mines_marked',   tooltip = {'msw.mines_marked'},   state = state[4] }, settings)
        sort_button(scoreboard, { caption = '[img=entity.minesweeper-exploded]', key = 'mines_exploded', tooltip = {'msw.mines_exploded'}, state = state[5] }, settings)
    end

    -- Body rows ---------------------------------------------------------
    table.sort(data, settings.descending and descending(settings.key) or ascending(settings.key))

    for i, entry in pairs(data) do
        -- Rank column (medals for top 3)
        local rank_label = scoreboard.add { type = 'label', caption = i, style = 'minesweeper_label' }
        if i < 4 then
            rank_label.caption = ('[img=entity.minesweeper-%d]'):format(i)
        end

        -- Name column
        local name_label = scoreboard.add { type = 'label', caption = entry.name, style = 'semibold_label' }
        Gui.set_style(name_label, { font_color = entry.color })

        -- Score column
        scoreboard.add { type = 'label', caption = entry.score, tooltip = entry.score }

        if advanced then
            scoreboard.add { type = 'label', caption = entry.tiles_revealed, tooltip = entry.tiles_revealed }
            scoreboard.add { type = 'label', caption = entry.mines_marked,   tooltip = entry.mines_marked }
            scoreboard.add { type = 'label', caption = entry.mines_exploded, tooltip = entry.mines_exploded }
        end
    end
end

local function draw_left_gui(player)
    local flow = Gui.get_left_flow(player)
    local frame = flow.add {
        type = 'frame',
        name = left_frame_name,
        use_header_filler = false,
    }
    frame.visible = false

    local window = frame
        .add { type = 'frame', style = 'inside_shallow_frame' }
        .add { type = 'scroll-pane', style = 'naked_scroll_pane', horizontal_scroll_policy = 'never', vertical_scroll_policy = 'auto' }
    Gui.set_style(window, { maximal_height = 320, padding = 4 })

    Gui.set_data(frame, window)
end

local function init_player(player)
    get_player_stats(player.index)
    get_player_settings(player.index)

    draw_top_gui(player)
    update_top_gui(player)

    draw_left_gui(player)
    update_left_gui(player)
end

---------------------------------------------------------
-- EVENT HANDLERS
---------------------------------------------------------

local function on_player_created(event)
    init_player(game.get_player(event.player_index))
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    update_top_gui(player)
    update_left_gui(player)
end

---@param event
---@field tick number
---@field name defines.events.on_tile_revealed
---@field player_index number
---@field surface_index number
---@field tiles table<{ position: MapPosition, type: number }>
local function on_tile_revealed(event)
    -- Player stats
    if event.player_index then
        local ps = get_player_stats(event.player_index)
        ps.tiles_revealed = ps.tiles_revealed + #event.tiles
        for _, tile in pairs(event.tiles) do
            ps.score = ps.score + (POINTS[tile.type] or 0)
            if tile.type == TILE_FLAGGED then
                ps.mines_marked = ps.mines_marked + 1
            elseif tile.type == TILE_EXPLODED then
                ps.mines_exploded = ps.mines_exploded + 1
            end
        end
    end

    -- Global stats
    global_stats.tiles_revealed = global_stats.tiles_revealed + #event.tiles
    for _, tile in pairs(event.tiles) do
        if tile.type == TILE_FLAGGED then
            global_stats.mines_marked = global_stats.mines_marked + 1
        elseif tile.type == TILE_EXPLODED then
            global_stats.mines_exploded = global_stats.mines_exploded + 1
        end
    end

    for _, p in pairs(game.connected_players) do
        update_top_gui(p)
    end
end

Gui.on_click(top_button_name, function(event)
    if event.shift then
        -- Update left gui
        local leaderboard = Gui.get_left_element(event.player, left_frame_name)

        if event.button == defines.mouse_button_type.left then
            leaderboard.visible = not leaderboard.visible
        elseif event.button == defines.mouse_button_type.right then
            local settings = get_player_settings(event.player_index)
            settings.advanced = not settings.advanced
        end

        update_left_gui(event.player)
    else
        -- Update top gui
        local frame = Gui.get_data(event.element)

        if event.button == defines.mouse_button_type.left then
            frame.visible = not frame.visible
        elseif event.button == defines.mouse_button_type.right then
            frame.global.visible = not frame.global.visible
            frame.player.visible = not frame.player.visible
        end

        local sprite = 'smile'
        local suffix = ''

        if frame.visible then
            if frame.global.visible then
                sprite = 'surprise'
                suffix = '_global'
            else
                sprite = 'success'
                suffix = '_player'
            end
        end

        event.element.sprite = 'entity.minesweeper-' .. sprite
        event.element.tooltip = { 'msw.main_button_tooltip' .. suffix }

        update_top_gui(event.player)
    end
end)

Gui.on_click(sort_button_tag, function(event)
    local button = event.element
    if button.type ~= 'button' then
        button = button.parent.children[1]
    end

    local old_tags = button.tags
    local settings = get_player_settings(event.player_index)

    if settings.key == old_tags.key then
        -- Same key, change sort order
        button.tags = {
            [Gui.tag]  = old_tags[Gui.tag],
            descending = not old_tags.descending,
            key        = old_tags.key,
        }
    else
        -- Different key, change key (but maintain its own sorting)
        settings.key = old_tags.key
    end

    settings.descending = button.tags.descending
    update_left_gui(event.player)
end)

---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

Score.on_init = function()
    init_storage()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end

Score.on_load = load_storage

Score.events = {
    [defines.events.on_player_created]     = on_player_created,
    [defines.events.on_tile_revealed]      = on_tile_revealed,
    [defines.events.on_player_joined_game] = on_player_joined_game,
}

return Score

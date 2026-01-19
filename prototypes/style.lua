local styles = data.raw['gui-style'].default

styles.scoreboard_table = {
    type = 'table_style',
    parent = 'finished_game_table',
    column_alignments = {
        { column = 1, alignment = 'middle-center' },
        { column = 2, alignment = 'middle-left' },
        { column = 3, alignment = 'middle-center' },
        { column = 4, alignment = 'middle-center' },
        { column = 5, alignment = 'middle-center' },
        { column = 6, alignment = 'middle-center' },
    },
}

styles.minesweeper_label = {
    type = 'label_style',
    parent = 'label',
    font = 'minesweeper',
}

styles.sort_button = {
    type = 'button_style',
    parent = 'button',
    padding = 0,
    default_graphical_set = {},
    clicked_graphical_set = {},
    hovered_graphical_set = {},
    selected_graphical_set = {},
    selected_hovered_graphical_set = {},
    selected_clicked_graphical_set = {},
    clicked_vertical_offset = 0,
    default_font_color = { 255, 255, 255 },
    hovered_font_color = { 255, 230, 192 },
    selected_hovered_font_color = { 255, 230, 192 },
    clicked_font_color = { 226, 156, 57 },
    selected_font_color = { 226, 156, 57 },
    selected_clicked_font_color = { 226, 156, 57 },
    font = 'default-tiny-bold',
    size = 10,
}

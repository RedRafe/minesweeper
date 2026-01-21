local Handler = require '__core__.lualib.event_handler'

Handler.add_libraries{
    require 'scripts.gui',
    require 'scripts.debug',
    require 'scripts.minesweeper',
    require 'scripts.score',
}

local Mini_games = require 'expcore.Mini_games'
local Commands = require 'expcore.commands'

Commands.new_command('stop', 'Command to stop a mini_game.')
:register(function(_, _)
    if Mini_games.get_current_game() then Mini_games.stop_game() end
end)

Commands.new_command('start', 'Command to start a mini_game.')
:add_param('name_of_game', false)
:add_param('option1', true)
:add_param('option2', true)
:add_param('option3', true)
:add_param('option4', true)
:register(function(_, name_of_game, option1, option2, option3, option4, _)
    local _, rtn = xpcall(Mini_games.start_game, Commands.error, name_of_game, {option1, option2, option3, option4})
    return rtn
end)
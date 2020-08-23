--[[-- Commands Module - Connect
    - Adds a commands that allows you to request a player move to another server
    @commands Connect
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_role_parse'

--- Prompt the player to join a different server
local function connect(player, address, default_name)
    local name = global.servers[address] and global.servers[address].name or default_name
    player.connect_to_server({
        address = address,
        name = '\n[color=red]'..name..'[/color]\n',
        description = 'You have been asked to switch to a different server, please press the connect button below to do so.'
    })
end

--- Connect a player to a different server
-- @command connect
-- @tparam string address the address of the server to connect the player to
-- @tparam[opt] LuaPlayer player the player to connect to a new server
Commands.new_command('connect', 'Connect a player to another server, option to send all')
:add_param('address')
:add_param('player', true, 'player-role')
:set_flag('admin-only')
:add_alias('server', 'send-to')
:register(function(_, address, player)
    local default_name = 'Factorio Olympic Server'
    if global.servers[address] then
        default_name = address
        address = global.servers[address]
        if type(address) == 'table' then address = address[1] end
    end
    if player then
        connect(player, address, default_name)
    else
        for _, next_player in ipairs(game.connected_players) do
            connect(next_player, address, default_name)
        end
    end
end)

--- Connect to the lobby server
-- @command lobby
Commands.new_command('lobby', 'Connect back to the lobby server')
:add_alias('hub')
:register(function(player)
    if global.servers["lobby"] then
        player.connect_to_server{
            address = global.servers["lobby"],
            name = '\n[font=heading-1][color=red]Factorio Olympics: '.."lobby"..'[/color][/font]\n',
            description = 'The game is over you must go back to the lobby.'
        }
    else
        return Commands.error('The address of the lobby server is currently unknown, please leave the game and join via the server browser.')
    end
end)
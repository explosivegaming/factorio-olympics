--[[-- Commands Module - Connect
    - Adds a commands that allows you to request a player move to another server
    @commands Connect
]]

local Event = require 'utils.event' --- @dep utils.event
local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_role_parse'

local servers
Event.on_load(function()
    servers = global.servers or {}
end)

--- Prompt the player to join a different server
local function connect(player, address, default_name)
    local name = servers[address] and servers[address].name or default_name
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
    if servers[address] then
        default_name = address
        address = servers[address]
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
    local address = servers.lobby
    if address then
        connect(player, address, 'Lobby')
    else
        return Commands.error('The address of the lobby server is currently unknown, please leave the game and join via the server browser.')
    end
end)
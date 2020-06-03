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
local function connect(player, address)
    local name = servers[address] and servers[address].name or 'Factorio Olympic Server'
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
    if servers[address] then address = servers[address] end
    if player then
        connect(player, address)
    else
        for _, next_player in ipairs(game.connected_players) do
            connect(next_player, address)
        end
    end
end)
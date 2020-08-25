
local Event = require 'utils.event' --- @dep utils.event
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Gui = require 'expcore.gui' --- @dep expcore.gui

local function update_gui(event)
    local player = game.players[event.player_index]
    Gui.update_top_flow(player)
    Gui.update_left_flow(player)
end

Event.add(Roles.events.on_role_assigned, update_gui)
Event.add(Roles.events.on_role_unassigned, update_gui)
Event.add(defines.events.on_player_joined_game, update_gui)
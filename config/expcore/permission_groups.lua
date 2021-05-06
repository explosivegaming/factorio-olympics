--- Use this file to add new permission groups to the game;
-- start with Permission_Groups.new_group('name');
-- then use either :allow_all() or :disallow_all() to set the default for non specified actions;
-- then use :allow{} and :disallow{} to specify certain actions to allow/disallow
-- @config Permission-Groups

--local Event = require 'utils.event' -- @dep utils.event
--local Game = require 'utils.game' -- @dep utils.game
local Permission_Groups = require 'expcore.permission_groups' --- @dep expcore.permission_groups

Permission_Groups.new_group('Admin')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter'
}

Permission_Groups.new_group('InGame')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter',
    'admin_action' -- in game
}

Permission_Groups.new_group('InGameProtected')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter',
    'admin_action', -- in game
    'activate_copy', -- in game protected
    'activate_cut',
    'activate_paste',
    'begin_mining',
    'begin_mining_terrain',
    'build',
    'build_terrain',
    'copy',
    'deconstruct',
    'drop_item',
    'remove_cables',
    'rotate_entity',
    'setup_blueprint',
    'undo',
    'upgrade'
}

Permission_Groups.new_group('Lobby')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter',
    'admin_action', -- in game
    'activate_copy', -- lobby
    'activate_cut',
    'activate_paste',
    'begin_mining',
    'begin_mining_terrain',
    'build',
    'build_terrain',
    'copy',
    'craft',
    'deconstruct',
    'drop_item',
    'open_achievements_gui',
    'open_blueprint_library_gui',
    'open_bonus_gui',
    'open_character_gui',
    'open_logistic_gui',
    'open_production_gui',
    'open_technology_gui',
    'open_trains_gui',
    'remove_cables',
    'rotate_entity',
    'setup_blueprint',
    'undo',
    'upgrade'
}

Permission_Groups.new_group('Restricted')
:disallow_all()
:allow('write_to_console')

--[[ These events are used until a role system is added to make it easier for our admins

local trusted_time = 60*60*60*10 -- 10 hour
local standard_time = 60*60*60*3 -- 3 hour
local function assign_group(player)
    local current_group_name = player.permission_group and player.permission_group.name or 'None'
    if player.admin then
        Permission_Groups.set_player_group(player,'Admin')
    elseif player.online_time > trusted_time or current_group_name == 'Trusted' then
        Permission_Groups.set_player_group(player,'Trusted')
    elseif player.online_time > standard_time or current_group_name == 'Standard' then
        Permission_Groups.set_player_group(player,'Standard')
    else
        Permission_Groups.set_player_group(player,'Guest')
    end
end

Event.add(defines.events.on_player_joined_game,function(event)
    local player = Game.get_player_by_index(event.player_index)
    assign_group(player)
end)

Event.add(defines.events.on_player_promoted,function(event)
    local player = Game.get_player_by_index(event.player_index)
    assign_group(player)
end)

Event.add(defines.events.on_player_demoted,function(event)
    local player = Game.get_player_by_index(event.player_index)
    assign_group(player)
end)

local check_interval = 60*60*15 -- 15 minutes
Event.on_nth_tick(check_interval,function(event)
    for _,player in pairs(game.connected_players) do
        assign_group(player)
    end
end)]]

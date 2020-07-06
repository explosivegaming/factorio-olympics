--- This is the main config file for the role system; file includes defines for roles and role flags and default values
-- @config Roles

local Roles = require 'expcore.roles' --- @dep expcore.roles

--- Role flags that will run when a player changes roles
Roles.define_flag_trigger('is_admin',function(player,state)
    player.admin = state
end)
Roles.define_flag_trigger('is_spectator',function(player,state)
    player.spectator = state
end)
Roles.define_flag_trigger('is_jail',function(player,state)
    if player.character then
        player.character.active = not state
    end
end)

--- Admin Roles
Roles.new_role('System','SYS')
:set_permission_group('Admin')
:set_flag('is_admin')
:set_flag('is_spectator')
:set_allow_all()

Roles.new_role('Organizer','Organizer')
:set_permission_group('Admin')
:set_custom_color{r=155,g=89,b=182}
:set_flag('is_admin')
:set_flag('is_spectator')
:set_parent('Developer')
:allow{
}

Roles.new_role('Developer','Dev')
:set_permission_group('Admin')
:set_custom_color{r=230,g=126,b=34}
:set_flag('is_admin')
:set_flag('is_spectator')
:set_parent('Official')
:allow{
    'command/interface',
    'command/debug',
}

Roles.new_role('Official','Official')
:set_permission_group('Admin')
:set_custom_color{r=52,g=152,b=219}
:set_flag('is_admin')
:set_flag('is_spectator')
:set_parent('Partner')
:allow{
    'command/assign-role',
    'command/unassign-role',
    'command/admin-chat',
    'command/kick',
    'command/ban',
    'command/win',
    'command/test',
    'command/hi',
    'gui/game_start',
    'gui/tightspot_speed',
    'command/stop',
    'command/clear_votes',
    'command/start',
    'command/add',
    'command/dump',
    'command/set',
    'command/connect'
}

--- Trusted Roles
Roles.new_role('Partner','Part')
:set_permission_group('Trusted')
:set_custom_color{r=241,g=196,b=15}
:set_flag('is_spectator')
:set_parent('Participant')
:allow{
}

Roles.new_role('Team Leader','Leader')
:set_permission_group('Trusted')
:set_custom_color{r=241,g=196,b=15}
:set_flag('is_spectator')
:set_parent('Participant')
:allow{
}

--- Standard User Roles
Roles.new_role('Participant','Player')
:set_permission_group('Standard')
:set_custom_color{r=24,g=172,b=188}
:set_parent('Guest')
:allow{
}

--- Guest/Default role
local default = Roles.new_role('Guest','')
:set_permission_group('Guest')
:set_custom_color{r=185,g=187,b=160}
:allow{
    'command/all_votes',
    'command/time_left',
    'command/vote',
    'command/search-help',
    'command/list-roles',
    'command/server-ups',
    'command/warp',
    'command/join-UFE',
    'command/join-UFW',
}

--- Jail role
Roles.new_role('Jail')
:set_permission_group('Restricted')
:set_custom_color{r=50,g=50,b=50}
:set_block_auto_promote(true)
:disallow(default.allowed)

--- System defaults which are required to be set
Roles.set_root('System')
Roles.set_default('Guest')

Roles.define_role_order{
    'System', -- Best to keep root at top
    'Organizer',
    'Developer',
    'Official',
    'Partner',
    'Team Leader',
    'Participant',
    'Jail',
    'Guest' -- Default must be last if you want to apply restrictions to other roles
}

Roles.override_player_roles{
    ['arty714'] = {'Organizer'},
    ['Cooldude2606'] = {'Organizer'},
    ['Drahc_pro'] = {'Organizer'},
    ['Poli'] = {'Organizer'},
    ['psihius'] = {'Organizer'},
    ['TheOrangeAngle'] = {'Organizer'},

    ['_reverend'] = {'Developer'},
    ['diffiehellman'] = {'Developer'},
    ['grilledham'] = {'Developer'},
    ['Guillaume'] = {'Developer'},
    ['happs'] = {'Developer'},
    ['Jayefuu'] = {'Developer'},
    ['MaX'] = {'Developer'},
    ['SimonFlapse'] = {'Developer'},
    ['TheKid'] = {'Developer'},
    ['tovernaar123'] = {'Developer'},
}

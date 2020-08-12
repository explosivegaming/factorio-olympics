--- This contains a list of all files that will be loaded and the order they are loaded in;
-- to stop a file from loading add "--" in front of it, remove the "--" to have the file be loaded;
-- config files should be loaded after all modules are loaded;
-- core files should be required by modules and not be present in this list;
-- @config File-Loader
return {
    --'example.file_not_loaded',
    'modules.commands.help',
    'modules.commands.roles',
    'modules.commands.debug',
    'modules.commands.interface',
    'modules.commands.admin-chat',
    'modules.commands.connect',

    --Gui
    'modules.gui.server-ups',
    'modules.gui.player-list',

    --Mini-games
    'modules.mini-games.greefer-start',
    'modules.mini-games.admin_overide',
    'modules.mini-games.Race',
    'modules.mini-games.tightspot',
    'modules.mini-games.space_race.scenario',
    'modules.mini-games.speedrun',
    'modules.mini-games.team_production.team_production',

    -- Config Files
    'config.expcore.command_auth_admin', -- commands tagged with admin_only are blocked for non admins
    'config.expcore.command_auth_roles', -- commands must be allowed via the role config
    'config.expcore.command_runtime_disable', -- allows commands to be enabled and disabled during runtime
    'config.expcore.permission_groups', -- loads some predefined permission groups
    'config.expcore.roles', -- loads some predefined roles
}
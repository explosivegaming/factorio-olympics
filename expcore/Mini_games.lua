local Token = require 'utils.token'
local Task = require 'utils.task'
local Event = require 'utils.event'
local Global = require 'utils.global'
local gen = require 'utils.map_gen.generate'

--- Expcore
local Gui = require 'expcore.gui'
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Commands = require 'expcore.commands'
require 'config.expcore.command_runtime_disable' --required to load before running the script

--- Locals
local add_DataLobby
local lobby
local require_player_list = {}
local online_player_list  = {}
local WaitingGui = require 'modules.gui.mini_game_waiting'
local LoadingGui = require 'modules.gui.mini_game_loading'
local Mini_games = {
    _prototype = {},
    mini_games = {},
    available  = {},
    events = {
        on_participant_added = script.generate_event_name(),
        on_participant_joined = script.generate_event_name(),
        on_participant_left = script.generate_event_name(),
        on_participant_removed = script.generate_event_name()
    }
}

--- Globals
local participants = {}
local primitives = { state = 'Closed' }
local vars = {
    is_lobby = false,
}

gen.init{}
gen.register()

global.servers = {}
global.running_servers = {}

--[[
global.servers= {
    lobby =  "127.0.0.1:12345"
}
--]]

--- Register the global variables
Global.register({
    available_games = Mini_games.available,
    participants = participants,
    primitives = primitives,
    vars = vars,
    online_player_list = online_player_list,
    require_player_list = require_player_list,
},function(tbl)
    Mini_games.available = tbl.available_games
    participants = tbl.participants
    primitives = tbl.primitives
    vars = tbl.vars
    online_player_list = tbl.online_player_list
    require_player_list = tbl.require_player_list
end)

--- Used with xpcall
local function internal_error(error_message)
    local err = error_message:gsub('%.%.%..-/temp/currently%-playing', '')
    game.print("Their is an error please contact the admins, error: "..err)
    log(debug.traceback(error_message))
end

--- Used to debug mini game control flow
local DEBUG = false
local function dlog(...)
    if not DEBUG then return end
    log{'mini-game-log', primitives.current_game or 'None', primitives.state, table.concat({...}, ' ')}
end

--- Used to set the current state and log it
local function set_internal_state(new)
    primitives.state = new
    dlog('===== State Change =====')
end

----- Defining Mini games -----

--- Create a new instance of a mini game, the name must be unique
function Mini_games.new_game(name)
    local mini_game = {
        name          = name,
        events        = {},
        on_nth_tick   = {},
        commands      = {},
        core_events   = {},
        surface_names = {},
        options       = 0,
        surfaces      = 0
    }

    Mini_games.mini_games[name] = mini_game
    return setmetatable(mini_game, { __index = Mini_games._prototype })
end

--- Add an event handler to this mini game, these handlers will be toggled on and off automatically
function Mini_games._prototype:add_event(event_name, func)
    local handler = Token.register(func)
    self.events[#self.events+1] = {event_name, handler}
end

--- Add an on nth tick handler to this mini game, these handlers will be toggled on and off automatically
function Mini_games._prototype:add_nth_tick(tick, func)
    local handler = Token.register(func)
    self.on_nth_tick[#self.on_nth_tick+1] = {tick, handler}
end

--- Set all the core events at once, normally all four are used so this can help same some lines
function Mini_games._prototype:set_core_events(on_init, on_start, on_stop, on_close)
    self.core_events = {
        on_init  = on_init,
        on_start = on_start,
        on_stop  = on_stop,
        on_close = on_close
    }
end

--- Add an on init handler to this mini game, this first code to be called by the mini game core, use to init variables and create forces and surfaces
function Mini_games._prototype:on_init(handler)
    self.core_events.on_init = handler
end

--- Add an on start handler to this mini game, called once all participants are added and ready condition is met
function Mini_games._prototype:on_start(handler)
    self.core_events.on_start = handler
end

--- Add an on stop handler to this mini game, called to stop the game, should return the data you want to save to file
function Mini_games._prototype:on_stop(handler)
    self.core_events.on_stop = handler
end

--- Add an on close handler to this mini game, this is the last code to be called by the mini game core, use to clean up used variables and removes forces and surfaces
function Mini_games._prototype:on_close(handler)
    self.core_events.on_close = handler
end

--- Add an to the allowed number of options for this mini game, used to tell /start how many params to accept
function Mini_games._prototype:add_option(amount)
    self.options = self.options + amount
end

--- Add the surfaces that will be used by this scenario, if only one surface is given then players will be teleported at the start
function Mini_games._prototype:add_surfaces(required, ...)
    self.surfaces = self.surfaces + required
    local lookup, surfaces = {}, self.surface_names
    for _, name in ipairs(surfaces) do lookup[name] = true end
    for _, name in ipairs{...} do
        if not lookup[name] then
            lookup[name] = true
            surfaces[#surfaces+1] = name
        end
    end
end

--- Add a surface with custom map gen for this mini game, if shape is given this is for redmew map gen
function Mini_games._prototype:add_map_gen(surface_name, shape)
    self:add_surfaces(0, surface_name)
    if type(shape) == 'string' then shape = require(shape) end
    if shape then gen.add_surface(surface_name, shape) end
end

--- Add a callback to check if the mini game is ready to start, if not used game starts after init, common example is to check map gen is done
function Mini_games._prototype:set_ready_condition(callback, hide_load_gui)
    self.ready_condition = callback
    self.hide_load_gui = hide_load_gui
end

--- Add a callback to check if a player should be added as a participant, if not used participants selected randomly, callback also used to clean up its self
function Mini_games._prototype:set_participant_selector(callback, hide_wait_gui)
    self.participant_selector = callback
    self.hide_wait_gui = hide_wait_gui
end

--- Add a gui element to be used in the vote gui, this gui element will be similar to /start with the callback being used to read the values
function Mini_games._prototype:set_gui(gui_element, gui_callback)
    self.gui = gui_element
    self.gui_callback = gui_callback
end

--- Add a command that can only be used in this mini game, this will automatically enable and disable commands that are linked to this mini game
function Mini_games._prototype:add_command(command_name)
    self.commands[#self.commands + 1] = command_name
    Commands.disable(command_name)
end

----- Public Variables -----

--- Get the currently game, returns the mini game object, mostly used internally
function Mini_games.get_current_game()
    return Mini_games.mini_games[primitives.current_game]
end

--- Get the currently running game, gets the name of the current game that is running, will be nil if loading or closing
function Mini_games.get_running_game()
    if primitives.state ~= 'Starting' and primitives.state ~= 'Started' then return end
    return primitives.current_game
end

--- Get the current state of the mini game server, get the current state of the mini game system
function Mini_games.get_current_state()
    return primitives.state
end

--- Get the start time for the running game, get the start tick for the current mini game, during loading this is the time when loading started
function Mini_games.get_start_time()
    return primitives.start_tick
end

--- Get the required amount of participants needed before a game can start
function Mini_games.get_participant_requirement()
    return primitives.participant_requirement
end

----- Participants -----

--- Internal, Raise a mini game event, this is used for all participant events
local function raise_event(name, player)
    script.raise_event(Mini_games.events[name], {
        name = Mini_games.events[name],
        player_index = player.index,
        tick = game.tick
    })
end

--- Respawn a spectator, if a game is running then they are placed in a god controller
-- If there is a game closing then they will be placed in a character in the lobby
-- If there if the server is closed nothing will happen as they have already been moved to the lobby
function Mini_games.respawn_spectator(player)
    Gui.update_top_flow(player)
    if player.character then player.character.destroy() end
    player.set_controller{ type = defines.controllers.god }
    if primitives.state == 'Closing' or primitives.state == 'Loading' then
        dlog('Respawn in lobby:', player.name)
        local surface = game.surfaces.nauvis
        local pos = surface.find_non_colliding_position('character', {-35, 55}, 6, 1)
        player.teleport(pos, surface)
        player.create_character()
    elseif primitives.current_game then
        dlog('Respawn in spectator:', player.name)
        player.set_controller{ type = defines.controllers.spectator }
    end
end

--- Get all the participants in a game, this should be used rather than force.players or game.connected_players since this excludes spectators
function Mini_games.get_participants()
    return participants
end

--- Get the names of all the participants in a game, optionally return a lookup table rather than calling is_participant many times
function Mini_games.get_participant_names(lookup)
    local rtn = {}
    for index, player in ipairs(participants) do
        if lookup then
            rtn[player.name] = true
            rtn[player.index] = true
        else
            rtn[index] = player.name
        end
    end
    return rtn
end

--- Check if a player is a participant, searches the participants list for this player, returns true if found
function Mini_games.is_participant(player)
    for _, nextPlayer in ipairs(participants) do
        if nextPlayer == player then return true end
    end
    return false
end

--- Add a participant to a game, only callable before on_start, will return false if game has started and the player is not an active participant
local check_participant_count
function Mini_games.add_participant(player)
    if Mini_games.is_participant(player) then return true end
    if primitives.state == 'Started' then return false end
    if not player.connected then return false end

    dlog('Added participant:', player.name)
    participants[#participants+1] = player
    raise_event('on_participant_added', player)
    check_participant_count()
    return true
end

--- Remove a participant from a game, advised to be called during on_participant_left, has no effect if player is not an active participant
function Mini_games.remove_participant(player)
    for index, nextPlayer in ipairs(participants) do
        if nextPlayer == player then
            participants[index] = participants[#participants]
            participants[#participants] = nil
            dlog('Remove participant:', player.name)
            raise_event('on_participant_removed', player)
            Mini_games.respawn_spectator(player)
            check_participant_count()
            return
        end
    end
    return 'player not found'
end

----- Participant Event Logic -----

--- Used with role events to trigger add and remove participant, filters the handler to only be called with the Participant role
local function role_event_filter(handler)
    return function(event)
        for _, role in ipairs(event.roles) do
            if role.name == 'Participant' then
                return handler(game.players[event.player_index])
            end
        end
    end
end

--- Used to decide if the wait gui should be shown to a new player
-- If there is no game, hide_wait_gui is true, or a game is started the gui is hidden
local function check_wait_screen(player)
    local mini_game = Mini_games.get_current_game()
    local started = primitives.state == 'Started' or primitives.state == 'Starting'
    if not mini_game or mini_game.hide_wait_gui or started then
        dlog('Hide Waiting:', player.name)
        WaitingGui.hide(player)
    else
        Mini_games.show_waiting_screen(player)
    end
end

--- Used to either add a participant or pass the player to participant_selector
-- If a participant selector exists then the player is passed to it
local function check_participant_selector_join(player)
    check_wait_screen(player)
    local mini_game = Mini_games.get_current_game()
    if mini_game and mini_game.participant_selector then
        dlog('Add selector:', player.name)
        xpcall(mini_game.participant_selector, internal_error, player)
    elseif not mini_game or #participants < primitives.participant_requirement then
        Mini_games.add_participant(player)
    end
end

--- Used to remove a participant and pass the player to participant_selector
-- If a participant selector exists then the player is passed to it
local function check_participant_selector_leave(player)
    check_wait_screen(player)
    Mini_games.remove_participant(player)
    local mini_game = Mini_games.get_current_game()
    if mini_game and mini_game.participant_selector then
        dlog('Remove selector:', player.name)
        xpcall(mini_game.participant_selector, internal_error, player, true)
    end
end
vars.amount_of_parts = 0

local function part_role_added(player)
    vars.amount_of_parts = vars.amount_of_parts + 1
    local data = {
        type = "player_count_changed",
        amount = vars.amount_of_parts,
    }
    game.write_file('mini_games/player_count_changed', game.table_to_json(data), false, 0)
    check_participant_selector_join(player)
end

local function part_role_removed(player)
    vars.amount_of_parts = vars.amount_of_parts - 1
    local data = {
        type = "player_count_changed",
        amount = vars.amount_of_parts,
    }
    game.write_file('mini_games/player_count_changed', game.table_to_json(data), false, 0)
    check_participant_selector_leave(player)
end

--- Triggered when a player is assigned new roles, and the player has joined the server once before
-- Non participants who gain the role before game start will be added to the participants list
-- Non participants who gain the role after game start will not be added to the participants list
Event.add(Roles.events.on_role_assigned, role_event_filter(part_role_added))
Event.add(Roles.events.on_role_assigned, function (event)
    Gui.update_top_flow(game.players[event.player_index])
end)


--- Triggered when a player is unassigned from roles, and the player has joined the server once before
-- Participants who lose the role will be removed from the participants list, if they are on it
Event.add(Roles.events.on_role_unassigned, role_event_filter(part_role_removed))
Event.add(Roles.events.on_role_unassigned, function (event)
    Gui.update_top_flow(game.players[event.player_index])
end)
--- Triggered when a player joins the game, will trigger on_participant_joined if there is a game running
-- Active participants who join after game start will trigger on_participant_joined
-- Inactive participants (who join before start) will be added to the participants list, or given to participant_selector
-- Non participants and Inactive participants (who join after start) will be spawned as spectator

Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    local data = {
        type = 'new_player',
        name = player.name
    }
    game.write_file('mini_games/new_player'..player.name, game.table_to_json(data), false, 0)
end)

vars.amount_of_parts  = 0
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.players[event.player_index]
    Gui.update_top_flow(player)
    local participant = Roles.player_has_role(player, 'Participant')
    if vars.is_lobby == true then
        --Gui stuffs
        local gui_table = Gui.get_left_element(player,lobby).container.scroll.table
        gui_table.clear()
        for ip, name in pairs(global.running_servers) do
            add_DataLobby(gui_table, name, require_player_list[ip], online_player_list[ip], ip)
        end

        player.print('You are now in the main lobby.')
    elseif vars.is_lobby == false then
        if participant then
            vars.amount_of_parts = vars.amount_of_parts + 1
            local data = {
                type = "player_count_changed",
                amount = vars.amount_of_parts,
            }
            game.write_file('mini_games/player_count_changed', game.table_to_json(data), false, 0)
        end
        player.print('You are now a the game server.')
    end

    local started = primitives.state == 'Started'
    if participant and Mini_games.is_participant(player) then
        dlog('Participant joined:', player.name)
        if started then raise_event('on_participant_joined', player) end
    elseif participant and not started then
        check_participant_selector_join(player)
    elseif primitives.current_game then
        Mini_games.respawn_spectator(player)
    end
end)

--- Triggered when a player leaves the game, will trigger on_participant_left if there is a game running
-- Active participants who leave after game start will be trigger on_participant_left
-- (In)Active participants who leave before game start will be removed from the participants list, and given to participant_selector
-- Non participants and Inactive participants will be moved to lobby
Event.add(defines.events.on_player_left_game, function(event)
    local player = game.players[event.player_index]
    local started = primitives.state == 'Started'
    local participant = Roles.player_has_role(player, 'Participant')
    if participant then
        vars.amount_of_parts = vars.amount_of_parts - 1
        local data = {
            type = "player_count_changed",
            amount = vars.amount_of_parts,
        }
        game.write_file('mini_games/player_count_changed', game.table_to_json(data), false, 0)
    end
    if started and Mini_games.is_participant(player) then
        dlog('Participant left:', player.name)
        raise_event('on_participant_left', player)
    elseif participant and not started then
        check_participant_selector_leave(player)
    elseif primitives.current_game then
        Mini_games.respawn_spectator(player)
    end
end)

--- Checks which mini games have they required surfaces
Event.on_init(function()
    local lookup, surfaces, available = {}, game.surfaces, Mini_games.available
    for name in pairs(surfaces) do lookup[name] = true end
    for _, mini_game in pairs(Mini_games.mini_games) do
        local required, ctn = mini_game.surfaces, 0
        if required > 0 then
            for _, name in ipairs(mini_game.surface_names) do
                if lookup[name] then ctn = ctn + 1 end
                if ctn >= required then break end
            end
        end
        if ctn < required then
            dlog('Unavailable:', mini_game.name)
            mini_game.unavailable = true
        else
            dlog('Available:', mini_game.name)
            available[#available+1] = mini_game.name
        end
    end
end)

----- Starting Mini Games -----

--- Start a mini game from the lobby server, skips everything and asks players to connect to a different server
local function start_from_lobby(name, player_count, args)
    local server_object  = global.servers[name]
    local server_address = server_object[#server_object]
    local clean_name = name:gsub('_', ' '):lower():gsub('(%l)(%w+)', function(a,b) return string.upper(a)..b end)
    require_player_list[server_address] = player_count
    online_player_list[server_address] = 0
    for index, player in pairs(game.connected_players) do
        player.connect_to_server{
            address = server_address,
            name = '\n[font=heading-1][color=red]Factorio Olympics: '..clean_name..'[/color][/font]\n',
            description = 'In order to participate you must be transferred to a private server, please press the connect button below to do so.'
        }
    end

    for index in ipairs(participants) do
        participants[index] = nil
    end

    local data = {
        type         = 'start_game',
        player_count = player_count,
        args         = args,
        name         = name,
        server       = server_address
    }

    dlog('Start lobby:', name, ' Address:', server_address)
    game.write_file('mini_games/start_game', game.table_to_json(data), false, 0)
end

--- Start a mini game from this server, calls on_participant_joined then on_start
local start_game = Token.register(function(timeout_nonce)
    if primitives.timeout_nonce ~= timeout_nonce then return end
    local mini_game = Mini_games.get_current_game()
    primitives.start_tick = game.tick
    set_internal_state('Starting')
    WaitingGui.remove_gui()

    -- Puts all players into spectator mode, teleports them to the surface, and call cleanup on participant selector
    local surfaces, selector, surface = mini_game.surface_names, mini_game.participant_selector, nil
    if #surfaces == 1 then surface = surfaces[1] end
    for _, player in ipairs(game.connected_players) do
        Gui.toggle_top_flow(player, false)
        Mini_games.respawn_spectator(player)
        if surface then player.teleport({0,0}, surface) end
        if selector then
            dlog('Remove selector:', player.name)
            xpcall(selector, internal_error, player, true)
        end
    end

    -- Raises on_participant_joined for all participants in the game
    for _, player in ipairs(participants) do
        dlog('Participant joined:', player.name)
        raise_event('on_participant_joined', player)
    end

    -- Calls on_start core event to start the game
    local on_start = mini_game.core_events.on_start
    if on_start then
        dlog('Call: On Start')
        xpcall(on_start, internal_error)
    end

    -- Write the game start to file
    local data = {
        type      = 'started_game',
        players   = Mini_games.get_participant_names(),
        name      = mini_game.name,
    }

    dlog('Start:', mini_game.name, 'Player Count:', #data.players)
    game.write_file('mini_games/started_game', game.table_to_json(data), false, 0)
    set_internal_state('Started')
end)

--- Show the loading screen to a player, this will auto update until game is started
function Mini_games.show_loading_screen(player)
    if primitives.state ~= 'Loading' then return end
    dlog('Show loading:', player.name)
    LoadingGui.show_gui({ player_index = player.index, tick = primitives.start_tick }, primitives.current_game)
end

--- Check if the game is ready to start, used to check if the game is ready to start once per second
local check_ready
check_ready = Token.register(function()
    local mini_game = Mini_games.get_current_game()
    local success, ready = xpcall(mini_game.ready_condition, internal_error)
    if not success then
        Event.remove_removable_nth_tick(60, check_ready)
    elseif ready then
        set_internal_state('Countdown')
        game.print('Game starts in 10 seconds')
        primitives.timeout_nonce = math.random()
        Task.set_timeout(10, start_game, primitives.timeout_nonce)
        dlog('Remove Loading')
        LoadingGui.remove_gui()
        Event.remove_removable_nth_tick(60, check_ready)
    else
        LoadingGui.update_gui(primitives.start_tick)
    end
end)

--- Show the waiting screen to a player, this will auto update until game is the required number have joined
function Mini_games.show_waiting_screen(player)
    if primitives.state ~= 'Waiting' then return end
    dlog('Show Waiting:', player.name)
    WaitingGui.show_gui({ player_index = player.index }, primitives.current_game, #participants, primitives.participant_requirement)
end

--- Check if the game has enough participants to start, will move onto loading screen or start once the require amount is met
-- If the amount is below the required at any point between on_init and on_start the waiting screen will be shown
function check_participant_count()
    local state = primitives.state
    if state ~= 'Waiting' and state ~= 'Loading' and state ~= 'Countdown' then return end
    local mini_game = Mini_games.get_current_game()

    -- If the participants count is less than required, and there has been less 2 minutes waiting, stop load checking, and update wait gui
    if #participants < primitives.participant_requirement and game.tick < primitives.start_tick + 7200 then
        WaitingGui.update_gui(#participants, primitives.participant_requirement)
        if state == 'Waiting' then return end
        set_internal_state('Waiting')

        dlog('Remove Loading')
        primitives.timeout_nonce = 0
        Event.remove_removable_nth_tick(60, check_ready)
        LoadingGui.remove_gui()

        return
    end

    -- Check if we are already in loading to prevent extra calls
    if state == 'Loading' or state == 'Countdown' then return end

    -- When requirement is met remove the gui
    dlog('Remove Waiting')
    WaitingGui.remove_gui(true)
    if mini_game.ready_condition then
        -- Start checking that the game is ready to start
        set_internal_state('Loading')
        Event.add_removable_nth_tick(60, check_ready)
        -- Show the loading screen to anyone who could see the wait gui
        for _, player in ipairs(game.connected_players) do
            if WaitingGui.check_player(player) then
                Mini_games.show_loading_screen(player)
            end
        end
    else
        -- No checks needed, start game count down now
        set_internal_state('Countdown')
        game.print('Game starts in 10 seconds')
        primitives.timeout_nonce = math.random()
        Task.set_timeout(10, start_game, primitives.timeout_nonce)
    end

end

--- Used to trigger a delayed check for the player count, will force waiting to be skipped
local delayed_player_count_check = Token.register(check_participant_count)

--- Starts a mini game if no other games are running, calls on_init then on_participant_added
function Mini_games.start_game(name, player_count, args)
    if vars.is_lobby then return start_from_lobby(name, player_count, args) end

    -- Setup and verify all args passed to the game
    args = args or {}
    local mini_game = assert(Mini_games.mini_games[name], 'This mini game does not exist')
    assert(mini_game.options == #args, 'Wrong number of arguments')
    assert(primitives.current_game == nil, 'A game is already running, please use /stop')
    primitives.participant_requirement = player_count
    primitives.custom_selector = false
    primitives.current_game = name
    primitives.start_tick = game.tick
    set_internal_state('Waiting')
    dlog('Enable handlers:', name)

    -- Enable all events for this mini game
    for _, event in ipairs(mini_game.events) do
        -- event = { event_name, handler }
        Event.add_removable(unpack(event))
    end

    -- Enable all nth tick events for this mini game
    for _, event in ipairs(mini_game.on_nth_tick) do
        -- event = { tick, handler }
        Event.add_removable_nth_tick(unpack(event))
    end

    -- Enable all commands for this mini game
    for _, command_name  in ipairs(mini_game.commands) do
        Commands.enable(command_name)
    end

    -- Call the on_init core event
    local on_init = mini_game.core_events.on_init
    if on_init then
        dlog('Call: On Init')
        xpcall(on_init, internal_error, args)
    end

    -- Get all the possible participants for this game
    local done, selector = {}, mini_game.participant_selector
    local all_participants = Roles.get_role_by_name('Participant'):get_players(true)
    if #all_participants > 0 then table.shuffle_table(all_participants) end

    if selector then
        -- With a custom selector, first clear the participants table
        for index in ipairs(participants) do
            participants[index] = nil
        end
        -- Then call the selector on all possible participants
        for _, player in ipairs(all_participants) do
            done[player.name] = true
            dlog('Add selector:', player.name)
            xpcall(selector, internal_error, player)
        end
    else
        -- When no selector, first raise the added event for existing participants
        for _, player in ipairs(participants) do
            dlog('Participant added:', player.name)
            raise_event('on_participant_added', player)
            done[player.name] = true
        end
        -- Then attempt to fill up to the required amount
        for _, player in ipairs(all_participants) do
            if #participants >= player_count then break end
            if not done[player.name] then done[player.name] = Mini_games.add_participant(player) end
        end
    end

    -- Show the waiting screen to all players unless hide_wait_gui is true and player is not a spectator
    for _, player in ipairs(game.connected_players) do
        if not mini_game.hide_wait_gui or not done[player.name] then
            Mini_games.show_waiting_screen(player)
        end
    end

    -- Check if we are able to start now, if not then this will be checked again with add_participant
    Task.set_timeout(120, delayed_player_count_check)
    check_participant_count()
end

----- Stopping Mini Games -----

--- Stop a mini game from this server, sends all players to lobby then calls on_close
local close_game = Token.register(function(timeout_nonce)
    if primitives.timeout_nonce ~= timeout_nonce then return end
    local mini_game = Mini_games.get_current_game()
    set_internal_state('Closing')

    -- Move all players to the lobby, and remove and selector if present
    local selector = mini_game.participant_selector
    for _, player in ipairs(game.connected_players) do
        Mini_games.respawn_spectator(player)
        if selector then
            dlog('Remove selector:', player.name)
            xpcall(selector, internal_error, player, true)
        end
    end

    -- Call on_close core event to clean up global variables and any thing else
    local on_close = mini_game.core_events.on_close
    if on_close then
        dlog('Call: On Close')
        xpcall(on_close, internal_error)
    end

    primitives.current_game = nil
    set_internal_state('Closed')
end)

--- Stop a mini game, calls on_stop then on_participant_removed
function Mini_games.stop_game()
    local mini_game = assert(Mini_games.get_current_game(), 'No mini game is currently running')
    local skip_timeout = primitives.state ~= 'Started'
    Event.remove_removable_nth_tick(60, check_ready)
    set_internal_state('Stopping')

    -- Calls on_stop core event to stop the game and to get the data to write to file
    -- on_stop should return an array of position entries which are tables of the
    -- on_stop is only called if the game was started, it would not make sense to write results to a file when no game was started
    -- following format: { place = integer, score = number, players = array of player names }
    local on_stop = mini_game.core_events.on_stop
    if not skip_timeout and on_stop then
        dlog('Call: On Stop')
        local success, res = xpcall(on_stop, internal_error)
        if success then
            local event = {
                type = "stopped_game",
                results = res or {},
            }
            game.write_file('mini_games/stopped_game', game.table_to_json(event), false, 0)
        end
    end

    -- Remove all participants from the game, this also places them into spectator
    -- Done in reverse as its removing elements form the table
    local amount = #participants
    for i = amount, 1, -1 do
        --is one so the remove_participant does not have to search (this shood not be an i)
        local player = participants[1]
        Mini_games.remove_participant(player)
    end
    -- Disable all events for this mini game
    dlog('Disable handlers:', mini_game.name)
    for _, event in ipairs(mini_game.events) do
        -- event = { event_name, handler }
        Event.remove_removable(unpack(event))
    end

    -- Disable all nth tick events for this mini game
    for _, event in ipairs(mini_game.on_nth_tick) do
        -- event = { tick, handler }
        Event.remove_removable_nth_tick(unpack(event))
    end

    -- Disable all commands for this mini game
    for _, command_name  in ipairs(mini_game.commands) do
        Commands.enable(command_name)
    end

    if skip_timeout then
        -- If this was called during loading, then skip the 10 second delay
        dlog('Lobby Countdown', 'Remove Waiting', 'Remove Loading')
        LoadingGui.remove_gui()
        WaitingGui.remove_gui()
        game.print('Game start canceled')
        primitives.timeout_nonce = math.random()
        Task.set_timeout_in_ticks(1, close_game, primitives.timeout_nonce)
        local data = { type = 'start_cancelled', name = mini_game.name }
        game.write_file('mini_games/start_cancelled', game.table_to_json(data), false, 0)
    else
        -- If this was called normally wait 10 seconds before closing the game
        dlog('Lobby Countdown')
        game.print('Returning to lobby in 10 seconds')
        primitives.timeout_nonce = math.random()
        Task.set_timeout(10, close_game, primitives.timeout_nonce)
    end

end

--- Get the english suffix that follows a position number
--@author https://rosettacode.org/wiki/N%27th#Lua
local function getSuffix (n)
    local lastTwo, lastOne = n % 100, n % 10
    if lastTwo > 3 and lastTwo < 21 then return "th" end
    if lastOne == 1 then return "st" end
    if lastOne == 2 then return "nd" end
    if lastOne == 3 then return "rd" end
    return "th"
end

--- Get the position number with the suffix appended
local function Nth (n) return n..getSuffix(n) end

--- Colours used while printing positions in chat
local message_format = '%s: %s with %d %s'
local colors =  {
    ["1st"] = { 255, 215, 0   },
    ["2nd"] = { 192, 192, 192 },
    ["3rd"] = { 205, 127, 50  },
    default = { 128, 128, 128 }
}

--- Print the results to game chat, follows the same requires as returning from on_close with optional names table as an override
function Mini_games.print_results(results, unit, names, limit)
    names = names or {}
    limit = limit or 5
    for i, result in ipairs(results) do
        if result.place < limit then
            local place = Nth(result.place)
            local colour = colors[place] or colors.default
            local name = names[i] or table.concat(result.players, ', ')
            game.print(message_format:format(place, name, result.score, unit), colour)
        end
    end
end

--- Raise an error which causes the mini game to stop
function Mini_games.error_in_game(error_game)
    game.print("An error has occurred things may be broken, error: "..error_game)
    Mini_games.stop_game()
end

----- Commands -----

--- Kicks all players from the game
Commands.new_command('kick_all', 'Kicks all players.')
:register(function(_,_)
    for _, player in ipairs(game.connected_players) do
        game.kick_player(player, "You cant stay here")
    end
end)

--- Sends all players back to the lobby server
Commands.new_command('lobby_all', 'Send everyone to the lobby server.')
:register(function(_,_)
    for _, player in ipairs(game.connected_players) do
        player.connect_to_server{
            address = global.servers["lobby"],
            name = '\n[font=heading-1][color=red]Factorio Olympics: '.."lobby"..'[/color][/font]\n',
            description = 'The game is over you must go back to the lobby.'
        }
    end
end)

--- Sets if this server is the lobby
Commands.new_command('set_lobby', 'Command to tell this server if its the lobby.')
:add_param('data',"boolean")
:register(function(_,data,_)
    vars.is_lobby = data
end)

----- Main Gui -----

--- Used to start a mini game, will also hide the start menu from every one
local mini_game_list, player_count_slider
local on_start_click = function (_,element,_)
    local name = element.parent.name
    local scroll_table = element.parent.parent
    local mini_game = Mini_games.mini_games[name]
    local args
    if mini_game.gui_callback then
        args = mini_game.gui_callback(scroll_table[name..'_flow'])
    end

    local player_count = scroll_table[player_count_slider.name].slider_value
    Mini_games.start_game(name, player_count, args)
    for _, player in ipairs(game.connected_players) do
        Gui.toggle_left_element(player, mini_game_list, false)
        Gui.update_top_flow(player)
    end
end

--- Slider used to select the number of players to take part
player_count_slider =
Gui.element{
    type = 'slider',
    minimum_value = 1,
    maximum_value = 20,
    value = 6,
    value_step = 1,
    discrete_slider = true,
    discrete_values = true,
    style = 'notched_slider'
}
:style{
    horizontally_stretchable = true
}
:on_value_changed(function(_, element, _)
    element.parent.player_count.caption = 'Players: '..element.slider_value
end)

--- Button used to start a mini game
local start_button =
Gui.element{
    type = 'sprite-button',
    sprite = 'utility/check_mark_white',
    style = 'slot_button',
    tooltip = 'Start Game'
}
:style(Gui.sprite_style(30))
:on_click(on_start_click)

--- Adds the base that a mini game will add onto
local add_mini_game =
Gui.element(function(_,parent,name)
    local start_flow = parent.add{ type = 'flow', name = name }
    start_flow.style.padding = 0
    start_button(start_flow)

    parent.add{
        type    = "label",
        style   = "heading_1_label",
        caption = name:gsub('_', ' '):lower():gsub('(%l)(%w+)', function(a,b) return string.upper(a)..b end)
    }

    local mini_game = Mini_games.mini_games[name]
    if mini_game.gui then
        mini_game.gui(parent.add{ type = 'flow', name = name..'_flow' })
    end
end)

--- Main gui to select a mini game from
mini_game_list =
Gui.element(function(event_trigger,parent)
    local container = Gui.container(parent,event_trigger,200)

    -- Add the header
    Gui.header(container, "Start a game", "You can start the game here.")

    -- Add the scroll table
    local scroll_table = Gui.scroll_table(container, 250, 3)
    local scroll_table_style = scroll_table.style
    scroll_table_style.padding = {3, 3}
    scroll_table_style.top_cell_padding = 3
    scroll_table_style.bottom_cell_padding = 3

    -- Add the player slider
    scroll_table.add{type='empty-widget'}
    scroll_table.add{type='label', style = 'heading_1_label', name='player_count', caption='Players: 6'}
    player_count_slider(scroll_table)

    -- Add all the mini games
    for _, name in ipairs(Mini_games.available) do
        add_mini_game(scroll_table, name)
    end

    return container.parent
end)
:add_to_left_flow()



--- Add a toggle button that can be used when no game is running
Gui.left_toolbar_button('utility/check_mark', 'Select a mini game to start', mini_game_list, function(player)
    return Roles.player_allowed(player, 'gui/game_start') and (primitives.state == 'Closing' or primitives.state == 'Closed')
end)


----- Lobby gui

local lobby_list = {}
local perfix = 1
local function pick_name(name)
    if lobby_list[name] ~= nil then
        local new_name = name..perfix
        if lobby_list[name] ~= nil then return new_name end
        perfix = perfix + 1
        return pick_name(name)
    else
        perfix = 1
        return name
    end
end

--- Button used to start a mini game
local join_button =
Gui.element{
    type = 'sprite-button',
    sprite = 'utility/import',
    style = 'slot_button',
    tooltip = 'Join game',
	--name = lobby_counter --should be an integer type
}
:style(Gui.sprite_style(30))
:on_click(function(player, element, _)
    local index = element.parent.name
    local lobbyData = lobby_list[index]
    player.connect_to_server{
        address = lobbyData.address,
        name = '\n[font=heading-1][color=red]Factorio Olympics: '..lobbyData.name..'[/color][/font]\n',
        description = 'In order to participate you must be transferred to a private server, please press the connect button below to do so.'
    }
end)

--- Adds  data to Lobby_table
add_DataLobby =
Gui.element(function(_,parent,name,maxPlayer,currentPlayer, address)
    name = pick_name(name)
    local start_flow = parent.add{ type = 'flow', name = name }
    start_flow.style.padding = 0
    join_button(start_flow)
	lobby_list[name] = {name = name, address = address}
    parent.add{
        type    = "label",
        style   = "heading_1_label",
        caption = name:gsub('_', ' '):lower():gsub('(%l)(%w+)', function(a,b) return string.upper(a)..b end)
    }
	local label = parent.add{
        type    = "label",
        style   = "heading_1_label",
        caption =  currentPlayer..' / '..maxPlayer..' Players'
    }
    label.style.left_padding = 20
end)

--lobby to select a game to join
lobby =
Gui.element(function(event_trigger,parent)
    local container = Gui.container(parent,event_trigger,200)

    -- Add the header
    Gui.header(container, "Game-Lobby", "You can find a game here.")

    -- Add the scroll table
	local scroll_table = Gui.scroll_table(container, 250, 3)
	local scroll_table_style = scroll_table.style
	scroll_table_style.padding = {3, 3}
	scroll_table_style.top_cell_padding = 3
    scroll_table_style.bottom_cell_padding = 3
    return container.parent
end)
:add_to_left_flow()

Mini_games.server_list_updated =
function ()
    if vars.is_lobby ~= true then return end
    lobby_list = {}
    for i , player in ipairs(game.connected_players) do
        local gui_table = Gui.get_left_element(player,lobby).container.scroll.table
        gui_table.clear()
        for ip, name in pairs(global.running_servers) do
            add_DataLobby(gui_table, name, require_player_list[ip], online_player_list[ip], ip)
        end
    end
end

Mini_games.set_online_player_count =
function(amount,ip)
    online_player_list[ip] = amount
    for i , player in ipairs(game.connected_players) do
        local gui_table = Gui.get_left_element(player,lobby).container.scroll.table
        gui_table[ip].caption = amount..' / 4 Players'
    end
end


Gui.left_toolbar_button('utility/change_recipe', 'Select a game to join', lobby, function(_)
    return vars.is_lobby
end)

----- Module Return -----
return Mini_games
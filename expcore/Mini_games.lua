local Token = require "utils.token"
local Event = require "utils.event"
local Commands = require "expcore.commands"
local Gui = require "expcore.gui._require"
require "config.expcore.command_runtime_disable" --required to load befor running the script
local Roles = require "expcore.roles" --- @dep expcore.roles

local Mini_games = {}
local main_gui = {}
local started_game = {}

local Global = require "utils.global" --Used to prevent desynicing.
Global.register(
    {
        started_game = started_game,
        main_gui = main_gui
    },
    function(tbl)
        started_game = tbl.started_game
        main_gui = tbl.main_gui
    end
)

Mini_games["mini_games"] = {}
Mini_games["_prototype"] = {}

local function internal_error(success, error_message)
    if not success and error_message then
        game.print("Their is an error please contact the admins, error: " .. error_message)
        log(error_message)
    end
end

function Mini_games.new_game(name)
    local mini_game =
        setmetatable(
        {
            name = name,
            events = {},
            onth_tick = {},
            commands = {},
            start_function = nil,
            stop_function = nil,
            map = nil,
            positon = {},
            options = 0,
            gui = nil,
            gui_callback = nil
        },
        {
            __index = Mini_games._prototype
        }
    )
    Mini_games.mini_games[name] = mini_game
    return mini_game
end

function Mini_games._prototype:add_onth_tick(tick, func)
    local handler = Token.register(func)
    self.onth_tick[#self.onth_tick + 1] = {tick, handler}
end

function Mini_games._prototype:add_start_function(start_function)
    self.start_function = start_function
end
function Mini_games._prototype:add_option(amount)
    self.options = self.options + amount
end

function Mini_games._prototype:add_stop_function(stop_function)
    self.stop_function = stop_function
end
function Mini_games._prototype:add_gui_element(gui_element)
    self.gui = gui_element
end

function Mini_games._prototype:add_gui_callback(callback)
    self.gui_callback = callback
end

function Mini_games._prototype:add_command(command_name)
    self.commands[#self.commands + 1] = command_name
    Commands.disable(command_name)
end
function Mini_games._prototype:add_map(map, x, y)
    --map is the name of surface to play the game on
    self.map = map
    self.positon.x = x
    self.positon.y = y
end

function Mini_games._prototype:add_event(event_name, func)
    local handler = Token.register(func)
    self.events[#self.events + 1] = {handler, event_name}
end
function Mini_games.Running_game()
    return started_game[1]
end

function Mini_games.start_game(name, parse_args)
    local mini_game = Mini_games.mini_games[name]
    if mini_game == nil then
        return "This mini_game does not exsit"
    end
    if parse_args then
        if mini_game.options ~= #parse_args then
            return "Wrong number of arguments"
        end
    else
        if mini_game.options ~= 0 then
            return "Wrong number of arguments"
        end
    end

    if started_game[1] == name then
        return "This game is already running"
    end
    if mini_game.map == nil then
        error("No map set")
    end

    if started_game[1] then
        Mini_games.stop_game(started_game[1])
    end

    for i, player in ipairs(game.connected_players) do
        game.connected_players[i].teleport({mini_game.positon.x, mini_game.positon.y}, mini_game.map)
    end

    started_game[1] = name

    for i, value in ipairs(mini_game.events) do
        local handler = value[1]
        local event_name = value[2]
        Event.add_removable(event_name, handler)
    end

    for i, value in ipairs(mini_game.onth_tick) do
        local tick = value[1]
        local token = value[2]
        Event.add_removable_nth_tick(tick, token)
    end

    if mini_game.commands then
        for i, command_name in ipairs(mini_game.commands) do
            Commands.enable(command_name)
        end
    end

    local start_func = mini_game.start_function
    if start_func then
        if parse_args then
            local success, err = pcall(start_func, parse_args)
            internal_error(success, err)
        else
            local success, err = pcall(start_func)
            internal_error(success, err)
        end
    end
end

function Mini_games.stop_game()
    local mini_game = Mini_games.mini_games[started_game[1]]

    started_game[1] = nil
    for i, value in ipairs(mini_game.events) do
        local handler = value[1]
        local event_name = value[2]
        Event.remove_removable(event_name, handler)
    end

    for i, value in ipairs(mini_game.onth_tick) do
        local tick = value[1]
        local token = value[2]
        Event.remove_removable_nth_tick(tick, token)
    end

    for i, player in ipairs(game.connected_players) do
        game.connected_players[i].teleport({-35, 55}, "nauvis")
    end

    local stop_func = mini_game.stop_function
    if stop_func then
        local success, err = pcall(stop_func)
        internal_error(success, err)
    end

    mini_game.vars = {}
    for i, command_name in ipairs(mini_game.commands) do
        Commands.disable(command_name)
    end
    for i, player in ipairs(game.connected_players) do
        Gui.update_top_flow(player)
    end
end

function Mini_games.error_in_game(error_game)
    Mini_games.stop_game()
    game.print("an error has occured things may be broken, error: " .. error_game)
end
local mini_game_list
--gui
local on_vote_click = function(player, element, event)
    local name = element.parent.name
    local scroll_table = element.parent.parent
    local mini_game = Mini_games.mini_games[name]
    local args
    if mini_game.gui_callback then
        args = mini_game.gui_callback(scroll_table)
    end
    if args then
        Mini_games.start_game(name, args)
    else
        Mini_games.start_game(name)
    end
    for i, player in ipairs(game.connected_players) do
        main_gui[i] = Gui.get_left_element(player, mini_game_list)
        Gui.toggle_left_element(player, main_gui[i], false)
        Gui.update_top_flow(player)
    end
end

local vote_button =
    Gui.element {
    type = "sprite-button",
    sprite = "utility/check_mark",
    style = "quick_bar_slot_button"
}:on_click(on_vote_click)

local add_mini_game =
    Gui.element(
    function(_, parent, name)
        local vote_flow = parent.add {type = "flow", name = name}
        vote_flow.style.padding = 0
        vote_button(vote_flow)
        parent.add {
            type = "label",
            caption = name,
            style = "heading_1_label"
        }
        local mini_game = Mini_games.mini_games[name]
        if mini_game.gui then
            mini_game.gui(parent)
        end
    end
)

mini_game_list =
    Gui.element(
    function(event_trigger, parent, ...)
        local container = Gui.container(parent, event_trigger, 200)
        local header = Gui.header(container, "Start a game", "You can start the game here.", true)
        local scroll_table = Gui.scroll_table(container, 250, 3, "thing")
        local scroll_table_style = scroll_table.style
        scroll_table_style.top_cell_padding = 3
        scroll_table_style.bottom_cell_padding = 3

        for i, e in pairs(Mini_games.mini_games) do
            add_mini_game(scroll_table, i)
        end
        return container.parent
    end
):add_to_left_flow(false)

Gui.left_toolbar_button(
    "utility/check_mark",
    "Nothing to see here",
    mini_game_list,
    function(player)
        return Roles.player_allowed(player, "gui/game_start") and not started_game[1]
    end
)

--[[
local example_button =
Gui.element{
    type = 'button',
    caption = 'Example Button'
}
:on_click(function(player,element,event)
    -- player is the player who interacted with the element to cause the event
    -- element is a refrence to the element which caused the event
     --event is a raw refrence to the event data if player and element are not enough
    game.print("lol")
end)
:add_to_left_flow(true)
Gui.left_toolbar_button('entity/inserter', 'Nothing to see here', example_button)

--left_toolbar_button
]]
return Mini_games

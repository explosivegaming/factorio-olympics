--[[-- Gui Module - Player List
    - Adds a player list to show names and play time; also includes action buttons which can preform actions to players
    @gui Player-List
    @alias player_list
]]

-- luacheck:ignore 211/Colors
local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Mini_games = require 'expcore.Mini_games' --- @dep expcore.Mini_games
local Game = require 'utils.game' --- @dep utils.game
local Event = require 'utils.event' --- @dep utils.event
local Colors = require 'utils.color_presets' --- @dep utils.color_presets
local format_time = _C.format_time --- @dep expcore.common

--- Set of elements that are used to make up a row of the player table
-- @element add_player_base
local add_player_base =
Gui.element(function(event_trigger, parent, player_data)
    -- Add the player name
    local player_name_flow = parent.add{ type = 'flow', name = 'player-name-'..player_data.index }
    local player_name = player_name_flow.add{
        type = 'label',
        name = event_trigger,
        caption = player_data.name,
        tooltip = {'player-list.open-map', player_data.name, player_data.tag, player_data.role_name}
    }
    player_name.style.padding = {0, 2,0, 0}
    player_name.style.font_color = player_data.chat_color

    -- Add the time played label
    local alignment = Gui.alignment(parent, 'player-time-'..player_data.index)
    local time_label = alignment.add{
        name = 'label',
        type = 'label',
        caption = player_data.caption,
        tooltip = player_data.tooltip
    }
    time_label.style.padding = 0

    return time_label
end)
:on_click(function(player, element, event)
    local selected_player_name = element.caption
    local selected_player = Game.get_player_from_any(selected_player_name)
    if event.button == defines.mouse_button_type.left then
        -- LMB will open the map to the selected player
        if player.character then
            player.zoom_to_world(selected_player.position, 1.75)
        else
            player.teleport(selected_player.position, selected_player.surface)
        end
    end
end)

-- Removes the three elements that are added as part of the base
local function remove_player_base(parent, player)
    Gui.destroy_if_valid(parent['player-name-'..player.index])
    Gui.destroy_if_valid(parent['player-time-'..player.index])
end

-- Update the time label for a player using there player time data
local function update_player_base(parent, player_time)
    local time_element = parent[player_time.element_name]
    if time_element and time_element.valid then
        time_element.label.caption = player_time.caption
        time_element.label.tooltip = player_time.tooltip
    end
end

-- Button to toggle a section dropdown
-- @element toggle_section
local toggle_section =
Gui.element{
	type = 'sprite-button',
	sprite = 'utility/expand_dark',
	hovered_sprite = 'utility/expand',
	tooltip = {'player-list.toggle-section-tooltip'}
}
:style(Gui.sprite_style(20))
:on_click(function(_, element, _)
	local header_flow = element.parent
	local flow_name = header_flow.caption
    local flow = header_flow.parent.parent[flow_name]
	if Gui.toggle_visible_state(flow) then
        element.sprite = 'utility/collapse_dark'
        element.hovered_sprite = 'utility/collapse'
        element.tooltip = {'player-list.toggle-section-collapse-tooltip'}
	else
        element.sprite = 'utility/expand_dark'
        element.hovered_sprite = 'utility/expand'
        element.tooltip = {'player-list.toggle-section-tooltip'}
	end
end)

-- Used to assign an event to the header label to trigger a toggle
-- @element header_toggle
local header_toggle = Gui.element()
:on_click(function(_, element, event)
	event.element = element.parent.alignment[toggle_section.name]
	toggle_section:raise_custom_event(event)
end)

-- Draw a section header and main scroll
-- @element rocket_list_container
local section =
Gui.element(function(_, parent, section_name)
	-- Draw the header for the section
    local header = Gui.header(
        parent,
		section_name,
        section_name,
		true,
		section_name..'-header',
		header_toggle.name
	)

	-- Right aligned button to toggle the section
	header.caption = section_name
	toggle_section(header)

    -- Table used to store the data
	local scroll_table = Gui.scroll_table(parent, 184, 2, section_name)
    scroll_table.parent.visible = false

    -- Change the style of the scroll table
    local scroll_table_style = scroll_table.style
    scroll_table_style.padding = {1, 0,1, 2}

	-- Return the flow table
	return scroll_table
end)

--- Main player list container for the left flow
-- @element player_list_container
local player_list_container =
Gui.element(function(event_trigger, parent)
    -- Draw the internal container
    local container = Gui.container(parent, event_trigger, 200)

    -- Draw the section for each force
    for name in pairs(game.forces) do
        section(container, name, 2)
    end

    -- Return the external container
    return container.parent
end)
:add_to_left_flow()

--- Button on the top flow used to toggle the player list container
-- @element toggle_left_element
Gui.left_toolbar_button('entity/character', {'player-list.main-tooltip'}, player_list_container, function(player)
    return not Roles.player_has_role(player, 'Participant') and Mini_games.get_current_state() == 'Started'
end)

-- Get caption and tooltip format for a player
local function get_time_formats(online_time, afk_time)
    local tick = game.tick > 0 and game.tick or 1
    local percent = math.round(online_time/tick, 3)*100
    local caption = format_time(online_time)
    local tooltip = {'player-list.afk-time', percent, format_time(afk_time, {minutes=true, long=true})}
    return caption, tooltip
end

-- Get the player time to be used to update time label
local function get_player_times()
    local ctn = 0
    local player_times = {}
    for _, player in pairs(game.connected_players) do
        ctn = ctn + 1
        -- Add the player time details to the array
        local caption, tooltip = get_time_formats(player.online_time, player.afk_time)
        player_times[ctn] = {
            element_name = 'player-time-'..player.index,
            caption = caption,
            tooltip = tooltip,
            force = player.force.name
        }
    end

    return player_times
end

-- Get a sorted list of all online players
local function get_player_list_order()
    -- Sort all the online players into roles
    local players = {}
    for _, player in pairs(game.connected_players) do
        local highest_role = Roles.get_player_highest_role(player)
        if not players[highest_role.name] then
            players[highest_role.name] = {}
        end
        table.insert(players[highest_role.name], player)
    end

    -- Sort the players from roles into a set order
    local ctn = 0
    local player_list_order = {}
    for _, role_name in pairs(Roles.config.order) do
        if players[role_name] then
            for _, player in pairs(players[role_name]) do
                ctn = ctn + 1
                -- Add the player data to the array
                local caption, tooltip = get_time_formats(player.online_time, player.afk_time)
                player_list_order[ctn] = {
                    name = player.name,
                    index = player.index,
                    tag = player.tag,
                    role_name = role_name,
                    chat_color = player.chat_color,
                    force = player.force.name,
                    caption = caption,
                    tooltip = tooltip
                }
            end
        end
    end

    --Adds fake players to the player list
    local tick = game.tick
    for i = 1, 10 do
        local online_time = math.random(1, tick)
        local afk_time = math.random(online_time-(tick/10), tick)
        local caption, tooltip = get_time_formats(online_time, afk_time)
        player_list_order[ctn+i] = {
            name='Player '..i,
            index=0-i,
            tag='',
            role_name = 'Fake Player',
            chat_color = table.get_random_dictionary_entry(Colors),
            force = 'neutral',
            caption = caption,
            tooltip = tooltip
        }
    end

    return player_list_order
end

--- Update the play times every 30 sections
Event.on_nth_tick(1800, function()
    local player_times = get_player_times()
    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, player_list_container)
        local container = frame.container
        for _, player_time in pairs(player_times) do
            update_player_base(container[player_time.force], player_time)
        end
    end
end)

--- When a player leaves only remove they entry
Event.add(defines.events.on_player_left_game, function(event)
    local remove_player = Game.get_player_by_index(event.player_index)
    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, player_list_container)
        local scroll_table = frame.container.scroll.table
        remove_player_base(scroll_table, remove_player)
    end
end)

--- All other events require a full redraw of the table
local function redraw_player_list()
    local player_list_order = get_player_list_order()
    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, player_list_container)
        local container = frame.container

        for name, force in pairs(game.forces) do
            local scroll_table = container[name]
            local header = container[name..'-header']
            scroll_table.table.clear()

            if #force.connected_players == 0 then
                scroll_table.visible = false
                header.visible = false
            else
                header.visible = true
            end
        end

        for _, next_player_data in ipairs(player_list_order) do
            add_player_base(container[next_player_data.force].table, next_player_data)
        end
    end
end

Event.add(defines.events.on_player_joined_game, redraw_player_list)
Event.add(Roles.events.on_role_assigned, redraw_player_list)
Event.add(Roles.events.on_role_unassigned, redraw_player_list)
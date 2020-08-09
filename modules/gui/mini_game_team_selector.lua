local Mini_games = require 'expcore.Mini_games'
local Gui = require 'expcore.gui'
local Public = {}

local ceil = math.ceil
local PlayerCount = 'Player Count: %d / %d'
local TotalPlayerCount = 'Waiting for players to join a team: %d / %d\nFeel free to pick a side!'

--- Button used to join a team
-- @element join_team
local join_team =
Gui.element(function(event_trigger, parent, team)
    return parent.add{
        type = 'button',
        name = event_trigger,
        caption = 'Join '..team.name,
        tooltip = 'Click to join '..team.name
    }
end)
:on_click(function(player, element)
    local team_name = element.parent.name
    local player_name = player.name
    local old_force_name = player.force.name

    player.print('[color=green]You have joined '..team_name..'![/color]')
    player.force = game.forces[team_name]
    Mini_games.add_participant(player)

    local remove_player = old_force_name ~= 'player'
    for _, next_player in ipairs(game.connected_players) do
        Public.add_player(next_player, team_name, player_name)
        if remove_player then
            Public.remove_player(next_player, old_force_name, player_name)
        end
    end
end)
:style{
    horizontally_stretchable = true
}

--- Add all player names to a list
local function add_players(scroll, force)
    scroll.clear()
    local players = force.players
    if #players == 0 then
        scroll.add{ type = 'label', name = 'none', caption = 'No Players' }
    else
        for _, next_player in pairs(force.players) do
            scroll.add{ type = 'label', name = next_player.name, caption = next_player.name }
        end
    end
end

--- The content used for each team, contains a button and a table
-- @element team_content
local team_content =
Gui.element(function(_, parent, team)
    local players, max_players = #team.players, Mini_games.get_participant_requirement()/tonumber(parent.caption)

    -- Add the team flow
    local flow = parent.add{ type = 'flow', name = team.name, direction = 'vertical' }
    flow.style.horizontally_stretchable = true
    flow.style.horizontal_align = 'center'

    -- Add a player counter above the button
    flow.add{
        type = 'label',
        name = 'player_count',
        caption = PlayerCount:format(players, ceil(max_players))
    }.style.horizontal_align = 'center'

    -- Add the join button
    join_team(flow, team).enabled = players < max_players

    -- Add the player names
    local frame = flow.add{ type = 'frame', name = 'list', style = 'inside_shallow_frame' }
    local scroll = frame.add{ type = 'scroll-pane', name = 'scroll', horizontal_scroll_policy = 'never' }
    scroll.style.horizontally_stretchable = true
    scroll.style.height  = 100
    scroll.style.padding = 4
    add_players(scroll, team)

    return flow
end)

--- The main gui that is drawn to the players center
-- @element team_selector
local team_selector =
Gui.element(function(event_trigger, parent, teams)
    local mini_game = Mini_games.get_current_game()
    local game_name = mini_game.name:gsub('_', ' '):lower():gsub('(%l)(%w+)', function(a,b) return string.upper(a)..b end)
    local total_players, required_players = #Mini_games.get_participants(), Mini_games.get_participant_requirement()

    -- Add the main frame
    local frame = parent.add {name = event_trigger, type = 'frame', direction = 'vertical', style = 'captionless_frame'}
    frame.style.minimal_width = 300

    -- Header
    local top_flow = frame.add {type = 'flow', direction = 'horizontal'}
    top_flow.style.horizontal_align = 'center'
    top_flow.style.horizontally_stretchable = true

    local title_flow = top_flow.add {type = 'flow'}
    title_flow.style.horizontal_align = 'center'
    title_flow.style.top_padding = 8
    title_flow.style.horizontally_stretchable = false

    local title = title_flow.add {type = 'label', caption = 'Welcome to '..game_name}
    title.style.font = 'default-large-bold'

    -- Body
    local content_flow = frame.add {type = 'flow', name = 'center', direction = 'vertical'}
    content_flow.style.top_padding = 8
    content_flow.style.bottom_padding = 16
    content_flow.style.left_padding = 24
    content_flow.style.right_padding = 24
    content_flow.style.horizontal_align = 'center'
    content_flow.style.horizontally_stretchable = true

    local label_flow = content_flow.add {type = 'flow', name = 'count' }
    label_flow.style.horizontal_align = 'center'
    label_flow.style.horizontally_stretchable = true

    local label = label_flow.add {type = 'label', name = 'label', caption = TotalPlayerCount:format(total_players, required_players)}
    label.style.horizontal_align = 'center'
    label.style.single_line = false
    label.style.font = 'default'

    --Footer
    local ctn = 0; for _ in pairs(teams) do ctn = ctn + 1 end
    local team_flow = frame.add {type = 'table', name = 'teams', caption = ctn, column_count = math.ceil(math.sqrt(ctn)) }
    team_flow.style.horizontally_stretchable = true
    team_flow.style.horizontal_align = 'center'
    for _, team in pairs(teams) do
        team_content(team_flow, team)
    end

    return frame
end)
:on_closed(function(player, element)
    Mini_games.show_waiting_screen(player)
    Mini_games.show_loading_screen(player)
    Gui.destroy_if_valid(element)
end)

--- Shows the gui to a player
function Public.show(player, teams)
    player.opened = team_selector(player.gui.center, teams)
end

--- Hides the gui from a player
function Public.hide(player)
    Gui.destroy_if_valid(player.gui.center[team_selector.name])
end

--- Updates the team button and label counts
local function update(team, force, frame)
    local total_players, required_players = #Mini_games.get_participants(), Mini_games.get_participant_requirement()
    local players, max_players = #force.players, required_players/tonumber(frame.teams.caption)
    frame.center.count.label.caption = TotalPlayerCount:format(total_players, required_players)
    team.player_count.caption = PlayerCount:format(players, ceil(max_players))
    team[join_team.name].enabled = players < max_players
end

--- Updates the player counts and player lists for the teams
function Public.update(player, team_name)
    local frame = player.gui.center[team_selector.name]
    if not frame then return end
    if team_name then
        -- If team name is given then only that team is updated
        local team, force = frame.teams[team_name], game.forces[team_name]
        if not team or not force then return end
        update(team, force, frame)
        add_players(team.list.scroll, force)
    else
        local total_players, required_players = #Mini_games.get_participants(), Mini_games.get_participant_requirement()
        local max_players =  required_players/tonumber(frame.teams.caption)
        frame.center.count.label.caption = TotalPlayerCount:format(total_players, required_players)
        -- If no team name is given then all teams are updated
        for _, team in pairs(frame.teams.get_children()) do
            local force = game.forces[team.name]
            local players = #force.players
            team.player_count.caption = PlayerCount:format(players, ceil(max_players))
            team[join_team.name].enabled = players < max_players
            add_players(team.list.scroll, force)
        end
    end
end

--- Add a player to a force list and update that force
function Public.add_player(player, team_name, player_name)
    local frame = player.gui.center[team_selector.name]
    if not frame then return end
    local team, force = frame.teams[team_name], game.forces[team_name]
    if not team or not force then return end

    local scroll = team.list.scroll
    scroll.add{ type = 'label', name = player_name, caption = player_name }
    Gui.destroy_if_valid(scroll.none)
    update(team, force, frame)
end

--- Remove a player from a force list and update that force
function Public.remove_player(player, team_name, player_name)
    local frame = player.gui.center[team_selector.name]
    if not frame then return end
    local team, force = frame.teams[team_name], game.forces[team_name]
    if not team or not force then return end

    local scroll = team.list.scroll
    Gui.destroy_if_valid(scroll[player_name])
    update(team, force, frame)
    if #force.players == 0 then
        scroll.add{ type = 'label', name = 'none', caption = 'No Players' }
    end
end

--- Factory function for making a participant selector using this gui
function Public.selector(teams)
    local is_function = type(teams) == 'function'
    return function(player, remove_selector)
        if remove_selector then
            Gui.destroy_if_valid(player.gui.center[team_selector.name])
            Mini_games.show_waiting_screen(player)
        else
            player.opened = team_selector(player.gui.center, is_function and teams() or teams)
        end
    end
end

return Public
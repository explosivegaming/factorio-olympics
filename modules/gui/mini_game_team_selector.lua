local Mini_games = require 'expcore.Mini_games'
local Gui = require 'expcore.gui'
local Public = {}

--- Button used to join a team
-- @element join_team
local join_team =
Gui.element(function(event_trigger, parent, team)
    return parent.add{
        type = 'button',
        name = event_trigger,
        caption = 'Join '..team.name
    }
end)
:on_click(function(player, element)
    local name = element.parent.name
    player.force = game.forces[name]
    player.print('[color=green]You have joined '..name..'![/color]')
    Mini_games.show_waiting_screen(player)
    Mini_games.add_participant(player)
    Public.hide(player)
    for _, next_player in ipairs(game.connected_players) do
        Public.update(next_player, name, player)
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
            scroll.add{ type = 'label', caption = next_player.name }
        end
    end
end

--- The content used for each team, contains a button and a table
-- @element team_content
local team_content =
Gui.element(function(_, parent, team)
    -- Add the team flow
    local flow = parent.add{ type = 'flow', name = team.name, direction = 'vertical' }
    flow.style.horizontally_stretchable = true
    flow.style.horizontal_align = 'center'

    -- Add a player counter above the button
    flow.add{
        type = 'label',
        name = 'player_count',
        caption = 'Player Count: '..#team.players
    }.style.horizontal_align = 'center'

    -- Add the join button
    join_team(flow, team)

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
    local content_flow = frame.add {type = 'flow', direction = 'horizontal'}
    content_flow.style.top_padding = 8
    content_flow.style.bottom_padding = 16
    content_flow.style.left_padding = 24
    content_flow.style.right_padding = 24
    content_flow.style.horizontal_align = 'center'
    content_flow.style.horizontally_stretchable = true

    local label_flow = content_flow.add {type = 'flow'}
    label_flow.style.horizontal_align = 'center'
    label_flow.style.horizontally_stretchable = true

    local label = label_flow.add {type = 'label', caption = 'Feel free to pick a side!'}
    label.style.horizontal_align = 'center'
    label.style.single_line = false
    label.style.font = 'default'

    --Footer
    local ctn = 0; for _ in pairs(teams) do ctn = ctn + 1 end
    local team_flow = frame.add {type = 'table', name = 'teams', column_count = math.ceil(math.sqrt(ctn)) }
    team_flow.style.horizontally_stretchable = true
    team_flow.style.horizontal_align = 'center'
    for _, team in pairs(teams) do
        team_content(team_flow, team)
    end

    return frame
end)

--- Shows the gui to a player
function Public.show(player, teams)
    team_selector(player.gui.center, teams)
end

--- Hides the gui from a player
function Public.hide(player)
    Gui.destroy_if_valid(player.gui.center[team_selector.name])
end

--- Updates the player counts and player lists for the teams
function Public.update(player, team_name, add_player)
    local frame = player.gui.center[team_selector.name]
    if not frame then return end
    if team_name then
        -- If team name is given then only that team is updated
        local team = frame.teams[team_name]
        local force = game.forces[team_name]
        local scroll = team.list.scroll
        team.player_count.caption = 'Player Count: '..#force.players
        if add_player then
            -- If a player is given then this player is added and nothing else is done
            scroll.add{ type = 'label', caption = add_player.name }
            Gui.destroy_if_valid(scroll.none)
        else
            -- Otherwise all players need to be re-added
            add_players(scroll, force)
        end
    else
        -- If no team name is given then all teams are updated
        for _, team in pairs(frame.teams.get_children()) do
            local force = game.forces[team.name]
            local scroll = team.list.scroll
            team.player_count.caption = 'Player Count: '..#force.players
            add_players(scroll, force)
        end
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
            team_selector(player.gui.center, is_function and teams() or teams)
        end
    end
end

return Public
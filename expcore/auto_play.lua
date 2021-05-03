local Token = require 'utils.token'
local Event = require 'utils.event'
local Global = require 'utils.global'

--- Expcore
local Gui = require 'expcore.gui'
local Roles = require 'expcore.roles'
local Mini_Games = require 'expcore.Mini_games'

--- Modules
local Interface = require 'modules.commands.interface'

--- Locals
local Auto_Play = { }
local vote_categories = {
    race_map = {
        title = "Map",
        items = {
            {"", "Cursed Curves"},
            {"", "Forest Safari race"},
        }
    },
    race_fuel = {
        title = "Fuel",
        items = {
            {"", "[img=item/wood] ", {"item-name.wood"}},
            {"", "[img=item/solid-fuel] ", {"item-name.solid-fuel"}},
            {"", "[img=item/rocket-fuel] ", {"item-name.rocket-fuel"}},
            {"", "[img=item/nuclear-fuel] ", {"item-name.nuclear-fuel"}}
        },
        values = { "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel" }
    },
    race_laps = {
        title = "Laps",
        items = {
            {"", "1 Lap"},
            {"", "2 Laps"},
            {"", "3 Laps"},
        }
    }
}

--- Globals
local primitives = { enabled = false, game_running = false }
local player_data = {}

--- Register the global variables
Global.register({
    primitives = primitives,
    player_data = player_data,
},function(tbl)
    primitives = tbl.primitives
    player_data = tbl.player_data
end)

--- Add public API to /interface command
Interface.add_interface_module('Auto_Play', Auto_Play)


-- Updates the display of the welcome screen and the voting screen
-- Does not update vote counts
local function update_selector_window(player)
    local role_window = player.gui.center.role_selector_window
    local vote_window = player.gui.screen.race_vote_window
    if primitives.game_running or not primitives.enabled then
        role_window.visible = false
        vote_window.visible = false
        return
    end

    if player_data[player.index].show_welcome_screen then
        role_window.visible = true
        vote_window.visible = false
    else
        role_window.visible = false
        vote_window.visible = true

        local participant = Roles.player_has_role(player, 'Participant')
        local data = player_data[player.index]
        vote_window.caption = participant and "Joining Race" or "Spectating Race"
        data.toggle_participant.caption = participant and "Spectate Game Instead" or "Join Game Instead"
    end
end

--- Welcome screen spectate button
local SpectateButton =
Gui.element{
    type = 'button',
    caption = "Spectate Game",
    style = 'button',
}
:on_click(function(player, _)
    -- Remove welcome screen and remove player from participants
    player_data[player.index].show_welcome_screen = false
    Roles.unassign_player(player, {'Participant'}, nil, true, true)
    update_selector_window(player)
end)

--- Welcome screen join button
local JoinButton =
Gui.element{
    type = 'button',
    caption = "Join Game",
    style = 'green_button',
}
:on_click(function(player, _, event)
    -- Remove welcome screen and add player to participants
    player_data[event.player_index].show_welcome_screen = false
    Roles.assign_player(player, {'Participant'}, nil, true, true)
    update_selector_window(player)
end)

--- Toggle participation button for race vote screen
local ToggleParticipant =
Gui.element{
    type = 'button',
    caption = "Spectate Game Instead",
    style = 'button',
}
:on_click(function(player, _)
    -- Toogle participant status and update selector screen
    local participant = Roles.player_has_role(player, 'Participant')
    if participant then
        Roles.unassign_player(player, {'Participant'}, nil, true, true)
    else
        Roles.assign_player(player, {'Participant'}, nil, true, true)
    end
    update_selector_window(player)
end)


--- Counts all the votes for a voting category and returns a array with votes for
-- the given index.
local function count_votes(category)
    -- Create array for counting up votes
    local votes = {}
    for i in ipairs(vote_categories[category].items) do
        votes[i] = 0
    end

    -- Count up votes cast
    for _, player in pairs(game.connected_players) do
        local selector = player_data[player.index].vote_selectors[category]
        if selector and selector.valid then
            local choice = selector.selected_index
            if choice ~= 0 then
                votes[choice] = votes[choice] + 1
            end
        end
    end

    return votes
end

--- Counts up and returns the value selected by vote for a given category
local function select_by_votes(category)
    local votes = count_votes(category)
    local max_vote = math.max(unpack(votes))

    -- Find all entries with max_votes votes.
    local tied = {}
    for i, cast_votes in pairs(votes) do
        if cast_votes == max_vote then
            tied[#tied + 1] = i
        end
    end

    -- Pick a random from the tied votes if multiple
    local index = #tied == 1 and tied[1] or tied[math.random(#tied)]

    -- If the category has a index to value map return the mapped value.
    if vote_categories[category].values then
        return vote_categories[category].values[index]
    end

    -- Otherwise return the index that won the vote.
    return index
end

--- Create list-box list for VoteSelector
local function vote_selector_list(category)
    local votes = count_votes(category)

    -- Create list-box items with the counted votes
    local list_items = {}
    for i, item in ipairs(vote_categories[category].items) do
        list_items[#list_items + 1] = {"", votes[i], " - ", item}
    end
    return list_items
end

-- Update vote counts for all categories and selectors
local function recount_votes()
    for category in pairs(vote_categories) do
        local list_items = vote_selector_list(category)
        for _, player in pairs(game.connected_players) do
            local selector = player_data[player.index].vote_selectors[category]
            if selector and selector.valid then
                selector.items = list_items
            end
        end
    end
end

--- Vote selector for a category.  Updates vote counts in real time.
local VoteSelector =
Gui.element(function(event_trigger, parent, data, category)
    local category_data = vote_categories[category]

    -- Wrapper flow to allow multiple selectors in the same flow.
    local flow = parent.add{
        type = 'flow',
        direction = 'vertical',
    }
    flow.style.padding = 0

    flow.add{
        type = 'label',
        caption = category_data.title,
        style = 'heading_3_label',
    }

    local selector = flow.add{
        name = event_trigger,
        type = 'list-box',
        items = vote_selector_list(category),
        style = 'list_box_in_shallow_frame'
    }
    data.vote_selectors[category] = selector
    return selector
end)
:on_selection_changed(function(player, element)
    local data = player_data[player.index]

    -- Find the category for this vote selector
    local category
    for selector_category, selector in pairs(data.vote_selectors) do
        if selector == element then
            category = selector_category
        end
    end
    if not category then return end

    -- Update vote counts displayed to everyone
    local list_items = vote_selector_list(category)
    for _, connected_player in pairs(game.connected_players) do
        local selector = player_data[connected_player.index].vote_selectors[category]
        if selector and selector.valid then
            selector.items = list_items
        end
    end
end)


--- Welcome screen presenting users with a choice of joining the game or
-- spectating in the game.
local RoleSelectorWindow =
Gui.element(function(_, parent)
    local outer_frame =
    parent.add{
        name = "role_selector_window",
        type = 'frame',
        direction = 'vertical',
        caption = "Factorio Car Race",
    }
    outer_frame.style.use_header_filler = false

    local inner_frame =
    outer_frame.add{
        name = "role_selector_inner_frame",
        type = 'frame',
        direction = 'vertical',
        style = 'inside_shallow_frame_with_padding',
    }
    inner_frame.style.width = 250 + 24

    local sprite =
    inner_frame.add{
        type = 'sprite',
        sprite = 'file/modules/gui/race.png',
    }
    sprite.style.stretch_image_to_widget_size = true
    sprite.style.width = 250
    sprite.style.height = 167
    sprite.style.margin = {0, 0, 4, 0}

    local label =
    inner_frame.add{
        type = 'label',
        caption = "Be the first to the finish line in this multiplayer car race mini-game.",
    }
    label.style.single_line = false


    local dialog_row =
    outer_frame.add{
        type = 'flow',
        direction = 'horizontal',
        style = 'dialog_buttons_horizontal_flow'
    }

    SpectateButton(dialog_row)

    local pusher =
    dialog_row.add{
        type = 'empty-widget',
    }
    pusher.style.horizontally_stretchable = true
    pusher.style.height = 32

    JoinButton(dialog_row)

    return outer_frame
end)


--- Race voting window.  Presents vote selectors for race map, fuel and lap count, and
-- a button to toggle participation in the game.
local RaceVoteWindow =
Gui.element(function(_, parent, data)
    local outer_frame =
    parent.add{
        name = "race_vote_window",
        type = 'frame',
        direction = 'vertical',
        caption = "...",
    }
    outer_frame.style.use_header_filler = true
    outer_frame.location = {400, 100}

    local inner_frame =
    outer_frame.add{
        name = "race_vote_inner_frame",
        type = 'frame',
        direction = 'vertical',
        style = 'inside_shallow_frame',
    }

    local header =
    inner_frame.add{
        type = 'frame',
        direction = 'horizontal',
        caption = "Vote for map",
        style = 'subheader_frame',
    }
    header.style.padding = {4, 8}
    header.style.use_header_filler = false

    local content =
    inner_frame.add{
        type = 'flow',
        direction = 'vertical',
    }
    content.style.padding = 12

    VoteSelector(content, data, "race_map")
    VoteSelector(content, data, "race_fuel")
    VoteSelector(content, data, "race_laps")

    data.start_label = content.add{
        type = 'label',
        style = 'heading_3_label',
        caption = '...'
    }

    local dialog_row =
    outer_frame.add{
        type = 'flow',
        direction = 'horizontal',
        style = 'dialog_buttons_horizontal_flow'
    }

    data.toggle_participant = ToggleParticipant(dialog_row)
    return outer_frame
end)

--- Removes all votes cast and updates the voting selectors
local function reset_voting()
    for _, player in pairs(game.connected_players) do
        -- Reset all votes cas
        for _, selector in pairs(player_data[player.index].vote_selectors) do
            if selector.valid then
                selector.selected_index = 0
            end
        end
        update_selector_window(player)
    end
    recount_votes()
end

local function start_game(player_count)
    local map = select_by_votes("race_map")
    local fuel = select_by_votes("race_fuel")
    local laps = select_by_votes("race_laps")
    Mini_Games.start_game('Race_game', player_count, { fuel, laps, map })
end

local update_time_left
update_time_left = Token.register(function()
    local player_count = #Roles.get_role_by_name('Participant'):get_players(true)
    if not primitives.start_time and player_count > 0 then
        primitives.start_time = game.tick + 30 * 60
    elseif primitives.start_time and player_count == 0 then
        primitives.start_time = nil
    end

    local message
    if primitives.start_time then
        if primitives.start_time < game.tick then
            primitives.start_time = nil
            start_game(player_count)
            return
        end
        local seconds = math.ceil((primitives.start_time - game.tick) / 60)
        message = {"", "starting in ", seconds, " seconds"}
    else
        message = "Waiting for players to join"
    end

    for _, player in pairs(game.connected_players) do
        player_data[player.index].start_label.caption = message
    end
end)

local function create_gui(player)
    local data = {
        show_welcome_screen = true,
        vote_selectors = {}
    }
    player_data[player.index] = data
    RoleSelectorWindow(player.gui.center)
    RaceVoteWindow(player.gui.screen, data)
end

Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    create_gui(player)
end)

Event.on_init(function()
    for _, player in pairs(game.players) do
        create_gui(player)
    end
end)

Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.players[event.player_index]
    local data = player_data[player.index]
    update_selector_window(player)

    if not primitives.enabled then return end

    -- Reset votes cast by the player
    for _, selector in pairs(data.vote_selectors) do
        if selector.valid then
            selector.selected_index = 0
        end
    end

    -- Update vote counts shown to player
    for category, selector in pairs(data.vote_selectors) do
        if selector.valid then
            selector.items = vote_selector_list(category)
        end
    end
end)

Event.add(defines.events.on_player_left_game, function()
    if primitives.enabled and not primitives.game_running then
        recount_votes()
    end
end)

Event.add(Mini_Games.events.on_game_starting, function()
    if not primitives.enabled then return end

    primitives.game_running = true
    Event.remove_removable_nth_tick(60, update_time_left)
    for _, player in pairs(game.connected_players) do
        update_selector_window(player)
    end
end)

Event.add(Mini_Games.events.on_game_stopped, function()
    if not primitives.enabled then return end

    primitives.game_running = false
    Event.add_removable_nth_tick(60, update_time_left)
    reset_voting()
end)


function Auto_Play.enable()
    if primitives.enabled then return end
    primitives.enabled = true
    primitives.game_running = Mini_Games.get_current_state() ~= "Closed"

    reset_voting()

    if not primitives.game_running then
        Event.add_removable_nth_tick(60, update_time_left)
    end
end

function Auto_Play.disable()
    if not primitives.enabled then return end
    primitives.enabled = false
    primitives.start_time = nil

    for _, player in pairs(game.connected_players) do
        update_selector_window(player)
    end

    if not primitives.game_running then
        Event.remove_removable_nth_tick(60, update_time_left)
    end
end

return Auto_Play

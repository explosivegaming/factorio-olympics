
local Event = require 'utils.event' --- @dep utils.event
local Global = require 'utils.global' --- @dep utils.global
local Gui = require 'expcore.gui' --- @dep expcore.gui

----- Locals -----
local following = {}
local Public = {}

----- Global data -----
Global.register(following, function(tbl)
    following = tbl
end)

----- Public Functions -----

local follow_label
--- Used to start a player following an entity or player
-- @tparam LuaPlayer player The player that will follow the entity
-- @tparam ?LuaPlayer|LuaEntity entity The player or entity that will be followed
function Public.start(player, entity)
    assert(player and player.valid, 'Invalid player given to follower')
    assert(entity and entity.valid, 'Invalid entity given to follower')
    -- Due to current use case we do not need to handle player characters, however using associate_character it would be possible
    assert(not player.character, 'Player can not have a character while following another')

    player.close_map()
    follow_label(player.gui.screen, entity)
    player.teleport(entity.position, entity.surface)
    following[player.index] = {player, entity, entity.position}
end

--- Used to stop a player following an entity or player
-- @tparam LuaPlayer player The player that you want to stop following their entity
function Public.stop(player)
    assert(player and player.valid, 'Invalid player given to follower')

    Gui.destroy_if_valid(player.gui.screen[follow_label.name])
    following[player.index] = nil
end

--- Used to stop all players following an entity or player
function Public.stop_all()
    for key in pairs(following) do
        following[key] = nil
    end
end

----- Gui -----

--- Label used to show that the player is following, also used to allow esc to stop following
-- @element follow_label
follow_label =
Gui.element(function(event_trigger, parent, target)
    Gui.destroy_if_valid(parent[event_trigger])

    local label = parent.add{
        name = event_trigger,
        type = 'label',
        style = 'heading_1_label',
        caption = 'Following '..target.name..'.\nPress ESC or this text to stop.'
    }

    local player = Gui.get_player_from_element(parent)
    local res = player.display_resolution
    label.location = {0, res.height-150}
    label.style.width = res.width
    label.style.horizontal_align = 'center'
    player.opened = label

    return label
end)
:on_closed(Public.stop)
:on_click(Public.stop)

----- Events -----

--- Updates the location of the player as well as doing some sanity checks
-- @tparam LuaPlayer player The player to update the position of
-- @tparam ?LuaPlayer|LuaEntity entity The player or entity being followed
local function update_player_location(player, entity, old_position)
    if not player.connected or player.character then
        Public.stop(player)
    elseif player.position.x ~= old_position.x or player.position.y ~= old_position.y then
        Public.stop(player)
    elseif not entity.valid then
        Public.stop(player)
    else
        player.teleport(entity.position)
    end
end

--- Updates the locations of all players currently following something
local function update_all()
    for _, data in pairs(following) do
        update_player_location(data[1], data[2], data[3])
        data[3] = data[1].position
    end
end

-- Update the location of all players each tick
Event.add(defines.events.on_tick, update_all)

----- Module Return -----
return Public
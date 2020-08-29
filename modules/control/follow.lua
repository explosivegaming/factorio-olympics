
local Event = require 'utils.event'
local Global = require 'utils.global'

----- Locals -----
local following = {}
local Public = {}

----- Global data -----
Global.register(following, function(tbl)
    following = tbl
end)

----- Public Functions -----

--- Used to start a player following an entity or player
-- @tparam LuaPlayer player The player that will follow the entity
-- @tparam ?LuaPlayer|LuaEntity entity The player or entity that will be followed
function Public.start(player, entity)
    assert(player and player.valid, 'Invalid player given to follower')
    assert(entity and entity.valid, 'Invalid entity given to follower')
    -- Due to current use case we do not need to handle player characters, however using associate_character it would be possible
    assert(not player.character, 'Player can not have a character while following another')

    following[player.index] = {player, entity}
end

--- Used to stop a player following an entity or player
-- @tparam LuaPlayer player The player that you want to stop following their entity
function Public.stop(player)
    assert(player and player.valid, 'Invalid player given to follower')

    following[player.index] = nil
end

----- Events -----

--- Updates the location of the player as well as doing some sanity checks
-- @tparam LuaPlayer player The player to update the position of
-- @tparam ?LuaPlayer|LuaEntity entity The player or entity being followed
local function update_player_location(player, entity)
    if not player.connected then
        following[player.index] = nil
    elseif not entity.valid then
        following[player.index] = nil
    else
        player.position = entity.position
    end
end

--- Updates the locations of all players currently following something
local function update_all()
    for _, data in pairs(following) do
        update_player_location(data[1], data[2])
    end
end

-- Update the location of all players each tick
Event.add(defines.events.on_tick, update_all)

----- Module Return -----
return Public
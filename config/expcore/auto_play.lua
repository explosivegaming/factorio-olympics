local Auto_Play = require 'expcore.auto_play'
local Event = require 'utils.event'

Event.on_init(function()
    Auto_Play.enable()
end)


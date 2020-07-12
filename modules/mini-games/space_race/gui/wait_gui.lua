local Gui = require 'utils.gui'

local Public = {}

-- <Waiting GUI start>

function Public.show_gui(event)
    local frame
    local player = game.get_player(event.player_index)
    local center = player.gui.center
    local gui = center['Space-Race-Lobby']
    if (gui) then
        Gui.destroy(gui)
    end

    frame = player.gui.center.add {name = 'Space-Race-Lobby', type = 'frame', direction = 'vertical', style = 'captionless_frame'}
    frame.style.minimal_width = 300

    --Header
    local top_flow = frame.add {type = 'flow', direction = 'horizontal'}
    top_flow.style.horizontal_align = 'center'
    top_flow.style.horizontally_stretchable = true

    local title_flow = top_flow.add {type = 'flow'}
    title_flow.style.horizontal_align = 'center'
    title_flow.style.top_padding = 8
    title_flow.style.horizontally_stretchable = false

    local title = title_flow.add {type = 'label', caption = 'Welcome to Space Race'}
    title.style.font = 'default-large-bold'

    --Body

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
    local players_needed = remote.call('space-race', 'get_players_needed')
    local label = label_flow.add {type = 'label', caption = #game.connected_players .. ' out of ' .. players_needed .. ' players needed to begin!'}
    label.style.horizontal_align = 'center'
    label.style.single_line = false
    label.style.font = 'default'

end

-- <Waiting GUI end>

return Public

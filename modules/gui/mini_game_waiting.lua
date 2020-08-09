local Gui = require 'utils.gui'

local Public = {}
local GuiName = 'Mini-game-Waiting'

function Public.show_gui(event, game_name, current, required)
    local player = game.get_player(event.player_index)
    local center = player.gui.center
    local gui = center[GuiName]
    if gui then
        Gui.destroy(gui)
    end

    local frame = player.gui.center.add {name = GuiName, type = 'frame', direction = 'vertical', style = 'captionless_frame'}
    frame.style.minimal_width = 300

    --Header
    local top_flow = frame.add {type = 'flow', direction = 'horizontal'}
    top_flow.style.horizontal_align = 'center'
    top_flow.style.horizontally_stretchable = true

    local title_flow = top_flow.add {type = 'flow'}
    title_flow.style.horizontal_align = 'center'
    title_flow.style.top_padding = 8
    title_flow.style.horizontally_stretchable = false

    local name = game_name:gsub('_', ' '):lower():gsub('(%l)(%w+)', function(a,b) return string.upper(a)..b end)
    local title = title_flow.add {type = 'label', caption = 'Welcome to '..name}
    title.style.font = 'default-large-bold'

    --Body

    local content_flow = frame.add {name = 'content_flow', type = 'flow', direction = 'horizontal'}
    content_flow.style.top_padding = 8
    content_flow.style.bottom_padding = 16
    content_flow.style.left_padding = 24
    content_flow.style.right_padding = 24
    content_flow.style.horizontal_align = 'center'
    content_flow.style.horizontally_stretchable = true

    local label_flow = content_flow.add {name = 'label_flow', type = 'flow' }
    label_flow.style.horizontal_align = 'center'

    label_flow.style.horizontally_stretchable = true
    local label = label_flow.add {name = 'required', type = 'label', caption = current .. ' out of ' .. required .. ' players needed to begin!'}
    label.style.horizontal_align = 'center'
    label.style.single_line = false
    label.style.font = 'default'

end

function Public.hide(player, temp)
    local center = player.gui.center
    local gui = center[GuiName]
    if gui and temp then
        gui.visible = false
    elseif gui then
        Gui.destroy(gui)
    end
end

function Public.remove_gui(temp)
    for _, player in pairs(game.players) do
        local center = player.gui.center
        local gui = center[GuiName]
        if gui and temp then
            gui.visible = false
        elseif gui then
            Gui.destroy(gui)
        end
    end
end

function Public.update_gui(current, required)
    local caption = current .. ' out of ' .. required .. ' players needed to begin!'
    for _, player in pairs(game.connected_players) do
        local gui = player.gui.center[GuiName]
        if gui and gui.valid then
            gui.visible = true
            local required_e = gui.content_flow.label_flow.required
            if required_e and required_e.valid then
                required_e.caption = caption
            end
        end
    end
end

function Public.check_player(player)
    local gui = player.gui.center[GuiName]
    return gui and gui.valid
end

return Public

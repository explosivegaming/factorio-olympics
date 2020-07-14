local Gui = require 'utils.gui'
local Color = require 'utils.color_presets'

local Public = {}
local GuiName = 'Mini-game-Loading'

local function CalculateTime(time)
    if time > 60 then
        local minutes = (time / 3600)
        minutes = minutes - minutes % 1
        time = time - (minutes * 3600)
        local seconds = (time / 60)
        seconds = seconds - seconds % 1
        return minutes .. ' minutes and ' .. seconds .. ' seconds'
    else
        local seconds = (time - (time % 60)) / 60
        return seconds .. ' seconds'
    end
end

function Public.show_gui(event, game_name, message)
    local player = game.get_player(event.player_index)
    local center = player.gui.center
    local gui = center[GuiName]
    if gui then
        Gui.destroy(gui)
    end

    local show_timer = message == nil
    local caption = message or 'Waiting for map to generate\n\n... Please wait ...\n'

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

    local title = title_flow.add {type = 'label', caption = 'Welcome to '..game_name}
    title.style.font = 'default-large-bold'

    --Body

    local content_flow = frame.add {name = 'content_flow', type = 'flow'}
    content_flow.style.top_padding = 8
    content_flow.style.horizontal_align = 'center'
    content_flow.style.horizontally_stretchable = true

    local label_flow = content_flow.add {name = 'label_flow', type = 'flow', direction = 'vertical'}
    label_flow.style.horizontal_align = 'center'

    label_flow.style.horizontally_stretchable = true
    local label = label_flow.add {type = 'label', caption = caption}
    label.style.horizontal_align = 'center'
    label.style.single_line = false
    label.style.font = 'default'
    label.style.font_color = Color.yellow

    if show_timer then
        local time = CalculateTime(game.tick - event.tick)

        label = label_flow.add {name = 'elapsed', type = 'label', caption = '[color=blue]Time elapsed: ' .. time .. ' [/color]'}
        label.style.horizontal_align = 'center'
        label.style.single_line = false
        label.style.font = 'default'
    end
end

function Public.remove_gui()
    for _, player in pairs(game.players) do
        local center = player.gui.center
        local gui = center[GuiName]
        if gui then
            Gui.destroy(gui)
        end
    end
end

function Public.update_gui(start_tick)
    local time = CalculateTime(game.tick - start_tick)
    local caption = '[color=blue]Time elapsed: ' .. time .. ' [/color]'
    for _, player in pairs(game.connected_players) do
        local center = player.gui.center
        local gui = center[GuiName]
        if gui and gui.valid then
            local elapsed = gui.content_flow.label_flow.elapsed
            if elapsed and elapsed.valid then
                elapsed.caption = caption
            end
        end
    end
end

return Public

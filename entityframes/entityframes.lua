local ui = require('core.ui')
local command = require('core.command')
local string = require('string')
local math = require('math')

local settings = require('settings')
local account = require('account')
local packets = require('packets')
local player = require('player')

local helpers = require('helpers')
local frame_ui = require('frame_ui')
local actions = require('action_handling')

local options = require('options')

local state = {
    layout = options.setup,
    in_cutscene = false,
}

if options.setup then
    options.setup = false
    settings.save()
end

local frame_height = 35
local frames = {
    player = {
        title = 'Player',
        style = 'normal',
        width = options.frames.player.width,
        height = frame_height,
        min_height = frame_height,
        max_height = frame_height,
        resizable = true,
        moveable = true,
        closeable = false,
        color = ui.color.rgb(0,0,0,0),
    },
    target = {
        title = 'Target',
        style = 'normal',
        width = options.frames.target.width,
        height = frame_height,
        min_height = frame_height,
        max_height = frame_height,
        resizable = true,
        moveable = true,
        closeable = false,
        color = ui.color.rgb(0,0,0,0),
    },
    subtarget = {
        title = 'Sub Target',
        style = 'normal',
        width = options.frames.subtarget.width,
        height = frame_height,
        min_height = frame_height,
        max_height = frame_height,
        resizable = true,
        moveable = true,
        closeable = false,
        color = ui.color.rgb(0,0,0,0),
    },
    focustarget = {
        title = 'Focus Target',
        style = 'normal',
        width = options.frames.focustarget.width,
        height = frame_height,
        min_height = frame_height,
        max_height = frame_height,
        resizable = true,
        moveable = true,
        closeable = false,
        color = ui.color.rgb(0,0,0,0),
    },
    aggro = {
        title = 'Aggro Mobs',
        style = 'normal',
        width = options.frames.aggro.width,
        height = options.frames.aggro.entity_padding * options.frames.aggro.entity_count + 12,
        min_height = options.frames.aggro.entity_padding * options.frames.aggro.entity_count + 12,
        max_height = options.frames.aggro.entity_padding * options.frames.aggro.entity_count + 12,
        resizable = true,
        moveable = true,
        closeable = false,
        color = ui.color.rgb(0,0,0,0),
    }
}
local options_window = {
    title = 'Entity Frame Options',
    style = 'normal',
    width = 400,
    height = 200,
    resizable = false,
    moveable = true,
    closable = true, 
    selection = 'player',
}

for name, frame in pairs(frames) do
    helpers.init_frame_position(frame, options.frames[name])
end
helpers.init_frame_position(options_window, { pos = { x = -50, y = -200, x_anchor = 'center', y_anchor = 'center' } } )

ui.display(function()
    if not account.logged_in or state.in_cutscene then 
        return
    end

    for name, frame in pairs(frames) do
        if state.layout then
            frame.style = 'layout'
        else
            frame.style = 'chromeless'
        end
    end

    for name, frame in pairs(frames) do
        if options.frames[name].show then
            frames[name] = ui.window(name, frames[name], function()
                frame_ui[name].draw_window(helpers, options.frames[name], frame)
            end)

            frame_ui[name].draw_decoration(helpers, options.frames[name], frames[name])
        end
    end

    if state.layout then
        local temp_options, options_closed = ui.window('options', options_window, function()
            options, options_window.width, options_window.height = frame_ui.options(helpers, frames, options, options_window)
        end)
        options_window.x = temp_options.x
        options_window.y = temp_options.y

        if options_closed then
            state.layout = false

            for name, frame in pairs(frames) do
                --helpers.init_frame_position(frame, options.frames[name])
                frames[name].width = options.frames[name].width
            end
        end
    end
end)

player.state_change:register(function()
    state.in_cutscene = player.state_id == 4
end)

local ef = command.new('ef')
ef:register('layout', function()
    state.layout = not state.layout
end)
local ipc = require('ipc')
local event = require('core.event')
local player = require('player')
local list = require('list')
local coroutine = require('coroutine')

local participating_characters = nil


local callback = event.new()

local function exec(participant, msg)
    ipc.send('execute '..participant..' '..msg)
end

local function fire_callback(msg)
    callback:trigger(msg)
end

-- send a message to all 'particiants' with the given delay between them.
local function send_all(msg, delay, participants)
    if participants == nil then
        participants = get_participants()
    end

    local total_delay = 0
    for _,c in ipairs(participants) do
        if c == player.name then
            coroutine.schedule(fire_callback, total_delay, msg)
        else
            coroutine.schedule(exec, total_delay, c, msg)
        end
        total_delay = total_delay + delay
    end
end

local function marco()
    local player = player.name
    participating_characters = list()
    participating_characters:add(player)
    ipc.send('marco '..player)
end

-- send an IPC message to all local clients and record which come back.
local function get_participants()
    marco()
    coroutine.sleep(0.1)

    local r = participating_characters:copy()
    participating_characters = nil
    return r
end


-- handle the ipc messages. 
ipc.received:register(function(msg) 
    local args = list(table.unpack(msg:split(' ')))
    local cmd = args[1]
    args:remove(1)

    if cmd == 'marco' then
        ipc.send('polo '..player.name)

    elseif cmd == 'polo' then
        if participating_characters ~= nil then 
            participating_characters:add(args[1])
        end
    elseif cmd == 'execute' and args[1] == player.name then
        args:remove(1)
        fire_callback(table.concat(args, ' '))

    end
end)

return {
    send = send_all,
    received = callback,
    get_participants = get_participants,
}
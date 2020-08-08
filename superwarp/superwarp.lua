--[[

Copyright © 2019, Akaden of Asura
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Superwarp nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]

--[[
    Special thanks to those that have helped with specific areas of Superwarp: 
        Waypoint currency calculations: Ivaar, Thorny
        Same-Zone warp data collection: Kenshi
        Escha domain elvorseal packets: Ivaar
        Unlocked warp point data packs: Ivaar
        Menu locked state reset functs: Ivaar
        Fuzzy matching logic for zones: Lili
]]

command = require('core.command')
chat = require('core.chat')
packets = require('packet')
set = require('set')
list = require('list')
player = require('player')
entities = require('entities')
world = require('world')
memory = require('memory')
string = require('string.ext')
table = require('table')
math = require('math')
require('pack')
os = require('os')
bit = require('bit')

require('defines')
require('config_settings')

state = {
    loop_count = nil,
    fast_retry = false,
    debug_stack = list(),
    client_lock = false,
}

require('helpers')
require('packet_helpers')
delaysend = require('delaysend')

maps = require('map/maps')

function handle_before_warp()
    if options.stop_autorun_before_warp then
        debug('stopping autorun before warp')
        --windower.ffxi.follow() -- with no index, stops auto following.
        run(false) -- stop autorun
    end
    if options.command_before_warp and type(options.command_before_warp) == 'string' and options.command_before_warp ~= '' then
        debug('running command before warp: '..options.command_before_warp)
        --windower.send_command(options.command_before_warp)
    end
    if (options.target_npc or options.simulate_client_lock) and current_activity and current_activity.npc then
        set_target(current_activity.npc.id)
        coroutine.sleep(0.2) -- give target time to work.
    end
    --if options.simulate_client_lock and current_activity and current_activity.npc then
    --    client_lock(current_activity.npc.index)
    --end
end

function handle_on_arrival()
    if options.command_on_arrival and type(options.command_on_arrival) == 'string' and options.command_on_arrival ~= '' then
        debug('running command on arrival: '..options.command_on_arrival)
        --windower.send_command(options.command_on_arrival)
    end
end


local function resolve_warp(map_name, zone, sub_zone)
    if options.shortcuts and options.shortcuts[map_name] then
        local shortcut_map = options.shortcuts[map_name][zone]
        if shortcut_map ~= nil then
            if shortcut_map.sub_zone ~= nil then
                debug("found custom shortcut: "..zone.." -> "..shortcut_map.zone.." "..shortcut_map.sub_zone)
                sub_zone = shortcut_map.sub_zone
            else
                debug("found custom shortcut: "..zone.." -> "..shortcut_map.zone)
            end
            zone = shortcut_map.zone
        end
    end

    local closest_zone_name = fmatch(zone, get_keys(maps[map_name].warpdata))
    if closest_zone_name then
        local zone_map = maps[map_name].warpdata[closest_zone_name]
        if type(zone_map) == 'table' and not (zone_map.index or zone_map.shortcut) then
            if sub_zone ~= nil then
                local closest_sub_zone_name = fmatch(sub_zone, get_keys(zone_map))
                local sub_zone_map = zone_map[closest_sub_zone_name]
                if sub_zone_map then
                    sub_zone_map = resolve_shortcuts(zone_map, sub_zone_map)
                    if sub_zone_map.index then
                        debug('found warp index: '..closest_zone_name..'/'..closest_sub_zone_name..' ('..sub_zone_map.index..')')
                        return sub_zone_map, closest_zone_name..' - '..closest_sub_zone_name
                    else
                        log("Found closest sub-zone, but index is not specified.")
                        return nil
                    end
                else
                    log('Found zone ('..closest_zone_name..'), but not sub zone: "'..sub_zone..'"')
                    return nil
                end
            else
                if options.favorites and options.favorites[map_name] then
                    local favorite_result = options.favorites[map_name][get_fuzzy_name(closest_zone_name)]
                    if favorite_result then
                        local fr = tostring(resolve_sub_zone_aliases(favorite_result))
                        local sub_zone_map = zone_map[fr]
                        if sub_zone_map then
                            sub_zone_map = resolve_shortcuts(zone_map, sub_zone_map)

                            debug('Found zone ('..closest_zone_name..'), but no sub-zone listed, using favorite ('..fr..')')
                            return sub_zone_map, closest_zone_name..' - '..fr.." (F)"
                        end
                    end
                    --for fz, fsz in pairs(options.favorites[map_name]) do
                    --    if get_fuzzy_name(fz) == get_fuzzy_name(closest_zone_name) then
                    --        for sz, sub_zone_map in pairs(zone_map) do
                    --            if sz == tostring(resolve_sub_zone_aliases(fsz)) then
                    --                if sub_zone_map.shortcut then
                    --                    if zone_map[sub_zone_map.shortcut] and type(zone_map[sub_zone_map.shortcut]) == 'table' then
                    --                        debug ('found shortcut: '..sub_zone_map.shortcut)
                    --                        sub_zone_map = zone_map[sub_zone_map.shortcut]
                    --                    end
                    --                end
                    --                debug('Found zone ('..closest_zone_name..'), but no sub-zone listed, using favorite ('..sz..')')
                    --                return sub_zone_map, closest_zone_name..' - '..sz.." (F)"
                    --            end
                    --        end
                    --    end
                    --end
                end
                for sz, sub_zone_map in pairs(zone_map) do
                    if sub_zone_map.shortcut then
                        if zone_map[sub_zone_map.shortcut] and type(zone_map[sub_zone_map.shortcut]) == 'table' then
                            debug ('found shortcut: '..sub_zone_map.shortcut)
                            sub_zone_map = zone_map[sub_zone_map.shortcut]
                        end
                    end
                    debug('Found zone ('..closest_zone_name..'), but no sub-zone listed, using first ('..sz..')')
                    return sub_zone_map, closest_zone_name..' - '..sz
                end
            end
        else
            debug("Found zone settings. No sub-zones defined.")
            return zone_map, closest_zone_name    
        end
    else
        log('Could not find zone: '..zone)
        return nil
    end
end 

function do_warp(map_name, zone, sub_zone)
    local map = maps[map_name]

    local warp_settings, display_name = resolve_warp(map_name, zone, sub_zone)
    if warp_settings and warp_settings.index then
        local npc, dist = find_npc(map.npc_names.warp)

        if not npc then
            if state.loop_count > 0 then
                log('No ' .. map.long_name .. ' found! Retrying...')
                state.loop_count = state.loop_count - 1
                coroutine.schedule(do_warp, options.retry_delay, map_name, zone, sub_zone)
            else
                log('No ' .. map.long_name .. ' found!')
            end
        elseif dist > 6^2 then
            if state.loop_count > 0 then
                log(npc.name .. ' found, but too far! Retrying...')
                state.loop_count = state.loop_count - 1
                coroutine.schedule(do_warp, options.retry_delay, map_name, zone, sub_zone)
            else
                log(npc.name .. ' found, but too far!')
            end
        elseif (warp_settings.npc == nil or warp_settings.npc == npc.index) and warp_settings.zone == world.zone_id then
            log("You are already at "..display_name.."! Teleport canceled.")
            state.loop_count = 0
        elseif npc.id and npc.index then
            current_activity = {type=map_name, npc=npc, activity_settings=warp_settings, zone=zone, sub_zone=sub_zone}
            handle_before_warp()
            log('Warping via ' .. npc.name .. ' to '..display_name..'.')
            poke_npc(npc.id, npc.index)
        end
    else
        state.loop_count = 0
    end
end

function do_sub_cmd(map_name, sub_cmd, args)
    local map = maps[map_name]

    local npc, dist = find_npc(map.npc_names[sub_cmd])

    if not npc then
        if state.loop_count > 0 then
            log('No '..map.long_name..' found! Retrying...')
            state.loop_count = state.loop_count - 1
            coroutine.schedule(do_sub_cmd, options.retry_delay, map_name, sub_cmd, args)
        else
            log('No '..map.long_name..' found!')
        end
    elseif dist > 6^2 then
        if state.loop_count > 0 then
            log(npc.name..' found, but too far! Retrying...')
            state.loop_count = state.loop_count - 1
            coroutine.schedule(do_sub_cmd, options.retry_delay, map_name, sub_cmd, args)
        else
            log(npc.name..' found, but too far!')
        end
    elseif npc and npc.id and npc.index and dist <= 6^2 then
        current_activity = {type=map_name, sub_cmd=sub_cmd, args=args, npc=npc}
        handle_before_warp()
        poke_npc(npc.id, npc.index)
    end
end

function handle_warp(warp, args, fast_retry, retries_remaining)
    warp = warp:lower()
    if retries_remaining == nil then
        state.loop_count = options.max_retries
    else
        state.loop_count = retries_remaining
    end
    state.fast_retry = fast_retry

    -- because I can't stop typing "hp warp X" because I've been trained. 
    if args[1]:lower() == 'warp' or args[1]:lower() == 'w' then args:remove(1) end

    local all = set('all','a','@all'):contains(args[1]:lower())
    local party = set('party','p','@party'):contains(args[1]:lower())
    if all or party then 
        args:remove(1) 

        local participants = nil
        if all then
            participants = delaysend.get_participants()
        elseif party then
            participants = get_party_members(delaysend.get_participants())
        end
        participants = order_participants(participants)
        debug('sending warp to all: '..table.concat(participants, ', '))

        delaysend.send(warp..' '..table.concat(args, ' '), options.send_all_delay, participants)

        return
    end

    state.current_warp = warp
    state.current_args = args:copy()

    for key,map in pairs(maps) do
        if map.short_name == warp then
            local sub_cmd = nil
            if map.sub_commands then
                for sc, fn in pairs(map.sub_commands) do
                    if sc:lower() == args[1]:lower() then
                        sub_cmd = sc
                    end
                end
            end

            if sub_cmd then
                args:remove(1)
                do_sub_cmd(key, sub_cmd, args)
                return
            else
                local sub_zone_target = nil
                if map.sub_zone_targets then
                    local target_candidate = resolve_sub_zone_aliases(args:last())
                    if map.sub_zone_targets:contains(target_candidate:lower()) then
                        sub_zone_target = target_candidate
                        args:remove(#args)
                    end
                end
                local zone = world.zone_id
                local zone_target = table.concat(args, ' ')
                if map.auto_select_zone and map.auto_select_zone(zone) then
                    zone_target = map.auto_select_zone(zone)
                end
                if map.auto_select_sub_zone and map.auto_select_sub_zone(zone) then
                    sub_zone_target = map.auto_select_sub_zone(zone)
                end
                do_warp(key, zone_target, sub_zone_target)
                return
            end
        end
    end

    print("ERROR: Superwarp encountered an unresolved map name: "..tostring(warp))
end

function do_warp_command(cmd, args)
    if current_activity ~= nil then
        log('Superwarp is currently busy. To cancel the last request try "//sw cancel"')
    else
        state.debug_stack = list()
        coroutine.schedule(handle_warp, 0, cmd, args)
    end
end

function received_warp_command(cmd, ...)
    local args = list(...)
    do_warp_command(cmd, args)
end

local sw_commands = require('commands')

function handle_ipc(msg)
    local args = list(table.unpack(msg:split(' ')))
    local cmd = args[1]
    args:remove(1)
    if cmd == 'reset' then
        reset()
    else
        do_warp_command(cmd, args)
    end
end
delaysend.received:register(function(m) event_call(handle_ipc, m) end)


local function perform_next_action()
    if current_activity and current_activity.running and current_activity.action_queue and current_activity.action_index > 0 then
        local current_action = nil
        if #current_activity.action_queue >= current_activity.action_index then current_action = current_activity.action_queue[current_activity.action_index] end
        if current_action == nil then
            debug("all actions complete")
            if last_action and last_action.expecting_zone then
                debug("expecting zone")
                -- we're going to zone. 
                expecting_zone = true
            else
                state.client_lock = false
                -- not zoning. Just run the command now + delay
                coroutine.schedule(handle_on_arrival, math.max(0, options.command_delay_on_arrival))
            end

            last_activity = current_activity
            state.loop_count = 0
            current_activity = nil
            last_action = nil
        elseif not state.fast_retry and current_action.wait_packet then
            debug("waiting for packet 0x"..hex(current_action.wait_packet).." for action "..tostring(current_activity.action_index)..' '..(current_action.description or ''))
            current_action.wait_start = os.time()
            if not current_action.timeout then 
                current_action.timeout = options.default_packet_wait_timeout
            end
            local fn = function(s, ca, i, p, d)
                if ca and ca.action_index == i and not ca.canceled then
                    debug("timed out waiting for packet 0x"..hex(p).." for action "..tostring(i)..' '..(d or ''))

                    if s.loop_count > 0 then
                        reset(true)
                        log("Timed out waiting for response from the menu. Retrying...")
                        coroutine.schedule(handle_warp, options.retry_delay, s.current_warp, s.current_args, false, s.loop_count - 1)
                    else
                        reset(true)
                        log("Timed out waiting for response from the menu.")
                    end
                end
            end

            coroutine.schedule(fn, current_action.timeout, state, current_activity, current_activity.action_index, current_action.wait_packet, current_action.description)
        elseif not state.fast_retry and current_action.delay and current_action.delay > 0 then
            debug("delaying action "..tostring(current_activity.action_index)..' '..(current_action.description or '')..' for '.. current_action.delay..'s...')
            local delay_seconds = current_action.delay
            current_action.delay = nil
            last_action = current_action
            coroutine.schedule(perform_next_action, delay_seconds)
        elseif current_action.packet then
            -- just a packet, inject it.
            debug("injecting packet "..tostring(current_activity.action_index)..' '..(current_action.description or ''))
            inject(current_action.packet)
            current_activity.action_index = current_activity.action_index + 1
            if current_action.message then
                log(current_action.message)
            end
            last_action = current_action
            perform_next_action()
        elseif current_action.fn ~= nil then
            -- has a function, pass along params.
            debug("performing action "..tostring(current_activity.action_index)..' '..(current_action.description or ''))
            continue = current_action.fn(current_action.incoming_packet)
            current_activity.action_index = current_activity.action_index + 1
            if current_action.message then
                log(current_action.message)
            end
            last_action = current_action
            if continue then
                perform_next_action()
            else
                reset(true)
                if state.loop_count > 0 then
                    log("Teleport aborted. Retrying...")
                    coroutine.schedule(handle_warp, options.retry_delay, state.current_warp, state.current_args, false, state.loop_count - 1)
                end
            end
        end
    end
end

packets.incoming[0x037]:register(function(p, info) 
    if not info.injected and state.client_lock then
        -- update this packet to include _flags3 = 2
    end
end)

packets.incoming[0x052]:register(function(p, info)
    if current_activity and current_activity.running then
        local message_type = string.unpack(info.original, 'b4', 1)
        if message_type == 2 then
            if state.loop_count > 0 then
                if options.enable_fast_retry_on_interrupt then
                    log("Detected event-skip. Retrying (fast)...")
                    coroutine.schedule(handle_warp, 0.1, state.current_warp, state.current_args, true, state.loop_count - 1)
                else
                    log("Detected event-skip. Retrying...")
                    coroutine.schedule(handle_warp, 0.1, state.current_warp, state.current_args, false, state.loop_count - 1)
                end
            end
        end
    end
end)


local function handle_incoming_menu(p, info)
    if current_activity and not current_activity.running then
        current_activity.caught_poke = true
        local zone = world.zone_id
        local map = maps[current_activity.type]

        if current_activity.poked_npc_id ~= p.npc or current_activity.poked_npc_index ~= p.npc_index then
            log("Incorrect npc detected. Canceling action.")
            last_activity = current_activity
            state.loop_count = 0
            current_activity = nil
            return
        end

        last_menu = p.menu_id
        last_npc = p.npc
        last_npc_index = p.npc_index
        --debug("recorded reset params: "..last_menu.." "..last_npc)

        local validation_message = nil
        if map.validate then validation_message = map.validate(p.menu_id, zone, current_activity) end
        if validation_message ~= nil then
            log("WARNING: "..validation_message.." Canceling action.")
            last_activity = current_activity
            state.loop_count = 0
            current_activity = nil
            reset(true)
            info.blocked = true
            return
        end

        current_activity.action_queue = nil
        current_activity.action_index = 1

        if current_activity.sub_cmd then
            debug("building "..current_activity.type.." sub_command actions: "..current_activity.sub_cmd)
            current_activity.action_queue = map.sub_commands[current_activity.sub_cmd](current_activity, zone, p, options)
        else
            debug("building "..current_activity.type.." warp actions...")
            current_activity.action_queue = map.build_warp_packets(current_activity, zone, p, options)
        end

        if current_activity.action_queue and type(current_activity.action_queue) == 'table' then
            -- startup actions.

            current_activity.running = true

            coroutine.schedule(perform_next_action, 0)

            info.blocked = true
            return
        else
            log("No action required.")
            last_activity = current_activity
            state.loop_count = 0
            current_activity = nil
            return
        end
    end
end
packets.incoming[0x034]:register(function(p,i) event_call(handle_incoming_menu, p, i) end)
packets.incoming[0x032]:register(function(p,i) event_call(handle_incoming_menu, p, i) end)

function handle_wait_packet_return(packet, info)
    if current_activity and current_activity.action_queue and current_activity.running and #current_activity.action_queue >= current_activity.action_index then
        local current_action = current_activity.action_queue[current_activity.action_index]
        if current_action and current_action.wait_packet and current_action.wait_packet == info.id then
            debug("received packet 0x"..hex(info.id).." for action "..tostring(current_activity.action_index)..' '..(current_action.description or ''))
            current_action.wait_packet = nil
            current_action.incoming_packet = p
            perform_next_action()
        end
    end 
end
packets.incoming:register(function(p,i) event_call(handle_wait_packet_return, p, i) end)

packets.outgoing[0x01A]:register(function(p, info)
    if not info.injected and p.action_category == 0 and current_activity and not current_activity.canceled then
        -- USER poked something and we were in the middle of something.
        -- we can't cancel that poke. The client is execting it already. We MUST cancel the current task.
        log('Detected user interaction. Canceling current warp...')

        reset(true)
        coroutine.sleep(1)
        return false
    end
end)

world.zone_change:register(function()
    state.client_lock = false
    if expecting_zone then
        coroutine.schedule(handle_on_arrival, math.max(0, options.command_delay_on_arrival))
    end
    expecting_zone = false
end)


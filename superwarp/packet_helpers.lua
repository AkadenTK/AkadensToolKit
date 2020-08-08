function inject(p)
    local id = p.id
    local type = p.type
    p.id = nil
    p.type = nil
    if type == 'outgoing' then
        packets.outgoing[id]:inject(p)
    elseif type == 'incoming' then
        packets.incoming[id]:inject(p)
    end
end

function poke_npc(id, index)
    local first_poke = true
    while id and index and current_activity and not current_activity.caught_poke do
        current_activity.poked_npc_index = index
        current_activity.poked_npc_id = id
        if not first_poke then
            if state.loop_count > 0 then
                state.loop_count = state.loop_count - 1
                log("Timed out waiting for response from the poke. Retrying...")
            else 
                log("Timed out waiting for response from the poke.")
                current_activity = nil
                return
            end
        end

        debug("poke npc: "..tostring(id)..' '..tostring(index))
        first_poke = false
        local p = {type='outgoing', id=0x01A}
        p.target_id = id
        p.target_index = index
        p.action_category = 0
        p.param = 0
        inject(p)

        coroutine.sleep(options.default_packet_wait_timeout)
    end
end

function set_target(id)
    local p = entities.npcs:by_id(player.id)
    local t = entities.npcs:by_id(id)
    if not (p and t) then return end
    local packet = {type='incoming', id=0x58 }
    packet.player_id = p.id
    packet.target_id = t.id
    packet.player_index = p.index
    inject(packet)
end

function client_lock(target_index)
    state.client_lock = not (not target_index)
    local p = packets.incoming[0x037].last
    if state.client_lock then
        set_target(tonumber(target_index))
        p['_flags3'] = bit.bor(p['_flags3'], 2)
    else
        p['_flags3'] = bit.band(p['_flags3'], bit.bnot(2))
    end
    packets.inject(p)
end

-- Thanks to Ivaar for these two:
function general_release()
    --packets.incoming[0x052].inject(string.char(0,0,0,0,0,0,0,0))
    --packets.incoming[0x052].inject(string.char(0,0,0,0,1,0,0,0))
end
function release(menu_id)
    --packets.incoming[0x052].inject(string.pack('ICHC',0,2,menu_id,0))
    --packets.incoming[0x052].inject(string.char(0,0,0,0,1,0,0,0)) -- likely not needed

end

function reset(quiet)
    --client_lock()
    if last_npc ~= nil and last_menu ~= nil then
        general_release()
        release(last_menu)
        local packet = {type='outgoing', id=0x05B}
        packet.target_id=last_npc
        packet.option_index = 0
        packet.option_index_2 = 16384
        packet.target_index = last_npc_index
        packet.not_exiting = false
        packet.zone_id = world.zone_id
        packet.menu_id = last_menu
        inject(packet)
        last_activity = activity
        if current_activity then
            current_activity.canceled = true
        end
        current_activity = nil
        last_npc = nil
        last_npc_index = nil
        last_menu = nil

        if not quiet then
            log('Should be reset now. Please try again. If still locked, try a second reset.')
        end
    else
        general_release()
        last_npc = nil
        last_npc_index = nil
        last_menu = nil
        current_activity = nil
        if not quiet then
            log('No warp scheduled.')
        end
    end
end
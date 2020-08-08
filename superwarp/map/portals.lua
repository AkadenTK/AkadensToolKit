return {
    short_name = 'po',
    long_name = 'runic portal',
    npc_names = {
        warp = {'Runic Portal'},
        ['return'] = {'Runic Portal'},
        assault = {'Runic Portal'},
    },
    validate = function(menu_id, zone, current_activity)
        if (current_activity.sub_cmd == nil or current_activity.sub_cmd == 'assault') and zone ~= 50 then
            return "Not in Whitegate!"
        end
        if current_activity.sub_cmd == 'return' and not set(79, 52, 61, 54, 72):contains(zone) then
            return "Not in an assault staging point!"
        end
        if not (menu_id == 101 or -- no assaults

               (menu_id >= 120 and menu_id <= 215) or -- assaults.

               menu_id == 131 or -- Leujaoam
               menu_id == 134 or -- Periqia
               menu_id == 109 or -- mamool Ja
               menu_id == 109 or -- Lebros
               menu_id == 109 or -- Ilrusi
               menu_id == 117 or menu_id == 118) then -- Nyzul 
            return "Incorrect menu detected! Menu ID: "..menu_id
        end

        if current_activity.sub_cmd == nil and menu_id ~= 101 then
            return "Assault orders active. Use \"po assault\" to be taken to your assault destination."
        end
        if current_activity.sub_cmd == 'assault' and menu_id == 101 then
            return "No assault orders active."
        end
        return nil
    end,
    help_text = "[sw] po [warp/w] [all/a/@all] staging point -- warp to a designated staging point.\n[sw] po [all/a/@all] return -- Return to Whitegate from the staging point.\n[sw] po [all/a/@all] assault -- Head to your current assault tag location.\n[sw] ew [all/a/@all] domain return -- return Elvorseal.\n[sw] ew [all/a/@all] exit -- leave escha.",
    sub_zone_targets =  nil,
    auto_select_zone = function(zone)
    end,
    build_warp_packets = function(current_activity, zone, p, options)
        local actions = list()
        local packet = nil
        local menu = p.menu_id
        local npc = current_activity.npc
        local destination = current_activity.activity_settings

        local is_stock = string.unpack(p.params, 'i', 13)
        local captain = string.unpack(p.params, 'b4', 17) == 1
        local unlock_bit_start = 33

        local portal_unlocked = has_bit(p.params, unlock_bit_start + (6-destination.index))
        debug('portal unlocked: '..tostring(portal_unlocked))

        if not portal_unlocked then
            packet = {type = 'outgoing', id = 0x05B}
            packet.target_id = npc.id
            packet.option_index = 0
            packet.option_index_2 = 16384
            packet.target_index = npc.index
            packet.not_exiting = false
            
            packet.zone_id = zone
            packet.menu_id = menu
            actions:add({packet=packet, description='cancel menu', message='Destination Runic Portal is not unlocked yet!'})
            return actions
        end

        debug('captain: '..tostring(captain)..' imperial standing: '..is_stock)
        if not captain and is_stock < 200 then
            packet = {type = 'outgoing', id = 0x05B}
            packet.target_id = npc.id
            packet.option_index = 0
            packet.option_index_2 = 16384
            packet.target_index = npc.index
            packet.not_exiting = false
            
            packet.zone_id = zone
            packet.menu_id = menu
            actions:add({packet=packet, description='cancel menu', message='Not enough Imperial Standing!'})
            return actions
        end

        local option = destination.index
        if not captain then
            option = option + 1000 -- use IS if not captain.
        end
        packet = {type = 'outgoing', id = 0x05B}
        packet.target_id = npc.id
        packet.option_index = option
        packet.option_index_2 = 0
        packet.target_index = npc.index
        packet.not_exiting = false
        
        packet.zone_id = zone
        packet.menu_id = menu
        actions:add({packet=packet, delay=1+wiggle_value(options.simulated_response_time, options.simulated_response_variation), description='warp to staging point'})

        return actions
    end,
    sub_commands = {
        ['return'] = function(current_activity, zone, p, options)
            local actions = list()
            local packet = nil
            local menu = p['Menu ID']
            local npc = current_activity.npc

            log("Returning to Whitegate...")

            packet = {type = 'outgoing', id = 0x05B}
            packet.target_id = npc.id
            packet.option_index = 0
            packet.option_index_2 = 0
            packet.target_index = npc.index
            packet.not_exiting = true
            
            packet.zone_id = zone
            packet.menu_id = menu
            actions:add({packet=packet, description='change menu'})

            packet = {type = 'outgoing', id = 0x05B}
            packet.target_id = npc.id
            packet.option_index = 1
            packet.option_index_2 = 0
            packet.target_index = npc.index
            packet.not_exiting = false
            
            packet.zone_id = zone
            packet.menu_id = menu
            actions:add({packet=packet, delay=1+wiggle_value(options.simulated_response_time, options.simulated_response_variation), description='warp to whitegate'})

            return actions
        end,
        assault = function(current_activity, zone, p, options)
            local actions = list()
            local packet = nil
            local menu = p['Menu ID']
            local npc = current_activity.npc

            log("Warping to assault orders staging point...")            

            packet = {type = 'outgoing', id = 0x05B}
            packet.target_id = npc.id
            packet.option_index = 1
            packet.option_index_2 = 0
            packet.target_index = npc.index
            packet.not_exiting = false
            
            packet.zone_id = zone
            packet.menu_id = menu
            actions:add({packet=packet, delay=1+wiggle_value(options.simulated_response_time, options.simulated_response_variation), description='warp to staging point'})
            
            return actions
        end,
    },
    warpdata = {
        ['Azouph Isle'] = { index = 1},
        ['Leujaoam Sanctum'] = { index = 1},

        ['Dvucca Isle'] = { index = 2},
        ['Periqia'] = { index = 2},

        ['Mamool Ja Training Grounds'] = { index = 3},

        ['Halvung'] = { index = 4},
        ['Lebros Caverns'] = { index = 4},

        ['Ilrusi Atoll'] = { index = 5},

        ['Nyzul Isle'] = { index = 6},
    },
}
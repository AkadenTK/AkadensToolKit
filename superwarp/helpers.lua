fmatch = require('fmatch')

-- log to chat
function log(msg)
    chat.add_text('Superwarp: '..msg)
end

-- log debug message to chat or save for later recall
function debug(msg)
    if options.debug then
        log('debug: '..msg)
    else
        state.debug_stack:add('debug: '..msg)
    end
end

function hex(n)
    return string.format("%x", n)
end

function has_bit(data, x)
  return string.unpack(data, 'q', math.floor(x/8)+1, x%8)
end

-- wiggle a value up or down by a given variation
function wiggle_value(value, variation)
    return math.max(0, value + (math.random() * 2 * variation - variation))
end

-- force stacktrace
event_call = function(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print('[Error]', err)
    else
        return ok, err
    end
end

-- get the distance between a and b squared. to get the real distance, take sqrt.
function distance_sqd(a, b)
    local dx, dy = b.x-a.x, b.y-a.y
    return dy*dy + dx*dx
end

-- get a "fuzzy" name. lowercased, removed symbols and spaces.
function get_fuzzy_name(name)
    return tostring(name):lower():gsub("%s", ""):gsub("%p", "")
end

function get_keys(t)
    local keys = list()
    for k, v in pairs(t) do
        keys:add(k)
    end
    return keys
end

-- order local instance names by options. 
function order_participants(participants)
    if options.send_all_order_mode ~= 'alphabetical' then
        participants:remove_element(player.name)
    end
    table.sort(participants)
    if options.send_all_order_mode == 'melast' then
        participants:add(player.name)
    elseif options.send_all_order_mode == 'mefirst' then
        participants:insert(player.name, 1)
    end
    return participants
end

-- find an npc given a name.
function find_npc(needles)
    local target_npc = nil
    local distance = nil
    local p = entities.pcs:by_id(player.id).position
    for i, v in pairs(entities.npcs) do
        if v then
            local d = distance_sqd(v.position, p)
            for i, needle in ipairs(needles) do
                if set(1, 2, 3):contains(v.target_type) and (not target_npc or d < distance) and string.find(get_fuzzy_name(v.name), "^"..get_fuzzy_name(needle)) then
                    target_npc = v
                    distance = d
                end
            end
        end
    end
    return target_npc, distance
end


--- resolve sub-zone target aliases (ah -> auction house, etc.)
function resolve_sub_zone_aliases(raw)
    if raw == nil then return nil end
    if type(raw) == 'number' then return raw end
    local raw_lower = raw:lower()

    if sub_zone_aliases[raw_lower] then return sub_zone_aliases[raw_lower] end

    return raw
end

function resolve_shortcuts(t, selection)
    if selection.shortcut == nil then return selection end

    return resolve_shortcuts(t, t[selection.shortcut])
end

run = function(first, second, third, ...)
    local x
    local y
    local auto_run

    local args = select('#', ...)
    if args <= 1 then
        -- Walk based on direction
        if first == false then
            -- Stop walking (false provided)
            x = 0
            y = 0
            auto_run = false
        else
            local dir
            if args == 0 or first == true then
                -- Walk in current direction (true provided)
                dir = target.me.heading
            else
                -- Walk in direction provided (in radians)
                dir = first
            end
            x = math.cos(dir)
            -- Minus, because SE says so
            y = -math.sin(dir)
            auto_run = true
        end
    elseif args <= 3 then
        -- Walk in direction of provided coordinates (only X and Y are relevant, Z can be ignored)
        -- X points east, Y points north (mimics game axes)
        x = first
        y = second
        auto_run = true
    end

    local follow = memory.follow
    follow.postion.x = x
    follow.postion.y = y
    follow.auto_run = auto_run
end
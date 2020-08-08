local sw = command.new('sw')
for k,map in pairs(maps) do
    map.cmd = command.new(map.short_name)
    map.cmd:register(function(...) event_call(received_warp_command, map.short_name, ...) end, '<commands:string()>*')
    sw:register(map.short_name, function(...) event_call(received_warp_command, map.short_name, ...) end, '<commands:string()>*')
end

local function toggle_debug(s)
    if s == nil then 
        s = not (options.debug or false)
    elseif set('true', 'on', 'yes'):contains(tostring(s):lower()) then
        s = true
    elseif set('false', 'off', 'no'):contains(tostring(s):lower()) then
        s = false
    end

    options.debug = s
    debug('Debug is now: '..tostring(s))
    if options.debug then 
        for _, m in ipairs(state.debug_stack) do
            log(m)
        end
    end
end

sw:register('debug', function(...) event_call(toggle_debug, ...) end, '[state:one_of(true,false,on,off,yes,no)]')

local function handle_reset(...)
    reset()    
    local args = list(...)
    if args[1] and args[1]:lower() == 'all' then
        ipc.send('reset')
    end
end

sw:register('reset', function(...) event_call(handle_reset, ...) end)
sw:register('cancel', function(...) event_call(handle_reset, ...) end)

return sw
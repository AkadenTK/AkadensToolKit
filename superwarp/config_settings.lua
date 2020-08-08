settings = require('settings')

local defaults = {
    debug = false,
    send_all_delay = 0.4,                   -- delay (seconds) between each character
    max_retries = 6,                        -- max retries for loading NPCs.
    retry_delay = 2,                        -- delay (seconds) between retries
    simulated_response_time = 0,            -- response time (seconds) for selecting a single menu item. Note this can happen multiple times per warp.
    simulated_response_variation = 0,       -- random variation (seconds) from the base simulated_response_time in either direction (+ or -)
    default_packet_wait_timeout = 5,        -- timeout (seconds) for waiting on a packet response before continuing on.
    enable_same_zone_teleport = true,       -- enable teleporting between points in the same zone. This is the default behavior in-game. Turning it off will look different than teleporting manually.
    enable_fast_retry_on_interrupt = false, -- after an event skip event, attempt a fast-retry that doesn't wait for packets or delay.
    use_tabs_at_survival_guides = false,    -- use tabs instead of gil at survival guides.
    stop_autorun_before_warp = true,        -- stop autorunning before using any warp system or subcommand
    command_before_warp = '',               -- inject this windower command before using any warp system or subcommand
    command_delay_on_arrival = 5,           -- delay before running command_on_arrival
    command_on_arrival = '',                -- inject this windower command on arriving at the next location.
    target_npc = true,                      -- locally target the warp/subcommand npc.
    simulate_client_lock = false,           -- lock the local client during a warp/subcommand, simulating menu behavior.
    send_all_order_mode = 'melast',         -- order modes: melast, mefirst, alphabetical
    favorites = {},                         -- favorite destination by zone. When warping to this zone, superwarp will prioritize this destination
    shortcuts = {},                         -- shorthand strings to warp to a zone or zone/destination pair
}


options = settings.load(defaults)

-- bounds checks.
if options.send_all_delay < 0 then
    options.send_all_delay = 0
end
if options.send_all_delay > 5 then
    options.send_all_delay = 5
end
if options.max_retries < 1 then
    options.max_retries = 1
end
if options.max_retries > 20 then
    options.max_retries = 20
end
if options.retry_delay < 1 then
    options.retry_delay = 1
end
if options.retry_delay > 10 then
    options.retry_delay = 10
end
if options.simulated_response_time < 0 then
    options.simulated_response_time = 0
end
if options.simulated_response_time > 5 then
    options.simulated_response_time = 5
end
if options.default_packet_wait_timeout < 1 then
    options.default_packet_wait_timeout = 1
end
if options.default_packet_wait_timeout > 10 then
    options.default_packet_wait_timeout = 10
end
settings.save()
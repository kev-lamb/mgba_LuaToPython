json = require "json"
lastkeys = nil
server = nil
ST_sockets = {}
nextID = 1

-- CHANGE THIS TO THE FULL FILEPATH FOR THE DIRECTORY YOU HAVE THE GITHUB CLONED INTO
script_filepath = "/Users/kevlamb/penncode/cis400/luascripts"

desired_move = nil
memorybuffer = console:createBuffer("Memory") -- used for debugging
battleflag = "emu:read32(0x4000)"
locationString = ""
gameState = {}
-- used so actions after input delay frames rather than when its just divisible
last_action_frame = 0

modebuffer = console:createBuffer("Agent Mode") -- tells us whether we are acting in traversal or battle mode
modebuffer:print("Traversal Mode") -- we start in traversal mode

traversal = true

prevZoneID = 0
zone_id = 0

default_delay = 60
input_delay = default_delay

local partyGetter = require"battledata"

local KEY_NAMES = { "A", "B", "s", "S", "<", ">", "^", "v", "R", "L" }

-- queue data structure for next actions -- 
action_q = {}
action_q.first = 0
action_q.last = -1
action_q.data = {}
-- insert action to back of the queue
function insert(q, val)
   q.last = q.last + 1
   q.data[q.last] = val
end
-- pop the oldest action from the queue
function remove(q)
    local rval = {-1, default_delay}
    if (q.first <= q.last) then
        rval = q.data[q.first]
        q.data[q.first] = nil
        q.first = q.first + 1
    end
    return rval
end
-- set the buttons to reflect the oldest action from the client
function perform_next_action(q)
    --console:log(q.data)
    local action = remove(q)

    console:log(string.format("performing action %d", action[1]))
    -- second number is the associated delay after pressing this input
    input_delay = action[2]
    emu:setKeys(0) -- Reset pressed butttons
    -- first number is the actual button press
	emu:addKey(action[1]) -- Press the desired button
end
-- given the provided list of actions, add them to the actions queue in the order they were provided
function add_actions(actions, q)
    for _, a in pairs(actions) do
        -- if input delay is provided, use it
        if type(a) == "table" then
            insert(q, a)
        else
            -- if no input delay is provided, use default input delay
            insert(q, {a, default_delay})
        end
    end
end

-- returns true if there are no elements in the queue
function queue_is_empty(q)
    return q.first > q.last
    -- if val then
    --     return true
    -- end
    -- return q.data[q.first] == nil
end

function ST_stop(id)
	local sock = ST_sockets[id]
	ST_sockets[id] = nil
	sock:close()
end

function ST_format(id, msg, isError)
	local prefix = "Socket " .. id
	if isError then
		prefix = prefix .. " Error: "
	else
		prefix = prefix .. " Received: "
	end
	return prefix .. msg
end

function ST_error(id, err)
	console:error(ST_format(id, err, true))
	ST_stop(id)
end

-- TODO: implement function to reset emulator to save state file
function loadState(filepath)
    if emu:loadStateFile(script_filepath .. filepath, 2) then
        console:log(string.format("reset to save state %s", filepath))
    else
        console:log(string.format("unable to reset to save state %s", filepath))
    end
end

-- used when the agent needs additional information outside of the normal state for the given mode
-- ex: when training the battle agent and the battle ends, we are in traversal mode, but the agent
--      needs the HP of the enemy mon to determine if the battle was won or lost
--[[
    example request formats:
    {"battle"} -> send battle data
    {"traversal"} -> send traversal data
    {"reset", filepath} -> load savestate at filepath
]]
function send_requested_info(sock, request)
    local req_type = request[1]
    if req_type == "battle" then
        -- need to send battle data to client (shouldnt be happening anymore)
		if sock then sock:send(json.encode(gameState["Battle"])) end
    elseif req_type == "traversal" then
        -- need to send traversal data to client (shouldnt be happening anymore)
        if sock then sock:send(json.encode(gameState["Traversal"])) end
    elseif req_type == "reset" then
        -- load statefile provided as second argument of request
        console:log("resetting state")
        loadState(request[2])
        -- send the initial state of this environment
        if sock then sock:send(ST_getstate()) end
    end
    -- may need to add more cases here as we go on
end

function ST_received(id)
	local sock = ST_sockets[id]
	if not sock then return end
	while true do
		local p, err = sock:receive(1024)
		if p then
            local actions = json.decode(p)

            if type(actions[1]) == 'string' then
                -- if message is a string, send the requested information back thru the socket
                send_requested_info(sock, actions)
            else
                --otherwise weve received an action request, add to action queue
                add_actions(actions, action_q)
            end
			-- desired_move = tonumber(actions[1]) -- Convert received byte string to int
            -- -- add the client action to the back of the action queue
            -- insert(action_q, desired_move)
			-- emu:setKeys(0) -- Reset pressed butttons
			-- emu:addKey(desired_move) -- Press the desired button
            -- console:log(p:match("^(.-)%s*$"))
            -- emu:clearKeys(0)
            -- emu:addKey(0)
            -- emu:runFrame()
			console:log(ST_format(id, p:match("^(.-)%s*$")))
		else
			if err ~= socket.ERRORS.AGAIN then
				console:error(ST_format(id, err, true))
				ST_stop(id)
			end
			return
		end
	end
end

-- not being used right now
function ST_scankeys()
	local keys = emu:getKeys()
	if keys ~= lastkeys then
		lastkeys = keys
		local msg = "["
		for i, k in ipairs(KEY_NAMES) do
			if (keys & (1 << (i - 1))) == 0 then
				msg = msg .. " "
			else
				msg = msg .. k;
			end
		end
		msg = msg .. "]\n"
		for id, sock in pairs(ST_sockets) do
			if sock then sock:send(msg) end
		end
	end
end

function printkeys()
    local msg = "["
	for i, k in ipairs(KEY_NAMES) do
		if (keys & (1 << (i - 1))) == 0 then
			msg = msg .. " "
		else
			msg = msg .. k;
		end
	end
	msg = msg .. "]\n"
    return msg
end

--[[
    game state is sent to the python client in json format for easy parsing
    Example Traversal Mode Data:
    {
        "Mode" : "Traversal",
        "Data" : {
            "X" : x_pos,
            "Y" : y_pos,
            "Zone" : zone_id
        }
    }

    Example Battle Mode Data:
    {
        "Mode" : "Battle",
        "Data" : {
            "Party" : [
                {
                    "Species" : "Torchic",
                    "T1" : 10,
                    "T2" : 1,
                    "HP" : 18,
                    "MaxHP" : 20,
                    "Atk" : 12,
                    "Def" : 9,
                    "SpA" : 14,
                    "SpD" : 10,
                    "Spe" : 8,
                    "Moves" : [
                        {
                            "Acc" : 100,
                            "BP" : 40,
                            "Eff" : 0,
                            "Type" : 0
                        },
                        {
                            "Acc" : 100,
                            "BP" : 0,
                            "Eff" : 18,
                            "Type" : 0
                        }
                    ]

                },
                {
                    MON 2 info
                },
                { ... }
            ],
            "Enemy" : {
                "Species" : "Poochyena",
                "T1" : 11,
                "T2" : 11,
                "HP" : 8,
                "MaxHP" : 13,
                "Atk" : 7,
                "Def" : 6,
                "SpA" : 6,
                "Spe" : 5
            }
        }
    }
]]


function ST_getstate()
	-- local keys = emu:getKeys()
	-- local msg = "["
	-- for i, k in ipairs(KEY_NAMES) do
	-- 	if (keys & (1 << (i - 1))) == 0 then
	-- 		msg = msg .. " "
	-- 	else
	-- 		msg = msg .. k;
	-- 	end
	-- end
	-- msg = msg .. "]\n"
    -- msg = msg .. statusString
    -- -- msg = msg .. enemyString
	-- msg = msg .. ST_getlocation()
    -- -- msg = msg .. partyGetter.partyStatus(game)
    -- -- console:log("hello")
    if traversal then
        gameState["Mode"] = "Traversal"
    else
        gameState["Mode"] = "Battle"
    end
    return json.encode(gameState)
end

function ST_accept()
	local sock, err = server:accept()
	if err then
		console:error(ST_format("Accept", err, true))
		return
	end
	local id = nextID
	nextID = id + 1
	ST_sockets[id] = sock
	sock:add("received", function() ST_received(id) end)
	sock:add("error", function() ST_error(id) end)
	console:log(ST_format(id, "Connected"))
end

-- Reads the current local X and Y coordinates as well as the Zone ID
function ST_getlocation()
	local x_coord = emu:read8(tonumber(0x02025A00)) -- X coord is the first byte at this offset
	local y_coord = emu:read32(tonumber(0x02025A00)) >> 16 -- From this offset, we need to read the first 4 bytes, and then shift out the first 2 to get the Y coord
	prevZoneID = zone_id -- Before updating the zone ID, save the current one
	zone_id = emu:read32(tonumber(0x02025A30)) >> 16 -- From this offset, we need to read the first 4 bytes, and then shift out the first 2 to get the zone ID
    local location = {
            x=x_coord,
            y=y_coord,
            zone=zone_id
        }
    gameState["Traversal"] = location
    locationString = json.encode(location)
	local msg = "[X: " .. x_coord .. ", Y: " .. y_coord .. ", Zone ID: " .. zone_id .. "]\n"
	return msg
end

function frame_dif(frame)
    return frame - last_action_frame
end

-- sends game state over all active socket connections every 60 frames
function ST_poll()
    -- console:log(ST_getstate())
    -- printMemoryOfInterest(memorybuffer)
    -- TODO: number of frames we wait should maybe be variable with the action returns from client?
    --          this way we arent performing useless actions during animations in battle, for example
    if frame_dif(emu:currentFrame()) % input_delay == 0 then -- input delay is 60 frames by default
        -- reset last action frame
        last_action_frame = emu:currentFrame()
        -- perform next action
        perform_next_action(action_q)
        local state = ST_getstate()
        -- console:log(state)
        -- only send state to client if we need a new action
        if not queue_is_empty(action_q) then
            -- console:log("no action needed")
            return --if there are more button presses we dont need a new action yet
        end
        -- console:log("past getn")
        for id, sock in pairs(ST_sockets) do
			if sock then sock:send(state) end
		end
    end
end

function printMemoryOfInterest(buffer)
    -- buffer:clear()
    local stuff = emu:read32(0x4000)
    -- local wildflag = emu:read8(0x8c1)
    -- local tempvars = emu:read32(0x4000)
    if stuff ~= battleflag then
        battleflag = stuff
        console:log(string.format("%x",stuff))
    end
    -- buffer:print(string.format("0x4000 = %x\n 0x4001 = %x\n 0x4002 = %x\n 0x4003 = %x\n 0x4004 = %x\n 0x4005 = %x\n 0x4006 = %x\n 0x4007 = %x\n 0x4008 = %x\n 0x4009 = %x\n 0x400A = %x\n 0x400B = %x, 0x400C = %x\n 0x400D = %x\n 0x400F = %x",
    -- emu:read8(0x4000),
    -- emu:read8(0x4001),
    -- emu:read8(0x4002),
    -- emu:read8(0x4003),
    -- emu:read8(0x4004),
    -- emu:read8(0x4005),
    -- emu:read8(0x4006),
    -- emu:read8(0x4007),
    -- emu:read8(0x4008),
    -- emu:read8(0x4009),
    -- emu:read8(0x400a),
    -- emu:read8(0x400b),
    -- emu:read8(0x400c),
    -- emu:read8(0x400d),
    -- emu:read8(0x400e),
    -- emu:read8(0x400f)))
    -- if battleflag ~= emu:read32(0x4000) then
    --     battleflag = emu:read32(0x00)
    --     console:log(string.format("battle flag changed to %x!", battleflag))
    -- end

end

function traversalHandler()
    -- switch to battle mode if we have entered a battle
    -- console:log("in traversal handler")
    if enteredBattle() then
        -- change to battle mode
        modebuffer:clear()
        modebuffer:print("Battle Mode")
        traversal = false
        return
    end

    --otherwise run the traversal agent
    -- NORMAL TRAVERSALE STUFF GOES HERE
    ST_poll()
end

function battleHandler()
    --switch to traversal mode if the battle 
    -- console:log("in the battle handler")
    if battleOver() then
        -- change to traversal mode
        modebuffer:clear()
        modebuffer:print("Traversal Mode")
        traversal = true
        return
    end

    --otherwise run the battling agent
    -- BATTLE AGENT STUFF GOES HERE
    ST_poll()

end

function agent_Action()
    ST_getlocation()
    if traversal then
        traversalHandler()
        return
    end
    battleHandler()
end

-- booleans for traversal vs. battle mode

function enteredBattle()
    -- if we were in traversal mode and the enemy party has changed, we entered a battle
	if (enemyString ~= prevEnemyString) then
		return true
	end

	return false
end

function battleOver()
    -- if we win, we know battle is over because all enemy hps are at 0
	if (all_enemy_ko) then
		return true
	end
    -- if we lose, we white out and out location changes (battle over if zoneid changes when in battle mode)
	if (zone_id ~= prevZoneID) then
		return true
	end

	return false
end


-- callbacks:add("keysRead", ST_scankeys)
callbacks:add("frame", agent_Action)

local port = 8888
server = nil
while not server do
	server, err = socket.bind(nil, port)
	if err then
		if err == socket.ERRORS.ADDRESS_IN_USE then
			port = port + 1
		else
			console:error(ST_format("Bind", err, true))
			break
		end
	else
		local ok
		ok, err = server:listen()
		if err then
			server:close()
			console:error(ST_format("Listen", err, true))
		else
			console:log("Socket Server Test: Listening on port " .. port)
			server:add("received", ST_accept)
		end
	end
end


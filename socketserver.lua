lastkeys = nil
server = nil
ST_sockets = {}
nextID = 1

desired_move = nil
memorybuffer = console:createBuffer("Memory") -- used for debugging
battleflag = "emu:read32(0x4000)"

modebuffer = console:createBuffer("Agent Mode") -- tells us whether we are acting in traversal or battle mode
modebuffer:print("Traversal Mode") -- we start in traversal mode

traversal = true

prevZoneID = 0
zone_id = 0

local partyGetter = require"battledata"

local KEY_NAMES = { "A", "B", "s", "S", "<", ">", "^", "v", "R", "L" }

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

function ST_received(id)
	local sock = ST_sockets[id]
	if not sock then return end
	while true do
		local p, err = sock:receive(1024)
		if p then
			desired_move = tonumber(p) -- Convert received byte string to int
			emu:setKeys(0) -- Reset pressed butttons
			emu:addKey(desired_move) -- Press the desired button
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


function ST_getstate()
	local keys = emu:getKeys()
	local msg = "["
	for i, k in ipairs(KEY_NAMES) do
		if (keys & (1 << (i - 1))) == 0 then
			msg = msg .. " "
		else
			msg = msg .. k;
		end
	end
	msg = msg .. "]\n"
    msg = msg .. partyString
    msg = msg .. enemyString
	msg = msg .. ST_getlocation()
    -- msg = msg .. partyGetter.partyStatus(game)
    -- console:log("hello")
	return msg
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
	local msg = "[X: " .. x_coord .. ", Y: " .. y_coord .. ", Zone ID: " .. zone_id .. "]\n"
	return msg
end

-- sends game state over all active socket connections every 60 frames
function ST_poll()
    -- console:log(ST_getstate())
    -- printMemoryOfInterest(memorybuffer)
    if emu:currentFrame() % 60 == 0 then
        local state = ST_getstate()
        -- console:log(state)
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


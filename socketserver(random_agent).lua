lastkeys = nil
server = nil
ST_sockets = {}
nextID = 1

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
	local zone_id = emu:read32(tonumber(0x02025A30)) >> 16 -- From this offset, we need to read the first 4 bytes, and then shift out the first 2 to get the zone ID
	local msg = "[X: " .. x_coord .. ", Y: " .. y_coord .. ", Zone ID: " .. zone_id .. "]\n"
	return msg
end

-- sends game state over all active socket connections every 60 frames
function ST_poll()
	
    if emu:currentFrame() % 60 == 0 then
		--emu:setKeys(0) -- Resets active keys to no keys being pressed  				--UNCOMMENT FOR RANDOM AGENT
		--nextbutton = math.random(0, 9) -- Chooses a random button to press			--UNCOMMENT FOR RANDOM AGENT
		--emu:addKey(nextbutton) -- Presses that button									--UNCOMMENT FOR RANDOM AGENT

        local state = ST_getstate()														--FOR TRACKING BUTTON PRESSES
		local location_info = ST_getlocation()
		console:log(location_info)
        --console:log(state)															--FOR TRACKING BUTTON PRESSES
        for id, sock in pairs(ST_sockets) do
			if sock then sock:send(location_info) end
			--if sock then sock:send(state) end											--FOR TRACKING BUTTON PRESSES
		end

    end
end


--callbacks:add("keysRead", ST_scankeys)
callbacks:add("frame", ST_poll)

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
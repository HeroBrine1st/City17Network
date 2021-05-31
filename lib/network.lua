local network = {}
local component = require("component")
local computer = require("computer")
local modem = component.modem
local hashes = {}
local event = require("event")
local lifeTime = 30
local port = 32456
local state = false
local broadcastAddress = "ffffffff-ffff-ffff-ffff-fffffffffff"
local function genhash()
  return string.char(math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
                     math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255))
end

local CODES = {
	message = "network/message",
	pong = "network/pong",
}

local function hashCheck(hash)
	for key, value in pairs(hashes) do
		if computer.uptime() - value > lifeTime then
			hashes[key] = nil
		end
	end
	if hash then
		if not hashes[hash] then
			hashes[hash] = computer.uptime()
			return true
		end
		return hashes[hash] == nil
	end
end

local modems = {}
local mainModem

local function newModem()
	local minDist = 400
	local newModem
	for key, value in pairs(modems) do
		minDist = math.min(value,minDist)
		newModem = value == minDist and key or newModem
	end
	mainModem = newModem
end

local function listener(name,receiver,sender,port1,distance,code,hash,nSender,nReceiver,...)
	local msg = {...}
	if hashCheck(hash) and port1 == port then
		if code == CODES.message then
			if nReceiver == receiver or nReceiver == broadcastAddress then
				computer.pushSignal("network_message",receiver,nSender,...)
				modems[sender] = distance
				newModem()
			end
		end
	end
	if code == CODES.pong then
		modems[sender] = distance
		newModem()
	end
end



local function send(receiver,...)
	if not mainModem then return nil, "No connection" end
	modem.send(mainModem,port,CODES.message,genhash(),modem.address,receiver,...)
end

function network.connect()
  if not state then
  	event.listen("modem_message",listener)
  	modem.open(port)
    state = not state
    return true
  end
  return false
end

function network.disconnect()
  if state then
  	modem.close(port)
  	event.ignore("modem_message",listener)
    state = not state
    return true
  end
  return false
end

network.send = send

return network
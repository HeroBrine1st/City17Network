local network = {}
local component = require("component")
local computer = require("computer")
local modem = component.modem
local hashes = {}
local event = require("event")
local inet = require("internet")
local lifeTime = 30
local port = 32456
local broadcastAddress = "ffffffff-ffff-ffff-ffff-fffffffffff"
local function genhash()
  return string.char(math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
          					 math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
          					 math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
          					 math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
          					 math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255),
          					 math.random(0, 255), math.random(0, 255),math.random(0, 255), math.random(0, 255))
end

local function tunnelBroadcast(...)
	for address, componentType in component.list("tunnel") do
		local proxy = component.proxy(address)
		proxy.send(...)
	end
end

local function log(...)
  local args = {...}
  local str = "[OPENNET RETRANSLATOR] "
  for i = 1, #args do
    str = str .. tostring(args[i]) .. "    "
  end
  local success, reason = inet.request("http://city17.xyz/net.php",str)
  print(str)
  if not success then print("Ошибка логгинга на внешний сервер:" .. reason) end
end

local CODES = {
	message = "network/message",
	ping = "network/ping",
	pong = "network/pong",
}

local function hashCheck(hash)
	for key, value in pairs(hashes) do
		if (computer.uptime() - value) > lifeTime then
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
local function concatStrs(...)
	local args = {...}
	local str = ""
	for _,value in pairs(args) do
		str = str .. tostring(value) .. " "
	end
	return str
end

local function listener(name,receiver,sender,port1,distance,code,hash,nSender,nReceiver,...)
	if hashCheck(hash) then
		if code == CODES.message then
	      	log("From",nSender,"to",nReceiver,"Message:",...)
	      	if nReceiver and nSender and hash then
	  			tunnelBroadcast(code,hash,nSender,nReceiver,...)
	  			if nReceiver ~= broadcastAddress then
	  				modem.send(nReceiver,port,code,hash,nSender,nReceiver,...)
	      		else
	      			modem.broadcast(port,code,hash,nSender,nReceiver,...)
	      		end
			end
		end
	end
end
modem.open(port)

while true do
  listener(event.pull(1,"modem_message"))
  modem.broadcast(port,CODES.pong)
end
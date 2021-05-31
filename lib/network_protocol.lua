local protocol = {}
local requests = {}
local codes = {
	REQUEST = "NETWORK_REQUEST",
	CHUNK = "CHUNK",
	RESPONCE = "RESPONCE",
}
local networkLib = require("network")
local fs = require("filesystem")
local crypt = require("crypt")
local computer = require("computer")
local serial = require("safeSerial")
local event = require("event")

local function md5Check(data,hash)
	data = tostring(data)
	local md5 = crypt.md5(data)
	return md5 == hash
end

local network = {
	send = networkLib.send,
	message_code = "network_message"
}

local function busySleep(time)
	local deadline = computer.uptime() + time
	while computer.uptime() < deadline do
		--нагружаем процессор на 100% 
		--(на самом деле все нагружается при проверке условия)
	end
end

function protocol.request(address,path,data)
	if type(data) == "table" then data = serial.serialize(data,"#") end
	if not path then path = "/" end
	if not path:sub(1,1) == "/" then path = "/" .. path end
	if data and #data > 7168 then return nil, "Too large data" end
	network.send(address,serial.serialize({path=path,data=data,type=codes.REQUEST}))
	local addrSend,responce
	while true do
		_,_,addrSend,responce = event.pull(5,network.message_code)
		if addrSend == address then break end
	end
	local code
	if not responce then return nil,"Connection timed out" end
	responce = serial.unserialize(responce)
	if type(responce) == "table" and responce["type"] == codes.RESPONCE then
		local md5All = responce["hash"]
		local lenght = responce["Content-Lenght"]
		code = responce["responce_code"]
		local buffer = ""
		local success = true
		while success do
			if #buffer > lenght-1 then break end
			local sign,addrReceive,addrSend,chunk = event.pull(5,network.message_code)
			if chunk and addrSend == address then
				chunk2 = serial.unserialize(chunk)
				if chunk2 and chunk2["type"] == codes.CHUNK then
					local data = chunk2["data"]
					local hash = chunk2["hash"]
					if md5Check(data,hash) then
						buffer = buffer .. data
					else success = false end		
				end
			end
			if not chunk then success = false break end
		end
		if success == false then 
			return nil, "Connetion refused",buffer
		end
		local ch = md5Check(buffer,md5All)
		if not ch then
			return nil, "File transfer attacked by man in-the-middle", buffer
		end
		return buffer
	end
end

function protocol.send(address,data,code,headers)
	if not code then code = 200 end
	local md5All = crypt.md5(data)
	local responce = {
		["hash"] = md5All,
		["Content-Lenght"] = #data,
		["type"] = codes.RESPONCE,
		["responce_code"] = code,
	}
	if headers then
		for key, value in pairs(headers) do
			responce[key] = value
		end 
	end
	network.send(address,serial.serialize(responce))
	while true do
		busySleep(0.1)
		local data1 = data:sub(1,1024)
		data = data:sub(1025)
		local EOS = false
		if data == "" or not data then EOS = true end
		local flags
		if EOS then flags = "110" else flags = "010" end
		local chunk = {
			["data"] = data1,
			["hash"] = crypt.md5(data1),
			["type"] = codes.CHUNK,
			["flags"] = flags,
		}
		network.send(address,serial.serialize(chunk))
		if EOS then break end
	end
	return true
end

local UDP_codes = {
	closing = "CLOSE_SOCKET_STREAM",
	head = "UDP/SOCKET",
	ping = "UFP/PING",
	pong = "TCP/PONG",
}

local UDP = {}
UDP.__index = UDP

function UDP:write(data)
	if #data > 7168 then error("Too large data") end
 	return network.send(self.address,UDP_codes.head .. data)
end

function UDP:read()
	if not self.buffer then self.buffer = {} end
	local returning = self.buffer[1] or ""
	table.remove(self.buffer,1)
	return returning
end

function UDP:ping()
	network.send(self.address,TCP_codes.ping)
end

function UDP:close()
	network.send(self.address,TCP_codes.closing)
	event.ignore(network.message_code,self.listener)
	require("computer").pushSignal("stream_close",self.address)
	self.status1 = "closed"
end

function UDP:status()
	return self.status1
end

function protocol.openUDP(address)
	local handle = {address=address,buffer={},status1="opened"}
	function handle.listener(signal,receiver,sender,data)
		if sender == handle.address then
			if data:sub(1,#UDP_codes.head) == UDP_codes.head then 
				data = data:sub(#UDP_codes.head+1,-1)
				table.insert(handle.buffer,data)
			elseif data == UDP_codes.closing then
				TCP:close()
			elseif data == UDP_codes.ping then
				network.send(handle.address,TCP_codes.pong)
			elseif data == UDP_codes.pong then
				require("computer").pushSignal("udp_pong",handle.address)
			end
		end
	end
	event.listen(network.message_code,handle.listener)
	setmetatable(handle,UDP)
	handle:ping()
	return handle
end


protocol.codes = codes
protocol.UDP_codes = UDP_codes

local streams = {}
local socket = {}
local TCP_codes = {
	head="TCP/broadcast",
	close="TCP/ask_for_close",
}
socket.__index = socket
local nextSN = 1
function socket:write(data)
	local msg = {
		data=data,
		SN=self.dSN	
	}
	network.send(self.address,)
end

function socket.read()
	if not self.buffer then self.buffer = {} end
	local returning = self.buffer[1] or ""
	table.remove(self.buffer,1)
	return returning
end

function socket:close(timeout)
	timeout = type(timeout) == "number" and timeout or 5
	network.send(self.address,TCP_codes.close)
	event.ignore(network.message_code,self.listener)
	while true do
		self.status = "FIN-WAIT"
		local signal, receiver, sender, msg = event.pull(timeout,network.message_code,_,self.address)
		if signal == nil then return true, "timeout" end
		if sender == self.address then
			if msg == TCP_codes.close then
				self.status = "CLOSING"
				return true
			end
		end
	end
end

function socket:status()
	return self.status
end

function protocol.openTCP(address)
	local handle = {address=address,SN=nextSN,buffer={},status="CLOSED"}
	setmetatable(handle,socket)
	nextSN = nextSN + 1
	function handle.listener(name,receiver,sender,data)
		if sender == handle.address then
			if data == TCP_codes.close then
				handle.status = "CLOSING"
			elseif data:sub(1,TCP_codes.head:len()) == TCP_codes.head then
				data = data:sub(TCP_codes.head:len()+1)
				data = serial.unserialize(data) 
				if data.SN == handle.SN then
					table.insert(handle.buffer,data)
				end
			end
		end
	end
	network.send(handle.address,"TCP/SYN" .. tostring(buffer.SN))
	handle.status = "SYN-SENT"
	while true do
		local signal, receiver, sender, msg = event.pull(5,network.message_code,_,handle.address)
		if not signal then handle.status = "CLOSING" return nil, "timeout" end
		if sender == handle.address then
			if msg:sub(1,7) == "TCP/SYN" then
				handle.status = "SYN-RECEIVED"
				local dSN = tonumber(msg:sub(8))
				handle.dSN = dSN
				network.send(handle.address,"TCP/ESTABLISHED")
				break
			end
		end
	end
	handle.status = "ESTABLISHED"
	event.listen(network.message_code,handle.listener)
	return handle
end

function protocol.TCPlistener(timeout)
	local deadline = computer.uptime() + timeout
	while true do
		local name, receiver, sender, data = event.pull(deadline-computer.uptime(),network.message_code)
		if data:sub(1,7) == "TCP/SYN" then
			local handle = {address=address,SN=nextSN,buffer={},status="CLOSED"}
			setmetatable(handle,socket)
			nextSN = nextSN + 1
			function handle.listener(name,receiver,sender,data)
				if sender == handle.address then
					if data == TCP_codes.close then
						handle.status = "CLOSING"
					elseif data:sub(1,TCP_codes.head:len()) == TCP_codes.head then
						data = data:sub(TCP_codes.head:len()+1)
						data = serial.unserialize(data) 
						if data.SN == handle.SN then
							table.insert(handle.buffer,data)
						end
					end
				end
			end
			handle.status = "SYN-RECEIVED"
			network.send(handle.address,"TCP/SYN" .. tostring(buffer.SN))
			handle.status = "SYN-SENT"
			while true do
				local signal, receiver, sender, msg = event.pull(0.5,network.message_code,_,handle.address)
				if not signal then handle.status = "CLOSING" break end
				if sender == handle.address then

				end
			end
			handle.status = "ESTABLISHED"
			event.listen(network.message_code,handle.listener)
			return handle
		end
	end
end

return protocol

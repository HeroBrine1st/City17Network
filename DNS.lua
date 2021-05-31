local protocol = require("IP")
local SD = require("SaveData")
local network = require("network")
local serial = require("safeSerial")
local crypt = require("crypt")
local event = require("event")
local inet = require("internet")
local domains = SD.readData("domains") or {}
--local password = "@uxpDp83pbyKJ4jYUe%MN@^K8w44245MuY&eBBXa#4dS*uupX8W*2c#9sMNfxXt6c2pW4^4VQN4y7uVt7N5J95!6296d99Z9"
local password = "hdsdqwGDDS"
local function generateCertificate(domain,address,password)
	return crypt.md5(domain .. address .. password)
end

local function log(...)
	local args = {...}
	local str = "[OPENNET DNS] "
	for i = 1, #args do
		str = str .. tostring(args[i]) .. "    "
	end
	local success, reason = inet.request("http://city17.xyz/net.php",str)
	print(str)
	if not success then print("Ошибка логгинга на внешний сервер:" .. reason) end
end

local function register(address,d1,d2,d3)
	if not address or not d1 or not d2 then return nil end
	if d1 then
		domains[d1] = domains[d1] or {}
	end
	if d2 then
		if d3 then
			domains[d1][d2] = domains[d1][d2] or {}
		elseif not domains[d1][d2] then
			domains[d1][d2] = address
			return true
		else
			return false
		end
	end
	if d3 then 
		domains[d1][d2][d3] = address
	end
end

local function get(d1,d2,d3)
	if not d1 and d2 then return nil end
	if domains[d1] then
		if domains[d1][d2] and d3 then
			return domains[d1][d2][d3]
		else
			return domains[d1][d2]
		end
	else 
		return nil
	end
end

local function unregister(d1,d2,d3)
	if not d1 or not d2 then return nil end
	if not domains[d1] or not domains[d1][d2] then return false end
	if d3 then
		domains[d1][d2][d3] = nil
	else
		domains[d1][d2] = nil
	end
	return true
end

local function saveData()
	SD.saveData("domains",domains)
end

local function split(source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] = value;  end);
  return elements
end

local cooldown = {}

local function checkCooldown(address,time)
	-- local uptime = require("computer").uptime()
	-- if cooldown[address] then
	-- 	if cooldown[address] < time then 
	-- 		cooldown[address] = uptime + time 
	-- 		return true
	-- 	else
	-- 		return false
	-- 	end
	-- else
	-- 	cooldown[address] = uptime + time
	-- 	return true
	-- end
	return true
end

network.connect()
while true do
	local name, _, address, message = event.pull()
	saveData()
	if name:find("interrupt") then
		print("Interrupting")
		saveData()
		os.exit()
	elseif name == "network_message" then
		message = serial.unserialize(message)
		if checkCooldown(address,2) then
			if message["path"] == "/get.lua" then
				domain = message["data"]
				if domain then 
					local domainS = split(domain,".")
					local d1,d2,d3 = domainS[3],domainS[2],domainS[1]
					if not d1 then d1 = d2 d2 = d3 d3 = nil end
					local domainAddress = tostring(get(d1,d2,d3) or "ADDRESS_INVALID")
					log("Получение адреса от:" .. address .. " Адрес: ",domain,"Домены: ",d1,d2,d3,"Ответ: " .. domainAddress)
					protocol.send(address,domainAddress)
				else
					protocol.send(address,"ADDRESS_INVALID")
				end
			elseif message["path"] == "/register.lua" then
				local data = serial.unserialize(message["data"],"#")
				local domain = tostring(data["domain"])
				local domainAddress = tostring(data["address"])
				local cetrificate = data["secure"]
				if cetrificate == generateCertificate(domain,domainAddress,password) then
					local domainS = split(domain,".")
					local d1,d2,d3 = domainS[3],domainS[2],domainS[1]
					if not d1 then d1 = d2 d2 = d3 d3 = nil end
					local success = register(domainAddress,d1,d2,d3)
					local service_code 
					if success == nil then 
						service_code = "INVALID_ARGUMENTS" 
					elseif success == false then 
						service_code = "DOMAIN_EXISTS" 
					elseif success == true then 
						service_code = "CREATE_SUCCESS" 
					end
					log("Регистрация домена от:" .. address .. " Адрес: " .. domain .. " Адрес домена: " .. domainAddress .. " Ответ: " .. service_code)
					protocol.send(address,service_code)
				else
					protocol.send(address,"CERTIFICATE_INVALID")
				end
			elseif message["path"] == "/unregister.lua" then
				local data = serial.unserialize(message["data"],"#")
				local domain = tostring(data["domain"])
				local domainAddress = "ANY_ADDRESS"
				local cetrificate = data["secure"]
				if cetrificate == generateCertificate(domain,domainAddress,password) then
					local domainS = split(domain,".")
					local d1,d2,d3 = domainS[3],domainS[2],domainS[1]
					if not d1 then d1 = d2 d2 = d3 d3 = nil end
					local success = unregister(d1,d2,d3)
					local service_code 
					if success == nil then 
						service_code = "INVALID_ARGUMENTS" 
					elseif success == false then 
						service_code = "DOMAIN_NULL" 
					elseif success == true then 
						service_code = "REMOVE_SUCCESS" 
					end
					log("Удаление домена от:" .. address .. " Адрес: " .. domain .. " Адрес домена: " .. domainAddress .. " Ответ: " .. service_code)
					protocol.send(address,service_code)
				else
					protocol.send(address,"CERTIFICATE_INVALID")
				end
			end
		else
			protocol.send(address,"TIMEOUT")
		end
	end
end
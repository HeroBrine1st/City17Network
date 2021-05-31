local DNS = {}
local protocol = require("IP")
local serial = require("safeSerial")
local crypt = require("crypt")

local function generateCertificate(domain,address,password)
	return crypt.md5(domain .. address .. password)
end
	
function DNS.get(address,domain)
	local data,reason = protocol.request(address,"/get.lua",domain)
	if not data then return nil, reason end
	return data
end

function DNS.register(address,domain,addressDomain,password)
	local certificate = generateCertificate(domain,addressDomain,password)
	local data = {domain=domain,address=addressDomain,secure=certificate}
	local responce, reason = protocol.request(address,"/register.lua",serial.serialize(data,"#"))
	if not responce then return nil, reason end
	return responce
end

function DNS.unregister(address,domain,password)
	local certificate = generateCertificate(domain,"ANY_ADDRESS",password)
	local data = {domain=domain,secure=certificate}
	local responce, reason = protocol.request(address,"/unregister.lua",serial.serialize(data,"#"))
	if not responce then return nil, reason end
	return responce
end

return DNS
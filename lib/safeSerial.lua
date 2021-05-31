local serialization = {}
local main = "&"

function serialization.serialize(data,symbol)
	symbol = symbol or main
	local post
	if type(data) == "string" then
	    return data
	elseif type(data) == "table" then
		for k, v in pairs(data) do
	    	post = post and (post .. symbol) or ""
	      	post = post .. tostring(k) .. "=" .. tostring(v)
	    end
	end
	return post
end



function serialization.unserialize(data,symbol1)
	symbol1 = symbol1 or main
	local t = {}
	while true do
		local symbol = data:find(symbol1)
		if symbol then
			local pair = data:sub(1,symbol-1)
			data = data:sub(symbol+1)
			local symbolPair = pair:find("=")
			if symbolPair then
				local key = pair:sub(1,symbolPair-1)
				local value = pair:sub(symbolPair+1)
				value = tonumber(value) or value
				key = tonumber(key) or key
				t[key] = value or key
			end
		else
			symbol = #data+1
			local pair = data:sub(1,symbol-1)
			data = data:sub(symbol+1)
			local symbolPair = pair:find("=")
			if symbolPair then
				local key = pair:sub(1,symbolPair-1)
				local value = pair:sub(symbolPair+1)
				value = tonumber(value) or value
				key = tonumber(key) or key
				t[key] = value
			end
			break
		end
	end
	return t
end

return serialization
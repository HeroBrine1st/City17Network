local generator = {}
local g = 2
local p = 16432651
function method2(b, e, m)
  if e == 0 then
    return 1
  elseif e == 1 then
    return b
  elseif e % 2 == 1 then
    return (method2(b, e - 1, m) * b) % m
  else
    local x = method2(b, e / 2, m)
    return (x * x) % m
  end
end
local modulePow = method2

local function generateKey()
	return math.random(0xFFFFFFFFFFF,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
end

function generator.step1()
	local raw = generateKey()
	local key = modulePow(g,raw,p)
	return key, raw
end

function generator.step2(B,a)
	return modulePow(B,a,p)
end

return generator
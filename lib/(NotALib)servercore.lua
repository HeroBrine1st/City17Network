--[[
    Server Core v0.2.1
    Author: LeshaInc
    Date: 10 November 2015 16:22
    Licenze: Creative Commons «Attribution-NonCommercial-NoDerivatives» («Атрибуция — Некоммерческое использование — Без производных произведений») 4.0 Всемирная.
]]

--[[
    Info codes:
    1 - Server started
    2 - Server stopped
]]

-- settings
local __name     = "server"
local __timezone = 0
local __correct  = 0

-- apis
local component = require("component")
local un  = require("unicode")
local fs  = require("filesystem")
local event = require("event")
local keyboard = require("keyboard")
local fs = require("filesystem")
local shell = require("shell")

-- other vars
local info_types = {
    {"err","Error",0xFF0000},
    {"ok","OK",0x00AA00},
    {"warn","Warning",0xFF6600},
    {"info","Info",0x62B1F6},
}
local text = 0xEEEEEE
local tz = __timezone + __correct
local t_correction = tz * 3600 
local running = true
local listeners = {}
local args, options = shell.parse(...)
local server_path = ""
_G.sc = {}
local _debug = true

-- components
local gpu

-- functions
listeners[1] = {"key_down",function (_,_,k1,k2) 
    if keyboard.isControlDown() and keyboard.isKeyDown(46) then
        info("info","interrupted server.")
        running = false
    end
end}

function getTime()
    local file = io.open('/tmp/' .. __name ..'.dt', 'w')
    file:write('')
    file:close()
    local lastmod = tonumber(string.sub(fs.lastModified('/tmp/' .. __name ..'.dt'), 1, -4)) + t_correction
 
    return lastmod
end
function info(type_x,mesg)
    if gpu and _debug then
        for i=1,#info_types do
            if type_x == info_types[i][1] then
                gpu.setForeground(info_types[i][3])
                local time_now = os.date("%d %b %H:%M:%S",getTime())
                io.write(time_now)
                gpu.setForeground(text)
                io.write(" - " .. info_types[i][2] .. ": " .. mesg .. "\n")
                return true
            end
        end
        return false
    end
end
function init()
    if component.isAvailable("gpu") then
        gpu = component.gpu
    else 
        gpu = nil
    end
    
    if #args < 1 then
        server_path = os.getenv("PWD")
    else
        server_path = args[1] 
    end
    
    if options.help or options.h  then 
        print("Server Core v0.1")
        print("Usage:")
        print("  sc [project path (default = ./)] [-d] [-h]")
        print("Options:")
        print("  -d,--nodebug = do not show information for debug")
        print("  -h,--help = show help")
        print("  -i,--ignore-servercore = ignore the check for file .servercore")
        os.exit()
    end
    
    if options.nodebug or options.d then
        _debug = false 
    end
    
    if not fs.exists(server_path) then
        info("err","path does not exist.")
        os.exit()
    end
    
    if options["ignore-servercore"] or options.i then
        --
    else
        if not fs.exists(fs.concat(fs.canonical(server_path), ".servercore")) then
            info("err",".servercore file not found.")
            os.exit()
        end
    end
    
    if not fs.isDirectory(server_path) then
        info("err","path must be a folder.")
        os.exit()
    end
    
    info("info",__name .. " is initializing...")
    
    package.preload["server_api"] = function () return api end
    
    for file in fs.list(server_path) do 
        if file ~= ".servercore" and fs.isDirectory(file) == false then
            local path_to_load = fs.concat(fs.canonical(server_path), file)
            info("info","loading module \"" .. path_to_load .. "\"...")
            local ok,err = pcall(loadfile(path_to_load))
            if not ok then
                info("err","error loading module \"" .. file .."\" - " .. err)
            else
                info("info","loaded module \"" .. file .. "\".")
            end
        end
    end
    
    info("ok",__name .. " is initialized.")
end
function main()
    while running do
        local e = {event.pull()}
        for i=1,#listeners do
            if listeners[i][1] == e[1] then
                local ok,err = pcall(listeners[i][2],table.unpack(e))
                if not ok then
                    info("err","error occurred while processing the event " .. e[1] .. " - " .. err)
                end
            end
        end
    end
    info("info",__name .. " is stopping...")
    os.sleep(0.5)
    _G.sc = nil
    info("ok",__name .. " is stopped.")
end

_G.sc.info = info
_G.sc.getTime = getTime
function _G.sc.on(event_name,handler)
    table.insert(listeners,{event_name,handler})
end
function _G.sc.test() print("hello world") end

-- main
init()
main()
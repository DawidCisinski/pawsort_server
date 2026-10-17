local pawlib = require("pawlib")
local functions = require("functions")

if not fs.exists("$options.txt") then
    local f = fs.open("$options.txt", "w")
    f.write('{guest = {power = 1, password = "default"}, user = {power = 2, password = "default"}, admin = {power = 3, password = "default"}}')
    f.close()
end

if not fs.exists("$sessions.txt") then
    local f = fs.open("$sessions.txt", "w")
    f.write("{}")
    f.close()
end
--===========================================================

local MODEM = peripheral.find("modem")
if not MODEM then
    error("FATAL ERROR: install modem", 0)
end

local SERVER_IP = os.getComputerID()
local SESSIONS = pawlib.open_list("$sessions.txt")
local PASSWORDS = pawlib.open_list("$options.txt")
local USER = 0

MODEM.open(SERVER_IP)

--===========================================================

local function verification(SESSIONS, message, senderIP)
    local session = SESSIONS[senderIP]

    if not session then
        return false
    end

    if session.ip ~= senderIP then
        return false
    end

    if type(message.password) ~= "string" then
        return false
    end

    return message.password == session.password
end

--===========================================================

local function addRecord(client_ip, user_type, scode)
    SESSIONS[client_ip] = {
    password = pawlib.hash64(PASSWORDS[user_type].password .. scode),
    ip = client_ip,
    power = PASSWORDS[user_type].power,
    key = pawlib.hash64(PASSWORDS[user_type].password)
    }
    pawlib.save_list("$sessions.txt",SESSIONS)
end

local function _registration(senderIP, msg)
    if msg.user_type ~= "guest"
        and msg.user_type ~= "user"
        and msg.user_type ~= "admin" then

        return { error = "invalid user type" }
    end

    local SCODE = math.random(1000, 9999)

    addRecord(senderIP, msg.user_type, SCODE)

    return {
        scode = SCODE,
        ok = "_"
    }
end

local function _login(senderIP, msg)
    if verification(SESSIONS, msg, senderIP) then
        return { ok = "Logged in" }
    else
        return { error = "Access denied" }
    end
end

--===========================================================

local COMMANDS = {
    { name = "_registration", starter = _registration,           class = -1 },
    { name = "_login",        starter = _login,                  class = -1 },
    { name = "ping",          starter = functions.ping,          class = -1 },
    { name = "list",          starter = functions.list,          class = 1 },
    { name = "get",           starter = functions.get,           class = 1 },
    { name = "print",         starter = functions.remoteprint,   class = 2 },
    { name = "push",          starter = functions.push,          class = 2 },
    { name = "stop",          starter = functions.stop,          class = 3 }

}

--===========================================================

local function server_loop()
    while true do
        local _, _, receiverIP, senderIP, msg = os.pullEvent("modem_message")
        if receiverIP == SERVER_IP and type(msg) == "table" then
            USER = 0

            if verification(SESSIONS, msg, senderIP) then
                USER = SESSIONS[senderIP].power
            end

            print("(server) p: " .. USER .. "ip: " .. senderIP)

            local found = false

            for _, command in ipairs(COMMANDS) do
                if command.name == msg.cmd then
                    found = true
                    if USER >= command.class then
                        local querry = command.starter(senderIP, msg, USER, SESSIONS)
                        MODEM.transmit(senderIP, SERVER_IP, querry)
                    else
                        MODEM.transmit(senderIP, SERVER_IP, { error = "invalid user" })
                    end
                    break
                end
            end

            if not found then
                MODEM.transmit(senderIP, SERVER_IP, { error = "unknown command" })
            end
        end
    end
end

--===========================================================

local function console_loop()
    while true do
        --local cmd = rinput("server")
        local cmd = pawlib.rinput("","","")
        if cmd == "stop" then return end
        if cmd == "info" then functions.system_info(PASSWORDS,false) end
        if cmd == "help" then  pawlib.rprint("blue", "help") end
        if cmd == "mount" then pawlib.startup_overwrite('shell.run("/pawsort-server.lua")\n') end
        if cmd == "clear" or cmd == "cls" then pawlib.clear() end
    end
end

--===========================================================

functions.system_info(PASSWORDS,true)

parallel.waitForAny(server_loop, console_loop)

pawlib.rprint("blue", "server closed\n")
MODEM.close(SERVER_IP)
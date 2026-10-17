local functions = {}

package.path = package.path .. ";/Libraries/?.lua"
local pawlib = require("pawlib")

--===========================================================

function functions.getDiskPath()
    if fs.exists("disk") and fs.isDir("disk") then
        return "disk"
    end
    return "none"
end

function functions.hasWebsite()
    return fs.exists("disk/index.txt")
end

function functions.hasPrinter()
    return peripheral.find("printer") ~= nil
end

--===========================================================

function functions.system_info(PASSWORDS,full_info)
    pawlib.clear()

    pawlib.rprint("yellow", "Pawsoft v.3 (server)")
    print("pawsoft-server [admin password] [user password]")
    print("type [help] for commands\n")

    if full_info then
        print(" Server IP: " .. os.getComputerID())
        print(" Admin password: " .. PASSWORDS["admin"].password)
        print(" User password: " .. PASSWORDS["user"].password)
        print(" Guest password: " .. PASSWORDS["guest"].password)

        print(" Website: " .. tostring(functions.hasWebsite()))
        print(" Printer: " .. tostring(functions.hasPrinter()))
        print(" Repo disk path: /" .. functions.getDiskPath() .. "\n")

        pawlib.line()

        print(
            "index.txt on the disk enables the www server.\n" ..
            "Files starting with '$' are protected\n" ..
            "and require a valid login."
        )

        pawlib.line()
    end
end

--===========================================================

function functions.ping(senderIP, msg)
    return {
        ok = "pong",
        repo = (functions.getDiskPath() ~= "none"),
        www = functions.hasWebsite(),
        printer = functions.hasPrinter()
    }
end

function functions.list(senderIP, msg)
    local disk = functions.getDiskPath()

    if disk == "none" then
        return { error = "No disk inserted" }
    end

    return {
        list = fs.list(disk),
        ok = "_"
    }
end

function functions.get(senderIP, msg, USER, SESSIONS)
    if type(msg.file) ~= "string" then
        return { error = "bad path" }
    end

    if msg.file:sub(1, 1) == "$" and USER < 2 then
        return { error = "Access denied" }
    end

    local disk = functions.getDiskPath()

    if disk == "none" then
        return { error = "No disk inserted" }
    end

    local path = disk .. "/" .. msg.file:gsub("/", "")

    if not fs.exists(path) then
        return { error = "bad path" }
    end

    local f = fs.open(path, "r")
    local data = f.readAll()
    f.close()

    return {
        data = pawlib.encrypt(data, SESSIONS[senderIP].key),
        ok = "_"
    }
end

function functions.push(senderIP, msg, USER, SESSIONS)
    if type(msg.file) ~= "string" then
        return { error = "bad path" }
    end

    if (msg.file == "index.txt" or msg.file:sub(1, 1) == "$") and USER < 3 then
        return { error = "Access denied" }
    end

    local disk = functions.getDiskPath()

    if disk == "none" then
        return { error = "No disk inserted" }
    end

    if fs.isReadOnly(disk) then
        return { error = "Disk is read-only" }
    end

    local path = disk .. "/" .. msg.file:gsub("/", "")

    local f = fs.open(path, "w")
    f.write(pawlib.decrypt(msg.data, SESSIONS[senderIP].key))
    f.close()

    return { ok = "saved" }
end

function functions.remoteprint(senderIP, msg, USER)
    local printer = peripheral.find("printer")

    if not printer then
        return { error = "No printer connected" }
    end

    if not printer.newPage() then
        return { error = "No paper" }
    end

    for line in msg.data:gmatch("[^\r\n]+") do
        printer.write(line)

        local _, y = printer.getCursorPos()
        printer.setCursorPos(1, y + 1)
    end

    printer.endPage()

    return { ok = "printed" }
end

function functions.stop(senderIP, msg, USER)
    error("Server stopped", 0)
end

function functions.help()
    pawlib.clear()
    print("Commands:")
    print("")
    print("  help       Display this help message")
    print("  info       Show system information")
    print("  mount      Mount server in startup.lua")
    print("  clear      Clear the terminal screen")
    print("  cls        Alias for clear")
    print("  stop       Exit the program")
end

return functions
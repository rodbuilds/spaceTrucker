-- Shared logger for the Space Trucker mod. All output is prefixed so server
-- operators can grep their logs cleanly.
package.path = package.path .. ";data/scripts/lib/?.lua"

TruckerLog = {}

local PREFIX = "[SpaceTrucker]"

local function fmt(level, msg, ...)
    local body
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, msg, ...)
        body = ok and formatted or tostring(msg)
    else
        body = tostring(msg)
    end
    return string.format("%s [%s] %s", PREFIX, level, body)
end

function TruckerLog.info(msg, ...)
    print(fmt("INFO", msg, ...))
end

function TruckerLog.warn(msg, ...)
    print(fmt("WARN", msg, ...))
end

function TruckerLog.error(msg, ...)
    eprint(fmt("ERROR", msg, ...))
end

function TruckerLog.banner(version)
    print(string.format("%s ====================================================", PREFIX))
    print(string.format("%s  Space Trucker v%s loaded", PREFIX, version or "?"))
    print(string.format("%s ====================================================", PREFIX))
end

return TruckerLog

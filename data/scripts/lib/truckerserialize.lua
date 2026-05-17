-- Lua-literal table serializer / deserializer.
--
-- Avorion's setValue / getValue accept only scalar types (number, string,
-- bool). Tables must be encoded to strings first. We use a Lua-literal
-- format because it round-trips natively via loadstring().
package.path = package.path .. ";data/scripts/lib/?.lua"

TruckerSerialize = {}

local function escape(s)
    return string.format("%q", s)
end

local function encodeValue(v)
    local t = type(v)
    if t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "string" then
        return escape(v)
    elseif t == "table" then
        return TruckerSerialize.encode(v)
    elseif t == "nil" then
        return "nil"
    end
    return "nil"
end

function TruckerSerialize.encode(tbl)
    if type(tbl) ~= "table" then return "nil" end
    local parts = {}
    local i = 1
    local isArray = true
    for k, _ in pairs(tbl) do
        if k ~= i then isArray = false; break end
        i = i + 1
    end
    if isArray then
        for _, v in ipairs(tbl) do
            table.insert(parts, encodeValue(v))
        end
    else
        for k, v in pairs(tbl) do
            local key
            if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
                key = k
            else
                key = "[" .. encodeValue(k) .. "]"
            end
            table.insert(parts, key .. "=" .. encodeValue(v))
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function TruckerSerialize.decode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local chunk, err = loadstring("return " .. s)
    if not chunk then return nil end
    local ok, val = pcall(chunk)
    if not ok then return nil end
    return val
end

return TruckerSerialize

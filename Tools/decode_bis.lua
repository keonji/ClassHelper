local env = { table = { insert = table.insert } }
for index = 1, #arg do
    local chunk = assert(loadfile(arg[index]))
    setfenv(chunk, env)
    debug.sethook(function() error("data instruction budget exceeded") end, "", 10000000)
    chunk()
    debug.sethook()
end
env.table = nil
local function encode(value)
    if type(value) == "string" then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(c) return ('\\u%04x'):format(c:byte()) end) .. '"'
    end
    if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
    if type(value) ~= "table" then return "null" end
    local parts, count = {}, 0
    for _ in pairs(value) do count = count + 1 end
    if count > 0 and count == #value then
        for _, v in ipairs(value) do parts[#parts + 1] = encode(v) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, v in pairs(value) do parts[#parts + 1] = encode(tostring(k)) .. ":" .. encode(v) end
    return "{" .. table.concat(parts, ",") .. "}"
end
io.write(encode(env))

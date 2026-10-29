if select(2, ...).INERT then return end
local _, ns = ...

-- Saved settings: tables and defaults.

-- A saved table of ours, made (or replaced if anything else stands there) on first use.
function ns.DbTable(key)
    local list = ns.db[key]
    if type(list) ~= "table" then
        list = {}
        ns.db[key] = list
    end
    return list
end

function ns.CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        end
    end
end

-- The copies Era's broad walk hands its pieces to (Art/BronzeClient.lua, Era(...) and era = true) are frames around
-- a picture, never a background under one: a copy layer sits one sublevel over its piece, so a background's covered
-- the icon on the same sublevel (UI-Quickslot dimmed every action icon). Usage: lua era_copies_test.lua <addon dir>
-- luacheck: std lua54
local dir = arg[1] or "."
local file = assert(io.open(dir .. "/Art/BronzeClient.lua", "r"))
local src = file:read("a")
file:close()

local BACKGROUNDS = { ["ui-quickslot"] = true, ["ui-emptyslot"] = true, ["ui-slot-background"] = true,
    ["ui-pagebutton-background"] = true, ["ui-bag-components"] = true, ["ui-backpackbackground"] = true,
    ["ui-character-statbackground"] = true, ["ui-bankframe-floor"] = true }

local names, bad = {}, {}
for name in src:gmatch('Era%([^,]+,%s*"([^"]+)"%)') do names[#names + 1] = name end
for name in src:gmatch('"([^"]+)",%s*crop = [%w_]+, era = true') do names[#names + 1] = name end
for name in src:gmatch('Era%([^,]+,%s*"UI%-MicroButton%-" %.%. name %.%. "%-(%a+)%.blp"%)') do
    names[#names + 1] = "UI-MicroButton-x-" .. name
end
for _, name in ipairs(names) do
    local base = name:gsub("%.%w+$", ""):lower()
    if BACKGROUNDS[base] then bad[#bad + 1] = name end
end
if #names == 0 then
    print("FAIL no Era copies found in Art/BronzeClient.lua (the pattern no longer matches)")
    os.exit(1)
end
if #bad > 0 then
    print("FAIL Era broad copies name a background sheet: " .. table.concat(bad, ", "))
    os.exit(1)
end
print("PASS " .. #names .. " Era copies, none a background")

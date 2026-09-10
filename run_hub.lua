-- Paste ONLY this file in a Real tab (do NOT paste chat code blocks)
local paths = {
	"bladeball_hub.lua",
	[[C:\Users\gyhdgsg\AppData\Local\Real\workspace\bladeball_hub.lua]],
	[[C:\Users\gyhdgsg\Desktop\roblox script\bladeball_hub.lua]],
}

local src, used
for _, path in ipairs(paths) do
	local ok, data = pcall(readfile, path)
	if ok and type(data) == "string" and #data > 1000 then
		src = data
		used = path
		break
	end
end

assert(src, "bladeball_hub.lua not found. Copy it to Real workspace folder first.")
print("[BBHub] loading from", used)

local fn, err = loadstring(src)
assert(fn, err or "loadstring failed")
fn()

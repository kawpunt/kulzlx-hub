-- Paste ONLY this in a Real tab
local paths = {
	"reeled_hub.lua",
	[[C:\Users\gyhdgsg\AppData\Local\Real\workspace\reeled_hub.lua]],
	[[C:\Users\gyhdgsg\Desktop\roblox script\reeled_hub.lua]],
}

local src, used
for _, path in ipairs(paths) do
	local ok, data = pcall(readfile, path)
	if ok and type(data) == "string" and #data > 500 then
		src = data
		used = path
		break
	end
end

assert(src, "reeled_hub.lua not found")
print("[ReeledHub] load", used)
local fn, err = loadstring(src, "@reeled_hub")
assert(fn, err)
fn()

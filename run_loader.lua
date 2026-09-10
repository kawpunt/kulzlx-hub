-- Paste in Real to boot Kulzlx Hub loader from disk
local paths = {
	"loader.obf.lua",
	[[C:\Users\gyhdgsg\Desktop\roblox script\loader.obf.lua]],
	"loader.lua",
	[[C:\Users\gyhdgsg\Desktop\roblox script\loader.lua]],
	[[C:\Users\gyhdgsg\AppData\Local\Real\workspace\loader.lua]],
}
for _, path in ipairs(paths) do
	local ok, src = pcall(readfile, path)
	if ok and type(src) == "string" and #src > 200 then
		print("[Kulzlx] loader", path)
		local fn, err = loadstring(src, "@loader")
		assert(fn, err)
		return fn()
	end
end
error("loader.lua not found")

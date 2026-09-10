-- Kulzlx Hub — paste this in Real (do not put )() on the same line as loadstring)
local url = "https://raw.githubusercontent.com/kawpunt/kulzlx-hub/main/loader.obf.lua"

local function httpget(link)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if typeof(req) == "function" then
		local res = req({
			Url = link,
			Method = "GET",
			Headers = { ["User-Agent"] = "Kulzlx-Loader/1.0" },
		})
		if type(res) == "table" then
			return res.Body or res.body
		end
	end
	if typeof(game.HttpGet) == "function" then
		return game:HttpGet(link)
	end
	error("no http get")
end

print("[Kulzlx] fetching", url)
local src = httpget(url)
assert(type(src) == "string" and #src > 100, "fetch failed: " .. tostring(src))
print("[Kulzlx] downloaded", #src, "bytes")

local fn, err = loadstring(src, "@kulzlx")
assert(fn, err)
fn()

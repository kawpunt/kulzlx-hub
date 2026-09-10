-- Kulzlx Hub — paste ALL of this in Real
local urls = {
	"https://raw.githubusercontent.com/kawpunt/kulzlx-hub/main/loader.lua",
	"https://cdn.jsdelivr.net/gh/kawpunt/kulzlx-hub@main/loader.lua",
}

local function httpget(link)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if typeof(req) == "function" then
		local ok, res = pcall(req, {
			Url = link,
			Method = "GET",
			Headers = { ["User-Agent"] = "Mozilla/5.0 Kulzlx" },
		})
		if ok and type(res) == "table" then
			local body = res.Body or res.body
			local code = res.StatusCode or res.statusCode or 0
			if type(body) == "string" and #body > 200 and not body:find("^%s*<") then
				return body, code
			end
		end
	end
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, link)
		if ok and type(body) == "string" and #body > 200 then
			return body, 200
		end
	end
	return nil, 0
end

local src, used
for _, link in ipairs(urls) do
	print("[Kulzlx] fetching", link)
	local body, code = httpget(link)
	if body then
		src, used = body, link
		break
	end
	warn("[Kulzlx] failed", link, code)
end

if not src then
	error("[Kulzlx] could not download loader from GitHub")
end

print("[Kulzlx] downloaded", #src, "from", used)
local fn, err = loadstring(src, "@kulzlx")
if not fn then
	error("[Kulzlx] compile failed: " .. tostring(err))
end
print("[Kulzlx] running")
fn()

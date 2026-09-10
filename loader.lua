--[[
  Kulzlx Hub Loader
  Auto-detects PlaceId / GameId, then loads the matching hub.
  Auth stack:
    /auth/access  license + HWID -> RSA-PSS session
    /hub          signed game catalog
    /cdn/:id      signed script body
    /hb           heartbeat
    /task         scheduled jobs
    /model/:name  signed metadata

  Paste this file in Real. Optional before run:
    getgenv().KULZLX_KEY = "KULZLX-...."
    getgenv().KULZLX_AUTH_URL = "http://127.0.0.1:8787"
    Users: Get key copies a Work.ink override link. Paste the token after the ads.
]]

repeat
	task.wait()
until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local function genvGet(...)
	if typeof(getgenv) ~= "function" then
		return nil
	end
	local g = getgenv()
	for i = 1, select("#", ...) do
		local v = g[select(i, ...)]
		if v ~= nil and v ~= "" then
			return v
		end
	end
	return nil
end

local AUTH_URL = genvGet("KULZLX_AUTH_URL", "VGC_AUTH_URL") or "http://127.0.0.1:8787"
local KEY_URL = genvGet("KULZLX_KEY_URL", "VGC_KEY_URL") or ""
local SAVE_FILE = "kulzlx/session.json"
local LOCAL_ROOTS = {
	[[C:\Users\gyhdgsg\Desktop\roblox script]],
	[[C:\Users\gyhdgsg\AppData\Local\Real\workspace]],
	".",
}

local function env()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = env()
G.Kulzlx = G.Kulzlx or G.VGC or {}
G.VGC = G.Kulzlx

local function notify(title, text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 4,
		})
	end)
	print("[Kulzlx]", title, text)
end

local function httpRequest(opts)
	local fn = (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
		or (fluxus and fluxus.request)
	if typeof(fn) == "function" then
		local ok, res = pcall(fn, opts)
		if ok and type(res) == "table" then
			return res
		end
	end
	if typeof(game.HttpGet) == "function" and (opts.Method or "GET") == "GET" then
		local ok, body = pcall(game.HttpGet, game, opts.Url)
		if ok then
			return { Success = true, StatusCode = 200, Body = body }
		end
	end
	return nil
end

local function api(method, route, body, token)
	local url = AUTH_URL .. route
	local headers = {
		["Content-Type"] = "application/json",
		["User-Agent"] = "Kulzlx-Loader/1.0",
	}
	if token then
		headers.Authorization = "Bearer " .. token
		headers["X-KULZLX-Session"] = token
		headers["X-VGC-Session"] = token
	end
	local res = httpRequest({
		Url = url,
		Method = method,
		Headers = headers,
		Body = body and HttpService:JSONEncode(body) or nil,
	})
	if not res or type(res.Body) ~= "string" or res.Body == "" then
		return nil, "no_response"
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, res.Body)
	if not ok then
		return nil, "bad_json"
	end
	if decoded.ok == false then
		return nil, decoded.error or "rejected"
	end
	return decoded
end

local function hwid()
	local id = ""
	pcall(function()
		if typeof(gethwid) == "function" then
			id = tostring(gethwid())
		end
	end)
	if id == "" then
		pcall(function()
			id = game:GetService("RbxAnalyticsService"):GetClientId()
		end)
	end
	if id == "" then
		id = "uid-" .. tostring(LocalPlayer and LocalPlayer.UserId or 0)
	end
	return id
end

local function executorName()
	local name = "unknown"
	pcall(function()
		if typeof(identifyexecutor) == "function" then
			name = identifyexecutor()
		elseif typeof(getexecutorname) == "function" then
			name = getexecutorname()
		end
	end)
	return tostring(name)
end

local function readLocal(rel)
	if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
		return nil
	end
	for _, root in ipairs(LOCAL_ROOTS) do
		local p = root .. "/" .. rel
		local ok, data = pcall(readfile, p)
		if ok and type(data) == "string" and #data > 0 then
			return data, p
		end
		p = rel
		ok, data = pcall(readfile, p)
		if ok and type(data) == "string" and #data > 0 then
			return data, p
		end
	end
	return nil
end

local function saveSession(pack)
	if typeof(writefile) ~= "function" or typeof(makefolder) ~= "function" then
		return
	end
	pcall(function()
		makefolder("kulzlx")
		writefile(SAVE_FILE, HttpService:JSONEncode(pack))
	end)
end

local function loadSaved()
	local preset = genvGet("KULZLX_KEY", "VGC_KEY")
	if preset then
		return { key = preset }
	end
	if typeof(isfile) == "function" and isfile(SAVE_FILE) then
		local ok, data = pcall(readfile, SAVE_FILE)
		if ok and type(data) == "string" then
			local ok2, pack = pcall(HttpService.JSONDecode, HttpService, data)
			if ok2 and type(pack) == "table" then
				return pack
			end
		end
	end
	return nil
end

local function promptKey()
	local preset = genvGet("KULZLX_KEY", "VGC_KEY")
	if preset then
		return preset
	end
	local saved = loadSaved()
	if saved and saved.key and saved.key ~= "" then
		return saved.key
	end

	local result
	local done = Instance.new("BindableEvent")
	local gui = Instance.new("ScreenGui")
	gui.Name = "KulzlxKey"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	pcall(function()
		if gethui then
			gui.Parent = gethui()
		else
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end
	end)
	if not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	dim.BackgroundTransparency = 0.25
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 230)
	card.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	card.Parent = dim
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 18)
	title.Size = UDim2.new(1, -40, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.Text = "Kulzlx Hub"
	title.TextColor3 = Color3.fromRGB(235, 240, 255)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Position = UDim2.fromOffset(20, 48)
	note.Size = UDim2.new(1, -40, 0, 36)
	note.Font = Enum.Font.Gotham
	note.Text = "Get a Work.ink key, then paste the token here. Owner keys still work."
	note.TextColor3 = Color3.fromRGB(160, 170, 190)
	note.TextSize = 13
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.Parent = card

	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(20, 100)
	box.Size = UDim2.new(1, -40, 0, 40)
	box.BackgroundColor3 = Color3.fromRGB(28, 34, 44)
	box.Font = Enum.Font.Gotham
	box.PlaceholderText = "Work.ink token or KULZLX-...."
	box.Text = saved and saved.key or ""
	box.TextColor3 = Color3.fromRGB(240, 245, 255)
	box.TextSize = 15
	box.ClearTextOnFocus = false
	box.Parent = card
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

	local submit = Instance.new("TextButton")
	submit.Position = UDim2.fromOffset(20, 156)
	submit.Size = UDim2.fromOffset(180, 42)
	submit.BackgroundColor3 = Color3.fromRGB(46, 140, 255)
	submit.Font = Enum.Font.GothamBold
	submit.Text = "Unlock"
	submit.TextColor3 = Color3.fromRGB(255, 255, 255)
	submit.TextSize = 15
	submit.Parent = card
	Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 8)

	local copy = Instance.new("TextButton")
	copy.Position = UDim2.fromOffset(214, 156)
	copy.Size = UDim2.fromOffset(186, 42)
	copy.BackgroundColor3 = Color3.fromRGB(36, 44, 56)
	copy.Font = Enum.Font.Gotham
	copy.Text = "Get key"
	copy.TextColor3 = Color3.fromRGB(220, 230, 240)
	copy.TextSize = 15
	copy.Parent = card
	Instance.new("UICorner", copy).CornerRadius = UDim.new(0, 8)

	local function finish(key)
		result = key
		gui:Destroy()
		done:Fire()
	end

	submit.MouseButton1Click:Connect(function()
		if box.Text and box.Text ~= "" then
			finish(box.Text)
		end
	end)
	copy.MouseButton1Click:Connect(function()
		local pack, err = api("POST", "/auth/keylink", {
			hwid = hwid(),
			userId = LocalPlayer and LocalPlayer.UserId or 0,
		})
		local url = pack and pack.payload and pack.payload.url
		if not url and KEY_URL ~= "" then
			url = KEY_URL
		end
		if url and typeof(setclipboard) == "function" then
			setclipboard(url)
			notify("Kulzlx", "Work.ink link copied — finish it, then paste the token")
		else
			notify("Kulzlx", tostring(err or (pack and pack.error) or "set work.ink link in workink.json"))
		end
	end)

	done.Event:Wait()
	return result
end

local function access(key)
	local pack, err = api("POST", "/auth/access", {
		key = key,
		hwid = hwid(),
		userId = LocalPlayer and LocalPlayer.UserId or 0,
		executor = executorName(),
		placeId = game.PlaceId,
		universeId = game.GameId,
	})
	if pack and pack.payload then
		return pack
	end
	return nil, err
end

local function detectGame(catalog)
	local pid, uid = game.PlaceId, game.GameId
	for _, g in ipairs(catalog) do
		for _, id in ipairs(g.placeIds or {}) do
			if id == pid then
				return g
			end
		end
		for _, id in ipairs(g.universeIds or {}) do
			if id == uid then
				return g
			end
		end
	end
	return nil
end

local function runSource(src, chunkName)
	local fn, err = loadstring(src, chunkName or "@kulzlx")
	if not fn then
		return false, err
	end
	local ok, runErr = pcall(fn)
	if not ok then
		return false, runErr
	end
	return true
end

local function loadLocalCatalog()
	local raw = readLocal("hub_loader/catalog.json")
	if not raw then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function startHeartbeat(token)
	task.spawn(function()
		while G.Kulzlx and G.Kulzlx.token == token do
			task.wait(45)
			local hb = api("POST", "/hb", { hwid = hwid() }, token)
			if not hb then
				notify("Kulzlx", "heartbeat failed")
			end
		end
	end)
end

local function localKeyOk(key)
	local raw = readLocal("hub_loader/data/licenses.json")
	if not raw then
		return true
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(data) ~= "table" then
		return false
	end
	for _, lic in ipairs(data.licenses or {}) do
		if lic.key == key then
			return true
		end
	end
	return false
end

local function queueLoader()
	if typeof(queue_on_teleport) ~= "function" then
		return
	end
	local src = table.concat({
		"getgenv().KULZLX_AUTH_URL = " .. string.format("%q", AUTH_URL),
		"getgenv().KULZLX_KEY = " .. string.format("%q", G.KULZLX_KEY or ""),
		'local p = "C:/Users/gyhdgsg/Desktop/roblox script/loader.lua"',
		"if isfile and isfile('loader.lua') then loadstring(readfile('loader.lua'))()",
		"elseif isfile and isfile(p) then loadstring(readfile(p))() end",
	}, "\n")
	queue_on_teleport(src)
end

local function main()
	notify("Kulzlx", "detecting " .. tostring(game.PlaceId))

	local key = promptKey()
	if not key or key == "" then
		notify("Kulzlx", "no key")
		return
	end
	G.KULZLX_KEY = key
	G.VGC_KEY = key

	local session, err = access(key)
	local token, catalog, gameRec

	if err == "invalid_key" or err == "hwid_mismatch" or err == "key_expired" then
		notify("Kulzlx", tostring(err))
		return
	end

	if session and session.payload then
		token = session.payload.token
		G.Kulzlx.token = token
		G.Kulzlx.fingerprint = session.payload.fingerprint or session.fingerprint
		saveSession({ key = key, token = token, fingerprint = G.Kulzlx.fingerprint })
		notify("Kulzlx", "access ok · RSA " .. string.sub(tostring(G.Kulzlx.fingerprint or ""), 1, 8))

		local hub = api("GET", "/hub", nil, token)
		if hub and hub.payload and hub.payload.games then
			catalog = hub.payload.games
		end
		gameRec = session.payload.game or detectGame(catalog or {})
		startHeartbeat(token)
		pcall(function()
			api("GET", "/task", nil, token)
			api("GET", "/model/" .. tostring((gameRec and gameRec.id) or "hub"), nil, token)
		end)
	else
		if not localKeyOk(key) then
			notify("Kulzlx", "invalid local key")
			return
		end
		notify("Kulzlx", "auth server offline · local fallback (" .. tostring(err) .. ")")
		local localCat = loadLocalCatalog()
		catalog = localCat and localCat.games or {}
		gameRec = detectGame(catalog)
	end

	if not gameRec then
		notify("Kulzlx", "no hub for this game · place " .. tostring(game.PlaceId))
		return
	end

	local src
	if token then
		local cdn = api("GET", "/cdn/" .. gameRec.id, nil, token)
		if cdn and cdn.payload and type(cdn.payload.script) == "string" then
			src = cdn.payload.script
			if cdn.payload.sha256 and crypt and typeof(crypt.hash) == "function" then
				local hex = crypt.hash(src, "sha256")
				if type(hex) == "string" and hex:lower() ~= cdn.payload.sha256 then
					notify("Kulzlx", "cdn hash mismatch")
					src = nil
				end
			end
		end
	end
	if not src then
		src = readLocal(gameRec.file)
	end
	if not src then
		notify("Kulzlx", "script missing: " .. tostring(gameRec.file))
		return
	end

	queueLoader()
	notify("Kulzlx", "loading " .. tostring(gameRec.name))
	local ok, runErr = runSource(src, "@" .. tostring(gameRec.label or gameRec.id))
	if not ok then
		notify("Kulzlx", "execute failed: " .. tostring(runErr))
	end
end

task.spawn(main)

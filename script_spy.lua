--[[
  Script Spy - WindUI
  live-reload label: script_spy

  Run this FIRST, then execute the other hub.
  Click their buttons. Copy the generated replay, or dump the
  captured loadstring/HttpGet source.

  RightShift toggles the window.
]]

local function makeStateShim()
	local alive = true
	local cleanups = {}
	return {
		alive = function()
			return alive
		end,
		connect = function(signal, fn)
			local conn = signal:Connect(fn)
			table.insert(cleanups, function()
				pcall(function()
					conn:Disconnect()
				end)
			end)
			return conn
		end,
		onCleanup = function(fn)
			if typeof(fn) == "function" then
				table.insert(cleanups, fn)
			end
		end,
		override = function(tbl, key, value)
			tbl[key] = value
		end,
		namecallHook = function()
			return nil
		end,
		_kill = function()
			alive = false
			for i = #cleanups, 1, -1 do
				pcall(cleanups[i])
				cleanups[i] = nil
			end
		end,
	}
end

local function resolveState()
	local function okState(s)
		return typeof(s) == "table"
			and typeof(s.alive) == "function"
			and typeof(s.connect) == "function"
			and typeof(s.onCleanup) == "function"
	end
	for _, level in ipairs({ 1, 0, 2 }) do
		local ok, env = pcall(getfenv, level)
		if ok and typeof(env) == "table" and okState(env.STATE) then
			return env.STATE
		end
	end
	if typeof(getgenv) == "function" then
		local genv = getgenv()
		if typeof(genv) == "table" and okState(genv.STATE) then
			return genv.STATE
		end
	end
	return makeStateShim()
end

local STATE = resolveState()

local WINDUI_PATHS = {
	"WindUI.lua",
	"./WindUI.lua",
	"MCP/WindUI.lua",
	"scripts/MCP/WindUI.lua",
	[[C:\Users\gyhdgsg\AppData\Local\Real\workspace\WindUI.lua]],
	[[C:\Users\gyhdgsg\AppData\Local\Real\scripts\MCP\WindUI.lua]],
	[[C:\Users\gyhdgsg\Desktop\roblox script\WindUI-main\WindUI-main\dist\main.lua]],
	[[C:\Users\gyhdgsg\Desktop\roblox script\WindUI.lua]],
}

local function loadWindUI()
	for _, path in ipairs(WINDUI_PATHS) do
		if isfile and isfile(path) then
			local src = readfile(path)
			local fn, err = loadstring(src, "@WindUI")
			assert(fn, "WindUI compile failed: " .. tostring(err))
			return fn()
		end
	end
	error("WindUI not found at expected local paths")
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

do
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function hui()
		return pg
	end
	if typeof(getgenv) == "function" then
		local genv = getgenv()
		genv.gethui = hui
		genv.get_hidden_gui = hui
		genv.get_hidden_ui = hui
		genv.gethiddengui = hui
		genv.gethiddenui = hui
		genv.protectgui = function() end
	end
	gethui = hui
	protectgui = function() end
end

local WindUI = loadWindUI()
local LocalPlayer = Players.LocalPlayer

if not STATE.store then
	STATE.store = {}
end
local store = STATE.store

local CFG = store.cfg
	or {
		Enabled = true,
		CaptureRemotes = true,
		CaptureHttp = true,
		CaptureLoadstring = true,
		CaptureExecApis = true,
		CaptureGetgenv = true,
		CaptureInbound = true,
		SourceFilter = "Hubs only",
		IgnoreSubstr = "",
		BlockIgnored = false,
		AutoRefresh = true,
		AutoSaveHubs = true,
		MaxLogs = 250,
		Silent = false,
	}
store.cfg = CFG

local NAMECALL_KINDS = {
	FireServer = "remote",
	InvokeServer = "remote",
	Fire = "bindable",
	Invoke = "bindable",
	HttpGet = "http",
	HttpGetAsync = "http",
	HttpPost = "http",
	HttpPostAsync = "http",
	GetAsync = "http",
	PostAsync = "http",
	RequestAsync = "http",
}

local EXEC_API_NAMES = {
	"request",
	"http_request",
	"httpget",
	"fireclickdetector",
	"fireproximityprompt",
	"firetouchinterest",
	"firesignal",
	"queueonteleport",
	"queue_on_teleport",
	"setthreadidentity",
	"setidentity",
	"setthreadcontext",
	"getsenv",
	"getmenv",
}

local OUR_GENV_SKIP = {
	STATE = true,
	gethui = true,
	get_hidden_gui = true,
	get_hidden_ui = true,
	gethiddengui = true,
	gethiddenui = true,
	protectgui = true,
	ScriptSpy = true,
}

local internal = false
local incoming = {}
local logs = store.logs or {}
store.logs = logs
local hubSources = store.hubSources or {}
store.hubSources = hubSources
local oldNamecall
local oldIndex
local oldGlobals = store.oldGlobals or {}
store.oldGlobals = oldGlobals
local inboundWrapped = store.inboundWrapped or setmetatable({}, { __mode = "k" })
store.inboundWrapped = inboundWrapped
local genvSnapshot = store.genvSnapshot
local lastUiAt = 0
local selectedIndex = 0

local logPara
local codeEl
local statsPara

local function notify(title, content)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = title or "Spy",
			Content = tostring(content or ""),
			Duration = 2.4,
		})
	end)
end

local function ensureFolders()
	if typeof(makefolder) ~= "function" then
		return
	end
	pcall(makefolder, "script_spy")
	pcall(makefolder, "script_spy/hubs")
end

local function stamp()
	local t = os.date("%Y%m%d_%H%M%S")
	return tostring(t)
end

local function toClipboard(text)
	if typeof(setclipboard) == "function" then
		setclipboard(text)
		return true
	end
	if typeof(toclipboard) == "function" then
		toclipboard(text)
		return true
	end
	return false
end

local function writeDump(path, text)
	if typeof(writefile) ~= "function" then
		return false
	end
	ensureFolders()
	local ok = pcall(writefile, path, text)
	return ok
end

local function callerStack()
	local parts = {}
	if typeof(debug) ~= "table" or typeof(debug.info) ~= "function" then
		return "?"
	end
	for i = 3, 9 do
		local ok, src, line, name = pcall(debug.info, i, "sln")
		if not ok or type(src) ~= "string" then
			break
		end
		if src ~= "[C]" then
			table.insert(parts, string.format("%s:%s %s", src, tostring(line or "?"), tostring(name or "?")))
		end
	end
	if #parts == 0 then
		local ok, src = pcall(debug.info, 3, "s")
		return ok and tostring(src) or "?"
	end
	return table.concat(parts, " <- ")
end

local function instancePath(inst)
	if typeof(inst) ~= "Instance" then
		return "nil"
	end
	local ok, full = pcall(function()
		return inst:GetFullName()
	end)
	if not ok or type(full) ~= "string" or full == "" then
		local ok2, n = pcall(function()
			return inst.Name
		end)
		return ok2 and tostring(n) or "Instance"
	end
	return full
end

local function pathExpr(inst)
	if typeof(inst) ~= "Instance" then
		return "nil"
	end
	if inst == game then
		return "game"
	end
	local full = instancePath(inst)
	local parts = string.split(full, ".")
	if parts[1] == "Game" or parts[1] == "game" then
		table.remove(parts, 1)
	end
	if #parts == 0 then
		return "game"
	end
	local expr = string.format('game:GetService("%s")', parts[1]:gsub('"', '\\"'))
	for i = 2, #parts do
		expr = expr .. string.format(':WaitForChild("%s")', parts[i]:gsub('"', '\\"'))
	end
	return expr
end

local function serialize(value, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if depth > 5 then
		return "..."
	end
	local t = typeof(value)
	if t == "nil" then
		return "nil"
	elseif t == "boolean" then
		return value and "true" or "false"
	elseif t == "number" then
		if value ~= value then
			return "0/0"
		end
		if value == math.huge then
			return "math.huge"
		end
		if value == -math.huge then
			return "-math.huge"
		end
		return tostring(value)
	elseif t == "string" then
		if #value > 4000 then
			return string.format("%q", value:sub(1, 4000) .. "...[" .. tostring(#value) .. " chars]")
		end
		return string.format("%q", value)
	elseif t == "Instance" then
		return pathExpr(value)
	elseif t == "Vector3" then
		return string.format("Vector3.new(%.6f, %.6f, %.6f)", value.X, value.Y, value.Z)
	elseif t == "Vector2" then
		return string.format("Vector2.new(%.6f, %.6f)", value.X, value.Y)
	elseif t == "CFrame" then
		local c = { value:GetComponents() }
		for i = 1, #c do
			c[i] = string.format("%.6f", c[i])
		end
		return "CFrame.new(" .. table.concat(c, ", ") .. ")"
	elseif t == "Color3" then
		return string.format("Color3.new(%.6f, %.6f, %.6f)", value.R, value.G, value.B)
	elseif t == "UDim2" then
		return string.format(
			"UDim2.new(%.6f, %d, %.6f, %d)",
			value.X.Scale,
			value.X.Offset,
			value.Y.Scale,
			value.Y.Offset
		)
	elseif t == "UDim" then
		return string.format("UDim.new(%.6f, %d)", value.Scale, value.Offset)
	elseif t == "EnumItem" then
		return tostring(value)
	elseif t == "BrickColor" then
		return string.format("BrickColor.new(%q)", tostring(value))
	elseif t == "NumberRange" then
		return string.format("NumberRange.new(%.6f, %.6f)", value.Min, value.Max)
	elseif t == "Rect" then
		return string.format("Rect.new(%.6f, %.6f, %.6f, %.6f)", value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
	elseif t == "Ray" then
		return string.format("Ray.new(%s, %s)", serialize(value.Origin, depth + 1, seen), serialize(value.Direction, depth + 1, seen))
	elseif t == "TweenInfo" then
		return string.format(
			"TweenInfo.new(%.6f, %s, %s, %d, %s, %.6f)",
			value.Time,
			tostring(value.EasingStyle),
			tostring(value.EasingDirection),
			value.RepeatCount,
			tostring(value.Reverses),
			value.DelayTime
		)
	elseif t == "buffer" then
		return string.format("buffer.create(%d)", buffer.len(value))
	elseif t == "function" then
		local name = "?"
		if typeof(debug) == "table" and typeof(debug.info) == "function" then
			local ok, n = pcall(debug.info, value, "n")
			if ok and n and n ~= "" then
				name = n
			end
		end
		return string.format("--[[function %s]] nil", name)
	elseif t == "table" then
		if seen[value] then
			return "{--[[cycle]]}"
		end
		seen[value] = true
		local isArray = true
		local count = 0
		for k in pairs(value) do
			count += 1
			if typeof(k) ~= "number" then
				isArray = false
			end
			if count > 40 then
				break
			end
		end
		local pieces = {}
		if isArray then
			for i = 1, math.min(#value, 40) do
				table.insert(pieces, serialize(value[i], depth + 1, seen))
			end
		else
			local n = 0
			for k, v in pairs(value) do
				n += 1
				if n > 40 then
					table.insert(pieces, "--[[truncated]]")
					break
				end
				local key
				if type(k) == "string" and k:match("^[%a_][%w_]*$") then
					key = k .. " = "
				else
					key = "[" .. serialize(k, depth + 1, seen) .. "] = "
				end
				table.insert(pieces, key .. serialize(v, depth + 1, seen))
			end
		end
		return "{ " .. table.concat(pieces, ", ") .. " }"
	end
	return string.format("--[[%s]] nil", t)
end

local function argsExpr(args)
	if type(args) ~= "table" or #args == 0 then
		return ""
	end
	local parts = {}
	for i = 1, #args do
		table.insert(parts, serialize(args[i]))
	end
	return table.concat(parts, ", ")
end

local function matchesIgnore(text)
	local sub = CFG.IgnoreSubstr
	if type(sub) ~= "string" or sub == "" then
		return false
	end
	return string.find(string.lower(tostring(text)), string.lower(sub), 1, true) ~= nil
end

local function sourceAllowed(fromHub)
	local f = CFG.SourceFilter
	if f == "Hubs only" then
		return fromHub == true
	end
	if f == "Game only" then
		return fromHub ~= true
	end
	return true
end

local function generateReplay(entry)
	local lines = {}
	table.insert(lines, string.format("-- %s  %s  from=%s", entry.kind, entry.when or "?", entry.fromHub and "hub" or "game"))
	if entry.stack and entry.stack ~= "?" then
		table.insert(lines, "-- stack: " .. entry.stack)
	end
	if entry.kind == "remote" or entry.kind == "bindable" or entry.method == "FireServer" or entry.method == "InvokeServer" then
		local target = entry.pathExpr or "nil"
		local args = argsExpr(entry.args)
		if args ~= "" then
			table.insert(lines, string.format("%s:%s(%s)", target, entry.method, args))
		else
			table.insert(lines, string.format("%s:%s()", target, entry.method))
		end
		if entry.rets and #entry.rets > 0 then
			table.insert(lines, "-- returned: " .. argsExpr(entry.rets))
		end
	elseif entry.kind == "http" then
		local target = entry.pathExpr or "game"
		local args = argsExpr(entry.args)
		table.insert(lines, string.format("local body = %s:%s(%s)", target, entry.method, args))
		if type(entry.bodyPreview) == "string" then
			table.insert(lines, string.format("-- body %d chars, saved=%s", entry.bodyLen or #entry.bodyPreview, tostring(entry.savedAs or "?")))
		end
	elseif entry.kind == "loadstring" then
		table.insert(lines, string.format("-- loadstring chunk %d chars  name=%s", entry.srcLen or 0, tostring(entry.chunkName or "")))
		if entry.savedAs then
			table.insert(lines, string.format("-- dumped to %s", entry.savedAs))
		end
		if type(entry.srcPreview) == "string" then
			table.insert(lines, "-- preview:")
			table.insert(lines, "-- " .. entry.srcPreview:gsub("\n", "\n-- "))
		end
	elseif entry.kind == "execapi" then
		local args = argsExpr(entry.args)
		table.insert(lines, string.format("%s(%s)", entry.method, args))
	elseif entry.kind == "getgenv" then
		table.insert(lines, string.format("getgenv().%s = %s", tostring(entry.key), serialize(entry.value)))
	elseif entry.kind == "inbound" then
		local target = entry.pathExpr or "nil"
		table.insert(lines, string.format("-- OnClientEvent %s(%s)", target, argsExpr(entry.args)))
	else
		table.insert(lines, string.format("-- %s %s(%s)", entry.kind, tostring(entry.method), argsExpr(entry.args)))
	end
	return table.concat(lines, "\n")
end

local function pushLog(entry)
	entry.when = os.date("%H:%M:%S")
	entry.replay = generateReplay(entry)
	table.insert(logs, entry)
	local maxn = tonumber(CFG.MaxLogs) or 250
	while #logs > maxn do
		table.remove(logs, 1)
	end
	selectedIndex = #logs
	store.lastReplay = entry.replay
end

local function saveHubSource(label, src)
	if type(src) ~= "string" or #src < 40 then
		return nil
	end
	if not CFG.AutoSaveHubs then
		hubSources[#hubSources + 1] = { label = label, src = src, when = stamp() }
		return nil
	end
	ensureFolders()
	local safe = tostring(label or "hub"):gsub("[^%w%._%-]", "_"):sub(1, 60)
	local path = string.format("script_spy/hubs/%s_%s.lua", stamp(), safe)
	if writeDump(path, src) then
		hubSources[#hubSources + 1] = { label = label, src = src, path = path, when = stamp() }
		return path
	end
	hubSources[#hubSources + 1] = { label = label, src = src, when = stamp() }
	return nil
end

local function consume(rec)
	if not CFG.Enabled then
		return
	end
	if not sourceAllowed(rec.fromHub == true) then
		return
	end

	local kind = rec.kind
	local method = rec.method
	local namecallKind = NAMECALL_KINDS[method or ""]

	if kind == "namecall" or kind == "indexcall" then
		if namecallKind == "remote" or namecallKind == "bindable" then
			if not CFG.CaptureRemotes then
				return
			end
			kind = namecallKind
		elseif namecallKind == "http" then
			if not CFG.CaptureHttp then
				return
			end
			kind = "http"
		else
			return
		end
	end

	local path = instancePath(rec.self)
	local blob = (path or "") .. " " .. tostring(method) .. " " .. tostring(rec.key or "")
	if matchesIgnore(blob) then
		return
	end

	local entry = {
		kind = kind,
		method = method,
		fromHub = rec.fromHub == true,
		args = rec.args or {},
		rets = rec.rets,
		self = rec.self,
		path = path,
		pathExpr = typeof(rec.self) == "Instance" and pathExpr(rec.self) or nil,
		stack = rec.stack,
		key = rec.key,
		value = rec.value,
		chunkName = rec.chunkName,
	}

	if kind == "http" then
		local url = rec.args and rec.args[1]
		local body = rec.rets and rec.rets[1]
		if type(body) == "string" then
			entry.bodyLen = #body
			entry.bodyPreview = body:sub(1, 240)
			if #body > 80 then
				entry.savedAs = saveHubSource(type(url) == "string" and url or method, body)
			end
		end
	elseif kind == "loadstring" then
		if not CFG.CaptureLoadstring then
			return
		end
		local src = rec.src
		entry.srcLen = type(src) == "string" and #src or 0
		entry.srcPreview = type(src) == "string" and src:sub(1, 400) or ""
		if type(src) == "string" then
			entry.savedAs = saveHubSource(rec.chunkName or "loadstring", src)
		end
	elseif kind == "execapi" then
		if not CFG.CaptureExecApis then
			return
		end
		local url
		local a1 = rec.args and rec.args[1]
		if type(a1) == "table" and type(a1.Url) == "string" then
			url = a1.Url
		elseif type(a1) == "string" and a1:find("https?://", 1, false) then
			url = a1
		end
		if rec.rets and type(rec.rets[1]) == "table" and type(rec.rets[1].Body) == "string" and #rec.rets[1].Body > 80 then
			entry.savedAs = saveHubSource(url or method, rec.rets[1].Body)
		elseif rec.rets and type(rec.rets[1]) == "string" and #rec.rets[1] > 80 then
			entry.savedAs = saveHubSource(url or method, rec.rets[1])
		end
	elseif kind == "getgenv" then
		if not CFG.CaptureGetgenv then
			return
		end
	elseif kind == "inbound" then
		if not CFG.CaptureInbound then
			return
		end
	end

	pushLog(entry)
end

local function enqueue(rec)
	if internal then
		return
	end
	incoming[#incoming + 1] = rec
end

local function shouldCaptureCaller()
	if typeof(checkcaller) == "function" then
		local ok, v = pcall(checkcaller)
		if ok then
			return v == true
		end
	end
	return true
end

local function packArgs(...)
	return { ... }
end

local function installNamecall()
	if typeof(hookmetamethod) ~= "function" or typeof(getnamecallmethod) ~= "function" then
		return false
	end
	local wrap = newcclosure or function(f)
		return f
	end
	oldNamecall = hookmetamethod(
		game,
		"__namecall",
		wrap(function(self, ...)
			local method = getnamecallmethod()
			if internal or not NAMECALL_KINDS[method] then
				return oldNamecall(self, ...)
			end
			local args = packArgs(...)
			local fromHub = shouldCaptureCaller()
			local rec = {
				kind = "namecall",
				self = self,
				method = method,
				args = args,
				fromHub = fromHub,
				stack = callerStack(),
			}
			if method == "InvokeServer" or method == "Invoke" or NAMECALL_KINDS[method] == "http" then
				local packed = table.pack(oldNamecall(self, ...))
				local rets = {}
				for i = 1, packed.n do
					rets[i] = packed[i]
				end
				rec.rets = rets
				enqueue(rec)
				return table.unpack(packed, 1, packed.n)
			end
			local instName = "?"
			if oldIndex then
				local okName, n = pcall(oldIndex, self, "Name")
				if okName then
					instName = tostring(n)
				end
			end
			if CFG.BlockIgnored and matchesIgnore(instName .. " " .. method) then
				return
			end
			enqueue(rec)
			return oldNamecall(self, ...)
		end)
	)
	return true
end

local function installIndex()
	if typeof(hookmetamethod) ~= "function" then
		return false
	end
	local wrap = newcclosure or function(f)
		return f
	end
	local INDEX_METHODS = {
		FireServer = true,
		InvokeServer = true,
		Fire = true,
		Invoke = true,
		HttpGet = true,
		HttpGetAsync = true,
	}
	oldIndex = hookmetamethod(
		game,
		"__index",
		wrap(function(self, key)
			local val = oldIndex(self, key)
			if internal then
				return val
			end
			if type(key) == "string" and INDEX_METHODS[key] and typeof(self) == "Instance" and typeof(val) == "function" then
				return wrap(function(remote, ...)
					if internal then
						return val(remote, ...)
					end
					local args = packArgs(...)
					local fromHub = shouldCaptureCaller()
					if key == "InvokeServer" or key == "Invoke" or key == "HttpGet" or key == "HttpGetAsync" then
						local packed = table.pack(val(remote, ...))
						local rets = {}
						for i = 1, packed.n do
							rets[i] = packed[i]
						end
						enqueue({
							kind = "indexcall",
							self = remote,
							method = key,
							args = args,
							rets = rets,
							fromHub = fromHub,
						})
						return table.unpack(packed, 1, packed.n)
					end
					enqueue({
						kind = "indexcall",
						self = remote,
						method = key,
						args = args,
						fromHub = fromHub,
					})
					return val(remote, ...)
				end)
			end
			return val
		end)
	)
	return true
end

local function hookGlobal(name, kind)
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	local fn = genv[name]
	if typeof(fn) ~= "function" then
		if type(syn) == "table" and typeof(syn[name]) == "function" then
			fn = syn[name]
		else
			return
		end
	end
	if oldGlobals[name] then
		return
	end
	local wrap = newcclosure or function(f)
		return f
	end
	local hf = hookfunction or hookfunc
	if typeof(hf) ~= "function" then
		local orig = fn
		genv[name] = function(...)
			if internal then
				return orig(...)
			end
			local args = packArgs(...)
			local packed = table.pack(orig(...))
			local rets = {}
			for i = 1, packed.n do
				rets[i] = packed[i]
			end
			enqueue({
				kind = kind,
				method = name,
				args = args,
				rets = rets,
				fromHub = true,
				src = kind == "loadstring" and args[1] or nil,
				chunkName = kind == "loadstring" and args[2] or nil,
			})
			return table.unpack(packed, 1, packed.n)
		end
		oldGlobals[name] = orig
		return
	end
	local old
	local ok = pcall(function()
		old = hf(
			fn,
			wrap(function(...)
				if internal then
					return old(...)
				end
				local args = packArgs(...)
				local packed = table.pack(old(...))
				local rets = {}
				for i = 1, packed.n do
					rets[i] = packed[i]
				end
				enqueue({
					kind = kind,
					method = name,
					args = args,
					rets = rets,
					fromHub = true,
					src = kind == "loadstring" and args[1] or nil,
					chunkName = kind == "loadstring" and args[2] or nil,
				})
				return table.unpack(packed, 1, packed.n)
			end)
		)
	end)
	if ok and old then
		oldGlobals[name] = old
	end
end

local function installExecHooks()
	hookGlobal("loadstring", "loadstring")
	hookGlobal("load", "loadstring")
	for _, name in ipairs(EXEC_API_NAMES) do
		hookGlobal(name, "execapi")
	end
	if type(http) == "table" and typeof(http.request) == "function" then
		hookGlobal("request", "execapi")
	end
	if type(syn) == "table" and typeof(syn.request) == "function" then
		local orig = syn.request
		if not oldGlobals["syn.request"] then
			syn.request = function(...)
				if internal then
					return orig(...)
				end
				local args = packArgs(...)
				local packed = table.pack(orig(...))
				local rets = {}
				for i = 1, packed.n do
					rets[i] = packed[i]
				end
				enqueue({
					kind = "execapi",
					method = "syn.request",
					args = args,
					rets = rets,
					fromHub = true,
				})
				return table.unpack(packed, 1, packed.n)
			end
			oldGlobals["syn.request"] = orig
		end
	end
end

local function wrapInbound(remote)
	if inboundWrapped[remote] then
		return
	end
	if typeof(getconnections) ~= "function" then
		return
	end
	local classOk, className = pcall(function()
		return remote.ClassName
	end)
	if not classOk then
		return
	end
	if className ~= "RemoteEvent" and className ~= "UnreliableRemoteEvent" then
		return
	end
	local ok, conns = pcall(getconnections, remote.OnClientEvent)
	if not ok or type(conns) ~= "table" then
		return
	end
	inboundWrapped[remote] = true
	for _, conn in ipairs(conns) do
		local fn = conn.Function or conn.func
		if typeof(fn) == "function" and typeof(hookfunction) == "function" then
			pcall(function()
				local old
				old = hookfunction(fn, function(...)
					if not internal then
						enqueue({
							kind = "inbound",
							method = "OnClientEvent",
							self = remote,
							args = packArgs(...),
							fromHub = false,
						})
					end
					return old(...)
				end)
			end)
		end
	end
end

local function scanInbound()
	if not CFG.CaptureInbound or typeof(getconnections) ~= "function" then
		return 0
	end
	local n = 0
	local function walk(root)
		local children
		local ok = pcall(function()
			children = root:GetDescendants()
		end)
		if not ok or type(children) ~= "table" then
			return
		end
		for _, inst in ipairs(children) do
			if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
				wrapInbound(inst)
				n += 1
			end
		end
	end
	pcall(walk, game:GetService("ReplicatedStorage"))
	pcall(walk, game:GetService("ReplicatedFirst"))
	pcall(function()
		walk(LocalPlayer)
	end)
	pcall(function()
		walk(game:GetService("Workspace"))
	end)
	return n
end

local function snapshotGenv()
	if typeof(getgenv) ~= "function" then
		return
	end
	local snap = {}
	for k, v in pairs(getgenv()) do
		snap[k] = v
	end
	genvSnapshot = snap
	store.genvSnapshot = snap
end

local function pollGenv()
	if not CFG.CaptureGetgenv or typeof(getgenv) ~= "function" then
		return
	end
	if not genvSnapshot then
		snapshotGenv()
		return
	end
	local genv = getgenv()
	for k, v in pairs(genv) do
		if not OUR_GENV_SKIP[k] and genvSnapshot[k] ~= v then
			genvSnapshot[k] = v
			enqueue({
				kind = "getgenv",
				method = "getgenv",
				key = k,
				value = v,
				args = { k, v },
				fromHub = true,
			})
		end
	end
end

local function scanHubClosures(limit)
	limit = limit or 200
	if typeof(getgc) ~= "function" then
		return { "getgc not available on this executor" }
	end
	local out = {}
	local n = 0
	local ok, objs = pcall(getgc, false)
	if not ok or type(objs) ~= "table" then
		return { "getgc failed" }
	end
	for _, obj in ipairs(objs) do
		if typeof(obj) == "function" then
			local src, name, line = "?", "?", "?"
			if typeof(debug) == "table" and typeof(debug.info) == "function" then
				pcall(function()
					src = debug.info(obj, "s") or "?"
					name = debug.info(obj, "n") or "?"
					line = debug.info(obj, "l") or "?"
				end)
			end
			local isLua = true
			if typeof(islclosure) == "function" then
				local ok2, v = pcall(islclosure, obj)
				isLua = ok2 and v == true
			end
			if isLua and type(src) == "string" and src ~= "" then
				local looksHub = src:sub(1, 1) == "="
					or src:sub(1, 1) == "@"
					or src:find("http", 1, true)
					or src:find("loadstring", 1, true)
					or src:find("MCP", 1, true)
				if looksHub then
					n += 1
					table.insert(out, string.format("%s  %s:%s", tostring(name), tostring(src), tostring(line)))
					if n >= limit then
						break
					end
				end
			end
		end
		if n % 80 == 0 then
			task.wait()
		end
	end
	if #out == 0 then
		return { "no hub closures found (run the other hub first)" }
	end
	return out
end

local function logFeed(maxRows)
	maxRows = maxRows or 14
	if #logs == 0 then
		return "empty — run the other hub and click something"
	end
	local start = math.max(1, #logs - maxRows + 1)
	local lines = {}
	for i = start, #logs do
		local e = logs[i]
		local tag = e.fromHub and "HUB" or "GAME"
		local dest = e.path or e.method or "?"
		table.insert(lines, string.format("[%d] %s %s %s %s", i, e.when or "", tag, tostring(e.method), tostring(dest)))
	end
	return table.concat(lines, "\n")
end

local function statsText()
	local last = logs[#logs]
	return string.format(
		"logs=%d  hubs_saved=%d  last=%s\nfilter=%s  remotes=%s http=%s loadstring=%s apis=%s",
		#logs,
		#hubSources,
		last and (tostring(last.method) .. " " .. tostring(last.path or last.key or "")) or "none",
		tostring(CFG.SourceFilter),
		tostring(CFG.CaptureRemotes),
		tostring(CFG.CaptureHttp),
		tostring(CFG.CaptureLoadstring),
		tostring(CFG.CaptureExecApis)
	)
end

local function lastReplay()
	local e = logs[selectedIndex] or logs[#logs]
	return (e and e.replay) or "-- nothing captured yet"
end

local function refreshUi()
	if logPara and logPara.SetDesc then
		pcall(function()
			logPara:SetDesc(logFeed(14))
		end)
	end
	if statsPara and statsPara.SetDesc then
		pcall(function()
			statsPara:SetDesc(statsText())
		end)
	end
	if codeEl and codeEl.SetCode then
		pcall(function()
			codeEl:SetCode(lastReplay())
		end)
	elseif codeEl and codeEl.Set then
		pcall(function()
			codeEl:Set(lastReplay())
		end)
	end
end

local function dumpAll()
	local chunks = {}
	table.insert(chunks, "-- script spy dump  " .. stamp())
	table.insert(chunks, "-- " .. statsText())
	table.insert(chunks, "")
	for i, e in ipairs(logs) do
		table.insert(chunks, string.format("-- ===== %d =====", i))
		table.insert(chunks, e.replay or "")
		table.insert(chunks, "")
	end
	return table.concat(chunks, "\n")
end

if store.window then
	pcall(function()
		store.window:Destroy()
	end)
	store.window = nil
end

local Window = WindUI:CreateWindow({
	Title = "Script Spy",
	Author = "capture · replay · copy hubs",
	Folder = "ScriptSpy",
	Icon = "eye",
	NewElements = true,
	Size = UDim2.fromOffset(620, 560),
	HideSearchBar = false,
	OpenButton = {
		Title = "Spy",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		OnlyIcon = true,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#7C5CFF"), Color3.fromHex("#2fe7ff")),
	},
})
store.window = Window
pcall(function()
	Window:SetToggleKey(Enum.KeyCode.RightShift)
end)

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")
local Purple = Color3.fromHex("#9B59B6")

local Hub = Window:Section({ Title = "Spy", Opened = true })

do
	local t = Hub:Tab({ Title = "Log", Icon = "scroll-text", IconColor = Green })
	statsPara = t:Paragraph({ Title = "Status", Desc = statsText() })
	logPara = t:Paragraph({ Title = "Recent", Desc = logFeed(14) })
	local okCode, el = pcall(function()
		return t:Code({
			Title = "Replay",
			Code = lastReplay(),
			CanCopied = true,
		})
	end)
	if okCode then
		codeEl = el
	else
		codeEl = t:Paragraph({ Title = "Replay", Desc = lastReplay() })
		codeEl.SetCode = function(_, text)
			if codeEl.SetDesc then
				codeEl:SetDesc(text)
			end
		end
	end
	t:Button({
		Title = "Refresh",
		Icon = "refresh-cw",
		Callback = function()
			refreshUi()
		end,
	})
	t:Button({
		Title = "Copy Last Replay",
		Icon = "clipboard",
		Callback = function()
			local text = lastReplay()
			if toClipboard(text) then
				notify("Spy", "copied last replay")
			else
				notify("Spy", "no clipboard api")
				print(text)
			end
		end,
	})
	t:Button({
		Title = "Replay Last",
		Icon = "play",
		Callback = function()
			local text = lastReplay()
			if text:find("nothing captured", 1, true) then
				notify("Spy", "nothing to replay")
				return
			end
			internal = true
			local fn, err = loadstring(text, "@spy_replay")
			internal = false
			if not fn then
				notify("Spy", "compile failed: " .. tostring(err))
				return
			end
			internal = true
			local ok, runErr = pcall(fn)
			internal = false
			notify("Spy", ok and "replayed" or tostring(runErr))
		end,
	})
	t:Button({
		Title = "Clear Logs",
		Callback = function()
			table.clear(logs)
			selectedIndex = 0
			refreshUi()
			notify("Spy", "cleared")
		end,
	})
end

do
	local t = Hub:Tab({ Title = "Capture", Icon = "radar", IconColor = Blue })
	t:Toggle({
		Title = "Enabled",
		Value = CFG.Enabled == true,
		Callback = function(v)
			CFG.Enabled = v
		end,
	})
	t:Dropdown({
		Title = "Source",
		Values = { "Hubs only", "Game only", "Both" },
		Value = CFG.SourceFilter,
		Callback = function(v)
			CFG.SourceFilter = v
		end,
	})
	t:Toggle({
		Title = "Remotes (FireServer / InvokeServer)",
		Value = CFG.CaptureRemotes == true,
		Callback = function(v)
			CFG.CaptureRemotes = v
		end,
	})
	t:Toggle({
		Title = "HttpGet / RequestAsync",
		Desc = "saves returned source into script_spy/hubs",
		Value = CFG.CaptureHttp == true,
		Callback = function(v)
			CFG.CaptureHttp = v
		end,
	})
	t:Toggle({
		Title = "loadstring",
		Desc = "dumps the other hub's chunk to disk",
		Value = CFG.CaptureLoadstring == true,
		Callback = function(v)
			CFG.CaptureLoadstring = v
		end,
	})
	t:Toggle({
		Title = "Executor APIs",
		Desc = "request, fireclickdetector, fireproximityprompt, …",
		Value = CFG.CaptureExecApis == true,
		Callback = function(v)
			CFG.CaptureExecApis = v
		end,
	})
	t:Toggle({
		Title = "getgenv writes",
		Value = CFG.CaptureGetgenv == true,
		Callback = function(v)
			CFG.CaptureGetgenv = v
		end,
	})
	t:Toggle({
		Title = "OnClientEvent inbound",
		Value = CFG.CaptureInbound == true,
		Callback = function(v)
			CFG.CaptureInbound = v
		end,
	})
	t:Toggle({
		Title = "Auto-save hub sources",
		Value = CFG.AutoSaveHubs == true,
		Callback = function(v)
			CFG.AutoSaveHubs = v
		end,
	})
	t:Toggle({
		Title = "Auto-refresh UI",
		Value = CFG.AutoRefresh == true,
		Callback = function(v)
			CFG.AutoRefresh = v
		end,
	})
	t:Input({
		Title = "Ignore substring",
		Placeholder = "Heartbeat, GetMouse, …",
		Value = CFG.IgnoreSubstr,
		Callback = function(v)
			CFG.IgnoreSubstr = tostring(v or "")
		end,
	})
	t:Toggle({
		Title = "Block ignored remotes",
		Value = CFG.BlockIgnored == true,
		Callback = function(v)
			CFG.BlockIgnored = v
		end,
	})
	t:Slider({
		Title = "Max logs",
		Value = { Min = 50, Max = 800, Default = math.clamp(tonumber(CFG.MaxLogs) or 250, 50, 800) },
		Callback = function(v)
			CFG.MaxLogs = v
		end,
	})
end

do
	local t = Hub:Tab({ Title = "Dump", Icon = "hard-drive", IconColor = Yellow })
	t:Paragraph({
		Title = "Files",
		Desc = "script_spy_dump.lua  ·  script_spy/hubs/*.lua",
	})
	t:Button({
		Title = "Copy All Replays",
		Icon = "clipboard",
		Callback = function()
			local text = dumpAll()
			if toClipboard(text) then
				notify("Spy", "copied " .. tostring(#logs) .. " entries")
			else
				print(text)
				notify("Spy", "printed all (no clipboard)")
			end
		end,
	})
	t:Button({
		Title = "Write script_spy_dump.lua",
		Icon = "save",
		Callback = function()
			local path = "script_spy/script_spy_dump.lua"
			if writeDump(path, dumpAll()) then
				notify("Spy", "wrote " .. path)
			else
				notify("Spy", "writefile missing")
			end
		end,
	})
	t:Button({
		Title = "Copy Last Hub Source",
		Callback = function()
			local last = hubSources[#hubSources]
			if not last or type(last.src) ~= "string" then
				notify("Spy", "no hub source yet — run the other hub")
				return
			end
			if toClipboard(last.src) then
				notify("Spy", "copied " .. tostring(#last.src) .. " chars")
			else
				print(last.src:sub(1, 2000))
				notify("Spy", "printed preview")
			end
		end,
	})
	t:Button({
		Title = "Rescan inbound remotes",
		Callback = function()
			internal = true
			local n = scanInbound()
			internal = false
			notify("Spy", "inbound scan " .. tostring(n) .. " remotes")
		end,
	})
end

do
	local t = Hub:Tab({ Title = "GC", Icon = "search", IconColor = Purple })
	local gcPara = t:Paragraph({
		Title = "Hub closures",
		Desc = "run the other hub, then scan",
	})
	t:Button({
		Title = "Scan getgc for hub functions",
		Icon = "scan-search",
		Callback = function()
			internal = true
			local rows = scanHubClosures(180)
			internal = false
			local text = table.concat(rows, "\n")
			if gcPara and gcPara.SetDesc then
				gcPara:SetDesc(text:sub(1, 1800))
			end
			if toClipboard(text) then
				notify("Spy", "scanned " .. tostring(#rows) .. " (copied)")
			else
				notify("Spy", "scanned " .. tostring(#rows))
			end
		end,
	})
	t:Button({
		Title = "Decompile selected closure names",
		Desc = "uses decompile() if this executor has it",
		Callback = function()
			if typeof(decompile) ~= "function" then
				notify("Spy", "no decompile on this executor")
				return
			end
			notify("Spy", "use GC scan + dump; decompile is per-function via replay")
		end,
	})
end

pcall(function()
	Window:Tag({
		Title = "spy",
		Color = Color3.fromHex("#7C5CFF"),
		Border = true,
	})
end)

ensureFolders()
internal = true
local ncOk = installNamecall()
local idxOk = installIndex()
if not ncOk and typeof(STATE.namecallHook) == "function" then
	STATE.namecallHook("FireServer", function(self, method, ...)
		enqueue({
			kind = "namecall",
			self = self,
			method = method,
			args = packArgs(...),
			fromHub = shouldCaptureCaller(),
			stack = callerStack(),
		})
	end)
	STATE.namecallHook("InvokeServer", function(self, method, ...)
		enqueue({
			kind = "namecall",
			self = self,
			method = method,
			args = packArgs(...),
			fromHub = shouldCaptureCaller(),
			stack = callerStack(),
		})
	end)
	STATE.namecallHook("HttpGet", function(self, method, ...)
		enqueue({
			kind = "namecall",
			self = self,
			method = method,
			args = packArgs(...),
			fromHub = shouldCaptureCaller(),
			stack = callerStack(),
		})
	end)
	ncOk = true
end
installExecHooks()
scanInbound()
snapshotGenv()
internal = false

notify(
	"Spy",
	string.format(
		"namecall=%s index=%s  run the other hub now",
		ncOk and "on" or "FAIL",
		idxOk and "on" or "FAIL"
	)
)

STATE.connect(RunService.Heartbeat, function()
	if not STATE.alive() then
		return
	end
	if #incoming > 0 then
		local batch = incoming
		incoming = {}
		internal = true
		for i = 1, #batch do
			pcall(consume, batch[i])
		end
		internal = false
	end
	pcall(pollGenv)
	if CFG.AutoRefresh then
		local now = os.clock()
		if now - lastUiAt > 0.45 then
			lastUiAt = now
			pcall(refreshUi)
		end
	end
end)

STATE.onCleanup(function()
	internal = true
	if oldNamecall and typeof(hookmetamethod) == "function" then
		pcall(hookmetamethod, game, "__namecall", oldNamecall)
	end
	if oldIndex and typeof(hookmetamethod) == "function" then
		pcall(hookmetamethod, game, "__index", oldIndex)
	end
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	local hf = hookfunction or hookfunc
	for name, orig in pairs(oldGlobals) do
		if name == "syn.request" and type(syn) == "table" then
			syn.request = orig
		elseif typeof(hf) == "function" and typeof(genv[name]) == "function" then
			pcall(hf, genv[name], orig)
		else
			genv[name] = orig
		end
	end
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
	internal = false
end)

if typeof(getgenv) == "function" then
	getgenv().ScriptSpy = {
		logs = logs,
		hubs = hubSources,
		cfg = CFG,
		dump = dumpAll,
		refresh = refreshUi,
	}
end

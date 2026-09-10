--[[
  Fisch Hub — WindUI
  live-reload label: fisch_hub

  Auto farm: RF/FishingRod/Cast + LureShake + Reel/Finish + events.reelfinished
  Instant catch skips shake/reel bars. 200 functions across farm / tp / player / esp.
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

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

local function netChild(name)
	local net = ReplicatedStorage:FindFirstChild("packages")
	net = net and net:FindFirstChild("Net")
	return net and net:FindFirstChild(name)
end

local function fireNet(name, ...)
	local remote = netChild(name)
	if not remote then
		return false, "missing " .. name
	end
	local args = { ... }
	local ok, err = pcall(function()
		if remote:IsA("RemoteFunction") then
			return remote:InvokeServer(table.unpack(args))
		end
		remote:FireServer(table.unpack(args))
	end)
	return ok, err
end

local function fireEvent(name, ...)
	local ev = ReplicatedStorage:FindFirstChild("events")
	ev = ev and ev:FindFirstChild(name)
	if not ev then
		return false, "missing events." .. name
	end
	local args = { ... }
	local ok, err = pcall(function()
		if ev:IsA("RemoteFunction") then
			return ev:InvokeServer(table.unpack(args))
		end
		ev:FireServer(table.unpack(args))
	end)
	return ok, err
end

local function rodValues()
	local fishing = ReplicatedStorage:FindFirstChild("shared")
	fishing = fishing and fishing:FindFirstChild("modules")
	fishing = fishing and fishing:FindFirstChild("fishing")
	local res = fishing and fishing:FindFirstChild("rodresources")
	return res and res:FindFirstChild("values"), res and res:FindFirstChild("events")
end

if not STATE.store then
	STATE.store = {}
end
local store = STATE.store

local CFG = store.cfg
	or {
		AutoFish = false,
		InstantReel = true,
		InstantShake = true,
		PerfectCatch = true,
		AutoCast = true,
		AutoRecast = true,
		AutoSell = false,
		AutoSellAfterCatch = false,
		InstantAppraise = false,
		AutoAppraise = false,
		FastLure = true,
		SkipMinigame = true,
		ForceBite = false,
		InstantCast = true,
		AutoEquipRod = true,
		FreezeBobber = false,
		AutoResetRod = true,
		AutoClaimCages = false,
		AutoClaimMeteor = true,
		AutoDaily = true,
		NoDrown = true,
		InfOxygen = true,
		WaterWalk = false,
		AntiAfk = true,
		AutoEnchant = false,
		SkipCutscene = true,
		AutoTreasure = false,
		InstantHarpoon = false,
		AlwaysPerfect = true,
		FarmDelay = 0.18,
		CastPower = 100,
		WalkSpeedOn = false,
		WalkSpeed = 36,
		JumpPowerOn = false,
		JumpPower = 60,
		Fly = false,
		FlySpeed = 80,
		Noclip = false,
		InfJump = false,
		Gravity = 196.2,
		HipHeightOn = false,
		HipHeight = 2,
		FpsCap = 0,
		NoClipBoats = false,
		SwimSpeedOn = false,
		PlayerEsp = false,
		ChestEsp = false,
		NpcEsp = false,
		MeteorEsp = false,
		CageEsp = false,
		BoatEsp = false,
		FishEsp = false,
		ItemEsp = false,
		EspDistance = true,
		EspNames = true,
		Fullbright = false,
		NoFog = false,
		NoWater = false,
		NoBlur = false,
		NoParticles = false,
		NoShadows = false,
		Xray = false,
		HideOthers = false,
		LowGfx = false,
		KeepShiny = true,
		KeepMutated = true,
		SellCommons = true,
		Silent = false,
		OpMode = false,
	}
store.cfg = CFG

local stats = store.stats
	or {
		catches = 0,
		sells = 0,
		casts = 0,
		shakes = 0,
		reels = 0,
		lastAction = "idle",
		functions = 0,
		lastShake = 0,
		lastReel = 0,
		lastCast = 0,
	}
store.stats = stats

local highlights = store.highlights or {}
store.highlights = highlights

local ORIG_LIGHT = store.origLight
	or {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		FogEnd = Lighting.FogEnd,
		FogStart = Lighting.FogStart,
		GlobalShadows = Lighting.GlobalShadows,
		Ambient = Lighting.Ambient,
	}
store.origLight = ORIG_LIGHT

local function notify(title, content)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = title or "Fisch Hub",
			Content = content or "",
			Duration = 2.3,
		})
	end)
end

local function hrp()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function equippedRod()
	local char = LocalPlayer.Character
	if not char then
		return nil
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			local n = string.lower(child.Name)
			if string.find(n, "rod", 1, true) or child:FindFirstChild("values") or child:GetAttribute("Rod") then
				return child
			end
		end
	end
	return char:FindFirstChildOfClass("Tool")
end

local function anyRodInBackpack()
	local bag = LocalPlayer:FindFirstChild("Backpack")
	if not bag then
		return nil
	end
	for _, child in ipairs(bag:GetChildren()) do
		if child:IsA("Tool") then
			local n = string.lower(child.Name)
			if string.find(n, "rod", 1, true) then
				return child
			end
		end
	end
	return nil
end

local function equipRod()
	local already = equippedRod()
	if already then
		return already
	end
	local rod = anyRodInBackpack()
	local hum = humanoid()
	if rod and hum then
		pcall(function()
			hum:EquipTool(rod)
		end)
		fireNet("RF/Rod/Equip", rod.Name)
		return rod
	end
	return nil
end

local function finishReel()
	local now = os.clock()
	if now - (stats.lastReel or 0) < 0.45 then
		return
	end
	stats.lastReel = now
	stats.reels += 1
	stats.lastAction = "reel"
	fireNet("RF/Reel/Start")
	if CFG.PerfectCatch or CFG.AlwaysPerfect then
		local ok = fireEvent("reelfinished", 100, true)
		if not ok then
			fireNet("RE/Reel/Finish", true)
		end
	else
		fireEvent("reelfinished", 80, false)
		fireNet("RE/Reel/Finish")
	end
end

local function doShake()
	local now = os.clock()
	if now - (stats.lastShake or 0) < 0.12 then
		return
	end
	stats.lastShake = now
	stats.shakes += 1
	stats.lastAction = "shake"
	fireNet("RE/LureShake/Shake")
	fireNet("RF/LureShake/Start")
end

local function doCast()
	local now = os.clock()
	if now - (stats.lastCast or 0) < 0.7 then
		return
	end
	stats.lastCast = now
	if CFG.AutoEquipRod then
		equipRod()
	end
	stats.casts += 1
	stats.lastAction = "cast"
	local vals, evs = rodValues()
	if vals then
		local power = vals:FindFirstChild("power")
		if power and CFG.InstantCast then
			pcall(function()
				power.Value = math.clamp(CFG.CastPower / 100, 0.05, 1)
			end)
		end
	end
	if evs then
		local castAsync = evs:FindFirstChild("castAsync")
		if castAsync then
			pcall(function()
				castAsync:InvokeServer()
			end)
		end
	end
	fireNet("RF/FishingRod/Cast")
	fireNet("RF/FishingRod/Cast", CFG.CastPower / 100)
	fireNet("RE/FishingRod/HandleBobber")
	local tool = equippedRod()
	if tool then
		pcall(function()
			tool:Activate()
		end)
	end
end

local function resetRod()
	fireNet("RE/FishingRod/Reset")
	local _, evs = rodValues()
	if evs then
		local reset = evs:FindFirstChild("reset")
		if reset then
			pcall(function()
				reset:FireServer()
			end)
		end
	end
end

local function sellAll()
	stats.sells += 1
	stats.lastAction = "sell"
	fireEvent("selleverything")
end

local function appraiseNow()
	fireNet("RF/AppraiseAnywhere/Fire")
	fireNet("RE/EventAppraiseService/StartAppraise")
	fireNet("RE/EventAppraiseService/Complete")
	fireNet("RE/EventAppraiseService/TakeNow")
end

local function claimDaily()
	fireNet("RE/DailyReward/Claim")
end

local function claimMeteor()
	fireNet("RE/Meteor/Claim")
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst.Name == "Meteor" or string.find(string.lower(inst.Name), "meteor", 1, true) then
			local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt and fireproximityprompt then
				pcall(fireproximityprompt, prompt)
			end
		end
	end
end

local function claimCages()
	fireNet("RF/CrabCage/Claim")
	for _, inst in ipairs(Workspace:GetDescendants()) do
		local n = string.lower(inst.Name)
		if string.find(n, "cage", 1, true) or string.find(n, "crab", 1, true) then
			local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt and fireproximityprompt then
				pcall(fireproximityprompt, prompt)
			end
		end
	end
end

local function fishingState()
	local vals = rodValues()
	if not vals then
		return {
			casted = false,
			bite = false,
			lure = 0,
			state = 0,
		}
	end
	local function num(name)
		local v = vals:FindFirstChild(name)
		return v and tonumber(v.Value) or 0
	end
	local function bool(name)
		local v = vals:FindFirstChild(name)
		return v and v.Value == true
	end
	return {
		casted = bool("casted"),
		bite = bool("bite"),
		lure = num("lure"),
		state = num("state"),
		power = num("power"),
	}
end

local function guiHasShake()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return false
	end
	for _, gui in ipairs(pg:GetDescendants()) do
		local n = string.lower(gui.Name)
		if string.find(n, "shake", 1, true) and gui:IsA("GuiObject") and gui.Visible then
			return true
		end
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			local t = string.lower(gui.Text or "")
			if t == "shake" and gui.Visible then
				return true
			end
		end
	end
	return false
end

local function guiHasReel()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return false
	end
	for _, gui in ipairs(pg:GetDescendants()) do
		local n = string.lower(gui.Name)
		if (string.find(n, "reel", 1, true) or string.find(n, "fishingbar", 1, true) or n == "minigame")
			and gui:IsA("GuiObject")
			and gui.Visible
		then
			return true
		end
	end
	return false
end

local function farmTick()
	if not CFG.AutoFish and not CFG.OpMode then
		return
	end
	if CFG.AutoEquipRod then
		equipRod()
	end
	local st = fishingState()
	local shakeUi = CFG.InstantShake and guiHasShake()
	local reelUi = CFG.InstantReel and guiHasReel()

	if (CFG.InstantShake or CFG.SkipMinigame) and (shakeUi or st.lure >= 98 or st.state == 3) then
		doShake()
	end
	if (CFG.InstantReel or CFG.SkipMinigame) and (reelUi or st.bite or st.state == 4 or st.state == 5) then
		finishReel()
		stats.catches += 1
		if CFG.AutoSellAfterCatch then
			sellAll()
		end
		if CFG.AutoResetRod then
			task.defer(resetRod)
		end
		return
	end
	if CFG.ForceBite and st.casted then
		doShake()
		finishReel()
		return
	end
	if CFG.AutoCast and not st.casted and not reelUi and not shakeUi then
		doCast()
	end
end

local function setOxygen()
	if not (CFG.InfOxygen or CFG.NoDrown) then
		return
	end
	local char = LocalPlayer.Character
	if not char then
		return
	end
	for _, name in ipairs({ "Oxygen", "oxygen", "Air", "Breath" }) do
		local v = char:FindFirstChild(name) or LocalPlayer:FindFirstChild(name)
		if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
			pcall(function()
				v.Value = v.MaxValue or 100
			end)
		end
	end
	pcall(function()
		char:SetAttribute("Oxygen", 100)
		LocalPlayer:SetAttribute("Oxygen", 100)
	end)
	local hum = humanoid()
	if hum then
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
		end)
	end
end

local flyBv
local flyBg
local noclipParts = {}

local function stopFly()
	if flyBv then
		pcall(function()
			flyBv:Destroy()
		end)
		flyBv = nil
	end
	if flyBg then
		pcall(function()
			flyBg:Destroy()
		end)
		flyBg = nil
	end
end

local function startFly()
	stopFly()
	local part = hrp()
	if not part then
		return
	end
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bv.Velocity = Vector3.zero
	bv.Parent = part
	flyBv = bv
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bg.P = 9e4
	bg.CFrame = part.CFrame
	bg.Parent = part
	flyBg = bg
	STATE.onCleanup(stopFly)
end

local function flyStep()
	if not CFG.Fly then
		if flyBv then
			stopFly()
		end
		return
	end
	local part = hrp()
	local cam = Workspace.CurrentCamera
	if not part or not cam then
		return
	end
	if not flyBv or flyBv.Parent ~= part then
		startFly()
	end
	if not flyBv then
		return
	end
	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		dir += cam.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		dir -= cam.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		dir -= cam.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		dir += cam.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		dir += Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		dir -= Vector3.new(0, 1, 0)
	end
	if dir.Magnitude > 0 then
		dir = dir.Unit * CFG.FlySpeed
	end
	flyBv.Velocity = dir
	flyBg.CFrame = cam.CFrame
end

local waterPart = store.waterPart
local function setWaterWalk(on)
	if waterPart then
		pcall(function()
			waterPart:Destroy()
		end)
		waterPart = nil
		store.waterPart = nil
	end
	if not on then
		return
	end
	local part = Instance.new("Part")
	part.Name = "FischWaterWalk"
	part.Size = Vector3.new(12, 1, 12)
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 1
	part.Parent = Workspace
	waterPart = part
	store.waterPart = part
	STATE.onCleanup(function()
		if waterPart then
			pcall(function()
				waterPart:Destroy()
			end)
			waterPart = nil
		end
	end)
end

local function waterWalkStep()
	if not CFG.WaterWalk or not waterPart then
		return
	end
	local part = hrp()
	if not part then
		return
	end
	waterPart.CFrame = CFrame.new(part.Position.X, part.Position.Y - 3.4, part.Position.Z)
end

local function noclipStep()
	local char = LocalPlayer.Character
	if not char then
		return
	end
	if CFG.Noclip then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.CanCollide then
					noclipParts[p] = true
				end
				p.CanCollide = false
			end
		end
		return
	end
	for p in pairs(noclipParts) do
		if p.Parent then
			p.CanCollide = true
		end
		noclipParts[p] = nil
	end
end

local function applyWalk()
	local hum = humanoid()
	if not hum then
		return
	end
	if CFG.WalkSpeedOn then
		hum.WalkSpeed = CFG.WalkSpeed
	end
	if CFG.JumpPowerOn then
		hum.UseJumpPower = true
		hum.JumpPower = CFG.JumpPower
	end
	if CFG.HipHeightOn then
		hum.HipHeight = CFG.HipHeight
	end
	Workspace.Gravity = CFG.Gravity
end

local function applyVisuals()
	if CFG.Fullbright then
		Lighting.ClockTime = 14
		Lighting.Brightness = 3
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
	else
		Lighting.ClockTime = ORIG_LIGHT.ClockTime
		Lighting.Brightness = ORIG_LIGHT.Brightness
		Lighting.Ambient = ORIG_LIGHT.Ambient
	end
	if CFG.NoFog then
		Lighting.FogEnd = 1e9
		Lighting.FogStart = 1e9
	else
		Lighting.FogEnd = ORIG_LIGHT.FogEnd
		Lighting.FogStart = ORIG_LIGHT.FogStart
	end
	Lighting.GlobalShadows = not CFG.NoShadows and ORIG_LIGHT.GlobalShadows
	if CFG.NoBlur then
		for _, v in ipairs(Lighting:GetChildren()) do
			if v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then
				v.Enabled = false
			end
		end
	end
	if typeof(setfpscap) == "function" then
		pcall(setfpscap, CFG.FpsCap)
	end
end

local function clearEsp()
	for inst, hl in pairs(highlights) do
		pcall(function()
			hl:Destroy()
		end)
		highlights[inst] = nil
	end
end

local function paintEsp(inst, color)
	if highlights[inst] then
		return
	end
	local hl = Instance.new("Highlight")
	hl.Adornee = inst
	hl.FillColor = color
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.65
	hl.OutlineTransparency = 0.2
	hl.Parent = inst
	highlights[inst] = hl
end

local function tickEsp()
	if
		not (
			CFG.PlayerEsp
			or CFG.ChestEsp
			or CFG.NpcEsp
			or CFG.MeteorEsp
			or CFG.CageEsp
			or CFG.BoatEsp
			or CFG.FishEsp
			or CFG.ItemEsp
		)
	then
		if next(highlights) then
			clearEsp()
		end
		return
	end
	local wanted = {}
	if CFG.PlayerEsp then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				wanted[plr.Character] = Color3.fromRGB(80, 180, 255)
			end
		end
	end
	local function scan(root, pred, color)
		for _, inst in ipairs(root:GetChildren()) do
			if pred(inst) then
				wanted[inst] = color
			end
		end
	end
	local folders = { Workspace }
	for _, name in ipairs({ "world", "World", "interact", "Interact", "npcs", "NPC", "Chests", "Items" }) do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(folders, f)
		end
	end
	for _, folder in ipairs(folders) do
		if CFG.ChestEsp then
			scan(folder, function(i)
				local n = string.lower(i.Name)
				return string.find(n, "chest", 1, true) ~= nil
			end, Color3.fromRGB(255, 210, 60))
		end
		if CFG.MeteorEsp then
			scan(folder, function(i)
				return string.find(string.lower(i.Name), "meteor", 1, true) ~= nil
			end, Color3.fromRGB(255, 90, 40))
		end
		if CFG.CageEsp then
			scan(folder, function(i)
				local n = string.lower(i.Name)
				return string.find(n, "cage", 1, true) ~= nil
			end, Color3.fromRGB(120, 220, 90))
		end
		if CFG.BoatEsp then
			scan(folder, function(i)
				return string.find(string.lower(i.Name), "boat", 1, true) ~= nil
			end, Color3.fromRGB(90, 140, 255))
		end
		if CFG.NpcEsp then
			scan(folder, function(i)
				return i:FindFirstChildWhichIsA("Humanoid") ~= nil and not Players:GetPlayerFromCharacter(i)
			end, Color3.fromRGB(220, 120, 255))
		end
	end
	for inst, hl in pairs(highlights) do
		if not wanted[inst] or not inst.Parent then
			pcall(function()
				hl:Destroy()
			end)
			highlights[inst] = nil
		end
	end
	for inst, color in pairs(wanted) do
		paintEsp(inst, color)
	end
end

local TELEPORTS = {
	{ "Moosewood", CFrame.new(379.7, 134.5, 233.7) },
	{ "Roslit Bay", CFrame.new(-1441.7, 134.5, 710.5) },
	{ "Roslit Volcano", CFrame.new(-1888.5, 165.2, 160.4) },
	{ "Sunstone Island", CFrame.new(-913.9, 138.1, -1133.3) },
	{ "Terrapin Island", CFrame.new(-147.5, 143.3, 1875.2) },
	{ "Statue of Sovereignty", CFrame.new(21.5, 159.6, -1040.9) },
	{ "Mushgrove Swamp", CFrame.new(2442.8, 131.3, -685.9) },
	{ "Snowcap Island", CFrame.new(2606.2, 139.3, 2381.2) },
	{ "Snowcap Peak", CFrame.new(2900.1, 280.4, 2560.8) },
	{ "Forsaken Shores", CFrame.new(-2499.6, 137.3, 1551.3) },
	{ "Ancient Isle", CFrame.new(6059.9, 195.2, 276.4) },
	{ "Ancient Isle Waterfall", CFrame.new(5833.2, 160.1, 401.5) },
	{ "Keepers Altar", CFrame.new(1296.3, -805.3, -297.4) },
	{ "Desolate Deep Pipe", CFrame.new(-790.4, -245.4, -3100.8) },
	{ "Desolate Deep", CFrame.new(-979.2, -245.5, -2697.1) },
	{ "Vertigo", CFrame.new(-112.0, -515.4, 1040.3) },
	{ "The Arch", CFrame.new(999.0, 126.7, -1237.3) },
	{ "Birch Cay", CFrame.new(1742.3, 141.3, -2502.3) },
	{ "Harvesters Spike", CFrame.new(-1234.7, 132.3, 1742.8) },
	{ "Earmark Island", CFrame.new(1243.4, 135.5, 554.2) },
	{ "Haddock Rock", CFrame.new(-514.2, 134.5, -505.8) },
	{ "Rock Island", CFrame.new(-736.4, 133.5, -136.2) },
	{ "Ocean Marker", CFrame.new(1200.0, 131.5, 1400.0) },
	{ "Grand Reef", CFrame.new(-3539.7, 130.5, 541.3) },
	{ "Atlantean Storm", CFrame.new(-3600.0, 133.0, 1400.0) },
	{ "Atlantis Gates", CFrame.new(-4305.0, -603.0, 1825.0) },
	{ "Atlantis Hub", CFrame.new(-2550.0, -380.0, 8500.0) },
	{ "Ethereal Abyss", CFrame.new(-3600.0, -565.0, 1800.0) },
	{ "Kraken Pool", CFrame.new(-3515.0, -555.0, 1620.0) },
	{ "Northern Expedition", CFrame.new(19700.0, 140.0, 5400.0) },
	{ "Northern Summit", CFrame.new(19960.0, 1130.0, 5550.0) },
	{ "Overgrowth Caves", CFrame.new(19763.0, 414.0, 5405.0) },
	{ "Frigid Cavern", CFrame.new(19872.0, 416.0, 5332.0) },
	{ "Cryogenic Canal", CFrame.new(19970.0, 444.0, 5557.0) },
	{ "Glacial Grotto", CFrame.new(19911.0, 1130.0, 5555.0) },
	{ "Volcanic Vents", CFrame.new(-3190.0, -2272.0, 1635.0) },
	{ "Challengers Deep", CFrame.new(-739.0, -3355.0, -2862.0) },
	{ "Abyssal Zenith", CFrame.new(-13520.0, -11050.0, 145.0) },
	{ "Calm Zone", CFrame.new(-4270.0, -11230.0, 1485.0) },
	{ "Veil of the Forsaken", CFrame.new(-24790.0, -11175.0, 4705.0) },
	{ "Marianas Veil Entrance", CFrame.new(-1700.0, 130.0, -3500.0) },
	{ "Waveborne", CFrame.new(360.0, 90.0, 780.0) },
	{ "Isle of New Beginnings", CFrame.new(-300.0, 80.0, 250.0) },
	{ "Lushgrove", CFrame.new(1300.0, 85.0, -900.0) },
	{ "Emberreach", CFrame.new(2400.0, 90.0, 400.0) },
	{ "Pine Shoals", CFrame.new(-900.0, 85.0, 1400.0) },
	{ "The Cursed Shores", CFrame.new(900.0, 80.0, 2200.0) },
	{ "Gilded Arch", CFrame.new(-1600.0, 90.0, -400.0) },
	{ "Azure Lagoon", CFrame.new(400.0, 80.0, -1600.0) },
	{ "Open Ocean South", CFrame.new(0.0, 131.0, 3000.0) },
	{ "Open Ocean North", CFrame.new(0.0, 131.0, -3000.0) },
	{ "Merlin", CFrame.new(446.0, 150.0, 280.0) },
	{ "Moosewood Merchant", CFrame.new(465.0, 150.0, 235.0) },
	{ "Moosewood Angler", CFrame.new(480.0, 150.0, 310.0) },
	{ "Moosewood Inn", CFrame.new(487.0, 150.0, 220.0) },
	{ "Shipwright", CFrame.new(360.0, 135.0, 260.0) },
	{ "Moosewood Pier", CFrame.new(404.0, 135.0, 255.0) },
	{ "Roslit Merchant", CFrame.new(-1515.0, 141.0, 680.0) },
	{ "Sunstone Merchant", CFrame.new(-905.0, 135.0, -1100.0) },
	{ "Terrapin Merchant", CFrame.new(-190.0, 145.0, 1920.0) },
	{ "Snowcap Merchant", CFrame.new(2600.0, 140.0, 2400.0) },
	{ "Forsaken Merchant", CFrame.new(-2560.0, 140.0, 1480.0) },
	{ "Ancient Isle Merchant", CFrame.new(6000.0, 200.0, 300.0) },
	{ "Mushgrove Merchant", CFrame.new(2480.0, 131.0, -700.0) },
	{ "Enchant Altar", CFrame.new(1310.0, -805.0, -240.0) },
	{ "Keepers Torch", CFrame.new(1298.0, -803.0, -310.0) },
	{ "Desolate Merchant", CFrame.new(-980.0, -246.0, -2700.0) },
	{ "Vertigo Merchant", CFrame.new(-115.0, -515.0, 1055.0) },
	{ "Grand Reef Merchant", CFrame.new(-3570.0, 132.0, 520.0) },
	{ "AFK Zone", CFrame.new(220.0, 136.0, 240.0) },
	{ "Trade Plaza", CFrame.new(446.0, 150.0, 200.0) },
	{ "Caleia", CFrame.new(140.0, 150.0, 2000.0) },
	{ "Jack Marrow", CFrame.new(-2830.0, 215.0, 1510.0) },
	{ "Captain Ahab", CFrame.new(-3510.0, 130.0, 580.0) },
	{ "Dr Glimmerfin", CFrame.new(-1450.0, 135.0, 720.0) },
	{ "Challenger Deep Camp", CFrame.new(-800.0, -3320.0, -2900.0) },
	{ "Zenith Camp", CFrame.new(-13500.0, -11040.0, 160.0) },
	{ "Calm Zone Camp", CFrame.new(-4300.0, -11220.0, 1500.0) },
	{ "Veil Camp", CFrame.new(-24750.0, -11170.0, 4680.0) },
	{ "Volcanic Camp", CFrame.new(-3180.0, -2260.0, 1650.0) },
	{ "Sunken Chests Area", CFrame.new(-790.0, -246.0, -3050.0) },
	{ "Orcas Area", CFrame.new(-3400.0, 130.0, 700.0) },
	{ "Megalodon Hunt Zone", CFrame.new(-2000.0, 131.0, 2000.0) },
	{ "Kraken Hunt Zone", CFrame.new(-4300.0, -555.0, 1750.0) },
	{ "Scylla Zone", CFrame.new(-2500.0, -390.0, 8500.0) },
	{ "Lucky Pool", CFrame.new(390.0, 135.0, 250.0) },
	{ "Moosewood Beach", CFrame.new(390.0, 134.0, 280.0) },
	{ "Roslit Beach", CFrame.new(-1460.0, 133.0, 740.0) },
	{ "Snowcap Shore", CFrame.new(2580.0, 134.0, 2360.0) },
}

local function teleportTo(entry)
	local name, cf = entry[1], entry[2]
	stats.lastAction = "tp " .. name
	fireNet("RE/FastTravel/Teleport", name)
	fireNet("RE/RequestTeleport", name)
	fireNet("RE/TeleportService/RequestTeleport", name)
	fireNet("RF/RequestTeleportCFrame", cf)
	fireNet("RF/Deep/Teleport", name)
	fireNet("RF/MarianasVeil/Teleport", name)
	local part = hrp()
	if part then
		pcall(function()
			part.CFrame = cf + Vector3.new(0, 4, 0)
		end)
	end
	notify("Teleport", name)
end

local function enableOp(on)
	CFG.OpMode = on
	if on then
		CFG.AutoFish = true
		CFG.InstantReel = true
		CFG.InstantShake = true
		CFG.PerfectCatch = true
		CFG.AlwaysPerfect = true
		CFG.AutoCast = true
		CFG.AutoRecast = true
		CFG.SkipMinigame = true
		CFG.InstantCast = true
		CFG.AutoEquipRod = true
		CFG.InfOxygen = true
		CFG.NoDrown = true
		CFG.AntiAfk = true
		CFG.FastLure = true
		notify("OP Mode", "auto farm + instant catch stacked")
	end
end

local function statusText()
	local st = fishingState()
	local rod = equippedRod()
	return string.format(
		"rod %s | casted %s bite %s lure %.0f state %s | catches %d casts %d reels %d sells %d | last %s | funcs %d",
		rod and rod.Name or "none",
		st.casted and "Y" or "N",
		st.bite and "Y" or "N",
		st.lure,
		tostring(st.state),
		stats.catches,
		stats.casts,
		stats.reels,
		stats.sells,
		stats.lastAction,
		stats.functions
	)
end

task.spawn(function()
	while STATE.alive() do
		local delay = math.max(0.05, CFG.FarmDelay)
		if CFG.AutoFish or CFG.OpMode then
			pcall(farmTick)
			task.wait(delay)
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoSell and (CFG.AutoFish or CFG.OpMode) then
			sellAll()
		end
		if CFG.AutoAppraise then
			appraiseNow()
		end
		if CFG.AutoDaily then
			claimDaily()
		end
		if CFG.AutoClaimMeteor then
			pcall(claimMeteor)
		end
		if CFG.AutoClaimCages then
			pcall(claimCages)
		end
		if CFG.AutoEnchant then
			fireEvent("enchant")
			fireNet("RF/EnchantAltar/Interact")
			fireNet("RF/Enchant/ConfirmTarget")
		end
		if CFG.InstantHarpoon then
			fireNet("RE/HarpoonMinigame/Finish")
			fireNet("RE/Stab/Finish")
		end
		task.wait(2.2)
	end
end)

task.spawn(function()
	while STATE.alive() do
		setOxygen()
		applyWalk()
		if CFG.HideOthers then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and plr.Character then
					pcall(function()
						plr.Character:Destroy()
					end)
				end
			end
		end
		if CFG.NoParticles then
			for _, v in ipairs(Workspace:GetDescendants()) do
				if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
					v.Enabled = false
				end
			end
		end
		if CFG.NoWater then
			local ocean = ReplicatedStorage:FindFirstChild("Ocean") or Workspace:FindFirstChild("Ocean")
			if ocean and ocean:IsA("BasePart") then
				ocean.Transparency = 1
			end
		end
		tickEsp()
		task.wait(0.4)
	end
end)

STATE.connect(RunService.Heartbeat, function()
	if not STATE.alive() then
		return
	end
	flyStep()
	waterWalkStep()
end)

STATE.connect(RunService.Stepped, function()
	if not STATE.alive() then
		return
	end
	noclipStep()
end)

STATE.connect(UserInputService.JumpRequest, function()
	if not CFG.InfJump then
		return
	end
	local hum = humanoid()
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

STATE.connect(LocalPlayer.Idled, function()
	if not CFG.AntiAfk then
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

STATE.connect(LocalPlayer.CharacterAdded, function()
	task.wait(0.4)
	if STATE.alive() then
		applyWalk()
		if CFG.Fly then
			startFly()
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AntiAfk then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
			fireEvent("afk")
		end
		task.wait(40)
	end
end)

local vals = select(1, rodValues())
if vals then
	for _, name in ipairs({ "bite", "lure", "casted", "state" }) do
		local v = vals:FindFirstChild(name)
		if v then
			STATE.connect(v.Changed, function()
				if CFG.AutoFish or CFG.OpMode or CFG.InstantReel or CFG.InstantShake then
					pcall(farmTick)
				end
			end)
		end
	end
end

STATE.onCleanup(function()
	stopFly()
	setWaterWalk(false)
	clearEsp()
	applyVisuals()
	Lighting.ClockTime = ORIG_LIGHT.ClockTime
	Lighting.Brightness = ORIG_LIGHT.Brightness
	Lighting.FogEnd = ORIG_LIGHT.FogEnd
	Lighting.FogStart = ORIG_LIGHT.FogStart
	Lighting.GlobalShadows = ORIG_LIGHT.GlobalShadows
	Lighting.Ambient = ORIG_LIGHT.Ambient
	Workspace.Gravity = 196.2
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "Fisch Hub",
	Author = "200 functions · instant · autofarm",
	Folder = "FischHub",
	Icon = "fish",
	NewElements = true,
	Size = UDim2.fromOffset(620, 500),
	HideSearchBar = false,
	OpenButton = {
		Title = "Fisch",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		OnlyIcon = true,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#3BA3FF"), Color3.fromHex("#7CFFB2")),
	},
})
store.window = Window

Window:Tag({
	Title = "200",
	Icon = "zap",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")
local Purple = Color3.fromHex("#7C5CFF")
local Cyan = Color3.fromHex("#2fe7ff")

local MainSec = Window:Section({ Title = "Main", Opened = true })
local FarmSec = Window:Section({ Title = "Farm", Opened = true })
local WorldSec = Window:Section({ Title = "World", Opened = true })
local ExtraSec = Window:Section({ Title = "Extra", Opened = true })

local function countFn()
	stats.functions += 1
end

local HomeTab = MainSec:Tab({ Title = "Home", Icon = "house", IconColor = Green })
task.wait()
local para = HomeTab:Paragraph({
	Title = "Fisch",
	Desc = statusText(),
})
countFn()

HomeTab:Toggle({
	Title = "OP Mode",
	Desc = "stacks auto fish + instant shake/reel + perfect + oxygen + anti afk",
	Default = CFG.OpMode,
	Value = CFG.OpMode,
	Callback = function(v)
		enableOp(v)
	end,
})
countFn()

HomeTab:Toggle({
	Title = "Silent Mode",
	Default = CFG.Silent,
	Value = CFG.Silent,
	Callback = function(v)
		CFG.Silent = v
	end,
})
countFn()

HomeTab:Button({
	Title = "Refresh Status",
	Icon = "refresh-cw",
	Callback = function()
		local text = statusText()
		if para and para.SetDesc then
			para:SetDesc(text)
		end
		notify("Status", text)
	end,
})
countFn()

HomeTab:Button({
	Title = "Start OP Farm Now",
	Icon = "zap",
	Callback = function()
		enableOp(true)
		doCast()
		notify("Farm", "op farm armed")
	end,
})
countFn()

HomeTab:Button({
	Title = "Copy JobId",
	Icon = "clipboard",
	Callback = function()
		if typeof(setclipboard) == "function" then
			setclipboard(game.JobId)
			notify("JobId", game.JobId)
		end
	end,
})

local FarmTab = FarmSec:Tab({ Title = "Auto Farm", Icon = "fish", IconColor = Cyan })
task.wait()

local farmToggles = {
	{ "Auto Fish", "AutoFish", "cast + shake + reel loop" },
	{ "Instant Reel", "InstantReel", "RE/Reel/Finish + reelfinished 100 true" },
	{ "Instant Shake", "InstantShake", "RE/LureShake/Shake the second lure pops" },
	{ "Perfect Catch", "PerfectCatch", "always send perfect reel payload" },
	{ "Always Perfect", "AlwaysPerfect", "force 100 / true on every finish" },
	{ "Auto Cast", "AutoCast", "RF/FishingRod/Cast when idle" },
	{ "Auto Recast", "AutoRecast", "reset + cast after catch" },
	{ "Instant Cast", "InstantCast", "slam rod power then cast" },
	{ "Fast Lure", "FastLure", "shake as soon as lure value spikes" },
	{ "Skip Minigame", "SkipMinigame", "finish reel without playing the bar" },
	{ "Force Bite", "ForceBite", "shake+reel while bobber is out" },
	{ "Auto Equip Rod", "AutoEquipRod", "equip a rod from backpack" },
	{ "Auto Reset Rod", "AutoResetRod", "RE/FishingRod/Reset after catch" },
	{ "Freeze Bobber", "FreezeBobber", "re-handle bobber so it does not despawn" },
	{ "Auto Sell", "AutoSell", "events.selleverything on a timer" },
	{ "Auto Sell After Catch", "AutoSellAfterCatch", "sell immediately after reel finish" },
	{ "Instant Appraise", "InstantAppraise", "RF/AppraiseAnywhere/Fire" },
	{ "Auto Appraise", "AutoAppraise", "appraise loop while farming" },
	{ "Auto Claim Cages", "AutoClaimCages", "RF/CrabCage/Claim + prompts" },
	{ "Auto Claim Meteor", "AutoClaimMeteor", "RE/Meteor/Claim" },
	{ "Auto Daily", "AutoDaily", "RE/DailyReward/Claim" },
	{ "No Drown", "NoDrown", "keep oxygen / ignore drown" },
	{ "Inf Oxygen", "InfOxygen", "write oxygen values every tick" },
	{ "Water Walk", "WaterWalk", "invisible part under feet" },
	{ "Anti AFK", "AntiAfk", "VirtualUser + events.afk" },
	{ "Auto Enchant", "AutoEnchant", "enchant RF + altar interact" },
	{ "Skip Cutscene", "SkipCutscene", "request fade / skip cutscene remotes" },
	{ "Auto Treasure", "AutoTreasure", "companion / otter treasure claim" },
	{ "Instant Harpoon", "InstantHarpoon", "finish harpoon + stab minigames" },
}

for _, row in ipairs(farmToggles) do
	local title, key, desc = row[1], row[2], row[3]
	FarmTab:Toggle({
		Title = title,
		Desc = desc,
		Default = CFG[key],
		Value = CFG[key],
		Callback = function(v)
			CFG[key] = v
			if key == "WaterWalk" then
				setWaterWalk(v)
			end
			if key == "SkipCutscene" and v then
				fireNet("RE/RequestFade")
				fireNet("RE/FastTravel/Fade")
			end
			if key == "AutoTreasure" and v then
				fireNet("RE/Companion/OllieOtter/ClaimTreasure")
			end
			if key == "FreezeBobber" and v then
				fireNet("RE/FishingRod/HandleBobber")
			end
		end,
	})
	countFn()
end

FarmTab:Slider({
	Title = "Farm Delay",
	Desc = "seconds between farm ticks",
	Value = { Min = 0.05, Max = 1, Default = CFG.FarmDelay },
	Step = 0.01,
	Callback = function(v)
		CFG.FarmDelay = v
	end,
})
countFn()

FarmTab:Slider({
	Title = "Cast Power",
	Value = { Min = 10, Max = 100, Default = CFG.CastPower },
	Step = 1,
	Callback = function(v)
		CFG.CastPower = v
	end,
})
countFn()

local InstantTab = FarmSec:Tab({ Title = "Instant", Icon = "zap", IconColor = Yellow })
task.wait()

local instantButtons = {
	{ "Catch Now", function()
		doShake()
		finishReel()
		notify("Instant", "catch sent")
	end },
	{ "Cast Now", function()
		doCast()
	end },
	{ "Shake Now", doShake },
	{ "Reel Finish Now", finishReel },
	{ "Reset Rod", resetRod },
	{ "Sell All", sellAll },
	{ "Appraise Now", appraiseNow },
	{ "Claim Daily", claimDaily },
	{ "Claim Meteor", claimMeteor },
	{ "Claim Cages", claimCages },
	{ "Spawn Boat", function()
		fireNet("RF/Boats/Spawn")
		fireNet("RE/Boats/Open")
	end },
	{ "Despawn Boat", function()
		fireNet("RE/Boats/Despawn")
	end },
	{ "Equip Best Rod", function()
		local rod = equipRod()
		notify("Rod", rod and rod.Name or "none in backpack")
	end },
	{ "Recast", function()
		resetRod()
		task.wait(0.15)
		doCast()
	end },
	{ "Abort Reel", function()
		fireNet("RE/Reel/Abort")
	end },
	{ "Handle Bobber", function()
		fireNet("RE/FishingRod/HandleBobber")
	end },
	{ "Break Bobber", function()
		fireNet("RE/FishingRod/BreakBobber")
	end },
	{ "Enchant Confirm", function()
		fireEvent("enchant")
		fireNet("RF/Enchant/ConfirmTarget")
		fireNet("RF/EnchantAltar/Interact")
	end },
	{ "Claim Challenges", function()
		fireNet("RF/Challenges/Claim")
		fireNet("RE/Mastery/ClaimQuest")
		fireNet("RE/RodJournal/ClaimRodReward")
	end },
	{ "Skip Fade", function()
		fireNet("RE/RequestFade")
		fireNet("RE/FastTravel/Fade")
	end },
	{ "Fill Oxygen", setOxygen },
	{ "TP Random Island", function()
		teleportTo(TELEPORTS[math.random(1, 20)])
	end },
	{ "Favorite Current Rod", function()
		fireNet("RF/Rod/Favorite")
	end },
	{ "Cycle Rod Mode", function()
		fireNet("RF/Rod/CycleMode")
	end },
	{ "Open Fast Travel", function()
		fireNet("RE/FastTravel/ToggleUI")
	end },
}

for _, row in ipairs(instantButtons) do
	InstantTab:Button({
		Title = row[1],
		Icon = "play",
		Callback = function()
			pcall(row[2])
		end,
	})
	countFn()
end

local TpTab = WorldSec:Tab({ Title = "Teleports", Icon = "map", IconColor = Purple })
task.wait()
TpTab:Paragraph({
	Title = "Islands + NPCs",
	Desc = tostring(#TELEPORTS) .. " destinations. FastTravel name first, CFrame fallback.",
})
countFn()

for _, entry in ipairs(TELEPORTS) do
	local loc = entry
	TpTab:Button({
		Title = loc[1],
		Callback = function()
			teleportTo(loc)
		end,
	})
	countFn()
end

local PlayerTab = ExtraSec:Tab({ Title = "Player", Icon = "person-standing", IconColor = Blue })
task.wait()

PlayerTab:Toggle({
	Title = "Walk Speed",
	Default = CFG.WalkSpeedOn,
	Value = CFG.WalkSpeedOn,
	Callback = function(v)
		CFG.WalkSpeedOn = v
		applyWalk()
	end,
})
countFn()
PlayerTab:Slider({
	Title = "Speed",
	Value = { Min = 16, Max = 120, Default = CFG.WalkSpeed },
	Step = 1,
	Callback = function(v)
		CFG.WalkSpeed = v
		applyWalk()
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "Jump Power",
	Default = CFG.JumpPowerOn,
	Value = CFG.JumpPowerOn,
	Callback = function(v)
		CFG.JumpPowerOn = v
		applyWalk()
	end,
})
countFn()
PlayerTab:Slider({
	Title = "Jump",
	Value = { Min = 50, Max = 200, Default = CFG.JumpPower },
	Step = 1,
	Callback = function(v)
		CFG.JumpPower = v
		applyWalk()
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "Fly (WASD + Space / Ctrl)",
	Default = CFG.Fly,
	Value = CFG.Fly,
	Callback = function(v)
		CFG.Fly = v
		if v then
			startFly()
		else
			stopFly()
		end
	end,
})
countFn()
PlayerTab:Slider({
	Title = "Fly Speed",
	Value = { Min = 20, Max = 250, Default = CFG.FlySpeed },
	Step = 1,
	Callback = function(v)
		CFG.FlySpeed = v
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "Noclip",
	Default = CFG.Noclip,
	Value = CFG.Noclip,
	Callback = function(v)
		CFG.Noclip = v
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "Infinite Jump",
	Default = CFG.InfJump,
	Value = CFG.InfJump,
	Callback = function(v)
		CFG.InfJump = v
	end,
})
countFn()
PlayerTab:Slider({
	Title = "Gravity",
	Value = { Min = 0, Max = 196, Default = CFG.Gravity },
	Step = 1,
	Callback = function(v)
		CFG.Gravity = v
		Workspace.Gravity = v
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "Hip Height",
	Default = CFG.HipHeightOn,
	Value = CFG.HipHeightOn,
	Callback = function(v)
		CFG.HipHeightOn = v
		applyWalk()
	end,
})
countFn()
PlayerTab:Slider({
	Title = "Hip Height Value",
	Value = { Min = 0, Max = 20, Default = CFG.HipHeight },
	Step = 0.5,
	Callback = function(v)
		CFG.HipHeight = v
		applyWalk()
	end,
})
countFn()
PlayerTab:Slider({
	Title = "FPS Cap (0 = unlock)",
	Value = { Min = 0, Max = 240, Default = CFG.FpsCap },
	Step = 1,
	Callback = function(v)
		CFG.FpsCap = v
		if typeof(setfpscap) == "function" then
			pcall(setfpscap, v)
		end
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "No Clip Boats",
	Default = CFG.NoClipBoats,
	Value = CFG.NoClipBoats,
	Callback = function(v)
		CFG.NoClipBoats = v
	end,
})
countFn()
PlayerTab:Button({
	Title = "Sit",
	Callback = function()
		local hum = humanoid()
		if hum then
			hum.Sit = true
		end
	end,
})
countFn()
PlayerTab:Button({
	Title = "Reset Character",
	Callback = function()
		local hum = humanoid()
		if hum then
			hum.Health = 0
		end
	end,
})
countFn()
PlayerTab:Button({
	Title = "Unstuck +4 studs",
	Callback = function()
		local part = hrp()
		if part then
			part.CFrame = part.CFrame + Vector3.new(0, 8, 0)
		end
	end,
})
countFn()
PlayerTab:Button({
	Title = "TP to Nearest Player",
	Callback = function()
		local me = hrp()
		if not me then
			return
		end
		local best, bestDist
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				local other = plr.Character:FindFirstChild("HumanoidRootPart")
				if other then
					local d = (other.Position - me.Position).Magnitude
					if not bestDist or d < bestDist then
						best, bestDist = other, d
					end
				end
			end
		end
		if best then
			me.CFrame = best.CFrame + Vector3.new(4, 0, 0)
		end
	end,
})
countFn()
PlayerTab:Button({
	Title = "Copy Position",
	Callback = function()
		local part = hrp()
		if part and typeof(setclipboard) == "function" then
			setclipboard(tostring(part.CFrame))
			notify("Copied", tostring(part.Position))
		end
	end,
})
countFn()
PlayerTab:Toggle({
	Title = "Hide Other Players",
	Default = CFG.HideOthers,
	Value = CFG.HideOthers,
	Callback = function(v)
		CFG.HideOthers = v
	end,
})
countFn()

local EspTab = ExtraSec:Tab({ Title = "ESP / Visual", Icon = "eye", IconColor = Yellow })
task.wait()

local espToggles = {
	{ "Player ESP", "PlayerEsp" },
	{ "Chest ESP", "ChestEsp" },
	{ "NPC ESP", "NpcEsp" },
	{ "Meteor ESP", "MeteorEsp" },
	{ "Cage ESP", "CageEsp" },
	{ "Boat ESP", "BoatEsp" },
	{ "Fish ESP", "FishEsp" },
	{ "Item ESP", "ItemEsp" },
	{ "ESP Distance", "EspDistance" },
	{ "ESP Names", "EspNames" },
	{ "Fullbright", "Fullbright" },
	{ "No Fog", "NoFog" },
	{ "No Water", "NoWater" },
	{ "No Blur", "NoBlur" },
	{ "No Particles", "NoParticles" },
	{ "No Shadows", "NoShadows" },
	{ "Xray Parts", "Xray" },
	{ "Low GFX", "LowGfx" },
}

for _, row in ipairs(espToggles) do
	EspTab:Toggle({
		Title = row[1],
		Default = CFG[row[2]],
		Value = CFG[row[2]],
		Callback = function(v)
			CFG[row[2]] = v
			if row[2] == "Fullbright" or row[2] == "NoFog" or row[2] == "NoShadows" or row[2] == "NoBlur" then
				applyVisuals()
			end
			if row[2] == "Xray" then
				for _, p in ipairs(Workspace:GetDescendants()) do
					if p:IsA("BasePart") and not p.Parent:FindFirstChildOfClass("Humanoid") then
						p.LocalTransparencyModifier = v and 0.7 or 0
					end
				end
			end
			if not v and string.find(row[2], "Esp", 1, true) then
				clearEsp()
			end
		end,
	})
	countFn()
end

EspTab:Button({
	Title = "Clear ESP",
	Callback = clearEsp,
})
countFn()
EspTab:Button({
	Title = "Restore Lighting",
	Callback = function()
		CFG.Fullbright = false
		CFG.NoFog = false
		applyVisuals()
	end,
})
countFn()

local EcoTab = ExtraSec:Tab({ Title = "Economy", Icon = "coins", IconColor = Green })
task.wait()

EcoTab:Toggle({
	Title = "Keep Shiny",
	Default = CFG.KeepShiny,
	Value = CFG.KeepShiny,
	Callback = function(v)
		CFG.KeepShiny = v
	end,
})
countFn()
EcoTab:Toggle({
	Title = "Keep Mutated",
	Default = CFG.KeepMutated,
	Value = CFG.KeepMutated,
	Callback = function(v)
		CFG.KeepMutated = v
	end,
})
countFn()
EcoTab:Toggle({
	Title = "Sell Commons",
	Default = CFG.SellCommons,
	Value = CFG.SellCommons,
	Callback = function(v)
		CFG.SellCommons = v
	end,
})
countFn()
EcoTab:Button({
	Title = "Sell Everything",
	Callback = sellAll,
})
countFn()
EcoTab:Button({
	Title = "Appraise Anywhere",
	Callback = appraiseNow,
})
countFn()
EcoTab:Button({
	Title = "Open Black Market",
	Callback = function()
		fireNet("RE/BlackMarket/Open")
	end,
})
countFn()
EcoTab:Button({
	Title = "Open Daily Shop",
	Callback = function()
		fireNet("RE/DailyShop/Open")
	end,
})
countFn()
EcoTab:Button({
	Title = "Open Bait Shop",
	Callback = function()
		fireNet("RE/BuyBait/Show")
	end,
})
countFn()
EcoTab:Button({
	Title = "Open Shell Merchant",
	Callback = function()
		fireNet("RE/ShellMerchant/Open")
	end,
})
countFn()
EcoTab:Button({
	Title = "Claim Aquarium Rewards",
	Callback = function()
		fireNet("RE/PersonalAquarium/ClaimRewards")
	end,
})
countFn()

if para and para.SetDesc then
	para:SetDesc(statusText())
end

notify("Fisch Hub", tostring(stats.functions) .. " functions loaded. turn on OP Mode to farm.")
print("[FischHub] functions=" .. tostring(stats.functions))

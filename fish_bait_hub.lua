--[[
  BE A FISH BAIT Hub - WindUI
  live-reload label: fish_bait_hub
  Place 99702578544768 / Universe 9330616906

  Auto farm: ThrowSystem fake-auto + StartAutoFishing, instant/perfect throw bar,
  FISH! GUI click fallback, aquarium collect/place, train, sell, rebirth, claims.
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

local WINDUI_URLS = {
	"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
	"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
}

local function compileWindUI(src, label)
	assert(type(src) == "string" and #src > 100, "WindUI source empty from " .. tostring(label))
	local fn, err = loadstring(src, "@WindUI")
	assert(fn, "WindUI compile failed (" .. tostring(label) .. "): " .. tostring(err))
	local ok, lib = pcall(fn)
	assert(ok and lib, "WindUI init failed (" .. tostring(label) .. "): " .. tostring(lib))
	return lib
end

local function loadWindUI()
	for _, path in ipairs(WINDUI_PATHS) do
		local okRead, src = pcall(function()
			return readfile(path)
		end)
		if okRead and type(src) == "string" and #src > 100 then
			return compileWindUI(src, path)
		end
	end
	for _, url in ipairs(WINDUI_URLS) do
		local okHttp, src = pcall(function()
			return game:HttpGet(url)
		end)
		if okHttp and type(src) == "string" and #src > 100 then
			pcall(function()
				if writefile then
					writefile("WindUI.lua", src)
				end
			end)
			return compileWindUI(src, url)
		end
	end
	error("WindUI not found: put WindUI.lua in Real workspace, or allow HttpGet")
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

do
	local pg = LocalPlayer:WaitForChild("PlayerGui")
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

local function safeRequire(pathParts)
	local cur = ReplicatedStorage
	for _, name in ipairs(pathParts) do
		if not cur then
			return nil
		end
		cur = cur:FindFirstChild(name)
	end
	if not cur then
		return nil
	end
	local ok, mod = pcall(require, cur)
	if ok then
		return mod
	end
	return nil
end

local Remotes = safeRequire({ "shared", "Remotes" })
	or safeRequire({ "Shared", "Remotes" })
	or {}
local ClientPlayerData = safeRequire({ "client", "ClientPlayerData" })
	or safeRequire({ "Client", "ClientPlayerData" })
local InventoryConfig = safeRequire({ "shared", "config", "InventoryConfig" })
local getAvilibleBaseSlotsNames = safeRequire({ "shared", "util", "getAvilibleBaseSlotsNames" })
local ThrowBar = safeRequire({ "client", "throw", "ThrowBar" })
local ThrowSystem = safeRequire({ "shared", "UECS", "Systems", "Client", "ThrowSystem" })

if not STATE.store then
	STATE.store = {}
end
local store = STATE.store

local CFG = store.cfg
	or {
		Silent = false,
		MasterFarm = false,
		AutoFarm = false,
		InstantBar = true,
		PerfectThrow = true,
		ClickFishGui = true,
		AutoSell = true,
		AutoCollect = true,
		AutoPlace = true,
		AutoTrain = true,
		AutoRebirth = false,
		AutoClaim = true,
		AutoUpgrade = false,
		WalkSpeedOn = false,
		WalkSpeed = 32,
		JumpOn = false,
		JumpPower = 50,
		InfJump = false,
		Noclip = false,
		Fullbright = false,
		AntiAfk = true,
		FpsUnlock = false,
		FarmDelay = 0.75,
		TrainDelay = 0.2,
		CollectDelay = 1.2,
	}
store.cfg = CFG

local ORIG_BAR = store.origBar
if not ORIG_BAR and ThrowBar and typeof(ThrowBar.Config) == "table" then
	ORIG_BAR = {
		AutoThrowBarDuration = ThrowBar.Config.AutoThrowBarDuration,
		AutoAccuracyMin = ThrowBar.Config.AutoAccuracyMin,
		AutoAccuracyMax = ThrowBar.Config.AutoAccuracyMax,
		BarCamTransitionTime = ThrowBar.Config.BarCamTransitionTime,
	}
	store.origBar = ORIG_BAR
end

local function notify(title, content)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = title or "Fish Bait",
			Content = content or "",
			Duration = 2.5,
		})
	end)
end

local function fireRemote(name, ...)
	local args = { ... }
	local r = Remotes and Remotes[name]
	if r then
		local ok = pcall(function()
			if typeof(r.Fire) == "function" then
				r:Fire(table.unpack(args))
			elseif typeof(r.FireServer) == "function" then
				r:FireServer(table.unpack(args))
			elseif typeof(r.Invoke) == "function" then
				r:Invoke(table.unpack(args))
			elseif typeof(r.InvokeServer) == "function" then
				r:InvokeServer(table.unpack(args))
			end
		end)
		if ok then
			return true
		end
	end
	return false
end

local function getState()
	if not ClientPlayerData then
		return nil
	end
	if ClientPlayerData.isPlayerDataLoaded == false then
		return nil
	end
	local ok, st = pcall(function()
		return ClientPlayerData.serverProfile:getState()
	end)
	if ok and typeof(st) == "table" then
		return st
	end
	return nil
end

local function fishCount()
	local st = getState()
	if not st or not InventoryConfig or typeof(InventoryConfig.countFish) ~= "function" then
		return 0
	end
	local ok, n = pcall(InventoryConfig.countFish, st)
	if ok and typeof(n) == "number" then
		return n
	end
	return 0
end

local function fishLimit()
	if InventoryConfig and typeof(InventoryConfig.FishLimit) == "number" then
		return InventoryConfig.FishLimit
	end
	return 150
end

local function applyInstant()
	if not ThrowBar or typeof(ThrowBar.Config) ~= "table" or not ORIG_BAR then
		return
	end
	if CFG.InstantBar then
		ThrowBar.Config.AutoThrowBarDuration = 0.05
		ThrowBar.Config.BarCamTransitionTime = 0.05
	else
		ThrowBar.Config.AutoThrowBarDuration = ORIG_BAR.AutoThrowBarDuration
		ThrowBar.Config.BarCamTransitionTime = ORIG_BAR.BarCamTransitionTime
	end
	if CFG.PerfectThrow then
		ThrowBar.Config.AutoAccuracyMin = 1
		ThrowBar.Config.AutoAccuracyMax = 1
	else
		ThrowBar.Config.AutoAccuracyMin = ORIG_BAR.AutoAccuracyMin
		ThrowBar.Config.AutoAccuracyMax = ORIG_BAR.AutoAccuracyMax
	end
end

local function restoreInstant()
	if not ThrowBar or typeof(ThrowBar.Config) ~= "table" or not ORIG_BAR then
		return
	end
	ThrowBar.Config.AutoThrowBarDuration = ORIG_BAR.AutoThrowBarDuration
	ThrowBar.Config.AutoAccuracyMin = ORIG_BAR.AutoAccuracyMin
	ThrowBar.Config.AutoAccuracyMax = ORIG_BAR.AutoAccuracyMax
	ThrowBar.Config.BarCamTransitionTime = ORIG_BAR.BarCamTransitionTime
end

if not store.hookedThrow and ThrowSystem and typeof(ThrowSystem.ThrowWithForce) == "function" and typeof(hookfunction) == "function" then
	store.origThrowWithForce = hookfunction(ThrowSystem.ThrowWithForce, function(self, power)
		if CFG.PerfectThrow then
			power = 1
		end
		return store.origThrowWithForce(self, power)
	end)
	store.hookedThrow = true
end

local function startFarm()
	applyInstant()
	if ThrowSystem then
		pcall(function()
			ThrowSystem:SetFakeAutoFishing(true)
		end)
		local already = false
		pcall(function()
			already = ThrowSystem.IsAutoFishing and ThrowSystem:IsAutoFishing()
		end)
		if already then
			return true
		end
		local ok = pcall(function()
			ThrowSystem:StartAutoFishing()
		end)
		if ok then
			return true
		end
	end
	return false
end

local function stopFarm()
	if ThrowSystem then
		pcall(function()
			ThrowSystem:StopAutoFishing()
		end)
		pcall(function()
			ThrowSystem:SetFakeAutoFishing(false)
		end)
	end
end

local function sellAll()
	fireRemote("SellAllFish")
	fireRemote("RequestSellAllFish")
	fireRemote("SellFish")
end

local function collectAllCash()
	local st = getState()
	local names = {}
	local seen = {}
	local level = 1
	if st and typeof(st.tycoonLevel) == "number" then
		level = math.max(st.tycoonLevel, 1)
	end
	if typeof(getAvilibleBaseSlotsNames) == "function" then
		local ok, slots = pcall(getAvilibleBaseSlotsNames, level)
		if ok and typeof(slots) == "table" then
			for _, name in ipairs(slots) do
				local s = tostring(name)
				if not seen[s] then
					seen[s] = true
					table.insert(names, s)
				end
			end
		end
	end
	if st and typeof(st.baseSlots) == "table" then
		for name in pairs(st.baseSlots) do
			local s = tostring(name)
			if not seen[s] then
				seen[s] = true
				table.insert(names, s)
			end
		end
	end
	for _, name in ipairs(names) do
		fireRemote("RequestCollectCash", name)
	end
	fireRemote("RequestUseAutoCollect")
	fireRemote("CollectAllCash")
	return #names
end

local function trainOnce()
	fireRemote("Train")
	fireRemote("RequestTrain")
	fireRemote("TrainPower")
end

local function placeFish()
	local st = getState()
	if not st or typeof(getAvilibleBaseSlotsNames) ~= "function" then
		return 0
	end
	local level = 1
	if typeof(st.tycoonLevel) == "number" then
		level = math.max(st.tycoonLevel, 1)
	end
	local ok, slots = pcall(getAvilibleBaseSlotsNames, level)
	if not ok or typeof(slots) ~= "table" then
		return 0
	end
	local occupied = {}
	if typeof(st.baseSlots) == "table" then
		for name, data in pairs(st.baseSlots) do
			if data ~= nil then
				occupied[tostring(name)] = true
			end
		end
	end
	local fishes = {}
	if typeof(st.inventory) == "table" then
		for _, item in pairs(st.inventory) do
			if typeof(item) == "table" and item.Category == "Fish" and typeof(item.ConfigName) == "string" then
				local stack = item.Stack
				if typeof(stack) ~= "number" then
					stack = 1
				end
				for _ = 1, math.max(stack, 1) do
					table.insert(fishes, item.ConfigName)
				end
			end
		end
	end
	local placed = 0
	local fi = 1
	for _, slotName in ipairs(slots) do
		if fi > #fishes then
			break
		end
		if not occupied[slotName] then
			local configName = fishes[fi]
			fi = fi + 1
			fireRemote("RequestPlaceFish", {
				ConfigName = configName,
				BaseSlotIndexName = slotName,
			})
			placed = placed + 1
		end
	end
	return placed
end

local function claimAll()
	fireRemote("RequestClaimDailyLogin")
	fireRemote("RequestFreeGiftClaim")
	fireRemote("ClaimOfflineMoney")
	fireRemote("RequestClaimGift")
	fireRemote("ClaimDaily")
end

local function upgradeAll()
	fireRemote("RequestUpgradeThrowSpeed")
	fireRemote("RequestUpgradePullSpeed")
	fireRemote("RequestUpgradeRollSpeed")
	fireRemote("RequestUpgradeRod")
	fireRemote("RequestUpgradeWeight")
end

local function rebirth()
	fireRemote("RequestRebirth")
	fireRemote("Rebirth")
end

local function charHum()
	local char = LocalPlayer.Character
	if not char then
		return nil, nil
	end
	return char, char:FindFirstChildOfClass("Humanoid")
end

local function applyWalkSpeed()
	local _, hum = charHum()
	if not hum then
		return
	end
	if CFG.WalkSpeedOn then
		hum.WalkSpeed = CFG.WalkSpeed
	end
	if CFG.JumpOn then
		pcall(function()
			hum.UseJumpPower = true
			hum.JumpPower = CFG.JumpPower
		end)
	end
end

local function clickFishGui()
	if typeof(mouse1click) == "function" then
		pcall(mouse1click)
	end
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local n = 0
	for _, gui in ipairs(pg:GetChildren()) do
		n = n + 1
		if n > 40 then
			break
		end
		local ok, descendants = pcall(function()
			return gui:GetDescendants()
		end)
		if ok then
			local scanned = 0
			for _, inst in ipairs(descendants) do
				scanned = scanned + 1
				if scanned > 250 then
					break
				end
				if inst:IsA("GuiButton") or inst:IsA("TextLabel") or inst:IsA("TextButton") then
					local text = ""
					pcall(function()
						text = string.upper(inst.Text or "")
					end)
					if text == "FISH!" or text == "FISH" or text:find("FISH!", 1, true) then
						if inst:IsA("GuiButton") then
							pcall(function()
								firesignal(inst.Activated)
							end)
							pcall(function()
								firesignal(inst.MouseButton1Click)
							end)
						end
						if typeof(mouse1click) == "function" then
							pcall(mouse1click)
						end
						return
					end
				end
			end
		end
		task.wait()
	end
end

local function fireTrainWorld()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or typeof(fireproximityprompt) ~= "function" then
		return
	end
	local scanned = 0
	for _, inst in ipairs(Workspace:GetChildren()) do
		scanned = scanned + 1
		if scanned > 80 then
			break
		end
		local ok, desc = pcall(function()
			return inst:GetDescendants()
		end)
		if ok then
			local inner = 0
			for _, d in ipairs(desc) do
				inner += 1
				if inner > 120 then
					break
				end
				if d:IsA("ProximityPrompt") then
					local action = string.lower(tostring(d.ActionText) .. " " .. tostring(d.ObjectText) .. " " .. d.Name)
					if action:find("train") or action:find("weight") or action:find("power") then
						pcall(fireproximityprompt, d)
					end
				end
			end
		end
		task.wait()
	end
end

local function statusText()
	local st = getState()
	local money = st and (st.money or st.Cash or st.cash) or "?"
	local gems = st and st.gems or "?"
	local str = st and (st.strength or st.power or st.Power) or "?"
	local rod = st and (st.fishRod or st.rod) or "?"
	local inZone = false
	local auto = false
	pcall(function()
		inZone = ThrowSystem and ThrowSystem.IsInThrowZone and ThrowSystem.IsInThrowZone()
	end)
	pcall(function()
		auto = ThrowSystem and ThrowSystem.IsAutoFishing and ThrowSystem:IsAutoFishing()
	end)
	local engine = ThrowSystem and "ThrowSystem" or "GUI click"
	return string.format(
		"%s  cash %s  gems %s  power %s\nfish %d/%d  rod %s\nzone %s  auto %s  delay %.2fs",
		engine,
		tostring(money),
		tostring(gems),
		tostring(str),
		fishCount(),
		fishLimit(),
		tostring(rod),
		inZone and "yes" or "no",
		auto and "on" or "off",
		CFG.FarmDelay
	)
end

local function applyFullbright()
	if not CFG.Fullbright then
		return
	end
	pcall(function()
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.Brightness = 2
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.ClockTime = 14
	end)
end

local function applyFps()
	if typeof(setfpscap) == "function" then
		if CFG.FpsUnlock then
			pcall(setfpscap, 0)
		else
			pcall(setfpscap, 60)
		end
	end
end

local function tpTo(cf)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and typeof(cf) == "CFrame" then
		hrp.CFrame = cf + Vector3.new(0, 4, 0)
		return true
	end
	return false
end

local function tpNamed(needles)
	local scanned = 0
	for _, inst in ipairs(Workspace:GetChildren()) do
		scanned += 1
		if scanned > 120 then
			break
		end
		local n = string.lower(inst.Name)
		for _, needle in ipairs(needles) do
			if n:find(needle, 1, true) then
				local part = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
				if part then
					return tpTo(part.CFrame)
				end
			end
		end
	end
	return false
end

applyInstant()
applyFps()

task.spawn(function()
	while STATE.alive() do
		applyInstant()
		if CFG.MasterFarm or CFG.AutoFarm then
			local auto = false
			pcall(function()
				auto = ThrowSystem and ThrowSystem.IsAutoFishing and ThrowSystem:IsAutoFishing()
			end)
			if not auto then
				startFarm()
			end
			if CFG.AutoSell and fishCount() >= fishLimit() - 2 then
				sellAll()
				task.wait(0.35)
				startFarm()
			end
		end
		task.wait(CFG.FarmDelay)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.MasterFarm or CFG.AutoSell then
			if fishCount() >= 8 then
				sellAll()
			end
		end
		if CFG.MasterFarm or CFG.AutoCollect then
			collectAllCash()
		end
		if CFG.MasterFarm or CFG.AutoPlace then
			placeFish()
		end
		if CFG.AutoClaim then
			claimAll()
		end
		if CFG.AutoUpgrade then
			upgradeAll()
		end
		if CFG.AutoRebirth then
			rebirth()
		end
		task.wait(CFG.CollectDelay)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.MasterFarm or CFG.AutoTrain then
			trainOnce()
			fireTrainWorld()
		end
		task.wait(CFG.TrainDelay)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.WalkSpeedOn or CFG.JumpOn then
			applyWalkSpeed()
		end
		if CFG.Fullbright then
			applyFullbright()
		end
		task.wait(0.4)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if (CFG.MasterFarm or CFG.AutoFarm or CFG.InstantBar) and CFG.ClickFishGui then
			local gui = LocalPlayer:FindFirstChild("PlayerGui")
			local main = gui and gui:FindFirstChild("MainUI")
			local throwFrame = main and main:FindFirstChild("ThrowFrame")
			local meter = throwFrame and throwFrame:FindFirstChild("SpeedMeter")
			if meter and meter.Visible then
				if typeof(mouse1click) == "function" then
					pcall(mouse1click)
				end
			end
			clickFishGui()
		end
		task.wait(0.05)
	end
end)

STATE.connect(UserInputService.JumpRequest, function()
	if not CFG.InfJump then
		return
	end
	local _, hum = charHum()
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

STATE.connect(RunService.Stepped, function()
	if not CFG.Noclip then
		return
	end
	local char = LocalPlayer.Character
	if not char then
		return
	end
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
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
	task.wait(0.3)
	if STATE.alive() then
		applyWalkSpeed()
	end
end)

STATE.onCleanup(function()
	restoreInstant()
	if not CFG.AutoFarm and not CFG.MasterFarm then
		stopFarm()
	end
	if store.origThrowWithForce and typeof(restorefunction) == "function" then
		pcall(restorefunction, store.origThrowWithForce)
		store.hookedThrow = false
	end
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "BE A FISH BAIT",
	Author = "auto farm + instant",
	Folder = "FishBaitHub",
	Icon = "fish",
	NewElements = true,
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = true,
	OpenButton = {
		Title = "Fish Bait",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		OnlyIcon = true,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#2fe7ff")),
	},
})
store.window = Window

Window:Tag({
	Title = "v1",
	Icon = "fish",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")

local MainSec = Window:Section({ Title = "Main", Opened = true })
local FarmSec = Window:Section({ Title = "Farm", Opened = true })
local MoveSec = Window:Section({ Title = "Move", Opened = true })

do
	local Tab = MainSec:Tab({ Title = "Home", Icon = "house", IconColor = Green })
	task.wait()
	local para = Tab:Paragraph({
		Title = "BE A FISH BAIT",
		Desc = statusText(),
	})
	Tab:Toggle({
		Title = "Master Auto Farm",
		Desc = "Fish + collect + place + train + sell",
		Icon = "zap",
		Value = CFG.MasterFarm,
		Callback = function(v)
			CFG.MasterFarm = v
			CFG.AutoFarm = v or CFG.AutoFarm
			CFG.AutoCollect = v or CFG.AutoCollect
			CFG.AutoPlace = v or CFG.AutoPlace
			CFG.AutoTrain = v or CFG.AutoTrain
			CFG.AutoSell = v or CFG.AutoSell
			if v then
				startFarm()
				notify("Master Farm", "ON — stand on the dock / throw zone")
			else
				stopFarm()
				notify("Master Farm", "OFF")
			end
		end,
	})
	Tab:Toggle({
		Title = "Silent Mode",
		Desc = "Mute hub notifications",
		Value = CFG.Silent,
		Callback = function(v)
			CFG.Silent = v
		end,
	})
	Tab:Toggle({
		Title = "Anti AFK",
		Value = CFG.AntiAfk,
		Callback = function(v)
			CFG.AntiAfk = v
		end,
	})
	Tab:Button({
		Title = "Refresh Status",
		Icon = "refresh-cw",
		Callback = function()
			if para and para.SetDesc then
				para:SetDesc(statusText())
			end
			notify("Status", statusText())
		end,
	})
	Tab:Button({
		Title = "Claim Daily / Gift / Offline",
		Icon = "gift",
		Callback = function()
			claimAll()
			notify("Claim", "daily + gift + offline sent")
		end,
	})
end

do
	local Tab = FarmSec:Tab({ Title = "Auto Fish", Icon = "fish", IconColor = Blue })
	task.wait()
	Tab:Paragraph({
		Title = "Stand in the throw zone",
		Desc = "Unlocks the game auto-fish flag, then starts it. Instant bar + perfect accuracy skip the meter. FISH! click is the backup.",
	})
	Tab:Toggle({
		Title = "Auto Farm",
		Desc = "Fake auto-fish + StartAutoFishing loop",
		Value = CFG.AutoFarm,
		Callback = function(v)
			CFG.AutoFarm = v
			if v then
				local ok = startFarm()
				notify("Auto Farm", ok and "started" or "waiting (stay in zone)")
			else
				stopFarm()
				notify("Auto Farm", "stopped")
			end
		end,
	})
	Tab:Toggle({
		Title = "Instant Throw Bar",
		Desc = "Bar commits in 0.05s",
		Value = CFG.InstantBar,
		Callback = function(v)
			CFG.InstantBar = v
			applyInstant()
		end,
	})
	Tab:Toggle({
		Title = "Always Perfect Throw",
		Desc = "Force accuracy 1.0",
		Value = CFG.PerfectThrow,
		Callback = function(v)
			CFG.PerfectThrow = v
			applyInstant()
		end,
	})
	Tab:Toggle({
		Title = "Click FISH! GUI",
		Desc = "Backup if ThrowSystem is busy",
		Value = CFG.ClickFishGui,
		Callback = function(v)
			CFG.ClickFishGui = v
		end,
	})
	Tab:Slider({
		Title = "Farm Delay",
		Value = { Min = 0.15, Max = 2, Default = CFG.FarmDelay },
		Step = 0.05,
		Callback = function(v)
			CFG.FarmDelay = v
		end,
	})
	Tab:Button({
		Title = "Throw Once (perfect)",
		Icon = "target",
		Callback = function()
			applyInstant()
			pcall(function()
				if ThrowSystem then
					ThrowSystem:ThrowingSegment(true)
				end
			end)
			clickFishGui()
			notify("Throw", "cast started")
		end,
	})
end

do
	local Tab = FarmSec:Tab({ Title = "Money", Icon = "banknote", IconColor = Yellow })
	task.wait()
	Tab:Toggle({
		Title = "Auto Collect Cash",
		Desc = "RequestCollectCash on every plot slot",
		Value = CFG.AutoCollect,
		Callback = function(v)
			CFG.AutoCollect = v
			if v then
				collectAllCash()
			end
		end,
	})
	Tab:Toggle({
		Title = "Auto Place Fish",
		Desc = "Inventory fish onto empty aquarium slots",
		Value = CFG.AutoPlace,
		Callback = function(v)
			CFG.AutoPlace = v
			if v then
				notify("Place", tostring(placeFish()) .. " placed")
			end
		end,
	})
	Tab:Toggle({
		Title = "Auto Sell",
		Desc = "Sell when inventory fills",
		Value = CFG.AutoSell,
		Callback = function(v)
			CFG.AutoSell = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Rebirth",
		Desc = "Spam RequestRebirth when you can afford it",
		Value = CFG.AutoRebirth,
		Callback = function(v)
			CFG.AutoRebirth = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Upgrade Speeds",
		Desc = "Throw / pull / roll upgrades",
		Value = CFG.AutoUpgrade,
		Callback = function(v)
			CFG.AutoUpgrade = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Claim",
		Desc = "Daily, free gift, offline cash",
		Value = CFG.AutoClaim,
		Callback = function(v)
			CFG.AutoClaim = v
		end,
	})
	Tab:Slider({
		Title = "Collect Delay",
		Value = { Min = 0.4, Max = 4, Default = CFG.CollectDelay },
		Step = 0.1,
		Callback = function(v)
			CFG.CollectDelay = v
		end,
	})
	Tab:Button({
		Title = "Collect All Cash Now",
		Icon = "hand-coins",
		Callback = function()
			notify("Collect", tostring(collectAllCash()) .. " slots")
		end,
	})
	Tab:Button({
		Title = "Place Fish Now",
		Icon = "map-pin",
		Callback = function()
			notify("Place", tostring(placeFish()) .. " placed")
		end,
	})
	Tab:Button({
		Title = "Sell All Now",
		Icon = "coins",
		Callback = function()
			sellAll()
			notify("Sell", "SellAllFish fired")
		end,
	})
	Tab:Button({
		Title = "Rebirth Now",
		Callback = function()
			rebirth()
			notify("Rebirth", "request sent")
		end,
	})
	Tab:Button({
		Title = "Upgrade Speeds Now",
		Callback = function()
			upgradeAll()
			notify("Upgrade", "throw/pull/roll")
		end,
	})
end

do
	local Tab = FarmSec:Tab({ Title = "Train", Icon = "dumbbell", IconColor = Red })
	task.wait()
	Tab:Toggle({
		Title = "Auto Train",
		Desc = "Spam Train remote + nearby weight prompts",
		Value = CFG.AutoTrain,
		Callback = function(v)
			CFG.AutoTrain = v
		end,
	})
	Tab:Slider({
		Title = "Train Delay",
		Value = { Min = 0.05, Max = 1, Default = CFG.TrainDelay },
		Step = 0.05,
		Callback = function(v)
			CFG.TrainDelay = v
		end,
	})
	Tab:Button({
		Title = "Train Once",
		Icon = "dumbbell",
		Callback = function()
			trainOnce()
			notify("Train", "fired")
		end,
	})
	Tab:Button({
		Title = "TP Train Area",
		Callback = function()
			local ok = tpNamed({ "train", "weight", "gym", "power" })
			notify("TP", ok and "train area" or "not found")
		end,
	})
end

do
	local Tab = MoveSec:Tab({ Title = "Player", Icon = "user", IconColor = Green })
	task.wait()
	Tab:Toggle({
		Title = "Speed",
		Value = CFG.WalkSpeedOn,
		Callback = function(v)
			CFG.WalkSpeedOn = v
			applyWalkSpeed()
		end,
	})
	Tab:Slider({
		Title = "WalkSpeed",
		Value = { Min = 16, Max = 120, Default = CFG.WalkSpeed },
		Callback = function(v)
			CFG.WalkSpeed = v
			applyWalkSpeed()
		end,
	})
	Tab:Toggle({
		Title = "Jump Power",
		Value = CFG.JumpOn,
		Callback = function(v)
			CFG.JumpOn = v
			applyWalkSpeed()
		end,
	})
	Tab:Slider({
		Title = "JumpPower",
		Value = { Min = 50, Max = 200, Default = CFG.JumpPower },
		Callback = function(v)
			CFG.JumpPower = v
			applyWalkSpeed()
		end,
	})
	Tab:Toggle({
		Title = "Inf Jump",
		Value = CFG.InfJump,
		Callback = function(v)
			CFG.InfJump = v
		end,
	})
	Tab:Toggle({
		Title = "Noclip",
		Value = CFG.Noclip,
		Callback = function(v)
			CFG.Noclip = v
		end,
	})
	Tab:Toggle({
		Title = "Fullbright",
		Value = CFG.Fullbright,
		Callback = function(v)
			CFG.Fullbright = v
			applyFullbright()
		end,
	})
	Tab:Toggle({
		Title = "Unlock FPS",
		Value = CFG.FpsUnlock,
		Callback = function(v)
			CFG.FpsUnlock = v
			applyFps()
		end,
	})
	Tab:Button({
		Title = "TP Last / Best Zone",
		Icon = "map",
		Callback = function()
			local st = getState()
			local names = { "zone", "island", "area", "sci-fi", "scifi", "pier", "dock" }
			if st then
				for _, key in ipairs({ "lastZone", "currentZone", "zone", "area", "unlockedZone" }) do
					local v = st[key]
					if typeof(v) == "string" then
						table.insert(names, 1, string.lower(v))
					end
				end
			end
			local ok = tpNamed(names)
			notify("TP", ok and "moved" or "zone part not found — walk onto the dock")
		end,
	})
	Tab:Button({
		Title = "TP Spawn / Dock",
		Callback = function()
			local ok = tpNamed({ "spawn", "dock", "pier", "lobby" })
			notify("TP", ok and "dock" or "not found")
		end,
	})
end

print("[FishBaitHub] loaded")

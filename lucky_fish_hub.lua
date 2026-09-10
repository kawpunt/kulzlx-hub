--[[
  Pull a Lucky Fish Hub - WindUI
  live-reload label: lucky_fish_hub
  Place 112781315318195 / Universe 10195997258

  Instant throw/pull/roll, speed x1-x1000, value editor, autofarm, shop, claims, worlds.
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

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

local function req(path)
	local ok, mod = pcall(require, path)
	if ok then
		return mod
	end
	return nil
end

local Remotes = req(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Remotes"))
local ClientPlayerData = req(ReplicatedStorage:WaitForChild("client"):WaitForChild("ClientPlayerData"))
local InventoryConfig = req(ReplicatedStorage.shared.config.InventoryConfig)
local getAvilibleBaseSlotsNames = req(ReplicatedStorage.shared.util.getAvilibleBaseSlotsNames)
local ThrowBar = req(ReplicatedStorage.client.throw.ThrowBar)
local ThrowSystem = req(ReplicatedStorage.shared.UECS.Systems.Client.ThrowSystem)
local ThrowPacing = req(ReplicatedStorage.shared.config.ThrowPacingConfig)
local FishRodConfig = req(ReplicatedStorage.shared.config.FishRodConfig)
local TrainToolConfig = req(ReplicatedStorage.shared.config.TrainToolConfig)
local PotionConfig = req(ReplicatedStorage.shared.config.PotionConfig)
local EnchantConfig = req(ReplicatedStorage.shared.config.EnchantConfig)
local calculateClickPower = req(ReplicatedStorage.shared.util.calculateClickPower)
local RollSpeedMultiplier = req(ReplicatedStorage.shared.util.RollSpeedMultiplier)
local FishingFloatsConfig = req(ReplicatedStorage.shared.config.FishingFloatsConfig)
local DeepsGearConfig = req(ReplicatedStorage.shared.config.DeepsGearConfig)
local DeepsConfig = req(ReplicatedStorage.shared.config.DeepsConfig)
local DeepsState = req(ReplicatedStorage.client.DeepsState)
local MountConfig = req(ReplicatedStorage.shared.config.MountConfig)
local CollectionService = game:GetService("CollectionService")

if not STATE.store then
	STATE.store = {}
end
local store = STATE.store

local DEFAULTS = {
	AutoFarm = false,
	PerfectThrow = true,
	InstantBar = true,
	InstantPull = true,
	InstantRoll = false,
	AutoSell = false,
	AutoCollect = false,
	AutoTrain = false,
	AutoClickBonus = true,
	AutoPlace = false,
	AutoUpgrade = false,
	AutoClick = true,
	WalkSpeedOn = false,
	WalkSpeed = 32,
	JumpOn = false,
	JumpPower = 50,
	InfJump = false,
	Noclip = false,
	Fly = false,
	FlySpeed = 80,
	Fullbright = false,
	AntiAfk = true,
	FpsUnlock = false,
	Silent = false,
	ThrowMult = 1,
	PullMult = 1,
	PullPowerMult = 1,
	RollMult = 1,
	FarmDelay = 0.6,
	TrainDelay = 0.15,
	CollectDelay = 1.1,
	Gravity = 196.2,
	GravityOn = false,
	ZoomUnlock = false,
	BarDuration = 0.05,
	SelectedRod = "FISHROD1",
	SelectedTool = "RockTrainTool",
	PromoCode = "",
	UpgradeBurst = 5,
	AutoUpdateTools = false,
	AutoUpdateRods = false,
	AutoEquipBest = false,
	EquipBestMode = "BestNow",
	AutoSellMin = 0,
	SelectedEnchant = "Luck4",
	SelectedFloat = "FourLeafClover",
	SelectedFloatTier = "Mythic",
	FloatSlot = 1,
	SelectedMount = "MOUNT_Fish_Rideable_1",
	InfOxygen = false,
	AutoDeepsCatch = false,
	AutoDeepsLoot = false,
	AutoLuckyblock = false,
	AutoEnchant = false,
	AutoNpcTrade = false,
	AutoCooking = false,
	AutoMutation = false,
	AutoAlchemy = false,
	AutoWeather = false,
	AutoChest = false,
	AutoVault = false,
	EspOn = false,
	EspFish = true,
	EspAirdrop = true,
	EspNpc = true,
	EspChest = true,
}

if not store.cfg then
	store.cfg = {}
end
for k, v in pairs(DEFAULTS) do
	if store.cfg[k] == nil then
		store.cfg[k] = v
	end
end
local CFG = store.cfg

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

local ORIG_PACE = store.origPace
if not ORIG_PACE and ThrowPacing then
	ORIG_PACE = {
		MinPullTime = ThrowPacing.MinPullTime,
		DiveFallTime = ThrowPacing.DiveFallTime,
		SpinDurationMin = ThrowPacing.SpinDurationMin,
		SpinDurationMax = ThrowPacing.SpinDurationMax,
		RevealFlyTime = ThrowPacing.RevealFlyTime,
		RevealGrowTime = ThrowPacing.RevealGrowTime,
		RevealHoldTime = ThrowPacing.RevealHoldTime,
		DisappearDelay = ThrowPacing.DisappearDelay,
		DisappearDuration = ThrowPacing.DisappearDuration,
		WallRiseDelay = ThrowPacing.WallRiseDelay,
		WallRiseTweenTime = ThrowPacing.WallRiseTweenTime,
	}
	store.origPace = ORIG_PACE
end

if store.origGravity == nil then
	store.origGravity = Workspace.Gravity
end

local function notify(title, content)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = title or "Lucky Fish",
			Content = content or "",
			Duration = 2.2,
		})
	end)
end

local function fireRemote(name, ...)
	local args = { ... }
	local r = Remotes and Remotes[name]
	if not r then
		return false
	end
	local ok = pcall(function()
		if typeof(r.Fire) == "function" then
			r:Fire(table.unpack(args))
		elseif typeof(r.Call) == "function" then
			r:Call(table.unpack(args))
		elseif typeof(r.FireServer) == "function" then
			r:FireServer(table.unpack(args))
		end
	end)
	return ok
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

local function charHum()
	local char = LocalPlayer.Character
	if not char then
		return nil, nil, nil
	end
	return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function setAttr(name, value)
	pcall(function()
		LocalPlayer:SetAttribute(name, value)
	end)
end

local FAKE_ATTRS = {
	"LuckMultiplier",
	"MutationLuckMultiplier",
	"CashMultiplier",
}

local function stripFakeAttrs()
	for _, name in ipairs(FAKE_ATTRS) do
		local v = LocalPlayer:GetAttribute(name)
		if typeof(v) == "number" and v > 10 then
			setAttr(name, nil)
		end
	end
end
stripFakeAttrs()
if store.hookedThrowData and store.origThrowDataCall and Remotes and Remotes.ThrowData and typeof(restorefunction) == "function" then
	pcall(restorefunction, Remotes.ThrowData.Call)
	store.origThrowDataCall = nil
	store.hookedThrowData = false
end
CFG.ThrowPowerMult = nil
CFG.LuckOn = nil

local function rememberAttr(key, attr)
	local cur = LocalPlayer:GetAttribute(attr)
	if store[key] == nil or (typeof(store[key]) == "number" and store[key] > 10) then
		if typeof(cur) == "number" and cur > 10 then
			store[key] = 1
		else
			store[key] = cur
		end
	end
end

local function applyThrowMult()
	local v = CFG.ThrowMult
	if typeof(v) ~= "number" or v <= 1 then
		setAttr("DebugThrowSpeedMult", nil)
	else
		setAttr("DebugThrowSpeedMult", v)
	end
end

local function applyPullSpoof()
	rememberAttr("origFishSpeed", "FishingSpeedMultiplier")
	rememberAttr("origPullPower", "PullPowerMultiplier")
	local pull = CFG.PullMult
	if typeof(pull) ~= "number" or pull <= 1 then
		local orig = store.origFishSpeed
		if orig == nil then
			setAttr("FishingSpeedMultiplier", 1)
		else
			setAttr("FishingSpeedMultiplier", orig)
		end
	else
		setAttr("FishingSpeedMultiplier", pull)
	end
	local power = CFG.PullPowerMult
	if typeof(power) ~= "number" or power <= 1 then
		setAttr("PullPowerMultiplier", store.origPullPower)
	else
		setAttr("PullPowerMultiplier", power)
	end
end

local function itemCost(cfg, id)
	local item = cfg and cfg[id]
	if typeof(item) ~= "table" then
		return math.huge
	end
	return tonumber(item.Cost) or tonumber(item.Price) or math.huge
end

local function nextAffordable(cfg, currentId, money)
	if typeof(cfg) ~= "table" or typeof(money) ~= "number" then
		return nil
	end
	local currentCost = itemCost(cfg, currentId)
	if currentCost ~= currentCost then
		currentCost = 0
	end
	local best = nil
	for id, item in pairs(cfg) do
		if typeof(item) == "table" then
			local cost = tonumber(item.Cost) or tonumber(item.Price)
			if typeof(cost) == "number" and cost >= 0 and cost <= money and cost > currentCost then
				if not best or cost > best.cost then
					best = { id = id, cost = cost, name = item.DisplayName or id }
				end
			end
		end
	end
	return best
end

local function equipBestNow()
	local mode = CFG.EquipBestMode or "BestNow"
	local now = os.clock()
	if (now - (store.lastEquipBest or 0)) < 10.2 then
		return false
	end
	local st = getState()
	if st and st.hasEquipBest ~= true then
		fireRemote("RequestBuyEquipBest")
	end
	fireRemote("RequestEquipBest", mode)
	store.lastEquipBest = now
	return true
end

local function autoUpdateTools()
	local st = getState()
	if not st then
		return
	end
	local money = tonumber(st.money) or 0
	local now = os.clock()
	if CFG.AutoUpdateTools then
		local nxt = nextAffordable(TrainToolConfig, st.trainingTool, money)
		if nxt and (now - (store.lastToolBuy or 0)) > 2 then
			store.lastToolBuy = now
			fireRemote("BuyTrainingTool", nxt.id)
			fireRemote("EquipTrainingTool", nxt.id)
			CFG.SelectedTool = nxt.id
			notify("Auto Tool", nxt.name)
		end
	end
	if CFG.AutoUpdateRods then
		local nxt = nextAffordable(FishRodConfig, st.fishRod, money)
		if nxt and (now - (store.lastRodBuy or 0)) > 2 then
			store.lastRodBuy = now
			fireRemote("BuyFishRod", nxt.id)
			fireRemote("EquipFishRod", nxt.id)
			CFG.SelectedRod = nxt.id
			notify("Auto Rod", nxt.name)
		end
	end
	if CFG.AutoEquipBest then
		equipBestNow()
	end
end

local function applyOxygen()
	if not CFG.InfOxygen then
		return
	end
	if DeepsConfig and typeof(DeepsConfig.Oxygen) == "table" then
		DeepsConfig.Oxygen.BaseSeconds = 1e7
		DeepsConfig.Oxygen.FailGraceSeconds = 1e7
	end
	if DeepsState then
		pcall(function()
			DeepsState.oxygenCapacity = 1e7
			DeepsState.oxygenRemaining = 1e7
		end)
	end
	if DeepsGearConfig and typeof(DeepsGearConfig.GetOxygenSeconds) == "function" and not store.hookedOxygen and typeof(hookfunction) == "function" then
		store.origOxygen = hookfunction(DeepsGearConfig.GetOxygenSeconds, function(...)
			if CFG.InfOxygen then
				return 1e7
			end
			return store.origOxygen(...)
		end)
		store.hookedOxygen = true
	end
end

local function deepsAuto()
	if CFG.AutoDeepsCatch then
		local ids = {}
		local function takeId(inst)
			if not inst then
				return
			end
			local id = inst:GetAttribute("Id") or inst:GetAttribute("FishId") or inst:GetAttribute("id")
			if typeof(id) == "number" then
				ids[id] = true
			end
		end
		pcall(function()
			for _, tag in ipairs({ "DeepsFish", "DeepsItem", "DeepsCatch", "DeepsLoot" }) do
				for _, inst in ipairs(CollectionService:GetTagged(tag)) do
					takeId(inst)
				end
			end
		end)
		pcall(function()
			local map = Workspace:FindFirstChild("DeepsMap") or Workspace:FindFirstChild("Map")
			if map then
				local n = 0
				for _, d in ipairs(map:GetDescendants()) do
					n += 1
					if n > 400 then
						break
					end
					if d:IsA("ProximityPrompt") then
						local blob = string.lower(tostring(d.ActionText) .. tostring(d.Name))
						if blob:find("catch") or blob:find("fish") or blob:find("loot") or blob:find("pick") then
							takeId(d.Parent)
							if typeof(fireproximityprompt) == "function" then
								pcall(fireproximityprompt, d)
							end
						end
					end
				end
			end
		end)
		for id in pairs(ids) do
			fireRemote("DeepsCatchStart", id)
			fireRemote("DeepsCatchFinish", { Id = id, Success = true, Rejected = 0 })
		end
	end
	if CFG.AutoDeepsLoot then
		fireRemote("DeepsProcessLoot")
		fireRemote("DeepsPickupItem")
		fireRemote("DeepsWatchAdForLoot")
	end
end

local function eventsAuto()
	if CFG.AutoLuckyblock then
		fireRemote("OpenLuckyblock")
		fireRemote("ClaimLuckyblockFish")
	end
	if CFG.AutoEnchant then
		fireRemote("RequestEnchantRoll", { Method = "Gems", EnchantId = CFG.SelectedEnchant, ExtraGems = 0 })
		fireRemote("RequestEnchantRoll", { Method = "Stones", EnchantId = CFG.SelectedEnchant })
	end
	if CFG.AutoNpcTrade then
		fireRemote("NPCTradeRespond", { Accept = true })
		fireRemote("RequestNPCTradeOffer")
		fireRemote("RequestNPCTradeQueue")
	end
	if CFG.AutoCooking then
		fireRemote("CookingStartCook")
		fireRemote("CookingClaim")
	end
	if CFG.AutoMutation then
		fireRemote("StartMutationExtraction")
		fireRemote("ClaimMutationJar")
		fireRemote("ApplyMutationJar")
		fireRemote("ApplyLevelWorm")
	end
	if CFG.AutoAlchemy then
		fireRemote("RequestClaimAlchemyPotion")
		fireRemote("RequestInsertAlchemyFish")
	end
	if CFG.AutoWeather then
		fireRemote("RequestSummonWeather")
	end
	if CFG.AutoChest then
		fireRemote("ChestMinigameCompleted")
	end
	if CFG.AutoVault then
		fireRemote("RequestDepositAllVaultFish")
	end
	if CFG.AutoSellMin and CFG.AutoSellMin > 0 then
		fireRemote("SetAutoSellMinEarnings", CFG.AutoSellMin)
	end
end

local espFolder
local function clearEsp()
	if espFolder then
		pcall(function()
			espFolder:Destroy()
		end)
		espFolder = nil
	end
end

local function matchEsp(inst)
	local n = string.lower(inst.Name)
	if CFG.EspAirdrop and (n:find("airdrop") or n:find("crate") or n:find("supply")) then
		return Color3.fromRGB(255, 170, 0), "AIRDROP"
	end
	if CFG.EspNpc and (n:find("npc") or n:find("trade") or n:find("merchant")) then
		return Color3.fromRGB(80, 200, 255), "NPC"
	end
	if CFG.EspChest and (n:find("chest") or n:find("luckyblock") or n:find("lootbox")) then
		return Color3.fromRGB(255, 80, 180), "CHEST"
	end
	if CFG.EspFish and (n:find("fish") or n:find("boss") or n:find("beast")) then
		return Color3.fromRGB(80, 255, 120), "FISH"
	end
	return nil
end

local function refreshEsp()
	clearEsp()
	if not CFG.EspOn then
		return
	end
	espFolder = Instance.new("Folder")
	espFolder.Name = "LuckyFishESP"
	espFolder.Parent = LocalPlayer:FindFirstChild("PlayerGui") or Workspace
	local added = 0
	local function mark(inst)
		if added > 40 then
			return
		end
		if not inst:IsA("Model") and not inst:IsA("BasePart") then
			return
		end
		local color, label = matchEsp(inst)
		if not color then
			return
		end
		added += 1
		local adornee = inst
		if inst:IsA("Model") then
			adornee = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
		end
		if not adornee then
			return
		end
		local hl = Instance.new("Highlight")
		hl.Adornee = inst:IsA("Model") and inst or adornee
		hl.FillColor = color
		hl.OutlineColor = color
		hl.FillTransparency = 0.65
		hl.Parent = espFolder
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(80, 18)
		bb.AlwaysOnTop = true
		bb.Adornee = adornee
		bb.Parent = espFolder
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = label
		t.TextColor3 = color
		t.TextStrokeTransparency = 0.2
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = bb
	end
	pcall(function()
		for _, child in ipairs(Workspace:GetChildren()) do
			mark(child)
			local inner = 0
			if child:IsA("Folder") or child:IsA("Model") then
				for _, d in ipairs(child:GetChildren()) do
					inner += 1
					if inner > 80 then
						break
					end
					mark(d)
				end
			end
		end
	end)
end

local function applyInstant()
	if ThrowBar and typeof(ThrowBar.Config) == "table" and ORIG_BAR then
		if CFG.InstantBar then
			ThrowBar.Config.AutoThrowBarDuration = CFG.BarDuration
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
	if ThrowPacing and ORIG_PACE then
		if CFG.InstantPull then
			ThrowPacing.MinPullTime = 0.05
			ThrowPacing.DiveFallTime = 0.08
			ThrowPacing.RevealFlyTime = 0.08
			ThrowPacing.RevealGrowTime = 0.08
			ThrowPacing.RevealHoldTime = 0.05
			ThrowPacing.DisappearDelay = 0.02
			ThrowPacing.DisappearDuration = 0.05
			ThrowPacing.WallRiseDelay = 0.05
			ThrowPacing.WallRiseTweenTime = 0.05
		else
			ThrowPacing.MinPullTime = ORIG_PACE.MinPullTime
			ThrowPacing.DiveFallTime = ORIG_PACE.DiveFallTime
			ThrowPacing.RevealFlyTime = ORIG_PACE.RevealFlyTime
			ThrowPacing.RevealGrowTime = ORIG_PACE.RevealGrowTime
			ThrowPacing.RevealHoldTime = ORIG_PACE.RevealHoldTime
			ThrowPacing.DisappearDelay = ORIG_PACE.DisappearDelay
			ThrowPacing.DisappearDuration = ORIG_PACE.DisappearDuration
			ThrowPacing.WallRiseDelay = ORIG_PACE.WallRiseDelay
			ThrowPacing.WallRiseTweenTime = ORIG_PACE.WallRiseTweenTime
		end
		if CFG.InstantRoll then
			ThrowPacing.SpinDurationMin = 0.08
			ThrowPacing.SpinDurationMax = 0.12
		else
			ThrowPacing.SpinDurationMin = ORIG_PACE.SpinDurationMin
			ThrowPacing.SpinDurationMax = ORIG_PACE.SpinDurationMax
		end
	end
	applyThrowMult()
	applyPullSpoof()
end

local function restoreAll()
	if ThrowBar and typeof(ThrowBar.Config) == "table" and ORIG_BAR then
		ThrowBar.Config.AutoThrowBarDuration = ORIG_BAR.AutoThrowBarDuration
		ThrowBar.Config.AutoAccuracyMin = ORIG_BAR.AutoAccuracyMin
		ThrowBar.Config.AutoAccuracyMax = ORIG_BAR.AutoAccuracyMax
		ThrowBar.Config.BarCamTransitionTime = ORIG_BAR.BarCamTransitionTime
	end
	if ThrowPacing and ORIG_PACE then
		for k, v in pairs(ORIG_PACE) do
			ThrowPacing[k] = v
		end
	end
	pcall(function()
		LocalPlayer:SetAttribute("DebugThrowSpeedMult", nil)
	end)
	pcall(function()
		LocalPlayer:SetAttribute("RollSpeedMultiplier", nil)
	end)
	pcall(function()
		if store.origFishSpeed == nil then
			LocalPlayer:SetAttribute("FishingSpeedMultiplier", 1)
		else
			LocalPlayer:SetAttribute("FishingSpeedMultiplier", store.origFishSpeed)
		end
	end)
	pcall(function()
		LocalPlayer:SetAttribute("PullPowerMultiplier", store.origPullPower)
	end)
	if store.origGravity then
		Workspace.Gravity = store.origGravity
	end
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

if not store.hookedClick and typeof(calculateClickPower) == "function" and typeof(hookfunction) == "function" then
	store.origClick = hookfunction(calculateClickPower, function(...)
		local v = store.origClick(...)
		if typeof(v) ~= "number" then
			v = 1
		end
		local m = CFG.PullMult or 1
		if CFG.InstantPull then
			m = math.max(m, 8)
		end
		return v * m
	end)
	store.hookedClick = true
end

if not store.hookedRoll and RollSpeedMultiplier and typeof(RollSpeedMultiplier.GetMultiplier) == "function" and typeof(hookfunction) == "function" then
	store.origRollGet = hookfunction(RollSpeedMultiplier.GetMultiplier, function(a, b)
		local player = a
		if typeof(a) ~= "Instance" then
			player = b
		end
		if typeof(player) ~= "Instance" then
			player = LocalPlayer
		end
		local m = store.origRollGet(player)
		if typeof(m) ~= "number" then
			m = 1
		end
		local extra = CFG.RollMult or 1
		if CFG.InstantRoll then
			extra = math.max(extra, 10)
		end
		return m * extra
	end)
	store.hookedRoll = true
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
		return pcall(function()
			ThrowSystem:StartAutoFishing()
		end)
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
	return #names
end

local function findTrainingTool()
	local char, hum = charHum()
	local st = getState()
	local want = (st and st.trainingTool) or CFG.SelectedTool
	local function isTrainTool(t)
		if not t or not t:IsA("Tool") then
			return false
		end
		if t:GetAttribute("IsTrainingTool") then
			return true
		end
		return want ~= nil and t.Name == want
	end
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if isTrainTool(t) then
				return t, hum, char, true
			end
		end
	end
	local bp = LocalPlayer:FindFirstChild("Backpack")
	if bp then
		if typeof(want) == "string" then
			local named = bp:FindFirstChild(want)
			if named and named:IsA("Tool") then
				return named, hum, char, false
			end
		end
		for _, t in ipairs(bp:GetChildren()) do
			if isTrainTool(t) then
				return t, hum, char, false
			end
		end
	end
	return nil, hum, char, false
end

local function ensureTrainToolEquipped()
	local tool, hum = findTrainingTool()
	if not tool then
		local st = getState()
		local id = (st and st.trainingTool) or CFG.SelectedTool
		if id then
			fireRemote("EquipTrainingTool", id)
			task.wait(0.15)
			tool, hum = findTrainingTool()
		end
	end
	if not tool or not hum then
		return false
	end
	if tool.Parent ~= LocalPlayer.Character then
		pcall(function()
			hum:EquipTool(tool)
		end)
		task.wait(0.05)
	end
	return tool.Parent == LocalPlayer.Character
end

local function trainReady()
	local char = LocalPlayer.Character
	if not char then
		return false, 0.05
	end
	local last = char:GetAttribute("LastTrained")
	if typeof(last) ~= "number" then
		return true, 0
	end
	local remain = last - workspace:GetServerTimeNow()
	if remain <= 0 then
		return true, 0
	end
	return false, math.clamp(remain, 0.02, 1)
end

local function trainOnce()
	if not ensureTrainToolEquipped() then
		return false
	end
	local ready = trainReady()
	if not ready then
		return false
	end
	return fireRemote("Train")
end

local function wantClickBonus()
	return CFG.AutoClickBonus or CFG.AutoTrain
end

local function claimClickBonus(id)
	if typeof(id) ~= "string" or id == "" then
		return false
	end
	store.lastClickBonusId = id
	return fireRemote("ClaimClickBonus", id)
end

local function fireGuiButton(btn)
	if not btn or not btn:IsA("GuiButton") then
		return false
	end
	local fired = false
	if typeof(getconnections) == "function" then
		for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
			local sig = btn[sigName]
			if typeof(sig) == "RBXScriptSignal" then
				local ok, cons = pcall(getconnections, sig)
				if ok and typeof(cons) == "table" then
					for _, c in ipairs(cons) do
						if typeof(c) == "table" then
							if typeof(c.Function) == "function" then
								pcall(c.Function)
								fired = true
							elseif typeof(c.Fire) == "function" then
								pcall(function()
									c:Fire()
								end)
								fired = true
							end
						end
					end
				end
			end
		end
	end
	return fired
end

local function clickBonusButtons()
	if not wantClickBonus() then
		return
	end
	if store.lastClickBonusId then
		claimClickBonus(store.lastClickBonusId)
	end
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local main = gui and gui:FindFirstChild("MainUI")
	if not main then
		return
	end
	for _, name in ipairs({ "ClickBonus", "ClickBonusExtra" }) do
		local btn = main:FindFirstChild(name)
		if btn and btn:IsA("GuiObject") and btn.Visible then
			fireGuiButton(btn)
			for _, child in ipairs(btn:GetDescendants()) do
				if child:IsA("GuiButton") then
					fireGuiButton(child)
				end
			end
		end
	end
end

if Remotes and Remotes.ShowClickBonus and typeof(Remotes.ShowClickBonus.On) == "function" then
	local disc
	pcall(function()
		disc = Remotes.ShowClickBonus:On(function(payload)
			if typeof(payload) ~= "table" then
				return
			end
			local id = payload.id
			if typeof(id) == "string" then
				store.lastClickBonusId = id
				if wantClickBonus() then
					claimClickBonus(id)
					task.defer(clickBonusButtons)
				end
			end
		end)
	end)
	if disc ~= nil then
		STATE.onCleanup(function()
			pcall(function()
				if typeof(disc) == "function" then
					disc()
				elseif typeof(disc) == "table" then
					if typeof(disc.Disconnect) == "function" then
						disc:Disconnect()
					elseif typeof(disc.disconnect) == "function" then
						disc:disconnect()
					end
				end
			end)
		end)
	end
end

do
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local main = gui and gui:FindFirstChild("MainUI")
	if main then
		STATE.connect(main.ChildAdded, function(child)
			if not wantClickBonus() then
				return
			end
			if child.Name == "ClickBonus" or child.Name == "ClickBonusExtra" then
				task.wait(0.03)
				if store.lastClickBonusId then
					claimClickBonus(store.lastClickBonusId)
				end
				fireGuiButton(child)
			end
		end)
	end
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
	if store.lastClickBonusId then
		claimClickBonus(store.lastClickBonusId)
	end
	clickBonusButtons()
	fireRemote("FriendBoostRecalculate")
	local st = getState()
	if st and typeof(st.quests) == "table" and typeof(st.quests.Active) == "table" then
		for id, data in pairs(st.quests.Active) do
			if typeof(data) == "table" and data.Done then
				fireRemote("RequestClaimQuest", id)
			else
				fireRemote("RequestClaimQuest", id)
			end
		end
	end
	if st and typeof(st.quests) == "table" and typeof(st.quests.Milestones) == "table" then
		for id in pairs(st.quests.Milestones) do
			fireRemote("RequestClaimQuestMilestone", id)
		end
	end
	if st and typeof(st.index) == "table" then
		for id in pairs(st.index) do
			fireRemote("RequestClaimIndexReward", id)
			fireRemote("RequestClaimIndexMilestone", id)
		end
	end
	if st and typeof(st.milestones) == "table" then
		for id in pairs(st.milestones) do
			fireRemote("RequestClaimMilestone", id)
		end
	end
	fireRemote("RequestClaimIndexReward")
	fireRemote("RequestClaimIndexMilestone")
	fireRemote("RequestClaimMilestone")
	fireRemote("RequestClaimQuestMilestone")
	fireRemote("RequestClaimAlchemyPotion")
end

local function upgradeOnce()
	fireRemote("RequestUpgradeThrowSpeed")
	fireRemote("RequestUpgradePullSpeed")
	fireRemote("RequestUpgradeRollSpeed")
end

local function upgradeBurst()
	local n = math.clamp(CFG.UpgradeBurst or 5, 1, 25)
	for _ = 1, n do
		upgradeOnce()
	end
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

local function applyGravity()
	if CFG.GravityOn then
		Workspace.Gravity = CFG.Gravity
	elseif store.origGravity then
		Workspace.Gravity = store.origGravity
	end
end

local function applyZoom()
	if CFG.ZoomUnlock then
		pcall(function()
			LocalPlayer.CameraMaxZoomDistance = 9999
		end)
	end
end

local function clickPull()
	if typeof(mouse1click) == "function" then
		pcall(mouse1click)
	end
end

local function tpTo(cf)
	local _, _, hrp = charHum()
	if hrp and typeof(cf) == "CFrame" then
		hrp.CFrame = cf + Vector3.new(0, 4, 0)
		return true
	end
	return false
end

local function tpThrowZone()
	local map = Workspace:FindFirstChild("Map")
	local sp = map and map:FindFirstChild("StartPointFish")
	if sp and sp:IsA("BasePart") then
		return tpTo(sp.CFrame)
	end
	if ThrowSystem and ThrowSystem.IsInThrowZone then
		local tagged = Workspace:FindFirstChild("ThrowZone") or (map and map:FindFirstChild("ThrowZone"))
		if tagged and tagged:IsA("BasePart") then
			return tpTo(tagged.CFrame)
		end
	end
	return false
end

local function listRods()
	local names = {}
	local map = {}
	if typeof(FishRodConfig) == "table" then
		for id, cfg in pairs(FishRodConfig) do
			if typeof(cfg) == "table" then
				local label = (cfg.DisplayName or id) .. " [" .. tostring(id) .. "]"
				table.insert(names, label)
				map[label] = id
			end
		end
		table.sort(names)
	end
	return names, map
end

local function listTools()
	local names = {}
	local map = {}
	if typeof(TrainToolConfig) == "table" then
		for id, cfg in pairs(TrainToolConfig) do
			if typeof(cfg) == "table" then
				local label = (cfg.DisplayName or id) .. " [" .. tostring(id) .. "]"
				table.insert(names, label)
				map[label] = id
			end
		end
		table.sort(names)
	end
	return names, map
end

local function listPotions()
	local names = {}
	local pots = PotionConfig and PotionConfig.Potions
	if typeof(pots) == "table" then
		for id, cfg in pairs(pots) do
			local label = typeof(cfg) == "table" and (cfg.DisplayName or id) or id
			table.insert(names, tostring(label) .. " [" .. tostring(id) .. "]")
		end
		table.sort(names)
	end
	return names
end

local function listEnchants()
	local names = {}
	local map = {}
	local list = EnchantConfig and (EnchantConfig.List or EnchantConfig.Enchants)
	if typeof(list) == "table" then
		for _, cfg in pairs(list) do
			if typeof(cfg) == "table" then
				local id = cfg.Id or cfg.Name
				local label = (cfg.DisplayName or id) .. " [" .. tostring(id) .. "]"
				table.insert(names, label)
				map[label] = id
			end
		end
		table.sort(names)
	end
	return names, map
end

local function listFloats()
	local names = {}
	local map = {}
	local floats = FishingFloatsConfig and FishingFloatsConfig.Floats
	if typeof(floats) == "table" then
		for id, cfg in pairs(floats) do
			if typeof(cfg) == "table" then
				local label = (cfg.DisplayName or id) .. " [" .. tostring(cfg.Effect or id) .. "]"
				table.insert(names, label)
				map[label] = id
			end
		end
		table.sort(names)
	end
	return names, map
end

local function listMounts()
	local names = {}
	local map = {}
	if typeof(MountConfig) == "table" then
		for id, cfg in pairs(MountConfig) do
			if typeof(cfg) == "table" then
				local label = (cfg.DisplayName or id) .. " [" .. tostring(id) .. "]"
				table.insert(names, label)
				map[label] = id
			end
		end
		table.sort(names)
	end
	return names, map
end

local function listGear(slotTbl)
	local names = {}
	local map = {}
	if typeof(slotTbl) == "table" then
		for id, cfg in pairs(slotTbl) do
			if typeof(cfg) == "table" then
				local label = (cfg.DisplayName or id) .. " [" .. tostring(id) .. "]"
				table.insert(names, label)
				map[label] = id
			end
		end
		table.sort(names)
	end
	return names, map
end

local MULT_VALUES = { "x1", "x2", "x3", "x4", "x6", "x10", "x25", "x50", "x100", "x250", "x500", "x1000" }
local MULT_MAP = {
	x1 = 1,
	x2 = 2,
	x3 = 3,
	x4 = 4,
	x6 = 6,
	x10 = 10,
	x25 = 25,
	x50 = 50,
	x100 = 100,
	x250 = 250,
	x500 = 500,
	x1000 = 1000,
}

local function multLabel(n)
	for label, v in pairs(MULT_MAP) do
		if v == n then
			return label
		end
	end
	return "x1"
end

local function statusText()
	local st = getState()
	local money = st and st.money or "?"
	local gems = st and st.gems or "?"
	local str = st and st.strength or "?"
	local rod = st and st.fishRod or "?"
	local world = st and st.currentWorldId or "?"
	local rebirth = st and st.rebirthLevel or "?"
	local inZone = false
	local auto = false
	pcall(function()
		inZone = ThrowSystem and ThrowSystem.IsInThrowZone and ThrowSystem.IsInThrowZone()
	end)
	pcall(function()
		auto = ThrowSystem and ThrowSystem.IsAutoFishing and ThrowSystem:IsAutoFishing()
	end)
	return string.format(
		"cash %s  gems %s  str %s  rb %s\nfish %d/%d  rod %s  world %s\nzone %s  auto %s  throw x%s  pull x%s  power x%s  roll x%s",
		tostring(money),
		tostring(gems),
		tostring(str),
		tostring(rebirth),
		fishCount(),
		fishLimit(),
		tostring(rod),
		tostring(world),
		inZone and "yes" or "no",
		auto and "on" or "off",
		tostring(CFG.ThrowMult),
		tostring(CFG.PullMult),
		tostring(CFG.PullPowerMult or 1),
		tostring(CFG.RollMult)
	)
end

applyInstant()
applyFps()
applyZoom()

task.spawn(function()
	while STATE.alive() do
		applyInstant()
		if CFG.AutoFarm and not CFG.AutoTrain then
			local auto = false
			pcall(function()
				auto = ThrowSystem and ThrowSystem:IsAutoFishing()
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
		task.wait(CFG.FarmDelay or 0.6)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoSell and fishCount() >= 8 then
			sellAll()
		end
		if CFG.AutoCollect then
			collectAllCash()
		end
		if CFG.AutoPlace then
			placeFish()
		end
		if CFG.AutoUpgrade then
			upgradeOnce()
		end
		autoUpdateTools()
		eventsAuto()
		deepsAuto()
		applyOxygen()
		if CFG.EspOn then
			refreshEsp()
		else
			clearEsp()
		end
		task.wait(CFG.CollectDelay or 1.1)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoTrain then
			if ensureTrainToolEquipped() then
				local ready, waitFor = trainReady()
				if ready then
					fireRemote("Train")
					task.wait(CFG.TrainDelay or 0.15)
				else
					task.wait(waitFor)
				end
			else
				task.wait(0.4)
			end
		else
			task.wait(CFG.TrainDelay or 0.15)
		end
		if wantClickBonus() then
			clickBonusButtons()
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		if wantClickBonus() then
			clickBonusButtons()
			task.wait(0.05)
		else
			task.wait(0.2)
		end
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
		if CFG.GravityOn then
			applyGravity()
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoFarm or CFG.InstantPull or CFG.AutoClick then
			local gui = LocalPlayer:FindFirstChild("PlayerGui")
			local main = gui and gui:FindFirstChild("MainUI")
			local throwFrame = main and main:FindFirstChild("ThrowFrame")
			local meter = throwFrame and throwFrame:FindFirstChild("SpeedMeter")
			if meter and meter.Visible then
				clickPull()
			end
		end
		task.wait(0.04)
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
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
end)

STATE.connect(RunService.Heartbeat, function(dt)
	if not CFG.Fly then
		return
	end
	local _, hum, hrp = charHum()
	if not hrp then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
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
		dir += Vector3.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		dir -= Vector3.yAxis
	end
	if dir.Magnitude > 0 then
		dir = dir.Unit
	end
	hrp.AssemblyLinearVelocity = dir * CFG.FlySpeed
	if hum then
		hum.PlatformStand = true
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
	if not STATE.alive() then
		return
	end
	applyWalkSpeed()
	applyThrowMult()
	applyPullSpoof()
end)

STATE.onCleanup(function()
	restoreAll()
	pcall(function()
		if ThrowSystem then
			ThrowSystem:SetFakeAutoFishing(false)
		end
	end)
	if not CFG.AutoFarm then
		stopFarm()
	end
	local _, hum = charHum()
	if hum then
		hum.PlatformStand = false
	end
	if store.origThrowWithForce and typeof(restorefunction) == "function" then
		pcall(restorefunction, ThrowSystem.ThrowWithForce)
		store.hookedThrow = false
	end
	if store.origClick and typeof(restorefunction) == "function" and typeof(calculateClickPower) == "function" then
		pcall(restorefunction, calculateClickPower)
		store.hookedClick = false
	end
	if store.origRollGet and typeof(restorefunction) == "function" and RollSpeedMultiplier then
		pcall(restorefunction, RollSpeedMultiplier.GetMultiplier)
		store.hookedRoll = false
	end
	if store.origOxygen and typeof(restorefunction) == "function" and DeepsGearConfig then
		pcall(restorefunction, DeepsGearConfig.GetOxygenSeconds)
		store.hookedOxygen = false
	end
	clearEsp()
	stripFakeAttrs()
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "Lucky Fish Hub",
	Author = "farm · train · shop",
	Folder = "LuckyFishHub",
	Icon = "fish",
	NewElements = true,
	Size = UDim2.fromOffset(520, 480),
	HideSearchBar = true,
	OpenButton = {
		Title = "Lucky Fish",
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

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")
local Purple = Color3.fromHex("#9B59B6")
local Cyan = Color3.fromHex("#1ABC9C")

local rodNames, rodMap = listRods()
local toolNames, toolMap = listTools()
local enchantNames, enchantMap = listEnchants()
local floatNames, floatMap = listFloats()
local mountNames, mountMap = listMounts()
local tankNames, tankMap = listGear(DeepsGearConfig and DeepsGearConfig.OxygenTanks)
local finNames, finMap = listGear(DeepsGearConfig and DeepsGearConfig.Fins)
local bagNames, bagMap = listGear(DeepsGearConfig and DeepsGearConfig.LootBags)
local TIER_VALUES = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Godly" }

local function ui(tab)
	local api = {}

	function api.head(title)
		pcall(function()
			tab:Section({ Title = title, TextSize = 16 })
		end)
		return api
	end

	function api.toggle(key, title, onChange)
		tab:Toggle({
			Title = title,
			Value = CFG[key],
			Callback = function(v)
				CFG[key] = v
				if onChange then
					onChange(v)
				end
			end,
		})
		return api
	end

	function api.slider(key, title, min, max, onChange)
		tab:Slider({
			Title = title,
			Value = { Min = min, Max = max, Default = math.clamp(tonumber(CFG[key]) or min, min, max) },
			Callback = function(v)
				CFG[key] = v
				if onChange then
					onChange(v)
				end
			end,
		})
		return api
	end

	function api.drop(title, values, current, onPick)
		if typeof(values) ~= "table" or #values == 0 then
			return api
		end
		tab:Dropdown({
			Title = title,
			Values = values,
			Value = current,
			Callback = onPick,
		})
		return api
	end

	function api.pick(title, names, map, key)
		return api.drop(title, names, nil, function(label)
			CFG[key] = map[label] or CFG[key]
		end)
	end

	function api.btn(title, fn, icon)
		tab:Button({
			Title = title,
			Icon = icon,
			Callback = fn,
		})
		return api
	end

	function api.input(title, key, placeholder)
		tab:Input({
			Title = title,
			Placeholder = placeholder or "",
			Callback = function(v)
				CFG[key] = v
			end,
		})
		return api
	end

	function api.fire(title, name, ...)
		local args = { ... }
		return api.btn(title, function()
			fireRemote(name, table.unpack(args))
		end)
	end

	return api
end

local function tab(section, title, icon, color)
	local t = section:Tab({ Title = title, Icon = icon, IconColor = color })
	task.wait()
	return ui(t), t
end

local Hub = Window:Section({ Title = "Hub", Opened = true })

do
	local u, t = tab(Hub, "Home", "house", Green)
	local para = t:Paragraph({ Title = "Status", Desc = statusText() })
	u.toggle("Silent", "Silent")
		.toggle("AntiAfk", "Anti AFK")
		.toggle("FpsUnlock", "Unlock FPS", applyFps)
		.btn("Refresh", function()
			if para and para.SetDesc then
				para:SetDesc(statusText())
			end
		end, "refresh-cw")
		.btn("Claim All", function()
			claimAll()
			notify("Claims", "sent")
		end, "gift")
		.btn("Copy Status", function()
			if typeof(setclipboard) == "function" then
				setclipboard(statusText())
			end
		end, "clipboard")
end

do
	local u = tab(Hub, "Farm", "fish", Blue)
	u.toggle("AutoFarm", "Auto Farm", function(on)
		if on then
			local ok = startFarm()
			notify("Farm", ok and "started" or "wait — stand in zone")
		else
			stopFarm()
		end
	end)
		.toggle("InstantBar", "Instant Throw Bar", applyInstant)
		.toggle("PerfectThrow", "Perfect Throw", applyInstant)
		.toggle("InstantPull", "Instant Pull", applyInstant)
		.toggle("InstantRoll", "Instant Roll", applyInstant)
		.toggle("AutoClick", "Auto Click Pull")
		.toggle("AutoSell", "Auto Sell")
		.slider("FarmDelay", "Recheck Delay", 0.2, 2)
		.btn("Instant All", function()
			CFG.InstantBar, CFG.PerfectThrow, CFG.InstantPull, CFG.InstantRoll = true, true, true, true
			CFG.ThrowMult, CFG.PullMult, CFG.PullPowerMult, CFG.RollMult = 1000, 1000, 1000, 1000
			applyInstant()
			notify("Farm", "instant + x1000")
		end, "zap")
		.btn("Sell All", sellAll, "coins")
		.btn("Throw Once", function()
			applyInstant()
			pcall(function()
				ThrowSystem:ThrowingSegment(true)
			end)
		end, "target")
		.btn("Recover Throw", function()
			pcall(function()
				ThrowSystem:RecoverThrow()
			end)
		end)
end

do
	local u = tab(Hub, "Train", "dumbbell", Cyan)
	u.toggle("AutoTrain", "Auto Train", function(on)
		if on then
			ensureTrainToolEquipped()
			trainOnce()
		end
	end)
		.toggle("AutoClickBonus", "Auto Click x2")
		.toggle("AutoUpdateTools", "Auto Upgrade Tool", function(on)
			if on then
				autoUpdateTools()
			end
		end)
		.slider("TrainDelay", "Train Delay", 0.05, 1)
		.drop("Pull Power", MULT_VALUES, multLabel(CFG.PullPowerMult), function(v)
			CFG.PullPowerMult = MULT_MAP[v] or 1
			applyPullSpoof()
		end)
		.slider("PullPowerMult", "Pull Power x", 1, 1000, applyPullSpoof)
		.pick("Tool", toolNames, toolMap, "SelectedTool")
		.btn("Train Once", function()
			notify("Train", trainOnce() and "fired" or "need dumbbell / cooldown")
		end)
		.btn("Buy Tool", function()
			fireRemote("BuyTrainingTool", CFG.SelectedTool)
		end)
		.btn("Equip Tool", function()
			fireRemote("EquipTrainingTool", CFG.SelectedTool)
			ensureTrainToolEquipped()
		end)
end

do
	local u = tab(Hub, "Money", "banknote", Yellow)
	u.toggle("AutoCollect", "Auto Collect", function(on)
		if on then
			collectAllCash()
		end
	end)
		.toggle("AutoPlace", "Auto Place")
		.toggle("AutoUpgrade", "Auto Upgrade Speeds")
		.toggle("AutoEquipBest", "Auto Equip Best", function(on)
			if on then
				store.lastEquipBest = 0
				equipBestNow()
			end
		end)
		.drop("Equip Best Mode", { "BestNow", "BestPossible", "BestFlat" }, CFG.EquipBestMode, function(v)
			CFG.EquipBestMode = v
		end)
		.slider("CollectDelay", "Loop Delay", 0.3, 3)
		.slider("UpgradeBurst", "Upgrade Burst", 1, 25)
		.btn("Collect Now", function()
			notify("Collect", tostring(collectAllCash()) .. " slots")
		end, "hand-coins")
		.btn("Place Now", function()
			notify("Place", tostring(placeFish()) .. " placed")
		end)
		.btn("Upgrade Burst", upgradeBurst)
		.fire("Rebirth", "RequestRebirth")
		.btn("Equip Best Now", function()
			store.lastEquipBest = 0
			notify("Best", equipBestNow() and CFG.EquipBestMode or "cooldown")
		end)
		.fire("Buy Auto-Sell", "BuyAutoSellWithGems")
		.fire("Buy Slot", "BuyFishingSlot")
		.fire("Buy Slot (gems)", "BuyFishingSlotWithGems")
		.fire("Use Auto Collect", "RequestUseAutoCollect")
		.fire("Slot Upgrade", "RequestBuySlotUpgrade")
end

do
	local u = tab(Hub, "Shop", "store", Blue)
	u.toggle("AutoUpdateRods", "Auto Upgrade Rod", function(on)
		if on then
			autoUpdateTools()
		end
	end)
		.pick("Rod", rodNames, rodMap, "SelectedRod")
		.btn("Buy Rod", function()
			fireRemote("BuyFishRod", CFG.SelectedRod)
		end)
		.btn("Equip Rod", function()
			fireRemote("EquipFishRod", CFG.SelectedRod)
		end)
		.pick("Float", floatNames, floatMap, "SelectedFloat")
		.drop("Float Tier", TIER_VALUES, CFG.SelectedFloatTier, function(v)
			CFG.SelectedFloatTier = v
		end)
		.slider("FloatSlot", "Float Slot", 1, 5)
		.btn("Equip Float", function()
			fireRemote("EquipFishingFloat", {
				FloatName = CFG.SelectedFloat,
				Tier = CFG.SelectedFloatTier,
				Slot = CFG.FloatSlot,
			})
		end)
		.btn("Unequip Float", function()
			fireRemote("UnequipFishingFloat", CFG.FloatSlot)
		end)
		.pick("Mount", mountNames, mountMap, "SelectedMount")
		.btn("Equip Mount", function()
			fireRemote("RequestEquipMount", CFG.SelectedMount)
			fireRemote("RequestToggleMount")
		end)
		.fire("Use Potion", "RequestUsePotion")
		.input("Promo Code", "PromoCode", "code")
		.btn("Redeem Code", function()
			if CFG.PromoCode ~= "" then
				fireRemote("RequestCodeRedeem", CFG.PromoCode)
			end
		end)
end

do
	local u = tab(Hub, "Speed", "gauge", Yellow)
	local function setAll(n)
		CFG.ThrowMult, CFG.PullMult, CFG.PullPowerMult, CFG.RollMult = n, n, n, n
		applyThrowMult()
		applyPullSpoof()
	end
	u.drop("Throw Speed", MULT_VALUES, multLabel(CFG.ThrowMult), function(v)
		CFG.ThrowMult = MULT_MAP[v] or 1
		applyThrowMult()
	end)
		.slider("ThrowMult", "Throw Custom", 1, 1000, applyThrowMult)
		.drop("Pull Speed", MULT_VALUES, multLabel(CFG.PullMult), function(v)
			CFG.PullMult = MULT_MAP[v] or 1
			applyPullSpoof()
		end)
		.slider("PullMult", "Pull Custom", 1, 1000, applyPullSpoof)
		.drop("Roll Speed", MULT_VALUES, multLabel(CFG.RollMult), function(v)
			CFG.RollMult = MULT_MAP[v] or 1
		end)
		.slider("RollMult", "Roll Custom", 1, 1000)
		.drop("Set All", MULT_VALUES, "x1", function(v)
			setAll(MULT_MAP[v] or 1)
		end)
		.slider("BarDuration", "Throw Bar Duration", 0.01, 1.5, applyInstant)
		.btn("Reset x1", function()
			setAll(1)
		end)
end

do
	local u = tab(Hub, "Player", "user", Red)
	u.toggle("WalkSpeedOn", "WalkSpeed", applyWalkSpeed)
		.slider("WalkSpeed", "WalkSpeed Value", 16, 1000, applyWalkSpeed)
		.toggle("JumpOn", "JumpPower", applyWalkSpeed)
		.slider("JumpPower", "JumpPower Value", 50, 1000, applyWalkSpeed)
		.toggle("InfJump", "Inf Jump")
		.toggle("Noclip", "Noclip")
		.toggle("Fly", "Fly", function(on)
			local _, hum = charHum()
			if hum and not on then
				hum.PlatformStand = false
			end
		end)
		.slider("FlySpeed", "Fly Speed", 20, 1000)
		.toggle("Fullbright", "Fullbright", applyFullbright)
		.toggle("GravityOn", "Custom Gravity", applyGravity)
		.slider("Gravity", "Gravity", 0, 196, applyGravity)
		.toggle("ZoomUnlock", "Unlock Zoom", applyZoom)
		.btn("Reset Character", function()
			local _, hum = charHum()
			if hum then
				hum.Health = 0
			end
		end)
end

do
	local u = tab(Hub, "World", "globe", Cyan)
	u.btn("TP Throw Zone", function()
		notify("TP", tpThrowZone() and "zone" or "missing")
	end, "map-pin")
		.fire("World 1", "TravelToWorld", 1)
		.fire("World 2", "TravelToWorld", 2)
		.fire("Unlock World 2", "UnlockWorld", 2)
		.fire("Unlock Village", "UnlockFishingVillage")
end

do
	local u = tab(Hub, "More", "sparkles", Purple)
	u.head("Events")
		.toggle("AutoLuckyblock", "Luckyblock")
		.toggle("AutoEnchant", "Enchant Roll")
		.toggle("AutoNpcTrade", "NPC Trade Accept")
		.toggle("AutoCooking", "Cooking")
		.toggle("AutoMutation", "Mutation / Worm")
		.toggle("AutoAlchemy", "Alchemy")
		.toggle("AutoWeather", "Weather")
		.toggle("AutoChest", "Chest Complete")
		.toggle("AutoVault", "Vault Deposit")
		.slider("AutoSellMin", "Auto-Sell Min $", 0, 1000000, function(v)
			fireRemote("SetAutoSellMinEarnings", v)
		end)
		.pick("Enchant", enchantNames, enchantMap, "SelectedEnchant")
		.btn("Enchant Once", function()
			fireRemote("RequestEnchantRoll", { Method = "Gems", EnchantId = CFG.SelectedEnchant, ExtraGems = 0 })
		end)
		.fire("Garden Drill", "RequestClaimGardenDrill")
		.fire("Upgrade Fish", "RequestUpgradeFish")
		.btn("Alien Catch", function()
			fireRemote("AlienCatchStart")
			fireRemote("AlienCatchFinish")
			fireRemote("AlienCollectFuel")
		end)
		.btn("Lootbox", function()
			fireRemote("SkipFloatLootboxTimer")
			fireRemote("OpenFloatLootbox")
			fireRemote("ClaimFloatLootboxReward")
		end)

	u.head("Deeps")
		.toggle("InfOxygen", "Inf Oxygen", applyOxygen)
		.toggle("AutoDeepsCatch", "Auto Catch")
		.toggle("AutoDeepsLoot", "Auto Loot")
		.pick("Tank", tankNames, tankMap, "SelectedTank")
		.pick("Fins", finNames, finMap, "SelectedFins")
		.pick("Bag", bagNames, bagMap, "SelectedBag")
		.btn("Buy + Equip Gear", function()
			if CFG.SelectedTank then
				fireRemote("BuyDeepsGear", { Slot = "tank", Name = CFG.SelectedTank })
				fireRemote("EquipDeepsGear", { Slot = "tank", Name = CFG.SelectedTank })
			end
			if CFG.SelectedFins then
				fireRemote("BuyDeepsGear", { Slot = "fins", Name = CFG.SelectedFins })
				fireRemote("EquipDeepsGear", { Slot = "fins", Name = CFG.SelectedFins })
			end
			if CFG.SelectedBag then
				fireRemote("BuyDeepsGear", { Slot = "bag", Name = CFG.SelectedBag })
				fireRemote("EquipDeepsGear", { Slot = "bag", Name = CFG.SelectedBag })
			end
		end)
		.fire("Process Loot", "DeepsProcessLoot")

	u.head("ESP")
		.toggle("EspOn", "ESP", function(on)
			if on then
				refreshEsp()
			else
				clearEsp()
			end
		end)
		.toggle("EspFish", "Fish / Boss")
		.toggle("EspAirdrop", "Airdrop")
		.toggle("EspNpc", "NPC")
		.toggle("EspChest", "Chest")

	u.head("Misc")
		.fire("Skip Quest", "RequestSkipQuest")
		.btn("Skip Tutorial", function()
			for i = 1, 20 do
				fireRemote("MarkTutorialStepCompletion", i)
			end
		end)
		.fire("Base Skin", "RequestClaimBaseSkin")
		.fire("Weather", "RequestSummonWeather")
end

print("[LuckyFishHub] v4 loaded")

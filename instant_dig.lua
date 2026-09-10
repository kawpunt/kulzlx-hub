--[[
  Dig & Clean hub — hunt, sell, luck, plot, ESP, AFK, stats.
  Keys: F dig · G autodig · C clean · V autoclean · H background clean · B best gear · T/Y island
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local CFG_PATH = "instant_dig_cfg.json"
local CFG = {
	Enabled = false,
	AutoDig = false,
	MaxLuck = false,
	RangeMult = 1,
	CleanEnabled = false,
	AutoClean = false,
	HuntTrails = false,
	MinRarity = "legendary",
	RarityMode = "min",
	TweenSpeed = 95,
	PatrolRadius = 62,
	EdgeInset = 14,
	HideClan = false,
	BackgroundClean = false,
	AutoBestGear = false,
	PreferHorus = false,
	TweenToHole = false,
	RandomEdge = false,
	WaterRescue = false,
	ZoneDebug = false,
	PauseNearPlayers = false,
	NearbyRadius = 42,
	RequireHeldDetector = false,
	ReholdDetector = false,
	MinItemSize = 0,
	StopAfterDigs = 0,
	StopAfterMinutes = 0,
	StopWhenFull = false,
	HopNoFindMinutes = 0,
	FarmWeather = false,
	WeatherHop = false,
	RejoinJob = false,
	IslandRarityAuto = false,
	AutoSell = false,
	SellBelow = "legendary",
	SellDirty = false,
	SellWhenFull = false,
	KeepMutations = true,
	KeepNewIndex = true,
	KeepOneEach = false,
	MinKeepValue = 0,
	AutoFavorite = false,
	TpSellAndReturn = false,
	AutoCodes = false,
	AutoQuests = false,
	AutoGroupLuck = false,
	AutoAdLuck = false,
	MinLuckToDig = 0,
	MaxLuckOnlyWithBuff = false,
	AutoBuyShovel = false,
	AutoBuyDetector = false,
	AutoBuySpray = false,
	AutoUnlockIsland = false,
	AutoPlot = false,
	AutoPedestal = false,
	AutoForge = false,
	WellGold = 0,
	AntiAfk = false,
	AfkReturn = false,
	WalkSpeed = 0,
	NoclipTween = false,
	Fullbright = false,
	HidePlayers = false,
	MuteSpam = false,
	HidePopups = false,
	SkipTutorial = false,
	LowPlayerHop = false,
	LowPlayerMax = 8,
	HoleESP = false,
	PlayerESP = false,
	NpcESP = false,
	BoundsESP = false,
	MutationESP = false,
	StatsHud = false,
	Webhook = "",
	WebhookRares = false,
	WebhookHourly = false,
	Humanized = false,
	ToggleKey = Enum.KeyCode.F,
	AutoDigKey = Enum.KeyCode.G,
	CleanKey = Enum.KeyCode.C,
	AutoCleanKey = Enum.KeyCode.V,
	HideClanKey = Enum.KeyCode.H,
	BestGearKey = Enum.KeyCode.B,
	NextIslandKey = Enum.KeyCode.T,
	PrevIslandKey = Enum.KeyCode.Y,
}

local ISLAND_RARITY = {
	starterIsland = "legendary",
	island2 = "legendary",
	island3 = "legendary",
	island4 = "legendary",
	island5 = "legendary",
	island6 = "legendary",
	island7 = "anomaly",
}

local KNOWN_CODES = {
	"UPDATE1",
	"UPDATE2",
	"UPDATE3",
	"UPDATE4",
	"SECRET10",
	"RELEASE",
	"LUCK",
	"DIG",
	"CLEAN",
	"DIGCLEAN",
	"HORUS",
	"TOMBSTONE",
}

local WEBHOOK_RARITIES = {
	mythic = true,
	divine = true,
	eternal = true,
	transcendent = true,
	omega = true,
	anomaly = true,
	paradox = true,
	singularity = true,
	genesis = true,
}

local function genv()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local function hasConnect(s)
	return typeof(s) == "table" and typeof(s.connect) == "function"
end

local foundState
do
	local ok, value = pcall(function()
		return STATE
	end)
	if ok and hasConnect(value) then
		foundState = value
	end
	if not foundState then
		for _, level in ipairs({ 1, 0, 2 }) do
			local eok, env = pcall(getfenv, level)
			if eok and typeof(env) == "table" and hasConnect(env.STATE) then
				foundState = env.STATE
				break
			end
		end
	end
end

if not foundState then
	local g = genv()
	if typeof(g.__InstantDigKill) == "function" then
		pcall(g.__InstantDigKill)
	end
	local conns = {}
	local cleanups = {}
	foundState = {
		store = (typeof(g.__InstantDigStore) == "table" and g.__InstantDigStore) or {},
		connect = function(signal, fn)
			local conn = signal:Connect(fn)
			table.insert(conns, conn)
			return conn
		end,
		alive = function()
			return true
		end,
		onCleanup = function(fn)
			if typeof(fn) == "function" then
				table.insert(cleanups, fn)
			end
		end,
	}
	g.__InstantDigStore = foundState.store
	g.__InstantDigKill = function()
		for i = #cleanups, 1, -1 do
			pcall(cleanups[i])
		end
		table.clear(cleanups)
		for _, conn in ipairs(conns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(conns)
	end
end

local STATE = foundState
if not STATE.store then
	STATE.store = {}
end
local store = STATE.store
store.lastAuto = store.lastAuto or 0
store.lastNotify = store.lastNotify or 0
store.lastAutoClean = store.lastAutoClean or 0
store.bgCleaning = false
store.skipAt = store.skipAt or 0
store.stuckCleanAt = store.stuckCleanAt or 0
store.bootAt = os.clock()
store.digEndedAt = store.digEndedAt or 0
store.hadDig = store.hadDig or false
store.lastHide = store.lastHide or 0
store.lastGear = store.lastGear or 0
store.tweening = false
store.traveling = false
store.islandIndex = store.islandIndex or 0
store.patrolIndex = store.patrolIndex or 0
store.huntIslandId = store.huntIslandId or nil
store.sessionStart = store.sessionStart or os.clock()
store.sessionDigs = store.sessionDigs or 0
store.sessionGold0 = store.sessionGold0 or nil
store.dropLog = store.dropLog or {}
store.lastFindAt = store.lastFindAt or os.clock()
store.lastAfk = store.lastAfk or 0
store.lastSell = store.lastSell or 0
store.lastHub = store.lastHub or 0
store.lastWebhookHour = store.lastWebhookHour or os.clock()
store.drawings = store.drawings or {}
store.codesTried = store.codesTried or false
store.lastLuck = store.lastLuck or 0
store.pausedNear = false
store.origWalk = store.origWalk or nil
store.origBright = store.origBright or nil

local TS = ReplicatedStorage:WaitForChild("TS")
local DiggingConfig = require(TS:WaitForChild("constants"):WaitForChild("digging"):WaitForChild("DiggingConfig"))
local DetectorsModule = require(TS:WaitForChild("constants"):WaitForChild("digging"):WaitForChild("Detectors"))
local ShovelsModule = require(TS:WaitForChild("constants"):WaitForChild("digging"):WaitForChild("Shovels"))
local ItemsModule = require(TS:WaitForChild("constants"):WaitForChild("items"):WaitForChild("Items"))
local IslandsModule = require(TS:WaitForChild("constants"):WaitForChild("world"):WaitForChild("Islands"))
local ItemsNetwork = require(PlayerScripts:WaitForChild("TS"):WaitForChild("network"):WaitForChild("ItemsNetwork"))
local ItemsEvents = ItemsNetwork.ItemsEvents
local ItemsFunctions = ItemsNetwork.ItemsFunctions
local ShopFunctions = require(PlayerScripts:WaitForChild("TS"):WaitForChild("network"):WaitForChild("ShopNetwork")).ShopFunctions
local TravelFunctions = require(PlayerScripts:WaitForChild("TS"):WaitForChild("network"):WaitForChild("TravelNetwork")).TravelFunctions
local DetectorEvents = require(PlayerScripts:WaitForChild("TS"):WaitForChild("network"):WaitForChild("DetectorNetwork")).DetectorEvents
local Notification = require(PlayerScripts:WaitForChild("TS"):WaitForChild("utils"):WaitForChild("ui"):WaitForChild("Notification")).Notification

local function requireNet(name)
	local ok, mod = pcall(function()
		return require(PlayerScripts.TS.network[name])
	end)
	if ok and typeof(mod) == "table" then
		return mod
	end
	return {}
end

local SellFunctions = requireNet("SellNetwork").SellFunctions
local CodeFunctions = requireNet("CodeNetwork").CodeFunctions
local QuestFunctions = requireNet("QuestNetwork").QuestFunctions
local LuckFunctions = requireNet("LuckNetwork").LuckFunctions
local LuckEvents = requireNet("LuckNetwork").LuckEvents
local FreeLuckFunctions = requireNet("FreeLuckNetwork").FreeLuckFunctions
local FreeLuckEvents = requireNet("FreeLuckNetwork").FreeLuckEvents
local MiscEvents = requireNet("MiscNetwork").MiscEvents
local MiscFunctions = requireNet("MiscNetwork").MiscFunctions
local PedestalFunctions = requireNet("PedestalNetwork").PedestalFunctions
local PlotSectionFunctions = requireNet("PlotSectionNetwork").PlotSectionFunctions
local ForgeFunctions = requireNet("ForgeNetwork").ForgeFunctions
local PyramidFunctions = requireNet("PyramidNetwork").PyramidFunctions

local BackpackCapacity
local QuestsMod
pcall(function()
	BackpackCapacity = require(TS.constants.inventory.BackpackCapacity).BackpackCapacity
end)
pcall(function()
	QuestsMod = require(TS.constants.quests.Quests)
end)

local itemValueFor = ItemsModule.itemValueFor
local dirtyItemValueFor = ItemsModule.dirtyItemValueFor

local SprayBottles
do
	local ok, mod = pcall(function()
		return require(TS.constants.cleaning.SprayBottles).SprayBottles
	end)
	if ok then
		SprayBottles = mod
	else
		ok, mod = pcall(function()
			return require(TS.constants.digging.SprayBottles).SprayBottles
		end)
		if ok then
			SprayBottles = mod
		end
	end
end

local RARITY_ORDER = ItemsModule.RARITY_ORDER
local ISLAND_ORDER = IslandsModule.ISLAND_ORDER
local digReachFor = DiggingConfig.digReachFor

local DIG_WIN_THRESHOLD = DiggingConfig.DIG_WIN_THRESHOLD
local DIG_REVEAL_SECONDS = DiggingConfig.DIG_REVEAL_SECONDS
local DIG_POWER_MIN_STOP_SECONDS = DiggingConfig.DIG_POWER_MIN_STOP_SECONDS
local DIG_MAX_CLICKS_PER_SECOND = DiggingConfig.DIG_MAX_CLICKS_PER_SECOND
local DIG_MAX_CLICK_BURST = DiggingConfig.DIG_MAX_CLICK_BURST
local DIG_BEGIN_COOLDOWN = DiggingConfig.DIG_BEGIN_COOLDOWN
local digPowerAt = DiggingConfig.digPowerAt

local flameworkOut = ReplicatedStorage
	:WaitForChild("rbxts_include")
	:WaitForChild("node_modules")
	:WaitForChild("@flamework")
	:WaitForChild("core")
	:WaitForChild("out")
local Flamework = require(flameworkOut).Flamework

local function getDig()
	local ok, dig = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/DigController@DigController")
	end)
	if ok and typeof(dig) == "table" then
		return dig
	end
	return nil
end

local function getDetector()
	local ok, det = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/DetectorController@DetectorController")
	end)
	if ok and typeof(det) == "table" then
		return det
	end
	return nil
end

local function getShovel()
	local ok, shovel = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/ShovelController@ShovelController")
	end)
	if ok and typeof(shovel) == "table" then
		return shovel
	end
	return nil
end

local function getWorkbench()
	local ok, wb = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/WorkbenchController@WorkbenchController")
	end)
	if ok and typeof(wb) == "table" then
		return wb
	end
	return nil
end

local function getSpray()
	local ok, spray = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/SprayBottleController@SprayBottleController")
	end)
	if ok and typeof(spray) == "table" then
		return spray
	end
	return nil
end

local function getSweep()
	local ok, sweep = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/DetectorSweepController@DetectorSweepController")
	end)
	if ok and typeof(sweep) == "table" then
		return sweep
	end
	return nil
end

local function getData()
	local ok, data = pcall(function()
		return Flamework.resolveDependency("client/controllers/data/DataController@DataController")
	end)
	if ok and typeof(data) == "table" then
		return data
	end
	return nil
end

local function getIslandCtl()
	local ok, ctl = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/IslandController@IslandController")
	end)
	if ok and typeof(ctl) == "table" then
		return ctl
	end
	return nil
end

local function getTravel()
	local ok, travel = pcall(function()
		return Flamework.resolveDependency("client/controllers/world/TravelController@TravelController")
	end)
	if ok and typeof(travel) == "table" then
		return travel
	end
	return nil
end

local function applyRange(def)
	if typeof(def) ~= "table" or typeof(def.range) ~= "number" then
		return
	end
	local orig = def.__idOrigRange
	if orig == nil then
		orig = def.range
		def.__idOrigRange = orig
	end
	local want = orig * ((CFG.Humanized and 1) or CFG.RangeMult)
	if def.range ~= want then
		def.range = want
	end
end

local function boostDetectorRange()
	local detectors = DetectorsModule.Detectors
	if typeof(detectors) == "table" then
		for _, def in pairs(detectors) do
			applyRange(def)
		end
	end
	local det = getDetector()
	if not det then
		return
	end
	pcall(function()
		applyRange(det:getLocalDefinition())
	end)
	local rig = det.localRig
	if typeof(rig) == "table" then
		applyRange(rig.def)
	end
end

local function notify(text, kind, color)
	local now = os.clock()
	if now - store.lastNotify < 0.15 then
		return
	end
	store.lastNotify = now
	pcall(function()
		Notification.new(text, 2.5, kind or "Pop", color or "Light Gray")
	end)
	print("[InstantDig]", text)
end

local function rarityRank(name)
	if typeof(name) ~= "string" then
		return 0
	end
	local idx = table.find(RARITY_ORDER, name)
	if typeof(idx) == "number" then
		return idx
	end
	return 0
end

local function rarityWanted(name)
	if typeof(name) ~= "string" then
		return false
	end
	if CFG.RarityMode == "exact" then
		return name == CFG.MinRarity
	end
	return rarityRank(name) >= rarityRank(CFG.MinRarity)
end

local function cancelTween()
	if store.tween then
		pcall(function()
			store.tween:Cancel()
		end)
		store.tween = nil
	end
	store.tweening = false
end

local function hideClanSigns()
	if not CFG.HideClan then
		return
	end
	local now = os.clock()
	if now - store.lastHide < 0.8 then
		return
	end
	store.lastHide = now
	local tagged = CollectionService:GetTagged("JoinGroupSign")
	for _, model in ipairs(tagged) do
		pcall(function()
			for _, inst in ipairs(model:GetDescendants()) do
				if inst:IsA("BasePart") then
					inst.Transparency = 1
					inst.CanCollide = false
					inst.CanQuery = false
					inst.CanTouch = false
					inst.LocalTransparencyModifier = 1
				elseif inst:IsA("Decal") or inst:IsA("Texture") then
					inst.Transparency = 1
				elseif inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
					inst.Enabled = false
				elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
					inst.Enabled = false
				end
			end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character then
				for _, inst in ipairs(character:GetDescendants()) do
					if inst:IsA("BillboardGui") then
						inst.Enabled = false
					end
				end
			end
		end
	end
end

local function hideCleanUi()
	if not CFG.BackgroundClean then
		return
	end
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local cleanUi = pg:FindFirstChild("CleanUI")
	if cleanUi and cleanUi:IsA("LayerCollector") then
		cleanUi.Enabled = false
	end
	for _, child in ipairs(pg:GetChildren()) do
		local name = string.lower(child.Name)
		if child:IsA("LayerCollector") and (string.find(name, "clean") or string.find(name, "reveal")) then
			child.Enabled = false
		end
	end
	local cam = Workspace.CurrentCamera
	if cam and cam.CameraType ~= Enum.CameraType.Custom then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function bestOwnedId(owned, catalog)
	if typeof(owned) ~= "table" or typeof(catalog) ~= "table" then
		return nil, -1
	end
	local bestId = nil
	local bestCost = -1
	for _, id in ipairs(owned) do
		local def = catalog[id]
		local cost = 0
		if typeof(def) == "table" and typeof(def.cost) == "number" then
			cost = def.cost
		end
		if cost > bestCost then
			bestCost = cost
			bestId = id
		end
	end
	return bestId, bestCost
end

local function equipBestGear(force)
	if not CFG.AutoBestGear and not force then
		return
	end
	local now = os.clock()
	if not force and now - store.lastGear < 6 then
		return
	end
	store.lastGear = now
	local dataCtl = getData()
	if not dataCtl then
		return
	end
	local data = dataCtl.getDataIfLoaded and dataCtl:getDataIfLoaded()
	if typeof(data) ~= "table" then
		return
	end
	local jobs = {
		{ "shovel", data.OwnedShovels, ShovelsModule.Shovels, data.EquippedShovel },
		{ "detector", data.OwnedDetectors, DetectorsModule.Detectors, data.EquippedDetector },
		{ "spray", data.OwnedSprays, SprayBottles, data.EquippedSpray },
	}
	local names = {}
	for _, job in ipairs(jobs) do
		local category, owned, catalog, equipped = job[1], job[2], job[3], job[4]
		local bestId = bestOwnedId(owned, catalog)
		if bestId and bestId ~= equipped then
			pcall(function()
				ShopFunctions.equipGear:invoke(category, bestId)
			end)
			table.insert(names, bestId)
		end
	end
	if force and #names > 0 then
		notify("Equipped best: " .. table.concat(names, ", "), "Pop", "Green")
	elseif force then
		notify("Already on best-price gear", "Pop", "Blue")
	end
end

local function getHuntIslandId()
	if typeof(store.huntIslandId) == "string" and store.huntIslandId ~= "" then
		return store.huntIslandId
	end
	local dataCtl = getData()
	local data = dataCtl and dataCtl.getDataIfLoaded and dataCtl:getDataIfLoaded()
	return data and data.CurrentIsland
end

local function islandEntryById(id)
	if not id then
		return nil
	end
	local ctl = getIslandCtl()
	if ctl and typeof(ctl.islands) == "table" then
		for _, entry in ipairs(ctl.islands) do
			if entry.id == id then
				return entry
			end
		end
	end
	return nil
end

local function expandBounds(inst, bounds)
	local cf, size
	if inst:IsA("BasePart") then
		cf, size = inst.CFrame, inst.Size
	elseif inst:IsA("Model") then
		cf, size = inst:GetBoundingBox()
	else
		return
	end
	local hx = size.X / 2
	local hz = size.Z / 2
	for _, ox in ipairs({ -hx, hx }) do
		for _, oz in ipairs({ -hz, hz }) do
			local world = cf * Vector3.new(ox, 0, oz)
			if world.X < bounds.minX then
				bounds.minX = world.X
			end
			if world.X > bounds.maxX then
				bounds.maxX = world.X
			end
			if world.Z < bounds.minZ then
				bounds.minZ = world.Z
			end
			if world.Z > bounds.maxZ then
				bounds.maxZ = world.Z
			end
			if bounds.y then
				bounds.y = (bounds.y + world.Y) * 0.5
			else
				bounds.y = world.Y
			end
			bounds.found = true
		end
	end
end

local function getZoneBounds(islandId)
	if not islandId then
		return nil
	end
	if store.boundsId == islandId and store.bounds and store.boundsAt and os.clock() - store.boundsAt < 4 then
		return store.bounds
	end
	local tag = ShovelsModule.DIG_ZONE_TAG
	local bounds = {
		minX = math.huge,
		maxX = -math.huge,
		minZ = math.huge,
		maxZ = -math.huge,
		y = nil,
		found = false,
	}
	if typeof(tag) == "string" then
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			local ok, zoneId = true, islandId
			if typeof(IslandsModule.islandOfZone) == "function" then
				ok, zoneId = pcall(IslandsModule.islandOfZone, inst)
			end
			if ok and zoneId == islandId then
				expandBounds(inst, bounds)
			end
		end
	end
	store.boundsId = islandId
	store.boundsAt = os.clock()
	if not bounds.found then
		store.bounds = nil
		return nil
	end
	store.bounds = bounds
	return bounds
end

local function inHuntBounds(pos)
	if typeof(pos) ~= "Vector3" then
		return false
	end
	local islandId = getHuntIslandId()
	local bounds = getZoneBounds(islandId)
	if bounds then
		local pad = 8
		return pos.X >= bounds.minX + pad
			and pos.X <= bounds.maxX - pad
			and pos.Z >= bounds.minZ + pad
			and pos.Z <= bounds.maxZ - pad
	end
	local entry = islandEntryById(islandId)
	local spawn = entry and entry.spawn
	if spawn then
		local here = spawn.Position
		if math.abs(pos.Y - here.Y) > 45 then
			return false
		end
		return (Vector3.new(pos.X, here.Y, pos.Z) - here).Magnitude < 180
	end
	return false
end

local function pickTargetTrail()
	local sweep = getSweep()
	if not sweep or typeof(sweep.nodes) ~= "table" then
		return nil
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local here = hrp.Position
	local bestSurfaced = nil
	local bestHidden = nil
	local distS = math.huge
	local distH = math.huge
	local minSize = CFG.MinItemSize or 0
	for id, node in pairs(sweep.nodes) do
		if typeof(node) == "table" and typeof(node.position) == "Vector3" and rarityWanted(node.rarity) then
			local sizeOk = minSize <= 0 or (typeof(node.itemSize) == "number" and node.itemSize >= minSize)
			if sizeOk and inHuntBounds(node.position) then
				local dist = (node.position - here).Magnitude
				local surfaced = sweep.surfaced ~= nil and sweep.surfaced[id] ~= nil
				if surfaced then
					if dist < distS then
						distS = dist
						bestSurfaced = { id = id, node = node, dist = dist, surfaced = true }
					end
				elseif dist < distH then
					distH = dist
					bestHidden = { id = id, node = node, dist = dist, surfaced = false }
				end
			end
		end
	end
	return bestSurfaced or bestHidden
end

local function unequipHeldItems()
	local character = LocalPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid:UnequipTools()
		end)
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			pcall(function()
				child.Parent = LocalPlayer:FindFirstChild("Backpack")
			end)
		end
	end
end

local function holdDetector()
	unequipHeldItems()
	local det = getDetector()
	if not det then
		return
	end
	pcall(function()
		det.digging = false
		det:evaluateLocalHold()
	end)
	pcall(function()
		if det.isLocalHeld and det:isLocalHeld() then
			return
		end
		local rig = det.localRig
		if rig then
			if det.setHeld then
				det:setHeld(rig, true)
			else
				rig.held = true
			end
		end
		DetectorEvents.SetDetectorHeld:fire(true)
		local shovel = getShovel()
		if shovel and shovel.setDetectorHeld then
			shovel:setDetectorHeld(true)
		end
	end)
end

local function islandCenter()
	local huntId = getHuntIslandId()
	local entry = islandEntryById(huntId)
	if entry and entry.spawn then
		return entry.spawn.Position, huntId
	end
	local dataCtl = getData()
	local data = dataCtl and dataCtl.getDataIfLoaded and dataCtl:getDataIfLoaded()
	local current = data and data.CurrentIsland
	local ctl = getIslandCtl()
	if ctl and typeof(ctl.islands) == "table" and current then
		for _, item in ipairs(ctl.islands) do
			if item.id == current and item.spawn then
				return item.spawn.Position, current
			end
		end
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position, huntId or current
	end
	return nil, huntId or current
end

local function groundAt(pos)
	local origin = pos + Vector3.new(0, 80, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = LocalPlayer.Character
	if character then
		params.FilterDescendantsInstances = { character }
	end
	local hit = Workspace:Raycast(origin, Vector3.new(0, -200, 0), params)
	if hit then
		local water = hit.Material == Enum.Material.Water
			or string.find(string.lower(hit.Instance.Name), "water", 1, true) ~= nil
		if not water then
			return hit.Position
		end
	end
	local center = islandCenter()
	if center then
		local pulled = Vector3.new(center.X, pos.Y, center.Z)
		if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude > 4 then
			local dir = (Vector3.new(center.X, 0, center.Z) - Vector3.new(pos.X, 0, pos.Z)).Unit
			pulled = pos + dir * 22
		end
		local hit2 = Workspace:Raycast(pulled + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
		if hit2 and hit2.Material ~= Enum.Material.Water then
			return hit2.Position
		end
		return center
	end
	return pos
end

local function clampToIsland(pos)
	if typeof(pos) ~= "Vector3" then
		return nil
	end
	local center, islandId = islandCenter()
	local bounds = getZoneBounds(islandId)
	local x, z = pos.X, pos.Z
	if bounds then
		local inset = math.max(12, CFG.EdgeInset or 14)
		local minX = bounds.minX + inset
		local maxX = bounds.maxX - inset
		local minZ = bounds.minZ + inset
		local maxZ = bounds.maxZ - inset
		if maxX > minX then
			x = math.clamp(x, minX, maxX)
		end
		if maxZ > minZ then
			z = math.clamp(z, minZ, maxZ)
		end
	elseif center then
		local dx = x - center.X
		local dz = z - center.Z
		local mag = math.sqrt(dx * dx + dz * dz)
		if mag > 150 then
			x = center.X + dx / mag * 150
			z = center.Z + dz / mag * 150
		end
	end
	return groundAt(Vector3.new(x, pos.Y, z))
end

local function edgePath(bounds)
	local inset = math.clamp(CFG.EdgeInset or 14, 4, 40)
	local minX = bounds.minX + inset
	local maxX = bounds.maxX - inset
	local minZ = bounds.minZ + inset
	local maxZ = bounds.maxZ - inset
	if maxX - minX < 16 then
		minX = bounds.minX + 3
		maxX = bounds.maxX - 3
	end
	if maxZ - minZ < 16 then
		minZ = bounds.minZ + 3
		maxZ = bounds.maxZ - 3
	end
	local y = bounds.y or 0
	local points = {}
	local n = 8
	local function add(x, z)
		if CFG.RandomEdge then
			x = x + (math.random() - 0.5) * 8
			z = z + (math.random() - 0.5) * 8
		end
		table.insert(points, Vector3.new(x, y, z))
	end
	for i = 0, n - 1 do
		add(minX + (maxX - minX) * (i / n), minZ)
	end
	for i = 0, n - 1 do
		add(maxX, minZ + (maxZ - minZ) * (i / n))
	end
	for i = 0, n - 1 do
		add(maxX - (maxX - minX) * (i / n), maxZ)
	end
	for i = 0, n - 1 do
		add(minX, maxZ - (maxZ - minZ) * (i / n))
	end
	return points
end

local function patrolPoint()
	local center, islandId = islandCenter()
	if not center then
		return nil
	end
	store.patrolIndex = (store.patrolIndex or 0) + 1
	local bounds = getZoneBounds(islandId)
	if bounds then
		local points = edgePath(bounds)
		if #points > 0 then
			return clampToIsland(points[((store.patrolIndex - 1) % #points) + 1])
		end
	end
	local radius = math.max(18, CFG.PatrolRadius or 62)
	local steps = 12
	local ang = ((store.patrolIndex - 1) % steps) / steps * math.pi * 2
	return groundAt(center + Vector3.new(math.cos(ang) * radius, 0, math.sin(ang) * radius))
end

local function zoneAt(pos)
	local shovel = getShovel()
	local zone = nil
	if shovel and shovel.getLocalZone then
		pcall(function()
			zone = shovel:getLocalZone()
		end)
	end
	if zone then
		return zone
	end
	local tag = ShovelsModule.DIG_ZONE_TAG
	if typeof(tag) ~= "string" or typeof(pos) ~= "Vector3" then
		return nil
	end
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsA("BasePart") then
			local rel = inst.CFrame:PointToObjectSpace(pos)
			if math.abs(rel.X) <= inst.Size.X / 2 + 10 and math.abs(rel.Z) <= inst.Size.Z / 2 + 10 then
				return inst
			end
		elseif inst:IsA("Model") then
			local cf, size = inst:GetBoundingBox()
			local rel = cf:PointToObjectSpace(pos)
			if math.abs(rel.X) <= size.X / 2 + 10 and math.abs(rel.Z) <= size.Z / 2 + 10 then
				return inst
			end
		end
	end
	return nil
end

local function startTargetDig(dig, pick)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not hrp then
		return false
	end
	unequipHeldItems()
	local zone = zoneAt(hrp.Position)
	if not zone and pick.node and pick.node.position then
		zone = zoneAt(pick.node.position)
	end
	store.lastAuto = os.clock()
	store.lastFindAt = os.clock()
	store.sessionDigs = (store.sessionDigs or 0) + 1
	if pick.node and pick.node.rarity then
		table.insert(store.dropLog, 1, {
			rarity = pick.node.rarity,
			at = os.clock(),
		})
		while #store.dropLog > 20 do
			table.remove(store.dropLog)
		end
		store.pendingWebhook = pick
	end
	local ok = pcall(function()
		dig:beginBuriedDig(pick.node, character, humanoid, hrp, zone)
	end)
	if not ok then
		store.sessionDigs = math.max(0, (store.sessionDigs or 1) - 1)
	end
	return ok
end

local function tweenToward(pos)
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local destFlat = clampToIsland(pos)
	if not destFlat then
		return false
	end
	local dest = destFlat + Vector3.new(0, 3.2, 0)
	local dist = (hrp.Position - dest).Magnitude
	if dist <= 6 then
		return false
	end
	local center = islandCenter()
	if center then
		local away = Vector3.new(dest.X, center.Y, dest.Z)
		if (away - center).Magnitude > 280 then
			dest = groundAt(center) + Vector3.new(0, 3.2, 0)
			dist = (hrp.Position - dest).Magnitude
		end
	end
	cancelTween()
	if CFG.NoclipTween then
		hrp.CanCollide = false
	end
	store.tweening = true
	local seconds = 0.1
	if CFG.TweenToHole ~= false then
		local speed = CFG.Humanized and math.min(CFG.TweenSpeed, 52) or CFG.TweenSpeed
		seconds = math.clamp(dist / math.max(20, speed), 0.18, 2.8)
	end
	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(dest) }
	)
	store.tween = tween
	tween.Completed:Connect(function()
		if store.tween == tween then
			store.tween = nil
			store.tweening = false
			store.landedAt = os.clock()
			if CFG.NoclipTween and hrp.Parent then
				hrp.CanCollide = true
			end
			local here = hrp.Position
			if zoneAt(here) == nil then
				local spawn = islandCenter()
				if spawn then
					hrp.CFrame = CFrame.new(spawn + Vector3.new(0, 4, 0))
				end
			end
		end
	end)
	tween:Play()
	return true
end

local tpIsland

local function huntBestTrail(dig)
	if not CFG.HuntTrails then
		unequipHeldItems()
		return
	end
	holdDetector()
	if CFG.RequireHeldDetector then
		local det = getDetector()
		local held = false
		pcall(function()
			held = det ~= nil and det.isLocalHeld and det:isLocalHeld()
		end)
		if not held then
			return
		end
	end
	if store.traveling then
		return
	end
	if store.tweening then
		return
	end
	if store.landedAt and os.clock() - store.landedAt < 0.08 then
		return
	end
	if CFG.StopAfterDigs > 0 and (store.sessionDigs or 0) >= CFG.StopAfterDigs then
		return
	end
	if CFG.StopAfterMinutes > 0 and (os.clock() - (store.sessionStart or os.clock())) / 60 >= CFG.StopAfterMinutes then
		return
	end
	if CFG.IslandRarityAuto then
		local hid = getHuntIslandId()
		local mapped = hid and ISLAND_RARITY[hid]
		if mapped and store.autoRarityFor ~= hid then
			store.autoRarityFor = hid
			CFG.MinRarity = mapped
			notify("Trail rarity -> " .. mapped, "Pop", "Blue")
		end
	end
	if CFG.PauseNearPlayers then
		local me = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if me then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - me.Position).Magnitude < (CFG.NearbyRadius or 42) then
						store.pausedNear = true
						return
					end
				end
			end
		end
		store.pausedNear = false
	end
	local huntId = getHuntIslandId()
	local dataCtl = getData()
	local data = dataCtl and dataCtl.getDataIfLoaded and dataCtl:getDataIfLoaded()
	local current = data and data.CurrentIsland
	if huntId and current and current ~= huntId then
		local entry = islandEntryById(huntId)
		if entry then
			tpIsland(entry)
		end
		return
	end
	local center = islandCenter()
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if center and hrp then
		local flat = Vector3.new(hrp.Position.X, center.Y, hrp.Position.Z)
		if (flat - center).Magnitude > 380 then
			local entry = islandEntryById(huntId)
			if entry then
				tpIsland(entry)
				return
			end
		end
	end
	local shovel = getShovel()
	local inZone = zoneAt(hrp and hrp.Position or Vector3.zero) ~= nil
	local pick = pickTargetTrail()
	if pick then
		local reach = 8
		if typeof(digReachFor) == "function" then
			local ok, value = pcall(digReachFor, pick.node.itemSize)
			if ok and typeof(value) == "number" then
				reach = math.max(6, value)
			end
		end
		if pick.dist > reach then
			tweenToward(pick.node.position)
			return
		end
		if os.clock() - store.lastAuto < DIG_BEGIN_COOLDOWN then
			return
		end
		startTargetDig(dig, pick)
		return
	end
	if not inZone then
		local point = patrolPoint()
		if point then
			tweenToward(point)
		elseif center then
			tweenToward(center)
		end
		return
	end
	local point = patrolPoint()
	if point then
		tweenToward(point)
	end
end

local function islandList()
	local ctl = getIslandCtl()
	if ctl and typeof(ctl.islands) == "table" and #ctl.islands > 0 then
		return ctl.islands
	end
	return nil
end

tpIsland = function(entry)
	if store.traveling or typeof(entry) ~= "table" then
		return
	end
	store.traveling = true
	cancelTween()
	notify("TP " .. tostring(entry.name or entry.id), "Pop", "Blue")
	pcall(function()
		local promise = TravelFunctions.travel:invoke(entry.id)
		promise:andThen(function(result)
			store.traveling = false
			if result == "poor" then
				notify("Need more gold for that island", "Error", "Red")
				return
			end
			local travel = getTravel()
			if travel and travel.arrive then
				pcall(function()
					travel:arrive(entry)
				end)
			end
		end):catch(function()
			store.traveling = false
		end)
	end)
	task.delay(4, function()
		store.traveling = false
	end)
end

local function cycleIsland(dir)
	local list = islandList()
	if not list then
		notify("Islands not loaded yet", "Error", "Orange")
		return
	end
	local dataCtl = getData()
	local data = dataCtl and dataCtl.getDataIfLoaded and dataCtl:getDataIfLoaded()
	local unlocked = data and data.UnlockedIslands
	local current = data and data.CurrentIsland
	local usable = {}
	for _, entry in ipairs(list) do
		local free = IslandsModule.Islands[entry.id] and IslandsModule.Islands[entry.id].cost == 0
		local owned = typeof(unlocked) == "table" and table.find(unlocked, entry.id) ~= nil
		if free or owned then
			table.insert(usable, entry)
		end
	end
	if #usable == 0 then
		return
	end
	local idx = 1
	for i, entry in ipairs(usable) do
		if entry.id == current then
			idx = i
			break
		end
	end
	idx = ((idx - 1 + dir) % #usable) + 1
	store.islandIndex = idx
	store.huntIslandId = usable[idx].id
	store.patrolIndex = 0
	store.bounds = nil
	tpIsland(usable[idx])
end

local function allowedClicks(elapsed)
	return DIG_MAX_CLICK_BURST + math.floor(math.max(0, elapsed) * DIG_MAX_CLICKS_PER_SECOND)
end

local function neededClicks(session)
	local difficulty = session.difficulty
	if typeof(difficulty) ~= "table" then
		return nil
	end
	local clickPower = difficulty.clickPower
	if typeof(clickPower) ~= "number" or clickPower <= 0 then
		return nil
	end
	local remain = DIG_WIN_THRESHOLD - (session.progress or 0)
	if remain <= 0 then
		return 0
	end
	return math.max(1, math.ceil(remain / clickPower) + 1)
end

local function skipReveal(session)
	if session.phase ~= "revealing" then
		return
	end
	local started = session.revealStarted
	if typeof(started) ~= "number" then
		return
	end
	session.revealStarted = os.clock() - DIG_REVEAL_SECONDS
end

local function stopPowerAtPeak(dig, session)
	if session.phase ~= "power" or session.powerStopping then
		return
	end
	local started = session.powerStartedAt
	if typeof(started) ~= "number" or started <= 0 then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - started
	if elapsed < DIG_POWER_MIN_STOP_SECONDS then
		return
	end
	local power = digPowerAt(elapsed)
	if CFG.MaxLuck then
		if CFG.MaxLuckOnlyWithBuff and (store.serverLuck or 1) <= 1.05 then
			pcall(function()
				dig:stopPower()
			end)
			return
		end
		if power < 0.97 and elapsed < 0.34 then
			return
		end
	end
	pcall(function()
		dig:stopPower()
	end)
end

local function finishMinigame(dig, session)
	if session.phase ~= "minigame" then
		return
	end
	if dig.isResolving and dig:isResolving(session) then
		return
	end
	local need = neededClicks(session)
	if need == nil then
		return
	end
	if session.firstDigAt == nil then
		session.firstDigAt = os.clock()
	end
	local elapsed = os.clock() - session.firstDigAt
	if need > allowedClicks(elapsed) then
		return
	end
	session.totalClicks = math.max(session.totalClicks or 0, need)
	session.progress = DIG_WIN_THRESHOLD
	pcall(function()
		if dig.bar and dig.bar.setProgress then
			dig.bar:setProgress(session.progress)
		end
	end)
	pcall(function()
		dig:finish(true)
	end)
end

local function tryAutoDig(dig)
	if not CFG.Enabled or not CFG.AutoDig then
		return
	end
	if store.blockDigLuck then
		return
	end
	if CFG.StopWhenFull and store.packFull then
		return
	end
	if dig.session or dig.starting then
		return
	end
	local wb = getWorkbench()
	if not CFG.BackgroundClean and wb and (wb.cleaning or wb.session) then
		return
	end
	local now = os.clock()
	if now - store.digEndedAt < 0.7 then
		return
	end
	huntBestTrail(dig)
end

local function findDirtyTool()
	local function from(root)
		if not root then
			return nil
		end
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Tool") and CollectionService:HasTag(child, "Dirt") then
				return child
			end
		end
		return nil
	end
	local character = LocalPlayer.Character
	return from(character) or from(LocalPlayer:FindFirstChild("Backpack"))
end

local function patchFastClean(wb)
	if wb.__idFastClean then
		return
	end
	wb.__idFastClean = true
	function wb:onInstantCleaned(inventoryId)
		local session = self.session
		if not session or session.inventoryId ~= inventoryId or self.finishing then
			return
		end
		self.finishing = true
		pcall(function()
			self.sprayBottle:halt()
			self.sprayBottle:popAllDirt()
		end)
		pcall(function()
			self:endCleaning()
		end)
	end
end

local function recoverStuckClean(wb)
	if not wb.cleaning or wb.session then
		store.stuckCleanAt = 0
		return
	end
	local now = os.clock()
	if store.stuckCleanAt == 0 then
		store.stuckCleanAt = now
		return
	end
	if now - store.stuckCleanAt < 1.1 then
		return
	end
	store.stuckCleanAt = 0
	wb.cleaning = false
	wb.finishing = false
	pcall(function()
		local spray = wb.sprayBottle
		if spray and spray.endSession then
			spray:endSession()
		end
		wb:refreshPrompt()
	end)
end

local function backgroundClean()
	if not CFG.CleanEnabled or not CFG.AutoClean or not CFG.BackgroundClean then
		return
	end
	if store.bgCleaning then
		return
	end
	local now = os.clock()
	if now - store.lastAutoClean < 0.45 then
		return
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local tool = nil
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and CollectionService:HasTag(child, "Dirt") then
				tool = child
				break
			end
		end
	end
	if not tool then
		local character = LocalPlayer.Character
		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") and CollectionService:HasTag(child, "Dirt") then
					tool = child
					break
				end
			end
		end
	end
	if not tool then
		return
	end
	local inventoryId = tool:GetAttribute("inventoryId")
	if inventoryId == nil then
		return
	end
	store.lastAutoClean = now
	store.bgCleaning = true
	unequipHeldItems()
	hideCleanUi()
	pcall(function()
		local promise = ItemsFunctions.beginCleaning:invoke(inventoryId)
		if promise and promise.andThen then
			promise:andThen(function()
				pcall(function()
					ItemsEvents.requestSkipClean:fire()
				end)
				pcall(function()
					ItemsEvents.finishCleaning:fire(inventoryId)
				end)
				store.bgCleaning = false
			end):catch(function()
				store.bgCleaning = false
			end)
		else
			ItemsEvents.requestSkipClean:fire()
			ItemsEvents.finishCleaning:fire(inventoryId)
			store.bgCleaning = false
		end
	end)
	pcall(function()
		ItemsEvents.requestSkipClean:fire()
	end)
	task.delay(1.2, function()
		store.bgCleaning = false
	end)
end

local function instantClean(wb)
	if not CFG.CleanEnabled then
		return
	end
	if CFG.BackgroundClean then
		hideCleanUi()
		if typeof(wb.session) == "table" and not wb.finishing then
			local inventoryId = wb.session.inventoryId
			if inventoryId ~= nil then
				pcall(function()
					ItemsEvents.requestSkipClean:fire()
				end)
				pcall(function()
					ItemsEvents.finishCleaning:fire(inventoryId)
				end)
			end
			pcall(function()
				wb:endCleaning()
			end)
		end
		return
	end
	local session = wb.session
	if typeof(session) ~= "table" or wb.finishing then
		return
	end
	local inventoryId = session.inventoryId
	local now = os.clock()
	local shouldSkip = inventoryId ~= nil
		and (store.lastSkipId ~= inventoryId or now - store.skipAt > 0.55)
	if shouldSkip then
		store.lastSkipId = inventoryId
		store.skipAt = now
		pcall(function()
			ItemsEvents.requestSkipClean:fire()
		end)
	end
	local spray = getSpray()
	if spray then
		pcall(function()
			spray:popAllDirt()
		end)
		if store.skipAt > 0 and now - store.skipAt > 0.35 and not wb.finishing then
			pcall(function()
				spray:forceFinish()
			end)
		end
	end
end

local function tryAutoClean(wb, dig)
	if CFG.BackgroundClean then
		return false
	end
	if not CFG.CleanEnabled or not CFG.AutoClean then
		return false
	end
	if wb.cleaning or wb.session or wb.finishing then
		return true
	end
	if dig and (dig.session or dig.starting) then
		return false
	end
	local now = os.clock()
	if not wb.workbench or not wb.tableTop or not wb.billboard then
		return false
	end
	if now - store.lastAutoClean < 0.35 then
		return true
	end
	local tool = findDirtyTool()
	if not tool then
		return false
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return true
	end
	if tool.Parent ~= character then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
		return true
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return true
	end
	store.lastAutoClean = now
	wb.cleaning = true
	if wb.prompt then
		wb.prompt.Enabled = false
	end
	local itemId = tool:GetAttribute("itemId")
	local inventoryId = tool:GetAttribute("inventoryId")
	local ok = pcall(function()
		wb:enterCleaning(tool, itemId, inventoryId)
	end)
	if not ok or (wb.cleaning and not wb.session) then
		wb.cleaning = false
		wb.finishing = false
		pcall(function()
			wb:refreshPrompt()
		end)
	end
	return true
end

local function loadedData()
	local ctl = getData()
	if not ctl or not ctl.getDataIfLoaded then
		return nil
	end
	local data = ctl:getDataIfLoaded()
	if typeof(data) == "table" then
		return data
	end
	return nil
end

local function saveCfg()
	if typeof(writefile) ~= "function" then
		return
	end
	local dump = {}
	for key, value in pairs(CFG) do
		local ty = typeof(value)
		if ty == "boolean" or ty == "number" or ty == "string" then
			dump[key] = value
		end
	end
	pcall(function()
		writefile(CFG_PATH, HttpService:JSONEncode(dump))
	end)
end

local function loadCfg()
	if typeof(isfile) ~= "function" or not isfile(CFG_PATH) then
		return
	end
	local ok, src = pcall(readfile, CFG_PATH)
	if not ok or typeof(src) ~= "string" then
		return
	end
	local ok2, saved = pcall(function()
		return HttpService:JSONDecode(src)
	end)
	if not ok2 or typeof(saved) ~= "table" then
		return
	end
	for key, value in pairs(saved) do
		if CFG[key] ~= nil and typeof(value) == typeof(CFG[key]) then
			CFG[key] = value
		end
	end
end

loadCfg()
CFG.TweenToHole = false

local function saveProfile(name)
	if typeof(writefile) ~= "function" or typeof(name) ~= "string" or name == "" then
		return
	end
	local dump = {}
	for key, value in pairs(CFG) do
		local ty = typeof(value)
		if ty == "boolean" or ty == "number" or ty == "string" then
			dump[key] = value
		end
	end
	pcall(function()
		writefile("instant_dig_profile_" .. name .. ".json", HttpService:JSONEncode(dump))
	end)
	notify("Saved profile " .. name, "Pop", "Green")
end

local function loadProfile(name)
	local path = "instant_dig_profile_" .. tostring(name) .. ".json"
	if typeof(isfile) ~= "function" or not isfile(path) then
		notify("No profile " .. tostring(name), "Error", "Orange")
		return
	end
	local ok, src = pcall(readfile, path)
	if not ok then
		return
	end
	local ok2, saved = pcall(function()
		return HttpService:JSONDecode(src)
	end)
	if not ok2 or typeof(saved) ~= "table" then
		return
	end
	for key, value in pairs(saved) do
		if CFG[key] ~= nil and typeof(value) == typeof(CFG[key]) then
			CFG[key] = value
		end
	end
	notify("Loaded profile " .. name, "Pop", "Green")
end

local function applyHumanized()
	CFG.Humanized = true
	CFG.RangeMult = 1
	CFG.TweenSpeed = 52
	CFG.NoclipTween = false
	CFG.TweenToHole = true
	boostDetectorRange()
	notify("Humanized mode", "Pop", "Blue")
end

local function applyGoldFarm()
	CFG.RarityMode = "min"
	CFG.MinRarity = "common"
	CFG.AutoSell = true
	CFG.SellBelow = "legendary"
	CFG.SellWhenFull = true
	CFG.StopWhenFull = true
	CFG.HuntTrails = true
	notify("Gold farm profile", "Pop", "Green")
end

local function applyRareFarm()
	CFG.RarityMode = "min"
	CFG.MinRarity = "legendary"
	CFG.IslandRarityAuto = true
	CFG.AutoSell = true
	CFG.SellBelow = "legendary"
	CFG.KeepMutations = true
	notify("Rare farm profile", "Pop", "Green")
end

local function playerGui()
	return LocalPlayer:FindFirstChild("PlayerGui")
end

local function backpackFull(data)
	data = data or loadedData()
	if not data then
		return false
	end
	if BackpackCapacity and BackpackCapacity.isFull then
		local ok, full = pcall(BackpackCapacity.isFull, data)
		if ok then
			return full == true
		end
	end
	local inv = data.Inventory
	if typeof(inv) ~= "table" then
		return false
	end
	local n = 0
	for _, item in pairs(inv) do
		if typeof(item) == "table" and item.pedestalSlot == nil and item.polisherSlot == nil then
			n = n + 1
		end
	end
	return n >= 48
end

local function backpackCount(data)
	data = data or loadedData()
	if not data or typeof(data.Inventory) ~= "table" then
		return 0, 50
	end
	local n = 0
	for _, item in pairs(data.Inventory) do
		if typeof(item) == "table" and item.pedestalSlot == nil and item.polisherSlot == nil then
			n = n + 1
		end
	end
	local cap = 50
	if BackpackCapacity and BackpackCapacity.limitFor then
		local ok, value = pcall(BackpackCapacity.limitFor, data)
		if ok and typeof(value) == "number" then
			cap = value
		end
	end
	return n, cap
end

local function collectionHas(data, itemId)
	if typeof(data) ~= "table" then
		return false
	end
	local bags = { data.Collection, data.CollectedItems, data.ItemStats, data.DiscoveredItems }
	for _, bag in ipairs(bags) do
		if typeof(bag) == "table" then
			if bag[itemId] ~= nil then
				return true
			end
			for _, row in pairs(bag) do
				if row == itemId or (typeof(row) == "table" and (row.id == itemId or row.itemId == itemId)) then
					return true
				end
			end
		end
	end
	return false
end

local function itemGold(item)
	if typeof(item) ~= "table" then
		return 0
	end
	local id = item.id or item.itemId
	local kg = item.kg
	local mutation = item.mutation
	if item.dirty and typeof(dirtyItemValueFor) == "function" then
		local ok, value = pcall(dirtyItemValueFor, id, kg, mutation)
		if ok and typeof(value) == "number" then
			return value
		end
	end
	if typeof(itemValueFor) == "function" then
		local ok, value = pcall(itemValueFor, id, item.condition or "mint", kg, mutation)
		if ok and typeof(value) == "number" then
			return value
		end
	end
	return 0
end

local function shouldKeepItem(item, data, seenIds)
	if typeof(item) ~= "table" then
		return false
	end
	if item.pedestalSlot ~= nil or item.polisherSlot ~= nil then
		return true
	end
	if item.favorited == true then
		return true
	end
	local def = ItemsModule.Items and ItemsModule.Items[item.id]
	local rarity = (def and def.rarity) or item.rarity
	if CFG.KeepMutations and item.mutation ~= nil then
		return true
	end
	if CFG.KeepNewIndex and not collectionHas(data, item.id) then
		return true
	end
	if CFG.MinKeepValue > 0 and itemGold(item) >= CFG.MinKeepValue then
		return true
	end
	if rarityWanted(rarity) then
		return true
	end
	if rarityRank(rarity) >= rarityRank(CFG.SellBelow) then
		return true
	end
	if CFG.KeepOneEach and item.id then
		if seenIds[item.id] then
			return false
		end
		seenIds[item.id] = true
		return rarityRank(rarity) >= rarityRank("rare")
	end
	return false
end

local function favoriteItem(inventoryId)
	if inventoryId == nil or not ItemsEvents or not ItemsEvents.toggleFavorite then
		return
	end
	pcall(function()
		ItemsEvents.toggleFavorite:fire(inventoryId)
	end)
end

local function autoFavoriteKeepers()
	if not CFG.AutoFavorite then
		return
	end
	local data = loadedData()
	if not data or typeof(data.Inventory) ~= "table" then
		return
	end
	local seen = {}
	for uid, item in pairs(data.Inventory) do
		if typeof(item) == "table" and item.favorited ~= true and shouldKeepItem(item, data, seen) then
			favoriteItem(item.inventoryId or uid)
		end
	end
end

local function findWorldPart(needles)
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") or inst:IsA("Model") then
			local lower = string.lower(inst.Name)
			for _, needle in ipairs(needles) do
				if string.find(lower, needle, 1, true) then
					if inst:IsA("Model") then
						local p = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart")
						if p then
							return p.Position, inst
						end
					else
						return inst.Position, inst
					end
				end
			end
		end
	end
	return nil
end

local function sellDump()
	if not CFG.AutoSell or store.selling then
		return false
	end
	if os.clock() - (store.lastSell or 0) < 2.5 then
		return false
	end
	store.lastSell = os.clock()
	store.selling = true
	autoFavoriteKeepers()
	local before = loadedData()
	local gold0 = before and before.Gold or 0
	task.spawn(function()
		if SellFunctions and SellFunctions.sellInventory then
			pcall(function()
				SellFunctions.sellInventory:invoke()
			end)
		end
		task.wait(0.8)
		store.selling = false
		local after = loadedData()
		local gold1 = after and after.Gold or gold0
		if gold1 > gold0 then
			notify("Sold junk +" .. tostring(math.floor(gold1 - gold0)), "Pop", "Green")
		end
	end)
	return true
end

local function currentLuck()
	local n = 1
	if LuckFunctions then
		pcall(function()
			if LuckFunctions.getServerLuck then
				local p = LuckFunctions.getServerLuck:invoke()
				if p and p.andThen then
					p:andThen(function(info)
						if typeof(info) == "table" and typeof(info.multiplier) == "number" then
							store.serverLuck = info.multiplier
							store.luckSource = info.source
						end
					end)
				end
			end
			if LuckFunctions.getGlobalLuck then
				LuckFunctions.getGlobalLuck:invoke()
			end
			if LuckFunctions.getFriendLuck then
				local p = LuckFunctions.getFriendLuck:invoke()
				if p and p.andThen then
					p:andThen(function(v)
						if typeof(v) == "number" then
							store.friendLuck = v
						end
					end)
				end
			end
		end)
	end
	n = math.max(n, store.serverLuck or 1, store.friendLuck or 1)
	return n
end

local function weatherActive()
	local rain = false
	local meteor = false
	pcall(function()
		local ctl = Flamework.resolveDependency("client/controllers/world/RainController@RainController")
		if ctl and ctl.isActive then
			rain = ctl:isActive() == true
		end
	end)
	pcall(function()
		local ctl = Flamework.resolveDependency("client/controllers/world/MeteorShowerController@MeteorShowerController")
		if ctl then
			if ctl.isActive then
				meteor = ctl:isActive() == true
			elseif ctl.active or ctl.showerActive then
				meteor = true
			end
		end
	end)
	return rain, meteor
end

local function sendWebhook(title, body)
	local url = CFG.Webhook
	if typeof(url) ~= "string" or url == "" or string.find(url, "http", 1, true) ~= 1 then
		return
	end
	local payload = HttpService:JSONEncode({
		username = "Dig & Clean",
		embeds = {
			{
				title = title,
				description = body,
				color = 5814783,
			},
		},
	})
	task.spawn(function()
		pcall(function()
			if typeof(request) == "function" then
				request({
					Url = url,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = payload,
				})
			elseif typeof(http_request) == "function" then
				http_request({
					Url = url,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = payload,
				})
			end
		end)
	end)
end

local function maybeWebhookRare(pick)
	if not CFG.WebhookRares or not pick or not pick.node then
		return
	end
	local rarity = pick.node.rarity
	if WEBHOOK_RARITIES[rarity] then
		sendWebhook("Rare trail", tostring(rarity) .. " on " .. tostring(getHuntIslandId() or "?"))
	end
end

local function redeemCodes()
	if not CFG.AutoCodes or store.codesTried then
		return
	end
	if not CodeFunctions or not CodeFunctions.redeemCode then
		return
	end
	store.codesTried = true
	task.spawn(function()
		for _, code in ipairs(KNOWN_CODES) do
			pcall(function()
				CodeFunctions.redeemCode:invoke(code)
			end)
			task.wait(0.4)
		end
		notify("Tried known codes", "Pop", "Blue")
	end)
end

local function claimQuests()
	if not CFG.AutoQuests or not QuestFunctions or not QuestFunctions.claimQuest then
		return
	end
	local data = loadedData()
	local quests = data and data.DailyQuests
	if typeof(quests) ~= "table" then
		return
	end
	for i, quest in ipairs(quests) do
		local done = false
		if QuestsMod and QuestsMod.isQuestComplete then
			local ok, value = pcall(QuestsMod.isQuestComplete, quest)
			done = ok and value == true
		elseif typeof(quest) == "table" and typeof(quest.progress) == "number" and typeof(quest.target) == "number" then
			done = quest.progress >= quest.target and quest.claimed ~= true
		end
		if done then
			pcall(function()
				QuestFunctions.claimQuest:invoke(i - 1)
			end)
		end
	end
end

local function claimLuck()
	if CFG.AutoGroupLuck and FreeLuckFunctions and FreeLuckFunctions.claimGroupReward then
		pcall(function()
			FreeLuckFunctions.claimGroupReward:invoke()
		end)
	end
	if CFG.AutoAdLuck and FreeLuckEvents and FreeLuckEvents.RequestAdReward then
		pcall(function()
			FreeLuckEvents.RequestAdReward:fire()
		end)
	end
end

local function boostLuckNow()
	CFG.MaxLuck = true
	CFG.AutoGroupLuck = true
	CFG.AutoAdLuck = true
	CFG.AutoCodes = true
	CFG.AutoQuests = true
	store.codesTried = false
	claimLuck()
	redeemCodes()
	claimQuests()
	local luck = currentLuck()
	notify(
		string.format("Luck claim  x%.2f  group/ad/codes/quests + 5x power", luck),
		"Pop",
		"Green"
	)
end

local function cheapestUnowned(owned, catalog)
	if typeof(owned) ~= "table" or typeof(catalog) ~= "table" then
		return nil, nil
	end
	local have = {}
	for _, id in ipairs(owned) do
		have[id] = true
	end
	local bestId, bestCost = nil, math.huge
	for id, def in pairs(catalog) do
		if typeof(def) == "table" and typeof(def.cost) == "number" and def.cost > 0 and not have[id] then
			if def.cost < bestCost then
				bestCost = def.cost
				bestId = id
			end
		end
	end
	return bestId, bestCost
end

local function autoBuyGear()
	local data = loadedData()
	if not data or not ShopFunctions or not ShopFunctions.buyGear then
		return
	end
	local gold = data.Gold or 0
	local jobs = {}
	if CFG.AutoBuyDetector then
		table.insert(jobs, { "detector", data.OwnedDetectors, DetectorsModule.Detectors })
	end
	if CFG.AutoBuyShovel then
		table.insert(jobs, { "shovel", data.OwnedShovels, ShovelsModule.Shovels })
	end
	if CFG.AutoBuySpray then
		table.insert(jobs, { "spray", data.OwnedSprays, SprayBottles })
	end
	for _, job in ipairs(jobs) do
		local id, cost = cheapestUnowned(job[2], job[3])
		if id and cost and gold >= cost then
			pcall(function()
				ShopFunctions.buyGear:invoke(job[1], id)
			end)
			gold = gold - cost
			notify("Bought " .. tostring(id), "Pop", "Green")
			return
		end
	end
end

local function horusId(catalog)
	if typeof(catalog) ~= "table" then
		return nil
	end
	for id in pairs(catalog) do
		if typeof(id) == "string" and string.find(string.lower(id), "horus", 1, true) then
			return id
		end
	end
	return nil
end

local oldEquip = equipBestGear
equipBestGear = function(force)
	if CFG.PreferHorus then
		local data = loadedData()
		if data then
			local pairsList = {
				{ "shovel", horusId(ShovelsModule.Shovels), data.EquippedShovel },
				{ "detector", horusId(DetectorsModule.Detectors), data.EquippedDetector },
			}
			for _, row in ipairs(pairsList) do
				if row[2] and row[2] ~= row[3] then
					pcall(function()
						ShopFunctions.equipGear:invoke(row[1], row[2])
					end)
				end
			end
		end
	end
	oldEquip(force)
end

local function autoUnlockIsland()
	if not CFG.AutoUnlockIsland then
		return
	end
	local data = loadedData()
	if not data then
		return
	end
	local gold = data.Gold or 0
	local unlocked = data.UnlockedIslands
	for _, id in ipairs(ISLAND_ORDER) do
		local free = IslandsModule.Islands[id] and IslandsModule.Islands[id].cost == 0
		local owned = typeof(unlocked) == "table" and table.find(unlocked, id) ~= nil
		if not free and not owned then
			local cost = IslandsModule.Islands[id] and IslandsModule.Islands[id].cost
			if typeof(cost) == "number" and gold >= cost then
				local entry = islandEntryById(id)
				if entry then
					tpIsland(entry)
				end
				return
			end
		end
	end
end

local function autoPlot()
	if not CFG.AutoPlot or not PlotSectionFunctions or not PlotSectionFunctions.unlockSection then
		return
	end
	for _, section in ipairs({ "Polishing", "Floor2", "Floor3", "ExtraPolishers" }) do
		pcall(function()
			PlotSectionFunctions.unlockSection:invoke(section)
		end)
	end
end

local function autoPedestal()
	if not CFG.AutoPedestal or not PedestalFunctions or not PedestalFunctions.placeItem then
		return
	end
	local data = loadedData()
	if not data or typeof(data.Inventory) ~= "table" then
		return
	end
	local bestUid, bestRank = nil, -1
	for uid, item in pairs(data.Inventory) do
		if typeof(item) == "table" and item.pedestalSlot == nil and item.dirty ~= true then
			local def = ItemsModule.Items and ItemsModule.Items[item.id]
			local rank = rarityRank(def and def.rarity)
			if rank > bestRank then
				bestRank = rank
				bestUid = item.inventoryId or uid
			end
		end
	end
	if bestUid ~= nil then
		for slot = 1, 24 do
			pcall(function()
				PedestalFunctions.placeItem:invoke(slot, bestUid)
			end)
		end
	end
end

local function autoForge()
	if not CFG.AutoForge or not ForgeFunctions then
		return
	end
	if ForgeFunctions.offerForgeItem then
		pcall(function()
			ForgeFunctions.offerForgeItem:invoke()
		end)
	end
	if ForgeFunctions.claimForgedItem then
		pcall(function()
			ForgeFunctions.claimForgedItem:invoke()
		end)
	end
end

local function wellDump()
	if CFG.WellGold <= 0 or not PyramidFunctions or not PyramidFunctions.sacrificeGold then
		return
	end
	if os.clock() - (store.lastWell or 0) < 8 then
		return
	end
	store.lastWell = os.clock()
	pcall(function()
		PyramidFunctions.sacrificeGold:invoke(CFG.WellGold)
	end)
end

local function antiAfk()
	if CFG.AntiAfk and MiscEvents and MiscEvents.AntiAFK and os.clock() - (store.lastAfk or 0) > 25 then
		store.lastAfk = os.clock()
		pcall(function()
			MiscEvents.AntiAFK:fire()
		end)
	end
	if CFG.AfkReturn and MiscFunctions and MiscFunctions.RequestAfkReturn then
		pcall(function()
			MiscFunctions.RequestAfkReturn:invoke()
		end)
	end
end

local function applyWalkSpeed()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if CFG.WalkSpeed > 0 then
		if store.origWalk == nil then
			store.origWalk = humanoid.WalkSpeed
		end
		humanoid.WalkSpeed = CFG.WalkSpeed
	elseif store.origWalk then
		humanoid.WalkSpeed = store.origWalk
	end
end

local function applyFullbright()
	if CFG.Fullbright then
		if store.origBright == nil then
			store.origBright = Lighting.Brightness
		end
		Lighting.Brightness = 4
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			atm.Density = 0
		end
	elseif store.origBright then
		Lighting.Brightness = store.origBright
	end
end

local function hideOtherPlayers()
	if not CFG.HidePlayers then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			for _, inst in ipairs(player.Character:GetDescendants()) do
				if inst:IsA("BasePart") then
					inst.LocalTransparencyModifier = 1
				elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
					inst.Enabled = false
				elseif inst:IsA("Decal") then
					inst.Transparency = 1
				end
			end
		end
	end
end

local function muteSpam()
	if not CFG.MuteSpam then
		return
	end
	SoundService.Volume = 0
end

local function hidePopups()
	if not CFG.HidePopups then
		return
	end
	local pg = playerGui()
	if not pg then
		return
	end
	local main = pg:FindFirstChild("Main")
	if not main then
		return
	end
	for _, name in ipairs({ "Shop", "Offer", "Gamepass", "Vip", "Notice", "Tutorial" }) do
		local child = main:FindFirstChild(name)
		if child and child:IsA("LayerCollector") then
			child.Enabled = false
		elseif child and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
end

local function skipTutorial()
	if not CFG.SkipTutorial then
		return
	end
	local pg = playerGui()
	if not pg then
		return
	end
	for _, child in ipairs(pg:GetChildren()) do
		local name = string.lower(child.Name)
		if string.find(name, "tutorial", 1, true) then
			if child:IsA("LayerCollector") then
				child.Enabled = false
			elseif child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end
end

local function hopServer()
	pcall(function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)
end

local function rejoinJob()
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end

if CFG.RejoinJob then
	STATE.connect(LocalPlayer.CharacterAdded, function()
		store.tweening = false
	end)
end

local function drawingNew(className)
	if typeof(Drawing) ~= "table" or typeof(Drawing.new) ~= "function" then
		return nil
	end
	local obj = Drawing.new(className)
	table.insert(store.drawings, obj)
	return obj
end

local function clearDrawings()
	for _, obj in ipairs(store.drawings) do
		pcall(function()
			obj:Remove()
		end)
	end
	table.clear(store.drawings)
end

local RARITY_COLOR = {
	common = Color3.fromRGB(200, 200, 200),
	uncommon = Color3.fromRGB(80, 220, 80),
	rare = Color3.fromRGB(70, 140, 255),
	epic = Color3.fromRGB(180, 70, 255),
	legendary = Color3.fromRGB(255, 180, 40),
	mythic = Color3.fromRGB(255, 70, 70),
	divine = Color3.fromRGB(255, 255, 140),
	eternal = Color3.fromRGB(140, 255, 255),
	anomaly = Color3.fromRGB(255, 0, 180),
	paradox = Color3.fromRGB(255, 80, 200),
	singularity = Color3.fromRGB(120, 0, 255),
	genesis = Color3.fromRGB(255, 255, 255),
}

local function worldToScreen(pos)
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local v, on = cam:WorldToViewportPoint(pos)
	if not on or v.Z < 0 then
		return nil
	end
	return Vector2.new(v.X, v.Y), v.Z
end

local function drawEsp()
	clearDrawings()
	if CFG.Humanized then
		return
	end
	local sweep = getSweep()
	if CFG.HoleESP and sweep and typeof(sweep.nodes) == "table" then
		for _, node in pairs(sweep.nodes) do
			if typeof(node) == "table" and typeof(node.position) == "Vector3" then
				local screen = worldToScreen(node.position)
				if screen then
					local text = drawingNew("Text")
					if text then
						text.Text = tostring(node.rarity or "?")
						text.Position = screen
						text.Size = 16
						text.Center = true
						text.Outline = true
						text.Color = RARITY_COLOR[node.rarity] or Color3.new(1, 1, 1)
						text.Visible = true
					end
				end
			end
		end
	end
	if CFG.MutationESP and sweep and typeof(sweep.nodes) == "table" then
		for _, node in pairs(sweep.nodes) do
			if typeof(node) == "table" and node.mutation and typeof(node.position) == "Vector3" then
				local screen = worldToScreen(node.position + Vector3.new(0, 4, 0))
				if screen then
					local text = drawingNew("Text")
					if text then
						text.Text = tostring(node.mutation)
						text.Position = screen
						text.Size = 14
						text.Center = true
						text.Outline = true
						text.Color = Color3.fromRGB(180, 255, 255)
						text.Visible = true
					end
				end
			end
		end
	end
	if CFG.PlayerESP then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local screen = worldToScreen(root.Position)
					if screen then
						local text = drawingNew("Text")
						if text then
							text.Text = player.DisplayName
							text.Position = screen
							text.Size = 14
							text.Center = true
							text.Outline = true
							text.Color = Color3.fromRGB(255, 120, 120)
							text.Visible = true
						end
					end
				end
			end
		end
	end
	if CFG.NpcESP then
		local pos = findWorldPart({ "seller", "forge", "well", "workbench", "shop" })
		if pos then
			local screen = worldToScreen(pos)
			if screen then
				local text = drawingNew("Text")
				if text then
					text.Text = "NPC"
					text.Position = screen
					text.Size = 14
					text.Center = true
					text.Outline = true
					text.Color = Color3.fromRGB(120, 255, 180)
					text.Visible = true
				end
			end
		end
	end
	if CFG.BoundsESP then
		local bounds = getZoneBounds(getHuntIslandId())
		if bounds then
			local corners = {
				Vector3.new(bounds.minX, bounds.y or 0, bounds.minZ),
				Vector3.new(bounds.maxX, bounds.y or 0, bounds.minZ),
				Vector3.new(bounds.maxX, bounds.y or 0, bounds.maxZ),
				Vector3.new(bounds.minX, bounds.y or 0, bounds.maxZ),
			}
			for i = 1, 4 do
				local a = worldToScreen(corners[i])
				local b = worldToScreen(corners[i % 4 + 1])
				if a and b then
					local line = drawingNew("Line")
					if line then
						line.From = a
						line.To = b
						line.Color = Color3.fromRGB(80, 255, 120)
						line.Thickness = 1
						line.Visible = true
					end
				end
			end
		end
	end
end

local function ensureHud()
	if not CFG.StatsHud then
		if store.hud then
			pcall(function()
				store.hud:Destroy()
			end)
			store.hud = nil
		end
		return
	end
	if store.hud and store.hud.Parent then
		return store.hud
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "InstantDigHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9999
	local label = Instance.new("TextLabel")
	label.Name = "Stats"
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	label.BorderSizePixel = 0
	label.Position = UDim2.fromOffset(12, 70)
	label.Size = UDim2.fromOffset(320, 86)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = gui
	local parent = playerGui()
	if typeof(gethui) == "function" then
		pcall(function()
			gui.Parent = gethui()
		end)
	end
	if not gui.Parent and parent then
		gui.Parent = parent
	end
	store.hud = gui
	return gui
end

local function updateHud()
	local gui = ensureHud()
	if not gui then
		return
	end
	local label = gui:FindFirstChild("Stats")
	if not label then
		return
	end
	local data = loadedData()
	local gold = data and data.Gold or 0
	if store.sessionGold0 == nil then
		store.sessionGold0 = gold
	end
	local elapsed = math.max(1, os.clock() - (store.sessionStart or os.clock()))
	local gained = gold - (store.sessionGold0 or gold)
	local perHour = gained / elapsed * 3600
	local n, cap = backpackCount(data)
	local rain, meteor = weatherActive()
	local luck = math.max(store.serverLuck or 1, store.friendLuck or 1)
	label.Text = string.format(
		"Gold %s  (%s/hr)\nBackpack %d/%d  Digs %d\nLuck x%.2f  %s%s\nIsland %s  %s %s",
		tostring(math.floor(gold)),
		tostring(math.floor(perHour)),
		n,
		cap,
		store.sessionDigs or 0,
		luck,
		rain and "RAIN " or "",
		meteor and "METEOR" or "",
		tostring(getHuntIslandId() or "?"),
		CFG.MinRarity,
		CFG.Enabled and "DIG" or "dig-off"
	)
end

local function collectionText()
	local data = loadedData()
	local have, total = 0, 0
	if ItemsModule.Items then
		for id in pairs(ItemsModule.Items) do
			total = total + 1
			if collectionHas(data, id) then
				have = have + 1
			end
		end
	end
	return have .. "/" .. total
end

local lastEsp = 0
local lastHud = 0

local function tickHub()
	local now = os.clock()
	if not CFG.Enabled and not CFG.AutoSell and not CFG.AntiAfk and not CFG.HoleESP and not CFG.StatsHud and not CFG.AutoCodes and not CFG.AutoQuests and not CFG.AutoBestGear and not CFG.Fullbright and not CFG.HidePlayers then
		if store.hud then
			pcall(function()
				store.hud:Destroy()
			end)
			store.hud = nil
		end
		if store.drawings and #store.drawings > 0 then
			clearDrawings()
		end
		return
	end
	if now - (store.lastHub or 0) < 0.35 then
		if CFG.HoleESP or CFG.PlayerESP or CFG.NpcESP or CFG.BoundsESP then
			if now - lastEsp > 0.12 then
				lastEsp = now
				drawEsp()
			end
		end
		return
	end
	store.lastHub = now
	antiAfk()
	applyWalkSpeed()
	applyFullbright()
	hideOtherPlayers()
	muteSpam()
	hidePopups()
	skipTutorial()
	redeemCodes()
	claimQuests()
	if now - (store.lastLuck or 0) > 8 then
		store.lastLuck = now
		claimLuck()
		local luck = currentLuck()
		if store.shownLuck ~= luck and luck > 1.05 then
			store.shownLuck = luck
			notify("Luck x" .. string.format("%.2f", luck), "Pop", "Blue")
			local rain, meteor = weatherActive()
			if rain then
				notify("Rain luck", "Pop", "Blue")
			end
			if meteor then
				notify("Meteor shower", "Pop", "Blue")
			end
		end
	end
	if now - (store.lastGearBuy or 0) > 7 then
		store.lastGearBuy = now
		autoBuyGear()
		autoUnlockIsland()
		autoPlot()
		autoForge()
		wellDump()
	end
	if now - (store.lastPedestal or 0) > 20 then
		store.lastPedestal = now
		autoPedestal()
	end
	local data = loadedData()
	store.packFull = backpackFull(data)
	local n, cap = backpackCount(data)
	if CFG.StopWhenFull and backpackFull(data) then
		if CFG.SellWhenFull then
			sellDump()
		end
	elseif n >= cap - 2 and CFG.AutoSell then
		notify("Backpack almost full", "Pop", "Orange")
		if CFG.SellWhenFull then
			sellDump()
		end
	end
	if CFG.HopNoFindMinutes > 0 and (now - (store.lastFindAt or now)) / 60 >= CFG.HopNoFindMinutes then
		store.lastFindAt = now
		cycleIsland(1)
	end
	if CFG.WeatherHop then
		local rain, meteor = weatherActive()
		if not rain and not meteor and now - (store.lastWeatherHop or 0) > 45 then
			store.lastWeatherHop = now
			hopServer()
		end
	end
	if CFG.LowPlayerHop and #Players:GetPlayers() > CFG.LowPlayerMax and now - (store.lastPlayerHop or 0) > 60 then
		store.lastPlayerHop = now
		hopServer()
	end
	if store.pendingWebhook then
		maybeWebhookRare(store.pendingWebhook)
		store.pendingWebhook = nil
	end
	if CFG.WebhookHourly and now - (store.lastWebhookHour or now) > 3600 then
		store.lastWebhookHour = now
		local gold = data and data.Gold or 0
		sendWebhook("Hourly", "Gold " .. tostring(gold) .. "  digs " .. tostring(store.sessionDigs or 0))
	end
	if not CFG.Enabled and now - (store.lastOffNudge or 0) > 45 then
		store.lastOffNudge = now
		notify("Instant Dig is OFF", "Pop", "Orange")
	end
	if CFG.MinLuckToDig > 0 then
		local luck = math.max(store.serverLuck or 1, store.friendLuck or 1)
		store.blockDigLuck = luck < CFG.MinLuckToDig
	else
		store.blockDigLuck = false
	end
	if now - lastHud > 0.4 then
		lastHud = now
		updateHud()
	end
	if now - lastEsp > 0.12 then
		lastEsp = now
		drawEsp()
	end
	if now - (store.lastCfgSave or 0) > 12 then
		store.lastCfgSave = now
		saveCfg()
	end
end

if LuckEvents and LuckEvents.ServerLuckChanged then
	pcall(function()
		LuckEvents.ServerLuckChanged:connect(function(info)
			if typeof(info) == "table" and typeof(info.multiplier) == "number" then
				store.serverLuck = info.multiplier
				notify("Server luck x" .. tostring(info.multiplier), "Pop", "Blue")
			end
		end)
	end)
end

if MiscEvents then
	pcall(function()
		if MiscEvents.PlayRainAnnouncement then
			MiscEvents.PlayRainAnnouncement:connect(function()
				notify("Rain started", "Pop", "Blue")
			end)
		end
		if MiscEvents.PlayMeteorShowerAnnouncement then
			MiscEvents.PlayMeteorShowerAnnouncement:connect(function()
				notify("Meteor shower", "Pop", "Blue")
			end)
		end
	end)
end

if typeof(STATE.onCleanup) == "function" then
	STATE.onCleanup(function()
		clearDrawings()
		if store.hud then
			pcall(function()
				store.hud:Destroy()
			end)
			store.hud = nil
		end
		saveCfg()
	end)
end

if CFG.RangeMult > 1 then
	boostDetectorRange()
end
if CFG.HideClan then
	hideClanSigns()
end

STATE.connect(RunService.Heartbeat, function()
	if CFG.RangeMult > 1 and not CFG.Humanized then
		boostDetectorRange()
	end
	if CFG.HideClan then
		hideClanSigns()
	end
	if CFG.BackgroundClean then
		hideCleanUi()
	end
	tickHub()
	if CFG.AutoBestGear then
		equipBestGear(false)
	end
	if CFG.BackgroundClean then
		backgroundClean()
	end
	local wb = getWorkbench()
	local dig = getDig()
	if dig and dig.session then
		store.hadDig = true
	elseif store.hadDig then
		store.hadDig = false
		store.digEndedAt = os.clock()
	end
	local busyClean = false
	if wb then
		if not CFG.BackgroundClean then
			patchFastClean(wb)
			recoverStuckClean(wb)
			busyClean = tryAutoClean(wb, dig)
		end
		instantClean(wb)
	end
	if not CFG.Enabled then
		return
	end
	if not dig then
		return
	end
	local session = dig.session
	if typeof(session) == "table" then
		stopPowerAtPeak(dig, session)
		skipReveal(session)
		finishMinigame(dig, session)
	elseif not busyClean then
		tryAutoDig(dig)
	end
end)

STATE.connect(UserInputService.InputBegan, function(input, gpe)
	if gpe then
		return
	end
	if os.clock() - store.bootAt < 0.5 then
		return
	end
	if input.KeyCode == CFG.ToggleKey then
		CFG.Enabled = not CFG.Enabled
		notify(
			CFG.Enabled and "Instant Dig ON" or "Instant Dig OFF",
			"Pop",
			CFG.Enabled and "Green" or "Red"
		)
	elseif input.KeyCode == CFG.AutoDigKey then
		CFG.AutoDig = not CFG.AutoDig
		notify(
			CFG.AutoDig and "AutoDig ON" or "AutoDig OFF",
			"Pop",
			CFG.AutoDig and "Blue" or "Orange"
		)
	elseif input.KeyCode == CFG.CleanKey then
		CFG.CleanEnabled = not CFG.CleanEnabled
		notify(
			CFG.CleanEnabled and "Instant Clean ON" or "Instant Clean OFF",
			"Pop",
			CFG.CleanEnabled and "Green" or "Red"
		)
	elseif input.KeyCode == CFG.AutoCleanKey then
		CFG.AutoClean = not CFG.AutoClean
		notify(
			CFG.AutoClean and "AutoClean ON" or "AutoClean OFF",
			"Pop",
			CFG.AutoClean and "Blue" or "Orange"
		)
	elseif input.KeyCode == CFG.HideClanKey then
		CFG.BackgroundClean = not CFG.BackgroundClean
		notify(
			CFG.BackgroundClean and "Background Clean ON" or "Background Clean OFF",
			"Pop",
			CFG.BackgroundClean and "Green" or "Red"
		)
		if CFG.BackgroundClean then
			hideCleanUi()
		end
	elseif input.KeyCode == CFG.BestGearKey then
		CFG.AutoBestGear = true
		store.lastGear = 0
		equipBestGear(true)
	elseif input.KeyCode == CFG.NextIslandKey then
		cycleIsland(1)
	elseif input.KeyCode == CFG.PrevIslandKey then
		cycleIsland(-1)
	end
end)

notify(
	"Instant Dig+Clean  RightShift UI  [F][G] dig  [C][V] clean  [H] hide  [B] best  [T/Y] island",
	"Pop",
	"Green"
)

local WINDUI_PATHS = {
	[[C:\Users\gyhdgsg\AppData\Local\Real\workspace\WindUI.lua]],
	[[C:\Users\gyhdgsg\AppData\Local\Real\scripts\MCP\WindUI.lua]],
	[[C:\Users\gyhdgsg\Desktop\roblox script\WindUI-main\WindUI-main\dist\main.lua]],
}

local function loadWindUI()
	for _, path in ipairs(WINDUI_PATHS) do
		if typeof(isfile) == "function" and isfile(path) then
			local ok, src = pcall(readfile, path)
			if ok and typeof(src) == "string" then
				local fn = loadstring(src, "@WindUI")
				if fn then
					return fn()
				end
			end
		end
	end
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
	end)
	if ok and lib then
		return lib
	end
	error("WindUI not found")
end

local WindUI = loadWindUI()

do
	local g = genv()
	if g.__InstantDigWindow then
		pcall(function()
			g.__InstantDigWindow:Destroy()
		end)
		g.__InstantDigWindow = nil
	end
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end

local ISLAND_LABELS = {
	starterIsland = "Home Beach",
	island2 = "Shipwreck Cove",
	island3 = "Sphinx Sands",
	island4 = "Frozen Shores",
	island5 = "Lava Lagoon",
	island6 = "Paradise Point",
	island7 = "Tombstone Tides",
}

local islandNames = {}
for _, id in ipairs(ISLAND_ORDER) do
	table.insert(islandNames, ISLAND_LABELS[id] or id)
end

local function islandByLabel(label)
	local id = nil
	for key, name in pairs(ISLAND_LABELS) do
		if name == label then
			id = key
			break
		end
	end
	if not id then
		return nil
	end
	local list = islandList()
	if list then
		for _, entry in ipairs(list) do
			if entry.id == id then
				return entry
			end
		end
	end
	return { id = id, name = label }
end

local function lockHuntIsland(entry, doTp)
	if not entry then
		return
	end
	store.huntIslandId = entry.id
	store.patrolIndex = 0
	store.bounds = nil
	if doTp then
		tpIsland(entry)
	end
end

local huntDefault = ISLAND_LABELS[getHuntIslandId()] or islandNames[1]

local Window = WindUI:CreateWindow({
	Title = "Dig & Clean",
	Author = "Instant Dig + Clean",
	Folder = "InstantDigClean",
	Icon = "pickaxe",
	NewElements = true,
	Theme = "Dark",
	Size = UDim2.fromOffset(600, 520),
	HideSearchBar = true,
	OpenButton = {
		Title = "Dig",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		OnlyIcon = true,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#7CFF6B"), Color3.fromHex("#4D9FFF")),
	},
})

pcall(function()
	genv().__InstantDigWindow = Window
end)
pcall(function()
	Window:SetToggleKey(Enum.KeyCode.RightShift)
end)

local DigSec = Window:Section({ Title = "Farm", Opened = true })
local DigTab = DigSec:Tab({ Title = "Dig", Icon = "pickaxe" })
local CleanTab = DigSec:Tab({ Title = "Clean", Icon = "droplets" })
local WorldTab = DigSec:Tab({ Title = "World", Icon = "globe" })
local SellTab = DigSec:Tab({ Title = "Sell", Icon = "coins" })
local LuckTab = DigSec:Tab({ Title = "Luck", Icon = "sparkles" })
local VisualTab = DigSec:Tab({ Title = "Visual", Icon = "eye" })
local StatsTab = DigSec:Tab({ Title = "Stats", Icon = "chart" })

DigTab:Paragraph({
	Title = "Instant Dig",
	Desc = "Pick one island. Autodig stays there, tweens along the shore, and only digs the rarity you pick.",
})

DigTab:Toggle({
	Title = "Instant Dig",
	Desc = "Skip power meter + shovel minigame",
	Value = CFG.Enabled,
	Callback = function(state)
		CFG.Enabled = state and true or false
	end,
})

DigTab:Toggle({
	Title = "Auto Dig",
	Desc = "Keep digging. Hunts good trails when enabled.",
	Value = CFG.AutoDig,
	Callback = function(state)
		CFG.AutoDig = state and true or false
	end,
})

DigTab:Toggle({
	Title = "Max Luck Power",
	Desc = "Stop the power bar on the 5x luck peak",
	Value = CFG.MaxLuck,
	Callback = function(state)
		CFG.MaxLuck = state and true or false
	end,
})

DigTab:Toggle({
	Title = "Hunt Trails",
	Desc = "Stay on the selected island. Walk the edge. Dig when that trail shows up.",
	Value = CFG.HuntTrails,
	Callback = function(state)
		CFG.HuntTrails = state and true or false
	end,
})

DigTab:Dropdown({
	Title = "Rarity Mode",
	Desc = "min = this rarity and better. exact = only this rarity.",
	Values = { "min", "exact" },
	Value = CFG.RarityMode,
	Callback = function(selected)
		if typeof(selected) == "string" then
			CFG.RarityMode = selected
		end
	end,
})

DigTab:Dropdown({
	Title = "Trail to Dig",
	Desc = "Only this rarity. Other holes are ignored.",
	Values = RARITY_ORDER,
	Value = CFG.MinRarity,
	Callback = function(selected)
		if typeof(selected) == "string" then
			CFG.MinRarity = selected
		end
	end,
})

DigTab:Dropdown({
	Title = "Island",
	Desc = "Stay on this one island. Tween along the edge until the trail is found.",
	Values = islandNames,
	Value = huntDefault,
	Callback = function(selected)
		local entry = islandByLabel(selected)
		lockHuntIsland(entry, os.clock() - store.bootAt >= 1)
	end,
})

DigTab:Slider({
	Title = "Tween Speed",
	Desc = "Studs per second along the island edge",
	Value = { Min = 30, Max = 180, Default = CFG.TweenSpeed },
	Callback = function(value)
		CFG.TweenSpeed = tonumber(value) or CFG.TweenSpeed
	end,
})

DigTab:Slider({
	Title = "Edge Inset",
	Desc = "How far inland from the water while walking the shore",
	Value = { Min = 4, Max = 40, Default = CFG.EdgeInset },
	Callback = function(value)
		CFG.EdgeInset = tonumber(value) or CFG.EdgeInset
	end,
})

DigTab:Slider({
	Title = "Detector Range x",
	Value = { Min = 1, Max = 100, Default = CFG.RangeMult },
	Callback = function(value)
		CFG.RangeMult = math.max(1, tonumber(value) or CFG.RangeMult)
		boostDetectorRange()
	end,
})

CleanTab:Toggle({
	Title = "Instant Clean",
	Desc = "Skip-clean remote + forceFinish fallback",
	Value = CFG.CleanEnabled,
	Callback = function(state)
		CFG.CleanEnabled = state and true or false
	end,
})

CleanTab:Toggle({
	Title = "Auto Clean",
	Desc = "Clean dirty items automatically",
	Value = CFG.AutoClean,
	Callback = function(state)
		CFG.AutoClean = state and true or false
	end,
})

CleanTab:Toggle({
	Title = "Clean in Background",
	Desc = "Skip the workbench screen. Cleans from backpack while you keep digging.",
	Value = CFG.BackgroundClean,
	Callback = function(state)
		CFG.BackgroundClean = state and true or false
		if CFG.BackgroundClean then
			hideCleanUi()
		end
	end,
})

WorldTab:Toggle({
	Title = "Hide Group Signs",
	Desc = "Fade Join Group boards into the map",
	Value = CFG.HideClan,
	Callback = function(state)
		CFG.HideClan = state and true or false
		if CFG.HideClan then
			store.lastHide = 0
			hideClanSigns()
		end
	end,
})

WorldTab:Toggle({
	Title = "Auto Best Gear",
	Desc = "Keep the highest-price shovel, detector, and spray equipped",
	Value = CFG.AutoBestGear,
	Callback = function(state)
		CFG.AutoBestGear = state and true or false
		if CFG.AutoBestGear then
			store.lastGear = 0
			equipBestGear(true)
		end
	end,
})

WorldTab:Button({
	Title = "Equip Best Price Gear Now",
	Icon = "sparkles",
	Callback = function()
		store.lastGear = 0
		equipBestGear(true)
	end,
})

WorldTab:Dropdown({
	Title = "Island",
	Desc = "Same picker. Stay here and walk the edge while hunting.",
	Values = islandNames,
	Value = huntDefault,
	Callback = function(selected)
		local entry = islandByLabel(selected)
		lockHuntIsland(entry, os.clock() - store.bootAt >= 1)
	end,
})

WorldTab:Button({
	Title = "Next Island",
	Callback = function()
		cycleIsland(1)
	end,
})

WorldTab:Button({
	Title = "Previous Island",
	Callback = function()
		cycleIsland(-1)
	end,
})

WorldTab:Paragraph({
	Title = "Hotkeys",
	Desc = "RightShift menu · F dig · G autodig · C clean · V autoclean · H hide clan · B best gear · T/Y island",
})

local function flagToggle(tab, title, key, desc)
	tab:Toggle({
		Title = title,
		Desc = desc,
		Value = CFG[key],
		Callback = function(state)
			CFG[key] = state and true or false
			saveCfg()
		end,
	})
end

flagToggle(DigTab, "Tween to hole", "TweenToHole", "Off = instant TP onto the trail")
flagToggle(DigTab, "Random edge", "RandomEdge", "Jitter the shore path")
flagToggle(DigTab, "Water rescue", "WaterRescue", "Pull inland if you hit water")
flagToggle(DigTab, "Pause near players", "PauseNearPlayers", "Stop hunt if someone is close")
flagToggle(DigTab, "Island rarity auto", "IslandRarityAuto", "Tombstone uses anomaly, etc")
flagToggle(DigTab, "Stop when backpack full", "StopWhenFull", "Pause digs until you sell")
flagToggle(DigTab, "Farm weather", "FarmWeather", "Stay when rain/meteor is up")
flagToggle(DigTab, "Humanized", "Humanized", "x1 range, slower tween, no noclip")

SellTab:Dropdown({
	Title = "Sell below",
	Desc = "Dump everything cheaper than this rarity. Favorites are kept.",
	Values = RARITY_ORDER,
	Value = CFG.SellBelow,
	Callback = function(selected)
		if typeof(selected) == "string" then
			CFG.SellBelow = selected
		end
	end,
})
flagToggle(SellTab, "Auto sell", "AutoSell", "Favorite keepers, then sellInventory")
flagToggle(SellTab, "Sell when full", "SellWhenFull", "Dump junk in place. No teleport.")
flagToggle(SellTab, "Keep mutations", "KeepMutations", "Never sell lunar/meteorite")
flagToggle(SellTab, "Keep new index", "KeepNewIndex", "Keep items you have not collected")
flagToggle(SellTab, "Keep one of each", "KeepOneEach", "Sell duplicates only")
flagToggle(SellTab, "Auto favorite", "AutoFavorite", "Star keepers before selling")
SellTab:Button({
	Title = "Sell junk now",
	Callback = function()
		sellDump()
	end,
})

flagToggle(LuckTab, "Auto codes", "AutoCodes", "Try known codes once per session")
flagToggle(LuckTab, "Auto quests", "AutoQuests", "Claim finished daily quests")
flagToggle(LuckTab, "Group luck", "AutoGroupLuck", "claimGroupReward  +2x / 30 min")
flagToggle(LuckTab, "Ad luck", "AutoAdLuck", "RequestAdReward")
flagToggle(LuckTab, "Peak only with luck buff", "MaxLuckOnlyWithBuff", "Skip 5x wait unless server luck is up")
LuckTab:Button({
	Title = "Claim all luck",
	Desc = "Group 2x, ad luck, codes, quests, and lock dig power on 5x. Luck is server-side — this claims the real buffs.",
	Callback = function()
		boostLuckNow()
	end,
})
LuckTab:Slider({
	Title = "Min luck to dig",
	Value = { Min = 0, Max = 10, Default = CFG.MinLuckToDig },
	Callback = function(value)
		CFG.MinLuckToDig = tonumber(value) or 0
	end,
})
LuckTab:Slider({
	Title = "Well gold dump",
	Desc = "0 = off. Sacrifices this much to the Well of the Gods.",
	Value = { Min = 0, Max = 50000, Default = CFG.WellGold },
	Callback = function(value)
		CFG.WellGold = tonumber(value) or 0
	end,
})

flagToggle(WorldTab, "Auto buy shovel", "AutoBuyShovel", "Buy next cheapest owned-missing shovel")
flagToggle(WorldTab, "Auto buy detector", "AutoBuyDetector", "Buy next cheapest detector")
flagToggle(WorldTab, "Auto buy spray", "AutoBuySpray", "Buy next cheapest spray")
flagToggle(WorldTab, "Prefer Horus gear", "PreferHorus", "Equip Horus over highest cost")
flagToggle(WorldTab, "Auto unlock island", "AutoUnlockIsland", "Travel to next island you can afford")
flagToggle(WorldTab, "Auto plot", "AutoPlot", "unlockSection Polishing/Floors")
flagToggle(WorldTab, "Auto pedestal", "AutoPedestal", "Place best item on an empty slot")
flagToggle(WorldTab, "Auto forge", "AutoForge", "offerForgeItem + claim")
flagToggle(WorldTab, "Anti AFK", "AntiAfk", "MiscEvents.AntiAFK every 25s")
flagToggle(WorldTab, "AFK return", "AfkReturn", "RequestAfkReturn")
flagToggle(WorldTab, "Rejoin same job on respawn", "RejoinJob", "Keeps this server")
flagToggle(WorldTab, "Weather hop", "WeatherHop", "Teleport if no rain/meteor")
flagToggle(WorldTab, "Low player hop", "LowPlayerHop", "Hop if the server is crowded")
WorldTab:Button({
	Title = "Copy jobId",
	Callback = function()
		local id = tostring(game.JobId)
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, id)
		end
		notify(id, "Pop", "Blue")
	end,
})
WorldTab:Button({
	Title = "Hop server",
	Callback = function()
		hopServer()
	end,
})
WorldTab:Button({
	Title = "Rejoin this job",
	Callback = function()
		rejoinJob()
	end,
})

flagToggle(VisualTab, "Hole ESP", "HoleESP", "Rarity labels on buried trails")
flagToggle(VisualTab, "Mutation ESP", "MutationESP", "lunar / meteorite tags")
flagToggle(VisualTab, "Player ESP", "PlayerESP", "Other players")
flagToggle(VisualTab, "NPC ESP", "NpcESP", "Seller / forge / well")
flagToggle(VisualTab, "Island bounds ESP", "BoundsESP", "Dig-zone rectangle")
flagToggle(VisualTab, "Stats HUD", "StatsHud", "Gold, backpack, luck, weather")
flagToggle(VisualTab, "Fullbright", "Fullbright", "No fog")
flagToggle(VisualTab, "Hide players", "HidePlayers", "Local transparency")
flagToggle(VisualTab, "Mute spam", "MuteSpam", "SoundService volume 0")
flagToggle(VisualTab, "Hide popups", "HidePopups", "Shop / offer / tutorial")
flagToggle(VisualTab, "Skip tutorial", "SkipTutorial", "Hide tutorial UI")
flagToggle(VisualTab, "Noclip while tween", "NoclipTween", "No snag on rocks")
VisualTab:Slider({
	Title = "Walkspeed",
	Desc = "0 = leave the game speed alone",
	Value = { Min = 0, Max = 80, Default = CFG.WalkSpeed },
	Callback = function(value)
		CFG.WalkSpeed = tonumber(value) or 0
	end,
})

StatsTab:Paragraph({
	Title = "Session",
	Desc = "HUD shows gold/hr, backpack, luck, weather. Config saves every 12s.",
})
StatsTab:Button({
	Title = "Gold farm profile",
	Callback = function()
		applyGoldFarm()
		saveCfg()
	end,
})
StatsTab:Button({
	Title = "Rare farm profile",
	Callback = function()
		applyRareFarm()
		saveCfg()
	end,
})
StatsTab:Button({
	Title = "Humanized profile",
	Callback = function()
		applyHumanized()
		saveCfg()
	end,
})
StatsTab:Button({
	Title = "Save config",
	Callback = function()
		saveCfg()
		notify("Config saved", "Pop", "Green")
	end,
})
pcall(function()
	StatsTab:Input({
		Title = "Discord webhook",
		Placeholder = "https://discord.com/api/webhooks/...",
		Value = CFG.Webhook,
		Callback = function(text)
			CFG.Webhook = tostring(text or "")
			saveCfg()
		end,
	})
end)
flagToggle(StatsTab, "Webhook rares", "WebhookRares", "Post mythic+ trails")
flagToggle(StatsTab, "Webhook hourly", "WebhookHourly", "Gold + digs once an hour")
StatsTab:Button({
	Title = "Collection count",
	Callback = function()
		notify("Index " .. collectionText(), "Pop", "Blue")
	end,
})

store.window = Window

if typeof(STATE.onCleanup) == "function" then
	STATE.onCleanup(function()
		cancelTween()
		if store.window then
			pcall(function()
				store.window:Destroy()
			end)
			store.window = nil
		end
		local g = genv()
		if g.__InstantDigWindow then
			pcall(function()
				g.__InstantDigWindow:Destroy()
			end)
			g.__InstantDigWindow = nil
		end
	end)
end

pcall(function()
	WindUI:Notify({
		Title = "Dig & Clean",
		Content = "UI ready. RightShift to toggle.",
		Duration = 3,
	})
end)

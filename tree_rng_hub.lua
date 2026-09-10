--[[
  Tree RNG Hub - WindUI (local)
  Loads WindUI from Desktop/roblox script/WindUI-main

  Prefer Real live-reload (label tree_rng_hub) — STATE is injected into the
  chunk env. If missing (Execute / plain loadstring), a local shim is used.
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
		-- used only by shim path if something wants to tear down
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
	-- live-reload usually sets the chunk env (getfenv(1)); thread env is (0)
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

local WindUI = loadWindUI()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Networking = ReplicatedStorage:WaitForChild("Networking")
local Events = Networking:WaitForChild("Events")
local Requests = Networking:WaitForChild("Requests")

local FishingState = Events:WaitForChild("FishingState")
local RodAction = Requests:WaitForChild("RodAction")
local SellFish = Requests:WaitForChild("SellFish")
local RequestFishInventory = Requests:WaitForChild("RequestFishInventory")
local ToggleFishLock = Requests:WaitForChild("ToggleFishLock")
local AutoPlaceBest = Requests:WaitForChild("AutoPlaceBest")
local UnequipAll = Requests:WaitForChild("UnequipAll")
local FisherKiosk = Requests:WaitForChild("FisherKiosk")
local FishGearAction = Requests:WaitForChild("FishGearAction")

local AutoRollState = Events:WaitForChild("AutoRollState")
local TeleportHome = Events:WaitForChild("TeleportHome")
local CollectItem = Events:WaitForChild("CollectItem")
local CollectLeafGen = Events:WaitForChild("CollectLeafGen")
local ToggleLeafGenOverclock = Events:FindFirstChild("ToggleLeafGenOverclock")
local FeedLeafGenMoney = Events:FindFirstChild("FeedLeafGenMoney")
local DockAquariumAdd = Events:WaitForChild("DockAquariumAdd")
local DockAquariumCollect = Events:WaitForChild("DockAquariumCollect")
local DockAquariumRemove = Events:WaitForChild("DockAquariumRemove")
local FisherCrewSync = Events:WaitForChild("FisherCrewSync")
local FisherWage = Events:WaitForChild("FisherWage")

local ClaimSeasonTier = Requests:WaitForChild("ClaimSeasonTier")
local RequestSeasonPass = Requests:WaitForChild("RequestSeasonPass")
local CollectHoneyFruit = Requests:WaitForChild("CollectHoneyFruit")
local CollectTransientMutation = Requests:WaitForChild("CollectTransientMutation")
local EnchantAction = Requests:WaitForChild("EnchantAction")
local PetIncubatorAction = Requests:WaitForChild("PetIncubatorAction")
local GiraffeGrab = Requests:WaitForChild("GiraffeGrab")
local GiraffeClaim = Requests:WaitForChild("GiraffeClaim")
local GiraffeCarry = Requests:FindFirstChild("GiraffeCarry")
local HatchEgg = Requests:FindFirstChild("HatchEgg")
local RequestSnailEggs = Requests:FindFirstChild("RequestSnailEggs")

local HoneyFruitSync = Events:WaitForChild("HoneyFruitSync")
local TransientMutationSync = Events:WaitForChild("TransientMutationSync")
local OfflineEarnings = Events:WaitForChild("OfflineEarnings")
local ChestEvent = Events:WaitForChild("ChestEvent")
local EnchantAuto = Events:FindFirstChild("EnchantAuto")
local GiraffeFetch = Events:FindFirstChild("GiraffeFetch")
local HoneyObbyProgress = Events:FindFirstChild("HoneyObbyProgress")
local HoneyObbyChest = Events:FindFirstChild("HoneyObbyChest")
local HoneyObbyFinish = Events:FindFirstChild("HoneyObbyFinish")
local MushroomChestOpen = Events:FindFirstChild("MushroomChestOpen")
local IncubatorCycle = Events:FindFirstChild("IncubatorCycle")
local PetIncubated = Events:FindFirstChild("PetIncubated")
local PlaceBaitBucket = Events:FindFirstChild("PlaceBaitBucket")
local SetPlayerSetting = Events:FindFirstChild("SetPlayerSetting")

local Merchant = ReplicatedStorage.Networking:FindFirstChild("Merchant")
local UseConsumable = Merchant and Merchant:FindFirstChild("UseConsumable")
local RequestConsumableInventory = Requests:FindFirstChild("RequestConsumableInventory")
local RequestActivePotions = Requests:FindFirstChild("RequestActivePotions")

local FishDictionary = require(ReplicatedStorage:WaitForChild("FishDictionary"))
local SeasonPassConfig = require(ReplicatedStorage:WaitForChild("SeasonPassConfig"))
local ConsumableDictionary = require(ReplicatedStorage:WaitForChild("ConsumableDictionary"))

-- persistent across live-reload
if not STATE.store then
	STATE.store = {
		lastCast = 0,
		lastReel = 0,
		esp = {},
		honeyKnown = {},
		mutSlots = {},
		giraffePending = {},
		lastOfflineClaim = 0,
		lastIncubFeed = 0,
	}
end
local store = STATE.store
store.honeyKnown = store.honeyKnown or {}
store.mutSlots = store.mutSlots or {}
store.giraffePending = store.giraffePending or {}

local CFG = {
	InstantFish = true,
	AutoCast = true,
	CastPower = 1,
	CastCooldown = 0.35,
	AutoSell = false,
	SellOnCatch = false,
	AutoSellDelay = 2,
	LockMinTier = 4,
	AutoLock = false,
	AutoRoll = false,
	HideRollFx = true,
	AutoCollectDrops = true,
	AutoLeafGen = true,
	InstantLeafGen = true,
	LeafGenEvery = 0.75,
	AutoLeafGenFeed = true,
	AutoLeafGenOverclock = true,
	-- LeafGeneratorClient buttons: +1B / +10B / Fill
	LeafGenFeedAmount = 1e15,
	LeafGenMinRuntime = 600,
	AutoSeasonClaim = true,
	SeasonClaimEvery = 2,
	InstantHoney = true,
	InstantMutations = true,
	AutoOfflineClaim = true,
	AutoChests = true,
	AutoEnchant = false,
	EnchantTargetId = (FishDictionary.EnchantOrder and FishDictionary.EnchantOrder[1]) or "Swift",
	EnchantTargetTier = 3,
	AutoEggs = false,
	AutoIncubator = false,
	AutoGiraffe = true,
	WatchHoneyObby = true,
	AutoLuckPotions = true,
	AutoFishBait = true,
	AutoBaitBucket = true,
	ForceFullLuck = true,
	PreferLuckPotion = "Luck I Potion",
	AutoFisherCollect = true,
	AutoFisherOptimize = true,
	AutoFisherResume = true,
	InstantNpcFishers = true,
	MinFisherSpeed = 90,
	FisherCollectEvery = 5,
	FisherResumeEvery = 1.5,
	EspPlayers = false,
	EspFishSpots = false,
	Silent = true, -- no auto notify/print yap; UI starts closed
}

local function notify(title, dur)
	pcall(function()
		WindUI:Notify({
			Title = "Tree RNG Hub",
			Content = title,
			Duration = dur or 3,
		})
	end)
end

-- background loops use this — muted when Silent
local function notifyAuto(title, dur)
	if CFG.Silent then
		return
	end
	notify(title, dur)
end

local function island()
	return Workspace.PlayerIslands:FindFirstChild(LocalPlayer.Name .. "_Island")
end

local function fishSpotCFrame()
	local isl = island()
	if not isl then
		return nil
	end
	local spot = isl:FindFirstChild("BackOffshoot") and isl.BackOffshoot:FindFirstChild("FishingSpot")
	if spot then
		return spot.CFrame + Vector3.new(0, 3, 0)
	end
	return nil
end

local function tp(cf)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and cf then
		hrp.CFrame = cf
	end
end

local function doReel()
	local now = os.clock()
	if now - store.lastReel < 0.08 then
		return
	end
	store.lastReel = now
	task.spawn(function()
		pcall(function()
			RodAction:InvokeServer("reel")
		end)
	end)
end

local function doCast()
	if not CFG.InstantFish or not CFG.AutoCast then
		return
	end
	if Workspace:GetAttribute("FishingEnabled") == false then
		return
	end
	local now = os.clock()
	if now - store.lastCast < CFG.CastCooldown then
		return
	end
	store.lastCast = now
	task.spawn(function()
		pcall(function()
			RodAction:InvokeServer("cast", CFG.CastPower)
		end)
	end)
end

local function getFishInv()
	local ok, res = pcall(function()
		return RequestFishInventory:InvokeServer()
	end)
	if ok and typeof(res) == "table" then
		return res
	end
	return {}
end

local function sellAll()
	local ok, err = pcall(function()
		SellFish:InvokeServer("all")
	end)
	notify(ok and "Sold all fish" or ("Sell failed: " .. tostring(err)))
end

local function sellDailyDeal()
	local ok, res = pcall(function()
		return SellFish:InvokeServer("dailydeal")
	end)
	if ok and typeof(res) == "table" and res.status == "ok" then
		notify("Daily deal claimed")
	else
		notify("Daily deal unavailable")
	end
end

local function sellUnlocked()
	local inv = getFishInv()
	local n = 0
	-- sell high index first so indices stay valid longer
	table.sort(inv, function(a, b)
		return (a.Index or 0) > (b.Index or 0)
	end)
	for _, fish in ipairs(inv) do
		if not fish.Locked then
			pcall(function()
				SellFish:InvokeServer({ index = fish.Index, name = fish.Name })
			end)
			n += 1
			task.wait(0.05)
		end
	end
	notify("Sold " .. n .. " unlocked fish")
end

local function lockHighTier()
	local inv = getFishInv()
	local n = 0
	for _, fish in ipairs(inv) do
		local def = FishDictionary.Fish[fish.Name]
		local tier = def and def.Tier or 0
		local want = tier >= CFG.LockMinTier or fish.Percentile and fish.Percentile >= 95
		if want and not fish.Locked then
			pcall(function()
				ToggleFishLock:InvokeServer(fish.Index)
			end)
			n += 1
			task.wait(0.05)
		end
	end
	notify("Locked " .. n .. " fish (tier>=" .. CFG.LockMinTier .. " / top %)")
end

local function dumpAquarium()
	local inv = getFishInv()
	local n = 0
	for _, fish in ipairs(inv) do
		if not fish.Locked then
			pcall(function()
				DockAquariumAdd:FireServer(fish.Index)
			end)
			n += 1
			task.wait(0.08)
		end
	end
	notify("Sent " .. n .. " fish to aquarium")
end

local function collectAquarium()
	pcall(function()
		DockAquariumCollect:FireServer()
	end)
	notify("Aquarium collect fired")
end

local function fisherState()
	local ok, res = pcall(function()
		return FisherKiosk:InvokeServer("state")
	end)
	if ok and typeof(res) == "table" then
		return res
	end
	return nil
end

local function fisherUnpauseAll(silent)
	local state = fisherState()
	if not state or not state.hired then
		return 0
	end
	local n = 0
	-- try resumeAll first (harmless if ignored)
	pcall(function()
		FisherKiosk:InvokeServer("resumeAll")
	end)
	state = fisherState() or state
	for i, h in ipairs(state.hired) do
		if typeof(h) == "table" and h.paused then
			pcall(function()
				FisherKiosk:InvokeServer("pause", i) -- toggle off pause
			end)
			n += 1
			task.wait(0.08)
		end
	end
	if not silent and n > 0 then
		notifyAuto("Resumed " .. n .. " fisher(s)")
	end
	return n
end

local function fisherCollect(silent)
	local ok, res = pcall(function()
		return FisherKiosk:InvokeServer("collect")
	end)
	if not silent then
		notifyAuto(ok and "Fisher wages collected" or ("Fisher collect failed: " .. tostring(res)))
	end
	return ok
end

--[[
  NPC cycle is server-side (FishermanConfig.CycleSeconds=300 * speed roll).
  No remote can set speed. Fastest client lever = keep max-speed crew hired
  and collect stash often. Score prefers speed, then efficiency, then power.
]]
local function fisherScore(h)
	if typeof(h) ~= "table" then
		return -1e18
	end
	return (h.speed or 0) * 1e6 + (h.efficiency or 0) * 1e3 + (h.power or 0) * 1e-6
end

local function fisherHiredCount(hired)
	local n = 0
	for _, h in ipairs(hired or {}) do
		if typeof(h) == "table" then
			n += 1
		end
	end
	return n
end

local function fisherOptimizeOnce()
	local state = fisherState()
	if not state then
		return "no state"
	end

	-- always unpause
	for i, h in ipairs(state.hired or {}) do
		if typeof(h) == "table" and h.paused then
			pcall(function()
				FisherKiosk:InvokeServer("pause", i)
			end)
			task.wait(0.12)
		end
	end

	state = fisherState() or state
	local hired = state.hired or {}
	local offers = state.offers or {}
	local stations = state.stations or fisherHiredCount(hired)
	if #offers == 0 then
		return "no offers"
	end

	-- best offer by score
	local bestOffer, bestOfferScore = nil, -1e18
	for _, o in ipairs(offers) do
		if typeof(o) == "table" then
			local s = fisherScore(o)
			if s > bestOfferScore then
				bestOffer, bestOfferScore = o, s
			end
		end
	end
	if not bestOffer then
		return "no offer"
	end

	-- empty station → hire best
	if fisherHiredCount(hired) < stations then
		pcall(function()
			FisherKiosk:InvokeServer("hire", bestOffer.uid)
		end)
		return "hired " .. tostring(bestOffer.name) .. " spd=" .. tostring(bestOffer.speed)
	end

	-- find weakest hired below min speed / worse than offer
	local weakIdx, weakScore = nil, 1e18
	for i, h in ipairs(hired) do
		if typeof(h) == "table" then
			local s = fisherScore(h)
			if s < weakScore then
				weakIdx, weakScore = i, s
			end
		end
	end

	local weak = weakIdx and hired[weakIdx]
	local shouldSwap = typeof(weak) == "table"
		and bestOfferScore > weakScore
		and (
			(weak.speed or 0) < CFG.MinFisherSpeed
			or (bestOffer.speed or 0) >= (weak.speed or 0) + 3
			or fisherScore(bestOffer) > fisherScore(weak) * 1.05
		)

	if shouldSwap and bestOffer.uid and weakIdx then
		pcall(function()
			FisherKiosk:InvokeServer("dismiss", weakIdx)
		end)
		task.wait(0.35)
		pcall(function()
			FisherKiosk:InvokeServer("hire", bestOffer.uid)
		end)
		return string.format(
			"swapped %s(%d) → %s(%d)",
			tostring(weak.name),
			weak.speed or 0,
			tostring(bestOffer.name),
			bestOffer.speed or 0
		)
	end

	return "crew ok"
end

local function applyInstantNpcMode(on)
	CFG.InstantNpcFishers = on
	if on then
		CFG.AutoFisherResume = true
		CFG.AutoFisherCollect = true
		CFG.AutoFisherOptimize = true
		CFG.FisherCollectEvery = 0.5
		CFG.FisherResumeEvery = 0.4
		fisherUnpauseAll(true)
		fisherOptimizeOnce()
		fisherCollect(true)
	else
		CFG.FisherCollectEvery = 5
		CFG.FisherResumeEvery = 1.5
	end
end

local function isOwnFisherId(id)
	if id == nil then
		return false
	end
	local s = tostring(id)
	local uid = tostring(LocalPlayer.UserId)
	return s == uid or string.sub(s, 1, #uid + 1) == uid .. ":"
end

local function setAutoRoll(on)
	CFG.AutoRoll = on
	local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
	if hud then
		hud:SetAttribute("AutoRollEnabled", on)
		hud:SetAttribute("HideRollEffects", CFG.HideRollFx)
	end
	pcall(function()
		AutoRollState:FireServer(on, CFG.HideRollFx)
	end)
end

local function collectDropsNear()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return 0
	end
	local payload = {}
	local radius = 80
	local r2 = radius * radius
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part:GetAttribute("IsBeingCollected") then
			local id = tonumber(part.Name)
			if id and part:GetAttribute("Slot") ~= nil then
				local d = hrp.Position - part.Position
				if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= r2 then
					table.insert(payload, {
						id,
						part:GetAttribute("Stack") or 1,
						part:GetAttribute("Slot"),
					})
					if #payload >= 8 then
						break
					end
				end
			end
		end
	end
	if #payload > 0 then
		pcall(function()
			CollectItem:FireServer(payload)
		end)
	end
	return #payload
end

local function isLeafGenModel(inst)
	if not inst or not inst:IsA("Model") then
		return false
	end
	local dt = inst:GetAttribute("DecorType")
	if typeof(dt) == "string" and dt:lower() == "leafgenerator" then
		return true
	end
	if inst.Name == "LeafGenerator" or inst.Name:lower():find("leafgen") then
		return true
	end
	return inst:FindFirstChild("LeafGenPrompt", true) ~= nil
end

local function listLeafGens()
	local isl = island()
	if not isl then
		return {}
	end
	local seen = {}
	local out = {}
	local function add(m)
		if m and not seen[m] and isLeafGenModel(m) then
			seen[m] = true
			table.insert(out, m)
		end
	end
	for _, inst in ipairs(isl:GetDescendants()) do
		if inst:IsA("Model") then
			add(inst)
		elseif inst:IsA("ProximityPrompt") and inst.Name == "LeafGenPrompt" then
			local p = inst.Parent
			while p and p ~= Workspace do
				if p:IsA("Model") and p:GetAttribute("DecorType") == "leafgenerator" then
					add(p)
					break
				end
				p = p.Parent
			end
		end
	end
	return out
end

-- game path: CollectLeafGen:FireServer(leafGenModel)
local function collectLeafGens()
	local gens = listLeafGens()
	local n = 0
	for _, gen in ipairs(gens) do
		local ok = pcall(function()
			CollectLeafGen:FireServer(gen)
		end)
		if ok then
			n += 1
		end
	end
	return n
end

-- ToggleLeafGenOverclock:FireServer(model) — only enable if currently off
local function ensureOverclockLeafGens()
	if not ToggleLeafGenOverclock then
		return 0
	end
	local n = 0
	for _, gen in ipairs(listLeafGens()) do
		if gen:GetAttribute("Overclock") ~= true then
			local ok = pcall(function()
				ToggleLeafGenOverclock:FireServer(gen)
			end)
			if ok then
				n += 1
			end
		end
	end
	return n
end

local function overclockLeafGens()
	if not ToggleLeafGenOverclock then
		return 0
	end
	local n = 0
	for _, gen in ipairs(listLeafGens()) do
		local ok = pcall(function()
			ToggleLeafGenOverclock:FireServer(gen)
		end)
		if ok then
			n += 1
		end
	end
	return n
end

-- FeedLeafGenMoney:FireServer(model, amount) — UI: 1e9 / 1e10 / 1e15(Fill)
local function feedLeafGens(amount, force)
	if not FeedLeafGenMoney then
		return 0
	end
	amount = tonumber(amount) or tonumber(CFG.LeafGenFeedAmount) or 1e15
	local minRt = tonumber(CFG.LeafGenMinRuntime) or 600
	local n = 0
	for _, gen in ipairs(listLeafGens()) do
		local runtime = tonumber(gen:GetAttribute("RuntimeLeft")) or 0
		local fuel = tonumber(gen:GetAttribute("DecorFuel")) or 0
		local needs = force or runtime < minRt or fuel <= 0 or gen:GetAttribute("GenRunning") ~= true
		if needs then
			local ok = pcall(function()
				FeedLeafGenMoney:FireServer(gen, amount)
			end)
			if ok then
				n += 1
			end
		end
	end
	return n
end

local function leafGenMaintain()
	local fed, oc = 0, 0
	if CFG.AutoLeafGenFeed then
		fed = feedLeafGens(CFG.LeafGenFeedAmount, false)
	end
	if CFG.AutoLeafGenOverclock then
		oc = ensureOverclockLeafGens()
	end
	return fed, oc
end

local function claimedSet(list)
	local set = {}
	if typeof(list) == "table" then
		for _, t in pairs(list) do
			if typeof(t) == "number" then
				set[t] = true
			end
		end
	end
	return set
end

local function seasonStatus()
	local ok, st = pcall(function()
		return RequestSeasonPass:InvokeServer()
	end)
	if not ok or typeof(st) ~= "table" then
		return nil, tostring(st)
	end
	local freeClaimed = claimedSet(st.f)
	local paidClaimed = claimedSet(st.p)
	local tier = tonumber(st.tier) or 0
	local freeReady, paidReady = 0, 0
	for i = 1, tier do
		if not freeClaimed[i] then
			freeReady += 1
		end
		if st.paid and not paidClaimed[i] then
			paidReady += 1
		end
	end
	return {
		id = st.id,
		tier = tier,
		xp = st.xp,
		need = st.need,
		into = st.into,
		paid = st.paid and true or false,
		freeReady = freeReady,
		paidReady = paidReady,
		live = st.live,
		name = SeasonPassConfig and SeasonPassConfig.Name,
	}
end

-- ClaimSeasonTier:InvokeServer(track, tier) — track "free"|"paid", tier 0 = bulk all ready
local function claimSeasonTrack(track)
	local ok, res = pcall(function()
		return ClaimSeasonTier:InvokeServer(track, 0)
	end)
	if not ok then
		return false, 0, tostring(res)
	end
	local granted = 0
	if typeof(res) == "table" then
		granted = tonumber(res.granted) or 0
		return res.ok == true or granted > 0, granted, res
	end
	return false, 0, res
end

local function claimSeasonAll()
	local freeOk, freeN = claimSeasonTrack("free")
	local paidOk, paidN = false, 0
	local st = select(1, seasonStatus())
	if st and st.paid then
		paidOk, paidN = claimSeasonTrack("paid")
	end
	return (freeN or 0) + (paidN or 0), freeOk, paidOk
end

local function collectHoneyFruits()
	local isl = island()
	if not isl then
		return 0
	end
	local n = 0
	local seen = {}
	local function try(slot, idx)
		local key = slot .. ":" .. tostring(idx)
		if seen[key] then
			return
		end
		seen[key] = true
		local ok, res = pcall(function()
			return CollectHoneyFruit:InvokeServer(slot, idx)
		end)
		if ok and typeof(res) == "table" and res.ok then
			n += 1
		end
	end
	-- world prompts: Island/<slot>/HoneyFruitFX/Fruit_N
	for _, fx in ipairs(isl:GetDescendants()) do
		if fx.Name == "HoneyFruitFX" and fx.Parent then
			local slot = fx.Parent.Name
			for _, fruit in ipairs(fx:GetChildren()) do
				local idx = tonumber(fruit.Name:match("Fruit_(%d+)"))
				if idx then
					try(slot, idx)
				end
			end
		end
	end
	-- sync cache
	for key, _ in pairs(store.honeyKnown) do
		local slot, idx = key:match("^(.+):(%d+)$")
		if slot and idx then
			try(slot, tonumber(idx))
		end
	end
	return n
end

local function collectMutations()
	local n = 0
	local tried = {}
	local function try(slot)
		if not slot or tried[slot] then
			return
		end
		tried[slot] = true
		local ok, res = pcall(function()
			return CollectTransientMutation:InvokeServer(slot)
		end)
		if ok and typeof(res) == "table" and res.ok then
			n += 1
			store.mutSlots[slot] = nil
		end
	end
	for slot, _ in pairs(store.mutSlots) do
		try(slot)
	end
	local isl = island()
	if isl then
		for _, prompt in ipairs(isl:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") and prompt.Name == "TransientCollectPrompt" then
				local model = prompt.Parent
				while model and not model:IsA("Model") do
					model = model.Parent
				end
				-- dress stores slot on tree model name under island
				local slot = model and model.Name
				if slot and model.Parent == isl then
					try(slot)
				elseif model then
					-- climb to island child
					local cur = model
					while cur and cur.Parent and cur.Parent ~= isl do
						cur = cur.Parent
					end
					if cur and cur.Parent == isl then
						try(cur.Name)
					end
				end
			end
		end
	end
	return n
end

local function claimOffline()
	local now = os.clock()
	if now - (store.lastOfflineClaim or 0) < 1 then
		return false
	end
	store.lastOfflineClaim = now
	return pcall(function()
		OfflineEarnings:FireServer()
	end)
end

local function claimChests()
	pcall(function()
		ChestEvent:FireServer("claim", "daily")
	end)
	pcall(function()
		ChestEvent:FireServer("claim", "group")
	end)
	pcall(function()
		ChestEvent:FireServer("acceptGroupReward")
	end)
	return true
end

local function enchantStatus()
	local ok, res = pcall(function()
		return EnchantAction:InvokeServer("get")
	end)
	if ok and typeof(res) == "table" then
		return res
	end
	return nil
end

local function startEnchantAuto()
	local st = enchantStatus()
	local rod = (st and st.equipped) or "Quasar Rod"
	local id = CFG.EnchantTargetId or "Swift"
	local tier = CFG.EnchantTargetTier or 3
	local ok, res = pcall(function()
		return EnchantAction:InvokeServer("autostart", { rod = rod, id = id, tier = tier })
	end)
	return ok and typeof(res) == "table" and res.ok == true, res
end

local function stopEnchantAuto()
	return pcall(function()
		EnchantAction:InvokeServer("autostop")
	end)
end

local function incubState()
	local ok, res = pcall(function()
		return PetIncubatorAction:InvokeServer("state")
	end)
	if ok and typeof(res) == "table" then
		return res
	end
	return nil
end

local function isSnailPet(pet)
	if typeof(pet) ~= "table" then
		return false
	end
	local key = tostring(pet.key or ""):lower()
	local display = tostring(pet.display or ""):lower()
	return key:find("snail", 1, true) ~= nil or display:find("snail", 1, true) ~= nil
end

local function listFeedableSnails(st)
	local ids = {}
	if not st or typeof(st.pets) ~= "table" then
		return ids
	end
	for _, pet in pairs(st.pets) do
		if isSnailPet(pet) and pet.uid and not pet.locked and not pet.equipped then
			table.insert(ids, tonumber(pet.uid) or pet.uid)
		end
	end
	return ids
end

-- PetIncubatorAction feed — snails only, exactly `cost` (10)
local function incubFeedOnce()
	local st = incubState()
	if not st then
		return false, "no state"
	end
	local cost = tonumber(st.cost) or 10
	local ids = listFeedableSnails(st)
	if #ids < cost then
		return false, ("need %d snails have %d"):format(cost, #ids)
	end
	local payload = {}
	for i = 1, cost do
		payload[i] = ids[i]
	end
	local now = os.clock()
	if now - (store.lastIncubFeed or 0) < 1.2 then
		return false, "slow"
	end
	store.lastIncubFeed = now
	local ok, res = pcall(function()
		return PetIncubatorAction:InvokeServer("feed", payload)
	end)
	return ok and typeof(res) == "table" and res.ok == true, res
end

local function requestAllEggs()
	if not RequestSnailEggs then
		return nil
	end
	local ok, res = pcall(function()
		return RequestSnailEggs:InvokeServer()
	end)
	if ok and typeof(res) == "table" then
		return res
	end
	return nil
end

-- hatch only via RequestSnailEggs inventory (no BuyEgg / no Instant)
local function hatchFromRequestSnailEggs(maxPerTick)
	maxPerTick = maxPerTick or 40
	if not HatchEgg then
		return 0, {}, nil
	end
	local eggs = requestAllEggs()
	if not eggs then
		return 0, {}, nil
	end
	local hatched = 0
	local got = {}
	for eggType, count in pairs(eggs) do
		local n = tonumber(count) or 0
		if typeof(eggType) == "string" and n > 0 then
			for _ = 1, n do
				if hatched >= maxPerTick then
					return hatched, got, eggs
				end
				local ok, res = pcall(function()
					return HatchEgg:InvokeServer(eggType)
				end)
				if ok and typeof(res) == "table" and res.ok == true then
					hatched += 1
					local key = tostring(res.key or res.revealed or eggType)
					got[key] = (got[key] or 0) + 1
				else
					break
				end
				task.wait(0.1)
			end
		end
	end
	return hatched, got, eggs
end

local function giraffeClaimAll()
	local ok, res = pcall(function()
		return GiraffeClaim:InvokeServer()
	end)
	return ok, res
end

local function giraffeProcessPending()
	local n = 0
	for key, fetch in pairs(store.giraffePending) do
		if typeof(fetch) == "table" and fetch.slot and fetch.id then
			local ok, res = pcall(function()
				return GiraffeGrab:InvokeServer(fetch.slot, fetch.id)
			end)
			if ok and typeof(res) == "table" and res.ok then
				n += 1
				store.giraffePending[key] = nil
			end
		else
			store.giraffePending[key] = nil
		end
	end
	if n > 0 or next(store.giraffePending) == nil then
		giraffeClaimAll()
	end
	return n
end

local function sellAllFish()
	return pcall(function()
		SellFish:InvokeServer("all")
	end)
end

local function consumableNameFromId(cid)
	local id = tostring(cid)
	if ConsumableDictionary and ConsumableDictionary.Items then
		for name, def in pairs(ConsumableDictionary.Items) do
			if typeof(def) == "table" and tostring(def.ConsumableID) == id then
				return name, def
			end
		end
	end
	return nil, nil
end

local function getConsumableInv()
	if not RequestConsumableInventory then
		return {}
	end
	local ok, inv = pcall(function()
		return RequestConsumableInventory:InvokeServer()
	end)
	if ok and typeof(inv) == "table" then
		return inv
	end
	return {}
end

local function getActivePotions()
	if not RequestActivePotions then
		return {}
	end
	local ok, pots = pcall(function()
		return RequestActivePotions:InvokeServer()
	end)
	if ok and typeof(pots) == "table" then
		return pots
	end
	return {}
end

local function hasActivePotionId(id)
	id = tonumber(id)
	for _, p in ipairs(getActivePotions()) do
		if typeof(p) == "table" and tonumber(p.id) == id then
			return true
		end
	end
	return false
end

local function useConsumable(name, qty)
	if not UseConsumable or not name then
		return false
	end
	return pcall(function()
		if qty then
			UseConsumable:FireServer(name, qty)
		else
			UseConsumable:FireServer(name)
		end
	end)
end

local function qtyOwned(consumableId)
	local inv = getConsumableInv()
	local key = "c" .. tostring(consumableId)
	return tonumber(inv[key]) or 0
end

-- keep a luck potion ticking (can't invent luck; only apply owned pots)
local function ensureLuckPotion()
	-- already boosted?
	if (tonumber(LocalPlayer:GetAttribute("LuckPotion")) or 0) > 0 then
		return false, "active"
	end
	-- prefer highest owned luck pot
	local order = {
		{ id = 7, name = "God Potion" },
		{ id = 21, name = "Luck II Potion" },
		{ id = 6, name = "Sharing Luck Potion" },
		{ id = 3, name = "Luck I Potion" },
	}
	-- if preferred set and owned, try that first
	if CFG.PreferLuckPotion then
		local pref = CFG.PreferLuckPotion
		local def = ConsumableDictionary.Items and ConsumableDictionary.Items[pref]
		local pid = typeof(def) == "table" and tonumber(def.ConsumableID) or nil
		table.insert(order, 1, { id = pid, name = pref })
	end
	for _, pot in ipairs(order) do
		local name = pot.name
		local id = pot.id
		if id and qtyOwned(id) > 0 and not hasActivePotionId(id) then
			useConsumable(name, 1)
			return true, name
		elseif id and hasActivePotionId(id) then
			return false, "active"
		end
	end
	return false, "none"
end

local function ensureFishBait()
	-- Dirt Bait = FishLuck boost (id 15)
	if hasActivePotionId(15) then
		return false, "active"
	end
	if qtyOwned(15) > 0 then
		useConsumable("Dirt Bait", 1)
		return true, "Dirt Bait"
	end
	return false, "none"
end

local function placeBaitBucketNearPier()
	if not PlaceBaitBucket then
		return false, "no remote"
	end
	if qtyOwned(20) <= 0 then
		return false, "no bucket"
	end
	local spot = fishSpotCFrame()
	local pos
	if spot then
		pos = spot.Position + Vector3.new(4, 0, 0)
	else
		local isl = island()
		local part = isl and isl:FindFirstChildWhichIsA("BasePart", true)
		if not part then
			return false, "no pier"
		end
		pos = part.Position + Vector3.new(0, 0, 6)
	end
	-- PlaceBaitBucket:FireServer(Vector3) — game places at pier zone
	local ok = pcall(function()
		PlaceBaitBucket:FireServer(pos)
	end)
	return ok, ok and "placed" or "fail"
end

local function forceFullLuck()
	if not SetPlayerSetting then
		return
	end
	if LocalPlayer:GetAttribute("MaxLuckEnabled") == true then
		pcall(function()
			SetPlayerSetting:FireServer("MaxLuckEnabled", false)
		end)
	end
	pcall(function()
		SetPlayerSetting:FireServer("MaxLuckCap", 100)
	end)
end

local function luckStatusLine()
	local base = tonumber(LocalPlayer:GetAttribute("Luck")) or 0
	local pot = tonumber(LocalPlayer:GetAttribute("LuckPotion")) or 0
	local mult = 1 + 0.5 * (tonumber(LocalPlayer:GetAttribute("Upg_LuckMultiplier")) or 0)
	local disp = tonumber(LocalPlayer:GetAttribute("DisplayedLuckRaw")) or 0
	local fishLuck = tonumber(LocalPlayer:GetAttribute("Upg_FishLuck")) or 0
	return ("luck %s | pot +%s | mult x%.1f | displayed %s | fishLuck upg %s"):format(
		tostring(math.floor(base)),
		tostring(pot),
		mult,
		tostring(math.floor(disp)),
		tostring(fishLuck)
	)
end

local function clearEsp()
	for _, obj in pairs(store.esp) do
		pcall(function()
			obj:Destroy()
		end)
	end
	table.clear(store.esp)
end

local function makeBillboard(adornee, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Name = "TRNG_ESP"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(120, 28)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.Adornee = adornee
	bb.Parent = LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = color or Color3.fromRGB(120, 255, 180)
	label.Text = text
	label.Parent = bb
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
	return bb
end

local function refreshEsp()
	clearEsp()
	if CFG.EspPlayers then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					store.esp["p_" .. plr.UserId] = makeBillboard(hrp, plr.Name, Color3.fromRGB(255, 200, 80))
				end
			end
		end
	end
	if CFG.EspFishSpots then
		for _, isl in ipairs(Workspace.PlayerIslands:GetChildren()) do
			local back = isl:FindFirstChild("BackOffshoot")
			if back then
				for _, name in ipairs({ "FishingSpot", "FishingSpot2" }) do
					local spot = back:FindFirstChild(name)
					if spot then
						store.esp[isl.Name .. "_" .. name] =
							makeBillboard(spot, isl.Name:gsub("_Island", "") .. " fish", Color3.fromRGB(80, 200, 255))
					end
				end
			end
		end
	end
end

-- FishingState instant reel
STATE.connect(FishingState.OnClientEvent, function(state)
	if not CFG.InstantFish then
		return
	end
	if state == "reel" then
		doReel()
	elseif state == "catch" or state == "escape" or state == "fail" then
		if state == "catch" and CFG.SellOnCatch then
			task.delay(0.15, function()
				if STATE.alive() then
					sellAllFish()
				end
			end)
		end
		if CFG.AutoCast then
			task.delay(0.4, function()
				if STATE.alive() then
					doCast()
				end
			end)
		end
		if CFG.AutoLock then
			task.delay(0.6, function()
				if STATE.alive() then
					lockHighTier()
				end
			end)
		end
	end
end)

-- HoneyFruitSync → instant pick
STATE.connect(HoneyFruitSync.OnClientEvent, function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.owner ~= LocalPlayer.UserId then
		return
	end
	local slot = payload.slot
	if typeof(slot) ~= "string" then
		return
	end
	if typeof(payload.fruits) == "table" then
		for _, fruit in ipairs(payload.fruits) do
			if typeof(fruit) == "table" and fruit.i then
				store.honeyKnown[slot .. ":" .. tostring(fruit.i)] = true
			end
		end
	end
	if CFG.InstantHoney then
		task.defer(function()
			if typeof(payload.fruits) == "table" then
				for _, fruit in ipairs(payload.fruits) do
					if typeof(fruit) == "table" and fruit.i then
						pcall(function()
							CollectHoneyFruit:InvokeServer(slot, fruit.i)
						end)
						store.honeyKnown[slot .. ":" .. tostring(fruit.i)] = nil
					end
				end
			else
				collectHoneyFruits()
			end
		end)
	end
end)

-- TransientMutationSync → claim slot
STATE.connect(TransientMutationSync.OnClientEvent, function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local owner = tonumber(payload.owner)
	if owner ~= LocalPlayer.UserId then
		return
	end
	if payload.action == "full" and typeof(payload.slots) == "table" then
		for slot, tm in pairs(payload.slots) do
			if tm then
				store.mutSlots[slot] = tm
			end
		end
	elseif payload.action == "set" and typeof(payload.slot) == "string" then
		if payload.tm then
			store.mutSlots[payload.slot] = payload.tm
		else
			store.mutSlots[payload.slot] = nil
		end
	end
	if CFG.InstantMutations then
		task.defer(function()
			collectMutations()
		end)
	end
end)

-- Offline popup → claim immediately
STATE.connect(OfflineEarnings.OnClientEvent, function(payload)
	if not CFG.AutoOfflineClaim then
		return
	end
	if typeof(payload) == "table" then
		task.defer(claimOffline)
	end
end)

if GiraffeFetch then
	STATE.connect(GiraffeFetch.OnClientEvent, function(payload)
		if typeof(payload) ~= "table" or typeof(payload.slot) ~= "string" then
			return
		end
		local id = payload.id or (payload.fetch and payload.fetch.id)
		local slot = payload.slot or (payload.fetch and payload.fetch.slot)
		if payload.fetch and typeof(payload.fetch) == "table" then
			id = payload.fetch.id or id
			slot = payload.fetch.slot or slot
		end
		-- also array of fetches
		if typeof(payload.fetches) == "table" then
			for _, f in ipairs(payload.fetches) do
				if typeof(f) == "table" and f.slot and f.id then
					store.giraffePending[f.slot .. ":" .. tostring(f.id)] = f
				end
			end
		elseif slot and id then
			store.giraffePending[slot .. ":" .. tostring(id)] = { slot = slot, id = id }
		end
		if CFG.AutoGiraffe then
			task.defer(giraffeProcessPending)
		end
	end)
end

if IncubatorCycle then
	STATE.connect(IncubatorCycle.OnClientEvent, function()
		if CFG.AutoIncubator then
			task.defer(incubFeedOnce)
		end
	end)
end

if PetIncubated then
	STATE.connect(PetIncubated.OnClientEvent, function()
		if CFG.AutoEggs then
			task.defer(function()
				hatchFromRequestSnailEggs(40)
			end)
		end
	end)
end

if HoneyObbyChest then
	STATE.connect(HoneyObbyChest.OnClientEvent, function(_payload)
		if CFG.WatchHoneyObby then
			notifyAuto("Honey Obby chest — touch-gated (server)", 3)
		end
	end)
end

if HoneyObbyFinish then
	STATE.connect(HoneyObbyFinish.OnClientEvent, function(payload)
		if CFG.WatchHoneyObby and typeof(payload) == "table" then
			notifyAuto("Honey Obby finish: " .. tostring(payload.name or payload.userId), 3)
		end
	end)
end

-- Instant NPC fishers: claim stash the moment OUR fisher reels/deposits
STATE.connect(FisherCrewSync.OnClientEvent, function(payload)
	if not CFG.InstantNpcFishers then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	if not isOwnFisherId(payload.id) then
		return
	end
	if payload.t == "phase" and (payload.p == "reel" or payload.p == "deposit") then
		fisherCollect(true)
	end
end)

-- wages tick often means stash/money moved — claim
STATE.connect(FisherWage.OnClientEvent, function()
	if CFG.InstantNpcFishers or CFG.AutoFisherCollect then
		fisherCollect(true)
	end
end)

-- background loops
task.spawn(function()
	pcall(function()
		RodAction:InvokeServer("hold")
	end)
	while STATE.alive() do
		task.wait(0.3)
		if CFG.InstantFish and CFG.AutoCast then
			local sinceCast = os.clock() - store.lastCast
			local sinceReel = os.clock() - store.lastReel
			if sinceCast > 1.25 and sinceReel > 0.6 then
				doCast()
			end
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		task.wait(CFG.AutoSellDelay)
		if CFG.AutoSell then
			pcall(function()
				SellFish:InvokeServer("all")
			end)
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		local every = CFG.LeafGenEvery or 0.75
		if CFG.InstantLeafGen then
			every = math.min(every, 0.35)
		end
		task.wait(math.max(0.25, every))
		if CFG.AutoLeafGen or CFG.InstantLeafGen then
			collectLeafGens()
		end
		if CFG.AutoLeafGenFeed or CFG.AutoLeafGenOverclock then
			leafGenMaintain()
		end
		if CFG.AutoCollectDrops then
			collectDropsNear()
		end
	end
end)

-- slower dedicated fuel/OC pass (money feed is heavier)
task.spawn(function()
	while STATE.alive() do
		task.wait(2.5)
		if CFG.AutoLeafGenFeed or CFG.AutoLeafGenOverclock then
			leafGenMaintain()
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		task.wait(math.max(1, CFG.SeasonClaimEvery or 2))
		if CFG.AutoSeasonClaim then
			local st = select(1, seasonStatus())
			if st and ((st.freeReady or 0) > 0 or (st.paidReady or 0) > 0) then
				local n = claimSeasonAll()
				if n > 0 then
					notifyAuto(("Season claimed %d tier(s)"):format(n))
				end
			end
		end
	end
end)

task.spawn(function()
	-- one-shot offline + chests on load
	task.wait(0.5)
	if CFG.AutoOfflineClaim then
		claimOffline()
	end
	if CFG.AutoChests then
		claimChests()
	end
	while STATE.alive() do
		task.wait(0.6)
		if CFG.InstantHoney then
			collectHoneyFruits()
		end
		if CFG.InstantMutations then
			collectMutations()
		end
		if CFG.AutoGiraffe then
			giraffeProcessPending()
			giraffeClaimAll()
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		task.wait(4)
		if CFG.AutoChests then
			claimChests()
		end
		if CFG.AutoEggs then
			hatchFromRequestSnailEggs(40)
		end
		if CFG.AutoIncubator then
			incubFeedOnce()
		end
		if CFG.AutoEnchant then
			local st = enchantStatus()
			if st and not st.autoRunning then
				startEnchantAuto()
			end
		end
	end
end)

task.spawn(function()
	if CFG.ForceFullLuck then
		forceFullLuck()
	end
	local lastBucket = 0
	while STATE.alive() do
		task.wait(2.5)
		if CFG.ForceFullLuck then
			forceFullLuck()
		end
		if CFG.AutoLuckPotions then
			ensureLuckPotion()
		end
		if CFG.AutoFishBait then
			ensureFishBait()
		end
		if CFG.AutoBaitBucket and os.clock() - lastBucket > 310 then
			local ok = placeBaitBucketNearPier()
			if ok then
				lastBucket = os.clock()
			end
		end
	end
end)

-- fire collect as soon as a leafgenerator model lands on the island
do
	local function hookIsland(isl)
		if not isl then
			return
		end
		STATE.connect(isl.DescendantAdded, function(inst)
			if not (CFG.AutoLeafGen or CFG.InstantLeafGen) then
				return
			end
			local gen = nil
			if inst:IsA("Model") and isLeafGenModel(inst) then
				gen = inst
			elseif inst:IsA("ProximityPrompt") and inst.Name == "LeafGenPrompt" then
				local p = inst.Parent
				while p and p ~= Workspace do
					if p:IsA("Model") and p:GetAttribute("DecorType") == "leafgenerator" then
						gen = p
						break
					end
					p = p.Parent
				end
			end
			if gen then
				task.defer(function()
					pcall(function()
						CollectLeafGen:FireServer(gen)
					end)
				end)
			end
		end)
	end
	hookIsland(island())
	local islands = Workspace:FindFirstChild("PlayerIslands")
	if islands then
		STATE.connect(islands.ChildAdded, function(child)
			if child.Name == LocalPlayer.Name .. "_Island" then
				hookIsland(child)
			end
		end)
	end
end

task.spawn(function()
	fisherUnpauseAll(true)
	if CFG.InstantNpcFishers then
		applyInstantNpcMode(true)
	end
	while STATE.alive() do
		local waitFor = math.max(0.35, CFG.FisherCollectEvery or 5)
		if CFG.InstantNpcFishers then
			waitFor = math.min(waitFor, 0.5)
		end
		task.wait(waitFor)
		if CFG.AutoFisherCollect or CFG.InstantNpcFishers then
			fisherCollect(true)
		end
		if CFG.AutoFisherOptimize or CFG.InstantNpcFishers then
			local msg = fisherOptimizeOnce()
			if msg and (msg:find("swap") or msg:find("hired")) then
				notifyAuto("Fishers: " .. msg)
			end
		end
	end
end)

-- dedicated auto-resume: catch pauseAll / wage-pause ASAP
task.spawn(function()
	while STATE.alive() do
		local every = CFG.FisherResumeEvery or 1.5
		if CFG.InstantNpcFishers then
			every = math.min(every, 0.4)
		end
		task.wait(math.max(0.35, every))
		if CFG.AutoFisherResume or CFG.InstantNpcFishers then
			fisherUnpauseAll(true)
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		task.wait(2)
		if CFG.EspPlayers or CFG.EspFishSpots then
			refreshEsp()
		end
	end
end)

STATE.onCleanup(function()
	clearEsp()
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

-- UI (starts closed — OpenButton / keybind to open; no load yap)
local Window = WindUI:CreateWindow({
	Title = "Tree RNG Hub",
	Author = "local WindUI",
	Folder = "TreeRNGHub",
	Icon = "fish",
	NewElements = true,
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = false,
	OpenButton = {
		Title = "Tree RNG",
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

-- WindUI auto-opens; close immediately for silent boot
task.defer(function()
	pcall(function()
		Window:Close()
	end)
end)

Window:Tag({
	Title = "v1",
	Icon = "leaf",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")

local MainSec = Window:Section({ Title = "Main", Opened = true })
local FishSec = Window:Section({ Title = "Systems", Opened = true })

-- ABOUT
do
	local Tab = MainSec:Tab({ Title = "Home", Icon = "house", IconColor = Green })
	Tab:Paragraph({
		Title = "Tree RNG Hub",
		Desc = "Silent boot · click OpenButton icon to open menu",
	})
	Tab:Toggle({
		Title = "Silent Mode",
		Desc = "Mute auto notifications (buttons still notify)",
		Default = CFG.Silent,
		Callback = function(v)
			CFG.Silent = v
		end,
	})
	Tab:Button({
		Title = "Hold Rod",
		Icon = "fishing-rod",
		Callback = function()
			pcall(function()
				RodAction:InvokeServer("hold")
			end)
			notify("Rod hold")
		end,
	})
	Tab:Button({
		Title = "Refresh Status",
		Callback = function()
			local inv = getFishInv()
			notify(
				string.format(
					"Fish:%d  Coins:%s  Money:%s",
					#inv,
					tostring(LocalPlayer:GetAttribute("FishCoins")),
					tostring(LocalPlayer:GetAttribute("Money"))
				)
			)
		end,
	})
end

-- FISHING
do
	local Tab = FishSec:Tab({ Title = "Fishing", Icon = "fish", IconColor = Blue })

	Tab:Toggle({
		Title = "Instant Fishing",
		Desc = "RodAction reel on FishingState \"reel\"",
		Default = CFG.InstantFish,
		Callback = function(v)
			CFG.InstantFish = v
			if v then
				pcall(function()
					RodAction:InvokeServer("hold")
				end)
				doCast()
			end
		end,
	})

	Tab:Toggle({
		Title = "Auto Cast",
		Desc = "Cast at configured power after catch / idle",
		Default = CFG.AutoCast,
		Callback = function(v)
			CFG.AutoCast = v
		end,
	})

	Tab:Slider({
		Title = "Cast Power",
		Step = 0.05,
		Value = { Min = 0, Max = 1, Default = CFG.CastPower },
		Callback = function(v)
			CFG.CastPower = v
		end,
	})

	Tab:Button({
		Title = "Cast Now (max)",
		Callback = function()
			pcall(function()
				RodAction:InvokeServer("hold")
			end)
			task.wait(0.15)
			pcall(function()
				RodAction:InvokeServer("cast", 1)
			end)
		end,
	})

	Tab:Space()

	Tab:Toggle({
		Title = "Auto Sell All",
		Desc = "SellFish(\"all\") on a timer",
		Default = CFG.AutoSell,
		Callback = function(v)
			CFG.AutoSell = v
		end,
	})

	Tab:Toggle({
		Title = "Sell On Catch",
		Desc = "SellFish all immediately after catch",
		Default = CFG.SellOnCatch,
		Callback = function(v)
			CFG.SellOnCatch = v
		end,
	})

	Tab:Button({
		Title = "Sell All Now",
		Icon = "coins",
		Callback = sellAll,
	})

	Tab:Button({
		Title = "Sell Unlocked Only",
		Callback = sellUnlocked,
	})

	Tab:Button({
		Title = "Daily Deal x5",
		Callback = sellDailyDeal,
	})

	Tab:Space()

	Tab:Slider({
		Title = "Auto-Lock Min Tier",
		Step = 1,
		Value = { Min = 1, Max = 6, Default = CFG.LockMinTier },
		Callback = function(v)
			CFG.LockMinTier = math.floor(v)
		end,
	})

	Tab:Toggle({
		Title = "Auto-Lock High Tier",
		Desc = "Lock tier / top percentile after catch",
		Default = CFG.AutoLock,
		Callback = function(v)
			CFG.AutoLock = v
		end,
	})

	Tab:Button({
		Title = "Lock High Tier Now",
		Callback = lockHighTier,
	})

	Tab:Space()

	Tab:Button({
		Title = "Dump Fish → Aquarium",
		Callback = dumpAquarium,
	})

	Tab:Button({
		Title = "Collect Aquarium",
		Callback = collectAquarium,
	})

	Tab:Button({
		Title = "Merchant AutoBuy Toggle",
		Callback = function()
			local ok, res = pcall(function()
				return FishGearAction:InvokeServer("get")
			end)
			local on = ok and typeof(res) == "table" and res.AutoBuyOn == true
			pcall(function()
				FishGearAction:InvokeServer("setAutoBuy", not on)
			end)
			notify("Merchant AutoBuy → " .. tostring(not on))
		end,
	})
end

-- FISHERS (NpcFishCap)
do
	local Tab = FishSec:Tab({ Title = "Fishers", Icon = "users", IconColor = Yellow })

	Tab:Paragraph({
		Title = "NPC catch interval is server-locked",
		Desc = "CycleSeconds=300 + rolled speed. Instant mode = claim on reel/deposit + aggressive resume/collect/optimize.",
	})

	Tab:Toggle({
		Title = "Instant NPC Fishers",
		Desc = "Max pipeline: claim on reel · resume 0.4s · collect 0.5s · optimize",
		Default = CFG.InstantNpcFishers,
		Callback = function(v)
			applyInstantNpcMode(v)
			notify(v and "Instant NPC Fishers ON" or "Instant NPC Fishers OFF")
		end,
	})

	Tab:Toggle({
		Title = "Auto Resume",
		Desc = "If any fisher pauses, unpause within ~1.5s",
		Default = CFG.AutoFisherResume,
		Callback = function(v)
			CFG.AutoFisherResume = v
			if v then
				notify("Resumed " .. fisherUnpauseAll(true))
			end
		end,
	})

	Tab:Toggle({
		Title = "Auto Optimize Crew",
		Desc = "Unpause all · dismiss slow · hire faster offers",
		Default = CFG.AutoFisherOptimize,
		Callback = function(v)
			CFG.AutoFisherOptimize = v
			if v then
				notify(fisherOptimizeOnce())
			end
		end,
	})

	Tab:Toggle({
		Title = "Auto Collect Stash",
		Desc = "FisherKiosk collect on a short timer",
		Default = CFG.AutoFisherCollect,
		Callback = function(v)
			CFG.AutoFisherCollect = v
		end,
	})

	Tab:Slider({
		Title = "Min Keep Speed",
		Step = 1,
		Value = { Min = 50, Max = 100, Default = CFG.MinFisherSpeed },
		Callback = function(v)
			CFG.MinFisherSpeed = math.floor(v)
		end,
	})

	Tab:Slider({
		Title = "Collect Every (sec)",
		Step = 1,
		Value = { Min = 2, Max = 30, Default = CFG.FisherCollectEvery },
		Callback = function(v)
			CFG.FisherCollectEvery = math.floor(v)
		end,
	})

	Tab:Slider({
		Title = "Resume Check (sec)",
		Step = 0.5,
		Value = { Min = 0.5, Max = 5, Default = CFG.FisherResumeEvery },
		Callback = function(v)
			CFG.FisherResumeEvery = v
		end,
	})

	Tab:Button({
		Title = "Optimize Now",
		Callback = function()
			notify(fisherOptimizeOnce())
		end,
	})

	Tab:Button({
		Title = "Resume / Unpause All",
		Callback = function()
			local n = fisherUnpauseAll(true)
			notify("Resumed " .. n)
		end,
	})

	Tab:Button({
		Title = "Collect Stash Now",
		Callback = function()
			fisherCollect(false)
		end,
	})

	Tab:Button({
		Title = "Show Crew Speeds",
		Callback = function()
			local state = fisherState()
			if not state then
				notify("no state")
				return
			end
			local parts = {}
			for i, h in ipairs(state.hired or {}) do
				if typeof(h) == "table" then
					table.insert(
						parts,
						string.format(
							"%d:%s spd=%d eff=%d%s",
							i,
							h.name,
							h.speed or 0,
							h.efficiency or 0,
							h.paused and " PAUSE" or ""
						)
					)
				else
					table.insert(parts, string.format("%d:empty", i))
				end
			end
			notify(table.concat(parts, " · "))
		end,
	})
end

-- TREES
do
	local Tab = FishSec:Tab({ Title = "Trees", Icon = "tree-deciduous", IconColor = Green })

	Tab:Toggle({
		Title = "Auto Roll",
		Desc = "HUD AutoRollEnabled + AutoRollState",
		Default = CFG.AutoRoll,
		Callback = function(v)
			setAutoRoll(v)
		end,
	})

	Tab:Toggle({
		Title = "Hide Roll FX",
		Default = CFG.HideRollFx,
		Callback = function(v)
			CFG.HideRollFx = v
			if CFG.AutoRoll then
				setAutoRoll(true)
			end
		end,
	})

	Tab:Button({
		Title = "Auto Place Best",
		Callback = function()
			local ok, res = pcall(function()
				return AutoPlaceBest:InvokeServer()
			end)
			notify(ok and "AutoPlaceBest done" or tostring(res))
		end,
	})

	Tab:Button({
		Title = "Unequip All Trees",
		Callback = function()
			pcall(function()
				UnequipAll:InvokeServer()
			end)
			notify("UnequipAll")
		end,
	})
end

-- FARM
do
	local Tab = FishSec:Tab({ Title = "Farm", Icon = "sprout", IconColor = Yellow })

	Tab:Toggle({
		Title = "Auto Collect Drops",
		Desc = "CollectItem near HRP (numeric drop parts)",
		Default = CFG.AutoCollectDrops,
		Callback = function(v)
			CFG.AutoCollectDrops = v
		end,
	})

	Tab:Button({
		Title = "Collect Drops Now",
		Callback = function()
			notify("Collected " .. collectDropsNear() .. " drop stacks")
		end,
	})

	Tab:Divider()

	Tab:Toggle({
		Title = "Instant LeafGen",
		Desc = "CollectLeafGen on every leafgenerator model (~0.35s)",
		Default = CFG.InstantLeafGen,
		Callback = function(v)
			CFG.InstantLeafGen = v
			if v then
				CFG.AutoLeafGen = true
			end
		end,
	})

	Tab:Toggle({
		Title = "Auto LeafGen Collect",
		Default = CFG.AutoLeafGen,
		Callback = function(v)
			CFG.AutoLeafGen = v
		end,
	})

	Tab:Button({
		Title = "LeafGen Collect Now",
		Callback = function()
			local gens = listLeafGens()
			local n = collectLeafGens()
			notify(("LeafGen: %d model(s), fired %d"):format(#gens, n))
		end,
	})

	Tab:Toggle({
		Title = "Auto LeafGen Feed Money",
		Desc = "FeedLeafGenMoney Fill (1e15) when runtime/fuel low",
		Default = CFG.AutoLeafGenFeed,
		Callback = function(v)
			CFG.AutoLeafGenFeed = v
		end,
	})

	Tab:Dropdown({
		Title = "Feed Amount",
		Values = { "Fill (1e15)", "+10B", "+1B" },
		Value = "Fill (1e15)",
		Callback = function(v)
			if v == "+10B" then
				CFG.LeafGenFeedAmount = 1e10
			elseif v == "+1B" then
				CFG.LeafGenFeedAmount = 1e9
			else
				CFG.LeafGenFeedAmount = 1e15
			end
		end,
	})

	Tab:Button({
		Title = "Feed LeafGen Money Now",
		Desc = "FeedLeafGenMoney(model, amount) force",
		Callback = function()
			local gens = listLeafGens()
			local n = feedLeafGens(CFG.LeafGenFeedAmount, true)
			notify(("fed %d / %d gen(s) amount=%s"):format(n, #gens, tostring(CFG.LeafGenFeedAmount)))
		end,
	})

	Tab:Toggle({
		Title = "Auto LeafGen Overclock",
		Desc = "Keep Overclock=true (Toggle only if off)",
		Default = CFG.AutoLeafGenOverclock,
		Callback = function(v)
			CFG.AutoLeafGenOverclock = v
			if v then
				ensureOverclockLeafGens()
			end
		end,
	})

	Tab:Button({
		Title = "Toggle LeafGen Overclock",
		Desc = "ToggleLeafGenOverclock on each placed gen",
		Callback = function()
			notify("Overclock toggled on " .. overclockLeafGens() .. " gen(s)")
		end,
	})

	Tab:Button({
		Title = "Ensure Overclock ON",
		Callback = function()
			notify("Enabled OC on " .. ensureOverclockLeafGens() .. " gen(s)")
		end,
	})

	Tab:Divider()

	Tab:Toggle({
		Title = "Auto Season Claim",
		Desc = "ClaimSeasonTier free/paid bulk when tiers ready",
		Default = CFG.AutoSeasonClaim,
		Callback = function(v)
			CFG.AutoSeasonClaim = v
		end,
	})

	Tab:Button({
		Title = "Season Status",
		Callback = function()
			local st, err = seasonStatus()
			if not st then
				notify("Season status failed: " .. tostring(err))
				return
			end
			notify(
				("%s t%d xp %s | free ready %d | paid %s ready %d"):format(
					tostring(st.name or st.id),
					st.tier,
					tostring(st.xp),
					st.freeReady,
					st.paid and "yes" or "no",
					st.paidReady
				),
				5
			)
		end,
	})

	Tab:Button({
		Title = "Claim All Free Tiers",
		Callback = function()
			local ok, n, res = claimSeasonTrack("free")
			notify(("Free claim: granted %d%s"):format(n or 0, ok and "" or " (none ready)"))
		end,
	})

	Tab:Button({
		Title = "Claim All Paid Tiers",
		Desc = "Needs paid season pass",
		Callback = function()
			local st = select(1, seasonStatus())
			if st and not st.paid then
				notify("Paid track locked — buy season pass first")
				return
			end
			local ok, n = claimSeasonTrack("paid")
			notify(("Paid claim: granted %d%s"):format(n or 0, ok and "" or " (none ready)"))
		end,
	})

	Tab:Button({
		Title = "Claim All Season Rewards",
		Callback = function()
			local n = claimSeasonAll()
			notify(("Season bulk: granted %d"):format(n))
		end,
	})
end

-- EVENTS / INSTANT CLAIMS
do
	local Tab = FishSec:Tab({ Title = "Events", Icon = "zap", IconColor = Yellow })

	Tab:Toggle({
		Title = "Instant Honey Fruit",
		Desc = "CollectHoneyFruit(slot, i) on sync + poll",
		Default = CFG.InstantHoney,
		Callback = function(v)
			CFG.InstantHoney = v
		end,
	})

	Tab:Button({
		Title = "Pick All Honey Now",
		Callback = function()
			notify("Honey picked: " .. collectHoneyFruits())
		end,
	})

	Tab:Toggle({
		Title = "Instant Mutations",
		Desc = "CollectTransientMutation(slot) on sync",
		Default = CFG.InstantMutations,
		Callback = function(v)
			CFG.InstantMutations = v
		end,
	})

	Tab:Button({
		Title = "Claim Mutations Now",
		Callback = function()
			notify("Mutations claimed: " .. collectMutations())
		end,
	})

	Tab:Divider()

	Tab:Toggle({
		Title = "Auto Offline Claim",
		Desc = "OfflineEarnings:FireServer on popup + load",
		Default = CFG.AutoOfflineClaim,
		Callback = function(v)
			CFG.AutoOfflineClaim = v
			if v then
				claimOffline()
			end
		end,
	})

	Tab:Button({
		Title = "Claim Offline Now",
		Callback = function()
			claimOffline()
			notify("OfflineEarnings fired")
		end,
	})

	Tab:Toggle({
		Title = "Auto Chests",
		Desc = "ChestEvent claim daily + group",
		Default = CFG.AutoChests,
		Callback = function(v)
			CFG.AutoChests = v
			if v then
				claimChests()
			end
		end,
	})

	Tab:Button({
		Title = "Claim Chests Now",
		Callback = function()
			claimChests()
			notify("Chest claim fired (daily+group)")
		end,
	})

	Tab:Divider()

	Tab:Toggle({
		Title = "Auto Enchant",
		Desc = "EnchantAction autostart on equipped rod",
		Default = CFG.AutoEnchant,
		Callback = function(v)
			CFG.AutoEnchant = v
			if v then
				local ok = startEnchantAuto()
				notify(ok and "Enchant auto started" or "Enchant autostart failed")
			else
				stopEnchantAuto()
				notify("Enchant auto stopped")
			end
		end,
	})

	Tab:Button({
		Title = "Enchant Status",
		Callback = function()
			local st = enchantStatus()
			if not st then
				notify("Enchant get failed")
				return
			end
			notify(
				("rod %s | auto %s running %s | coins %s"):format(
					tostring(st.equipped),
					tostring(st.auto),
					tostring(st.autoRunning),
					tostring(st.coins)
				),
				4
			)
		end,
	})

	Tab:Button({
		Title = "Start / Stop Enchant Auto",
		Callback = function()
			local st = enchantStatus()
			if st and st.autoRunning then
				stopEnchantAuto()
				notify("Stopped enchant auto")
			else
				local ok = startEnchantAuto()
				notify(ok and "Started enchant auto" or "Failed — check rod/target")
			end
		end,
	})

	Tab:Divider()

	Tab:Toggle({
		Title = "Auto Hatch (RequestSnailEggs)",
		Desc = "Only RequestSnailEggs → HatchEgg(type). No BuyEgg / Instant",
		Default = CFG.AutoEggs,
		Callback = function(v)
			CFG.AutoEggs = v
		end,
	})

	Tab:Button({
		Title = "RequestSnailEggs + Hatch",
		Callback = function()
			local eggs = requestAllEggs() or {}
			local parts = {}
			for k, v in pairs(eggs) do
				table.insert(parts, ("%s=%s"):format(tostring(k), tostring(v)))
			end
			table.sort(parts)
			local n, got = hatchFromRequestSnailEggs(40)
			local gotParts = {}
			for k, v in pairs(got) do
				table.insert(gotParts, ("%s x%d"):format(k, v))
			end
			notify(
				("RequestSnailEggs [%s] | hatched %d %s"):format(
					#parts > 0 and table.concat(parts, ", ") or "empty",
					n,
					#gotParts > 0 and ("→ " .. table.concat(gotParts, ", ")) or ""
				),
				6
			)
		end,
	})

	Tab:Toggle({
		Title = "Auto Incubator Feed",
		Desc = "Feed exactly 10 snails only → Mystery Egg",
		Default = CFG.AutoIncubator,
		Callback = function(v)
			CFG.AutoIncubator = v
		end,
	})

	Tab:Button({
		Title = "Feed 10 Snails Now",
		Callback = function()
			local st = incubState()
			if not st then
				notify("Incubator state failed")
				return
			end
			local ids = listFeedableSnails(st)
			local ok, res = incubFeedOnce()
			notify(
				("snails %d/%s | eggs %s | feed %s"):format(
					#ids,
					tostring(st.cost or 10),
					tostring(st.eggs),
					ok and "ok" or tostring(typeof(res) == "table" and res.err or res)
				),
				5
			)
		end,
	})

	Tab:Divider()

	Tab:Toggle({
		Title = "Auto Giraffe",
		Desc = "GiraffeGrab on fetch + GiraffeClaim",
		Default = CFG.AutoGiraffe,
		Callback = function(v)
			CFG.AutoGiraffe = v
			if v then
				giraffeProcessPending()
				giraffeClaimAll()
			end
		end,
	})

	Tab:Button({
		Title = "Giraffe Claim Now",
		Callback = function()
			local n = giraffeProcessPending()
			local ok, res = giraffeClaimAll()
			local reason = typeof(res) == "table" and (res.reason or res.claimed) or tostring(res)
			notify(("grabbed %d | claim %s"):format(n, tostring(reason)))
		end,
	})

	Tab:Toggle({
		Title = "Watch Honey Obby",
		Desc = "Notify on chest/finish (S2C only — touch gated)",
		Default = CFG.WatchHoneyObby,
		Callback = function(v)
			CFG.WatchHoneyObby = v
		end,
	})

	Tab:Button({
		Title = "Collect Everything Now",
		Desc = "Honey + mutations + leafgen + drops + chests + offline + season",
		Callback = function()
			local h = collectHoneyFruits()
			local m = collectMutations()
			local l = collectLeafGens()
			local d = collectDropsNear()
			claimChests()
			claimOffline()
			local s = claimSeasonAll()
			notify(("H%d M%d L%d D%d S%d"):format(h, m, l, d, s), 5)
		end,
	})
end

-- BOOSTS (luck + fish produce quality)
do
	local Tab = FishSec:Tab({ Title = "Boosts", Icon = "sparkles", IconColor = Green })

	Tab:Paragraph({
		Title = "Limits",
		Desc = "Can't invent luck or spawn fish. Can auto-use potions/bait + keep MaxLuck off. NPC catch interval still server-locked.",
	})

	Tab:Toggle({
		Title = "Auto Luck Potions",
		Desc = "God → Luck II → Sharing → Luck I when none active",
		Default = CFG.AutoLuckPotions,
		Callback = function(v)
			CFG.AutoLuckPotions = v
			if v then
				local ok, name = ensureLuckPotion()
				notify(ok and ("Used " .. tostring(name)) or ("Luck pot: " .. tostring(name)))
			end
		end,
	})

	Tab:Toggle({
		Title = "Force Full Luck",
		Desc = "MaxLuckEnabled=false (use 100% displayed luck)",
		Default = CFG.ForceFullLuck,
		Callback = function(v)
			CFG.ForceFullLuck = v
			if v then
				forceFullLuck()
				notify("Full luck unlocked")
			end
		end,
	})

	Tab:Toggle({
		Title = "Auto Fish Bait (Dirt)",
		Desc = "Dirt Bait → +FishLuck while fishing",
		Default = CFG.AutoFishBait,
		Callback = function(v)
			CFG.AutoFishBait = v
			if v then
				local ok, name = ensureFishBait()
				notify(ok and ("Used " .. tostring(name)) or ("Fish bait: " .. tostring(name)))
			end
		end,
	})

	Tab:Toggle({
		Title = "Auto Bait Bucket",
		Desc = "PlaceBaitBucket at pier (~5min) for fish rarity/size",
		Default = CFG.AutoBaitBucket,
		Callback = function(v)
			CFG.AutoBaitBucket = v
			if v then
				local ok, msg = placeBaitBucketNearPier()
				notify(ok and "Bait bucket placed" or ("Bucket: " .. tostring(msg)))
			end
		end,
	})

	Tab:Button({
		Title = "Luck Status",
		Callback = function()
			notify(luckStatusLine(), 5)
		end,
	})

	Tab:Button({
		Title = "Pop Luck Potion Now",
		Callback = function()
			local ok, name = ensureLuckPotion()
			notify(ok and ("Used " .. tostring(name)) or ("Luck: " .. tostring(name)))
		end,
	})

	Tab:Button({
		Title = "Pop Dirt Bait Now",
		Callback = function()
			local ok, name = ensureFishBait()
			notify(ok and ("Used " .. tostring(name)) or ("Bait: " .. tostring(name)))
		end,
	})

	Tab:Button({
		Title = "Place Bait Bucket Now",
		Callback = function()
			local ok, msg = placeBaitBucketNearPier()
			notify(ok and "Placed near pier" or tostring(msg))
		end,
	})

	Tab:Button({
		Title = "Owned Boost Items",
		Callback = function()
			local inv = getConsumableInv()
			local parts = {}
			for key, qty in pairs(inv) do
				local id = tostring(key):match("c(%d+)")
				local name = id and select(1, consumableNameFromId(id)) or key
				if tonumber(qty) and tonumber(qty) > 0 then
					table.insert(parts, ("%s x%s"):format(tostring(name), tostring(qty)))
				end
			end
			notify(#parts > 0 and table.concat(parts, " · ") or "no consumables", 6)
		end,
	})
end

-- TELEPORT
do
	local Tab = FishSec:Tab({ Title = "Teleport", Icon = "map-pin", IconColor = Red })

	Tab:Button({
		Title = "Teleport Home",
		Desc = "Requires Teleport Home upgrade",
		Callback = function()
			pcall(function()
				TeleportHome:FireServer()
			end)
			notify("TeleportHome fired")
		end,
	})

	Tab:Button({
		Title = "Fishing Spot",
		Callback = function()
			local cf = fishSpotCFrame()
			if cf then
				tp(cf)
				notify("Warped to fishing spot")
			else
				notify("No fishing spot found")
			end
		end,
	})

	Tab:Button({
		Title = "Island Center",
		Callback = function()
			local isl = island()
			if not isl then
				notify("No island")
				return
			end
			local part = isl:FindFirstChildWhichIsA("BasePart", true)
			if part then
				tp(part.CFrame + Vector3.new(0, 8, 0))
			end
		end,
	})
end

-- ESP
do
	local Tab = FishSec:Tab({ Title = "Visuals", Icon = "eye", IconColor = Blue })

	Tab:Toggle({
		Title = "Player ESP",
		Default = CFG.EspPlayers,
		Callback = function(v)
			CFG.EspPlayers = v
			if not v then
				clearEsp()
			else
				refreshEsp()
			end
		end,
	})

	Tab:Toggle({
		Title = "Fishing Spot ESP",
		Default = CFG.EspFishSpots,
		Callback = function(v)
			CFG.EspFishSpots = v
			if not v then
				clearEsp()
			else
				refreshEsp()
			end
		end,
	})

	Tab:Button({
		Title = "Refresh ESP",
		Callback = refreshEsp,
	})
end

-- silent boot: systems armed, window closed, no load toast/print

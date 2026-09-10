--[[
  Heroes RNG Hub - WindUI
  live-reload label: heroes_rng_hub

  Instant roll hooks RollingView.WaitForRollComplete.
  Instant loot patches Shared.Config magnet / auto-loot delays.
  Auto farm stays on the highest unlocked zone and clicks if unlocked.
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
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Network = require(ReplicatedStorage.client.Network.Network)
local Shared = require(ReplicatedStorage.shared.Shared)
local Config = Shared.Config
local ZoneData = require(ReplicatedStorage.shared.Zones.ZoneData)
local Rolling = require(ReplicatedStorage.client.Rolling.Rolling)
local RollingView = require(ReplicatedStorage.client.Rolling.RollingView)
local Inventory = require(ReplicatedStorage.client.Inventory.Inventory)
local Upgrades = require(ReplicatedStorage.client.Upgrades.Upgrades)
local Enemies = require(ReplicatedStorage.client.Enemies.Enemies)
local Settings = require(ReplicatedStorage.client.Settings.Settings)
local FusionClient = require(ReplicatedStorage.client.Fusion.Fusion)
local FusionShared = require(ReplicatedStorage.shared.Fusion.Fusion)
local Heroes = Shared.Heroes
local Items = require(ReplicatedStorage.client.Items.Items)

if not STATE.store then
	STATE.store = {}
end
local store = STATE.store

local CFG = store.cfg
	or {
		AutoFarm = false,
		AutoZone = true,
		AutoUnlock = true,
		AutoUpgrades = true,
		AutoClick = true,
		AutoRoll = false,
		InstantRoll = true,
		InstantLoot = true,
		SkipCutscene = true,
		SkipCombatVfx = true,
		AutoEquip = true,
		AutoFuse = false,
		InstantFuse = true,
		EnemyEsp = false,
		WalkSpeedOn = false,
		WalkSpeed = 36,
		InfJump = false,
		AntiAfk = true,
		Silent = false,
		RollDelay = 0.22,
		ClickDelay = 0.08,
		ZonePick = "Best",
	}
store.cfg = CFG

local ORIG_CFG = store.origCfg
	or {
		AutoLootDelaySeconds = Config.AutoLootDelaySeconds,
		LootMagnetTweenSeconds = Config.LootMagnetTweenSeconds,
		LootMergeIntervalSeconds = Config.LootMergeIntervalSeconds,
		LootMergeSettleSeconds = Config.LootMergeSettleSeconds,
		LootPickupScanHz = Config.LootPickupScanHz,
	}
store.origCfg = ORIG_CFG

local CODES = {
	"30Thousand",
	"BossUpdate",
	"Batteries",
	"EasyPotions",
	"Beginnings",
}

local UPGRADE_PRIORITY = {
	Luck = 100,
	RollSpeed = 95,
	["3 Hero Slots"] = 90,
	["4 Hero Slots"] = 88,
	["5 Hero Slots"] = 86,
	["Auto-Equip Best"] = 84,
	["Click Attack"] = 82,
	["Hold to Attack"] = 80,
	["Loot Magnet I"] = 78,
	["Hero Damage I"] = 76,
	["Hero Damage"] = 74,
	Walkspeed = 70,
	Teleporter = 68,
	["Faster Rolls"] = 66,
	Player = 60,
	["3 Enemies"] = 55,
}

local highlights = store.highlights or {}
store.highlights = highlights

local function notify(title, content)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = title or "Heroes RNG",
			Content = content or "",
			Duration = 2.4,
		})
	end)
end

local function fire(name, ...)
	return pcall(function(...)
		Network.FireServer(name, ...)
	end, ...)
end

local function invoke(name, ...)
	local ok, res = pcall(function(...)
		return Network.InvokeServer(name, ...)
	end, ...)
	if ok then
		return true, res
	end
	return false, res
end

local function gold()
	local ok, n = pcall(Upgrades.GetGold)
	if ok and typeof(n) == "number" then
		return n
	end
	local ok2, snap = invoke("GetCurrencies")
	if ok2 and typeof(snap) == "table" and typeof(snap.balances) == "table" then
		return tonumber(snap.balances.Gold) or 0
	end
	return 0
end

local function ownedUpgrades()
	local ok, owned = pcall(Upgrades.GetOwned)
	if ok and typeof(owned) == "table" then
		return owned
	end
	return {}
end

local function hasUpgrade(id)
	local owned = ownedUpgrades()
	return owned[id] == true
end

local function zoneOrder()
	return ZoneData.Order or {
		"Starter",
		"Meadows",
		"Forest",
		"Beach",
		"Sea",
		"Arctic",
		"Jungle",
		"Badlands",
		"Shadowgrove",
		"SerpentSands",
		"Void",
		"IceCave",
	}
end

local function unlockedSet()
	local set = { Starter = true }
	local ok, st = invoke("GetZoneUnlockState")
	if ok and typeof(st) == "table" and typeof(st.unlocked) == "table" then
		for name, on in pairs(st.unlocked) do
			if on then
				set[name] = true
			end
		end
	end
	return set
end

local function bestUnlockedZone()
	local unlocked = unlockedSet()
	local best = "Starter"
	for _, id in ipairs(zoneOrder()) do
		if unlocked[id] then
			best = id
		end
	end
	return best
end

local function nextLockedZone()
	local unlocked = unlockedSet()
	for _, id in ipairs(zoneOrder()) do
		if not unlocked[id] then
			return id
		end
	end
	return nil
end

local function currentZone()
	local ok, z = pcall(Enemies.GetCurrentZone)
	if ok and typeof(z) == "string" and z ~= "" then
		return z
	end
	return "Starter"
end

local function teleportZone(id)
	if typeof(id) ~= "string" or id == "" then
		return false
	end
	local ok, res = invoke("RequestZoneTeleport", id)
	return ok and res == true
end

local function applyInstantLoot(on)
	if on then
		Config.AutoLootDelaySeconds = 0
		Config.LootMagnetTweenSeconds = 0.05
		Config.LootMergeIntervalSeconds = 0.05
		Config.LootMergeSettleSeconds = 0.05
		Config.LootPickupScanHz = 30
	else
		Config.AutoLootDelaySeconds = ORIG_CFG.AutoLootDelaySeconds
		Config.LootMagnetTweenSeconds = ORIG_CFG.LootMagnetTweenSeconds
		Config.LootMergeIntervalSeconds = ORIG_CFG.LootMergeIntervalSeconds
		Config.LootMergeSettleSeconds = ORIG_CFG.LootMergeSettleSeconds
		Config.LootPickupScanHz = ORIG_CFG.LootPickupScanHz
	end
end

local function applySettings()
	pcall(function()
		if CFG.SkipCutscene then
			Network.FireServer("SetSetting", "Cutscene", false)
		end
	end)
	pcall(function()
		if Settings.SetBool then
			Settings.SetBool("CombatVfx", not CFG.SkipCombatVfx)
			Settings.SetBool("AutoEquip", true)
			Settings.SetBool("AutoPower", true)
		end
	end)
end

local function ensureRollHooks()
	if store.hookedWait then
		return
	end
	if typeof(hookfunction) ~= "function" then
		return
	end
	if typeof(RollingView.WaitForRollComplete) == "function" then
		store.origWait = hookfunction(RollingView.WaitForRollComplete, function(...)
			if CFG.InstantRoll then
				return
			end
			return store.origWait(...)
		end)
		store.hookedWait = true
	end
	local ok, FusionAnimation = pcall(require, ReplicatedStorage.client.Fusion.FusionAnimation)
	if ok and typeof(FusionAnimation) == "table" and typeof(FusionAnimation.IsPlaying) == "function" then
		store.origFusePlaying = hookfunction(FusionAnimation.IsPlaying, function(...)
			if CFG.InstantFuse then
				return false
			end
			return store.origFusePlaying(...)
		end)
		store.hookedFuse = true
	end
end

local function restoreHooks()
	if typeof(restorefunction) == "function" then
		if store.origWait then
			pcall(restorefunction, RollingView.WaitForRollComplete)
		end
		if store.origFusePlaying then
			local ok, FusionAnimation = pcall(require, ReplicatedStorage.client.Fusion.FusionAnimation)
			if ok and FusionAnimation then
				pcall(restorefunction, FusionAnimation.IsPlaying)
			end
		end
	end
	store.hookedWait = false
	store.hookedFuse = false
	store.origWait = nil
	store.origFusePlaying = nil
end

local function setClientAutoRoll(on)
	if on then
		if not Rolling.IsAutoRolling() then
			pcall(Rolling.StartAutoRollCompact)
		end
		pcall(Rolling.ResumeAutoRoll)
		fire("SetAutoRoll", true)
		return
	end
	fire("SetAutoRoll", false)
	if typeof(debug) == "table" and typeof(debug.setupvalue) == "function" then
		pcall(function()
			debug.setupvalue(Rolling.IsAutoRolling, 1, false)
		end)
	end
end

local function rollColumns()
	local cols = tonumber(LocalPlayer:GetAttribute("GamepassRollColumns")) or 1
	cols = math.floor(cols + (tonumber(LocalPlayer:GetAttribute("EventExtraColumns")) or 0))
	return math.clamp(cols, 1, 5)
end

local function forceRoll()
	return invoke("Roll", rollColumns())
end

local function scoreHero(heroId, size, instanceId)
	local lvl = 1
	pcall(function()
		lvl = Inventory.GetInstanceLevel(heroId, size, instanceId) or 1
	end)
	local atk = 0
	pcall(function()
		atk = Heroes.GetCombatATK(heroId, lvl, size, Inventory.GetBestOwnedDps()) or 0
	end)
	local starMul = 1
	pcall(function()
		starMul = FusionClient.GetInstanceStarMul(heroId, size, instanceId) or 1
	end)
	return atk * starMul, lvl
end

local function listOwnedHeroes()
	local out = {}
	local ok, snap = invoke("GetInventory")
	if not ok or typeof(snap) ~= "table" or typeof(snap.Heroes) ~= "table" then
		return out
	end
	for heroId, entry in pairs(snap.Heroes) do
		if typeof(entry) == "table" and typeof(entry.Sizes) == "table" then
			for size, sizeEntry in pairs(entry.Sizes) do
				if typeof(sizeEntry) == "table" and typeof(sizeEntry.Instances) == "table" then
					for instId, inst in pairs(sizeEntry.Instances) do
						local id = tonumber(instId) or instId
						local stars = 0
						if typeof(inst) == "table" then
							stars = tonumber(inst.Stars or inst.stars) or 0
						end
						local atk = scoreHero(heroId, size, id)
						table.insert(out, {
							heroId = heroId,
							size = size,
							instanceId = id,
							stars = stars,
							atk = atk,
							copies = 0,
						})
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.atk or 0) > (b.atk or 0)
	end)
	return out
end

local function maxSlots()
	local ok, snap = invoke("GetInventory")
	if ok and typeof(snap) == "table" and typeof(snap.MaxEquippedHeroes) == "number" then
		return snap.MaxEquippedHeroes
	end
	return Config.MaxEquippedHeroes or 2
end

local function autoEquipBest()
	local heroes = listOwnedHeroes()
	if #heroes == 0 then
		return 0
	end
	local slots = maxSlots()
	local equipped = {}
	pcall(function()
		equipped = Inventory.GetEquipped() or {}
	end)
	for _, slot in ipairs(equipped) do
		fire("UnequipHero", slot.HeroId, slot.Size, slot.InstanceId)
	end
	task.wait(0.05)
	local n = 0
	for i = 1, math.min(slots, #heroes) do
		local h = heroes[i]
		fire("EquipHero", h.heroId, h.size, h.stars, h.instanceId)
		n += 1
	end
	return n
end

local function autoFuseOnce()
	local fused = 0
	local copiesNeed = FusionShared.CopiesPerFuse or 10
	local ok, snap = invoke("GetInventory")
	if not ok or typeof(snap) ~= "table" or typeof(snap.Heroes) ~= "table" then
		return 0
	end
	for heroId, entry in pairs(snap.Heroes) do
		if typeof(entry) == "table" and typeof(entry.Sizes) == "table" then
			for size, sizeEntry in pairs(entry.Sizes) do
				local copies = 0
				if typeof(sizeEntry) == "table" and typeof(sizeEntry.Instances) == "table" then
					for _ in pairs(sizeEntry.Instances) do
						copies += 1
					end
				end
				if copies >= copiesNeed then
					FusionClient.RequestFuse(heroId, size, 0, 1)
					fused += 1
				end
			end
		end
	end
	return fused
end

local function buyUpgradesOnce()
	local owned = ownedUpgrades()
	local cash = gold()
	local candidates = {}
	local orderFn = Shared.Upgrades and Shared.Upgrades.Order
	local ids = {}
	if typeof(orderFn) == "function" then
		pcall(function()
			ids = Shared.Upgrades.Order() or {}
		end)
	end
	for _, id in ipairs(ids) do
		if not owned[id] then
			local prereq = true
			pcall(function()
				prereq = Shared.Upgrades.ArePrereqsMet(id, owned)
			end)
			if prereq then
				local cost = 0
				pcall(function()
					cost = Shared.Upgrades.GetCost(id, owned) or 0
				end)
				if typeof(cost) == "number" and cost > 0 and cost <= cash then
					table.insert(candidates, {
						id = id,
						cost = cost,
						prio = UPGRADE_PRIORITY[id] or 0,
					})
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.prio ~= b.prio then
			return a.prio > b.prio
		end
		return a.cost < b.cost
	end)
	local bought = 0
	for i = 1, math.min(4, #candidates) do
		fire("PurchaseUpgrade", candidates[i].id)
		bought += 1
		task.wait(0.12)
	end
	return bought
end

local function clickNearest()
	if not hasUpgrade("Click Attack") and not hasUpgrade("Hold to Attack") then
		return false
	end
	local zone = currentZone()
	if typeof(zone) ~= "string" then
		return false
	end
	local bestSlot, bestDist
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local origin = hrp and hrp.Position
	pcall(function()
		for slotId in Enemies.IterateZoneSlots(zone) do
			if Enemies.IsAlive(zone, slotId) then
				local pos = Enemies.GetPosition(zone, slotId)
				local dist = 0
				if origin and pos then
					dist = (origin - pos).Magnitude
				end
				if not bestSlot or dist < bestDist then
					bestSlot = slotId
					bestDist = dist
				end
			end
		end
	end)
	if not bestSlot then
		return false
	end
	local pos = Enemies.GetPosition(zone, bestSlot)
	fire("ReportClickAttack", zone, bestSlot, pos)
	return true
end

local function clearEsp()
	for key, h in pairs(highlights) do
		pcall(function()
			h:Destroy()
		end)
		highlights[key] = nil
	end
end

local function tickEsp()
	if not CFG.EnemyEsp then
		clearEsp()
		return
	end
	local zone = currentZone()
	local seen = {}
	pcall(function()
		for slotId in Enemies.IterateZoneSlots(zone) do
			local model = Enemies.GetModel(zone, slotId)
			if model and Enemies.IsAlive(zone, slotId) then
				local key = zone .. ":" .. tostring(slotId)
				seen[key] = true
				local hl = highlights[key]
				if not hl or hl.Parent ~= model then
					if hl then
						hl:Destroy()
					end
					hl = Instance.new("Highlight")
					hl.FillColor = Color3.fromRGB(255, 70, 70)
					hl.OutlineColor = Color3.fromRGB(255, 220, 80)
					hl.FillTransparency = 0.55
					hl.OutlineTransparency = 0
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Adornee = model
					hl.Parent = model
					highlights[key] = hl
				end
			end
		end
	end)
	for key, h in pairs(highlights) do
		if not seen[key] then
			pcall(function()
				h:Destroy()
			end)
			highlights[key] = nil
		end
	end
end

local function applyWalkSpeed()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = CFG.WalkSpeed
	end
end

local function claimAll()
	local results = {}
	local function add(name, ok, res)
		table.insert(results, name .. "=" .. tostring(ok and (typeof(res) == "table" and "ok" or res) or res))
	end
	local a, b = invoke("ClaimDailyReward")
	add("daily", a, b)
	a, b = invoke("ClaimOfflineRewards")
	add("offline", a, b)
	a, b = invoke("ClaimTutorialRewards")
	add("tutorial", a, b)
	fire("ClaimRuneShard")
	pcall(function()
		if Items.GetCount("GoldPotion") and Items.GetCount("GoldPotion") > 0 then
			Items.Use("GoldPotion")
		end
	end)
	return table.concat(results, " | ")
end

local function redeemCodes()
	local lines = {}
	for _, code in ipairs(CODES) do
		local ok, res = invoke("RedeemCode", code)
		local msg = code
		if ok and typeof(res) == "table" then
			msg = msg .. ": " .. tostring(res.ok or res.success or res.message or res.error or "sent")
		else
			msg = msg .. ": " .. tostring(res)
		end
		table.insert(lines, msg)
		task.wait(0.25)
	end
	return table.concat(lines, "\n")
end

local function statusText()
	local g = math.floor(gold())
	local z = currentZone()
	local auto = false
	pcall(function()
		auto = Rolling.IsAutoRolling()
	end)
	local lvl = "?"
	pcall(function()
		local ok, st = invoke("GetLevel")
		if ok and typeof(st) == "table" then
			lvl = tostring(st.level)
		end
	end)
	local eq = 0
	pcall(function()
		eq = #(Inventory.GetEquipped() or {})
	end)
	return string.format(
		"gold %s  |  zone %s  |  lvl %s  |  roll %s  |  equipped %d  |  farm %s",
		tostring(g),
		tostring(z),
		tostring(lvl),
		auto and "auto" or "off",
		eq,
		CFG.AutoFarm and "on" or "off"
	)
end

ensureRollHooks()
applyInstantLoot(CFG.InstantLoot)
applySettings()

task.spawn(function()
	while STATE.alive() do
		applyInstantLoot(CFG.InstantLoot)
		if CFG.AutoFarm then
			if CFG.AutoZone then
				local target = CFG.ZonePick
				if target == "Best" or target == nil or target == "" then
					target = bestUnlockedZone()
				end
				if currentZone() ~= target then
					teleportZone(target)
					task.wait(0.6)
				end
			end
			if CFG.AutoUnlock then
				local nxt = nextLockedZone()
				if nxt then
					fire("RequestZoneUnlock", nxt)
				end
			end
			if CFG.AutoUpgrades then
				buyUpgradesOnce()
			end
			if CFG.AutoEquip then
				pcall(autoEquipBest)
			end
		end
		task.wait(1.1)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoFarm and CFG.AutoClick then
			clickNearest()
			task.wait(math.max(CFG.ClickDelay, 0.07))
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoRoll then
			if not Rolling.IsAutoRolling() then
				setClientAutoRoll(true)
			end
		end
		if CFG.AutoFuse then
			autoFuseOnce()
		end
		task.wait(0.8)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.WalkSpeedOn then
			applyWalkSpeed()
		end
		tickEsp()
		task.wait(0.35)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AntiAfk then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
		task.wait(45)
	end
end)

STATE.connect(UserInputService.JumpRequest, function()
	if not CFG.InfJump then
		return
	end
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

STATE.connect(LocalPlayer.CharacterAdded, function()
	task.wait(0.35)
	if STATE.alive() and CFG.WalkSpeedOn then
		applyWalkSpeed()
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

STATE.onCleanup(function()
	applyInstantLoot(false)
	clearEsp()
	if not CFG.AutoRoll then
		setClientAutoRoll(false)
	end
	restoreHooks()
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "Heroes RNG Hub",
	Author = "instant / autofarm / op",
	Folder = "HeroesRngHub",
	Icon = "swords",
	NewElements = true,
	Size = UDim2.fromOffset(580, 470),
	HideSearchBar = true,
	OpenButton = {
		Title = "Heroes RNG",
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

Window:Tag({
	Title = "v1",
	Icon = "swords",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")
local Purple = Color3.fromHex("#7C5CFF")

local MainSec = Window:Section({ Title = "Main", Opened = true })
local FarmSec = Window:Section({ Title = "Farm", Opened = true })
local OpSec = Window:Section({ Title = "OP", Opened = true })

do
	local Tab = MainSec:Tab({ Title = "Home", Icon = "house", IconColor = Green })
	task.wait()
	local para = Tab:Paragraph({
		Title = "Heroes RNG",
		Desc = statusText(),
	})
	Tab:Toggle({
		Title = "Silent Mode",
		Desc = "Mute hub notifications",
		Default = CFG.Silent,
		Value = CFG.Silent,
		Callback = function(v)
			CFG.Silent = v
		end,
	})
	Tab:Button({
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
	Tab:Button({
		Title = "Claim Daily / Offline / Tutorial",
		Icon = "gift",
		Callback = function()
			notify("Claim", claimAll())
		end,
	})
	Tab:Button({
		Title = "Redeem All Codes",
		Icon = "ticket",
		Callback = function()
			notify("Codes", redeemCodes())
		end,
	})
	Tab:Button({
		Title = "Use Gold / XP Potions",
		Icon = "flask-conical",
		Callback = function()
			pcall(function()
				Items.Use("GoldPotion")
			end)
			pcall(function()
				Items.Use("XPPotion")
			end)
			notify("Potions", "use sent")
		end,
	})
end

do
	local Tab = FarmSec:Tab({ Title = "Auto Farm", Icon = "swords", IconColor = Red })
	task.wait()
	Tab:Paragraph({
		Title = "Farm loop",
		Desc = "stays on the highest unlocked biome, buys luck/slots/damage, auto-clicks if unlocked",
	})
	Tab:Toggle({
		Title = "Auto Farm",
		Desc = "master switch for zone + upgrades + click",
		Default = CFG.AutoFarm,
		Value = CFG.AutoFarm,
		Callback = function(v)
			CFG.AutoFarm = v
			notify("Farm", v and "on" or "off")
		end,
	})
	Tab:Toggle({
		Title = "Auto Best Zone",
		Desc = "teleport to highest unlocked biome",
		Default = CFG.AutoZone,
		Value = CFG.AutoZone,
		Callback = function(v)
			CFG.AutoZone = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Unlock Next Zone",
		Desc = "fires RequestZoneUnlock when gold is enough",
		Default = CFG.AutoUnlock,
		Value = CFG.AutoUnlock,
		Callback = function(v)
			CFG.AutoUnlock = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Buy Upgrades",
		Desc = "priority: luck, roll speed, slots, click, damage",
		Default = CFG.AutoUpgrades,
		Value = CFG.AutoUpgrades,
		Callback = function(v)
			CFG.AutoUpgrades = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Click Enemies",
		Desc = "ReportClickAttack nearest alive slot (needs Click Attack)",
		Default = CFG.AutoClick,
		Value = CFG.AutoClick,
		Callback = function(v)
			CFG.AutoClick = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Equip Best",
		Desc = "keeps highest ATK heroes in every slot",
		Default = CFG.AutoEquip,
		Value = CFG.AutoEquip,
		Callback = function(v)
			CFG.AutoEquip = v
		end,
	})
	Tab:Slider({
		Title = "Click Delay",
		Value = { Min = 0.07, Max = 0.4, Default = CFG.ClickDelay },
		Step = 0.01,
		Callback = function(v)
			CFG.ClickDelay = v
		end,
	})
	Tab:Button({
		Title = "Buy Upgrades Now",
		Icon = "shopping-cart",
		Callback = function()
			local n = buyUpgradesOnce()
			notify("Upgrades", "fired " .. tostring(n))
		end,
	})
	Tab:Button({
		Title = "Equip Best Now",
		Icon = "sparkles",
		Callback = function()
			local n = autoEquipBest()
			notify("Equip", tostring(n) .. " slotted")
		end,
	})
end

do
	local Tab = FarmSec:Tab({ Title = "Roll", Icon = "dices", IconColor = Yellow })
	task.wait()
	Tab:Paragraph({
		Title = "Instant roll",
		Desc = "hooks WaitForRollComplete so auto-roll skips the spin. server still rate-limits Roll at ~5/s",
	})
	Tab:Toggle({
		Title = "Instant Roll",
		Desc = "skip roll animation wait",
		Default = CFG.InstantRoll,
		Value = CFG.InstantRoll,
		Callback = function(v)
			CFG.InstantRoll = v
			ensureRollHooks()
			notify("Instant Roll", v and "on" or "off")
		end,
	})
	Tab:Toggle({
		Title = "Auto Roll",
		Desc = "uses the game StartAutoRollCompact path + SetAutoRoll",
		Default = CFG.AutoRoll,
		Value = CFG.AutoRoll,
		Callback = function(v)
			CFG.AutoRoll = v
			setClientAutoRoll(v)
			notify("Auto Roll", v and "on" or "off")
		end,
	})
	Tab:Toggle({
		Title = "Skip Cutscenes",
		Desc = "SetSetting Cutscene = off",
		Default = CFG.SkipCutscene,
		Value = CFG.SkipCutscene,
		Callback = function(v)
			CFG.SkipCutscene = v
			applySettings()
		end,
	})
	Tab:Button({
		Title = "Roll Once",
		Icon = "rotate-cw",
		Callback = function()
			local ok, res = forceRoll()
			notify("Roll", ok and "sent" or tostring(res))
		end,
	})
end

do
	local Tab = OpSec:Tab({ Title = "Instant", Icon = "zap", IconColor = Purple })
	task.wait()
	Tab:Toggle({
		Title = "Instant Loot",
		Desc = "patches Config magnet tween / auto-loot delay to near zero",
		Default = CFG.InstantLoot,
		Value = CFG.InstantLoot,
		Callback = function(v)
			CFG.InstantLoot = v
			applyInstantLoot(v)
		end,
	})
	Tab:Toggle({
		Title = "Skip Combat VFX",
		Desc = "Settings CombatVfx off",
		Default = CFG.SkipCombatVfx,
		Value = CFG.SkipCombatVfx,
		Callback = function(v)
			CFG.SkipCombatVfx = v
			applySettings()
		end,
	})
	Tab:Toggle({
		Title = "Instant Fuse Anim",
		Desc = "hooks FusionAnimation.IsPlaying so fuse is not blocked",
		Default = CFG.InstantFuse,
		Value = CFG.InstantFuse,
		Callback = function(v)
			CFG.InstantFuse = v
			ensureRollHooks()
		end,
	})
	Tab:Toggle({
		Title = "Auto Fuse",
		Desc = "FuseHero when a size has 10+ copies",
		Default = CFG.AutoFuse,
		Value = CFG.AutoFuse,
		Callback = function(v)
			CFG.AutoFuse = v
		end,
	})
	Tab:Toggle({
		Title = "Enemy ESP",
		Desc = "Highlight on alive zone models",
		Default = CFG.EnemyEsp,
		Value = CFG.EnemyEsp,
		Callback = function(v)
			CFG.EnemyEsp = v
			if not v then
				clearEsp()
			end
		end,
	})
	Tab:Button({
		Title = "Fuse Now",
		Icon = "layers",
		Callback = function()
			local n = autoFuseOnce()
			notify("Fuse", tostring(n) .. " requests")
		end,
	})
end

do
	local Tab = OpSec:Tab({ Title = "Player", Icon = "person-standing", IconColor = Blue })
	task.wait()
	Tab:Toggle({
		Title = "Walk Speed",
		Default = CFG.WalkSpeedOn,
		Value = CFG.WalkSpeedOn,
		Callback = function(v)
			CFG.WalkSpeedOn = v
			if v then
				applyWalkSpeed()
			end
		end,
	})
	Tab:Slider({
		Title = "Speed",
		Value = { Min = 16, Max = 80, Default = CFG.WalkSpeed },
		Step = 1,
		Callback = function(v)
			CFG.WalkSpeed = v
			if CFG.WalkSpeedOn then
				applyWalkSpeed()
			end
		end,
	})
	Tab:Toggle({
		Title = "Infinite Jump",
		Default = CFG.InfJump,
		Value = CFG.InfJump,
		Callback = function(v)
			CFG.InfJump = v
		end,
	})
	Tab:Toggle({
		Title = "Anti AFK",
		Default = CFG.AntiAfk,
		Value = CFG.AntiAfk,
		Callback = function(v)
			CFG.AntiAfk = v
		end,
	})
end

do
	local Tab = OpSec:Tab({ Title = "Teleport", Icon = "map", IconColor = Green })
	task.wait()
	local values = { "Best" }
	for _, id in ipairs(zoneOrder()) do
		table.insert(values, id)
	end
	Tab:Dropdown({
		Title = "Zone",
		Values = values,
		Value = CFG.ZonePick,
		Callback = function(v)
			if typeof(v) == "table" then
				v = v[1] or CFG.ZonePick
			end
			CFG.ZonePick = tostring(v)
		end,
	})
	Tab:Button({
		Title = "Teleport Selected",
		Icon = "map-pin",
		Callback = function()
			local id = CFG.ZonePick
			if id == "Best" then
				id = bestUnlockedZone()
			end
			local ok = teleportZone(id)
			notify("TP", ok and id or "refused " .. tostring(id))
		end,
	})
	Tab:Button({
		Title = "Arena",
		Icon = "skull",
		Callback = function()
			local ok, res = invoke("RequestArenaTeleport", true)
			notify("Arena", ok and tostring(res) or tostring(res))
		end,
	})
	Tab:Button({
		Title = "Enter Tower",
		Icon = "building-2",
		Callback = function()
			local ok, res = invoke("EnterTower")
			notify("Tower", ok and tostring(res) or tostring(res))
		end,
	})
end

pcall(function()
	Window:SelectTab(1)
end)

notify("Heroes RNG", "hub loaded  |  " .. statusText())

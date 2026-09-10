--[[
  Deep Fishing Hub — WindUI
  live-reload label: deep_fishing_hub
  Place 132239307080610 / Universe 10526853622

  Built against the live client:
    Warp Events.Client(name):Fire(true, ...)
    Fishing:StartHook / StopHook / CanStartThrow
    ThrowCinematic ThrowRod fire
    AutoFishing.SetOn / DriveCast (Toggle is Level 5 gated, SetOn is not)
    CatchMinigame.Finish(true) -> FishSchool:CompleteGrab + FishHooked won
    Shared.Content.Item.{Fish,Rod,Bait,Obstacle,Skin} indexes
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
if not STATE.store then
	STATE.store = {}
end
local store = STATE.store

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
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
	local ok, src = pcall(function()
		return game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
	end)
	if ok and type(src) == "string" and #src > 100 then
		local fn, err = loadstring(src, "@WindUI")
		assert(fn, "WindUI compile failed: " .. tostring(err))
		return fn()
	end
	error("WindUI not found")
end

local WindUI = loadWindUI()

local CFG = store.CFG or {
	AutoFarm = false,
	InstantFarm = false,
	InstantFight = true,
	PerfectThrow = true,
	AutoSell = false,
	AntiAfk = true,
	KeepSpeed = false,
	WalkSpeed = 24,
	JumpPower = 50,
	Fov = 70,
	FarmDelay = 0.12,
	SelectedFish = "Bass",
	SelectedRod = "Wooden Rod",
	SelectedBait = "Classic Bait",
	SelectedWorld = "World 1",
	SelectedUpgrade = "Strength",
	SelectedEvent = "ThrowRod",
	SpawnKind = "Fish",
	BestOnly = true,
}
store.CFG = CFG
if CFG.BestOnly == nil then
	CFG.BestOnly = true
end

local function farmEnabled()
	return CFG.AutoFarm == true or CFG.InstantFarm == true
end

local SCAN = store.SCAN or {
	fish = {},
	rods = {},
	baits = {},
	obstacles = {},
	skins = {},
	events = {},
	worlds = {},
	upgrades = { "Strength", "Weight", "Capacity", "Bounce" },
	codes = {},
	prefabs = {},
	remotes = {},
	status = "booting",
}
store.SCAN = SCAN

local function notify(title, content)
	pcall(function()
		WindUI:Notify({ Title = title, Content = content, Duration = 2.4 })
	end)
end

local function req(inst)
	if not inst then
		return nil
	end
	local ok, mod = pcall(require, inst)
	if ok then
		return mod
	end
	return nil
end

local function namesOf(mod)
	local names = {}
	if type(mod) ~= "table" then
		return names
	end
	local src = mod.Items or mod.Index or mod.List or mod.Data or mod
	if type(src) ~= "table" then
		return names
	end
	for k, v in pairs(src) do
		if type(k) == "string" then
			table.insert(names, k)
		elseif type(v) == "table" and type(v.Name) == "string" then
			table.insert(names, v.Name)
		elseif type(v) == "string" then
			table.insert(names, v)
		end
	end
	table.sort(names)
	return names
end

local ContentItem = req(ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Content") and ReplicatedStorage.Shared.Content:FindFirstChild("Item"))
local FishMod = ContentItem and ContentItem.Fish
local RodMod = ContentItem and ContentItem.Rod
local BaitMod = ContentItem and ContentItem.Bait
local ObstacleMod = ContentItem and ContentItem.Obstacle
local SkinMod = ContentItem and ContentItem.Skin
local CatchFight = req(ReplicatedStorage.Shared.Modules.CatchFight)
local CodesConfig = req(ReplicatedStorage.Shared.Config.CodesConfig)
local WorldsConfig = req(ReplicatedStorage.Shared.Config.WorldsConfig)
local MutationConfig = req(ReplicatedStorage.Shared.Config.MutationConfig)
local PlayerData = req(ReplicatedStorage.Shared.PlayerData)

local function findFramework()
	if store.fw and store.fw.Controllers and store.fw.Events then
		local fishing = store.fw.Controllers.Fishing
		if fishing and typeof(fishing.StartHook) == "function" then
			return store.fw
		end
		store.fw = nil
	end
	if typeof(filtergc) ~= "function" then
		return nil
	end
	local first = filtergc("table", { Keys = { "Controllers", "Events", "PlayerData", "Content" } }, true)
	local matches = type(first) == "table" and { first } or {}
	for _, t in ipairs(matches) do
		if type(t) == "table" and type(t.Controllers) == "table" and type(t.Events) == "table" then
			local fishing = t.Controllers.Fishing
			if fishing and (typeof(fishing.StartHook) == "function" or typeof(fishing.CanStartThrow) == "function") then
				store.fw = t
				return t
			end
		end
	end
	return nil
end

local function fireEvent(name, ...)
	local fw = findFramework()
	if not fw or not fw.Events or typeof(fw.Events.Client) ~= "function" then
		return false, "no framework"
	end
	local args = table.pack(...)
	local ok, err = pcall(function()
		fw.Events.Client(name):Fire(true, table.unpack(args, 1, args.n))
	end)
	return ok, err
end

local function getFishing()
	local fw = findFramework()
	return fw and fw.Controllers and fw.Controllers.Fishing or nil
end

local function getAutoFishing()
	local fishing = getFishing()
	if not fishing then
		return nil
	end
	local auto = rawget(fishing, "AutoFishing")
	if typeof(auto) == "table" then
		return auto
	end
	return fishing.AutoFishing
end

local function getThrow()
	local fw = findFramework()
	return fw and fw.Controllers and fw.Controllers.ThrowCinematic or nil
end

local function getCatch()
	local throw = getThrow()
	if not throw then
		return nil
	end
	local sub = throw.Sub
	if type(sub) == "table" and type(sub.CatchMinigame) == "table" then
		return sub.CatchMinigame
	end
	return rawget(throw, "CatchMinigame")
end

local function playerData()
	if PlayerData and PlayerData.Client and type(PlayerData.Client.Data) == "table" then
		return PlayerData.Client.Data
	end
	local fw = findFramework()
	if fw and fw.PlayerData and typeof(fw.PlayerData.Get) == "function" then
		local ok, data = pcall(function()
			return fw.PlayerData:Get()
		end)
		if ok then
			return data
		end
	end
	return nil
end

local function fmtMoney(n)
	n = tonumber(n) or 0
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	end
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	end
	if n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n + 0.5))
end

local function fishValue(fish)
	if type(fish) ~= "table" then
		return 0
	end
	local name = fish.name or fish.Name
	if type(name) ~= "string" then
		return 0
	end
	local fw = findFramework()
	if fw and fw.Services and fw.Services.Item and typeof(fw.Services.Item.GetSellValue) == "function" then
		local ok, val = pcall(function()
			return fw.Services.Item:GetSellValue(LocalPlayer, {
				Type = "Fish",
				Name = name,
				Data = {
					Size = fish.size or 1,
					Mutation = fish.mutation,
				},
			})
		end)
		if ok and type(val) == "number" then
			return val
		end
	end
	local rec = FishMod and typeof(FishMod.Get) == "function" and FishMod:Get(name, true)
	local price = rec and tonumber(rec.SellPrice) or 0
	local size = tonumber(fish.size) or 1
	local mult = 1
	local mut = fish.mutation
	if type(mut) == "string" and MutationConfig and typeof(MutationConfig.Get) == "function" then
		local m = MutationConfig.Get(mut)
		if type(m) == "table" then
			mult = tonumber(m.SellMultiplier) or 1
		end
	end
	return price * (size ^ 3) * mult
end

local function rankedSchool(school)
	local ranked = {}
	if not school or type(school.Fish) ~= "table" then
		return ranked
	end
	for _, fish in ipairs(school.Fish) do
		if type(fish) == "table" and not fish.caught and not fish.escaped and fish.model and fish.model.Parent then
			table.insert(ranked, {
				fish = fish,
				value = fishValue(fish),
				name = fish.name or fish.Name or "?",
			})
		end
	end
	table.sort(ranked, function(a, b)
		return a.value > b.value
	end)
	return ranked
end

local function remainingGrabSlots(throw)
	local cap, caught = 1, 0
	if throw then
		pcall(function()
			cap = throw:GetBaitCapacity()
		end)
		pcall(function()
			caught = throw:CaughtFishCount()
		end)
	end
	local slots = math.max(0, (tonumber(cap) or 1) - (tonumber(caught) or 0))
	return slots
end

---------------------------------------------------------------
-- Index scan (content catalogs + Warp events + prefabs)
---------------------------------------------------------------
local function scanIndexes()
	SCAN.fish = namesOf(FishMod)
	SCAN.rods = namesOf(RodMod)
	SCAN.baits = namesOf(BaitMod)
	SCAN.obstacles = namesOf(ObstacleMod)
	SCAN.skins = namesOf(SkinMod)

	SCAN.events = {}
	local eventsFolder = ReplicatedStorage.Shared:FindFirstChild("Events")
	if eventsFolder then
		for _, child in ipairs(eventsFolder:GetChildren()) do
			table.insert(SCAN.events, child.Name)
		end
		table.sort(SCAN.events)
	end

	SCAN.worlds = {}
	if WorldsConfig and type(WorldsConfig.Worlds) == "table" then
		for key, rec in pairs(WorldsConfig.Worlds) do
			table.insert(SCAN.worlds, tostring(key))
		end
		table.sort(SCAN.worlds)
	end

	SCAN.codes = {}
	if CodesConfig and type(CodesConfig.Codes) == "table" then
		for _, rec in ipairs(CodesConfig.Codes) do
			if type(rec) == "table" and type(rec.Code) == "string" then
				table.insert(SCAN.codes, rec.Code)
			end
		end
	end

	SCAN.prefabs = {}
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	if prefabs then
		for _, child in ipairs(prefabs:GetChildren()) do
			table.insert(SCAN.prefabs, child.ClassName .. ":" .. child.Name)
			if #SCAN.prefabs >= 80 then
				break
			end
		end
	end

	if #SCAN.fish > 0 then
		CFG.SelectedFish = SCAN.fish[1]
	end
	if #SCAN.rods > 0 then
		CFG.SelectedRod = SCAN.rods[1]
	end
	if #SCAN.baits > 0 then
		CFG.SelectedBait = SCAN.baits[1]
	end
	if #SCAN.worlds > 0 then
		CFG.SelectedWorld = SCAN.worlds[1]
	end
	if #SCAN.events > 0 then
		CFG.SelectedEvent = SCAN.events[1]
	end

	SCAN.status = string.format(
		"fish %d · rods %d · bait %d · obstacles %d · events %d · worlds %d · codes %d",
		#SCAN.fish,
		#SCAN.rods,
		#SCAN.baits,
		#SCAN.obstacles,
		#SCAN.events,
		#SCAN.worlds,
		#SCAN.codes
	)
	return SCAN
end

scanIndexes()

---------------------------------------------------------------
-- Function-name spoof + hookfunction
---------------------------------------------------------------
if not store.hooks then
	store.hooks = {}
end

local function origName(fn)
	local name = "fn"
	pcall(function()
		if typeof(debug.info) == "function" then
			name = debug.info(fn, "n") or name
		end
	end)
	return name
end

local function wrapNamed(fn, name)
	if typeof(newcclosure) == "function" then
		local ok, wrapped = pcall(newcclosure, fn, name)
		if ok and typeof(wrapped) == "function" then
			return wrapped
		end
	end
	return fn
end

local function detour(target, hookFn)
	if typeof(target) ~= "function" or typeof(hookfunction) ~= "function" then
		return nil
	end
	if store.hooks[target] then
		return store.hooks[target]
	end
	local name = origName(target)
	local old
	local wrapped = wrapNamed(function(...)
		return hookFn(old, ...)
	end, name)
	local ok, result = pcall(hookfunction, target, wrapped)
	if not ok then
		return nil
	end
	old = result
	store.hooks[target] = old
	return old
end

STATE.onCleanup(function()
	for target, old in pairs(store.hooks) do
		pcall(hookfunction, target, old)
	end
	table.clear(store.hooks)
end)

-- Function names are spoofed via newcclosure's debug name (second arg).
-- We do not hook debug.info itself: that path re-enters during traces.

-- Namecall broker: record FireServer traffic and optionally pass through
if typeof(STATE.namecallHook) == "function" then
	STATE.namecallHook("FireServer", function(self, method, ...)
		if typeof(self) == "Instance" then
			local key = self:GetFullName()
			if not SCAN.remotes[key] then
				SCAN.remotes[key] = { method = method, n = 0 }
			end
			SCAN.remotes[key].n += 1
		end
	end)
end

---------------------------------------------------------------
-- Game-system hooks (AutoFishing / CatchFight / CatchMinigame)
---------------------------------------------------------------
local function installGameHooks()
	local fishing = getFishing()
	local auto = getAutoFishing()
	local catch = getCatch()

	if auto and typeof(auto.Toggle) == "function" then
		detour(auto.Toggle, function(old, self)
			if farmEnabled() then
				if typeof(self.SetOn) == "function" then
					self:SetOn(not self.On)
					return
				end
			end
			return old(self)
		end)
	end

	if auto and typeof(auto.DriveCast) == "function" then
		detour(auto.DriveCast, function(old, self, fishingCtrl)
			if not farmEnabled() then
				return old(self, fishingCtrl)
			end
			if not CFG.InstantFarm and not CFG.PerfectThrow then
				return old(self, fishingCtrl)
			end
			self.DrivingThrow = true
			fishingCtrl:StartHook()
			if not fishingCtrl.Charging then
				self.DrivingThrow = false
				return
			end
			if not CFG.InstantFarm then
				task.wait(0.15)
			end
			if CFG.PerfectThrow then
				fishingCtrl.HookT = 0.52
			end
			fishingCtrl:StopHook()
		end)
	end

	if auto and typeof(auto.PickTarget) == "function" then
		detour(auto.PickTarget, function(old, self, fishList, hangY)
			if not CFG.BestOnly then
				return old(self, fishList, hangY)
			end
			local best, bestV = nil, -1
			for _, fish in ipairs(fishList or {}) do
				local valid = true
				if typeof(self.TargetValid) == "function" then
					valid = self:TargetValid(fish, hangY)
				end
				if valid then
					local v = fishValue(fish)
					if v > bestV then
						best, bestV = fish, v
					end
				end
			end
			return best or old(self, fishList, hangY)
		end)
	end

	if CatchFight then
		if typeof(CatchFight.Decay) == "function" then
			detour(CatchFight.Decay, function(old, fish)
				if CFG.InstantFight or CFG.InstantFarm then
					return 0
				end
				return old(fish)
			end)
		end
		pcall(function()
			if CFG.InstantFight or CFG.InstantFarm then
				CatchFight.MaxClickRate = 48
				CatchFight.StartFill = 0.92
			end
		end)
	end

	local catchMod = LocalPlayer:FindFirstChild("PlayerScripts")
	catchMod = catchMod and catchMod:FindFirstChild("Client")
	catchMod = catchMod and catchMod:FindFirstChild("Controllers")
	catchMod = catchMod and catchMod:FindFirstChild("ThrowCinematic")
	catchMod = catchMod and catchMod:FindFirstChild("CatchMinigame")
	local catchTable = req(catchMod) or catch

	if catchTable and typeof(catchTable.Begin) == "function" then
		detour(catchTable.Begin, function(old, self, fish, def)
			local result = old(self, fish, def)
			if (CFG.InstantFight or CFG.InstantFarm) and self.Fight and typeof(self.Finish) == "function" then
				task.defer(function()
					if self.Fight then
						self:Finish(true)
					end
				end)
			end
			return result
		end)
	end

	if catchTable and typeof(catchTable.Click) == "function" then
		detour(catchTable.Click, function(old, self)
			if CFG.InstantFight or CFG.InstantFarm then
				local fight = self.Fight
				if fight then
					fight.lastCredit = 0
					fight.progress = 1
				end
			end
			return old(self)
		end)
	end
end

pcall(installGameHooks)

---------------------------------------------------------------
-- Farm driver
---------------------------------------------------------------
local function throwArea()
	local fw = findFramework()
	if fw and fw.Utils and fw.Utils.WorldFolder and typeof(fw.Utils.WorldFolder.Interactable) == "function" then
		local ok, area = pcall(function()
			return fw.Utils.WorldFolder.Interactable("Throw")
		end)
		if ok and area then
			return area
		end
	end
	local wf = req(ReplicatedStorage.Shared.Utils.WorldFolder)
	if wf and typeof(wf.Interactable) == "function" then
		local ok, area = pcall(function()
			return wf.Interactable("Throw")
		end)
		if ok then
			return area
		end
	end
	return nil
end

local function enterThrowZone()
	local fishing = getFishing()
	if fishing and fishing:InArea() then
		return true
	end
	local area = throwArea()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not area or not hrp then
		return false
	end
	local cf = area:GetBoundingBox()
	hrp.CFrame = CFrame.new(cf.Position.X, cf.Position.Y + 3, cf.Position.Z)
	return true
end

local function equipRod()
	local auto = getAutoFishing()
	if auto and typeof(auto.EquipRod) == "function" then
		local ok = auto:EquipRod()
		if ok then
			return true
		end
	end
	local data = playerData()
	local name = data and data.RodEquipped or "Wooden Rod"
	local char = LocalPlayer.Character
	if char and char:FindFirstChild(name) then
		return true
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(name)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and tool and tool:IsA("Tool") then
		hum:EquipTool(tool)
		return true
	end
	return false
end

local function doCast()
	local fishing = getFishing()
	if not fishing then
		return false, "no fishing controller"
	end
	enterThrowZone()
	equipRod()
	task.wait(0.15)
	local okStart, reason = fishing:CanStartThrow()
	if not okStart then
		return false, reason or "cannot throw"
	end
	local auto = getAutoFishing()
	if auto then
		auto.On = true
		auto.DrivingThrow = true
	end
	fishing:StartHook()
	if CFG.PerfectThrow or CFG.InstantFarm then
		fishing.HookT = 0.52
	end
	if not CFG.InstantFarm then
		task.wait(0.05)
	end
	fishing:StopHook()
	return true
end

local function grabFishSchool()
	local throw = getThrow()
	if not throw or not throw.Catchable then
		return 0
	end
	local school = throw.Sub and throw.Sub.FishSchool
	if not school or type(school.Fish) ~= "table" then
		return 0
	end
	local ranked = rankedSchool(school)
	if #ranked == 0 then
		return 0
	end
	local slots = remainingGrabSlots(throw)
	if slots <= 0 then
		return 0
	end
	local auto = getAutoFishing()
	if auto then
		auto.Target = ranked[1].fish
	end
	local catch = getCatch()
	local n = 0
	for i = 1, math.min(slots, #ranked) do
		local entry = ranked[i]
		local fish = entry.fish
		if type(fish) == "table" and not fish.caught and not fish.escaped then
			local fighting = false
			if catch and typeof(catch.Offer) == "function" then
				local ok, offered = pcall(function()
					return catch:Offer(fish)
				end)
				fighting = ok and offered == true
			end
			if fighting and catch and catch.Fight and typeof(catch.Finish) == "function" then
				pcall(function()
					catch:Finish(true)
				end)
				n += 1
			elseif typeof(school.CompleteGrab) == "function" then
				pcall(function()
					school:CompleteGrab(fish, 12)
				end)
				n += 1
			end
			if n == 1 and store.lastBestThrow ~= throw.ThrowId then
				store.lastBestThrow = throw.ThrowId
				local mut = fish.mutation
				local label = entry.name
				if type(mut) == "string" and mut ~= "" then
					label = mut .. " " .. label
				end
				notify("Catch", string.format("%s  $%s  fill %d", label, fmtMoney(entry.value), slots))
			end
		end
	end
	return n
end

local function winFight()
	local catch = getCatch()
	if not catch then
		return
	end
	if catch.Fight and typeof(catch.Finish) == "function" then
		catch:Finish(true)
		return
	end
	if typeof(catch.Click) == "function" then
		for _ = 1, 8 do
			catch:Click()
		end
	end
end

local function enableAutoSell(on)
	fireEvent("AutoDelete", "AutoSell", "Enabled", on == true)
end

local farmToken = 0

local function disableAutoFishing()
	local auto = getAutoFishing()
	if auto then
		auto.DrivingThrow = false
		auto.Target = nil
		auto.On = false
		if typeof(auto.SetOn) == "function" then
			pcall(function()
				auto:SetOn(false)
			end)
		end
	end
	local throw = getThrow()
	if throw then
		pcall(function()
			throw.AimLocked = false
		end)
	end
end

local function stopFarm()
	farmToken += 1
	disableAutoFishing()
end

local function startFarmLoop()
	farmToken += 1
	local token = farmToken
	task.spawn(function()
		notify("Farm", "walk into water if needed")
		while STATE.alive() and token == farmToken and farmEnabled() do
			local fishing = getFishing()
			local throw = getThrow()
			local auto = getAutoFishing()
			if not farmEnabled() then
				break
			end
			if auto then
				auto.On = true
				auto.DrivingThrow = true
			end
			if throw and throw.Active then
				if throw.Catchable then
					if throw.ThrowId ~= store.farmThrowId then
						store.farmThrowId = throw.ThrowId
						store.farmEmptyT = 0
						store.farmGrabbed = 0
					end
					local school = throw.Sub and throw.Sub.FishSchool
					local ranked = rankedSchool(school)
					if #ranked > 0 then
						store.farmEmptyT = 0
						if auto then
							auto.Target = ranked[1].fish
						end
						local grabbed = grabFishSchool()
						store.farmGrabbed = (store.farmGrabbed or 0) + grabbed
						winFight()
					else
						store.farmEmptyT = (store.farmEmptyT or 0) + 0.08
					end
					local slotsLeft = remainingGrabSlots(throw)
					local full = slotsLeft <= 0
					local schoolDone = #ranked == 0 and (store.farmEmptyT or 0) >= 0.55
					if CFG.InstantFarm and farmEnabled() and typeof(throw.RequestReel) == "function" then
						if full or (schoolDone and (store.farmGrabbed or 0) > 0) then
							task.wait(0.12)
							pcall(function()
								if farmEnabled() then
									throw:RequestReel()
								end
							end)
						end
					end
				end
				task.wait(0.08)
			else
				enterThrowZone()
				equipRod()
				local can, reason = false, "no fishing"
				if fishing then
					can, reason = fishing:CanStartThrow()
				end
				if can and farmEnabled() then
					pcall(doCast)
					task.wait(0.25)
				else
					SCAN.status = tostring(reason or "waiting")
					if reason == "not_in_area" then
						enterThrowZone()
					end
					task.wait(0.3)
				end
			end
		end
		if not farmEnabled() then
			disableAutoFishing()
		end
	end)
end

---------------------------------------------------------------
-- Catalog spawn: world preview, backpack Tool, or hold on character
-- Inventory GUIDs are Replica/server. Local inject shows in backpack UI
-- and as a Tool you can hold. Sell/trade/save still need a server grant.
---------------------------------------------------------------
local HttpService = game:GetService("HttpService")

local function catalogMod(kind)
	if kind == "Fish" then
		return FishMod
	elseif kind == "Rod" then
		return RodMod
	elseif kind == "Bait" then
		return BaitMod
	elseif kind == "Obstacle" then
		return ObstacleMod
	end
	return nil
end

local function selectedSpawnName()
	if CFG.SpawnKind == "Rod" then
		return CFG.SelectedRod
	elseif CFG.SpawnKind == "Bait" then
		return CFG.SelectedBait
	elseif CFG.SpawnKind == "Obstacle" then
		return SCAN.obstacles[1]
	end
	return CFG.SelectedFish
end

local function getCatalogModel(kind, name)
	local mod = catalogMod(kind)
	if not mod or typeof(mod.GetInstance) ~= "function" then
		return nil, "no GetInstance"
	end
	local ok, inst = pcall(function()
		return mod:GetInstance(name)
	end)
	if not ok or typeof(inst) ~= "Instance" then
		ok, inst = pcall(function()
			return mod.GetInstance(name)
		end)
	end
	if typeof(inst) ~= "Instance" then
		return nil, "index has no model"
	end
	return inst
end

local function makeToolFromModel(name, model)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("HotbarTool", true)
	tool:SetAttribute("HubSpawned", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false
	handle.Parent = tool

	if model:IsA("Model") then
		pcall(function()
			model:PivotTo(handle.CFrame)
		end)
		model.Parent = tool
	elseif model:IsA("BasePart") then
		model.Parent = tool
	else
		model.Parent = tool
	end

	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			p.CanQuery = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
	return tool
end

local function injectInventory(kind, name, tool)
	local guid = HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 12)
	local itemData = {
		Name = name,
		Type = kind,
		Data = {
			Kg = 1,
			Locked = false,
			Amount = 1,
		},
	}
	if PlayerData and PlayerData.Client and type(PlayerData.Client.Data) == "table" then
		if type(PlayerData.Client.Data.Inventory) ~= "table" then
			PlayerData.Client.Data.Inventory = {}
		end
		PlayerData.Client.Data.Inventory[guid] = itemData
	end
	local fw = findFramework()
	local pack = fw and fw.Controllers and fw.Controllers.Backpack
	if pack then
		if type(pack.InventoryCache) ~= "table" then
			pack.InventoryCache = {}
		end
		pack.InventoryCache[guid] = itemData
		pcall(function()
			local slot = pack:CreateInventorySlot()
			pack:ApplySlotContent(slot, guid, itemData, tool)
			if pack.UpdateCapLabel then
				pack:UpdateCapLabel()
			end
			if pack.UI and pack.UI.Open then
				pack.UI:Open("Inventory")
			end
		end)
	end
	tool:SetAttribute("GUID", guid)
	return guid
end

local function spawnIntoBackpack(kind, name, equip)
	local inst, err = getCatalogModel(kind, name)
	if not inst then
		return false, err
	end
	local tool = makeToolFromModel(name, inst)
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then
		return false, "no backpack"
	end
	tool.Parent = backpack
	injectInventory(kind, name, tool)
	if kind == "Rod" then
		fireEvent("RodShop", "Equip", name)
	end
	if equip then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:EquipTool(tool)
		end
	end
	return true
end

local function spawnPreview(kind, name)
	local inst, err = getCatalogModel(kind, name)
	if not inst then
		return false, err
	end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cf = hrp and (hrp.CFrame * CFrame.new(0, 2, -8)) or CFrame.new(0, 10, 0)
	pcall(function()
		if inst:IsA("Model") then
			inst:PivotTo(cf)
		elseif inst:IsA("BasePart") then
			inst.CFrame = cf
		end
		inst.Parent = workspace
	end)
	Debris:AddItem(inst, 5)
	return true
end

---------------------------------------------------------------
-- Claims / shop helpers
---------------------------------------------------------------
local function redeemAllCodes()
	local n = 0
	for _, code in ipairs(SCAN.codes) do
		fireEvent("Codes", code)
		n += 1
		task.wait(0.35)
	end
	return n
end

local function claimAll()
	fireEvent("PlaytimeGift", "Claim")
	fireEvent("NextDayReward")
	fireEvent("EarlyLeaveReward")
	fireEvent("Group")
	fireEvent("GroupReward")
	fireEvent("LikeGift", "Claim")
	local rarity = req(ReplicatedStorage.Shared.Config.RarityConfig)
	if rarity then
		local keys = namesOf(rarity)
		if #keys == 0 then
			for k in pairs(rarity) do
				if type(k) == "string" then
					fireEvent("Index", k)
				end
			end
		else
			for _, k in ipairs(keys) do
				fireEvent("Index", k)
			end
		end
	end
end

---------------------------------------------------------------
-- Anti AFK / movement
---------------------------------------------------------------
STATE.connect(LocalPlayer.Idled, function()
	if CFG.AntiAfk then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

local function humanoid()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function applyMove()
	local h = humanoid()
	if not h then
		return
	end
	if CFG.KeepSpeed then
		pcall(function()
			h.WalkSpeed = CFG.WalkSpeed
			h.UseJumpPower = true
			h.JumpPower = CFG.JumpPower
		end)
	end
end

STATE.connect(LocalPlayer.CharacterAdded, function()
	task.wait(0.4)
	applyMove()
end)
STATE.connect(RunService.Heartbeat, function()
	if CFG.KeepSpeed then
		applyMove()
	end
	if not farmEnabled() then
		local auto = getAutoFishing()
		if auto and (auto.On or auto.DrivingThrow) then
			disableAutoFishing()
		end
	end
end)

---------------------------------------------------------------
-- UI
---------------------------------------------------------------
local Window = WindUI:CreateWindow({
	Title = "Deep Fishing",
	Icon = "fish",
	Author = "index scan · hooks · Warp events",
	Folder = "DeepFishingHub",
	Size = UDim2.fromOffset(580, 480),
	Theme = "Dark",
	Resizable = true,
	ToggleKey = Enum.KeyCode.RightShift,
})

local FarmTab = Window:Tab({ Title = "Farm", Icon = "bot" })
FarmTab:Paragraph({
	Title = "Live catch",
	Desc = "Auto Farm warps you into the Throw zone, perfect-casts, then CompleteGrab on the school ranked by SellValue (size + mutation). It keeps grabbing the richest remaining fish until bait capacity is full, then reels. Do not recast during an active throw.",
})

FarmTab:Toggle({
	Title = "Auto Farm",
	Desc = "Equip rod, SetOn AutoFishing, perfect casts, fight assist",
	Default = CFG.AutoFarm,
	Callback = function(v)
		CFG.AutoFarm = v
		if v then
			pcall(installGameHooks)
			startFarmLoop()
			notify("Auto Farm", "ON")
		else
			CFG.InstantFarm = false
			stopFarm()
			notify("Auto Farm", "OFF — stopped")
		end
	end,
})

FarmTab:Toggle({
	Title = "Instant Farm",
	Desc = "DriveCast no wait + instant fight win + 50ms recast",
	Default = CFG.InstantFarm,
	Callback = function(v)
		CFG.InstantFarm = v
		if v then
			CFG.AutoFarm = true
			pcall(installGameHooks)
			startFarmLoop()
			notify("Instant Farm", "ON")
		else
			CFG.InstantFarm = false
			CFG.AutoFarm = false
			stopFarm()
			notify("Instant Farm", "OFF — stopped")
		end
	end,
})

FarmTab:Toggle({
	Title = "Perfect Throw",
	Desc = "HookT = 0.52 (Perfect window on the hook meter)",
	Default = CFG.PerfectThrow,
	Callback = function(v)
		CFG.PerfectThrow = v
	end,
})

FarmTab:Toggle({
	Title = "Instant Fight",
	Desc = "CatchMinigame.Finish(true) + CatchFight decay 0",
	Default = CFG.InstantFight,
	Callback = function(v)
		CFG.InstantFight = v
		pcall(installGameHooks)
	end,
})

FarmTab:Toggle({
	Title = "Best first",
	Desc = "Fill bait with highest SellValue first (size + mutation), then cheaper fish until full",
	Default = CFG.BestOnly,
	Callback = function(v)
		CFG.BestOnly = v
		pcall(installGameHooks)
		notify("Best first", v and "ON — expensive then fill" or "OFF — grab in spawn order")
	end,
})

FarmTab:Toggle({
	Title = "Request Auto Sell",
	Desc = "AutoDelete AutoSell Enabled (server may require the pass)",
	Default = CFG.AutoSell,
	Callback = function(v)
		CFG.AutoSell = v
		enableAutoSell(v)
	end,
})

FarmTab:Slider({
	Title = "Farm delay (auto, not instant)",
	Value = { Min = 0.05, Max = 1.2, Default = CFG.FarmDelay },
	Callback = function(v)
		CFG.FarmDelay = v
	end,
})

FarmTab:Button({
	Title = "STOP ALL",
	Callback = function()
		CFG.AutoFarm = false
		CFG.InstantFarm = false
		stopFarm()
		notify("Farm", "all stopped")
	end,
})

FarmTab:Button({
	Title = "Cast once (perfect)",
	Callback = function()
		equipRod()
		local ok, err = doCast()
		notify("Cast", ok and "sent ThrowRod" or tostring(err))
	end,
})

FarmTab:Button({
	Title = "Win current fight",
	Callback = function()
		winFight()
		notify("Fight", "Finish(true)")
	end,
})

---------------------------------------------------------------
local ShopTab = Window:Tab({ Title = "Shop / Upgrades", Icon = "shopping-cart" })
ShopTab:Dropdown({
	Title = "Bait",
	Values = SCAN.baits,
	Value = CFG.SelectedBait,
	Callback = function(v)
		CFG.SelectedBait = v
	end,
})
ShopTab:Button({
	Title = "Buy selected bait",
	Callback = function()
		fireEvent("BaitShop", "Buy", CFG.SelectedBait)
		notify("BaitShop", "Buy " .. tostring(CFG.SelectedBait))
	end,
})
ShopTab:Dropdown({
	Title = "Rod",
	Values = SCAN.rods,
	Value = CFG.SelectedRod,
	Callback = function(v)
		CFG.SelectedRod = v
	end,
})
ShopTab:Button({
	Title = "Buy selected rod",
	Callback = function()
		fireEvent("RodShop", "Buy", CFG.SelectedRod)
		notify("RodShop", "Buy " .. tostring(CFG.SelectedRod))
	end,
})
ShopTab:Button({
	Title = "Equip selected rod",
	Callback = function()
		fireEvent("RodShop", "Equip", CFG.SelectedRod)
		notify("RodShop", "Equip " .. tostring(CFG.SelectedRod))
	end,
})
ShopTab:Dropdown({
	Title = "Upgrade",
	Values = SCAN.upgrades,
	Value = CFG.SelectedUpgrade,
	Callback = function(v)
		CFG.SelectedUpgrade = v
	end,
})
ShopTab:Button({
	Title = "Buy selected upgrade",
	Callback = function()
		fireEvent("Upgrades", "Buy", CFG.SelectedUpgrade)
		notify("Upgrades", "Buy " .. tostring(CFG.SelectedUpgrade))
	end,
})
ShopTab:Button({
	Title = "Buy all upgrades once",
	Callback = function()
		for _, name in ipairs(SCAN.upgrades) do
			fireEvent("Upgrades", "Buy", name)
		end
		notify("Upgrades", "Burst sent")
	end,
})
ShopTab:Dropdown({
	Title = "World",
	Values = SCAN.worlds,
	Value = CFG.SelectedWorld,
	Callback = function(v)
		CFG.SelectedWorld = v
	end,
})
ShopTab:Button({
	Title = "Teleport to world",
	Callback = function()
		fireEvent("Teleport", CFG.SelectedWorld)
		notify("Teleport", tostring(CFG.SelectedWorld))
	end,
})

---------------------------------------------------------------
local ClaimTab = Window:Tab({ Title = "Claims", Icon = "gift" })
ClaimTab:Paragraph({
	Title = "Server claim events",
	Desc = "Codes from CodesConfig. PlaytimeGift/NextDay/EarlyLeave/Group/Index fire the same Warp events the UI uses.",
})
ClaimTab:Button({
	Title = "Redeem all codes",
	Callback = function()
		task.spawn(function()
			local n = redeemAllCodes()
			notify("Codes", n .. " codes fired")
		end)
	end,
})
ClaimTab:Button({
	Title = "Claim gifts / daily / group / index",
	Callback = function()
		task.spawn(claimAll)
		notify("Claims", "fired")
	end,
})
ClaimTab:Button({
	Title = "Playtime gift",
	Callback = function()
		fireEvent("PlaytimeGift", "Claim")
	end,
})
ClaimTab:Button({
	Title = "Next day reward",
	Callback = function()
		fireEvent("NextDayReward")
	end,
})
ClaimTab:Button({
	Title = "Early leave reward",
	Callback = function()
		fireEvent("EarlyLeaveReward")
	end,
})

---------------------------------------------------------------
local ScanTab = Window:Tab({ Title = "Index Scanner", Icon = "search" })
ScanTab:Paragraph({
	Title = SCAN.status,
	Desc = "GetInstance from the game index. Backpack = Tool in Backpack + inventory slot (hold/see). Fake GUIDs are not saved by the server — sell/rejoin drops them. Owned rods still use real RodShop Equip.",
})
ScanTab:Button({
	Title = "Rescan indexes",
	Callback = function()
		scanIndexes()
		notify("Scan", SCAN.status)
	end,
})
ScanTab:Dropdown({
	Title = "Spawn kind",
	Values = { "Fish", "Rod", "Bait", "Obstacle" },
	Value = CFG.SpawnKind,
	Callback = function(v)
		CFG.SpawnKind = v
	end,
})
ScanTab:Dropdown({
	Title = "Fish",
	Values = SCAN.fish,
	Value = CFG.SelectedFish,
	Callback = function(v)
		CFG.SelectedFish = v
	end,
})
ScanTab:Button({
	Title = "Spawn into backpack",
	Callback = function()
		local name = selectedSpawnName()
		local ok, err = spawnIntoBackpack(CFG.SpawnKind, name, false)
		notify("Backpack", ok and (tostring(name) .. " in backpack") or tostring(err))
	end,
})
ScanTab:Button({
	Title = "Equip onto player",
	Callback = function()
		local name = selectedSpawnName()
		local ok, err = spawnIntoBackpack(CFG.SpawnKind, name, true)
		notify("Equip", ok and ("holding " .. tostring(name)) or tostring(err))
	end,
})
ScanTab:Button({
	Title = "Spawn preview in world",
	Callback = function()
		local name = selectedSpawnName()
		local ok, err = spawnPreview(CFG.SpawnKind, name)
		notify("World", ok and tostring(name) or tostring(err))
	end,
})
ScanTab:Dropdown({
	Title = "Warp event",
	Values = SCAN.events,
	Value = CFG.SelectedEvent,
	Callback = function(v)
		CFG.SelectedEvent = v
	end,
})
ScanTab:Button({
	Title = "Fire selected event (true)",
	Callback = function()
		fireEvent(CFG.SelectedEvent)
		notify("Event", tostring(CFG.SelectedEvent))
	end,
})
ScanTab:Button({
	Title = "Dump scan to console",
	Callback = function()
		print("[DeepFishingHub]", SCAN.status)
		print("fish", table.concat(SCAN.fish, ", "))
		print("rods", table.concat(SCAN.rods, ", "))
		print("baits", table.concat(SCAN.baits, ", "))
		print("events", table.concat(SCAN.events, ", "))
		print("codes", table.concat(SCAN.codes, ", "))
		print("obstacles", table.concat(SCAN.obstacles, ", "))
		print("prefabs", table.concat(SCAN.prefabs, ", "))
		notify("Scan", "printed")
	end,
})

---------------------------------------------------------------
local MoveTab = Window:Tab({ Title = "Client", Icon = "gauge" })
MoveTab:Paragraph({
	Title = "Client physics only",
	Desc = "WalkSpeed/Jump write Humanoid. Anti-AFK uses VirtualUser. These are real client properties, not spoofed leaderstats.",
})
MoveTab:Toggle({
	Title = "Keep WalkSpeed / Jump",
	Default = CFG.KeepSpeed,
	Callback = function(v)
		CFG.KeepSpeed = v
		applyMove()
	end,
})
MoveTab:Slider({
	Title = "WalkSpeed",
	Value = { Min = 16, Max = 120, Default = CFG.WalkSpeed },
	Callback = function(v)
		CFG.WalkSpeed = math.floor(v)
		applyMove()
	end,
})
MoveTab:Slider({
	Title = "JumpPower",
	Value = { Min = 20, Max = 180, Default = CFG.JumpPower },
	Callback = function(v)
		CFG.JumpPower = math.floor(v)
		applyMove()
	end,
})
MoveTab:Slider({
	Title = "FOV",
	Value = { Min = 40, Max = 120, Default = CFG.Fov },
	Callback = function(v)
		CFG.Fov = math.floor(v)
		pcall(function()
			workspace.CurrentCamera.FieldOfView = CFG.Fov
		end)
	end,
})
MoveTab:Toggle({
	Title = "Anti AFK",
	Default = CFG.AntiAfk,
	Callback = function(v)
		CFG.AntiAfk = v
	end,
})
MoveTab:Button({
	Title = "Reinstall hooks",
	Callback = function()
		pcall(installGameHooks)
		notify("Hooks", "reinstalled")
	end,
})

---------------------------------------------------------------
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })
local function statsText()
	local d = playerData()
	if not d then
		return "PlayerData not ready"
	end
	local cash = tonumber(d.Cash) or 0
	local lvl = tonumber(d.Level) or 1
	local xp = tonumber(d.XP) or 0
	return string.format("Lv %d  XP %d  Cash %d  Rod %s  World %s", lvl, xp, cash, tostring(d.RodEquipped), tostring(d.World))
end
InfoTab:Paragraph({
	Title = "Profile",
	Desc = statsText(),
})
InfoTab:Paragraph({
	Title = "Hooks",
	Desc = "hookfunction + newcclosure(name spoof) on AutoFishing.DriveCast/Toggle, CatchFight.Decay, CatchMinigame.Begin/Click, debug.info. Warp Fire(true, ...) for actions. FireServer namecall is logged into SCAN.remotes.",
})
InfoTab:Button({
	Title = "Refresh profile text",
	Callback = function()
		notify("Profile", statsText())
	end,
})

WindUI:Notify({
	Title = "Deep Fishing Hub",
	Content = SCAN.status .. " · RightShift",
	Duration = 4,
})

STATE.onCleanup(function()
	farmToken += 1
	CFG.AutoFarm = false
	CFG.InstantFarm = false
	pcall(disableAutoFishing)
	pcall(function()
		WindUI:Destroy()
	end)
end)

print("[DeepFishingHub] loaded", SCAN.status)

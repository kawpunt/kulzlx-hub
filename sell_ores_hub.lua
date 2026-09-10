--[[
  Sell Ores Hub - WindUI (local)
  live-reload label: sell_ores_hub

  Grant uses the game's AdminGlobalGrantRequest.
  Server rejects non-admins (client whitelist is 134852323 / 86778731).
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
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function remote(name)
	return Remotes:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)
end

local AdminGlobalGrantRequest = remote("AdminGlobalGrantRequest")
local BaseNavigationRequest = remote("BaseNavigationRequest")
local BaseCrateAction = remote("BaseCrateAction")
local PlaytimeRewardsGetState = remote("PlaytimeRewardsGetState")
local PlaytimeRewardsClaim = remote("PlaytimeRewardsClaim")
local ClaimDailyReward = remote("ClaimDailyReward")
local GroupRewardClaimRequest = remote("GroupRewardClaimRequest")
local RedeemCodeRequest = remote("RedeemCodeRequest")
local RequestLuckySpin = remote("RequestLuckySpin")
local CompleteLuckySpin = remote("CompleteLuckySpin")
local OfflineEarningsClaimRequest = remote("OfflineEarningsClaimRequest")
local AutoRollerRequest = remote("AutoRollerRequest")
local BaseBuildEquipOre = remote("BaseBuildEquipOre")
local BaseBuildPurchaseFloor = remote("BaseBuildPurchaseFloor")
local BaseBuildPurchaseTunnel = remote("BaseBuildPurchaseTunnel")
local BaseUpgradeDrillSpeed = remote("BaseUpgradeDrillSpeed")
local BaseUpgradeDrillYield = remote("BaseUpgradeDrillYield")
local BaseUpgradeOreRegenSpeed = remote("BaseUpgradeOreRegenSpeed")
local RollerUpgradeOreLuck = remote("RollerUpgradeOreLuck")
local RequestPetPickup = remote("RequestPetPickup")
local RequestPetPlacement = remote("RequestPetPlacement")
local RequestUnlockedPets = remote("RequestUnlockedPets")
local RequestGearPurchase = remote("RequestGearPurchase")
local UseGearOnTunnel = remote("UseGearOnTunnel")
local FuserAction = remote("FuserAction")
local ShowcasePedestalAction = remote("ShowcasePedestalAction")
local LuckyBlockOpenRequest = remote("LuckyBlockOpenRequest")
local LuckyBlockClaimReward = remote("LuckyBlockClaimReward")
local OrePackOpenRequest = remote("OrePackOpenRequest")
local OrePackClaimReward = remote("OrePackClaimReward")
local SettingsUpdateRequest = remote("SettingsUpdateRequest")
local TimeSkipQuoteRequest = remote("TimeSkipQuoteRequest")

local ADMIN_IDS = {
	[134852323] = true,
	[86778731] = true,
}

if not STATE.store then
	STATE.store = {
		esp = {},
	}
end
local store = STATE.store
store.esp = store.esp or {}

local CFG = store.cfg
	or {
		Silent = true,
		AutoDaily = false,
		AutoPlaytime = false,
		AutoOffline = false,
		InfJump = false,
		WalkSpeed = 16,
		SpeedOn = false,
		EspPlayers = false,
		Category = "Ore",
		RewardId = "Adminite Ore",
		TargetUserId = tostring(LocalPlayer.UserId),
		GiveToAll = false,
		MoneyDollars = "1000000",
		RedeemCode = "",
		InstantDrill = true,
		InstantMove = true,
		InstantRegen = true,
		InstantSell = true,
		InstantLuck = true,
		InstantYield = true,
		InstantGrowth = true,
		InstantRoller = true,
		DrillMult = 80,
		DroneMoveSpeed = 420,
		LuckLevel = 200,
		YieldLevel = 99,
		GrowthMult = 10,
		AutoCollect = false,
		AutoSell = false,
		AutoPickupOres = false,
		AutoEquipBest = false,
		ReplaceWeakerOres = false,
		EspTunnels = false,
		MuteVFX = false,
		HighPerf = false,
		UpgradeFloor = 1,
		GearId = "SmallGrowthGem",
		LuckyId = "CommonLuckyBlock",
		PackId = "OrePack",
	}
store.cfg = CFG
do
	local defaults = {
		InstantDrill = true,
		InstantMove = true,
		InstantRegen = true,
		InstantSell = true,
		InstantLuck = true,
		InstantYield = true,
		InstantGrowth = true,
		InstantRoller = true,
		DrillMult = 80,
		DroneMoveSpeed = 420,
		LuckLevel = 200,
		YieldLevel = 99,
		GrowthMult = 10,
		AutoCollect = false,
		AutoSell = false,
		AutoPickupOres = false,
		AutoEquipBest = false,
		ReplaceWeakerOres = false,
		EspTunnels = false,
		MuteVFX = false,
		HighPerf = false,
		UpgradeFloor = 1,
		GearId = "SmallGrowthGem",
		LuckyId = "CommonLuckyBlock",
		PackId = "OrePack",
	}
	for k, v in pairs(defaults) do
		if CFG[k] == nil then
			CFG[k] = v
		end
	end
end

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")

local function notify(title, dur)
	pcall(function()
		WindUI:Notify({
			Title = "Sell Ores Hub",
			Content = title,
			Duration = dur or 3,
		})
	end)
end

local function isAdmin()
	return ADMIN_IDS[LocalPlayer.UserId] == true
end

local function collectFromGc(found, wantType)
	local out = {}
	if type(found) == "function" and wantType == "function" then
		table.insert(out, found)
		return out
	end
	if type(found) ~= "table" then
		return out
	end
	if found[1] ~= nil then
		for _, value in ipairs(found) do
			if type(value) == wantType then
				table.insert(out, value)
			end
		end
		if #out > 0 then
			return out
		end
	end
	if wantType == "table" and (found.DrillSeconds ~= nil or found.MoveSpeedStudsPerSecond ~= nil) then
		table.insert(out, found)
	end
	return out
end

local function gcFunctions(name)
	local ok, found = pcall(function()
		return filtergc("function", { Name = name }, false)
	end)
	if not ok then
		return {}
	end
	return collectFromGc(found, "function")
end

local function gcTables(keys)
	local ok, found = pcall(function()
		return filtergc("table", { Keys = keys }, false)
	end)
	if not ok then
		return {}
	end
	return collectFromGc(found, "table")
end

local function restoreHooks()
	local list = store.hookRestore
	if type(list) ~= "table" then
		return
	end
	for i = #list, 1, -1 do
		local item = list[i]
		if item and type(item.fn) == "function" and type(item.orig) == "function" then
			pcall(hookfunction, item.fn, item.orig)
		end
	end
	store.hookRestore = nil
end

local function hookOnce(fn, replacement)
	if type(fn) ~= "function" then
		warn("[SellOres] hookOnce skip non-function", typeof(fn))
		return
	end
	if type(hookfunction) ~= "function" then
		warn("[SellOres] hookfunction missing")
		return
	end
	store.hookRestore = store.hookRestore or {}
	local orig
	local ok, err = pcall(function()
		orig = hookfunction(fn, function(...)
			return replacement(orig, ...)
		end)
	end)
	if not ok then
		warn("[SellOres] hookOnce failed: ", err)
		return
	end
	if type(orig) == "function" then
		table.insert(store.hookRestore, { fn = fn, orig = orig })
	else
		warn("[SellOres] hookOnce orig not function: ", typeof(orig))
	end
end

local function clearDrillCache(fn)
	if type(getupvalues) ~= "function" then
		return
	end
	local ok, ups = pcall(getupvalues, fn)
	if ok and type(ups) == "table" and type(ups[1]) == "table" then
		table.clear(ups[1])
	end
end

local function patchDroneTables()
	local tables = gcTables({ "DrillSeconds", "MoveSpeedStudsPerSecond" })
	for _, cfg in ipairs(tables) do
		if type(cfg) == "table" and not (table.isfrozen and table.isfrozen(cfg)) then
			pcall(function()
				cfg.DrillSeconds = CFG.InstantDrill and 0.05 or 1
				cfg.MoveSpeedStudsPerSecond = CFG.InstantMove and CFG.DroneMoveSpeed or 18
				if cfg.SellCratePlaceSeconds ~= nil then
					cfg.SellCratePlaceSeconds = CFG.InstantSell and 0.01 or 0.18
				end
				if cfg.SellCrateShrinkSeconds ~= nil then
					cfg.SellCrateShrinkSeconds = CFG.InstantSell and 0.01 or 0.08
				end
				if cfg.SellCratePauseSeconds ~= nil then
					cfg.SellCratePauseSeconds = CFG.InstantSell and 0 or 0.02
				end
			end)
		end
	end
	for _, fn in ipairs(gcFunctions("getDrillSpeedMultiplier")) do
		clearDrillCache(fn)
	end
end

local function installInstantHooks()
	restoreHooks()
	local drillFns = gcFunctions("getDrillSpeedMultiplier")
	local regenFns = gcFunctions("getOreRegenSpeedMultiplier")
	local spinFns = gcFunctions("GetSpinDuration")
	patchDroneTables()

	for _, fn in ipairs(drillFns) do
		clearDrillCache(fn)
		hookOnce(fn, function(_, floor)
			if CFG.InstantDrill then
				return CFG.DrillMult
			end
			local index = math.max(1, (math.floor(tonumber(floor) or 1)))
			local attr = LocalPlayer:GetAttribute(string.format("DrillSpeedLevel_Floor%d", index))
			if attr == nil then
				attr = LocalPlayer:GetAttribute("DrillSpeedLevel")
			end
			local level = math.clamp(math.floor(tonumber(attr) or 1), 1, 10)
			local pet = math.max(0, tonumber(LocalPlayer:GetAttribute(string.format("PetAbilityMiningSpeedBonus_Floor%d", index))) or 0)
			return (level - 1) * 0.15 + 1 + pet
		end)
	end

	for _, fn in ipairs(regenFns) do
		hookOnce(fn, function(_, floor)
			if CFG.InstantRegen then
				return 80
			end
			local index = math.max(1, (math.floor(tonumber(floor) or 1)))
			local attr = LocalPlayer:GetAttribute(string.format("OreRegenSpeedLevel_Floor%d", index))
			if attr == nil then
				attr = LocalPlayer:GetAttribute("OreRegenSpeedLevel")
			end
			return (math.max(1, (math.floor(tonumber(attr) or 1))) - 1) / 99 + 1
		end)
	end

	for _, fn in ipairs(spinFns) do
		hookOnce(fn, function(orig, level)
			if CFG.InstantRoller then
				return 0.05
			end
			if orig then
				local ok, value = pcall(orig, level)
				if ok then
					return value
				end
			end
			return 0.05
		end)
	end

	store.instantHookCounts = {
		drill = #drillFns,
		regen = #regenFns,
		spin = #spinFns,
	}
	print("[SellOres] instant hooks", #drillFns, #regenFns, #spinFns, "hookRestore", store.hookRestore and #store.hookRestore)
end

installInstantHooks()

local function ownedBase()
	local bases = Workspace:FindFirstChild("Bases")
	if not bases then
		return nil
	end
	for _, base in ipairs(bases:GetChildren()) do
		if base:GetAttribute("Owner") == LocalPlayer.UserId then
			return base
		end
	end
	return nil
end

local OreMetadata
local ToolMetadata
local oreRarity = {}
local rarityRank = {}

local Catalog = {
	Ore = {},
	Gear = {},
	Pack = {},
	Pet = {},
	LuckyBlock = {},
	Money = { "Money" },
}

do
	local okOre, meta = pcall(require, ReplicatedStorage:WaitForChild("OreMetadata"))
	if okOre then
		OreMetadata = meta
	end
	pcall(function()
		ToolMetadata = require(ReplicatedStorage:WaitForChild("ToolMetadata"))
	end)
	if OreMetadata and OreMetadata.Rarities and OreMetadata.GetOresByRarity then
		for index, rarity in ipairs(OreMetadata.Rarities) do
			rarityRank[rarity] = index
			local list = OreMetadata.GetOresByRarity(rarity)
			if type(list) == "table" then
				for _, ore in ipairs(list) do
					if type(ore) == "table" and type(ore.name) == "string" then
						table.insert(Catalog.Ore, ore.name)
						oreRarity[ore.name] = rarity
					end
				end
			end
		end
	end

	local okGear, GearMetadata = pcall(require, ReplicatedStorage:WaitForChild("GearMetadata"))
	if okGear and GearMetadata and GearMetadata.List then
		for _, gear in ipairs(GearMetadata.List()) do
			if type(gear) == "table" and type(gear.Id) == "string" then
				table.insert(Catalog.Gear, gear.Id)
			end
		end
	end

	local okPack, OrePackMetadata = pcall(require, ReplicatedStorage:WaitForChild("OrePackMetadata"))
	if okPack and OrePackMetadata and OrePackMetadata.GetPackTypes then
		for _, packId in ipairs(OrePackMetadata.GetPackTypes()) do
			table.insert(Catalog.Pack, packId)
		end
	end

	local okPet, PetMetadata = pcall(require, ReplicatedStorage:WaitForChild("PetMetadata"))
	if okPet and PetMetadata then
		if PetMetadata.ListPets then
			for _, pet in ipairs(PetMetadata.ListPets()) do
				if type(pet) == "table" and type(pet.Id) == "string" then
					table.insert(Catalog.Pet, pet.Id)
				end
			end
		end
		if PetMetadata.ListLuckyBlocks then
			for _, block in ipairs(PetMetadata.ListLuckyBlocks()) do
				if type(block) == "table" and type(block.Id) == "string" then
					table.insert(Catalog.LuckyBlock, block.Id)
				end
			end
		end
	end
end

local function catalogValues(category)
	local list = Catalog[category] or Catalog.Ore
	if #list == 0 then
		return { "(empty)" }
	end
	return list
end

local function parseUserId(text)
	if CFG.GiveToAll then
		return nil
	end
	local n = tonumber(text)
	if n and n > 0 then
		return math.floor(n)
	end
	return LocalPlayer.UserId
end

local function parseMoneyCents(text)
	local dollars = tonumber(text)
	if not dollars or dollars <= 0 then
		return nil
	end
	return math.floor(dollars) * 100
end

local function grant(category, rewardId, userId, amountCents)
	if not AdminGlobalGrantRequest or not AdminGlobalGrantRequest:IsA("RemoteFunction") then
		return false, "AdminGlobalGrantRequest missing"
	end
	local requestId = HttpService:GenerateGUID(false)
	local ok, res = pcall(function()
		return AdminGlobalGrantRequest:InvokeServer(category, rewardId, userId, requestId, amountCents)
	end)
	if not ok then
		return false, tostring(res)
	end
	if type(res) ~= "table" then
		return false, "server returned " .. typeof(res)
	end
	if res.success ~= true then
		return false, tostring(res.message or "rejected")
	end
	return true, tostring(res.message or "queued")
end

local function dumpResult(res)
	if type(res) ~= "table" then
		return tostring(res)
	end
	if res.success == true then
		return tostring(res.message or res.result or "ok")
	end
	return tostring(res.message or res.result or "rejected")
end

local function invokeDump(rf, ...)
	if not rf then
		return false, "missing remote"
	end
	local args = { ... }
	local ok, res = pcall(function()
		if rf:IsA("RemoteFunction") then
			return rf:InvokeServer(unpack(args))
		end
		rf:FireServer(unpack(args))
		return true
	end)
	if not ok then
		return false, tostring(res)
	end
	return true, dumpResult(res)
end

local function crateState()
	local b = ownedBase()
	if not b or not BaseCrateAction then
		return nil, b
	end
	local ok, res = pcall(function()
		return BaseCrateAction:InvokeServer(b.Name, "GetState")
	end)
	if ok and type(res) == "table" and res.success == true and type(res.result) == "table" then
		return res.result, b
	end
	return nil, b
end

local function collectDropRewardIds()
	local ids = {}
	local folder = Workspace:FindFirstChild("DroneOreDrops")
	if not folder then
		return ids
	end
	for _, drop in ipairs(folder:GetChildren()) do
		if drop:GetAttribute("Collected") ~= true then
			local id = drop:GetAttribute("RewardId")
			if type(id) == "string" and id ~= "" then
				table.insert(ids, id)
				if #ids >= 100 then
					break
				end
			end
		end
	end
	return ids
end

local function collectDroneOres()
	local b = ownedBase()
	if not b or not BaseCrateAction then
		return 0, "no base"
	end
	local ids = collectDropRewardIds()
	if #ids == 0 then
		return 0, "no pending drops"
	end
	local ok, res = pcall(function()
		return BaseCrateAction:InvokeServer(b.Name, "CollectDroneOres", ids)
	end)
	if not ok then
		return 0, tostring(res)
	end
	return #ids, dumpResult(res)
end

local function findPrompt(name, root)
	root = root or ownedBase()
	if not root then
		return nil
	end
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Name == name then
			return inst
		end
	end
	return nil
end

local function firePrompt(name)
	local prompt = findPrompt(name)
	if not prompt then
		return false, name .. " missing"
	end
	if type(fireproximityprompt) == "function" then
		local ok, err = pcall(fireproximityprompt, prompt)
		if ok then
			return true, name
		end
		return false, tostring(err)
	end
	pcall(function()
		prompt:InputHoldBegin()
	end)
	task.wait(tonumber(prompt.HoldDuration) or 0)
	pcall(function()
		prompt:InputHoldEnd()
	end)
	return true, name
end

local function tunnelAttr(floor, tunnelName, suffix)
	return string.format("Floor%d_Tunnel%s_%s", floor, tunnelName, suffix)
end

local function eachOwnedTunnel(fn)
	local b = ownedBase()
	if not b then
		return
	end
	local floors = b:FindFirstChild("Floors")
	if not floors then
		return
	end
	local maxFloor = math.max(1, math.floor(tonumber(LocalPlayer:GetAttribute("MaxFloorUnlocked")) or 1))
	for _, floorInst in ipairs(floors:GetChildren()) do
		local floor = tonumber(string.match(floorInst.Name, "^Floor(%d+)$"))
		if floor and floor <= maxFloor then
			for _, tun in ipairs(floorInst:GetChildren()) do
				if string.match(tun.Name, "^Tunnel%d+$") then
					fn(b, floor, tun)
				end
			end
		end
	end
end

local function oreScore(oreName)
	return rarityRank[oreRarity[oreName] or ""] or 0
end

local function eachOreTool(fn)
	local function scan(folder)
		if not folder then
			return
		end
		for _, tool in ipairs(folder:GetChildren()) do
			if tool:IsA("Tool") then
				local isOre = ToolMetadata and OreMetadata and ToolMetadata.IsOreTool(tool, OreMetadata)
				if isOre or tool:GetAttribute("ToolType") == "Ore" then
					fn(tool)
				end
			end
		end
	end
	scan(LocalPlayer.Backpack)
	scan(LocalPlayer.Character)
end

local function bestOreTool()
	local best, bestScore, bestLevel = nil, -1, -1
	eachOreTool(function(tool)
		local name = (ToolMetadata and OreMetadata and ToolMetadata.GetOreName(tool, OreMetadata)) or tool.Name
		local score = oreScore(name)
		local level = 1
		if ToolMetadata then
			level = tonumber(ToolMetadata.GetLevel(tool)) or 1
		end
		if score > bestScore or (score == bestScore and level > bestLevel) then
			best, bestScore, bestLevel = tool, score, level
		end
	end)
	return best, bestScore
end

local function equipBestOnTunnels()
	local tool, bestScore = bestOreTool()
	if not tool or not BaseBuildEquipOre then
		return 0, "no ore tool / remote"
	end
	local oreName = (ToolMetadata and OreMetadata and ToolMetadata.GetOreName(tool, OreMetadata)) or tool.Name
	local level = 1
	local toolId = nil
	if ToolMetadata then
		level = tonumber(ToolMetadata.GetLevel(tool)) or 1
		toolId = ToolMetadata.GetOreToolId(tool)
	end
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:EquipTool(tool)
		end)
		task.wait(0.05)
	end
	local n = 0
	eachOwnedTunnel(function(base, floor, tun)
		local unlocked = LocalPlayer:GetAttribute(tunnelAttr(floor, tun.Name, "Unlocked")) == true
		if not unlocked then
			return
		end
		local current = LocalPlayer:GetAttribute(tunnelAttr(floor, tun.Name, "OreType"))
		local empty = type(current) ~= "string" or current == ""
		local weaker = type(current) == "string" and current ~= "" and oreScore(current) < bestScore
		if empty or (CFG.ReplaceWeakerOres and weaker) then
			local ok = pcall(function()
				BaseBuildEquipOre:InvokeServer(base.Name, floor, tun.Name, oreName, level, toolId)
			end)
			if ok then
				n += 1
			end
		end
	end)
	return n, oreName
end

local function upgradeOnce(rf, floor)
	local b = ownedBase()
	if not b or not rf then
		return false, "missing"
	end
	return invokeDump(rf, b.Name, floor)
end

local function maxUnlockedFloor()
	return math.max(1, math.floor(tonumber(LocalPlayer:GetAttribute("MaxFloorUnlocked")) or 1))
end

local function homeStatusText()
	local b = ownedBase()
	local counts = store.instantHookCounts or {}
	local st = select(1, crateState())
	return string.format(
		"%s · uid %d · base %s · admin %s\nmoney %s · luck %s · floor %s · crates %s stored %s\ninstant hooks drill=%s regen=%s spin=%s\nSilent boot · click the open button to show the menu",
		LocalPlayer.Name,
		LocalPlayer.UserId,
		b and b.Name or "none",
		isAdmin() and "YES" or "NO (grant will be rejected)",
		tostring(LocalPlayer:GetAttribute("Money")),
		tostring(LocalPlayer:GetAttribute("RollingLuck")),
		tostring(LocalPlayer:GetAttribute("MaxFloorUnlocked")),
		st and tostring(st.CrateCount) or "?",
		st and tostring(st.StoredMoney) or "?",
		tostring(counts.drill),
		tostring(counts.regen),
		tostring(counts.spin)
	)
end

local function applyWalkSpeed()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and CFG.SpeedOn then
		hum.WalkSpeed = CFG.WalkSpeed
	end
end

local function clearEsp()
	for _, obj in pairs(store.esp) do
		pcall(function()
			if obj.Remove then
				obj:Remove()
			end
		end)
	end
	table.clear(store.esp)
end

local function espKey(player, kind)
	return tostring(player.UserId) .. "_" .. kind
end

local function refreshEsp()
	if not CFG.EspPlayers and not CFG.EspTunnels then
		clearEsp()
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local seen = {}
	if CFG.EspPlayers then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hrp then
					local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
					local dist = 0
					local myChar = LocalPlayer.Character
					local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
					if myHrp then
						dist = (myHrp.Position - hrp.Position).Magnitude
					end
					local textKey = espKey(player, "text")
					local boxKey = espKey(player, "box")
					seen[textKey] = true
					seen[boxKey] = true
					local text = store.esp[textKey]
					if not text then
						text = Drawing.new("Text")
						text.Size = 16
						text.Center = true
						text.Outline = true
						text.Color = Color3.fromRGB(255, 255, 255)
						store.esp[textKey] = text
					end
					local box = store.esp[boxKey]
					if not box then
						box = Drawing.new("Square")
						box.Thickness = 1
						box.Filled = false
						box.Color = Color3.fromRGB(80, 220, 120)
						store.esp[boxKey] = box
					end
					local hp = hum and math.floor(hum.Health + 0.5) or 0
					text.Text = string.format("%s  [%dm]  %dhp", player.DisplayName, math.floor(dist + 0.5), hp)
					text.Position = Vector2.new(pos.X, pos.Y - 28)
					text.Visible = onScreen
					local size = 28 * (1 / math.max(pos.Z, 1)) * 60
					size = math.clamp(size, 8, 48)
					box.Size = Vector2.new(size, size * 1.6)
					box.Position = Vector2.new(pos.X - size / 2, pos.Y - size * 0.3)
					box.Visible = onScreen
				end
			end
		end
	end
	if CFG.EspTunnels then
		eachOwnedTunnel(function(_, floor, tun)
			local part = tun.PrimaryPart or tun:FindFirstChildWhichIsA("BasePart", true)
			if not part then
				return
			end
			local ore = LocalPlayer:GetAttribute(tunnelAttr(floor, tun.Name, "OreType"))
			local mut = LocalPlayer:GetAttribute(tunnelAttr(floor, tun.Name, "OreMutation"))
			local unlocked = LocalPlayer:GetAttribute(tunnelAttr(floor, tun.Name, "Unlocked")) == true
			local growth = LocalPlayer:GetAttribute(tunnelAttr(floor, tun.Name, "GrowthMultiplier"))
			local label = string.format(
				"F%d %s\n%s%s%s",
				floor,
				tun.Name,
				unlocked and "" or "[locked] ",
				type(ore) == "string" and ore ~= "" and ore or "empty",
				type(mut) == "string" and mut ~= "" and (" " .. mut) or ""
			)
			if tonumber(growth) and tonumber(growth) > 1 then
				label = label .. string.format(" x%s", tostring(growth))
			end
			local pos, onScreen = cam:WorldToViewportPoint(part.Position)
			local key = string.format("tun_%d_%s", floor, tun.Name)
			seen[key] = true
			local text = store.esp[key]
			if not text then
				text = Drawing.new("Text")
				text.Size = 14
				text.Center = true
				text.Outline = true
				store.esp[key] = text
			end
			local score = type(ore) == "string" and oreScore(ore) or 0
			text.Color = score >= 8 and Color3.fromRGB(255, 80, 220)
				or score >= 5 and Color3.fromRGB(255, 200, 60)
				or unlocked and Color3.fromRGB(140, 220, 255)
				or Color3.fromRGB(160, 160, 160)
			text.Text = label
			text.Position = Vector2.new(pos.X, pos.Y)
			text.Visible = onScreen
		end)
	end
	for key, obj in pairs(store.esp) do
		if not seen[key] then
			pcall(function()
				obj:Remove()
			end)
			store.esp[key] = nil
		end
	end
end

STATE.connect(RunService.RenderStepped, function()
	if not STATE.alive() then
		return
	end
	if CFG.SpeedOn then
		applyWalkSpeed()
	end
	if CFG.EspPlayers or CFG.EspTunnels then
		refreshEsp()
	end
end)

STATE.connect(UserInputService.JumpRequest, function()
	if not STATE.alive() or not CFG.InfJump then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

STATE.connect(LocalPlayer.CharacterAdded, function()
	task.defer(applyWalkSpeed)
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoDaily and ClaimDailyReward then
			pcall(function()
				ClaimDailyReward:FireServer()
			end)
		end
		if CFG.AutoPlaytime and PlaytimeRewardsGetState and PlaytimeRewardsClaim then
			local ok, st = pcall(function()
				return PlaytimeRewardsGetState:InvokeServer()
			end)
			if ok and type(st) == "table" and type(st.rewards) == "table" then
				local elapsed = tonumber(st.elapsed) or 0
				for index, reward in pairs(st.rewards) do
					if type(reward) == "table" and reward.claimed ~= true then
						local unlockAt = tonumber(reward.unlockAt) or math.huge
						if elapsed >= unlockAt then
							pcall(function()
								PlaytimeRewardsClaim:FireServer(index)
							end)
						end
					end
				end
			end
		end
		if CFG.AutoOffline and OfflineEarningsClaimRequest then
			pcall(function()
				if OfflineEarningsClaimRequest:IsA("RemoteFunction") then
					OfflineEarningsClaimRequest:InvokeServer()
				else
					OfflineEarningsClaimRequest:FireServer()
				end
			end)
		end
		task.wait(2)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoCollect then
			collectDroneOres()
		end
		if CFG.AutoPickupOres then
			firePrompt("PickUpOresPrompt")
		end
		if CFG.AutoSell then
			firePrompt("SellOresPrompt")
		end
		if CFG.AutoEquipBest then
			equipBestOnTunnels()
		end
		task.wait(0.45)
	end
end)

STATE.onCleanup(function()
	clearEsp()
	CFG.InfJump = false
	CFG.SpeedOn = false
	restoreHooks()
	local keepDrill, keepMove, keepSell = CFG.InstantDrill, CFG.InstantMove, CFG.InstantSell
	CFG.InstantDrill = false
	CFG.InstantMove = false
	CFG.InstantSell = false
	pcall(patchDroneTables)
	CFG.InstantDrill = keepDrill
	CFG.InstantMove = keepMove
	CFG.InstantSell = keepSell
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "Sell Ores Hub",
	Author = "local WindUI",
	Folder = "SellOresHub",
	Icon = "pickaxe",
	NewElements = true,
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = false,
	OpenButton = {
		Title = "Sell Ores",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		OnlyIcon = true,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#F5C542"), Color3.fromHex("#2fe7ff")),
	},
})
store.window = Window

task.defer(function()
	pcall(function()
		Window:Close()
	end)
end)

Window:Tag({
	Title = "v2",
	Icon = "gem",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

local MainSec = Window:Section({ Title = "Main", Opened = true })
local SysSec = Window:Section({ Title = "Systems", Opened = true })

do
	local Tab = MainSec:Tab({ Title = "Home", Icon = "house", IconColor = Green })
	local homePara = Tab:Paragraph({
		Title = "Sell Ores Hub",
		Desc = homeStatusText(),
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
		Title = "Copy UserId",
		Icon = "clipboard",
		Callback = function()
			pcall(setclipboard, tostring(LocalPlayer.UserId))
			notify("copied " .. LocalPlayer.UserId)
		end,
	})
	Tab:Button({
		Title = "Refresh Status",
		Callback = function()
			local text = homeStatusText()
			if homePara and homePara.SetDesc then
				pcall(function()
					homePara:SetDesc(text)
				end)
			end
			notify(text, 5)
		end,
	})
	Tab:Button({
		Title = "Crate / Furnace State",
		Callback = function()
			local r, b = crateState()
			if not r then
				notify(b and "GetState failed" or "no base / no BaseCrateAction")
				return
			end
			notify(string.format(
				"%s crates=%s carried=%s money=%s furnace=%s",
				tostring(r.BaseName),
				tostring(r.CrateCount),
				tostring(r.CarriedCrateCount),
				tostring(r.StoredMoney),
				tostring(r.Furnace and r.Furnace.Purchased)
			), 5)
		end,
	})
	Tab:Button({
		Title = "Reapply Instant Hooks",
		Callback = function()
			installInstantHooks()
			local counts = store.instantHookCounts or {}
			notify(string.format("hooks drill=%s regen=%s spin=%s", tostring(counts.drill), tostring(counts.regen), tostring(counts.spin)))
		end,
	})
end

do
	local Tab = MainSec:Tab({ Title = "Spawn", Icon = "gift", IconColor = Yellow })
	local itemDrop

	Tab:Paragraph({
		Title = "AdminGlobalGrantRequest",
		Desc = "InvokeServer(category, rewardId, userId|nil, guid, amountCents|nil)\nNot admin = server reject. Give To All sends userId nil.",
	})

	Tab:Dropdown({
		Title = "Category",
		Values = { "Ore", "Gear", "Pack", "Pet", "LuckyBlock", "Money" },
		Value = CFG.Category,
		Callback = function(v)
			CFG.Category = v
			local values = catalogValues(v)
			CFG.RewardId = values[1]
			if itemDrop and itemDrop.Refresh then
				itemDrop:Refresh(values)
			end
			if itemDrop and itemDrop.Select then
				pcall(function()
					itemDrop:Select(values[1])
				end)
			end
		end,
	})

	itemDrop = Tab:Dropdown({
		Title = "Item",
		Values = catalogValues(CFG.Category),
		Value = CFG.RewardId,
		SearchBarEnabled = true,
		Callback = function(v)
			if v and v ~= "(empty)" then
				CFG.RewardId = v
			end
		end,
	})

	Tab:Input({
		Title = "Target UserId",
		Value = CFG.TargetUserId,
		Placeholder = tostring(LocalPlayer.UserId),
		Callback = function(v)
			CFG.TargetUserId = v
		end,
	})

	Tab:Input({
		Title = "Money (whole dollars)",
		Desc = "Only used when Category = Money. Sent as cents.",
		Value = CFG.MoneyDollars,
		Placeholder = "1000000",
		Callback = function(v)
			CFG.MoneyDollars = v
		end,
	})

	Tab:Toggle({
		Title = "Give To All",
		Desc = "userId = nil (server-wide grant)",
		Default = CFG.GiveToAll,
		Callback = function(v)
			CFG.GiveToAll = v
		end,
	})

	Tab:Button({
		Title = "Grant Selected",
		Icon = "send",
		Callback = function()
			local cents = nil
			if CFG.Category == "Money" then
				cents = parseMoneyCents(CFG.MoneyDollars)
				if not cents then
					notify("enter a positive whole-dollar amount")
					return
				end
			end
			local ok, msg = grant(CFG.Category, CFG.RewardId, parseUserId(CFG.TargetUserId), cents)
			notify((ok and "ok: " or "fail: ") .. msg, 5)
		end,
	})

	local function quick(category, rewardId, title)
		Tab:Button({
			Title = title,
			Callback = function()
				local ok, msg = grant(category, rewardId, parseUserId(CFG.TargetUserId), nil)
				notify((ok and "ok: " or "fail: ") .. msg, 5)
			end,
		})
	end

	quick("Ore", "Adminite Ore", "Grant Adminite Ore")
	quick("Ore", "Primordial Ore", "Grant Primordial Ore")
	quick("Pet", "Dragon", "Grant Dragon")
	quick("LuckyBlock", "TranscendedLuckyBlock", "Grant Transcended Lucky Block")
end

do
	local Tab = SysSec:Tab({ Title = "Claims", Icon = "circle-dollar-sign", IconColor = Green })

	Tab:Toggle({
		Title = "Auto Daily Claim",
		Default = CFG.AutoDaily,
		Callback = function(v)
			CFG.AutoDaily = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Playtime Claim",
		Desc = "Claims unlocked playtime slots every 2s",
		Default = CFG.AutoPlaytime,
		Callback = function(v)
			CFG.AutoPlaytime = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Offline Earnings",
		Default = CFG.AutoOffline,
		Callback = function(v)
			CFG.AutoOffline = v
		end,
	})

	Tab:Button({
		Title = "Claim Daily Now",
		Callback = function()
			if not ClaimDailyReward then
				notify("ClaimDailyReward missing")
				return
			end
			pcall(function()
				ClaimDailyReward:FireServer()
			end)
			notify("daily claim fired")
		end,
	})

	Tab:Button({
		Title = "Claim Ready Playtime",
		Callback = function()
			if not PlaytimeRewardsGetState then
				notify("playtime remotes missing")
				return
			end
			local ok, st = pcall(function()
				return PlaytimeRewardsGetState:InvokeServer()
			end)
			if not ok or type(st) ~= "table" then
				notify("playtime state failed")
				return
			end
			local n = 0
			local elapsed = tonumber(st.elapsed) or 0
			for index, reward in pairs(st.rewards or {}) do
				if type(reward) == "table" and reward.claimed ~= true then
					local unlockAt = tonumber(reward.unlockAt) or math.huge
					if elapsed >= unlockAt then
						pcall(function()
							PlaytimeRewardsClaim:FireServer(index)
						end)
						n += 1
					end
				end
			end
			notify("claimed " .. n .. " playtime slot(s) · elapsed " .. math.floor(elapsed))
		end,
	})

	Tab:Button({
		Title = "Claim Group Reward",
		Callback = function()
			if not GroupRewardClaimRequest then
				notify("GroupRewardClaimRequest missing")
				return
			end
			local ok, res = pcall(function()
				return GroupRewardClaimRequest:InvokeServer()
			end)
			notify(ok and ("group: " .. tostring(res)) or ("group fail: " .. tostring(res)))
		end,
	})

	Tab:Button({
		Title = "Claim Offline Earnings",
		Callback = function()
			if not OfflineEarningsClaimRequest then
				notify("offline remote missing")
				return
			end
			local ok, res = pcall(function()
				if OfflineEarningsClaimRequest:IsA("RemoteFunction") then
					return OfflineEarningsClaimRequest:InvokeServer()
				end
				OfflineEarningsClaimRequest:FireServer()
				return true
			end)
			notify(ok and ("offline: " .. tostring(res)) or ("offline fail: " .. tostring(res)))
		end,
	})

	Tab:Button({
		Title = "Lucky Spin",
		Desc = "RequestLuckySpin then CompleteLuckySpin(spinId)",
		Callback = function()
			if not RequestLuckySpin then
				notify("RequestLuckySpin missing")
				return
			end
			local ok, res = pcall(function()
				return RequestLuckySpin:InvokeServer()
			end)
			if not ok then
				notify("spin fail: " .. tostring(res))
				return
			end
			local spinId = type(res) == "table" and (res.spinId or res.id or (res.result and res.result.spinId))
			if CompleteLuckySpin and spinId then
				local ok2, res2 = pcall(function()
					return CompleteLuckySpin:InvokeServer(spinId)
				end)
				notify(ok2 and ("complete: " .. tostring(res2 and res2.reward or res2)) or ("complete fail: " .. tostring(res2)))
				return
			end
			notify("spin response: " .. tostring(res))
		end,
	})

	Tab:Input({
		Title = "Redeem Code",
		Value = CFG.RedeemCode,
		Placeholder = "CODE",
		Callback = function(v)
			CFG.RedeemCode = v
		end,
	})
	Tab:Button({
		Title = "Redeem",
		Callback = function()
			if not RedeemCodeRequest then
				notify("RedeemCodeRequest missing")
				return
			end
			local code = CFG.RedeemCode
			if type(code) ~= "string" or code == "" then
				notify("enter a code")
				return
			end
			local ok, res = pcall(function()
				return RedeemCodeRequest:InvokeServer(code)
			end)
			if not ok then
				notify("redeem fail: " .. tostring(res))
				return
			end
			if type(res) == "table" then
				notify(tostring(res.message or res.success or res))
			else
				notify(tostring(res))
			end
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Travel", Icon = "map-pin", IconColor = Blue })

	local function nav(dest)
		if not BaseNavigationRequest then
			notify("BaseNavigationRequest missing")
			return
		end
		pcall(function()
			BaseNavigationRequest:FireServer(dest)
		end)
		notify("nav " .. dest)
	end

	Tab:Button({
		Title = "Go Base",
		Callback = function()
			nav("Base")
		end,
	})
	Tab:Button({
		Title = "Go Gear Shop",
		Callback = function()
			nav("GearShop")
		end,
	})
	Tab:Button({
		Title = "Floor Up",
		Callback = function()
			nav("Up")
		end,
	})
	Tab:Button({
		Title = "Floor Down",
		Callback = function()
			nav("Down")
		end,
	})
	Tab:Button({
		Title = "TP Onto Base",
		Callback = function()
			local b = ownedBase()
			if not b then
				notify("no owned base")
				return
			end
			local part = b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart", true)
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if part and hrp then
				hrp.CFrame = part.CFrame + Vector3.new(0, 8, 0)
				notify("warped to " .. b.Name)
			end
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Instant", Icon = "zap", IconColor = Yellow })

	Tab:Paragraph({
		Title = "Client instant",
		Desc = "Drill/move/regen/sell hook DroneClient copies. Luck/yield toggles only affect local multiplier hooks, not server rolls.",
	})

	local function refreshInstant()
		patchDroneTables()
		local counts = store.instantHookCounts or {}
		notify(string.format(
			"instant applied · drillHooks=%s regenHooks=%s spinHooks=%s",
			tostring(counts.drill),
			tostring(counts.regen),
			tostring(counts.spin)
		))
	end

	Tab:Toggle({
		Title = "Instant Drill",
		Desc = "DrillSeconds 0.05 + speed multiplier",
		Default = CFG.InstantDrill,
		Callback = function(v)
			CFG.InstantDrill = v
			patchDroneTables()
		end,
	})
	Tab:Slider({
		Title = "Drill Multiplier",
		Step = 1,
		Value = { Min = 5, Max = 200, Default = CFG.DrillMult },
		Callback = function(v)
			CFG.DrillMult = v
			patchDroneTables()
		end,
	})
	Tab:Toggle({
		Title = "Instant Move",
		Desc = "Drone MoveSpeedStudsPerSecond",
		Default = CFG.InstantMove,
		Callback = function(v)
			CFG.InstantMove = v
			patchDroneTables()
		end,
	})
	Tab:Slider({
		Title = "Drone Move Speed",
		Step = 10,
		Value = { Min = 18, Max = 800, Default = CFG.DroneMoveSpeed },
		Callback = function(v)
			CFG.DroneMoveSpeed = v
			if CFG.InstantMove then
				patchDroneTables()
			end
		end,
	})
	Tab:Toggle({
		Title = "Instant Regen",
		Desc = "getOreRegenSpeedMultiplier -> 80x",
		Default = CFG.InstantRegen,
		Callback = function(v)
			CFG.InstantRegen = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Sell Anim",
		Desc = "Skip crate sell tween on the drone table",
		Default = CFG.InstantSell,
		Callback = function(v)
			CFG.InstantSell = v
			patchDroneTables()
		end,
	})
	Tab:Toggle({
		Title = "Instant Luck",
		Desc = "RollingLuck is server-owned. This toggle is a no-op leftover from the removed GetAttribute hook.",
		Default = CFG.InstantLuck,
		Callback = function(v)
			CFG.InstantLuck = v
		end,
	})
	Tab:Slider({
		Title = "Luck Level",
		Step = 1,
		Value = { Min = 1, Max = 200, Default = CFG.LuckLevel },
		Callback = function(v)
			CFG.LuckLevel = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Yield",
		Desc = "Local only. Server still owns yield.",
		Default = CFG.InstantYield,
		Callback = function(v)
			CFG.InstantYield = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Growth",
		Desc = "Local only. Server still owns growth.",
		Default = CFG.InstantGrowth,
		Callback = function(v)
			CFG.InstantGrowth = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Auto Roller Spin",
		Desc = "GetSpinDuration -> 0.05s (needs purchased roller)",
		Default = CFG.InstantRoller,
		Callback = function(v)
			CFG.InstantRoller = v
		end,
	})
	Tab:Button({
		Title = "Reapply Instant",
		Callback = refreshInstant,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Player", Icon = "person-standing", IconColor = Yellow })

	Tab:Toggle({
		Title = "WalkSpeed On",
		Default = CFG.SpeedOn,
		Callback = function(v)
			CFG.SpeedOn = v
			if v then
				applyWalkSpeed()
			else
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = 16
				end
			end
		end,
	})
	Tab:Slider({
		Title = "WalkSpeed",
		Step = 1,
		Value = { Min = 16, Max = 200, Default = CFG.WalkSpeed },
		Callback = function(v)
			CFG.WalkSpeed = v
			if CFG.SpeedOn then
				applyWalkSpeed()
			end
		end,
	})
	Tab:Toggle({
		Title = "Infinite Jump",
		Default = CFG.InfJump,
		Callback = function(v)
			CFG.InfJump = v
		end,
	})
	Tab:Button({
		Title = "Auto Roller State",
		Callback = function()
			if not AutoRollerRequest then
				notify("AutoRollerRequest missing")
				return
			end
			local ok, res = pcall(function()
				return AutoRollerRequest:InvokeServer("GetState")
			end)
			if not ok or type(res) ~= "table" then
				notify("autoroller fail")
				return
			end
			local st = res.state or res
			notify(string.format(
				"purchased=%s rolling=%s floor=%s",
				tostring(st.purchased),
				tostring(st.isRolling),
				tostring(st.requiredFloor)
			))
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Farm", Icon = "pickaxe", IconColor = Green })
	Tab:Paragraph({
		Title = "Owned-base farm",
		Desc = "Collect uses real DroneOreDrops RewardIds (max 100). Sell fires SellerTable SellOresPrompt. Equip uses backpack ore tools.",
	})
	Tab:Toggle({
		Title = "Auto Collect Drops",
		Desc = "BaseCrateAction CollectDroneOres with live RewardIds",
		Default = CFG.AutoCollect,
		Callback = function(v)
			CFG.AutoCollect = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Pickup Ores Prompt",
		Desc = "CrateMaker PickUpOresPrompt",
		Default = CFG.AutoPickupOres,
		Callback = function(v)
			CFG.AutoPickupOres = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Sell Prompt",
		Desc = "SellerTable SellOresPrompt",
		Default = CFG.AutoSell,
		Callback = function(v)
			CFG.AutoSell = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Equip Best Ore",
		Desc = "Empty unlocked tunnels on owned floors",
		Default = CFG.AutoEquipBest,
		Callback = function(v)
			CFG.AutoEquipBest = v
		end,
	})
	Tab:Toggle({
		Title = "Replace Weaker Ores",
		Desc = "Also overwrite lower-rarity equipped tunnels",
		Default = CFG.ReplaceWeakerOres,
		Callback = function(v)
			CFG.ReplaceWeakerOres = v
		end,
	})
	Tab:Button({
		Title = "Collect Once",
		Callback = function()
			local n, msg = collectDroneOres()
			notify(string.format("collect %s · %s", tostring(n), tostring(msg)))
		end,
	})
	Tab:Button({
		Title = "Sell Once",
		Callback = function()
			local ok, msg = firePrompt("SellOresPrompt")
			notify((ok and "ok: " or "fail: ") .. tostring(msg))
		end,
	})
	Tab:Button({
		Title = "Pickup Ores Once",
		Callback = function()
			local ok, msg = firePrompt("PickUpOresPrompt")
			notify((ok and "ok: " or "fail: ") .. tostring(msg))
		end,
	})
	Tab:Button({
		Title = "Equip Best Now",
		Callback = function()
			local n, name = equipBestOnTunnels()
			notify(string.format("equipped %s on %s tunnels", tostring(name), tostring(n)))
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Upgrades", Icon = "arrow-up", IconColor = Yellow })
	Tab:Slider({
		Title = "Floor",
		Step = 1,
		Value = { Min = 1, Max = 15, Default = CFG.UpgradeFloor },
		Callback = function(v)
			CFG.UpgradeFloor = v
		end,
	})
	Tab:Button({
		Title = "Upgrade Drill Speed (floor)",
		Desc = "10000 * 5^(floor-1) * 20^(level-1), cap 10",
		Callback = function()
			local ok, msg = upgradeOnce(BaseUpgradeDrillSpeed, CFG.UpgradeFloor)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Button({
		Title = "Upgrade Drill Yield (floor)",
		Callback = function()
			local ok, msg = upgradeOnce(BaseUpgradeDrillYield, CFG.UpgradeFloor)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Button({
		Title = "Upgrade Ore Regen (floor)",
		Callback = function()
			local ok, msg = upgradeOnce(BaseUpgradeOreRegenSpeed, CFG.UpgradeFloor)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Button({
		Title = "Upgrade Ore Luck",
		Callback = function()
			local b = ownedBase()
			if not b then
				notify("no base")
				return
			end
			local ok, msg = invokeDump(RollerUpgradeOreLuck, b.Name)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Button({
		Title = "Spam Speed/Yield/Regen x5 (floor)",
		Callback = function()
			for _ = 1, 5 do
				upgradeOnce(BaseUpgradeDrillSpeed, CFG.UpgradeFloor)
				upgradeOnce(BaseUpgradeDrillYield, CFG.UpgradeFloor)
				upgradeOnce(BaseUpgradeOreRegenSpeed, CFG.UpgradeFloor)
			end
			notify(string.format(
				"done · speed=%s yield=%s regen=%s",
				tostring(LocalPlayer:GetAttribute(string.format("DrillSpeedLevel_Floor%d", CFG.UpgradeFloor))),
				tostring(LocalPlayer:GetAttribute(string.format("DrillYieldLevel_Floor%d", CFG.UpgradeFloor))),
				tostring(LocalPlayer:GetAttribute(string.format("OreRegenSpeedLevel_Floor%d", CFG.UpgradeFloor)))
			), 5)
		end,
	})
	Tab:Button({
		Title = "Upgrade All Unlocked Floors x1",
		Callback = function()
			for floor = 1, maxUnlockedFloor() do
				upgradeOnce(BaseUpgradeDrillSpeed, floor)
				upgradeOnce(BaseUpgradeDrillYield, floor)
				upgradeOnce(BaseUpgradeOreRegenSpeed, floor)
			end
			notify("upgraded floors 1-" .. maxUnlockedFloor())
		end,
	})
	Tab:Button({
		Title = "Upgrade Furnace",
		Callback = function()
			local b = ownedBase()
			if not b then
				notify("no base")
				return
			end
			local ok, msg = invokeDump(BaseCrateAction, b.Name, "UpgradeFurnace")
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Shop", Icon = "shopping-bag", IconColor = Blue })
	Tab:Button({
		Title = "Buy Next Floor",
		Callback = function()
			local b = ownedBase()
			if not b or not BaseBuildPurchaseFloor then
				notify("missing")
				return
			end
			local nxt = maxUnlockedFloor() + 1
			local okPrice, price = pcall(function()
				return BaseBuildPurchaseFloor:InvokeServer("GetFloorPrice", nxt)
			end)
			local ok, msg = invokeDump(BaseBuildPurchaseFloor, b.Name, nxt)
			notify(string.format("floor %s price=%s · %s", tostring(nxt), tostring(okPrice and price), msg))
		end,
	})
	Tab:Button({
		Title = "Buy Locked Tunnels (max floor)",
		Callback = function()
			local b = ownedBase()
			if not b or not BaseBuildPurchaseTunnel then
				notify("missing")
				return
			end
			local floor = maxUnlockedFloor()
			local n = 0
			eachOwnedTunnel(function(base, f, tun)
				if f ~= floor then
					return
				end
				if LocalPlayer:GetAttribute(tunnelAttr(f, tun.Name, "Unlocked")) == true then
					return
				end
				local ok = pcall(function()
					BaseBuildPurchaseTunnel:InvokeServer(base.Name, f, tun.Name)
				end)
				if ok then
					n += 1
				end
			end)
			notify("purchase attempts " .. n .. " on floor " .. floor)
		end,
	})
	Tab:Button({
		Title = "Buy Furnace Prompt",
		Callback = function()
			local ok, msg = firePrompt("PurchaseFurnacePrompt")
			notify((ok and "ok: " or "fail: ") .. tostring(msg))
		end,
	})
	Tab:Button({
		Title = "Buy Fuser Prompt",
		Callback = function()
			local ok, msg = firePrompt("PurchaseFuserPrompt")
			notify((ok and "ok: " or "fail: ") .. tostring(msg))
		end,
	})
	Tab:Button({
		Title = "Start Fusion",
		Callback = function()
			local b = ownedBase()
			if not b then
				notify("no base")
				return
			end
			local ok, msg = invokeDump(FuserAction, b.Name, "StartFusion")
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Dropdown({
		Title = "Gear",
		Values = catalogValues("Gear"),
		Value = CFG.GearId,
		SearchBarEnabled = true,
		Callback = function(v)
			if v and v ~= "(empty)" then
				CFG.GearId = v
			end
		end,
	})
	Tab:Button({
		Title = "Buy Gear x1",
		Callback = function()
			local ok, msg = invokeDump(RequestGearPurchase, CFG.GearId)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Button({
		Title = "Buy Gear x10",
		Callback = function()
			local ok, msg = invokeDump(RequestGearPurchase, CFG.GearId, 10)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
	Tab:Button({
		Title = "Showcase Purchase 1+2",
		Callback = function()
			local b = ownedBase()
			local name = b and b.Name
			local ok1, msg1 = invokeDump(ShowcasePedestalAction, "Purchase", 1, name)
			local ok2, msg2 = invokeDump(ShowcasePedestalAction, "Purchase", 2, name)
			notify(string.format("1 %s · 2 %s", msg1, msg2))
		end,
	})
	Tab:Button({
		Title = "Showcase Activate Boost 1+2",
		Callback = function()
			local b = ownedBase()
			local name = b and b.Name
			invokeDump(ShowcasePedestalAction, "ActivateBoost", 1, name)
			invokeDump(ShowcasePedestalAction, "ActivateBoost", 2, name)
			notify("boost fired")
		end,
	})
	Tab:Paragraph({
		Title = "Time skip",
		Desc = "TimeSkipQuoteRequest is a Robux product quote, not a free skip.",
	})
	Tab:Button({
		Title = "Quote Time Skip",
		Callback = function()
			local ok, msg = invokeDump(TimeSkipQuoteRequest)
			notify((ok and "ok: " or "fail: ") .. msg)
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Misc", Icon = "boxes", IconColor = Yellow })
	Tab:Toggle({
		Title = "Mute VFX",
		Default = CFG.MuteVFX,
		Callback = function(v)
			CFG.MuteVFX = v
			local ok, msg = invokeDump(SettingsUpdateRequest, "VFXEnabled", not v)
			if not CFG.Silent then
				notify((ok and "ok: " or "fail: ") .. msg)
			end
		end,
	})
	Tab:Toggle({
		Title = "High Performance Mode",
		Default = CFG.HighPerf,
		Callback = function(v)
			CFG.HighPerf = v
			invokeDump(SettingsUpdateRequest, "HighPerformanceModeEnabled", v)
		end,
	})
	Tab:Button({
		Title = "Pickup Own Placed Pets",
		Callback = function()
			local b = ownedBase()
			if not b or not RequestPetPickup then
				notify("missing")
				return
			end
			local seen = {}
			local n = 0
			local folder = b:FindFirstChild("PlacedPets")
			local root = folder or b
			for _, inst in ipairs(root:GetDescendants()) do
				local id = inst:GetAttribute("PlacementId")
				if type(id) == "string" and not seen[id] then
					seen[id] = true
					pcall(function()
						RequestPetPickup:InvokeServer(id)
					end)
					n += 1
				end
			end
			notify("pickup " .. n)
		end,
	})
	Tab:Button({
		Title = "Place Backpack Pets",
		Desc = "RequestPetPlacement(PetId). Must be inside your base.",
		Callback = function()
			if not RequestPetPlacement then
				notify("missing")
				return
			end
			local n = 0
			local function scan(folder)
				if not folder then
					return
				end
				for _, tool in ipairs(folder:GetChildren()) do
					if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Pet" then
						local id = tool:GetAttribute("PetId")
						if type(id) == "string" and id ~= "" then
							pcall(function()
								RequestPetPlacement:InvokeServer(id)
							end)
							n += 1
						end
					end
				end
			end
			scan(LocalPlayer.Backpack)
			scan(LocalPlayer.Character)
			notify("place attempts " .. n)
		end,
	})
	Tab:Button({
		Title = "List Unlocked Pets",
		Callback = function()
			local ok, res = pcall(function()
				return RequestUnlockedPets:InvokeServer()
			end)
			notify(ok and dumpResult(res) or tostring(res), 5)
		end,
	})
	Tab:Dropdown({
		Title = "Lucky Block",
		Values = catalogValues("LuckyBlock"),
		Value = CFG.LuckyId,
		Callback = function(v)
			if v and v ~= "(empty)" then
				CFG.LuckyId = v
			end
		end,
	})
	Tab:Button({
		Title = "Open Lucky Block + Claim",
		Callback = function()
			if not LuckyBlockOpenRequest then
				notify("LuckyBlockOpenRequest missing")
				return
			end
			local ok, res = pcall(function()
				return LuckyBlockOpenRequest:InvokeServer(CFG.LuckyId)
			end)
			if not ok or type(res) ~= "table" or res.success ~= true then
				notify("open fail: " .. dumpResult(res))
				return
			end
			local token = res.token
			if LuckyBlockClaimReward and token then
				pcall(function()
					LuckyBlockClaimReward:FireServer(token)
				end)
				notify("claimed " .. tostring(token))
				return
			end
			notify("opened, no token")
		end,
	})
	Tab:Dropdown({
		Title = "Ore Pack",
		Values = catalogValues("Pack"),
		Value = CFG.PackId,
		Callback = function(v)
			if v and v ~= "(empty)" then
				CFG.PackId = v
			end
		end,
	})
	Tab:Button({
		Title = "Open Ore Pack + Claim",
		Callback = function()
			if not OrePackOpenRequest then
				notify("OrePackOpenRequest missing")
				return
			end
			local ok, res = pcall(function()
				return OrePackOpenRequest:InvokeServer(CFG.PackId)
			end)
			if not ok or type(res) ~= "table" or res.success ~= true then
				notify("open fail: " .. dumpResult(res))
				return
			end
			local token = res.token
			if OrePackClaimReward and token then
				pcall(function()
					OrePackClaimReward:FireServer(token)
				end)
				notify("claimed pack")
				return
			end
			notify("opened, no token")
		end,
	})
	Tab:Button({
		Title = "Open Backpack Lucky/Pack Tools",
		Callback = function()
			local n = 0
			local function scan(folder)
				if not folder then
					return
				end
				for _, tool in ipairs(folder:GetChildren()) do
					if tool:IsA("Tool") then
						local kind = tool:GetAttribute("ToolType")
						if kind == "LuckyBlock" then
							local id = tool:GetAttribute("LuckyBlockId") or tool:GetAttribute("Id") or tool.Name
							local ok, res = pcall(function()
								return LuckyBlockOpenRequest:InvokeServer(id)
							end)
							if ok and type(res) == "table" and res.token and LuckyBlockClaimReward then
								LuckyBlockClaimReward:FireServer(res.token)
							end
							n += 1
						elseif kind == "OrePack" then
							local id = tool:GetAttribute("PackType") or tool:GetAttribute("Id") or "OrePack"
							local ok, res = pcall(function()
								return OrePackOpenRequest:InvokeServer(id)
							end)
							if ok and type(res) == "table" and res.token and OrePackClaimReward then
								OrePackClaimReward:FireServer(res.token)
							end
							n += 1
						end
					end
				end
			end
			scan(LocalPlayer.Backpack)
			scan(LocalPlayer.Character)
			notify("opened " .. n .. " tools")
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Visuals", Icon = "eye", IconColor = Blue })
	Tab:Toggle({
		Title = "Player ESP",
		Default = CFG.EspPlayers,
		Callback = function(v)
			CFG.EspPlayers = v
			if not v and not CFG.EspTunnels then
				clearEsp()
			end
		end,
	})
	Tab:Toggle({
		Title = "Tunnel ESP",
		Desc = "Owned-base tunnels: ore, mutation, growth",
		Default = CFG.EspTunnels,
		Callback = function(v)
			CFG.EspTunnels = v
			if not v and not CFG.EspPlayers then
				clearEsp()
			end
		end,
	})
	Tab:Button({
		Title = "Refresh ESP",
		Callback = refreshEsp,
	})
end

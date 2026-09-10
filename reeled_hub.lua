--[[
  Reeled Hub - WindUI
  live-reload label: reeled_hub
  Place 137783946150684 / Universe 9511524806

  Farm + combat. Combat tab = targeting, ESP, presets, steal combat.
  Unique remotes ~55. ItemData scan expands BuyItem ids.
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
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

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

local MULT_VALUES = { "x1", "x2", "x3", "x4", "x6", "x10" }
local MULT_MAP = { x1 = 1, x2 = 2, x3 = 3, x4 = 4, x6 = 6, x10 = 10 }

local WORLDS = {
	{ id = 2000, name = "Wilderness" },
	{ id = 2001, name = "Warm water Lake" },
	{ id = 2002, name = "Sakura Valley" },
	{ id = 2003, name = "Sludge Pool" },
	{ id = 2004, name = "North Wind Canyon" },
	{ id = 2005, name = "Bloomwater Pond" },
	{ id = 2006, name = "Whispering Hollow" },
	{ id = 2007, name = "The Village" },
}

local RODS = {
	{ id = 4001, name = "Wooden Rod" },
	{ id = 4002, name = "Iron Rod" },
	{ id = 4003, name = "Gold Rod" },
	{ id = 4004, name = "Diamond Rod" },
	{ id = 4005, name = "Clover Rod" },
	{ id = 4006, name = "Turnip Rod" },
	{ id = 4007, name = "Amethyst Rod" },
	{ id = 4008, name = "Glacier Rod" },
	{ id = 4009, name = "Harden Rod" },
	{ id = 4010, name = "Mushroom Rod" },
	{ id = 4011, name = "Blade Rod" },
	{ id = 4012, name = "Monarch Rod" },
	{ id = 4013, name = "Rainbow Rod" },
	{ id = 4014, name = "Christmas Rod" },
	{ id = 4015, name = "Scallions Rod" },
	{ id = 4016, name = "Voidthorn Rod" },
	{ id = 4017, name = "Huntsman Blade Rod" },
}

local GUNS = {
	{ id = 2001, name = "Glock 17" },
	{ id = 2003, name = "M1911" },
	{ id = 2005, name = "Deagle" },
	{ id = 2007, name = "HK416" },
	{ id = 2009, name = "M4A1" },
	{ id = 2011, name = "AK47" },
	{ id = 2013, name = "M4 Benelli" },
	{ id = 2015, name = "M24" },
	{ id = 2017, name = "AS VAL" },
	{ id = 2019, name = "PP-91" },
	{ id = 2021, name = "SCAR" },
	{ id = 2023, name = "Evo" },
	{ id = 2025, name = "Vector" },
	{ id = 2027, name = "Barrett" },
	{ id = 2055, name = "Crimson HK416" },
	{ id = 2056, name = "VoidStorm AK47" },
}

local SHIPS = {
	{ id = 1001, name = "Raft" },
	{ id = 1002, name = "Duck Boat" },
	{ id = 1003, name = "Acacia Wooden Boat" },
	{ id = 1004, name = "Small Steamships" },
	{ id = 1005, name = "Speedboat" },
	{ id = 1006, name = "Luxury Cruises" },
}

local TRAPS = {
	{ id = 5001, name = "Beach Crab Pot" },
	{ id = 5002, name = "Sakura Crab Pot" },
	{ id = 5003, name = "Swamp Crab Pot" },
	{ id = 5004, name = "Garden Crab Pot" },
}

local VALUE_KEYS = {
	"coin",
	"gem",
	"exp",
	"level",
	"luckUp",
	"drawCount",
	"kill",
	"killCount",
	"passPoint",
	"robux",
	"title",
	"world",
}

local CFG = store.cfg
	or {
		AuraRange = 400,
		SpeedMult = 1,
		WalkSpeed = 16,
		JumpPower = 50,
		FlySpeed = 40,
		Gravity = 196.2,
		HipHeight = 2,
		AnimMult = 1,
		FarmDelay = 0.3,
		SelectedRod = 4002,
		SelectedGun = 2011,
		SelectedShip = 1001,
		SelectedTrap = 5001,
		SelectedWorld = 2001,
		EditKey = "coin",
		EditValue = "1500",
		PromoCode = "",
		TitleId = "1",
		BagSlot = 1,
		FpsCap = 0,
		SilentFov = 140,
		FireRateMult = 2.5,
		EspPrice = true,
		Pierce = true,
		InstantKill = true,
		InstantReload = true,
		RapidFire = true,
		TargetMode = "Richest",
		FishNameFilter = "",
		StickyLock = true,
		AutoBestGun = true,
		AutoGunMode = "Best",
		EspHp = true,
		EspOwner = true,
		EspLockLine = true,
		EspFovCircle = true,
		EspBrewTimer = true,
		SmartPierce = true,
		PierceMax = 3,
		PierceMinHp = 50,
		PierceCone = true,
		TriggerBot = false,
		CombatLos = true,
		StealTpFish = true,
		ShotBudget = true,
		CombatAutoRefill = true,
		PreferHeadshot = true,
	}
store.cfg = CFG
do
	local off = {
		Silent = false,
		AntiAfk = false,
		FpsUnlock = false,
		InstantBite = false,
		InstantCatch = false,
		InstantClick = false,
		InstantPrompt = false,
		InstantTween = false,
		AutoFarm = false,
		AutoSell = false,
		AutoShoot = false,
		KillAura = false,
		SilentAim = false,
		InfBullet = false,
		SpeedBullet = false,
		KillOthers = false,
		AutoPots = false,
		AutoRecycle = false,
		AutoRefill = false,
		AutoMail = false,
		AutoDaily = false,
		AutoDrink = false,
		AutoSteal = false,
		AutoHotspot = false,
		AutoUnlock = false,
		AutoUpgrade = false,
		AutoClaim = false,
		AutoNpcTask = false,
		AutoBrew = false,
		WalkOn = false,
		JumpOn = false,
		InfJump = false,
		Noclip = false,
		Fly = false,
		ClickTp = false,
		ZoomUnlock = false,
		GravityOn = false,
		AnimOn = false,
		ReplicaWrite = false,
	}
	for k, v in pairs(off) do
		CFG[k] = v
	end
	if CFG.SilentFov == nil then
		CFG.SilentFov = 140
	end
	if CFG.FireRateMult == nil then
		CFG.FireRateMult = 2.5
	end
	if CFG.RapidFire == nil then
		CFG.RapidFire = true
	end
	if CFG.InstantReload == nil then
		CFG.InstantReload = true
	end
	if CFG.EspPrice == nil then
		CFG.EspPrice = true
	end
	if CFG.Pierce == nil then
		CFG.Pierce = true
	end
	if CFG.InstantKill == nil then
		CFG.InstantKill = true
	end
	if CFG.TargetMode == nil then
		CFG.TargetMode = "Richest"
	end
	if CFG.StickyLock == nil then
		CFG.StickyLock = true
	end
	if CFG.AutoBestGun == nil then
		CFG.AutoBestGun = true
	end
	if CFG.PierceMax == nil then
		CFG.PierceMax = 3
	end
end

store.combatStats = store.combatStats or { kills = 0, shots = 0, t0 = tick() }

local function GG()
	local ok, env = pcall(getrenv)
	if ok and typeof(env) == "table" and typeof(env._G) == "table" then
		return env._G
	end
	return _G
end

local function gm()
	return GG().GameMgr
end

local function dm()
	return GG().DataMgr
end

local function nm()
	return GG().NetMgr
end

local function um()
	return GG().UIManager
end

local function notify(title, content)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = title or "Reeled",
			Content = tostring(content or ""),
			Duration = 2.2,
		})
	end)
end

local function call(method, ...)
	local m = gm()
	if not m or typeof(m[method]) ~= "function" then
		return false, "no " .. tostring(method)
	end
	return pcall(m[method], m, ...)
end

local function fire(name, ...)
	local n = nm()
	if not n then
		return false, "no NetMgr"
	end
	return pcall(function(...)
		n:FireServer(name, ...)
	end, ...)
end

local function invoke(name, ...)
	local n = nm()
	if not n then
		return false, "no NetMgr"
	end
	return pcall(function(...)
		return n:InvokeServer(name, ...)
	end, ...)
end

-- Unique NetMgr names the client actually fires. Not 300: Reeled only has ~55.
-- Extra "functions" the server eats are the SAME names with real args
-- (BuyItem+itemId, GetReward+type, TrigerSkill+skill). Scan ItemData for ids.
local NET_FIRE = {
	"BuyItem", "PlayerRespawn", "TeleportToGame", "BackLobby", "SendFeedBack",
	"Teleport", "SendCode", "ChangeTitle", "DrinkPotion", "InviteFriend",
	"UseItem", "Fish", "UpgradeWeapon", "SellWeapon", "EquipWeapon", "SellItem",
	"SellAllItem", "SpawnShip", "BuyShip", "RefillBullet", "BuyUnLockItem",
	"CollectCrabTrap", "RecycleCrabTrap", "UnLockWorld", "SkipTutorial",
	"LockItem", "ItemMove", "ChangeSetting", "LogEvent", "LogCustomEvent",
	"GetMail", "UpdataMail", "GiftToPlayer", "CancelGift", "GetReward",
	"CheckEligible", "StartWorldTask", "ReciveNpcTask", "SubmitNpcTask",
}
local NET_INVOKE = {
	"WaitFish", "GetConfigData", "GetTempBoost", "GetPlayerBaseData",
	"GetPlayerCacheData", "GetEnv", "GetTime", "GetWorldTask", "GetDailyTask",
}
local PLAYER_REP = { "EquipItem", "UnequipItem", "TrigerSkill", "SetState", "ReplicatedState" }
local SKILL_FIRE = {
	{ "GunFire", "Atk" },
	{ "GunFire", "OnEnter" },
	{ "Fish", "Throw" },
	{ "Fish", "Enter" },
	{ "GunReload", "Enter" },
}
local REWARD_TYPES = {
	"DailyReward", "DailyTaskReward", "TimeReward", "PassReward",
	"UpgradeReward", "GroupReward",
}
local OTHER_REMOTE = {
	{ "DevProduct", "PurchasePirateBrew" },
	{ "FishAreaEvent", "FishAreaDone" },
	{ "TutorialEvent", "FinishedLoading" },
	{ "NPC", "GetLevel" },
}

local function netCatalogText()
	local lines = {
		"# Reeled server names the client actually calls",
		"# unique remotes ~ " .. tostring(#NET_FIRE + #NET_INVOKE + #PLAYER_REP + #SKILL_FIRE + #OTHER_REMOTE),
		"",
		"[NetMgr FireServer]",
	}
	for _, n in ipairs(NET_FIRE) do
		table.insert(lines, "Fire " .. n)
	end
	table.insert(lines, "")
	table.insert(lines, "[NetMgr InvokeServer]")
	for _, n in ipairs(NET_INVOKE) do
		table.insert(lines, "Invoke " .. n)
	end
	table.insert(lines, "")
	table.insert(lines, "[PlayerReplicated]")
	for _, n in ipairs(PLAYER_REP) do
		table.insert(lines, "Player " .. n)
	end
	table.insert(lines, "")
	table.insert(lines, "[TrigerSkill]")
	for _, p in ipairs(SKILL_FIRE) do
		table.insert(lines, "Skill " .. p[1] .. " " .. p[2])
	end
	table.insert(lines, "")
	table.insert(lines, "[GetReward types]")
	for _, n in ipairs(REWARD_TYPES) do
		table.insert(lines, "GetReward " .. n)
	end
	table.insert(lines, "")
	table.insert(lines, "[other remotes]")
	for _, p in ipairs(OTHER_REMOTE) do
		table.insert(lines, p[1] .. " " .. p[2])
	end
	return table.concat(lines, "\n")
end

local function scanItemIds()
	local d = dm()
	local hits = {}
	if not d or typeof(d.GetConfig) ~= "function" then
		return hits
	end
	for id = 1000, 5999 do
		local ok, cfg = pcall(function()
			return d:GetConfig("ItemData", id)
		end)
		if ok and typeof(cfg) == "table" and cfg.type then
			table.insert(hits, {
				id = id,
				type = tostring(cfg.type),
				name = tostring(cfg.name or id),
			})
		end
	end
	return hits
end

local function pdata(key)
	local d = dm()
	if not d then
		return nil
	end
	if typeof(d.data) == "table" and d.data[key] ~= nil then
		return d.data[key]
	end
	local ok, v = pcall(function()
		return d:GetPlayerBaseData(key)
	end)
	if ok then
		return v
	end
	return nil
end

local function getClient()
	local d = dm()
	if not d then
		return nil
	end
	local ok, cp = pcall(function()
		return d:GetClientPlayer()
	end)
	if ok then
		return cp
	end
	return nil
end

local function unwrap(t)
	if typeof(t) ~= "table" then
		return t
	end
	return t._array or t
end

local function itemCfg(id)
	local d = dm()
	if not d or not id then
		return nil
	end
	local ok, cfg = pcall(function()
		return d:GetConfig("ItemData", id)
	end)
	if ok then
		return cfg
	end
	return nil
end

local function findSlot(itemType, wantId, needAmmo)
	local bag = unwrap(pdata("bag"))
	if typeof(bag) ~= "table" then
		return nil
	end
	local fallbackI, fallbackItem, fallbackCfg
	for i, item in pairs(bag) do
		if typeof(item) == "table" and item.id then
			local cfg = itemCfg(item.id)
			if cfg and cfg.type == itemType then
				local idx = tonumber(i) or i
				if wantId and item.id == wantId then
					if not needAmmo or (tonumber(item.bullet) or 0) > 0 then
						return idx, item, cfg
					end
				end
				if not needAmmo or (tonumber(item.bullet) or 0) > 0 then
					if not fallbackI then
						fallbackI, fallbackItem, fallbackCfg = idx, item, cfg
					end
				elseif not fallbackI then
					fallbackI, fallbackItem, fallbackCfg = idx, item, cfg
				end
			end
		end
	end
	return fallbackI, fallbackItem, fallbackCfg
end

local function getSkill(name)
	local cp = getClient()
	if not cp or typeof(cp.skillList) ~= "table" then
		return nil
	end
	local slot = cp.skillList[name]
	return slot and slot.skill
end

local function clearEquipBlockers()
	pcall(function()
		LocalPlayer:SetAttribute("InUi", false)
	end)
	local cp = getClient()
	local _, hum = charHum()
	if hum then
		hum.Sit = false
	end
	if cp then
		pcall(function()
			cp:SetState("action", false)
		end)
	end
end

local function netEquip(idx)
	local ch = select(1, charHum())
	local nm = ch and ch:FindFirstChild("NetMessage")
	local ev = nm and nm:FindFirstChild("EquipItem")
	if ev and ev:IsA("RemoteEvent") then
		ev:FireServer(idx)
		return true
	end
	return false
end

local function equipSlot(idx)
	local cp = getClient()
	if not cp or not idx then
		return false
	end
	if cp.equipIndex == idx then
		return true
	end
	clearEquipBlockers()
	pcall(function()
		cp:EquipItem(idx)
	end)
	if cp.equipIndex ~= idx then
		netEquip(idx)
	end
	local t0 = tick()
	while STATE.alive() and tick() - t0 < 1.4 and cp.equipIndex ~= idx do
		task.wait(0.05)
	end
	return cp.equipIndex == idx
end

local function setReplica(key, value)
	local d = dm()
	if not d or typeof(d.data) ~= "table" then
		return false
	end
	d.data[key] = value
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	if ls then
		local stat = ls:FindFirstChild(key)
		if stat and stat:IsA("ValueBase") then
			stat.Value = value
		end
	end
	return true
end

local function charHum()
	local chars = Workspace:FindFirstChild("Characters")
	local ch = (chars and chars:FindFirstChild(LocalPlayer.Name)) or LocalPlayer.Character
	if not ch then
		return nil, nil, nil
	end
	return ch, ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
end

local function names(list)
	local t = {}
	for _, v in ipairs(list) do
		table.insert(t, v.name)
	end
	return t
end

local function idOf(list, label)
	for _, v in ipairs(list) do
		if v.name == label then
			return v.id
		end
	end
	return list[1] and list[1].id
end

local function labelOf(list, id)
	for _, v in ipairs(list) do
		if v.id == id then
			return v.name
		end
	end
	return list[1] and list[1].name
end

local function bagDump()
	local lines = {}
	local bag = unwrap(pdata("bag"))
	if typeof(bag) ~= "table" then
		return "bag empty"
	end
	local keys = {}
	for i in pairs(bag) do
		table.insert(keys, i)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, i in ipairs(keys) do
		local item = bag[i]
		if typeof(item) == "table" and item.id then
			local cfg = itemCfg(item.id)
			local name = (cfg and cfg.name) or tostring(item.id)
			local extra = ""
			if item.bullet then
				extra = string.format("  mag %s/%s", tostring(item.bullet), tostring(item.ammo or "?"))
			elseif item.mass then
				extra = string.format("  %.2fkg", item.mass)
			end
			table.insert(lines, string.format("[%s] %s%s", tostring(i), name, extra))
		end
	end
	return #lines > 0 and table.concat(lines, "\n") or "bag empty"
end

local function statusText()
	local coin = pdata("coin")
	local gem = pdata("gem")
	local exp = pdata("exp")
	local level = pdata("level")
	local world = pdata("world")
	local luck = pdata("luckUp")
	local wname = labelOf(WORLDS, world) or tostring(world)
	local cp = getClient()
	local eq = cp and tostring(cp.equipIndex or -1) or "?"
	return string.format(
		"coin %s  gem %s  exp %s  lv %s\nworld %s  luck %s  equip %s  x%s\n%s",
		tostring(coin),
		tostring(gem),
		tostring(exp),
		tostring(level),
		wname,
		tostring(luck),
		eq,
		tostring(CFG.SpeedMult),
		bagDump()
	)
end

local function applyFps()
	if typeof(setfpscap) == "function" then
		setfpscap(CFG.FpsUnlock and (CFG.FpsCap <= 0 and 0 or CFG.FpsCap) or 60)
	end
end

local function applyWalk()
	local _, hum = charHum()
	if not hum then
		return
	end
	if CFG.WalkOn then
		hum.WalkSpeed = CFG.WalkSpeed
	end
	if CFG.JumpOn then
		pcall(function()
			hum.UseJumpPower = true
			hum.JumpPower = CFG.JumpPower
		end)
		pcall(function()
			hum.JumpHeight = CFG.JumpPower / 10
		end)
	end
	if CFG.HipHeight and CFG.HipHeight ~= 2 then
		pcall(function()
			hum.HipHeight = CFG.HipHeight
		end)
	end
end

local function instantReload(fire)
	if CFG.InstantReload == false or not fire or not fire.item then
		return false
	end
	local item = fire.item
	local detail = item.detail
	local data = item.data
	if not detail or not data then
		return false
	end
	local cp = fire.player or getClient()
	local mag = tonumber(data.magSize) or 30
	local cur = tonumber(detail.bullet) or 0
	if cur >= mag then
		pcall(function()
			if cp and cp:ChackState("reload") then
				cp:SetState("reload", false)
			end
			GG().EventMgr:Triger("Reload")
		end)
		return true
	end
	local ammo = tonumber(detail.ammo) or 0
	if ammo <= 0 then
		call("RefillBullet", item.id or CFG.SelectedGun)
		ammo = tonumber(detail.ammo) or 0
		if ammo <= 0 then
			ammo = mag
			detail.ammo = ammo
		end
	end
	local add = math.min(mag - cur, ammo)
	if add <= 0 then
		return false
	end
	detail.bullet = cur + add
	detail.ammo = ammo - add
	local reload = getSkill("GunReload")
	if reload then
		pcall(function()
			reload:Fire("Enter", add)
		end)
		pcall(function()
			local anims = item.Animations
			if anims and anims.reload then
				anims.reload:Stop(0)
			end
		end)
	end
	pcall(function()
		if cp then
			cp:SetState("reload", false)
			cp:SetState("action", false)
		end
		GG().EventMgr:Triger("Reload")
	end)
	return true
end

local function applyGunMods()
	local cp = getClient()
	local fire = getSkill("GunFire")
	local mult = math.clamp(tonumber(CFG.FireRateMult) or FIRE_RATE_MAX, 1, FIRE_RATE_MAX)
	if cp then
		if store.origPlayerRate == nil then
			store.origPlayerRate = cp.rate
		end
		cp.rate = mult
	end
	if not fire or not fire.item then
		return
	end
	local data = fire.item.data
	local detail = fire.item.detail
	if data then
		if not store.origGunData then
			store.origGunData = {
				rate = data.rate,
				recoil = data.recoilVal,
				reload = data.reloadTime,
			}
		end
		local base = store.origGunData.rate or 0.18
		data.rate = math.max(0.05, base / mult)
		data.reloadTime = 0.01
		data.recoilVal = (store.origGunData.recoil or 1) * 0.55
	end
	if CFG.InstantReload ~= false and cp and cp:ChackState("reload") then
		pcall(instantReload, fire)
	end
	if CFG.InfBullet then
		local mag = (data and tonumber(data.magSize)) or 30
		if detail then
			detail.bullet = mag
			if typeof(detail.ammo) == "number" then
				detail.ammo = math.max(detail.ammo, mag * 4)
			end
		end
		local bag = unwrap(pdata("bag"))
		if typeof(bag) == "table" then
			local d = dm()
			for _, it in pairs(bag) do
				if typeof(it) == "table" and it.id then
					local cfg = itemCfg(it.id)
					if cfg and cfg.type == "Weapon" then
						local wcfg = d and d:GetConfig("WeaponData", it.id)
						it.bullet = (wcfg and wcfg.magSize) or mag
					end
				end
			end
		end
		if typeof(fire.item.RemoveBullet) == "function" and not fire.item._infHook then
			local orig = fire.item.RemoveBullet
			fire.item.RemoveBullet = function(self, n)
				orig(self, n)
				if self.detail then
					self.detail.bullet = mag
				end
				return true
			end
			fire.item._infHook = true
		end
		if tick() - (store.refillTick or 0) > 2.5 then
			store.refillTick = tick()
			local _, item = findSlot("Weapon", CFG.SelectedGun)
			call("RefillBullet", item and item.id or CFG.SelectedGun)
		end
	end
end

local function applyGravity()
	Workspace.Gravity = CFG.GravityOn and CFG.Gravity or 196.2
end

local function applyZoom()
	if not CFG.ZoomUnlock then
		return
	end
	pcall(function()
		LocalPlayer.CameraMaxZoomDistance = 400
		LocalPlayer.CameraMinZoomDistance = 0.5
	end)
end

local function applyAnim()
	local _, hum = charHum()
	if not hum or not CFG.AnimOn then
		return
	end
	for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
		pcall(function()
			t:AdjustSpeed(CFG.AnimMult)
		end)
	end
end

local function applyPrompts()
	if not CFG.InstantPrompt then
		return
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") then
			inst.HoldDuration = 0
			inst.RequiresLineOfSight = false
			inst.MaxActivationDistance = math.max(inst.MaxActivationDistance, 18)
		end
	end
end

local function fireAllPrompts()
	local n = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
			pcall(fireproximityprompt, inst)
			n += 1
		end
	end
	return n
end

local origWaitFish = store.origWaitFish
local origTweenCreate = store.origTweenCreate

local function hookWaitFish()
	-- do not mutate WaitFish.waitTime — server still waits. fake 0 made Fish() miss.
end

local function hookTween()
	return
end

local function setSpeed(n)
	CFG.SpeedMult = n
	CFG.WalkSpeed = 16 * n
	CFG.AnimMult = n
	CFG.FlySpeed = 40 * n
	CFG.FarmDelay = math.max(0.02, 0.3 / n)
	applyWalk()
	applyAnim()
end

local function tpTo(inst)
	local _, _, hrp = charHum()
	if not hrp or not inst then
		return false
	end
	local cf
	if inst:IsA("Model") then
		cf = inst:GetPivot()
	elseif inst:IsA("BasePart") then
		cf = inst.CFrame
	else
		local p = inst:FindFirstChildWhichIsA("BasePart", true)
		cf = p and p.CFrame
	end
	if not cf then
		return false
	end
	hrp.CFrame = cf + Vector3.new(0, 4, 0)
	return true
end

local function findE(name)
	local e = Workspace:FindFirstChild("EItem")
	return e and e:FindFirstChild(name, true)
end

local function collectPots()
	local n = 0
	local folder = Workspace:FindFirstChild("Characters") and Workspace.Characters:FindFirstChild("CrabTrap")
	if not folder then
		return 0
	end
	for _, trap in ipairs(folder:GetChildren()) do
		if trap:GetAttribute("ID") then
			call("CollectCrabTrap", trap:GetAttribute("ID"))
			n += 1
		end
	end
	return n
end

local function recyclePots()
	local n = 0
	local folder = Workspace:FindFirstChild("Characters") and Workspace.Characters:FindFirstChild("CrabTrap")
	if not folder then
		return 0
	end
	for _, trap in ipairs(folder:GetChildren()) do
		if trap:GetAttribute("ID") then
			call("RecycleCrabTrap", trap:GetAttribute("ID"))
			n += 1
		end
	end
	return n
end

local function ownZone()
	local map = Workspace:FindFirstChild("Map")
	local fa = map and map:FindFirstChild("FishArea")
	if not fa then
		return nil
	end
	return fa:FindFirstChild(LocalPlayer.Name .. "'s Zone")
end

local function fishBoxPart(m, name)
	local box = m and m:FindFirstChild("Box")
	return box and box:FindFirstChild(name)
end

local function fishTorso(m)
	return fishBoxPart(m, "Torso") or m and (m:FindFirstChild("Root") or m.PrimaryPart)
end

local function fishHitPart(m)
	if not m then
		return nil
	end
	return fishBoxPart(m, "Head") or fishTorso(m)
end

local function preferHead(part)
	if not part or not part.Parent then
		return part
	end
	local m = part:FindFirstAncestorWhichIsA("Model")
	return fishHitPart(m) or part
end

local function zoneOwnerOf(inst)
	local n = inst
	while n do
		local owner = n:GetAttribute("Owner")
		if owner then
			return owner
		end
		n = n.Parent
	end
end

local function fishHp(m, hum)
	local hp = m and tonumber(m:GetAttribute("hp"))
	if hp then
		return hp
	end
	return (hum and tonumber(hum.Health)) or 100
end

local function fishUnitPrice(id)
	id = tonumber(id)
	if not id then
		return 0
	end
	store.priceCache = store.priceCache or {}
	if store.priceCache[id] ~= nil then
		return store.priceCache[id]
	end
	local cfg = itemCfg(id)
	local p = 0
	if cfg then
		pcall(function()
			p = tonumber(cfg.price) or 0
		end)
	end
	store.priceCache[id] = p
	return p
end

local function fishValue(m)
	if not m then
		return 0
	end
	local id = m:GetAttribute("Id") or m:GetAttribute("ID")
	local mass = tonumber(m:GetAttribute("Mass")) or 0
	local unit = fishUnitPrice(id)
	if mass > 0 then
		return mass * unit
	end
	return unit
end

local function fmtMoney(n)
	n = tonumber(n) or 0
	if n >= 1e6 then
		return string.format("$%.1fM", n / 1e6)
	end
	if n >= 1000 then
		return string.format("$%.1fK", n / 1000)
	end
	return string.format("$%.0f", n)
end

local function fishAlive(m, hum)
	local hp = m and tonumber(m:GetAttribute("hp"))
	if hp ~= nil then
		return hp > 1
	end
	return hum and hum.Health > 0
end

local function fishMaxHp(m, hum)
	local mx = m and tonumber(m:GetAttribute("maxHp"))
	if mx then
		return mx
	end
	return fishHp(m, hum)
end

local function fishInZone(zone)
	local out = {}
	if not zone then
		return out
	end
	for _, m in ipairs(zone:GetChildren()) do
		if m:IsA("Model") then
			local hum = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid", true)
			local hit = fishHitPart(m)
			if hit and fishAlive(m, hum) then
				table.insert(out, {
					model = m,
					hum = hum,
					root = hit,
					hit = hit,
					hp = fishHp(m, hum),
					maxHp = fishMaxHp(m, hum),
					price = fishValue(m),
					owner = zone:GetAttribute("Owner"),
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.price or 0) > (b.price or 0)
	end)
	return out
end

local function combatStatShot()
	store.combatStats = store.combatStats or { kills = 0, shots = 0, t0 = tick() }
	store.combatStats.shots = (store.combatStats.shots or 0) + 1
end

local function combatStatKill()
	store.combatStats = store.combatStats or { kills = 0, shots = 0, t0 = tick() }
	store.combatStats.kills = (store.combatStats.kills or 0) + 1
end

local function combatStatsText()
	local s = store.combatStats or {}
	local elapsed = math.max(1, tick() - (s.t0 or tick()))
	local kph = (s.kills or 0) / elapsed * 3600
	return string.format(
		"kills %d  shots %d  %.1f/hr  %.0fs",
		s.kills or 0,
		s.shots or 0,
		kph,
		elapsed
	)
end

local function weaponDataAtk(id)
	id = tonumber(id)
	if not id then
		return 0
	end
	local d = dm()
	if not d then
		return 0
	end
	local ok, w = pcall(function()
		return d:GetConfig("WeaponData", id)
	end)
	if ok and w then
		return tonumber(w.atk) or 0
	end
	return 0
end

local function bestGunSlot()
	local bag = unwrap(pdata("bag"))
	if typeof(bag) ~= "table" then
		return nil
	end
	local bestIdx, bestItem, bestAtk
	for i, item in pairs(bag) do
		if typeof(item) == "table" and item.id then
			local cfg = itemCfg(item.id)
			if cfg and cfg.type == "Weapon" and (tonumber(item.bullet) or 0) > 0 then
				local atk = weaponDataAtk(item.id)
				if not bestAtk or atk > bestAtk then
					bestAtk = atk
					bestIdx = tonumber(i) or i
					bestItem = item
				end
			end
		end
	end
	return bestIdx, bestItem, bestAtk
end

local function bagGunOptions()
	local out = { "Best (auto)" }
	local bag = unwrap(pdata("bag"))
	local seen = {}
	if typeof(bag) == "table" then
		for _, item in pairs(bag) do
			if typeof(item) == "table" and item.id and not seen[item.id] then
				local cfg = itemCfg(item.id)
				if cfg and cfg.type == "Weapon" then
					seen[item.id] = true
					local atk = weaponDataAtk(item.id)
					table.insert(out, string.format("%d %s (%d atk)", item.id, cfg.name or "Gun", atk))
				end
			end
		end
	end
	for _, g in ipairs(GUNS) do
		if not seen[g.id] then
			table.insert(out, string.format("%d %s", g.id, g.name))
		end
	end
	return out
end

local function parseGunPick(label)
	if not label or label == "Best (auto)" then
		return nil
	end
	return tonumber(string.match(label, "^(%d+)"))
end

local function fishDist(f)
	local _, _, hrp = charHum()
	local p = f and (f.root or f.hit)
	if not hrp or not p then
		return math.huge
	end
	return (p.Position - hrp.Position).Magnitude
end

local function fishPassesFilter(f)
	local filter = CFG.FishNameFilter
	if not filter or filter == "" or not f or not f.model then
		return true
	end
	local name = string.lower(f.model.Name or "")
	return string.find(name, string.lower(filter), 1, true) ~= nil
end

local function hasLos(part)
	if CFG.CombatLos == false or not part then
		return true
	end
	local _, _, hrp = charHum()
	local cam = Workspace.CurrentCamera
	local origin = (cam and cam.CFrame.Position) or (hrp and hrp.Position)
	if not origin then
		return false
	end
	local dir = part.Position - origin
	if dir.Magnitude < 0.1 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { LocalPlayer.Character }
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(origin, dir, params)
	if not hit then
		return true
	end
	local model = part:FindFirstAncestorWhichIsA("Model")
	return hit.Instance == part
		or hit.Instance:IsDescendantOf(model or part)
		or (model and hit.Instance:IsDescendantOf(model))
end

local function inFov(part)
	local cam = Workspace.CurrentCamera
	if not cam or not part then
		return false
	end
	local v, on = cam:WorldToViewportPoint(part.Position)
	if not on or v.Z <= 0 then
		return false
	end
	local center = cam.ViewportSize / 2
	return (Vector2.new(v.X, v.Y) - center).Magnitude <= (CFG.SilentFov or 140)
end

local function pierceInCone(part)
	if CFG.PierceCone == false or not part then
		return true
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return true
	end
	local dir = (part.Position - cam.CFrame.Position).Unit
	local dot = cam.CFrame.LookVector:Dot(dir)
	return dot > 0.45
end

local function tpNearFish(f)
	if CFG.StealTpFish == false or not f then
		return false
	end
	local part = f.root or f.hit
	local _, _, hrp = charHum()
	if not part or not hrp then
		return false
	end
	local offset = (hrp.Position - part.Position).Unit * 12
	local pos = part.Position + Vector3.new(offset.X, 6, offset.Z)
	hrp.CFrame = CFrame.new(pos, part.Position)
	return true
end

local function pickTarget(fishes)
	local filtered = {}
	for _, f in ipairs(fishes or {}) do
		if fishPassesFilter(f) and fishAlive(f.model, f.hum) and hasLos(f.root or f.hit) then
			f.dist = fishDist(f)
			table.insert(filtered, f)
		end
	end
	if #filtered == 0 then
		store.killLock = nil
		return nil
	end
	if CFG.StickyLock ~= false and store.killLock then
		for _, f in ipairs(filtered) do
			if f.model == store.killLock then
				return f
			end
		end
	end
	local mode = CFG.TargetMode or "Richest"
	if mode == "Closest" then
		table.sort(filtered, function(a, b)
			return (a.dist or math.huge) < (b.dist or math.huge)
		end)
	elseif mode == "Low HP" or mode == "LowHP" then
		table.sort(filtered, function(a, b)
			return (a.hp or math.huge) < (b.hp or math.huge)
		end)
	else
		table.sort(filtered, function(a, b)
			return (a.price or 0) > (b.price or 0)
		end)
	end
	local pick = filtered[1]
	store.killLock = pick and pick.model or nil
	return pick
end

local function applyCombatPreset(name)
	if name == "Farm" then
		CFG.KillAura = true
		CFG.InstantKill = true
		CFG.Pierce = true
		CFG.AutoShoot = true
		CFG.EspPrice = true
		CFG.EspHp = true
		CFG.AutoBestGun = true
		CFG.TargetMode = "Richest"
		CFG.KillOthers = false
		CFG.AutoSteal = false
		CFG.TriggerBot = false
	elseif name == "Steal" then
		CFG.KillAura = true
		CFG.InstantKill = true
		CFG.Pierce = true
		CFG.AutoSteal = true
		CFG.AutoBrew = true
		CFG.KillOthers = true
		CFG.StealTpFish = true
		CFG.TargetMode = "Richest"
		CFG.AuraRange = math.max(CFG.AuraRange or 400, 600)
		CFG.EspOwner = true
		CFG.EspBrewTimer = true
	elseif name == "Manual" then
		CFG.KillAura = false
		CFG.TriggerBot = false
		CFG.SilentAim = true
		CFG.AutoSteal = false
		CFG.AutoShoot = false
	end
	notify("Combat", name .. " preset")
	if store.combatPara and store.combatPara.SetDesc then
		store.combatPara:SetDesc(combatStatsText())
	end
end

local function collectFish(range, others)
	local out = {}
	local map = Workspace:FindFirstChild("Map")
	local fa = map and map:FindFirstChild("FishArea")
	if not fa then
		return out
	end
	local _, _, hrp = charHum()
	local origin = hrp and hrp.Position
	local maxd = range or CFG.AuraRange or 400
	for _, zone in ipairs(fa:GetChildren()) do
		local owner = zone:GetAttribute("Owner")
		if others or owner == LocalPlayer.Name then
			for _, f in ipairs(fishInZone(zone)) do
				if not origin or (f.root.Position - origin).Magnitude <= maxd then
					table.insert(out, f)
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.price or 0) > (b.price or 0)
	end)
	return out
end

local function lookAt(pos)
	local cam = Workspace.CurrentCamera
	if cam and pos then
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, pos)
	end
end

local function silentLook(pos)
	local cam = Workspace.CurrentCamera
	if not cam or not pos then
		return function() end
	end
	local old = cam.CFrame
	cam.CFrame = CFrame.lookAt(cam.CFrame.Position, pos)
	return function()
		if CFG.SilentAim then
			cam.CFrame = old
		end
	end
end

local function gunAtk(fire)
	local id = fire and fire.item and fire.item.id
	local wAtk = id and weaponDataAtk(id) or 0
	if wAtk > 0 then
		return wAtk
	end
	local data = fire and fire.item and fire.item.data
	return (data and tonumber(data.atk)) or 13
end

local function gunHeadMult(fire)
	local data = fire and fire.item and fire.item.data
	local m = data and tonumber(data.headshotMultiplier)
	if m and m > 1 then
		return m
	end
	return 1.5
end

local function shotsFor(model, hum, fire, part)
	local hp = fishHp(model, hum)
	local atk = math.max(gunAtk(fire), 1)
	if part and part.Name == "Head" then
		atk = atk * gunHeadMult(fire)
	end
	local need = math.ceil(hp / atk) + 1
	local cap = CFG.InstantKill and 96 or 32
	return math.clamp(need, 1, cap)
end

local function netAtk(part)
	local ch = select(1, charHum())
	local nm = ch and ch:FindFirstChild("NetMessage")
	local ev = nm and nm:FindFirstChild("TrigerSkill")
	if ev and ev:IsA("RemoteEvent") and part then
		ev:FireServer("GunFire", "Atk", part)
		return true
	end
	return false
end

local FIRE_RATE_MAX = 2.5

local function fireRateVals(fire)
	local rate = 0.18
	if fire and fire.item and fire.item.data then
		rate = tonumber(fire.item.data.rate) or rate
	end
	local cp = fire and fire.player or getClient()
	local pr = 1
	if cp then
		pr = tonumber(cp.rate) or 1
	end
	local mult = math.clamp(tonumber(CFG.FireRateMult) or FIRE_RATE_MAX, 1, FIRE_RATE_MAX)
	pr = math.clamp(math.min(pr, mult), 1, FIRE_RATE_MAX)
	return rate, pr, mult
end

local function gunShotWait(fire)
	local rate, pr = fireRateVals(fire)
	if CFG.RapidFire == false then
		task.wait(math.max(0.12, (rate / pr) * 0.85))
		return
	end
	-- sweet spot: fast enough but server + hitmarker UI keep up
	task.wait(math.max(0.085, (rate / pr) * 0.58))
end

local function firePart(fire, part)
	if not fire or not part then
		return
	end
	pcall(function()
		fire:Fire("Atk", part)
	end)
	netAtk(part)
end

local function readyGun(fire)
	if not fire then
		return
	end
	fire.coolTime = 0
	fire.locked = false
	local rate, pr = fireRateVals(fire)
	fire.equipTick = tick() - (rate / pr) * (CFG.RapidFire == false and 0.82 or 1.0)
	pcall(function()
		fire.player:SetState("action", false)
		fire.player:SetState("reload", false)
	end)
end

local function realAtk(fire, aim)
	if not fire then
		return
	end
	if aim and not hasLos(aim) then
		return
	end
	if fire.item and fire.item.detail and (tonumber(fire.item.detail.bullet) or 0) <= 0 then
		instantReload(fire)
		if CFG.CombatAutoRefill and (tonumber(fire.item.detail.bullet) or 0) <= 0 then
			call("RefillBullet", fire.item.id or CFG.SelectedGun)
			instantReload(fire)
		end
	end
	local cam = Workspace.CurrentCamera
	if cam and aim and aim.Parent then
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aim.Position)
	end
	readyGun(fire)
	pcall(function()
		fire:Enter()
	end)
	pcall(function()
		fire:Atk()
	end)
	combatStatShot()
	task.wait(0.03)
	gunShotWait(fire)
end

local function osskAim(model, part)
	local head = model and fishBoxPart(model, "Head")
	local torso = (model and fishTorso(model)) or part
	if CFG.PreferHeadshot ~= false and head then
		return head, torso
	end
	if head and head.Size.Magnitude >= 12 then
		return head, torso
	end
	return torso, torso
end

local function osskKill(fire, part, model, hum)
	if not fire or not part then
		return
	end
	model = model or part:FindFirstAncestorWhichIsA("Model")
	local aim, torso = osskAim(model, part)
	local setting = dm() and dm().data and dm().data.setting
	local oldLock
	if setting then
		oldLock = setting.MouseLock
		setting.MouseLock = true
	end
	local t0 = tick()
	local budget = CFG.ShotBudget and shotsFor(model, hum, fire, aim) or 96
	local shots = 0
	while STATE.alive() and model and model.Parent and fishAlive(model, hum) do
		realAtk(fire, aim)
		shots += 1
		if CFG.ShotBudget and shots >= budget then
			break
		end
		if tick() - t0 > 12 then
			break
		end
	end
	if model and not fishAlive(model, hum) then
		combatStatKill()
		store.killLock = nil
	end
	if setting and oldLock ~= nil then
		setting.MouseLock = oldLock
	end
end

local function pierceOthers(fire, skipModel)
	if not fire or CFG.Pierce == false then
		return
	end
	local others = collectFish(CFG.AuraRange, CFG.KillOthers or CFG.AutoSteal)
	local n = 0
	local cap = CFG.SmartPierce and (tonumber(CFG.PierceMax) or 3) or 8
	local minHp = tonumber(CFG.PierceMinHp) or 0
	for _, f in ipairs(others) do
		if n >= cap then
			break
		end
		if f.model and f.model ~= skipModel and fishAlive(f.model, f.hum) then
			local part = f.hit or f.root
			if (f.hp or 0) >= minHp and pierceInCone(part) and hasLos(part) then
				n += 1
				local aim = osskAim(f.model, part)
				if CFG.InstantKill then
					osskKill(fire, part, f.model, f.hum)
				else
					realAtk(fire, aim)
				end
			end
		end
	end
end

local function dumpAtk(fire, part, n, skipRay)
	if not fire or not part then
		return
	end
	local model = part:FindFirstAncestorWhichIsA("Model")
	local head = (model and fishBoxPart(model, "Head")) or (part.Name == "Head" and part) or nil
	local torso = (model and fishTorso(model)) or part
	local aim = torso
	if head and head.Size.Magnitude >= 12 then
		aim = head
	end
	if not skipRay then
		local owner = zoneOwnerOf(model or part)
		if owner and owner ~= LocalPlayer.Name and (tonumber(pdata("PirateBrewTime3")) or 0) <= 0 then
			local bag = unwrap(pdata("bag"))
			if typeof(bag) == "table" then
				for i, item in pairs(bag) do
					if typeof(item) == "table" and item.id == 1005 then
						call("DrinkPotion", tonumber(i) or i)
						call("UseItem", tonumber(i) or i, 1005)
						break
					end
				end
			end
		end
	end
	local setting = dm() and dm().data and dm().data.setting
	local oldLock
	if setting then
		oldLock = setting.MouseLock
		setting.MouseLock = true
	end
	local cam = Workspace.CurrentCamera
	local old = cam and cam.CFrame
	if cam and aim then
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aim.Position)
	end
	n = math.clamp(tonumber(n) or 1, 1, 96)
	if not skipRay then
		pcall(function()
			fire:Atk()
		end)
	end
	for _ = 1, n do
		if torso then
			pcall(function()
				fire:Fire("Atk", torso)
			end)
			netAtk(torso)
		end
		if head and head ~= torso then
			pcall(function()
				fire:Fire("Atk", head)
			end)
			netAtk(head)
		end
	end
	if setting and oldLock ~= nil then
		setting.MouseLock = oldLock
	end
	if CFG.SilentAim and cam and old then
		cam.CFrame = old
	end
end

local function instaHit(fire, part, hum, model)
	if not fire or not part then
		return
	end
	model = model or part:FindFirstAncestorWhichIsA("Model")
	pcall(function()
		fire:Enter()
	end)
	if CFG.InstantKill then
		osskKill(fire, part, model, hum)
	else
		local torso = model and fishTorso(model) or part
		dumpAtk(fire, part, 1)
	end
	if CFG.Pierce ~= false then
		pierceOthers(fire, model)
	end
	pcall(function()
		fire:Exit()
	end)
end

local function lockedFish(fishes)
	return pickTarget(fishes)
end

local function clearEspExtras()
	for _, d in pairs(store.espLines or {}) do
		pcall(function()
			d:Remove()
		end)
	end
	store.espLines = {}
	if store.espFov then
		pcall(function()
			store.espFov:Remove()
		end)
		store.espFov = nil
	end
	if store.espBrew then
		pcall(function()
			store.espBrew:Remove()
		end)
		store.espBrew = nil
	end
end

local function clearEsp()
	local pool = store.espDraw
	if typeof(pool) ~= "table" then
		clearEspExtras()
		return
	end
	for _, d in pairs(pool) do
		pcall(function()
			d:Remove()
		end)
	end
	store.espDraw = {}
	clearEspExtras()
end

STATE.onCleanup(clearEsp)

local function espTick()
	local anyEsp = CFG.EspPrice or CFG.EspHp or CFG.EspOwner
	if not anyEsp then
		clearEsp()
		return
	end
	if typeof(Drawing) ~= "table" or typeof(Drawing.new) ~= "function" then
		return
	end
	store.espDraw = store.espDraw or {}
	store.espLines = store.espLines or {}
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local seen = {}
	local fishes = collectFish(math.max(CFG.AuraRange or 400, 800), true)
	local target
	if store.killLock then
		for _, f in ipairs(fishes) do
			if f.model == store.killLock then
				target = f
				break
			end
		end
	end
	target = target or fishes[1]
	local lockModel = target and target.model
	if CFG.EspFovCircle then
		if not store.espFov then
			store.espFov = Drawing.new("Circle")
			store.espFov.Thickness = 1
			store.espFov.Filled = false
			store.espFov.NumSides = 48
		end
		local center = cam.ViewportSize / 2
		store.espFov.Visible = true
		store.espFov.Position = center
		store.espFov.Radius = CFG.SilentFov or 140
		store.espFov.Color = Color3.fromRGB(80, 200, 255)
	elseif store.espFov then
		store.espFov.Visible = false
	end
	if CFG.EspBrewTimer then
		if not store.espBrew then
			store.espBrew = Drawing.new("Text")
			store.espBrew.Size = 15
			store.espBrew.Center = false
			store.espBrew.Outline = true
			store.espBrew.OutlineColor = Color3.new(0, 0, 0)
		end
		local brew = tonumber(pdata("PirateBrewTime3")) or 0
		store.espBrew.Visible = true
		store.espBrew.Position = Vector2.new(12, 48)
		store.espBrew.Text = brew > 0
			and string.format("Brew %ds", math.ceil(brew))
			or "Brew off"
		store.espBrew.Color = brew > 0
			and Color3.fromRGB(120, 255, 160)
			or Color3.fromRGB(180, 180, 180)
	elseif store.espBrew then
		store.espBrew.Visible = false
	end
	local _, _, hrp = charHum()
	for _, f in ipairs(fishes) do
		local m = f.model
		local part = f.root or f.hit
		if m and m.Parent and part then
			seen[m] = true
			if CFG.EspPrice or CFG.EspHp or CFG.EspOwner then
				local d = store.espDraw[m]
				if not d then
					d = Drawing.new("Text")
					d.Center = true
					d.Outline = true
					d.OutlineColor = Color3.new(0, 0, 0)
					store.espDraw[m] = d
				end
				local v, on = cam:WorldToViewportPoint(part.Position + Vector3.new(0, 2.4, 0))
				if on and v.Z > 0 then
					local top = lockModel == m
					local lines = {}
					if CFG.EspPrice then
						table.insert(lines, fmtMoney(f.price))
					end
					if CFG.EspHp then
						table.insert(
							lines,
							string.format("%d/%d", math.floor(f.hp or 0), math.floor(f.maxHp or f.hp or 0))
						)
					end
					if CFG.EspOwner and f.owner and f.owner ~= LocalPlayer.Name then
						table.insert(lines, f.owner)
					end
					d.Visible = true
					d.Position = Vector2.new(v.X, v.Y)
					d.Text = string.format("%s\n%s", m.Name, table.concat(lines, " · "))
					d.Size = top and 17 or 14
					d.Color = top and Color3.fromRGB(255, 210, 40) or Color3.fromRGB(190, 225, 255)
				else
					d.Visible = false
				end
			end
		end
	end
	if CFG.EspLockLine and lockModel and hrp then
		local part = target.root or target.hit
		local lid = "lock"
		local line = store.espLines[lid]
		if not line then
			line = Drawing.new("Line")
			line.Thickness = 2
			store.espLines[lid] = line
		end
		if part then
			local a, onA = cam:WorldToViewportPoint(hrp.Position)
			local b, onB = cam:WorldToViewportPoint(part.Position)
			line.Visible = onA and onB and a.Z > 0 and b.Z > 0
			if line.Visible then
				line.From = Vector2.new(a.X, a.Y)
				line.To = Vector2.new(b.X, b.Y)
				line.Color = Color3.fromRGB(255, 210, 40)
			end
		else
			line.Visible = false
		end
	else
		local line = store.espLines and store.espLines.lock
		if line then
			line.Visible = false
		end
	end
	for m, d in pairs(store.espDraw) do
		if not seen[m] then
			pcall(function()
				d:Remove()
			end)
			store.espDraw[m] = nil
		end
	end
end

local function hitOne(fire, f)
	if not fire or not f or not fishAlive(f.model, f.hum) then
		return 0
	end
	if store.osskBusy then
		return 0
	end
	store.osskBusy = true
	task.spawn(function()
		local ok, err = pcall(instaHit, fire, f.hit or f.root, f.hum, f.model)
		store.osskBusy = false
		if not ok then
			warn("[reeled] ossk", err)
		end
	end)
	return 1
end

local function closestFishPart()
	local f = lockedFish(collectFish(CFG.AuraRange, CFG.KillOthers or CFG.AutoSteal))
	return f and (f.hit or f.root)
end

local function waterCf()
	local _, _, hrp = charHum()
	if not hrp then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local origin = hrp.Position + Vector3.new(0, 8, 0)
	local dirs = {
		hrp.CFrame.LookVector * 50 + Vector3.new(0, -35, 0),
		hrp.CFrame.LookVector * 25 + Vector3.new(0, -50, 0),
		Vector3.new(0, -80, 0),
	}
	for _, dir in ipairs(dirs) do
		local hit = Workspace:Raycast(origin, dir, params)
		if hit and hit.Material == Enum.Material.Water then
			return CFrame.new(hit.Position + Vector3.new(0, 0.4, 0))
		end
	end
end

local function ensureRod()
	local idx = findSlot("Rod")
	if not idx then
		return nil
	end
	equipSlot(idx)
	local t0 = tick()
	while STATE.alive() and tick() - t0 < 1.6 and not getSkill("Fish") do
		task.wait(0.05)
	end
	return getSkill("Fish")
end

local function ensureGun()
	local idx, item
	if CFG.AutoBestGun or CFG.AutoGunMode == "Best" then
		idx, item = bestGunSlot()
	end
	if not idx then
		idx, item = findSlot("Weapon", CFG.SelectedGun, true)
	end
	if not idx then
		idx, item = findSlot("Weapon", nil, true)
	end
	if not idx then
		idx, item = findSlot("Weapon")
	end
	if not idx then
		return nil
	end
	if item and (tonumber(item.bullet) or 0) <= 0 then
		call("RefillBullet", item.id)
	end
	equipSlot(idx)
	local t0 = tick()
	while STATE.alive() and tick() - t0 < 1.6 and not getSkill("GunFire") do
		task.wait(0.05)
	end
	local fire = getSkill("GunFire")
	if fire then
		instantReload(fire)
	end
	return getSkill("GunFire")
end

local function silentAimTick()
	if not CFG.SilentAim then
		return
	end
	local fishing = getSkill("Fish")
	if fishing and fishing.state and fishing.state ~= 1 then
		return
	end
	local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	if not holding then
		return
	end
	local fishes = collectFish(CFG.AuraRange, CFG.KillOthers or CFG.AutoSteal)
	local f = lockedFish(fishes)
	local part = f and (f.hit or f.root)
	if part and not inFov(part) then
		return
	end
	local fire = getSkill("GunFire") or ensureGun()
	if not fire then
		return
	end
	hitOne(fire, f)
end

local function triggerBotTick()
	if not CFG.TriggerBot or store.osskBusy then
		return
	end
	local fishing = getSkill("Fish")
	if fishing and fishing.state and fishing.state ~= 1 then
		return
	end
	local fishes = collectFish(CFG.AuraRange, CFG.KillOthers or CFG.AutoSteal)
	for _, f in ipairs(fishes) do
		local part = f.hit or f.root
		if part and inFov(part) and hasLos(part) and fishPassesFilter(f) then
			local fire = getSkill("GunFire") or ensureGun()
			if fire then
				hitOne(fire, f)
			end
			return
		end
	end
end

local function shootFish()
	local fishes = collectFish(CFG.AuraRange, CFG.KillOthers or CFG.AutoSteal)
	if #fishes == 0 then
		fishes = fishInZone(ownZone())
	end
	if #fishes == 0 then
		return 0
	end
	local fire = ensureGun()
	if not fire then
		notify("Gun", "no loaded gun")
		return 0
	end
	return hitOne(fire, lockedFish(fishes))
end

local function killAuraTick()
	if not CFG.KillAura then
		return
	end
	local fishing = getSkill("Fish")
	if fishing and fishing.state and fishing.state ~= 1 then
		return
	end
	local fishes = collectFish(CFG.AuraRange, CFG.KillOthers or CFG.AutoSteal)
	if #fishes == 0 then
		return
	end
	local fire = getSkill("GunFire") or ensureGun()
	if not fire then
		return
	end
	hitOne(fire, lockedFish(fishes))
end

local function brewActive()
	return (tonumber(pdata("PirateBrewTime3")) or 0) > 0
end

local function drinkBrew()
	if brewActive() then
		return true
	end
	local bag = unwrap(pdata("bag"))
	if typeof(bag) ~= "table" then
		return false
	end
	for i, item in pairs(bag) do
		if typeof(item) == "table" and item.id == 1005 then
			call("DrinkPotion", tonumber(i) or i)
			call("UseItem", tonumber(i) or i, 1005)
			return true
		end
	end
	call("DrinkPotion", CFG.BagSlot)
	return brewActive()
end

local function goHotspot()
	local world = tonumber(pdata("world")) or CFG.SelectedWorld or 2001
	local marker = findE(tostring(world))
	if marker then
		tpTo(marker)
		task.wait(0.15)
	end
	local cf = waterCf()
	if not cf then
		return false
	end
	local _, _, hrp = charHum()
	if hrp then
		hrp.CFrame = cf + Vector3.new(0, 4, 0)
		return true
	end
	return false
end

local function otherZones()
	local out = {}
	local map = Workspace:FindFirstChild("Map")
	local fa = map and map:FindFirstChild("FishArea")
	if not fa then
		return out
	end
	for _, zone in ipairs(fa:GetChildren()) do
		if zone:GetAttribute("Owner") ~= LocalPlayer.Name then
			local fishes = fishInZone(zone)
			if #fishes > 0 then
				table.insert(out, { zone = zone, fishes = fishes })
			end
		end
	end
	return out
end

local function stealOnce()
	if CFG.AutoBrew then
		drinkBrew()
	end
	local packed = otherZones()
	if #packed == 0 then
		return 0
	end
	table.sort(packed, function(a, b)
		local function zoneTop(fishes)
			local top = 0
			for _, f in ipairs(fishes) do
				top = math.max(top, f.price or 0)
			end
			return top
		end
		return zoneTop(a.fishes) > zoneTop(b.fishes)
	end)
	local target = packed[1]
	local fish = pickTarget(target.fishes)
	if not fish then
		return 0
	end
	if CFG.StealTpFish then
		tpNearFish(fish)
	else
		tpTo(target.zone)
	end
	task.wait(0.08)
	local fire = ensureGun()
	if not fire then
		return 0
	end
	return hitOne(fire, fish)
end

local function claimAll()
	for _, name in ipairs({
		"DailyReward",
		"DailyTaskReward",
		"TimeReward",
		"PassReward",
		"UpgradeReward",
		"GroupReward",
	}) do
		call("GetReward", name)
		call("CheckEligible", name)
	end
	call("UpdataMail")
	call("GetMail", 1)
end

local function npcTasks()
	local w = pdata("world") or CFG.SelectedWorld
	call("StartWorldTask", w)
	call("ReciveNpcTask", w)
	call("SubmitNpcTask", w)
end

local function tryUnlock()
	local wdic = unwrap(pdata("worldDic")) or {}
	local order = { 2002, 2000, 2005, 2007, 2003, 2004, 2006 }
	for _, id in ipairs(order) do
		if not (wdic[id] or wdic[tostring(id)]) then
			call("UnLockWorld", id)
			task.wait(0.15)
			call("Teleport", id)
			return id
		end
	end
end

local function upgradeOnce()
	local _, item = findSlot("Weapon", CFG.SelectedGun, true)
	if not item then
		_, item = findSlot("Weapon", nil, true)
	end
	if not item then
		_, item = findSlot("Weapon")
	end
	if item then
		call("UpgradeWeapon", item.id)
		return item.id
	end
end

local function placePot()
	local idx, item = findSlot("CrabTrap")
	if not idx then
		return false
	end
	equipSlot(idx)
	task.wait(0.1)
	local skill = getSkill("PlaceTrap")
	if skill then
		pcall(function()
			skill:Enter()
		end)
		task.wait(0.1)
		pcall(function()
			skill:Exit()
		end)
	end
	call("UseItem", idx, item and item.id or CFG.SelectedTrap)
	return true
end

local function castRod()
	local cf = waterCf()
	if not cf then
		notify("Farm", "face water")
		return false
	end
	local skill = ensureRod()
	if not skill then
		notify("Farm", "no rod")
		return false
	end
	if skill.state ~= 1 then
		skill.castAttemptId = (skill.castAttemptId or 0) + 1
		skill.state = 1
		skill.fishData = nil
		task.wait(0.1)
	end
	local _, _, hrp = charHum()
	if not hrp then
		return false
	end
	pcall(function()
		skill:Enter()
	end)
	task.wait(0.15)
	if skill.state ~= 2 then
		notify("Farm", "throw failed")
		return false
	end
	pcall(function()
		skill:Fire("Throw", hrp.CFrame.LookVector * 80 + Vector3.new(0, 35, 0))
	end)
	pcall(function()
		skill:Exit()
	end)
	if skill.float then
		pcall(function()
			skill.float.CFrame = cf
			skill.float.Anchored = true
		end)
	end
	local ok, res = pcall(function()
		return gm():WaitFish(cf)
	end)
	if not ok or typeof(res) ~= "table" then
		notify("Farm", "no bite")
		return false
	end
	local waitT = tonumber(res.waitTime) or 0
	if waitT > 0 then
		task.wait(waitT)
	end
	pcall(function()
		GG().EventMgr:Triger("StartFishClick", 1)
	end)
	res.times = 1
	skill.fishData = res
	skill.state = 4
	pcall(function()
		skill:Enter()
	end)
	task.wait(0.08)
	call("Fish")
	local t1 = tick()
	while STATE.alive() and tick() - t1 < 4 do
		if #fishInZone(ownZone()) > 0 then
			break
		end
		task.wait(0.1)
	end
	local tIdle = tick()
	while STATE.alive() and skill.state and skill.state ~= 1 and tick() - tIdle < 1.2 do
		task.wait(0.05)
	end
	return #fishInZone(ownZone()) > 0
end

local function farmOnce()
	if CFG.AutoBrew then
		drinkBrew()
	end
	local ok = castRod()
	if ok and (CFG.AutoShoot or CFG.KillAura or CFG.InstantKill) then
		shootFish()
	end
	if CFG.AutoSteal then
		stealOnce()
	end
	if CFG.AutoSell then
		call("SellAllItem")
	end
	if CFG.AutoRefill then
		local _, item = findSlot("Weapon", CFG.SelectedGun)
		call("RefillBullet", item and item.id or CFG.SelectedGun)
	end
	return ok
end

local farmThread
local function startFarm()
	if farmThread then
		return
	end
	farmThread = true
	task.spawn(function()
		while STATE.alive() and CFG.AutoFarm do
			local ok, err = pcall(farmOnce)
			if not ok then
				notify("Farm", tostring(err))
				task.wait(1)
			else
				task.wait(math.max(0.25, CFG.FarmDelay))
			end
		end
		farmThread = nil
	end)
end

local function valueDump()
	local lines = {}
	for _, k in ipairs(VALUE_KEYS) do
		table.insert(lines, k .. " = " .. tostring(pdata(k)))
	end
	local bag = pdata("bag")
	local bagN = 0
	if typeof(bag) == "table" then
		for _ in pairs(bag) do
			bagN += 1
		end
	end
	table.insert(lines, "bag slots ~ " .. tostring(bagN))
	return table.concat(lines, "\n")
end

-- nothing auto-enabled; toggles apply when He turns them on

STATE.connect(RunService.Heartbeat, function()
	if not STATE.alive() then
		return
	end
	pcall(applyGunMods)
	pcall(espTick)
	local auraGap = 0.16
	pcall(function()
		local fire = getSkill("GunFire")
		local r, pr = fireRateVals(fire)
		if r then
			auraGap = math.max(0.16, (r / pr) * (CFG.RapidFire == false and 1.2 or 0.88))
		end
	end)
	if not store.osskBusy and tick() - (store.auraTick or 0) >= auraGap then
		store.auraTick = tick()
		pcall(killAuraTick)
		pcall(silentAimTick)
		pcall(triggerBotTick)
	end
	if tick() - (store.combatUiTick or 0) >= 2 then
		store.combatUiTick = tick()
		if store.combatPara and store.combatPara.SetDesc then
			pcall(function()
				store.combatPara:SetDesc(combatStatsText())
			end)
		end
	end
	if CFG.AutoSteal and tick() - (store.stealTick or 0) >= 0.7 then
		store.stealTick = tick()
		local fishing = getSkill("Fish")
		if not (fishing and fishing.state and fishing.state ~= 1) then
			pcall(stealOnce)
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
	task.wait(0.4)
	if STATE.alive() then
		applyWalk()
		applyZoom()
		hookWaitFish()
	end
end)

STATE.onCleanup(function()
	CFG.AutoFarm = false
	Workspace.Gravity = 196.2
	local _, hum = charHum()
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = 16
	end
	if origWaitFish then
		local m = gm()
		if m then
			pcall(function()
				m.WaitFish = origWaitFish
			end)
		end
	end
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "Reeled Hub",
	Author = "cast · reel · shoot · WindUI",
	Folder = "ReeledHub",
	Icon = "fish",
	NewElements = true,
	Size = UDim2.fromOffset(580, 620),
	HideSearchBar = false,
	OpenButton = {
		Title = "Reeled",
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
pcall(function()
	Window:SetToggleKey(Enum.KeyCode.RightShift)
end)

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")
local Purple = Color3.fromHex("#9B59B6")
local Cyan = Color3.fromHex("#1ABC9C")

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
			Value = CFG[key] == true,
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
		tab:Dropdown({
			Title = title,
			Values = values,
			Value = current,
			Callback = onPick,
		})
		return api
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
	return api
end

local function tab(section, title, icon, color)
	local t = section:Tab({ Title = title, Icon = icon, IconColor = color })
	task.wait()
	return ui(t), t
end

local Hub = Window:Section({ Title = "Hub", Opened = true })

do
	local u, t = tab(Hub, "Farm", "fish", Blue)
	local para = t:Paragraph({
		Title = "keep",
		Desc = "cast+reel real waitTime · single gun GunFire:Atk · richest fish lock",
	})
	u.toggle("AutoFarm", "Auto Farm", function(on)
			if on then
				startFarm()
				notify("Farm", "loop")
			end
		end)
		.toggle("AutoShoot", "Shoot after catch")
		.toggle("AutoSteal", "Auto Steal")
		.toggle("AutoBrew", "Drink Pirates Brew")
		.toggle("AutoSell", "Auto Sell All")
		.toggle("AutoRefill", "Auto Refill")
		.slider("AuraRange", "Range", 50, 800)
		.btn("Cast", function()
			notify("Cast", tostring(castRod()))
		end, "fish")
		.btn("Shoot", function()
			notify("Shoot", tostring(shootFish()))
		end, "crosshair")
		.btn("Equip Rod", function()
			notify("Rod", tostring(equipSlot(findSlot("Rod"))))
		end)
		.btn("Equip Gun", function()
			local idx = findSlot("Weapon", CFG.SelectedGun, true) or findSlot("Weapon", nil, true)
			notify("Gun", tostring(equipSlot(idx) and getSkill("GunFire") ~= nil))
		end)
		.btn("Sell All", function()
			call("SellAllItem")
		end, "coins")
		.btn("Refill", function()
			local _, item = findSlot("Weapon", CFG.SelectedGun)
			call("RefillBullet", item and item.id or CFG.SelectedGun)
		end)
		.btn("Drink Brew", function()
			notify("Brew", tostring(drinkBrew()))
		end)
		.btn("Rejoin", function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	store.homePara = para
end

do
	local u, t = tab(Hub, "Combat", "crosshair", Red)
	local para = t:Paragraph({
		Title = "combat",
		Desc = combatStatsText(),
	})
	store.combatPara = para
	u.head("Presets")
		.btn("Farm preset", function()
			applyCombatPreset("Farm")
		end, "fish")
		.btn("Steal preset", function()
			applyCombatPreset("Steal")
		end, "target")
		.btn("Manual preset", function()
			applyCombatPreset("Manual")
		end, "mouse-pointer")
	u.head("Aura")
		.toggle("KillAura", "Kill Aura")
		.toggle("InstantKill", "One Shot One Kill")
		.toggle("Pierce", "Pierce")
		.toggle("SilentAim", "Silent Aim (hold M1)")
		.toggle("TriggerBot", "Trigger Bot (FOV)")
		.toggle("KillOthers", "Hit other zones")
		.slider("FireRateMult", "Fire Rate x", 1, 2.5, applyGunMods)
		.toggle("RapidFire", "Rapid Fire")
		.toggle("InstantReload", "Instant Reload")
		.toggle("InfBullet", "Inf Mag")
		.toggle("CombatAutoRefill", "Auto Refill in combat")
		.toggle("CombatLos", "Line of sight check")
		.toggle("ShotBudget", "Shot budget (no overkill)")
		.toggle("PreferHeadshot", "Prefer headshot")
	u.head("Target")
		.drop("Target mode", { "Richest", "Closest", "Low HP" }, CFG.TargetMode or "Richest", function(v)
			CFG.TargetMode = v
		end)
		.toggle("StickyLock", "Sticky lock until dead")
		.input("Fish name filter", "FishNameFilter", "e.g. Shark")
	u.head("Gun")
		.toggle("AutoBestGun", "Auto best gun (bag atk)")
		.drop("Manual gun", bagGunOptions(), "Best (auto)", function(v)
			local id = parseGunPick(v)
			if id then
				CFG.SelectedGun = id
				CFG.AutoBestGun = false
				CFG.AutoGunMode = "Manual"
			else
				CFG.AutoBestGun = true
				CFG.AutoGunMode = "Best"
			end
		end)
	u.head("ESP")
		.toggle("EspPrice", "ESP Price")
		.toggle("EspHp", "ESP HP")
		.toggle("EspOwner", "ESP Zone owner")
		.toggle("EspLockLine", "Lock tracer line")
		.toggle("EspFovCircle", "FOV circle")
		.toggle("EspBrewTimer", "Brew timer HUD")
		.slider("SilentFov", "FOV radius", 40, 320)
	u.head("Pierce / Steal")
		.toggle("SmartPierce", "Smart pierce")
		.slider("PierceMax", "Pierce max targets", 1, 8)
		.slider("PierceMinHp", "Pierce min HP", 0, 5000)
		.toggle("PierceCone", "Pierce cone only")
		.toggle("StealTpFish", "TP to fish (steal)")
		.btn("Shoot now", function()
			notify("Shoot", tostring(shootFish()))
		end, "crosshair")
		.btn("Equip best gun", function()
			local idx = bestGunSlot()
			notify("Gun", tostring(equipSlot(idx) and getSkill("GunFire") ~= nil))
		end)
		.btn("Reset stats", function()
			store.combatStats = { kills = 0, shots = 0, t0 = tick() }
			if para.SetDesc then
				para:SetDesc(combatStatsText())
			end
		end)
end

do
	local u, t = tab(Hub, "Server", "server", Yellow)
	local para = t:Paragraph({
		Title = "server-eaten names",
		Desc = "unique remotes: " .. tostring(#NET_FIRE + #NET_INVOKE + #PLAYER_REP + #SKILL_FIRE + #OTHER_REMOTE) .. "  (not 300 — Reeled only has these. Item ids expand BuyItem.)",
	})
	u.btn("Copy remote list", function()
			local txt = netCatalogText()
			if typeof(setclipboard) == "function" then
				setclipboard(txt)
			end
			notify("Server", tostring(#NET_FIRE) .. " FireServer names copied")
		end, "clipboard")
		.btn("Scan ItemData ids", function()
			local hits = scanItemIds()
			store.itemHits = hits
			local lines = { "ItemData " .. tostring(#hits) }
			for i, h in ipairs(hits) do
				if i <= 40 then
					table.insert(lines, tostring(h.id) .. " " .. h.type .. " " .. h.name)
				end
			end
			if para and para.SetDesc then
				para:SetDesc(table.concat(lines, "\n"))
			end
			if typeof(setclipboard) == "function" then
				local all = {}
				for _, h in ipairs(hits) do
					table.insert(all, string.format("BuyItem %d %s %s", h.id, h.type, h.name))
				end
				setclipboard(table.concat(all, "\n"))
			end
			notify("Scan", tostring(#hits) .. " ItemData ids")
		end)
		.btn("Claim rewards", function()
			for _, name in ipairs(REWARD_TYPES) do
				call("GetReward", name)
			end
			notify("Claim", "GetReward x" .. tostring(#REWARD_TYPES))
		end, "gift")
		.btn("Skip Tutorial", function()
			fire("SkipTutorial")
		end)
		.btn("SellAllItem", function()
			call("SellAllItem")
		end)
		.btn("Fish", function()
			call("Fish")
		end)
end


do
	if typeof(getgenv) == "function" and typeof(queue_on_teleport) == "function" then
		local genv = getgenv()
		if not genv.REELED_HUB_QOT then
			genv.REELED_HUB_QOT = true
			pcall(function()
				queue_on_teleport([[
					task.spawn(function()
						local paths = {
							"reeled_hub.lua",
							"MCP/reeled_hub.lua",
						}
						for _, p in ipairs(paths) do
							if isfile and isfile(p) then
								local fn, err = loadstring(readfile(p), "@reeled_hub")
								if fn then
									fn()
									return
								end
								warn("[ReeledHub] qot compile: " .. tostring(err))
							end
						end
					end)
				]])
			end)
		end
	end
end

print("[ReeledHub] WindUI loaded — RightShift toggle")

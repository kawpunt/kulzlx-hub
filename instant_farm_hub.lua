--[[
  Instant Farm Hub — place 122951224417794
  live-reload label: instant_farm_hub

  Server remotes used (all real, game Network API):
    set_combat_auto / set_combat_auto_action / combat_set_speed
    set_combat_action (Skill / Item)
    RollRequest.Send(roll_aura / toggle_auto_roll / toggle_quick_roll / resolve_unresolved_aura)
    claim_all_achievements / claim_all_battlepass / gift_claim_all / claim_rain_drop

  Instant Kill = VeryFast combat + auto action spam + strongest skill / LargeDamagePotion
  Instant Roll = roll_aura via RollRequest (requestId handled by game module)
  Instant Farm / Auto Farm = roll + combat + claim loops together
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

pcall(function()
	local g = typeof(getgenv) == "function" and getgenv() or _G
	if g.__IFH_CLEAN then
		pcall(g.__IFH_CLEAN)
	end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local NetFolder = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("Network")
local Network = require(NetFolder)
local Enums = require(ReplicatedStorage:WaitForChild("Enums"))
local RollRequest = require(ReplicatedStorage.Client.UI.Screens.HUDUI.Spin.RollRequest)

local function fire(name, ...)
	local r = NetFolder:FindFirstChild(name)
	if not r then
		return false
	end
	local args = table.pack(...)
	return pcall(function()
		r:FireServer(table.unpack(args, 1, args.n))
	end)
end

local function rollSend(eventName, ...)
	local extra = table.pack(...)
	return pcall(function()
		RollRequest.Send(eventName, nil, function() end, table.unpack(extra, 1, extra.n))
	end)
end

local CFG = {
	AutoFarm = false,
	InstantKill = false,
	InstantRoll = false,
	InstantFarm = false,
	AutoResolve = true,
	CombatSpeed = "VeryFast",
}

local last = {
	turn = 0,
	roll = 0,
	claim = 0,
	kill = 0,
	status = "idle",
}

local function setStatus(t)
	last.status = t
end

local function getCombatSession()
	local ok, mod = pcall(function()
		return require(ReplicatedStorage.Client.Combat.InCombat.CombatSession)
	end)
	if ok then
		return mod
	end
	return nil
end

local function getLocalFighter(payload)
	if not payload or type(payload.fighters) ~= "table" then
		return nil
	end
	local uid = tostring(LocalPlayer.UserId)
	for _, f in ipairs(payload.fighters) do
		if tostring(f.id) == uid then
			return f
		end
	end
	return nil
end

local function pickBestSkill(fighter)
	if not fighter then
		return nil, nil
	end
	local auraName = fighter.equippedAura or fighter.auraName or fighter.aura
	local skills = fighter.skills or fighter.auraSkills or fighter.moves
	if type(skills) ~= "table" then
		-- payload shapes vary; try nested aura table
		local aura = fighter.auraData or fighter.currentAura
		if type(aura) == "table" then
			auraName = auraName or aura.name or aura.id
			skills = aura.skills or aura.moves
		end
	end
	if type(skills) ~= "table" then
		return auraName, nil
	end
	local bestId, bestScore = nil, -1
	for _, sk in pairs(skills) do
		if type(sk) == "table" then
			local id = sk.id or sk.skillId or sk.name
			local score = tonumber(sk.power or sk.damage or sk.basePower or sk.pp or 0) or 0
			local pp = tonumber(sk.pp or sk.skillPP or 1) or 1
			if id and pp > 0 and score >= bestScore then
				bestScore = score
				bestId = id
			end
		end
	end
	return auraName, bestId
end

local function enableCombatCore(on)
	fire("set_combat_auto", on == true)
	if on then
		fire("combat_set_speed", CFG.CombatSpeed)
	end
end

local function tryInstantKill()
	-- 1) force server auto turn (real server pick)
	fire("set_combat_auto_action")
	-- 2) push LargeDamagePotion if inventory allows it
	fire("set_combat_action", Enums.CombatActionType.Item, { itemName = "LargeDamagePotion" })
	-- 3) fire strongest skill from live CombatSession payload
	local session = getCombatSession()
	if session and session.GetPayload then
		local payload = session.GetPayload()
		local fighter = getLocalFighter(payload)
		local auraName, skillId = pickBestSkill(fighter)
		if auraName and skillId then
			fire("set_combat_action", Enums.CombatActionType.Skill, {
				auraName = auraName,
				skillId = skillId,
			})
			setStatus("kill skill " .. tostring(skillId))
			return
		end
	end
	setStatus("kill auto-action")
end

local function tryInstantRoll()
	rollSend("roll_aura")
	if CFG.AutoResolve then
		rollSend("resolve_unresolved_aura", Enums.UnresolvedAuraAction.Equip)
		rollSend("resolve_unresolved_aura", Enums.UnresolvedAuraAction.ReplaceLowest)
	end
	setStatus("rolled")
end

local function claimAll()
	fire("claim_all_achievements")
	fire("claim_all_battlepass")
	fire("gift_claim_all")
	fire("claim_rain_drop")
end

local function applyInstantFarmBundle(on)
	-- full farm stack: auto roll + quick roll + auto combat + very fast
	rollSend("toggle_auto_roll")
	rollSend("toggle_quick_roll")
	enableCombatCore(on)
end

---------------------------------------------------------------
-- UI
---------------------------------------------------------------
local Window = WindUI:CreateWindow({
	Title = "Instant Farm Hub",
	Icon = "swords",
	Author = "server remotes only",
	Folder = "InstantFarmHub",
	Size = UDim2.fromOffset(520, 420),
	Theme = "Dark",
	ToggleKey = Enum.KeyCode.RightShift,
})

local Farm = Window:Tab({ Title = "Farm", Icon = "bot" })
Farm:Paragraph({
	Title = "Real remotes",
	Desc = "Auto Farm / Instant Farm / Instant Roll / Instant Kill all FireServer the game Network events. No fake cash UI.",
})

Farm:Toggle({
	Title = "Auto Farm",
	Desc = "Auto combat + auto turns + claim loop + VeryFast",
	Default = false,
	Callback = function(v)
		CFG.AutoFarm = v
		enableCombatCore(v)
		if v then
			rollSend("toggle_auto_roll")
			setStatus("auto farm on")
		else
			setStatus("auto farm off")
		end
		WindUI:Notify({ Title = "Auto Farm", Content = v and "ON" or "OFF", Duration = 2 })
	end,
})

Farm:Toggle({
	Title = "Instant Farm",
	Desc = "Auto+Quick roll + combat auto + VeryFast spam",
	Default = false,
	Callback = function(v)
		CFG.InstantFarm = v
		applyInstantFarmBundle(v)
		setStatus(v and "instant farm on" or "instant farm off")
		WindUI:Notify({ Title = "Instant Farm", Content = v and "ON" or "OFF", Duration = 2 })
	end,
})

Farm:Toggle({
	Title = "Instant Roll",
	Desc = "Spam roll_aura + auto equip unresolved",
	Default = false,
	Callback = function(v)
		CFG.InstantRoll = v
		if v then
			rollSend("toggle_quick_roll")
			tryInstantRoll()
		end
		WindUI:Notify({ Title = "Instant Roll", Content = v and "ON" or "OFF", Duration = 2 })
	end,
})

Farm:Toggle({
	Title = "Instant Kill",
	Desc = "In-combat: auto action + best skill + LargeDamagePotion",
	Default = false,
	Callback = function(v)
		CFG.InstantKill = v
		enableCombatCore(v)
		if v then
			tryInstantKill()
		end
		WindUI:Notify({ Title = "Instant Kill", Content = v and "ON" or "OFF", Duration = 2 })
	end,
})

Farm:Toggle({
	Title = "Auto Equip rolled auras",
	Default = true,
	Callback = function(v)
		CFG.AutoResolve = v
	end,
})

local Speed = Window:Tab({ Title = "Speed / Claim", Icon = "gauge" })
Speed:Button({
	Title = "Combat VeryFast",
	Callback = function()
		CFG.CombatSpeed = "VeryFast"
		fire("combat_set_speed", "VeryFast")
	end,
})
Speed:Button({
	Title = "Combat Fast",
	Callback = function()
		CFG.CombatSpeed = "Fast"
		fire("combat_set_speed", "Fast")
	end,
})
Speed:Button({
	Title = "Roll once now",
	Callback = function()
		tryInstantRoll()
	end,
})
Speed:Button({
	Title = "Kill pulse now",
	Callback = function()
		tryInstantKill()
	end,
})
Speed:Button({
	Title = "Claim all now",
	Callback = function()
		claimAll()
		WindUI:Notify({ Title = "Claim", Content = "sent", Duration = 2 })
	end,
})

local Info = Window:Tab({ Title = "Info", Icon = "info" })
Info:Paragraph({
	Title = "Status",
	Desc = "RightShift toggles UI. Instant Kill only works while you are in a combat Decision turn.",
})

---------------------------------------------------------------
-- loops
---------------------------------------------------------------
task.spawn(function()
	local g = typeof(getgenv) == "function" and getgenv() or _G
	while not g.__IFH_DEAD do
		task.wait(0.25)
		local now = os.clock()

		if CFG.InstantKill and now - last.kill >= 0.35 then
			last.kill = now
			tryInstantKill()
		elseif CFG.AutoFarm and now - last.turn >= 1.2 then
			last.turn = now
			fire("set_combat_auto_action")
			fire("combat_set_speed", CFG.CombatSpeed)
		end

		if (CFG.InstantFarm or CFG.InstantRoll) and now - last.roll >= 0.9 then
			last.roll = now
			tryInstantRoll()
		end

		if (CFG.AutoFarm or CFG.InstantFarm) and now - last.claim >= 45 then
			last.claim = now
			claimAll()
			setStatus("claimed")
		end
	end
end)

WindUI:Notify({
	Title = "Instant Farm Hub",
	Content = "Auto Farm / Instant Kill / Instant Roll / Instant Farm ready",
	Duration = 4,
})

do
	local g = typeof(getgenv) == "function" and getgenv() or _G
	g.__IFH_DEAD = false
	g.__IFH_CLEAN = function()
		g.__IFH_DEAD = true
		CFG.AutoFarm = false
		CFG.InstantKill = false
		CFG.InstantRoll = false
		CFG.InstantFarm = false
		pcall(function()
			fire("set_combat_auto", false)
		end)
		pcall(function()
			WindUI:Destroy()
		end)
	end
end

--[[
  Legacy Piece Hub - WindUI
  live-reload label: legacy_piece_hub
  Place 111097829542198 / Universe 9880286438  ([Araya & Rien] Legacy Piece)

  Runtime recon. Auto farm, instant/fast attack, kill aura, all skills (ท่า),
  auto quest, fishing, codes, teleports, ESP.
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

local WindUI = loadWindUI()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

if not STATE.store then
	STATE.store = {
		esp = {},
		remotes = {},
		spy = {},
		mobCache = {},
		npcCache = {},
		lastMobScan = 0,
		lastAttack = 0,
		lastSkill = 0,
		lastQuest = 0,
		lastFish = 0,
		lastCollect = 0,
		lastRecon = 0,
		reconSummary = "recon pending",
		noclipConn = nil,
		flyConn = nil,
		flyBv = nil,
		hitbox = {},
	}
end
local store = STATE.store
store.esp = store.esp or {}
store.remotes = store.remotes or {}
store.spy = store.spy or {}
store.mobCache = store.mobCache or {}
store.hitbox = store.hitbox or {}

local CFG = {
	Silent = true,
	AutoFarm = false,
	AutoQuest = true,
	KillAura = false,
	InstantKill = false,
	FastAttack = true,
	InstantAttack = false,
	BringMobs = false,
	HitboxExpand = false,
	AutoSkills = true,
	SkillZ = true,
	SkillX = true,
	SkillC = true,
	SkillV = true,
	SkillF = true,
	SkillR = false,
	AutoParry = true,
	AutoSmash = true,
	AttackDelay = 0.06,
	SkillDelay = 0.18,
	AuraRange = 80,
	FarmDistance = 6,
	HitboxSize = 18,
	WalkSpeed = 24,
	JumpPower = 50,
	Noclip = false,
	InfJump = false,
	Fly = false,
	FlySpeed = 80,
	AntiStun = true,
	Godmode = false,
	AutoFish = false,
	InstantFish = true,
	AutoCollect = true,
	AutoCodes = false,
	AutoStats = false,
	StatTarget = "Melee",
	EspMobs = false,
	EspPlayers = false,
	EspFruits = false,
	EspChests = false,
	EspNpcs = false,
	SpyRemotes = true,
	Priority = "Quest",
}

local MOB_FOLDERS = { "Mobs", "Enemies", "NPCs", "Monsters", "Alive", "Entities", "NPC", "Enemy", "Characters", "Living", "WorldNPCs", "MobsFolder" }
local ISLAND_FOLDERS = { "Islands", "Map", "World", "Locations", "Areas", "Sea", "Places" }

local ISLANDS = {
	"Starter Island",
	"Fusha Island",
	"Alvida Island",
	"Shells Town",
	"Shimotsuki Island",
	"Haki Island",
	"Orange Town",
	"Baratie",
	"Mink Island",
	"Arlong Park",
	"Legacy Island",
	"Jungle Island",
	"Jungle",
	"Iceland",
	"A City",
}

local CODES = {
	"sorryforbugs16!!",
	"sorryforbugs15!!",
	"sorryforbugs14!!",
	"sorryfordelay6!!",
	"19klikes!!",
	"update1.75!!",
	"sorryfordelay5!!",
	"minislopupdate!!",
	"sorryforbugs13!!",
	"18klikes!!",
	"dontknowwhattotypeforthiscode!!",
	"balancechange1!!",
	"sorryfordelay4!!",
	"update1.5part2!!",
	"sorryforbugs12!!",
	"sorryfordelay3!!",
	"update1.5!!",
	"oceanupdate!!",
	"thanksfor17klikes!!",
	"4mvisits!!",
	"bugfixforupdate1.1!!",
	"sorryfordelayyy2!!",
	"sorryfordelayyy!!",
	"update1.1!!",
	"sorryforbugs11!!",
	"sorryforbugs9!!",
	"thanksfor4kccu!!",
	"fireupdate!!",
	"sorryforbugs10!!",
}

local VK = {
	Z = 0x5A,
	X = 0x58,
	C = 0x43,
	V = 0x56,
	F = 0x46,
	R = 0x52,
	E = 0x45,
}

local REMOTE_KEYS = {
	combat = { "combat", "attack", "damage", "hit", "m1", "punch", "slash", "swing", "fight" },
	skill = { "skill", "ability", "move", "cast", "fruit", "spec", "haki", "smash", "parry" },
	quest = { "quest", "mission", "accept", "claim", "objective" },
	fish = { "fish", "cast", "reel", "catch", "bobber" },
	code = { "code", "redeem", "promo" },
	stat = { "stat", "upgrade", "allocate", "point" },
	tp = { "teleport", "travel", "island", "spawn" },
	prestige = { "prestige" },
	fruit = { "gacha", "roll", "spin", "summon" },
	collect = { "collect", "pickup", "loot", "chest", "drop" },
	shop = { "shop", "buy", "purchase" },
}

local function notify(msg, dur)
	pcall(function()
		WindUI:Notify({
			Title = "Legacy Piece Hub",
			Content = tostring(msg),
			Duration = dur or 3,
		})
	end)
end

local function notifyAuto(msg, dur)
	if CFG.Silent then
		return
	end
	notify(msg, dur)
end

local function lower(s)
	return string.lower(tostring(s or ""))
end

local function containsAny(hay, needles)
	hay = lower(hay)
	for _, n in ipairs(needles) do
		if string.find(hay, n, 1, true) then
			return true
		end
	end
	return false
end

local function hrp()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function partOf(inst)
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function tp(cf)
	local part = hrp()
	if not part or not cf then
		return false
	end
	if typeof(cf) == "CFrame" then
		part.CFrame = cf
	elseif typeof(cf) == "Vector3" then
		part.CFrame = CFrame.new(cf)
	elseif typeof(cf) == "Instance" then
		local p = partOf(cf)
		if not p then
			return false
		end
		part.CFrame = p.CFrame + Vector3.new(0, 4, 0)
	else
		return false
	end
	return true
end

local function firePrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end
	if typeof(fireproximityprompt) == "function" then
		local ok = pcall(fireproximityprompt, prompt)
		if ok then
			return true
		end
	end
	pcall(function()
		prompt:InputHoldBegin()
	end)
	task.wait(math.min(tonumber(prompt.HoldDuration) or 0, 0.2))
	pcall(function()
		prompt:InputHoldEnd()
	end)
	return true
end

local function classifyRemote(name)
	local hits = {}
	for key, words in pairs(REMOTE_KEYS) do
		if containsAny(name, words) then
			table.insert(hits, key)
		end
	end
	return hits
end

local function fireRemote(remote, ...)
	if not remote or not remote.Parent then
		return false
	end
	local args = { ... }
	local ok = pcall(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer(table.unpack(args))
		else
			remote:FireServer(table.unpack(args))
		end
	end)
	return ok
end

local function fireRemoteGroup(kind, ...)
	local list = store.remotes[kind]
	if type(list) ~= "table" then
		return 0
	end
	local n = 0
	for _, remote in ipairs(list) do
		if remote and remote.Parent and fireRemote(remote, ...) then
			n += 1
		end
	end
	return n
end

local function considerRemote(inst, buckets)
	if not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")) then
		return
	end
	table.insert(buckets.all, inst)
	local kinds = classifyRemote(inst.Name)
	if #kinds == 0 then
		kinds = classifyRemote(inst.Parent and inst.Parent.Name)
	end
	for _, kind in ipairs(kinds) do
		table.insert(buckets[kind], inst)
	end
end

local function scanRemotes()
	local buckets = {}
	for key in pairs(REMOTE_KEYS) do
		buckets[key] = {}
	end
	buckets.all = {}

	local function walk(root, depth)
		if not root then
			return
		end
		for _, inst in ipairs(root:GetChildren()) do
			considerRemote(inst, buckets)
			if depth < 6 then
				walk(inst, depth + 1)
			end
		end
	end

	walk(ReplicatedStorage, 0)
	local char = LocalPlayer.Character
	if char then
		walk(char, 0)
	end
	walk(LocalPlayer, 0)

	store.remotes = buckets
	store.lastRecon = os.clock()
	local parts = { ("remotes=%d"):format(#buckets.all) }
	for _, key in ipairs({ "combat", "skill", "quest", "fish", "code", "stat", "tp", "collect" }) do
		table.insert(parts, ("%s=%d"):format(key, #(buckets[key] or {})))
	end
	store.reconSummary = table.concat(parts, " · ")
	return store.reconSummary
end

local function findCombatRemote()
	local char = LocalPlayer.Character
	if char then
		local combat = char:FindFirstChild("Combat") or char:FindFirstChild("combat")
		if combat then
			local folder = combat:FindFirstChild("RemoteFolder") or combat:FindFirstChild("Remotes") or combat
			local ev = folder:FindFirstChild("CombatEvent")
				or folder:FindFirstChild("Combat")
				or folder:FindFirstChildWhichIsA("RemoteEvent")
			if ev then
				return ev
			end
		end
		for _, name in ipairs({ "CombatEvent", "Attack", "M1", "Damage" }) do
			local ev = char:FindFirstChild(name, true)
			if ev and (ev:IsA("RemoteEvent") or ev:IsA("RemoteFunction")) then
				return ev
			end
		end
	end
	local list = store.remotes.combat
	if list and list[1] then
		return list[1]
	end
	return nil
end

local function logSpy(remote, method, args)
	if not CFG.SpyRemotes or not remote then
		return
	end
	local key = remote:GetFullName()
	store.spy[key] = {
		name = remote.Name,
		method = method,
		argc = #args,
		t = os.clock(),
	}
	local kinds = classifyRemote(remote.Name)
	for _, kind in ipairs(kinds) do
		store.remotes[kind] = store.remotes[kind] or {}
		local found = false
		for _, r in ipairs(store.remotes[kind]) do
			if r == remote then
				found = true
				break
			end
		end
		if not found then
			table.insert(store.remotes[kind], remote)
		end
	end
end

if typeof(STATE.namecallHook) == "function" then
	STATE.namecallHook("FireServer", function(self, method, ...)
		logSpy(self, method, { ... })
	end)
	STATE.namecallHook("InvokeServer", function(self, method, ...)
		logSpy(self, method, { ... })
	end)
end

local function isPlayerChar(model)
	return Players:GetPlayerFromCharacter(model) ~= nil
end

local function considerMob(model, out)
	if not model or not model:IsA("Model") then
		return
	end
	if model == LocalPlayer.Character or isPlayerChar(model) then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if hum and root and hum.Health > 0 then
		table.insert(out, { model = model, hum = hum, root = root, name = model.Name })
	end
end

local function refreshMobs(force)
	local now = os.clock()
	if not force and now - store.lastMobScan < 0.45 then
		return store.mobCache
	end
	store.lastMobScan = now
	local out = {}
	for _, name in ipairs(MOB_FOLDERS) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				considerMob(child, out)
				if child:IsA("Folder") or (child:IsA("Model") and not child:FindFirstChildOfClass("Humanoid")) then
					for _, g in ipairs(child:GetChildren()) do
						considerMob(g, out)
					end
				end
			end
		end
	end
	for _, tag in ipairs({ "Mob", "Enemy", "NPC", "Monster", "Bandit", "Boss" }) do
		pcall(function()
			for _, inst in ipairs(CollectionService:GetTagged(tag)) do
				considerMob(inst, out)
			end
		end)
	end
	if #out == 0 then
		for _, child in ipairs(Workspace:GetChildren()) do
			considerMob(child, out)
			if child:IsA("Folder") then
				for _, g in ipairs(child:GetChildren()) do
					considerMob(g, out)
				end
			end
		end
	end
	store.mobCache = out
	return out
end

local function questText()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return ""
	end
	local chunks = {}
	local n = 0
	for _, gui in ipairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled then
			for _, inst in ipairs(gui:GetChildren()) do
				if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
					local t = inst.Text
					if type(t) == "string" and #t > 4 and #t < 80 then
						if containsAny(t, { "defeat", "kill", "quest", "bandit", "collect" }) then
							table.insert(chunks, t)
							n += 1
							if n >= 8 then
								return table.concat(chunks, " ")
							end
						end
					end
				end
				for _, nested in ipairs(inst:GetChildren()) do
					if nested:IsA("TextLabel") or nested:IsA("TextButton") then
						local t = nested.Text
						if type(t) == "string" and containsAny(t, { "defeat", "kill", "quest", "bandit" }) then
							table.insert(chunks, t)
							n += 1
							if n >= 8 then
								return table.concat(chunks, " ")
							end
						end
					end
				end
			end
		end
	end
	return table.concat(chunks, " ")
end

local function pickMob()
	local me = hrp()
	if not me then
		return nil
	end
	local mobs = refreshMobs()
	if #mobs == 0 then
		return nil
	end
	local q = lower(questText())
	local best, bestScore = nil, -1e9
	for _, mob in ipairs(mobs) do
		local dist = (mob.root.Position - me.Position).Magnitude
		if dist <= math.max(CFG.AuraRange, 400) then
			local score = -dist
			if CFG.Priority == "Quest" and q ~= "" and string.find(q, lower(mob.name), 1, true) then
				score += 10000
			elseif CFG.Priority == "LowestHP" then
				score += (1000 - mob.hum.Health)
			elseif CFG.Priority == "Boss" and containsAny(mob.name, { "boss", "captain", "king", "lord" }) then
				score += 5000
			end
			if CFG.InstantKill then
				score += 1
			end
			if score > bestScore then
				bestScore = score
				best = mob
			end
		end
	end
	return best
end

local function clickM1()
	if typeof(mouse1click) == "function" then
		pcall(mouse1click)
	end
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)
	local char = LocalPlayer.Character
	if char then
		local tool = char:FindFirstChildWhichIsA("Tool")
		if tool then
			pcall(function()
				tool:Activate()
			end)
		end
	end
end

local function pressKey(vk, enumKey)
	if typeof(keyclick) == "function" then
		pcall(keyclick, vk)
	elseif typeof(keypress) == "function" then
		pcall(keypress, vk)
		task.delay(0.03, function()
			if typeof(keyrelease) == "function" then
				pcall(keyrelease, vk)
			end
		end)
	end
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, enumKey, false, game)
		VirtualInputManager:SendKeyEvent(false, enumKey, false, game)
	end)
end

local function fireCombat(target)
	local remote = findCombatRemote()
	local model = target and target.model
	if remote then
		fireRemote(remote, model, 1)
		fireRemote(remote, model, 1, true)
		if CFG.InstantKill or CFG.InstantAttack then
			fireRemote(remote, model, 4)
			fireRemote(remote, model, 2)
			fireRemote(remote, "M1")
			fireRemote(remote, { Type = "Attack", Target = model })
		end
	end
	fireRemoteGroup("combat", model)
	fireRemoteGroup("combat", model, 1)
	if CFG.InstantKill then
		fireRemoteGroup("combat", model, 9999)
		fireRemoteGroup("skill", model)
	end
	clickM1()
end

local function useSkills()
	if not CFG.AutoSkills and not CFG.AutoSmash and not CFG.AutoParry then
		return
	end
	local now = os.clock()
	if now - store.lastSkill < CFG.SkillDelay then
		return
	end
	store.lastSkill = now
	if CFG.SkillZ or CFG.AutoSmash then
		pressKey(VK.Z, Enum.KeyCode.Z)
		fireRemoteGroup("skill", "Z")
		fireRemoteGroup("skill", "Smash")
	end
	if CFG.SkillX then
		pressKey(VK.X, Enum.KeyCode.X)
		fireRemoteGroup("skill", "X")
	end
	if CFG.SkillC then
		pressKey(VK.C, Enum.KeyCode.C)
		fireRemoteGroup("skill", "C")
	end
	if CFG.SkillV then
		pressKey(VK.V, Enum.KeyCode.V)
		fireRemoteGroup("skill", "V")
	end
	if CFG.SkillF or CFG.AutoParry then
		pressKey(VK.F, Enum.KeyCode.F)
		fireRemoteGroup("skill", "F")
		fireRemoteGroup("skill", "Parry")
	end
	if CFG.SkillR then
		pressKey(VK.R, Enum.KeyCode.R)
		fireRemoteGroup("skill", "R")
	end
end

local function bringMob(mob)
	if not CFG.BringMobs or not mob or not mob.root then
		return
	end
	local me = hrp()
	if not me then
		return
	end
	pcall(function()
		mob.root.CFrame = me.CFrame * CFrame.new(0, 0, -CFG.FarmDistance)
		mob.root.AssemblyLinearVelocity = Vector3.zero
	end)
end

local function expandHitbox(mob)
	if not CFG.HitboxExpand or not mob or not mob.root then
		return
	end
	local size = CFG.HitboxSize
	for _, p in ipairs(mob.model:GetChildren()) do
		if p:IsA("BasePart") then
			if not store.hitbox[p] then
				store.hitbox[p] = p.Size
			end
			p.Size = Vector3.new(size, size, size)
			p.Transparency = math.max(p.Transparency, 0.7)
			p.CanCollide = false
		end
	end
end

local function restoreHitboxes()
	for p, size in pairs(store.hitbox) do
		pcall(function()
			if p and p.Parent then
				p.Size = size
			end
		end)
		store.hitbox[p] = nil
	end
end

local function attackTarget(mob)
	if not mob then
		return false
	end
	local now = os.clock()
	local delay = CFG.InstantAttack and 0.01 or CFG.AttackDelay
	if now - store.lastAttack < delay then
		if CFG.InstantAttack then
			fireCombat(mob)
		end
		return true
	end
	store.lastAttack = now
	bringMob(mob)
	expandHitbox(mob)
	local me = hrp()
	if me and not CFG.BringMobs then
		local dist = (mob.root.Position - me.Position).Magnitude
		if dist > CFG.FarmDistance + 4 then
			tp(mob.root.CFrame * CFrame.new(0, 2, CFG.FarmDistance))
		end
	elseif me and CFG.BringMobs then
		-- stay put, mobs come to us
	end
	local bursts = (CFG.InstantKill or CFG.InstantAttack or CFG.FastAttack) and 4 or 1
	for _ = 1, bursts do
		fireCombat(mob)
	end
	if CFG.AutoSkills or CFG.AutoSmash or CFG.AutoParry then
		useSkills()
	end
	return true
end

local function farmTick()
	if not (CFG.AutoFarm or CFG.KillAura or CFG.InstantKill) then
		return
	end
	local mob = pickMob()
	if not mob then
		notifyAuto("no mobs in range")
		return
	end
	if CFG.KillAura or CFG.InstantKill then
		local me = hrp()
		if me then
			for _, other in ipairs(refreshMobs()) do
				if (other.root.Position - me.Position).Magnitude <= CFG.AuraRange then
					attackTarget(other)
				end
			end
			return
		end
	end
	attackTarget(mob)
end

local function talkPrompts(needles, radius)
	local me = hrp()
	if not me then
		return 0
	end
	radius = radius or 18
	local n = 0
	local function check(inst)
		if not inst:IsA("ProximityPrompt") or not inst.Enabled then
			return
		end
		local blob = inst.Name .. " " .. tostring(inst.ActionText) .. " " .. tostring(inst.ObjectText)
		if needles and not containsAny(blob, needles) then
			return
		end
		local p = partOf(inst.Parent)
		if p and (p.Position - me.Position).Magnitude <= radius then
			if firePrompt(inst) then
				n += 1
			end
		end
	end
	local char = LocalPlayer.Character
	if char then
		for _, inst in ipairs(char:GetDescendants()) do
			check(inst)
		end
	end
	for _, name in ipairs({ "NPCs", "NPC", "Quests", "Interactables", "Prompts" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, inst in ipairs(folder:GetDescendants()) do
				check(inst)
			end
		end
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") then
			local prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				check(prompt)
			end
		end
	end
	return n
end

local function acceptQuest()
	local now = os.clock()
	if now - store.lastQuest < 1.2 then
		return
	end
	store.lastQuest = now
	fireRemoteGroup("quest")
	fireRemoteGroup("quest", "Accept")
	fireRemoteGroup("quest", "Claim")
	fireRemoteGroup("quest", true)
	talkPrompts({ "quest", "talk", "accept", "mission", "claim" }, 22)
end

local function collectDrops()
	local now = os.clock()
	if now - store.lastCollect < 0.8 then
		return
	end
	store.lastCollect = now
	fireRemoteGroup("collect")
	local me = hrp()
	if not me then
		return
	end
	for _, name in ipairs({ "Drops", "Chests", "Loot", "Pickups", "Items" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, inst in ipairs(folder:GetChildren()) do
				local p = partOf(inst)
				if p and (p.Position - me.Position).Magnitude < 80 then
					if CFG.InstantAttack then
						tp(p.CFrame + Vector3.new(0, 3, 0))
					end
					if typeof(firetouchinterest) == "function" then
						pcall(firetouchinterest, p, me, 1)
						pcall(firetouchinterest, p, me, 0)
					end
					local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						firePrompt(prompt)
					end
				end
			end
		end
	end
end

local function fishTick()
	local now = os.clock()
	local waitFor = CFG.InstantFish and 0.15 or 0.6
	if now - store.lastFish < waitFor then
		return
	end
	store.lastFish = now
	fireRemoteGroup("fish")
	fireRemoteGroup("fish", "Cast")
	fireRemoteGroup("fish", "Catch")
	fireRemoteGroup("fish", "Reel")
	fireRemoteGroup("fish", true)
	talkPrompts({ "fish", "cast", "reel", "catch", "rod" }, 16)
	pressKey(VK.E, Enum.KeyCode.E)
	clickM1()
end

local function redeemCodes()
	local n = 0
	for _, code in ipairs(CODES) do
		n += fireRemoteGroup("code", code)
		n += fireRemoteGroup("code", { Code = code })
		n += fireRemoteGroup("code", "Redeem", code)
	end
	notify(("redeem fired %d times"):format(n), 4)
	return n
end

local function allocStats()
	local target = CFG.StatTarget
	fireRemoteGroup("stat", target)
	fireRemoteGroup("stat", target, 1)
	fireRemoteGroup("stat", { Stat = target, Amount = 1 })
	fireRemoteGroup("stat", "All", target)
end

local function findNamed(root, want)
	want = lower(want)
	if not root then
		return nil
	end
	for _, child in ipairs(root:GetChildren()) do
		if lower(child.Name) == want or string.find(lower(child.Name), want, 1, true) then
			return child
		end
	end
	return nil
end

local function findIsland(name)
	for _, folderName in ipairs(ISLAND_FOLDERS) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			local hit = findNamed(folder, name)
			if hit then
				return hit
			end
		end
	end
	return findNamed(Workspace, name)
end

local function tpIsland(name)
	local inst = findIsland(name)
	local p = partOf(inst)
	if p then
		return tp(p.CFrame + Vector3.new(0, 8, 0))
	end
	fireRemoteGroup("tp", name)
	fireRemoteGroup("tp", { Island = name })
	return false
end

local function applyAntiStun()
	local char = LocalPlayer.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.PlatformStand = false
			hum.Sit = false
			if hum:GetState() == Enum.HumanoidStateType.Physics or hum:GetState() == Enum.HumanoidStateType.Ragdoll then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
	for _, inst in ipairs(char:GetChildren()) do
		if inst:IsA("BodyVelocity") or inst:IsA("BodyAngularVelocity") or inst.Name == "Stun" then
			if inst ~= store.flyBv then
				pcall(function()
					inst:Destroy()
				end)
			end
		end
	end
end

local function applyMovement()
	local hum = humanoid()
	if not hum then
		return
	end
	pcall(function()
		hum.WalkSpeed = CFG.WalkSpeed
		hum.JumpPower = CFG.JumpPower
		hum.UseJumpPower = true
	end)
	if CFG.Godmode then
		pcall(function()
			hum.MaxHealth = 1e9
			hum.Health = hum.MaxHealth
		end)
	end
end

local function setNoclip(on)
	CFG.Noclip = on
	if store.noclipConn then
		pcall(function()
			store.noclipConn:Disconnect()
		end)
		store.noclipConn = nil
	end
	if not on then
		return
	end
	store.noclipConn = RunService.Stepped:Connect(function()
		if not STATE.alive() or not CFG.Noclip then
			return
		end
		local char = LocalPlayer.Character
		if not char then
			return
		end
		for _, p in ipairs(char:GetChildren()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
	end)
	STATE.onCleanup(function()
		if store.noclipConn then
			pcall(function()
				store.noclipConn:Disconnect()
			end)
			store.noclipConn = nil
		end
	end)
end

local function stopFly()
	if store.flyConn then
		pcall(function()
			store.flyConn:Disconnect()
		end)
		store.flyConn = nil
	end
	if store.flyBv then
		pcall(function()
			store.flyBv:Destroy()
		end)
		store.flyBv = nil
	end
end

local function setFly(on)
	CFG.Fly = on
	stopFly()
	if not on then
		return
	end
	local part = hrp()
	if not part then
		return
	end
	local bv = Instance.new("BodyVelocity")
	bv.Name = "LP_Fly"
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity = Vector3.zero
	bv.Parent = part
	store.flyBv = bv
	store.flyConn = RunService.Heartbeat:Connect(function()
		if not STATE.alive() or not CFG.Fly or not bv.Parent then
			return
		end
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			move -= Vector3.new(0, 1, 0)
		end
		if move.Magnitude > 0 then
			bv.Velocity = move.Unit * CFG.FlySpeed
		else
			bv.Velocity = Vector3.zero
		end
	end)
	STATE.onCleanup(stopFly)
end

local function clearEsp()
	for k, bb in pairs(store.esp) do
		pcall(function()
			bb:Destroy()
		end)
		store.esp[k] = nil
	end
end

local function makeBillboard(adornee, text, color)
	local bb = Instance.new("BillboardGui")
	bb.Name = "LP_ESP"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(150, 28)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.Adornee = adornee
	bb.Parent = LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
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
				local p = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if p then
					store.esp["p_" .. plr.UserId] = makeBillboard(p, plr.Name, Color3.fromRGB(255, 200, 80))
				end
			end
		end
	end
	if CFG.EspMobs then
		for i, mob in ipairs(refreshMobs()) do
			if i > 35 then
				break
			end
			store.esp["m_" .. i] = makeBillboard(mob.root, mob.name, Color3.fromRGB(255, 90, 90))
		end
	end
	if CFG.EspFruits then
		local i = 0
		for _, name in ipairs({ "Fruits", "DevilFruits", "Drops" }) do
			local folder = Workspace:FindFirstChild(name)
			if folder then
				for _, inst in ipairs(folder:GetChildren()) do
					if containsAny(inst.Name, { "fruit", "devil" }) or name == "Fruits" then
						local p = partOf(inst)
						if p then
							i += 1
							store.esp["f_" .. i] = makeBillboard(p, inst.Name, Color3.fromRGB(180, 90, 255))
							if i > 20 then
								break
							end
						end
					end
				end
			end
		end
	end
	if CFG.EspChests then
		local i = 0
		for _, name in ipairs({ "Chests", "Drops", "Loot" }) do
			local folder = Workspace:FindFirstChild(name)
			if folder then
				for _, inst in ipairs(folder:GetChildren()) do
					local p = partOf(inst)
					if p then
						i += 1
						store.esp["c_" .. i] = makeBillboard(p, inst.Name, Color3.fromRGB(255, 210, 70))
						if i > 15 then
							break
						end
					end
				end
			end
		end
	end
	if CFG.EspNpcs then
		local folder = Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("NPC")
		if folder then
			local i = 0
			for _, inst in ipairs(folder:GetChildren()) do
				local p = partOf(inst)
				if p then
					i += 1
					store.esp["n_" .. i] = makeBillboard(p, inst.Name, Color3.fromRGB(120, 220, 255))
					if i > 20 then
						break
					end
				end
			end
		end
	end
end

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoFarm or CFG.KillAura or CFG.InstantKill or CFG.FastAttack then
			pcall(farmTick)
		end
		local waitFor = CFG.InstantAttack and 0.02 or math.max(0.03, CFG.AttackDelay)
		task.wait(waitFor)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoQuest or CFG.AutoFarm then
			pcall(acceptQuest)
		end
		if CFG.AutoCollect or CFG.AutoFarm then
			pcall(collectDrops)
		end
		if CFG.AutoStats then
			pcall(allocStats)
		end
		task.wait(0.9)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoFish then
			pcall(fishTick)
		end
		task.wait((CFG.InstantFish and CFG.AutoFish) and 0.2 or 0.7)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AntiStun then
			pcall(applyAntiStun)
		end
		pcall(applyMovement)
		task.wait(0.2)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.EspMobs or CFG.EspPlayers or CFG.EspFruits or CFG.EspChests or CFG.EspNpcs then
			pcall(refreshEsp)
		else
			clearEsp()
		end
		task.wait(1.3)
	end
end)

STATE.connect(UserInputService.JumpRequest, function()
	if CFG.InfJump then
		local hum = humanoid()
		if hum then
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
		end
	end
end)

STATE.connect(LocalPlayer.CharacterAdded, function()
	task.wait(0.45)
	applyMovement()
	if CFG.Noclip then
		setNoclip(true)
	end
	if CFG.Fly then
		setFly(true)
	end
	scanRemotes()
end)

scanRemotes()

STATE.onCleanup(function()
	clearEsp()
	restoreHitboxes()
	stopFly()
	if store.noclipConn then
		pcall(function()
			store.noclipConn:Disconnect()
		end)
		store.noclipConn = nil
	end
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

local Window = WindUI:CreateWindow({
	Title = "Legacy Piece Hub",
	Author = "local WindUI",
	Folder = "LegacyPieceHub",
	Icon = "swords",
	NewElements = true,
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = false,
	OpenButton = {
		Title = "LP Hub",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		OnlyIcon = true,
		Scale = 0.5,
		Color = ColorSequence.new(Color3.fromHex("#FF5A7A"), Color3.fromHex("#FFD12F")),
	},
})
store.window = Window

task.defer(function()
	pcall(function()
		Window:Close()
	end)
end)

Window:Tag({
	Title = "v1",
	Icon = "anchor",
	Color = Color3.fromHex("#1c1c1c"),
	Border = true,
})

local Green = Color3.fromHex("#10C550")
local Blue = Color3.fromHex("#257AF7")
local Yellow = Color3.fromHex("#ECA201")
local Red = Color3.fromHex("#EF4F1D")

local MainSec = Window:Section({ Title = "Main", Opened = true })
local SysSec = Window:Section({ Title = "Systems", Opened = true })

do
	local Tab = MainSec:Tab({ Title = "Home", Icon = "house", IconColor = Green })
	Tab:Paragraph({
		Title = "Legacy Piece Hub",
		Desc = "Silent boot · RightShift / OpenButton · " .. store.reconSummary,
	})
	Tab:Toggle({
		Title = "Silent Mode",
		Desc = "Mute auto notifications",
		Default = CFG.Silent,
		Callback = function(v)
			CFG.Silent = v
		end,
	})
	Tab:Toggle({
		Title = "Remote Spy",
		Desc = "Learn remotes from your own attacks",
		Default = CFG.SpyRemotes,
		Callback = function(v)
			CFG.SpyRemotes = v
		end,
	})
	Tab:Button({
		Title = "Recon Remotes Now",
		Icon = "search",
		Callback = function()
			notify(scanRemotes(), 5)
		end,
	})
	Tab:Button({
		Title = "Dump Spy Log",
		Callback = function()
			local lines = {}
			for path, info in pairs(store.spy) do
				table.insert(lines, ("%s  %s  argc=%s"):format(info.method, path, tostring(info.argc)))
			end
			table.sort(lines)
			local text = #lines > 0 and table.concat(lines, "\n") or store.reconSummary
			pcall(function()
				if writefile then
					writefile("LegacyPieceHub_spy.txt", text)
				end
			end)
			notify(#lines > 0 and ("logged " .. #lines .. " remotes") or "spy empty — attack once", 4)
			print("[LP Hub]\n" .. text)
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Farm", Icon = "swords", IconColor = Red })
	Tab:Toggle({
		Title = "Auto Farm",
		Desc = "Quest + kill nearest / quest mob",
		Default = CFG.AutoFarm,
		Callback = function(v)
			CFG.AutoFarm = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Quest",
		Default = CFG.AutoQuest,
		Callback = function(v)
			CFG.AutoQuest = v
		end,
	})
	Tab:Toggle({
		Title = "Kill Aura",
		Default = CFG.KillAura,
		Callback = function(v)
			CFG.KillAura = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Kill",
		Desc = "Spam combat remotes + skills on aura targets",
		Default = CFG.InstantKill,
		Callback = function(v)
			CFG.InstantKill = v
		end,
	})
	Tab:Toggle({
		Title = "Fast Attack",
		Default = CFG.FastAttack,
		Callback = function(v)
			CFG.FastAttack = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Attack",
		Desc = "Minimum delay M1 + remotes",
		Default = CFG.InstantAttack,
		Callback = function(v)
			CFG.InstantAttack = v
			if v then
				CFG.AttackDelay = 0.02
			end
		end,
	})
	Tab:Toggle({
		Title = "Bring Mobs",
		Default = CFG.BringMobs,
		Callback = function(v)
			CFG.BringMobs = v
		end,
	})
	Tab:Toggle({
		Title = "Hitbox Expand",
		Default = CFG.HitboxExpand,
		Callback = function(v)
			CFG.HitboxExpand = v
			if not v then
				restoreHitboxes()
			end
		end,
	})
	Tab:Toggle({
		Title = "Auto Collect Drops",
		Default = CFG.AutoCollect,
		Callback = function(v)
			CFG.AutoCollect = v
		end,
	})
	Tab:Dropdown({
		Title = "Priority",
		Values = { "Quest", "Nearest", "LowestHP", "Boss" },
		Value = CFG.Priority,
		Callback = function(v)
			CFG.Priority = v
		end,
	})
	Tab:Slider({
		Title = "Attack Delay",
		Value = { Min = 0.01, Max = 0.4, Default = CFG.AttackDelay },
		Step = 0.01,
		Callback = function(v)
			CFG.AttackDelay = v
		end,
	})
	Tab:Slider({
		Title = "Aura Range",
		Value = { Min = 10, Max = 250, Default = CFG.AuraRange },
		Step = 1,
		Callback = function(v)
			CFG.AuraRange = v
		end,
	})
	Tab:Slider({
		Title = "Farm Distance",
		Value = { Min = 2, Max = 20, Default = CFG.FarmDistance },
		Step = 1,
		Callback = function(v)
			CFG.FarmDistance = v
		end,
	})
	Tab:Slider({
		Title = "Hitbox Size",
		Value = { Min = 6, Max = 40, Default = CFG.HitboxSize },
		Step = 1,
		Callback = function(v)
			CFG.HitboxSize = v
		end,
	})
	Tab:Button({
		Title = "Attack Once",
		Icon = "zap",
		Callback = function()
			local mob = pickMob()
			notify(mob and attackTarget(mob) and ("hit " .. mob.name) or "no target")
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Skills", Icon = "sparkles", IconColor = Yellow })
	Tab:Paragraph({
		Title = "ท่า / Moves",
		Desc = "Z Smash · X/C/V fruit/spec · F Parry · R dash. Turns on every key the game actually binds.",
	})
	Tab:Toggle({
		Title = "Auto All Skills",
		Default = CFG.AutoSkills,
		Callback = function(v)
			CFG.AutoSkills = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Smash (Z)",
		Default = CFG.SkillZ,
		Callback = function(v)
			CFG.SkillZ = v
			CFG.AutoSmash = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Skill X",
		Default = CFG.SkillX,
		Callback = function(v)
			CFG.SkillX = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Skill C",
		Default = CFG.SkillC,
		Callback = function(v)
			CFG.SkillC = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Skill V",
		Default = CFG.SkillV,
		Callback = function(v)
			CFG.SkillV = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Parry (F)",
		Default = CFG.SkillF,
		Callback = function(v)
			CFG.SkillF = v
			CFG.AutoParry = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Dash (R)",
		Default = CFG.SkillR,
		Callback = function(v)
			CFG.SkillR = v
		end,
	})
	Tab:Slider({
		Title = "Skill Delay",
		Value = { Min = 0.05, Max = 1, Default = CFG.SkillDelay },
		Step = 0.05,
		Callback = function(v)
			CFG.SkillDelay = v
		end,
	})
	Tab:Button({
		Title = "Fire All Skills Now",
		Callback = function()
			useSkills()
			notify("skills fired")
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Player", Icon = "user", IconColor = Blue })
	Tab:Slider({
		Title = "WalkSpeed",
		Value = { Min = 8, Max = 250, Default = CFG.WalkSpeed },
		Step = 1,
		Callback = function(v)
			CFG.WalkSpeed = v
			applyMovement()
		end,
	})
	Tab:Slider({
		Title = "JumpPower",
		Value = { Min = 0, Max = 250, Default = CFG.JumpPower },
		Step = 1,
		Callback = function(v)
			CFG.JumpPower = v
			applyMovement()
		end,
	})
	Tab:Toggle({
		Title = "Noclip",
		Default = CFG.Noclip,
		Callback = function(v)
			setNoclip(v)
		end,
	})
	Tab:Toggle({
		Title = "Inf Jump",
		Default = CFG.InfJump,
		Callback = function(v)
			CFG.InfJump = v
		end,
	})
	Tab:Toggle({
		Title = "Fly",
		Default = CFG.Fly,
		Callback = function(v)
			setFly(v)
		end,
	})
	Tab:Slider({
		Title = "Fly Speed",
		Value = { Min = 20, Max = 250, Default = CFG.FlySpeed },
		Step = 5,
		Callback = function(v)
			CFG.FlySpeed = v
		end,
	})
	Tab:Toggle({
		Title = "Anti Stun",
		Default = CFG.AntiStun,
		Callback = function(v)
			CFG.AntiStun = v
		end,
	})
	Tab:Toggle({
		Title = "Godmode",
		Desc = "Local health pad; server can still hit you",
		Default = CFG.Godmode,
		Callback = function(v)
			CFG.Godmode = v
		end,
	})
	Tab:Dropdown({
		Title = "Auto Stat",
		Values = { "Melee", "Defense", "Sword", "Fruit", "Gun" },
		Value = CFG.StatTarget,
		Callback = function(v)
			CFG.StatTarget = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Allocate Stats",
		Default = CFG.AutoStats,
		Callback = function(v)
			CFG.AutoStats = v
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Fish", Icon = "fish", IconColor = Blue })
	Tab:Toggle({
		Title = "Auto Fish",
		Default = CFG.AutoFish,
		Callback = function(v)
			CFG.AutoFish = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Catch",
		Default = CFG.InstantFish,
		Callback = function(v)
			CFG.InstantFish = v
		end,
	})
	Tab:Button({
		Title = "Fish Once",
		Callback = function()
			fishTick()
			notify("fish fired")
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Codes", Icon = "gift", IconColor = Yellow })
	Tab:Paragraph({
		Title = "Redeem All",
		Desc = "Fires every listed promo through recon'd code remotes.",
	})
	Tab:Button({
		Title = "Redeem All Codes",
		Icon = "gift",
		Callback = function()
			redeemCodes()
		end,
	})
	Tab:Button({
		Title = "Roll Fruit",
		Callback = function()
			local n = fireRemoteGroup("fruit")
			n += fireRemoteGroup("fruit", "Roll")
			notify("fruit roll calls: " .. n)
		end,
	})
	Tab:Button({
		Title = "Prestige",
		Callback = function()
			local n = fireRemoteGroup("prestige")
			n += fireRemoteGroup("prestige", true)
			notify("prestige calls: " .. n)
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Teleport", Icon = "map-pin", IconColor = Red })
	for _, name in ipairs(ISLANDS) do
		local island = name
		Tab:Button({
			Title = island,
			Callback = function()
				notify(tpIsland(island) and ("warped " .. island) or (island .. " not found — remote fired"))
			end,
		})
	end
end

do
	local Tab = SysSec:Tab({ Title = "Visuals", Icon = "eye", IconColor = Blue })
	Tab:Toggle({
		Title = "Mob ESP",
		Default = CFG.EspMobs,
		Callback = function(v)
			CFG.EspMobs = v
		end,
	})
	Tab:Toggle({
		Title = "Player ESP",
		Default = CFG.EspPlayers,
		Callback = function(v)
			CFG.EspPlayers = v
		end,
	})
	Tab:Toggle({
		Title = "Fruit ESP",
		Default = CFG.EspFruits,
		Callback = function(v)
			CFG.EspFruits = v
		end,
	})
	Tab:Toggle({
		Title = "Chest ESP",
		Default = CFG.EspChests,
		Callback = function(v)
			CFG.EspChests = v
		end,
	})
	Tab:Toggle({
		Title = "NPC ESP",
		Default = CFG.EspNpcs,
		Callback = function(v)
			CFG.EspNpcs = v
		end,
	})
	Tab:Button({
		Title = "Refresh ESP",
		Callback = function()
			refreshEsp()
			notify("esp refreshed")
		end,
	})
end

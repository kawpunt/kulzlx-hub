--[[
  Steal An Egg Hub - WindUI
  live-reload label: steal_egg_hub
  Place 107778070777162 / Universe 10563114921

  Runtime recon of remotes + proximity prompts.
  Instant steal, auto farm, unlock-all claims/upgrades, hatch/place, ESP.
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
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

if not STATE.store then
	STATE.store = {
		esp = {},
		remotes = {},
		spy = {},
		lastSteal = 0,
		lastHatch = 0,
		lastUpgrade = 0,
		lastIndex = 0,
		lastRecon = 0,
		lastStepSend = 0,
		reconSummary = "recon idle",
		noclipConn = nil,
		tween = nil,
	}
end
local store = STATE.store
store.esp = store.esp or {}
store.remotes = store.remotes or {}
store.spy = store.spy or {}

local CFG = {
	Silent = true,
	InstantSteal = true,
	AutoSteal = false,
	AutoFarm = false,
	AutoHatch = false,
	AutoPlace = false,
	AutoTreadmill = false,
	AutoCollectCash = false,
	AutoUpgradeTreadmill = false,
	AutoUpgradeBase = false,
	AutoBuyTrail = false,
	AutoSellEgg = false,
	AutoSellPets = false,
	AutoClaimIndex = false,
	AutoFuse = false,
	StealOthers = false,
	SkipGuarded = false,
	Priority = "Rarest",
	MinRarity = "Common",
	StealDelay = 0.55,
	FarmDelay = 0.8,
	MaxCarryWait = 0.9,
	TweenSpeed = 68,
	MoveMode = "Stepped",
	StepSize = 12,
	InstantStep = false,
	StepRate = 6,
	StepBurst = 1,
	SpeedOverride = false,
	WalkSpeed = 16,
	JumpPower = 50,
	Noclip = false,
	InfJump = false,
	AntiRagdoll = false,
	AntiTrap = false,
	AntiMobHit = false,
	VoidMobs = false,
	MobScanRadius = 48,
	BatAura = false,
	BatRange = 18,
	Godmode = false,
	EspEggs = false,
	EspPets = false,
	EspPlayers = false,
	EspGuardians = false,
	SpyRemotes = false,
}

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Cosmic = 7,
	Secret = 8,
	Eternal = 9,
	Divine = 10,
}

local RARITY_LIST = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }

local MOB_KEYWORDS = {
	"guardian",
	"chicken",
	"swan",
	"scorpion",
	"tiger",
	"yeti",
	"cerberus",
	"hellhound",
	"moby",
	"trex",
	"t-rex",
	"dragon",
	"kitsune",
	"fox",
	"boss",
	"mob",
	"enemy",
	"npc",
	"guard",
}

local MOB_VOID_CF = CFrame.new(0, -12000, 0)

local BIOMES = {
	{ Name = "Forest", Speed = 0 },
	{ Name = "Lake", Speed = 900 },
	{ Name = "Desert", Speed = 10000 },
	{ Name = "Jungle", Speed = 40000 },
	{ Name = "Snow", Speed = 170000 },
	{ Name = "Volcano", Speed = 700000 },
	{ Name = "Abyss Ocean", Speed = 2500000 },
	{ Name = "Prehistoric", Speed = 18000000 },
	{ Name = "Cosmic", Speed = 700000000 },
	{ Name = "Cherry Blossom", Speed = 2500000000 },
}

local REMOTE_KEYS = {
	steal = { "steal", "pickup", "pick_up", "grab", "takeegg", "take_egg", "carry", "collectegg" },
	hatch = { "hatch", "incubate", "openegg" },
	place = { "place", "deploy", "equippet", "putpet", "slot" },
	sell = { "sell" },
	upgrade = { "upgrade", "treadmill", "buyupgrade", "upgradebase", "penupgrade" },
	index = { "index", "claim", "reward", "unlock" },
	trail = { "trail" },
	fuse = { "fuse", "combine", "merge" },
	step = { "step", "train", "runstep", "addspeed", "gainspeed", "treadstep" },
	cash = { "cash", "collect", "pickupcash", "claimcash", "collectcoin" },
	buy = { "buy", "purchase", "shop" },
	bat = { "bat", "swing", "hit", "attack" },
	equip = { "equip", "favorite", "favourite" },
}

local function notify(msg, dur)
	pcall(function()
		WindUI:Notify({
			Title = "Steal Egg Hub",
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

local function toCFrame(cf)
	if typeof(cf) == "CFrame" then
		return cf
	end
	if typeof(cf) == "Vector3" then
		return CFrame.new(cf)
	end
	if typeof(cf) == "Instance" and cf:IsA("BasePart") then
		return cf.CFrame + Vector3.new(0, 4, 0)
	end
	return nil
end

local function tp(cf)
	local char = LocalPlayer.Character
	local part = hrp()
	local target = toCFrame(cf)
	if not char or not part or not target then
		return false
	end
	local start = part.Position
	local goal = target.Position
	local dist = (start - goal).Magnitude
	if dist < 2.5 or CFG.MoveMode == "Instant" then
		char:PivotTo(target)
		return true
	end
	if CFG.MoveMode == "Stepped" then
		local step = math.max(4, tonumber(CFG.StepSize) or 12)
		local n = math.max(1, math.ceil(dist / step))
		for i = 1, n do
			if not STATE.alive() then
				return false
			end
			local a = i / n
			local pos = start:Lerp(goal, a)
			char:PivotTo(CFrame.new(pos, pos + target.LookVector))
			RunService.Heartbeat:Wait()
		end
		char:PivotTo(target)
		return true
	end
	local speed = math.max(28, tonumber(CFG.TweenSpeed) or 68)
	local dur = math.clamp(dist / speed, 0.12, 4)
	local t0 = os.clock()
	while STATE.alive() and (os.clock() - t0) < dur do
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local pos = start:Lerp(goal, a)
		char:PivotTo(CFrame.new(pos, pos + target.LookVector))
		RunService.Heartbeat:Wait()
	end
	char:PivotTo(target)
	return true
end

local function partOf(inst)
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart
		end
		return inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function firePrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end
	pcall(function()
		prompt.Enabled = true
		prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 12)
	end)
	local fired = false
	if typeof(fireproximityprompt) == "function" then
		fired = pcall(fireproximityprompt, prompt)
	end
	pcall(function()
		prompt:InputHoldBegin()
	end)
	task.wait(math.clamp(tonumber(prompt.HoldDuration) or 0.1, 0.05, 0.35))
	pcall(function()
		prompt:InputHoldEnd()
	end)
	return fired or true
end

local function firePromptsNear(pos, radius)
	local n = 0
	radius = radius or 10
	local params = OverlapParams.new()
	local parts = Workspace:GetPartBoundsInRadius(pos, radius, params)
	local seen = {}
	for _, part in ipairs(parts) do
		local cur = part
		for _ = 1, 5 do
			if not cur or seen[cur] then
				break
			end
			seen[cur] = true
			for _, ch in ipairs(cur:GetChildren()) do
				if ch:IsA("ProximityPrompt") and firePrompt(ch) then
					n += 1
				end
			end
			cur = cur.Parent
		end
	end
	return n
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
	if not remote then
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

local function scanRemotes()
	local buckets = {}
	for key in pairs(REMOTE_KEYS) do
		buckets[key] = {}
	end
	buckets.all = {}
	local count = 0
	local function consider(inst)
		if not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")) then
			return
		end
		count += 1
		table.insert(buckets.all, inst)
		local kinds = classifyRemote(inst.Name)
		if #kinds == 0 then
			kinds = classifyRemote(inst.Parent and inst.Parent.Name)
		end
		for _, kind in ipairs(kinds) do
			table.insert(buckets[kind], inst)
		end
	end
	local roots = {}
	for _, name in ipairs({ "Remotes", "Networking", "Events", "Net", "Packages", "Remote", "Knit" }) do
		local folder = ReplicatedStorage:FindFirstChild(name)
		if folder then
			table.insert(roots, folder)
		end
	end
	if #roots == 0 then
		table.insert(roots, ReplicatedStorage)
	end
	for _, root in ipairs(roots) do
		for _, inst in ipairs(root:GetDescendants()) do
			consider(inst)
		end
	end
	store.remotes = buckets
	store.lastRecon = os.clock()
	local parts = { ("remotes=%d"):format(count) }
	for _, key in ipairs({ "steal", "hatch", "place", "sell", "upgrade", "index", "trail", "cash", "buy", "step" }) do
		table.insert(parts, ("%s=%d"):format(key, #(buckets[key] or {})))
	end
	store.reconSummary = table.concat(parts, " · ")
	return store.reconSummary
end

local function ensureRemotes()
	if type(store.remotes) == "table" and type(store.remotes.all) == "table" and #store.remotes.all > 0 then
		return store.remotes
	end
	scanRemotes()
	return store.remotes
end

local PLOT_NAMES = { "Plots", "Plot", "Tycoons", "Bases", "PlayerPlots", "Pens", "Farms", "Islands" }

local function ownerMatches(inst)
	if not inst then
		return false
	end
	local ok, owner = pcall(function()
		return inst:GetAttribute("Owner")
	end)
	if ok and owner ~= nil then
		return owner == LocalPlayer.Name or owner == LocalPlayer.UserId or tostring(owner) == tostring(LocalPlayer.UserId)
	end
	ok, owner = pcall(function()
		return inst:GetAttribute("OwnerId")
	end)
	if ok and owner ~= nil then
		return owner == LocalPlayer.UserId or tostring(owner) == tostring(LocalPlayer.UserId)
	end
	local name = inst.Name
	return name == LocalPlayer.Name
		or name == tostring(LocalPlayer.UserId)
		or string.find(name, LocalPlayer.Name, 1, true) ~= nil
end

local function findPlot()
	for _, folderName in ipairs(PLOT_NAMES) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if ownerMatches(child) then
					return child
				end
			end
			local byName = folder:FindFirstChild(LocalPlayer.Name) or folder:FindFirstChild(tostring(LocalPlayer.UserId))
			if byName then
				return byName
			end
		end
	end
	for _, inst in ipairs(Workspace:GetChildren()) do
		if ownerMatches(inst) and (inst:IsA("Model") or inst:IsA("Folder")) then
			return inst
		end
	end
	for _, key in ipairs({ "Plot", "Base", "Tycoon", "Pen", "Island" }) do
		local v = LocalPlayer:GetAttribute(key)
		if typeof(v) == "Instance" then
			return v
		end
	end
	local byName = Workspace:FindFirstChild(LocalPlayer.Name)
	if byName then
		return byName
	end
	return nil
end

local function plotHomeCFrame()
	local plot = findPlot()
	if plot then
		local spawn = plot:FindFirstChild("Spawn")
			or plot:FindFirstChild("Home")
			or plot:FindFirstChild("Pen")
			or plot:FindFirstChildWhichIsA("SpawnLocation", true)
		local p = partOf(spawn or plot)
		if p then
			return p.CFrame + Vector3.new(0, 6, 0)
		end
	end
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	return nil
end

local function tpHome()
	local cf = plotHomeCFrame()
	if cf then
		return tp(cf)
	end
	return false
end

local function findNamed(root, needles)
	for _, inst in ipairs(root:GetDescendants()) do
		if containsAny(inst.Name, needles) then
			return inst
		end
	end
	return nil
end

local function findTreadmill()
	local plot = findPlot()
	if plot then
		local t = findNamed(plot, { "treadmill", "tread", "speedpad", "gym" })
		if t then
			return t
		end
	end
	return Workspace:FindFirstChild("Treadmill", true)
end

local function findBiomeFolder(biomeName)
	local want = lower(biomeName)
	for _, name in ipairs({ "Biomes", "Zones", "Maps", "Map", "World", "Areas" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if lower(child.Name) == want or string.find(lower(child.Name), want, 1, true) then
					return child
				end
			end
		end
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if lower(child.Name) == want or string.find(lower(child.Name), want, 1, true) then
			return child
		end
	end
	return nil
end

local function rarityOf(inst)
	if not inst then
		return "Common"
	end
	local attrs = { "Rarity", "rarity", "Tier", "Quality" }
	for _, a in ipairs(attrs) do
		local ok, v = pcall(function()
			return inst:GetAttribute(a)
		end)
		if ok and type(v) == "string" and RARITY_RANK[v] then
			return v
		end
	end
	local n = inst.Name
	for _, r in ipairs(RARITY_LIST) do
		if string.find(n, r, 1, true) then
			return r
		end
	end
	return "Common"
end

local function isEgg(inst)
	if not inst then
		return false
	end
	if inst:IsA("LocalScript") or inst:IsA("Script") or inst:IsA("ModuleScript") then
		return false
	end
	local n = lower(inst.Name)
	if string.find(n, "egg", 1, true) then
		if string.find(n, "gui", 1, true) or string.find(n, "icon", 1, true) then
			return false
		end
		return inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("MeshPart")
	end
	local ok, tagged = pcall(function()
		return CollectionService:HasTag(inst, "Egg") or CollectionService:HasTag(inst, "egg")
	end)
	return ok and tagged == true
end

local function inOwnPlot(inst)
	local plot = findPlot()
	if not plot or not inst then
		return false
	end
	return inst:IsDescendantOf(plot)
end

local function isMobModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	if Players:GetPlayerFromCharacter(model) then
		return false
	end
	local ok, tagged = pcall(function()
		return CollectionService:HasTag(model, "Guardian")
			or CollectionService:HasTag(model, "guardian")
			or CollectionService:HasTag(model, "Mob")
			or CollectionService:HasTag(model, "mob")
			or CollectionService:HasTag(model, "NPC")
			or CollectionService:HasTag(model, "Enemy")
	end)
	if ok and tagged then
		return true
	end
	return containsAny(model.Name, MOB_KEYWORDS)
end

local function mobFromPart(part)
	if not part then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and isMobModel(model) then
		return model
	end
	return nil
end

local function collectNearbyMobs(radius)
	local me = hrp()
	if not me then
		return {}
	end
	radius = math.clamp(tonumber(radius) or 48, 8, 200)
	local params = OverlapParams.new()
	local parts = Workspace:GetPartBoundsInRadius(me.Position, radius, params)
	local out = {}
	local seen = {}
	for _, part in ipairs(parts) do
		local model = mobFromPart(part)
		if model and not seen[model] then
			seen[model] = true
			table.insert(out, model)
		end
	end
	return out
end

local function isGuardianNear(pos, dist)
	dist = dist or 28
	local params = OverlapParams.new()
	local parts = Workspace:GetPartBoundsInRadius(pos, dist, params)
	for _, part in ipairs(parts) do
		local model = mobFromPart(part)
		if model then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				return true
			end
		end
	end
	return false
end

local function eggScanRoots()
	local roots = {}
	local seen = {}
	local function add(inst)
		if inst and not seen[inst] then
			seen[inst] = true
			table.insert(roots, inst)
		end
	end
	for _, name in ipairs({ "Biomes", "Zones", "Maps", "Map", "World", "Areas", "Eggs", "Nests" }) do
		add(Workspace:FindFirstChild(name))
	end
	for _, biome in ipairs(BIOMES) do
		add(findBiomeFolder(biome.Name))
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") then
			if containsAny(child.Name, {
				"biome",
				"egg",
				"zone",
				"map",
				"world",
				"forest",
				"lake",
				"desert",
				"jungle",
				"snow",
				"volcano",
				"abyss",
				"prehistoric",
				"cosmic",
				"cherry",
				"sakura",
				"spawn",
				"drop",
				"nest",
			}) then
				add(child)
			end
		end
	end
	if CFG.StealOthers then
		for _, folderName in ipairs(PLOT_NAMES) do
			add(Workspace:FindFirstChild(folderName))
		end
	end
	return roots
end

local function collectEggs()
	local eggs = {}
	local function consider(inst)
		if not isEgg(inst) then
			return
		end
		if not CFG.StealOthers and inOwnPlot(inst) then
			return
		end
		local p = partOf(inst)
		if not p then
			return
		end
		local r = rarityOf(inst)
		if (RARITY_RANK[r] or 0) < (RARITY_RANK[CFG.MinRarity] or 1) then
			return
		end
		if CFG.SkipGuarded and isGuardianNear(p.Position) then
			return
		end
		table.insert(eggs, { inst = inst, part = p, rarity = r, rank = RARITY_RANK[r] or 1 })
	end
	for _, tag in ipairs({ "Egg", "egg", "Eggs" }) do
		pcall(function()
			for _, inst in ipairs(CollectionService:GetTagged(tag)) do
				consider(inst)
			end
		end)
	end
	for _, root in ipairs(eggScanRoots()) do
		for _, inst in ipairs(root:GetDescendants()) do
			consider(inst)
		end
	end
	return eggs
end

local function pickEgg()
	local eggs = collectEggs()
	if #eggs == 0 then
		return nil
	end
	local me = hrp()
	local origin = me and me.Position or Vector3.zero
	if CFG.Priority == "Nearest" then
		table.sort(eggs, function(a, b)
			return (a.part.Position - origin).Magnitude < (b.part.Position - origin).Magnitude
		end)
	elseif CFG.Priority == "HighestValue" then
		table.sort(eggs, function(a, b)
			return a.rank > b.rank
		end)
	else
		table.sort(eggs, function(a, b)
			if a.rank == b.rank then
				return (a.part.Position - origin).Magnitude < (b.part.Position - origin).Magnitude
			end
			return a.rank > b.rank
		end)
	end
	return eggs[1]
end

local function isCarryingEgg()
	local char = LocalPlayer.Character
	if not char then
		return false
	end
	for _, inst in ipairs(char:GetChildren()) do
		if isEgg(inst) or containsAny(inst.Name, { "egg", "carry" }) then
			return true
		end
	end
	local ok, v = pcall(function()
		return LocalPlayer:GetAttribute("Carrying") or LocalPlayer:GetAttribute("HasEgg") or char:GetAttribute("Carrying")
	end)
	if ok and v then
		return true
	end
	return false
end

local function stealOnce()
	local now = os.clock()
	if now - store.lastSteal < CFG.StealDelay then
		return false, "cooldown"
	end
	store.lastSteal = now
	ensureRemotes()
	if isCarryingEgg() then
		local home = plotHomeCFrame()
		if not home then
			local hatchAt = Workspace:FindFirstChild("Pen", true)
				or Workspace:FindFirstChild("Incubator", true)
				or Workspace:FindFirstChild("Hatch", true)
			local p = partOf(hatchAt)
			if p then
				home = p.CFrame + Vector3.new(0, 5, 0)
			end
		end
		if home then
			tp(home)
			firePromptsNear(home.Position, 16)
		end
		hatchAll()
		placeAll()
		return true, "returned with egg"
	end
	local picked = pickEgg()
	if not picked then
		return false, "no eggs in biomes"
	end
	local okMove = tp(picked.part.CFrame + Vector3.new(0, 3.5, 0))
	local prompts = firePromptsNear(picked.part.Position, 12)
	task.wait(0.15)
	prompts += firePromptsNear(picked.part.Position, 12)
	if CFG.InstantSteal then
		local home = plotHomeCFrame()
		if home then
			tp(home)
			firePromptsNear(home.Position, 14)
		end
	end
	return true, (okMove and "tweened " or "move fail ") .. picked.rarity .. " prompts=" .. tostring(prompts)
end

local function hatchAll()
	ensureRemotes()
	store.lastHatch = os.clock()
	local n = fireRemoteGroup("hatch")
	n += fireRemoteGroup("hatch", "All")
	n += fireRemoteGroup("hatch", "Hatch")
	local plot = findPlot()
	if plot then
		for _, inst in ipairs(plot:GetDescendants()) do
			if inst:IsA("ProximityPrompt") and containsAny(inst.Name .. (inst.ActionText or "") .. (inst.ObjectText or ""), { "hatch", "open", "incub" }) then
				firePrompt(inst)
				n += 1
			end
		end
	end
	return n
end

local function placeAll()
	ensureRemotes()
	local n = fireRemoteGroup("place")
	n += fireRemoteGroup("place", "All")
	n += fireRemoteGroup("place", "Place")
	local plot = findPlot()
	if plot then
		for _, inst in ipairs(plot:GetDescendants()) do
			if inst:IsA("ProximityPrompt") and containsAny(inst.Name .. (inst.ActionText or ""), { "place", "deploy", "slot" }) then
				firePrompt(inst)
				n += 1
			end
		end
	end
	return n
end

local function collectCash()
	ensureRemotes()
	local n = fireRemoteGroup("cash")
	local plot = findPlot()
	if plot then
		for _, inst in ipairs(plot:GetDescendants()) do
			if inst:IsA("ProximityPrompt") and containsAny(inst.Name .. (inst.ActionText or ""), { "collect", "cash", "claim" }) then
				firePrompt(inst)
				n += 1
			end
		end
	end
	return n
end

local function millParts(mill)
	local parts = {}
	if not mill then
		return parts
	end
	if mill:IsA("BasePart") then
		table.insert(parts, mill)
	end
	local n = 0
	for _, c in ipairs(mill:GetDescendants()) do
		if c:IsA("BasePart") then
			n += 1
			table.insert(parts, c)
			if n >= 1 then
				break
			end
		end
	end
	return parts
end

local function stayOnMill()
	local mill = findTreadmill()
	local p = partOf(mill)
	local char = LocalPlayer.Character
	local root = hrp()
	if not mill or not p or not char or not root then
		return nil
	end
	char:PivotTo(p.CFrame + Vector3.new(0, 3.2, 0))
	local hum = humanoid()
	if hum then
		pcall(function()
			hum:Move(Vector3.new(0, 0, -1), true)
		end)
	end
	return mill, p, root
end

local function doTreadmillStep()
	local now = os.clock()
	local minGap = 1 / 8
	if now - (store.lastStepSend or 0) < minGap then
		return 0, "quota"
	end
	store.lastStepSend = now
	ensureRemotes()
	local mill, _, root = stayOnMill()
	if not mill then
		return 0, "no mill"
	end
	local n = 0
	n += fireRemoteGroup("step", 1)
	if root and typeof(firetouchinterest) == "function" then
		local part = millParts(mill)[1]
		if part then
			pcall(firetouchinterest, part, root, 1)
			pcall(firetouchinterest, part, root, 0)
			n += 1
		end
	end
	return n, "ok"
end

local function useTreadmill()
	local mill = stayOnMill()
	if not mill then
		return false
	end
	doTreadmillStep()
	return true
end

local function upgradeAll()
	ensureRemotes()
	store.lastUpgrade = os.clock()
	local n = fireRemoteGroup("upgrade")
	n += fireRemoteGroup("upgrade", "Treadmill")
	n += fireRemoteGroup("upgrade", "Base")
	n += fireRemoteGroup("upgrade", "Pen")
	n += fireRemoteGroup("buy")
	if CFG.AutoBuyTrail then
		n += fireRemoteGroup("trail")
		n += fireRemoteGroup("buy", "Trail")
	end
	return n
end

local function claimIndex()
	ensureRemotes()
	store.lastIndex = os.clock()
	local n = fireRemoteGroup("index")
	for _, arg in ipairs({ "Claim", "ClaimAll", "All", "Index" }) do
		n += fireRemoteGroup("index", arg)
	end
	return n
end

local function sellStuff()
	ensureRemotes()
	local n = 0
	if CFG.AutoSellEgg then
		n += fireRemoteGroup("sell", "Egg")
		n += fireRemoteGroup("sell", "Eggs")
	end
	if CFG.AutoSellPets then
		n += fireRemoteGroup("sell", "Pet")
		n += fireRemoteGroup("sell", "Pets")
	end
	return n
end

local function unlockAll()
	scanRemotes()
	local n = 0
	n += claimIndex()
	n += hatchAll()
	n += placeAll()
	n += upgradeAll()
	n += fireRemoteGroup("buy")
	n += fireRemoteGroup("trail")
	n += fireRemoteGroup("index", "Unlock")
	n += fireRemoteGroup("index", "UnlockAll")
	notify(("unlock-all fired %d remote calls"):format(n), 4)
	return n
end

local function applyAntiRagdoll()
	local char = LocalPlayer.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.PlatformStand = false
			hum.Sit = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BallSocketConstraint") or inst:IsA("HingeConstraint") or inst:IsA("NoCollisionConstraint") then
			pcall(function()
				inst.Enabled = false
			end)
		end
		if inst:IsA("BodyVelocity") or inst:IsA("LinearVelocity") or inst.Name == "Ragdoll" then
			pcall(function()
				inst:Destroy()
			end)
		end
	end
end

local function applyAntiTrap()
	local me = hrp()
	if not me then
		return
	end
	local params = OverlapParams.new()
	local parts = Workspace:GetPartBoundsInRadius(me.Position, 24, params)
	for _, inst in ipairs(parts) do
		if inst:IsA("BasePart") and containsAny(inst.Name, { "trap", "bear", "spike", "snare", "stun" }) then
			pcall(function()
				inst.CanTouch = false
			end)
		end
	end
end

local function applyAntiMobHit()
	local me = hrp()
	if not me then
		return
	end
	local radius = math.clamp(tonumber(CFG.MobScanRadius) or 48, 12, 120)
	for _, model in ipairs(collectNearbyMobs(radius)) do
		for _, inst in ipairs(model:GetDescendants()) do
			if inst:IsA("BasePart") then
				pcall(function()
					inst.CanTouch = false
				end)
			end
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum.WalkSpeed = 0
				hum.AutoRotate = false
			end)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			for _, inst in ipairs(plr.Character:GetDescendants()) do
				if inst:IsA("BasePart") and containsAny(inst.Name, { "handle", "bat", "hitbox", "weapon", "blade" }) then
					if (inst.Position - me.Position).Magnitude <= radius then
						pcall(function()
							inst.CanTouch = false
						end)
					end
				end
			end
		end
	end
	if CFG.AntiRagdoll then
		applyAntiRagdoll()
	end
end

local function voidMobModel(model)
	if not model or not model.Parent then
		return false
	end
	pcall(function()
		model:PivotTo(MOB_VOID_CF)
	end)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			pcall(function()
				inst.CanTouch = false
				inst.CanCollide = false
				inst.Anchored = true
				inst.CFrame = MOB_VOID_CF
			end)
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.WalkSpeed = 0
			hum:MoveTo(MOB_VOID_CF.Position)
		end)
	end
	return true
end

local function voidNearbyMobs(radius)
	radius = radius or CFG.MobScanRadius
	local n = 0
	for _, model in ipairs(collectNearbyMobs(radius)) do
		if voidMobModel(model) then
			n = n + 1
		end
	end
	return n
end

local function applyVoidMobs()
	local radius = math.clamp(tonumber(CFG.MobScanRadius) or 48, 12, 200)
	for _, model in ipairs(collectNearbyMobs(radius)) do
		local root = partOf(model)
		if root and (root.Position - MOB_VOID_CF.Position).Magnitude > 80 then
			voidMobModel(model)
		end
	end
end

local function batAuraTick()
	local char = LocalPlayer.Character
	if not char then
		return
	end
	local me = char:FindFirstChild("HumanoidRootPart")
	if not me then
		return
	end
	local tool = char:FindFirstChildWhichIsA("Tool")
	if not tool or not containsAny(tool.Name, { "bat", "weapon" }) then
		for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if t:IsA("Tool") and containsAny(t.Name, { "bat" }) then
				pcall(function()
					humanoid():EquipTool(t)
				end)
				tool = t
				break
			end
		end
	end
	local swung = false
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local other = plr.Character:FindFirstChild("HumanoidRootPart")
			if other and (other.Position - me.Position).Magnitude <= CFG.BatRange then
				fireRemoteGroup("bat", plr)
				fireRemoteGroup("bat", plr.Character)
				if tool then
					pcall(function()
						tool:Activate()
					end)
				end
				swung = true
			end
		end
	end
	return swung
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
		for _, p in ipairs(char:GetDescendants()) do
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

local function applyMovement()
	if not CFG.SpeedOverride then
		return
	end
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
	bb.Name = "SAE_ESP"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(140, 28)
	bb.StudsOffset = Vector3.new(0, 3, 0)
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
	if CFG.EspEggs then
		for i, egg in ipairs(collectEggs()) do
			if i > 40 then
				break
			end
			store.esp["e_" .. i] = makeBillboard(egg.part, egg.rarity .. " egg", Color3.fromRGB(255, 120, 140))
		end
	end
	if CFG.EspPets then
		local plot = findPlot()
		if plot then
			local i = 0
			for _, inst in ipairs(plot:GetDescendants()) do
				if inst:IsA("Model") and containsAny(inst.Name, { "pet", "animal" }) then
					local p = partOf(inst)
					if p then
						i += 1
						store.esp["pet_" .. i] = makeBillboard(p, inst.Name, Color3.fromRGB(140, 220, 255))
						if i > 25 then
							break
						end
					end
				end
			end
		end
	end
	if CFG.EspGuardians then
		local me = hrp()
		if me then
			local i = 0
			local parts = Workspace:GetPartBoundsInRadius(me.Position, 180, OverlapParams.new())
			local seen = {}
			for _, part in ipairs(parts) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and not seen[model] and isMobModel(model) then
					seen[model] = true
					local p = partOf(model)
					if p then
						i += 1
						store.esp["g_" .. i] = makeBillboard(p, model.Name, Color3.fromRGB(255, 80, 80))
						if i > 12 then
							break
						end
					end
				end
			end
		end
	end
end

local function isNight()
	local t = Lighting.ClockTime
	return t >= 18 or t < 6
end

-- loops
task.spawn(function()
	while STATE.alive() do
		if CFG.AutoFarm or CFG.AutoSteal then
			pcall(stealOnce)
		end
		task.wait(CFG.FarmDelay)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AutoFarm or CFG.AutoHatch then
			pcall(hatchAll)
		end
		if CFG.AutoFarm or CFG.AutoPlace then
			pcall(placeAll)
		end
		if CFG.AutoFarm or CFG.AutoCollectCash then
			pcall(collectCash)
		end
		if CFG.AutoFarm and CFG.AutoUpgradeTreadmill then
			pcall(upgradeAll)
		end
		if CFG.AutoFarm and CFG.AutoClaimIndex then
			pcall(claimIndex)
		end
		if CFG.AutoSellEgg or CFG.AutoSellPets then
			pcall(sellStuff)
		end
		if CFG.AutoFuse then
			pcall(function()
				fireRemoteGroup("fuse")
			end)
		end
		task.wait(1.1)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.InstantStep or CFG.AutoTreadmill or (CFG.AutoFarm and isNight()) then
			pcall(doTreadmillStep)
		end
		local rate = math.clamp(tonumber(CFG.StepRate) or 6, 1, 8)
		task.wait(1 / rate)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.AntiRagdoll then
			pcall(applyAntiRagdoll)
		end
		if CFG.AntiTrap then
			pcall(applyAntiTrap)
		end
		if CFG.AntiMobHit then
			pcall(applyAntiMobHit)
		end
		if CFG.VoidMobs then
			pcall(applyVoidMobs)
		end
		if CFG.BatAura then
			pcall(batAuraTick)
		end
		if CFG.SpeedOverride or CFG.Godmode then
			pcall(applyMovement)
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	while STATE.alive() do
		if CFG.EspEggs or CFG.EspPets or CFG.EspPlayers or CFG.EspGuardians then
			pcall(refreshEsp)
		else
			clearEsp()
		end
		task.wait(1.25)
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
	task.wait(0.4)
	applyMovement()
	if CFG.Noclip then
		setNoclip(true)
	end
end)

STATE.onCleanup(function()
	clearEsp()
	if store.tween then
		pcall(function()
			store.tween:Cancel()
		end)
		store.tween = nil
	end
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
	Title = "Steal An Egg Hub",
	Author = "local WindUI",
	Folder = "StealEggHub",
	Icon = "egg",
	NewElements = true,
	Size = UDim2.fromOffset(580, 460),
	HideSearchBar = false,
	OpenButton = {
		Title = "SAE Hub",
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

Window:Tag({
	Title = "v6 mob",
	Icon = "egg",
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
		Title = "Steal An Egg Hub",
		Desc = "Tween move · no namecall hook · no load recon · RightShift / OpenButton",
	})
	Tab:Toggle({
		Title = "Silent Mode",
		Desc = "Mute auto notifications",
		Default = CFG.Silent,
		Callback = function(v)
			CFG.Silent = v
		end,
	})
	Tab:Button({
		Title = "Recon Remotes Now",
		Desc = "RS Remotes/Net only — not Workspace",
		Icon = "search",
		Callback = function()
			notify(scanRemotes(), 5)
		end,
	})
	Tab:Button({
		Title = "Teleport Home",
		Icon = "house",
		Callback = function()
			notify(tpHome() and "tweened home" or "plot not found")
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Steal", Icon = "egg", IconColor = Red })
	Tab:Toggle({
		Title = "Tween Steal",
		Desc = "Linear tween to egg, prompt, tween home",
		Default = CFG.InstantSteal,
		Callback = function(v)
			CFG.InstantSteal = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Steal",
		Default = CFG.AutoSteal,
		Callback = function(v)
			CFG.AutoSteal = v
		end,
	})
	Tab:Toggle({
		Title = "Steal Other Plots",
		Desc = "Also target eggs in other player pens",
		Default = CFG.StealOthers,
		Callback = function(v)
			CFG.StealOthers = v
		end,
	})
	Tab:Toggle({
		Title = "Skip Guarded",
		Default = CFG.SkipGuarded,
		Callback = function(v)
			CFG.SkipGuarded = v
		end,
	})
	Tab:Dropdown({
		Title = "Priority",
		Values = { "Rarest", "Nearest", "HighestValue" },
		Value = CFG.Priority,
		Callback = function(v)
			CFG.Priority = v
		end,
	})
	Tab:Dropdown({
		Title = "Min Rarity",
		Values = RARITY_LIST,
		Value = CFG.MinRarity,
		Callback = function(v)
			CFG.MinRarity = v
		end,
	})
	Tab:Dropdown({
		Title = "Move Mode",
		Desc = "Instant = snap · Stepped = short hops · Tween = lerp",
		Values = { "Tween", "Stepped", "Instant" },
		Value = CFG.MoveMode,
		Callback = function(v)
			CFG.MoveMode = v
		end,
	})
	Tab:Slider({
		Title = "Step Size",
		Desc = "studs per hop when Stepped",
		Value = { Min = 4, Max = 80, Default = CFG.StepSize },
		Step = 1,
		Callback = function(v)
			CFG.StepSize = v
		end,
	})
	Tab:Slider({
		Title = "Tween Speed",
		Desc = "studs/sec — keep near run speed",
		Value = { Min = 28, Max = 120, Default = CFG.TweenSpeed },
		Step = 1,
		Callback = function(v)
			CFG.TweenSpeed = v
		end,
	})
	Tab:Slider({
		Title = "Steal Delay",
		Value = { Min = 0.1, Max = 2, Default = CFG.StealDelay },
		Step = 0.05,
		Callback = function(v)
			CFG.StealDelay = v
		end,
	})
	Tab:Button({
		Title = "Steal Once",
		Icon = "zap",
		Callback = function()
			local ok, msg = stealOnce()
			notify((ok and "steal: " or "steal fail: ") .. tostring(msg))
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Farm", Icon = "sprout", IconColor = Green })
	Tab:Toggle({
		Title = "Auto Farm",
		Desc = "Steal + hatch + place + cash + upgrades",
		Default = CFG.AutoFarm,
		Callback = function(v)
			CFG.AutoFarm = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Hatch",
		Default = CFG.AutoHatch,
		Callback = function(v)
			CFG.AutoHatch = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Place Pets",
		Default = CFG.AutoPlace,
		Callback = function(v)
			CFG.AutoPlace = v
		end,
	})
	Tab:Toggle({
		Title = "Instant Step",
		Desc = "+240 ticks while on mill. Capped at 8 Hz — burst does not raise server quota.",
		Default = CFG.InstantStep,
		Callback = function(v)
			CFG.InstantStep = v
		end,
	})
	Tab:Slider({
		Title = "Step Rate",
		Desc = "ticks per second",
		Value = { Min = 1, Max = 8, Default = CFG.StepRate },
		Step = 1,
		Callback = function(v)
			CFG.StepRate = v
		end,
	})
	Tab:Slider({
		Title = "Step Burst",
		Desc = "ignored — extra packets hit quota and do not multiply +240",
		Value = { Min = 1, Max = 8, Default = CFG.StepBurst },
		Step = 1,
		Callback = function(v)
			CFG.StepBurst = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Treadmill",
		Default = CFG.AutoTreadmill,
		Callback = function(v)
			CFG.AutoTreadmill = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Collect Cash",
		Default = CFG.AutoCollectCash,
		Callback = function(v)
			CFG.AutoCollectCash = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Upgrade Treadmill",
		Default = CFG.AutoUpgradeTreadmill,
		Callback = function(v)
			CFG.AutoUpgradeTreadmill = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Buy Trails",
		Default = CFG.AutoBuyTrail,
		Callback = function(v)
			CFG.AutoBuyTrail = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Claim Index",
		Default = CFG.AutoClaimIndex,
		Callback = function(v)
			CFG.AutoClaimIndex = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Fuse",
		Default = CFG.AutoFuse,
		Callback = function(v)
			CFG.AutoFuse = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Sell Eggs",
		Default = CFG.AutoSellEgg,
		Callback = function(v)
			CFG.AutoSellEgg = v
		end,
	})
	Tab:Toggle({
		Title = "Auto Sell Pets",
		Default = CFG.AutoSellPets,
		Callback = function(v)
			CFG.AutoSellPets = v
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
		Title = "Hatch Now",
		Callback = function()
			notify("hatch calls: " .. hatchAll())
		end,
	})
	Tab:Button({
		Title = "Place Now",
		Callback = function()
			notify("place calls: " .. placeAll())
		end,
	})
	Tab:Button({
		Title = "Step Now",
		Callback = function()
			local n, msg = doTreadmillStep()
			notify(("step %s · %s"):format(tostring(n), tostring(msg)))
		end,
	})
	Tab:Button({
		Title = "Treadmill Now",
		Callback = function()
			notify(useTreadmill() and "on treadmill" or "treadmill missing")
		end,
	})
	Tab:Button({
		Title = "Collect Cash Now",
		Callback = function()
			notify("cash calls: " .. collectCash())
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Unlock", Icon = "unlock", IconColor = Yellow })
	Tab:Paragraph({
		Title = "Unlock All",
		Desc = "Claims index, buys upgrades/trails, hatches and places. Server still owns paid packs.",
	})
	Tab:Button({
		Title = "Unlock All",
		Icon = "unlock",
		Callback = function()
			unlockAll()
		end,
	})
	Tab:Button({
		Title = "Claim Index All",
		Callback = function()
			notify("index calls: " .. claimIndex())
		end,
	})
	Tab:Button({
		Title = "Buy / Upgrade All",
		Callback = function()
			CFG.AutoBuyTrail = true
			notify("upgrade calls: " .. upgradeAll())
		end,
	})
	Tab:Button({
		Title = "Hatch + Place All",
		Callback = function()
			notify(("hatch %d · place %d"):format(hatchAll(), placeAll()))
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Player", Icon = "user", IconColor = Blue })
	Tab:Toggle({
		Title = "Speed Override",
		Desc = "Off = do not write WalkSpeed (BAC vector)",
		Default = CFG.SpeedOverride,
		Callback = function(v)
			CFG.SpeedOverride = v
		end,
	})
	Tab:Slider({
		Title = "WalkSpeed",
		Value = { Min = 8, Max = 200, Default = CFG.WalkSpeed },
		Step = 1,
		Callback = function(v)
			CFG.WalkSpeed = v
			applyMovement()
		end,
	})
	Tab:Slider({
		Title = "JumpPower",
		Value = { Min = 0, Max = 200, Default = CFG.JumpPower },
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
		Title = "Anti Ragdoll",
		Default = CFG.AntiRagdoll,
		Callback = function(v)
			CFG.AntiRagdoll = v
		end,
	})
	Tab:Toggle({
		Title = "Anti Trap",
		Default = CFG.AntiTrap,
		Callback = function(v)
			CFG.AntiTrap = v
		end,
	})
	Tab:Toggle({
		Title = "Anti Mob Hit",
		Desc = "Strips CanTouch on nearby guardians + player bats. Pair with Anti Ragdoll.",
		Default = CFG.AntiMobHit,
		Callback = function(v)
			CFG.AntiMobHit = v
		end,
	})
	Tab:Toggle({
		Title = "Void Mobs",
		Desc = "Pushes guardians to Y -12000. Server may snap them back.",
		Default = CFG.VoidMobs,
		Callback = function(v)
			CFG.VoidMobs = v
		end,
	})
	Tab:Slider({
		Title = "Mob Scan Range",
		Value = { Min = 16, Max = 120, Default = CFG.MobScanRadius },
		Step = 2,
		Callback = function(v)
			CFG.MobScanRadius = v
		end,
	})
	Tab:Button({
		Title = "Void Nearby Mobs Now",
		Callback = function()
			local n = voidNearbyMobs()
			notify(("voided %d mob(s)"):format(n))
		end,
	})
	Tab:Toggle({
		Title = "Godmode",
		Desc = "Local health pad; server can still fling you",
		Default = CFG.Godmode,
		Callback = function(v)
			CFG.Godmode = v
		end,
	})
	Tab:Toggle({
		Title = "Bat Aura",
		Default = CFG.BatAura,
		Callback = function(v)
			CFG.BatAura = v
		end,
	})
	Tab:Slider({
		Title = "Bat Range",
		Value = { Min = 6, Max = 40, Default = CFG.BatRange },
		Step = 1,
		Callback = function(v)
			CFG.BatRange = v
		end,
	})
end

do
	local Tab = SysSec:Tab({ Title = "Teleport", Icon = "map-pin", IconColor = Red })
	Tab:Button({
		Title = "Home / Pen",
		Callback = function()
			notify(tpHome() and "home" or "plot missing")
		end,
	})
	Tab:Button({
		Title = "Treadmill",
		Callback = function()
			notify(useTreadmill() and "treadmill" or "missing")
		end,
	})
	for _, biome in ipairs(BIOMES) do
		local name = biome.Name
		Tab:Button({
			Title = name,
			Desc = "speed gate " .. tostring(biome.Speed),
			Callback = function()
				local folder = findBiomeFolder(name)
				local p = partOf(folder)
				if p then
					tp(p.CFrame + Vector3.new(0, 8, 0))
					notify("warped " .. name)
				else
					notify(name .. " folder not found")
				end
			end,
		})
	end
end

do
	local Tab = SysSec:Tab({ Title = "Visuals", Icon = "eye", IconColor = Blue })
	Tab:Toggle({
		Title = "Egg ESP",
		Default = CFG.EspEggs,
		Callback = function(v)
			CFG.EspEggs = v
		end,
	})
	Tab:Toggle({
		Title = "Pet ESP",
		Default = CFG.EspPets,
		Callback = function(v)
			CFG.EspPets = v
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
		Title = "Guardian ESP",
		Default = CFG.EspGuardians,
		Callback = function(v)
			CFG.EspGuardians = v
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

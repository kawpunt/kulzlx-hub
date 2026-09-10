-- [[🐥] Grow a Chicken Fighter — Power Hub ]]
-- Server-authoritative features via Remotes (not visual spoofs).
-- Toggle UI: RightCtrl | Destroy: End

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Remotes = require(ReplicatedStorage.Core.Remotes)
local DataService = require(ReplicatedStorage.Packages.DataService).client

local EGG_TIERS = {
	"barn", "feed", "diner", "golden", "arena", "rival", "trophy", "crown",
	"void", "haunt", "bloom", "storm", "fang", "circuit", "meme", "trick",
	"hotEgg", "ordnance", "colossus", "ascension", "demonic", "blessed", "charm",
}

local KEEP_RARITIES = {
	rare = true,
	epic = true,
	legendary = true,
	mythic = true,
	ascended = true,
	secret = true,
	exclusive = true,
}

local G = getgenv()
if G.__ChickenFighterHub and type(G.__ChickenFighterHub.destroy) == "function" then
	pcall(G.__ChickenFighterHub.destroy)
end

local Hub = {
	autoFarm = false,
	instantKill = false,
	instantRoll = false,
	instantFarm = false,
	keepMain = true,
	sellCommons = true,
	towerFloor = 1,
	status = "idle",
	alive = true,
}
G.__ChickenFighterHub = Hub

local function safeInvoke(def, ...)
	local ok, res = pcall(Remotes.invoke, def, ...)
	if not ok then
		return { ok = false, error = tostring(res) }
	end
	if type(res) ~= "table" then
		return { ok = false, error = "bad-response" }
	end
	return res
end

local function safeFire(def, ...)
	pcall(Remotes.fire, def, ...)
end

local function getRoster()
	return DataService:get({ "roster" })
end

local function getCoop()
	return DataService:get({ "coop" })
end

local function getHRP()
	local char = LocalPlayer.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

local function mainChickenId()
	local roster = getRoster()
	if not roster or type(roster.chickens) ~= "table" then
		return nil
	end
	local bestId, bestLevel = nil, -1
	for _, c in pairs(roster.chickens) do
		if type(c) == "table" and type(c.id) == "string" then
			local lvl = tonumber(c.level) or 0
			if lvl > bestLevel then
				bestLevel = lvl
				bestId = c.id
			end
		end
	end
	return bestId
end

local function collectNestEggs()
	local hrp = getHRP()
	if not hrp then
		return 0
	end
	local eggs = CollectionService:GetTagged("NestEgg")
	local n = 0
	for _, egg in ipairs(eggs) do
		if egg:IsA("BasePart") then
			local owner = egg:GetAttribute("Owner") or egg:GetAttribute("owner") or egg:GetAttribute("UserId")
			if owner == nil or owner == LocalPlayer.UserId or tostring(owner) == tostring(LocalPlayer.UserId) then
				hrp.CFrame = CFrame.new(egg.Position + Vector3.new(0, 3, 0))
				n += 1
				task.wait(0.22)
			end
		end
	end
	return n
end

local function hatchAll()
	local hatched = 0
	for _, tier in ipairs(EGG_TIERS) do
		local res = safeInvoke(Remotes.defs.HatchMaxEggs, tier)
		if res.ok then
			hatched += 1
		else
			local one = safeInvoke(Remotes.defs.HatchEgg, tier)
			if one.ok then
				hatched += 1
			end
		end
	end
	return hatched
end

local function sellJunk()
	if not Hub.sellCommons then
		return 0
	end
	local roster = getRoster()
	if not roster or type(roster.chickens) ~= "table" then
		return 0
	end
	local keep = Hub.keepMain and mainChickenId() or nil
	local toSell = {}
	for _, c in pairs(roster.chickens) do
		if type(c) == "table" and type(c.id) == "string" then
			local rarity = string.lower(tostring(c.rarity or ""))
			if c.id ~= keep and not KEEP_RARITIES[rarity] then
				table.insert(toSell, c.id)
			end
		end
	end
	if #toSell == 0 then
		return 0
	end
	local sold = 0
	for i = 1, #toSell, 40 do
		local chunk = table.create(40)
		for j = i, math.min(i + 39, #toSell) do
			table.insert(chunk, toSell[j])
		end
		local res = safeInvoke(Remotes.defs.SellChickens, chunk)
		if res.ok then
			sold += (res.data and tonumber(res.data.count)) or #chunk
		end
	end
	return sold
end

local function upgradeFarm()
	local coop = getCoop()
	if coop and type(coop.generators) == "table" then
		local count = 0
		for _, g in pairs(coop.generators) do
			local slot = tonumber(g.slot)
			if slot then
				safeInvoke(Remotes.defs.UpgradeGenerator, slot)
				count += 1
			end
		end
		safeInvoke(Remotes.defs.BuyGenerator, count + 1)
	end
	safeInvoke(Remotes.defs.ExpandCoop)
	safeInvoke(Remotes.defs.IncubatorClaim)
	safeInvoke(Remotes.defs.IncubatorUpgrade)
	safeInvoke(Remotes.defs.ClaimShopDust)
	safeInvoke(Remotes.defs.ClaimIndexMilestones)
	safeInvoke(Remotes.defs.ClaimRebirthMilestones)
	safeFire(Remotes.defs.PetChicken)
	safeInvoke(Remotes.defs.EncourageChicken)
end

local function doAutoFarmCycle()
	Hub.status = "collecting eggs"
	collectNestEggs()
	Hub.status = "hatching"
	hatchAll()
	Hub.status = "selling"
	sellJunk()
	Hub.status = "upgrading"
	upgradeFarm()
	Hub.status = "farm idle"
end

local function doInstantFarm()
	Hub.status = "instant farm"
	collectNestEggs()
	task.wait(0.35)
	hatchAll()
	sellJunk()
	for _ = 1, 8 do
		upgradeFarm()
	end
	Hub.status = "instant farm done"
end

local function doInstantRoll()
	Hub.status = "rolling"
	safeInvoke(Remotes.defs.OfflineDiceRoll)
	local roster = getRoster()
	if roster and type(roster.chickens) == "table" then
		for _, c in pairs(roster.chickens) do
			if type(c) == "table" and type(c.id) == "string" then
				safeInvoke(Remotes.defs.RollCharms, c.id)
				safeInvoke(Remotes.defs.AutoCraftCharms, c.id, {
					minTier = "common",
					targets = {},
					rolls = 25,
				})
			end
		end
	end
	hatchAll()
	Hub.status = "roll idle"
end

local function doInstantKill()
	Hub.status = "killing"
	safeFire(Remotes.defs.SetArenaAutoAbility, true)

	local arena = safeInvoke(Remotes.defs.ArenaFight)
	if arena.ok then
		local ability = "iaido"
		local roster = getRoster()
		local main = mainChickenId()
		if roster and roster.chickens then
			for _, c in pairs(roster.chickens) do
				if type(c) == "table" and c.id == main and type(c.ability) == "string" then
					ability = c.ability
					break
				end
			end
		end
		for _ = 1, 12 do
			safeFire(Remotes.defs.ArenaAbility, ability)
			task.wait(0.05)
		end
	end

	local floor = Hub.towerFloor
	local start = safeInvoke(Remotes.defs.TowerStart, floor)
	if start.ok then
		Hub.towerFloor = floor + 1
	else
		safeInvoke(Remotes.defs.TowerStart)
		for i = math.max(1, floor - 3), floor + 2 do
			local r = safeInvoke(Remotes.defs.TowerStart, i)
			if r.ok then
				Hub.towerFloor = i + 1
				break
			end
		end
	end
	Hub.status = "kill idle"
end

local function createUI()
	local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "ChickenFighterHub"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = guiParent

	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromOffset(280, 290)
	frame.Position = UDim2.new(0, 24, 0.5, -145)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 196, 64)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.35
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0, 36)
	title.Position = UDim2.fromOffset(12, 6)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 214, 102)
	title.Text = "Chicken Fighter Hub"
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -16, 0, 18)
	status.Position = UDim2.fromOffset(12, 34)
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(170, 170, 180)
	status.Text = "status: idle"
	status.Parent = frame

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 58)
	list.Size = UDim2.new(1, -24, 1, -70)
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function makeToggle(order, label, key)
		local row = Instance.new("TextButton")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
		row.AutoButtonColor = false
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 14
		row.TextColor3 = Color3.fromRGB(235, 235, 240)
		row.Text = label .. ": OFF"
		row.Parent = list

		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row

		local function paint()
			local on = Hub[key] == true
			row.Text = label .. (on and ": ON" or ": OFF")
			row.BackgroundColor3 = on and Color3.fromRGB(48, 92, 42) or Color3.fromRGB(32, 32, 40)
		end

		row.MouseButton1Click:Connect(function()
			Hub[key] = not Hub[key]
			paint()
			if key == "instantFarm" and Hub.instantFarm then
				task.spawn(function()
					pcall(doInstantFarm)
					Hub.instantFarm = false
					paint()
				end)
			end
		end)
		paint()
	end

	makeToggle(1, "Auto Farm", "autoFarm")
	makeToggle(2, "Instant Kill", "instantKill")
	makeToggle(3, "Instant Roll", "instantRoll")
	makeToggle(4, "Instant Farm", "instantFarm")

	local hint = Instance.new("TextLabel")
	hint.LayoutOrder = 99
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 32)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextWrapped = true
	hint.TextColor3 = Color3.fromRGB(130, 130, 140)
	hint.Text = "RightCtrl hide · End destroy\nAll actions hit server remotes"
	hint.Parent = list

	local hb
	hb = RunService.Heartbeat:Connect(function()
		if not Hub.alive then
			hb:Disconnect()
			return
		end
		if status.Parent then
			status.Text = "status: " .. tostring(Hub.status)
		end
	end)

	local function destroy()
		Hub.alive = false
		Hub.autoFarm = false
		Hub.instantKill = false
		Hub.instantRoll = false
		Hub.instantFarm = false
		if hb then
			hb:Disconnect()
		end
		if screen then
			screen:Destroy()
		end
	end

	Hub.destroy = destroy
	Hub._screen = screen

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or not Hub.alive then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightControl then
			screen.Enabled = not screen.Enabled
		elseif input.KeyCode == Enum.KeyCode.End then
			destroy()
		end
	end)
end

createUI()

task.spawn(function()
	while Hub.alive do
		if Hub.autoFarm then
			local ok, err = pcall(doAutoFarmCycle)
			if not ok then
				Hub.status = "farm err: " .. tostring(err)
			end
			task.wait(1.25)
		else
			task.wait(0.35)
		end
	end
end)

task.spawn(function()
	while Hub.alive do
		if Hub.instantKill then
			local ok, err = pcall(doInstantKill)
			if not ok then
				Hub.status = "kill err: " .. tostring(err)
			end
			task.wait(0.75)
		else
			task.wait(0.35)
		end
	end
end)

task.spawn(function()
	while Hub.alive do
		if Hub.instantRoll then
			local ok, err = pcall(doInstantRoll)
			if not ok then
				Hub.status = "roll err: " .. tostring(err)
			end
			task.wait(0.9)
		else
			task.wait(0.35)
		end
	end
end)

print("[ChickenFighterHub] loaded — server remotes only")

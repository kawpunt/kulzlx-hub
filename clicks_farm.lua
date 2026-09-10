--[[
  Clicks Farm + Auto Egg + Auto Rebirth — dump scripts_134719268825886
  Remotes: Click, Breakables, Egg, Rebirths

  Currency is server-authoritative. Farms clicks + hatches eggs + rebirths at legit remotes.
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Library = game:GetService("ReplicatedStorage"):WaitForChild("Library")
local Client = Library:WaitForChild("Client")
local Directory = require(Library:WaitForChild("Directory"))
local Balancing = require(Library:WaitForChild("Balancing"))
local Constants = require(Library:WaitForChild("Constants"))
local Network = require(Client:WaitForChild("Network"))
local ClickFrontend = require(Client:WaitForChild("ClickFrontend"))
local BreakablesFrontend = require(Client:WaitForChild("BreakablesFrontend"))
local EggsFrontend = require(Client:WaitForChild("EggsFrontend"))
local OpenEgg = require(Client:WaitForChild("OpenEgg"))
local Currency = require(Client:WaitForChild("Currency"))
local Pets = require(Client:WaitForChild("Pets"))
local Stats = require(Client:WaitForChild("Stats"))
local MasteryFrontend = require(Client:WaitForChild("MasteryFrontend"))
local GamepassFrontend = require(Client:WaitForChild("GamepassFrontend"))
local AutoRebirthFrontend = require(Client:WaitForChild("AutoRebirthFrontend"))

local Click = Network.Channel("Click")
local Breakables = Network.Channel("Breakables")
local Egg = Network.Channel("Egg")
local Rebirths = Network.Channel("Rebirths")

local CFG = {
	enabled = true,
	useAutoFlag = true,
	clickInterval = 0.1,
	breakables = true,
	breakableInterval = 0.15,
	breakableCooldown = {},

	autoEgg = true,
	eggId = "auto", -- "auto" = nearest egg podium in workspace, or set e.g. "BasicEgg"
	eggInterval = 1.25, -- seconds between hatch attempts (backup loop)
	eggCount = 0, -- 0 = max affordable (x1/x3/x8 from game stats)
	skipRobuxEggs = true,
	useGameAutoHatch = false, -- true = Egg:SetAutoHatchEnabled (stand at egg)

	fastEgg = true, -- skip hatch animation + chain opens
	fastEggInterval = 0.15, -- server floor on "Hatching too fast"

	autoRebirth = true,
	rebirthButton = "auto", -- "auto" = highest affordable unlocked button, "max" = MaxRebirth, or index 1+
	rebirthInterval = 0.3, -- same cadence as in-game auto rebirth
	useMaxRebirth = true, -- when auto + InfiniteRebirths pass, use MaxRebirth
	syncGameAutoRebirth = true, -- SetAutoRebirth + AutoRebirthFrontend selection
}

local lastClick = 0
local lastBreakable = 0
local lastRebirth = 0
local eggLoopRunning = false
local fastEggHooked = false
local hatchRetryPending = false

local function getClicks()
	local s = Stats.Local()
	return s and s.Currency and s.Currency.Clicks or 0
end

local function fireClick()
	local now = os.clock()
	if now - lastClick < CFG.clickInterval then
		return
	end
	lastClick = now
	if CFG.useAutoFlag then
		Click:FireServer("Click", true)
	else
		Click:FireServer("Click")
	end
end

local function farmBreakables()
	local now = os.clock()
	if now - lastBreakable < CFG.breakableInterval then
		return
	end
	lastBreakable = now

	local snapshots = BreakablesFrontend.GetSnapshots()
	if not snapshots then
		return
	end

	for uid, snap in pairs(snapshots) do
		if type(uid) == "string" and type(snap) == "table" then
			local cd = CFG.breakableCooldown[uid] or 0
			if now >= cd then
				local ok, res = pcall(function()
					return Breakables:InvokeServer("Click", uid)
				end)
				if ok and res then
					CFG.breakableCooldown[uid] = now + 0.35
				end
			end
		end
	end
end

local function normalizeRebirthButtonIndex(value)
	local n = tonumber(value)
	if n and n == math.floor(n) then
		return n
	end
	return nil
end

local function getUnlockedRebirthIndices(stats)
	local indices = { 1, 2, 3 }
	local seen = { [1] = true, [2] = true, [3] = true }
	local owned = stats and stats.OwnedRebirthButtons
	if type(owned) == "table" then
		for key, value in pairs(owned) do
			local idx = normalizeRebirthButtonIndex(key)
			if not idx and (value == true or type(value) == "number" or type(value) == "string") then
				idx = normalizeRebirthButtonIndex(value)
			end
			if idx and idx >= 4 and Constants.Rebirths[idx] and not seen[idx] then
				seen[idx] = true
				table.insert(indices, idx)
			end
		end
	end
	table.sort(indices)
	return indices
end

local function getRebirthButtonAmount(buttonIndex)
	local info = Constants.Rebirths[buttonIndex]
	if not info then
		return nil
	end
	return info.Amount or 1
end

local function getRebirthCost(buttonIndex, stats)
	local amount = getRebirthButtonAmount(buttonIndex)
	if not amount or not stats then
		return math.huge
	end
	local rebirths = Currency.Get("Rebirths")
	return Balancing.Rebirths.GetCost(amount, rebirths, MasteryFrontend.GetPower(stats, "RebirthCostMultiplier"))
end

local function canUseMaxRebirth(stats)
	if not stats or not CFG.useMaxRebirth then
		return false
	end
	local pass = Directory.Gamepasses and Directory.Gamepasses.InfiniteRebirths
	if not pass then
		return false
	end
	return GamepassFrontend.Owns(pass)
end

local function getMaxRebirthAffordable(stats)
	local clicks = Currency.Get("Clicks")
	local rebirths = Currency.Get("Rebirths")
	local amount, cost = Balancing.Rebirths.GetMaxAffordable(
		clicks,
		rebirths,
		MasteryFrontend.GetPower(stats, "RebirthCostMultiplier")
	)
	if not amount or amount <= 0 or not cost or cost <= 0 then
		return 0, 0
	end
	if cost > clicks then
		return 0, 0
	end
	return amount, cost
end

local function resolveRebirthButton(stats)
	if CFG.rebirthButton == "max" then
		return "max"
	end

	local fixed = normalizeRebirthButtonIndex(CFG.rebirthButton)
	if fixed and Constants.Rebirths[fixed] then
		return fixed
	end

	local clicks = Currency.Get("Clicks")
	local best = nil
	for _, idx in ipairs(getUnlockedRebirthIndices(stats)) do
		if getRebirthCost(idx, stats) <= clicks then
			best = idx
		end
	end
	return best
end

local function syncGameAutoRebirth(buttonIndex)
	if not CFG.syncGameAutoRebirth then
		return
	end
	pcall(function()
		AutoRebirthFrontend.SetSelectedButtonIndex(buttonIndex)
		Rebirths:FireServer("SetAutoRebirth", buttonIndex)
	end)
end

local function tryRebirth()
	if not CFG.enabled or not CFG.autoRebirth then
		return
	end

	local now = os.clock()
	if now - lastRebirth < CFG.rebirthInterval then
		return
	end

	local stats = Stats.Local()
	if not stats then
		return
	end

	local button = resolveRebirthButton(stats)
	if not button then
		return
	end

	if button == "max" or (button ~= "max" and CFG.rebirthButton == "auto" and canUseMaxRebirth(stats)) then
		local amount = getMaxRebirthAffordable(stats)
		if amount > 0 then
			lastRebirth = now
			pcall(function()
				Rebirths:FireServer("MaxRebirth")
			end)
			return
		end
		if CFG.rebirthButton == "max" then
			return
		end
	end

	if type(button) ~= "number" then
		return
	end

	local cost = getRebirthCost(button, stats)
	if cost > Currency.Get("Clicks") then
		return
	end

	lastRebirth = now
	syncGameAutoRebirth(button)
	pcall(function()
		Rebirths:FireServer("Rebirth", button)
	end)
end

local function findNearestEggId()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local bestId, bestDist = nil, math.huge
	local pos = hrp.Position

	for eggId, eggInfo in pairs(Directory.Eggs) do
		if type(eggId) == "string" and type(eggInfo) == "table" then
			if not (CFG.skipRobuxEggs and EggsFrontend.IsRobux(eggId)) then
				for _, desc in ipairs(workspace:GetDescendants()) do
					if desc.Name == eggId and (desc:IsA("Model") or desc:IsA("BasePart")) then
						local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart", true)
						if part then
							local dist = (part.Position - pos).Magnitude
							if dist < bestDist then
								bestDist = dist
								bestId = eggId
							end
						end
					end
				end
			end
		end
	end

	return bestId
end

local function resolveEggId()
	if CFG.eggId ~= "" and CFG.eggId ~= "auto" then
		return CFG.eggId
	end
	return findNearestEggId()
end

local function getHatchCount(eggId)
	if not eggId or not Directory.Eggs[eggId] then
		return 0
	end
	if CFG.skipRobuxEggs and EggsFrontend.IsRobux(eggId) then
		return 0
	end

	local max = EggsFrontend.GetMaxHatchCount(eggId)
	local slots = Pets.GetRemainingInventorySlots()
	max = math.min(max, slots)
	if max <= 0 then
		return 0
	end

	if EggsFrontend.IsExclusive(eggId) then
		local s = Stats.Local()
		local owned = s and s.Items and (s.Items[eggId .. "_1"] or 0) or 0
		return math.min(owned, max)
	end

	local currencyName = Directory.Eggs[eggId].Info.Currency
	if currencyName == "Robux" then
		return 0
	end

	local cost = EggsFrontend.GetEggCost(eggId)
	local bal = Currency.Get(currencyName)
	if cost <= 0 or bal < cost then
		return 0
	end

	local affordable = math.floor(bal / cost)
	local count = math.min(max, affordable)
	if CFG.eggCount > 0 then
		count = math.min(count, CFG.eggCount)
	end
	return count
end

local function getEggLoopDelay()
	if CFG.fastEgg then
		return math.max(0.08, CFG.fastEggInterval)
	end
	return math.max(0.35, CFG.eggInterval)
end

local function scheduleEggRetry(delay)
	if hatchRetryPending then
		return
	end
	hatchRetryPending = true
	task.delay(delay or getEggLoopDelay(), function()
		hatchRetryPending = false
		if CFG.enabled and CFG.autoEgg then
			tryOpenEgg()
		end
	end)
end

local function installFastEggHook()
	if fastEggHooked or not CFG.fastEgg then
		return
	end
	fastEggHooked = true
	local oldPlay = OpenEgg.Play
	OpenEgg.Play = function(eggId, results, onComplete, skipFn)
		if CFG.fastEgg then
			if onComplete then
				pcall(onComplete)
			end
			return
		end
		return oldPlay(eggId, results, onComplete, skipFn)
	end
end

local function tryOpenEgg()
	if not CFG.autoEgg or not CFG.enabled then
		return
	end
	if OpenEgg.IsHatching() then
		return
	end
	if Pets.GetRemainingInventorySlots() <= 0 then
		return
	end

	local eggId = resolveEggId()
	if not eggId then
		return
	end

	if CFG.useGameAutoHatch then
		pcall(function()
			Egg:FireServer("SetAutoHatchEnabled", true, eggId, 99)
		end)
		return
	end

	local count = getHatchCount(eggId)
	if count <= 0 then
		return
	end

	installFastEggHook()

	local opts = {
		RestoreUI = false,
	}
	if CFG.fastEgg then
		opts.Completed = function()
			if CFG.enabled and CFG.autoEgg then
				task.defer(tryOpenEgg)
			end
		end
		opts.Failed = function(msg)
			if not CFG.enabled or not CFG.autoEgg then
				return
			end
			if msg == "Hatching too fast" then
				scheduleEggRetry(CFG.fastEggInterval)
			else
				scheduleEggRetry(getEggLoopDelay())
			end
		end
	end

	pcall(function()
		OpenEgg.Request(eggId, count, opts)
	end)
end

local function startEggLoop()
	if eggLoopRunning then
		return
	end
	eggLoopRunning = true
	task.spawn(function()
		Stats.UntilLoaded()
		while eggLoopRunning do
			if CFG.enabled and CFG.autoEgg then
				tryOpenEgg()
			end
			task.wait(getEggLoopDelay())
		end
	end)
end

task.spawn(function()
	Stats.UntilLoaded()
	local s = Stats.Local()
	if s and s.CurrentIsland then
		pcall(function()
			BreakablesFrontend.SyncIsland(s.CurrentIsland)
		end)
	end
	startEggLoop()
end)

installFastEggHook()

print("[ClicksFarm] started | Clicks =", getClicks())
print(
	"[ClicksFarm] click =",
	CFG.clickInterval,
	"| autoEgg =",
	CFG.autoEgg,
	"| fastEgg =",
	CFG.fastEgg,
	"| autoRebirth =",
	CFG.autoRebirth
)

RunService.Heartbeat:Connect(function()
	if not CFG.enabled then
		return
	end
	fireClick()
	if CFG.breakables then
		farmBreakables()
	end
	tryRebirth()
end)

getgenv().ClicksFarm = CFG
getgenv().ClicksFarmStop = function()
	CFG.enabled = false
	if CFG.useGameAutoHatch then
		pcall(function()
			Egg:FireServer("SetAutoHatchEnabled", false, CFG.eggId ~= "auto" and CFG.eggId or "", 1)
		end)
	end
	print("[ClicksFarm] stopped | Clicks =", getClicks())
end
getgenv().ClicksFarmStart = function(opts)
	if type(opts) == "table" then
		for k, v in pairs(opts) do
			CFG[k] = v
		end
	end
	CFG.enabled = true
	startEggLoop()
	print("[ClicksFarm] running | Clicks =", getClicks(), "| egg =", CFG.eggId)
end
getgenv().ClicksFarmSetInterval = function(sec)
	CFG.clickInterval = math.max(0.04, tonumber(sec) or 0.1)
	print("[ClicksFarm] click interval =", CFG.clickInterval)
end
getgenv().ClicksFarmSetEgg = function(eggId)
	CFG.eggId = eggId or "auto"
	CFG.autoEgg = true
	print("[ClicksFarm] egg =", CFG.eggId)
end
getgenv().ClicksFarmEggOn = function(eggId)
	CFG.autoEgg = true
	if eggId then
		CFG.eggId = eggId
	end
	startEggLoop()
	print("[ClicksFarm] auto egg ON |", CFG.eggId)
end
getgenv().ClicksFarmEggOff = function()
	CFG.autoEgg = false
	if CFG.useGameAutoHatch then
		pcall(function()
			Egg:FireServer("SetAutoHatchEnabled", false, "", 1)
		end)
	end
	print("[ClicksFarm] auto egg OFF")
end
getgenv().ClicksFarmFastEggOn = function(interval)
	CFG.fastEgg = true
	if interval then
		CFG.fastEggInterval = math.max(0.08, tonumber(interval) or CFG.fastEggInterval)
	end
	installFastEggHook()
	print("[ClicksFarm] fast egg ON | interval =", CFG.fastEggInterval)
end
getgenv().ClicksFarmFastEggOff = function()
	CFG.fastEgg = false
	print("[ClicksFarm] fast egg OFF (normal hatch animation)")
end
getgenv().ClicksFarmRebirthOn = function(button)
	CFG.autoRebirth = true
	if button ~= nil then
		CFG.rebirthButton = button
	end
	print("[ClicksFarm] auto rebirth ON | button =", CFG.rebirthButton)
end
getgenv().ClicksFarmRebirthOff = function()
	CFG.autoRebirth = false
	if CFG.syncGameAutoRebirth then
		pcall(function()
			AutoRebirthFrontend.SetSelectedButtonIndex(nil)
			Rebirths:FireServer("SetAutoRebirth", nil)
		end)
	end
	print("[ClicksFarm] auto rebirth OFF")
end
getgenv().ClicksFarmSetRebirth = function(button)
	CFG.rebirthButton = button or "auto"
	CFG.autoRebirth = true
	print("[ClicksFarm] rebirth button =", CFG.rebirthButton)
end

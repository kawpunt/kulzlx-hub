--[[
  Pet Simulator 99 Hub - Free Claims (#4)
  Uses Library.Client.Network.Invoke (returns ok, err/data).

  live-reload label: ps99_hub
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
	error("WindUI not found")
end

local WindUI = loadWindUI()

local RS = game:GetService("ReplicatedStorage")
local Network = require(RS.Library.Client.Network)
local Save = require(RS.Library.Client.Save)
local Directory = require(RS.Library.Directory)
local LoginStreakCmds = require(RS.Library.Client.LoginStreakCmds)
local ForeverPackCmds = require(RS.Library.Client.ForeverPackCmds)
local RankCmds = require(RS.Library.Client.RankCmds)
local Functions = require(RS.Library.Functions)

if not STATE.store then
	STATE.store = {
		lastClaimPass = 0,
		lastSummary = "",
	}
end
local store = STATE.store

local CFG = {
	Silent = true,
	AutoClaim = true,
	ClaimEvery = 8,
	FreeGifts = true,
	LoginStreak = true,
	ForeverPack = true,
	Mailbox = true,
	TimedRewards = true,
	Ranks = true,
	CTA = true,
	NPCQuests = true,
}

local function notify(msg, dur)
	if CFG.Silent then
		return
	end
	pcall(function()
		WindUI:Notify({
			Title = "PS99 Hub",
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

local function inv(name, ...)
	local okCall, a, b = pcall(function(...)
		return Network.Invoke(name, ...)
	end, ...)
	if not okCall then
		return false, tostring(a)
	end
	return a, b
end

local function fire(name, ...)
	local ok, err = pcall(function(...)
		Network.Fire(name, ...)
	end, ...)
	return ok, err
end

local function getSave()
	local ok, s = pcall(function()
		return Save.Get()
	end)
	if ok then
		return s
	end
	return nil
end

local function searchArray(arr, value)
	if typeof(Functions.SearchArray) == "function" then
		return Functions.SearchArray(arr, value)
	end
	if typeof(arr) ~= "table" then
		return false
	end
	for _, v in ipairs(arr) do
		if v == value then
			return true
		end
	end
	return false
end

local function freeGiftDefs()
	local byId = {}
	local dir = Directory.FreeGifts
	if typeof(dir) ~= "table" then
		return byId
	end
	for _, v in pairs(dir) do
		if typeof(v) == "table" and v.Id then
			byId[v.Id] = v
		end
	end
	return byId
end

local function claimFreeGifts()
	if not CFG.FreeGifts then
		return 0, {}
	end
	local s = getSave()
	if not s then
		return 0, { "no save" }
	end
	local play = tonumber(s.FreeGiftsTime) or 0
	local redeemed = s.FreeGiftsRedeemed or {}
	local n, log = 0, {}
	local defs = freeGiftDefs()
	local ids = {}
	for id in pairs(defs) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def = defs[id]
		local waitTime = tonumber(def.WaitTime) or 0
		if play >= waitTime and not searchArray(redeemed, id) then
			local ok, err = inv("Redeem Free Gift", id)
			if ok then
				n += 1
				table.insert(log, ("gift%d ok"):format(id))
			else
				table.insert(log, ("gift%d %s"):format(id, tostring(err or "fail")))
			end
			task.wait(0.15)
		end
	end
	return n, log
end

local function claimLoginStreak()
	if not CFG.LoginStreak then
		return false, "off"
	end
	local can = false
	pcall(function()
		can = LoginStreakCmds.CanClaim() == true
	end)
	if not can then
		return false, "not ready"
	end
	return inv("Login Streaks: Claim")
end

local function claimForeverPackFree()
	if not CFG.ForeverPack then
		return 0, {}
	end
	local n, log = 0, {}
	-- Claim Free takes pack/slot id; try current slot + nearby free slots
	local s = getSave()
	local slot = 0
	if s and typeof(s.ForeverPacks) == "table" then
		slot = tonumber(s.ForeverPacks.Slot) or 0
	end
	local tryIds = { slot, 0, 1, 2, 3, 4 }
	local seen = {}
	for _, id in ipairs(tryIds) do
		if not seen[id] then
			seen[id] = true
			local ok, err = inv("ForeverPacks: Claim Free", id)
			if ok then
				n += 1
				table.insert(log, ("fp%d ok"):format(id))
			elseif err and tostring(err) ~= "false" then
				table.insert(log, ("fp%d %s"):format(id, tostring(err)))
			end
			task.wait(0.1)
		end
	end
	-- also ForeverPackCmds.Claim(slot) for free-priced slots
	pcall(function()
		ForeverPackCmds.Claim(slot)
	end)
	return n, log
end

local function claimMailbox()
	if not CFG.Mailbox then
		return false, "off"
	end
	return inv("Mailbox: Claim All")
end

local function timedRewardIds()
	local ids = {}
	local folder = RS:FindFirstChild("__DIRECTORY") and RS.__DIRECTORY:FindFirstChild("TimedRewards")
	if not folder then
		return ids
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("ModuleScript") then
			local ok, data = pcall(require, m)
			if ok and typeof(data) == "table" then
				table.insert(ids, data.MachineName or data._id or m.Name)
			end
		end
	end
	table.sort(ids)
	return ids
end

local function claimTimedRewards()
	if not CFG.TimedRewards then
		return 0, {}
	end
	local n, log = 0, {}
	for _, id in ipairs(timedRewardIds()) do
		local ok, err = inv("DailyRewards_Redeem", id)
		if ok then
			n += 1
			table.insert(log, id .. " ok")
		end
		task.wait(0.05)
	end
	return n, log
end

local function claimRanks()
	if not CFG.Ranks then
		return false, "off"
	end
	local ready = false
	pcall(function()
		ready = RankCmds.AllRewardsReady() == true
	end)
	fire("Ranks_ClaimReward")
	return true, ready and "ready" or "fired"
end

local function claimCTA()
	if not CFG.CTA then
		return false, "off"
	end
	return inv("CTA Pet: Claim")
end

local function claimNPCQuests()
	if not CFG.NPCQuests then
		return false, "off"
	end
	return inv("NPC Quests: Redeem")
end

local function claimAll()
	local summary = {}
	local total = 0

	local gN, gLog = claimFreeGifts()
	total += gN
	if gN > 0 then
		table.insert(summary, ("gifts+%d"):format(gN))
	end

	local sOk = claimLoginStreak()
	if sOk then
		total += 1
		table.insert(summary, "streak")
	end

	local fN = claimForeverPackFree()
	total += fN
	if fN > 0 then
		table.insert(summary, ("fp+%d"):format(fN))
	end

	local mOk, mErr = claimMailbox()
	if mOk then
		total += 1
		table.insert(summary, "mail")
	elseif mErr and tostring(mErr) ~= "No mail to claim!" then
		-- ignore empty mailbox noise
	end

	local tN = claimTimedRewards()
	total += tN
	if tN > 0 then
		table.insert(summary, ("timed+%d"):format(tN))
	end

	claimRanks()
	local cOk = claimCTA()
	if cOk then
		total += 1
		table.insert(summary, "cta")
	end
	local qOk = claimNPCQuests()
	if qOk then
		total += 1
		table.insert(summary, "quests")
	end

	local text = #summary > 0 and table.concat(summary, ", ") or "nothing ready"
	store.lastSummary = text
	store.lastClaimPass = os.clock()
	return total, text, gLog
end

local function statusLine()
	local s = getSave()
	if not s then
		return "no save"
	end
	local play = tonumber(s.FreeGiftsTime) or 0
	local redeemed = s.FreeGiftsRedeemed or {}
	local ready = 0
	local defs = freeGiftDefs()
	for id, def in pairs(defs) do
		if play >= (tonumber(def.WaitTime) or 0) and not searchArray(redeemed, id) then
			ready += 1
		end
	end
	local streakCan = false
	pcall(function()
		streakCan = LoginStreakCmds.CanClaim() == true
	end)
	return ("play=%ds giftsReady=%d redeemed=%d streak=%s rank=%s"):format(
		math.floor(play),
		ready,
		#redeemed,
		streakCan and "yes" or "no",
		tostring(s.Rank or "?")
	)
end

-- auto loop
task.spawn(function()
	task.wait(1)
	if CFG.AutoClaim then
		local n, text = claimAll()
		if n > 0 then
			notifyAuto("Claimed: " .. text, 4)
		end
	end
	while STATE.alive() do
		task.wait(math.max(3, CFG.ClaimEvery or 8))
		if CFG.AutoClaim then
			local n, text = claimAll()
			if n > 0 then
				notifyAuto("Claimed: " .. text, 4)
			end
		end
	end
end)

-- UI
local Window = WindUI:CreateWindow({
	Title = "PS99 Hub",
	Author = "free claims",
	Folder = "PS99Hub",
	Icon = "gift",
	NewElements = true,
	Size = UDim2.fromOffset(520, 420),
	HideSearchBar = true,
	OpenButton = {
		Title = "PS99",
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

pcall(function()
	Window:SetToggleKey(Enum.KeyCode.LeftControl)
end)

-- start closed / quiet
pcall(function()
	Window:Close()
end)

local Sec = Window:Section({ Title = "Main", Opened = true })
local Tab = Sec:Tab({ Title = "Free", Icon = "gift" })

Tab:Paragraph({
	Title = "Free Claims",
	Desc = "Login streak · free gifts · forever pack · mailbox · timed machines · ranks",
})

Tab:Toggle({
	Title = "Silent Mode",
	Default = CFG.Silent,
	Callback = function(v)
		CFG.Silent = v
	end,
})

Tab:Toggle({
	Title = "Auto Claim Free Stuff",
	Desc = "Poll Network.Invoke claim remotes",
	Default = CFG.AutoClaim,
	Callback = function(v)
		CFG.AutoClaim = v
		if v then
			task.defer(claimAll)
		end
	end,
})

Tab:Slider({
	Title = "Claim Interval (s)",
	Value = { Min = 3, Max = 60, Default = CFG.ClaimEvery },
	Callback = function(v)
		CFG.ClaimEvery = tonumber(v) or 8
	end,
})

Tab:Divider()

Tab:Toggle({
	Title = "Free Gifts 1–12",
	Default = CFG.FreeGifts,
	Callback = function(v)
		CFG.FreeGifts = v
	end,
})
Tab:Toggle({
	Title = "Login Streak",
	Default = CFG.LoginStreak,
	Callback = function(v)
		CFG.LoginStreak = v
	end,
})
Tab:Toggle({
	Title = "Forever Pack Free",
	Default = CFG.ForeverPack,
	Callback = function(v)
		CFG.ForeverPack = v
	end,
})
Tab:Toggle({
	Title = "Mailbox Claim All",
	Default = CFG.Mailbox,
	Callback = function(v)
		CFG.Mailbox = v
	end,
})
Tab:Toggle({
	Title = "Timed Reward Machines",
	Default = CFG.TimedRewards,
	Callback = function(v)
		CFG.TimedRewards = v
	end,
})
Tab:Toggle({
	Title = "Rank Rewards",
	Default = CFG.Ranks,
	Callback = function(v)
		CFG.Ranks = v
	end,
})
Tab:Toggle({
	Title = "CTA Pet Claim",
	Default = CFG.CTA,
	Callback = function(v)
		CFG.CTA = v
	end,
})
Tab:Toggle({
	Title = "NPC Quest Redeem",
	Default = CFG.NPCQuests,
	Callback = function(v)
		CFG.NPCQuests = v
	end,
})

Tab:Divider()

Tab:Button({
	Title = "Claim All Now",
	Callback = function()
		CFG.Silent = false
		local n, text = claimAll()
		notify(("claimed %d | %s"):format(n, text), 5)
		CFG.Silent = true
	end,
})

Tab:Button({
	Title = "Status",
	Callback = function()
		CFG.Silent = false
		notify(statusLine(), 6)
		CFG.Silent = true
	end,
})

STATE.onCleanup(function()
	if store.window then
		pcall(function()
			store.window:Destroy()
		end)
		store.window = nil
	end
end)

store.window = Window

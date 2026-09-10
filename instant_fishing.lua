--[[
  Tree RNG — Instant Fishing
  On FishingState "reel" → RodAction:InvokeServer("reel") immediately (skip click meter).
  Optional AutoCast at power 1.0.
  Keys: F = toggle · G = autocast
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Networking = ReplicatedStorage:WaitForChild("Networking")
local Events = Networking:WaitForChild("Events")
local Requests = Networking:WaitForChild("Requests")

local FishingState = Events:WaitForChild("FishingState")
local RodAction = Requests:WaitForChild("RodAction")

local CFG = {
	Enabled = true,
	AutoCast = true,
	CastPower = 1,
	CastCooldown = 0.35,
	ToggleKey = Enum.KeyCode.F,
	AutoCastKey = Enum.KeyCode.G,
}

if not STATE.store then
	STATE.store = {
		lastCast = 0,
		lastReel = 0,
	}
end
local store = STATE.store

local function notify(title)
	pcall(function()
		require(ReplicatedStorage:WaitForChild("NotificationService")).Client({
			Title = title,
			Duration = 2.5,
		})
	end)
	print("[InstantFishing]", (tostring(title):gsub("<.->", "")))
end

local function doReel()
	local now = os.clock()
	if now - store.lastReel < 0.08 then
		return
	end
	store.lastReel = now
	task.spawn(function()
		local ok, err = pcall(function()
			RodAction:InvokeServer("reel")
		end)
		if not ok then
			warn("[InstantFishing] reel failed:", err)
		end
	end)
end

local function doCast()
	if not CFG.Enabled or not CFG.AutoCast then
		return
	end
	if workspace:GetAttribute("FishingEnabled") == false then
		return
	end
	local now = os.clock()
	if now - store.lastCast < CFG.CastCooldown then
		return
	end
	store.lastCast = now
	task.spawn(function()
		local ok, err = pcall(function()
			return RodAction:InvokeServer("cast", CFG.CastPower)
		end)
		if not ok then
			warn("[InstantFishing] cast failed:", err)
		end
	end)
end

STATE.connect(FishingState.OnClientEvent, function(state)
	if not CFG.Enabled then
		return
	end
	if state == "reel" then
		doReel()
	elseif state == "catch" or state == "escape" or state == "fail" then
		if CFG.AutoCast then
			task.delay(0.4, function()
				if STATE.alive() then
					doCast()
				end
			end)
		end
	end
end)

STATE.connect(UserInputService.InputBegan, function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == CFG.ToggleKey then
		CFG.Enabled = not CFG.Enabled
		notify(
			CFG.Enabled and '<font color="#7DFF9A">Instant Fishing ON</font>'
				or '<font color="#FF7D7D">Instant Fishing OFF</font>'
		)
	elseif input.KeyCode == CFG.AutoCastKey then
		CFG.AutoCast = not CFG.AutoCast
		notify(
			CFG.AutoCast and '<font color="#7DE3FF">AutoCast ON</font>'
				or '<font color="#FFAA55">AutoCast OFF</font>'
		)
	end
end)

task.spawn(function()
	pcall(function()
		RodAction:InvokeServer("hold")
	end)
	task.wait(0.35)
	if STATE.alive() and CFG.Enabled and CFG.AutoCast then
		doCast()
	end
	while STATE.alive() do
		task.wait(0.3)
		if CFG.Enabled and CFG.AutoCast then
			local sinceCast = os.clock() - store.lastCast
			local sinceReel = os.clock() - store.lastReel
			if sinceCast > 1.25 and sinceReel > 0.6 then
				doCast()
			end
		end
	end
end)

notify('<font color="#7DFF9A">Instant Fishing loaded</font> <font color="#FFFFFF">[F] toggle · [G] autocast</font>')

--[[
  Heavyweight Fishing — instant auto fish
  live-reload label: heavyweight_autofish
  Place 98502499119821 / Universe 8342498724
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
		return typeof(s) == "table" and typeof(s.alive) == "function" and typeof(s.connect) == "function"
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
local store = STATE.store or {}
STATE.store = store

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local DataRoot = ReplicatedStorage:WaitForChild("Data")

local CFG = store.hwCfg or {
	AutoFish = true,
	InstantMinigame = true,
	AutoSell = true,
	AutoRhythm = true,
	ProgressRate = 0.08,
	CastDelay = 0.35,
}
store.hwCfg = CFG

local function pdata()
	return DataRoot:FindFirstChild(tostring(LocalPlayer.UserId))
end

local function char()
	return LocalPlayer.Character
end

local function hrp()
	local c = char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function mainGui()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild("MainGui")
end

local function fishingUi()
	local mg = mainGui()
	return mg and mg:FindFirstChild("Fishing")
end

local function inventoryCount()
	local d = pdata()
	if not d then
		return 0
	end
	local n = 0
	local inv = d:FindFirstChild("Inventory")
	if inv then
		n += #inv:GetChildren()
	end
	local hot = d:FindFirstChild("Hotbar")
	if hot then
		for _, item in ipairs(hot:GetChildren()) do
			local q = item:FindFirstChild("Quantity")
			if q then
				n += tonumber(q.Value) or 0
			end
		end
	end
	return n
end

local function inventoryFull()
	local d = pdata()
	if not d then
		return false
	end
	local lim = d:FindFirstChild("InventoryLimit")
	if not lim then
		return false
	end
	return inventoryCount() >= (tonumber(lim.Value) or 999)
end

local function hasRodOut()
	local c = char()
	return c and c:GetAttribute("Type") == "Fishing Rod"
end

local function castRod()
	local root = hrp()
	if not root or not hasRodOut() then
		return false
	end
	if inventoryFull() then
		return false
	end
	local c = char()
	if c and c:GetAttribute("Fishing") then
		return false
	end
	pcall(function()
		Events.Fishing:FireServer(root.CFrame)
	end)
	store.lastCast = tick()
	return true
end

local function sellAll()
	pcall(function()
		Events.SellFish:FireServer("All")
	end)
end

local function centerPullBar()
	local ui = fishingUi()
	if not ui then
		return
	end
	local barFrame = ui:FindFirstChild("BarFrame")
	local bar = barFrame and barFrame:FindFirstChild("Bar")
	if bar then
		bar.Position = UDim2.new(0.5, 0, bar.Position.Y.Scale, bar.Position.Y.Offset)
	end
	local bossBar = ui:FindFirstChild("BossFightBar")
	if bossBar then
		local hit = bossBar:FindFirstChild("Hitbox")
		local b = bossBar:FindFirstChild("Bar")
		if hit and b then
			hit.Position = UDim2.new(b.Position.X.Scale, 0, hit.Position.Y.Scale, hit.Position.Y.Offset)
		end
	end
end

local function spamProgression()
	pcall(function()
		Events.UpdateFishProgression:FireServer()
	end)
end

local function spamRhythm()
	if not CFG.AutoRhythm then
		return
	end
	local ui = fishingUi()
	local rhythm = ui and ui:FindFirstChild("Rhythm")
	if rhythm and rhythm.Visible then
		pcall(function()
			Events.RhythmHit:FireServer("hit")
		end)
	end
end

local function autoPrompts()
	local ui = fishingUi()
	if not ui then
		return
	end
	local trash = ui:FindFirstChild("TrashCan")
	if not trash then
		return
	end
	for _, w in ipairs(trash:GetChildren()) do
		local btn = w:FindFirstChild("Button", true)
		if btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
			pcall(function()
				if typeof(firesignal) == "function" then
					firesignal(btn.MouseButton1Click)
				elseif typeof(fireclickdetector) == "function" and btn:IsA("GuiButton") then
					fireclickdetector(btn)
				end
			end)
		end
	end
end

local hooksReady = store.hwHooksReady
if not hooksReady then
	store.hwHooksReady = true
	pcall(function()
		Events.Charge.OnClientEvent:Connect(function(r)
			if CFG.InstantMinigame and r then
				task.defer(function()
					pcall(function()
						r:FireServer()
					end)
				end)
			end
		end)
	end)
	pcall(function()
		Events.Slam.OnClientEvent:Connect(function(r)
			if CFG.InstantMinigame and r then
				task.defer(function()
					pcall(function()
						r:FireServer("Perfect")
					end)
				end)
			end
		end)
	end)
end

local lastProg = 0
local lastCastTry = 0

STATE.connect(RunService.Heartbeat, function()
	if not STATE.alive() or not CFG.AutoFish then
		return
	end
	if inventoryFull() then
		if CFG.AutoSell and tick() - (store.lastSell or 0) > 2 then
			store.lastSell = tick()
			sellAll()
		end
		return
	end
	local ui = fishingUi()
	local inFight = ui and ui.Visible
	if inFight and CFG.InstantMinigame then
		centerPullBar()
		autoPrompts()
		spamRhythm()
		if tick() - lastProg >= (CFG.ProgressRate or 0.08) then
			lastProg = tick()
			spamProgression()
		end
		return
	end
	if not hasRodOut() then
		return
	end
	local c = char()
	if c and c:GetAttribute("Fishing") then
		return
	end
	if tick() - lastCastTry >= (CFG.CastDelay or 0.35) then
		lastCastTry = tick()
		castRod()
	end
end)

if typeof(getgenv) == "function" and typeof(queue_on_teleport) == "function" then
	local genv = getgenv()
	if not genv.HW_AUTOFISH_QOT then
		genv.HW_AUTOFISH_QOT = true
		pcall(function()
			queue_on_teleport([[
				task.spawn(function()
					for _, p in ipairs({ "heavyweight_autofish.lua", "MCP/heavyweight_autofish.lua" }) do
						if isfile and isfile(p) then
							local fn, err = loadstring(readfile(p), "@hw_autofish")
							if fn then fn() return end
							warn("[HW] qot: " .. tostring(err))
						end
					end
				end)
			]])
		end)
	end
end

print("[Heavyweight] instant auto fish ON — cast + minigame spam")

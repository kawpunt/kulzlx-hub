--[[
  Blade Ball Hub
  live-reload label: bladeball_hub

  Physics spam detect: return time + how far the ball traveled.
  Close yo-yo = F/Mouse1. Long throw in a crowd = single parry.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local STEP = "BBHubParry"
local VK_F = 0x46
local VK_E = 0x45

local function genv()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local g = genv()
if typeof(g.__BB_HUB_CLEAN) == "function" then
	pcall(g.__BB_HUB_CLEAN)
end
pcall(function()
	RunService:UnbindFromRenderStep(STEP)
	RunService:UnbindFromRenderStep("BBPerfectParry")
	RunService:UnbindFromRenderStep("BBQuietParry")
end)
if typeof(g.__BB_PERFECT_CLEAN) == "function" then
	pcall(g.__BB_PERFECT_CLEAN)
end
if typeof(g.__BB_QUIET_CLEAN) == "function" then
	pcall(g.__BB_QUIET_CLEAN)
end

if typeof(STATE) ~= "table" or typeof(STATE.alive) ~= "function" then
	local alive = true
	local cleanups = {}
	STATE = {
		alive = function()
			return alive
		end,
		connect = function(sig, fn)
			local c = sig:Connect(fn)
			table.insert(cleanups, function()
				pcall(function()
					c:Disconnect()
				end)
			end)
			return c
		end,
		onCleanup = function(fn)
			table.insert(cleanups, fn)
		end,
		_kill = function()
			alive = false
			for i = #cleanups, 1, -1 do
				pcall(cleanups[i])
			end
			table.clear(cleanups)
		end,
	}
end

local VIM
pcall(function()
	VIM = game:GetService("VirtualInputManager")
end)

local CFG = {
	On = true,
	OnlyMe = true,
	PanicDist = 21,
	NearDist = 32,
	React = 0.16,
	ReactMax = 0.28,
	Cooldown = 0.32,
	PanicCooldown = 0.16,
	RearmDist = 22,
	Hold = 0.03,
	AutoSpam = false,
	LoadWait = 60, -- seconds after inject before any F
	SpamGap = 0.05,
	-- physics detect (not from/target names)
	ReturnMax = 0.28, -- ball came back this fast = they parried like a bot
	PocketDist = 24, -- ball never left this bubble while away
	NeedBounces = 2,
	KeepDist = 28, -- keep F/M1 while ball still in pocket
	LeaveDist = 40, -- ball flew off = stop
	MinSpamSpeed = 40,
	PocketFrames = 10, -- ~0.16s sitting in your face at 60fps
	SpamArm = 1.8,
}

local store = {
	armed = true,
	leftFar = true,
	lockUntil = 0,
	lastDist = 999,
	lastTargetMe = false,
	parries = 0,
	why = "boot",
	ping = 0.05,
	gui = nil,
	status = nil,
	toggleLbl = nil,
	spamLbl = nil,
	detectLbl = nil,
	spamUntil = 0,
	spamWho = "",
	spamKind = "",
	spamHits = {},
	lastFrom = nil,
	lastTarget = nil,
	keyIdx = 1,
	lastSpamAt = 0,
	awaySince = 0,
	peakAway = 0,
	bounces = 0,
	pocketFrames = 0,
	lastMe = false,
	readyAt = os.clock() + (tonumber(CFG.LoadWait) or 60),
	parryBound = false,
}

g.__BB_HUB = store
g.__BB_HUB_CFG = CFG

----------------------------------------------------------------
-- Ball
----------------------------------------------------------------
local function getBall()
	local folder = workspace:FindFirstChild("Balls")
	if not folder then
		return nil
	end
	for _, b in ipairs(folder:GetChildren()) do
		local real = b:GetAttribute("realBall") or b:GetAttribute("RealBall")
		if real == true or real == 1 then
			return b
		end
	end
	return folder:GetChildren()[1]
end

local function ballPart(ball)
	if not ball then
		return nil
	end
	if ball:IsA("BasePart") then
		return ball
	end
	return ball:FindFirstChild("Body")
		or ball:FindFirstChild("Ball")
		or ball.PrimaryPart
		or ball:FindFirstChildWhichIsA("BasePart", true)
end

local function ballVel(ball)
	local z = ball and ball:FindFirstChild("zoomies", true)
	if z and z:IsA("LinearVelocity") then
		return z.VectorVelocity
	end
	if ball then
		for _, d in ipairs(ball:GetDescendants()) do
			if d:IsA("LinearVelocity") and d.VectorVelocity.Magnitude > 1 then
				return d.VectorVelocity
			end
		end
	end
	local p = ballPart(ball)
	return (p and p.AssemblyLinearVelocity) or Vector3.zero
end

local function ballSpeed(ball)
	local gs = ball and ball:FindFirstChild("GetSpeed")
	if gs and gs:IsA("BindableFunction") then
		local ok, spd = pcall(function()
			return gs:Invoke()
		end)
		if ok and type(spd) == "number" and spd > 1 then
			return spd
		end
	end
	return ballVel(ball).Magnitude
end

local function samePlayer(inst)
	local char = LocalPlayer.Character
	if not inst then
		return false
	end
	if inst == LocalPlayer or inst == char then
		return true
	end
	if inst:IsA("Player") then
		return inst == LocalPlayer
	end
	if inst:IsA("Model") then
		return inst == char or Players:GetPlayerFromCharacter(inst) == LocalPlayer
	end
	return false
end

local function targetingMe(ball)
	if not ball then
		return false
	end
	local char = LocalPlayer.Character
	local attr = ball:GetAttribute("target") or ball:GetAttribute("Target")
	if type(attr) == "string" then
		local a = string.lower(attr)
		if a == string.lower(LocalPlayer.Name) or a == string.lower(LocalPlayer.DisplayName) then
			return true
		end
	elseif typeof(attr) == "number" then
		if attr == LocalPlayer.UserId then
			return true
		end
	elseif typeof(attr) == "Instance" then
		if samePlayer(attr) then
			return true
		end
	end
	for _, name in ipairs({ "GetTargetCharacter", "GetTarget", "getTarget" }) do
		local fn = ball:FindFirstChild(name)
		if fn and fn:IsA("BindableFunction") then
			local ok, tgt = pcall(function()
				return fn:Invoke()
			end)
			if ok and tgt then
				if typeof(tgt) == "Instance" and samePlayer(tgt) then
					return true
				end
				if type(tgt) == "string" then
					local a = string.lower(tgt)
					if a == string.lower(LocalPlayer.Name) or a == string.lower(LocalPlayer.DisplayName) then
						return true
					end
				end
			end
		elseif fn and fn:IsA("ObjectValue") and fn.Value and samePlayer(fn.Value) then
			return true
		end
	end
	return char ~= nil and false
end

local function attrName(v)
	if type(v) == "string" and v ~= "" then
		return v
	end
	if typeof(v) == "Instance" then
		if v:IsA("Player") then
			return v.Name
		end
		return v.Name
	end
	if typeof(v) == "number" then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == v then
				return p.Name
			end
		end
		return tostring(v)
	end
	return nil
end

local function classifyName(name)
	if not name then
		return "unknown", "?"
	end
	if string.sub(string.upper(name), 1, 4) == "BOT " then
		return "bot", name
	end
	local plr = Players:FindFirstChild(name)
	if plr and plr:IsA("Player") then
		return "player", plr.DisplayName ~= "" and plr.DisplayName or plr.Name
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
			return "player", p.DisplayName
		end
	end
	local alive = workspace:FindFirstChild("Alive")
	if alive and alive:FindFirstChild(name) and not Players:GetPlayerFromCharacter(alive:FindFirstChild(name)) then
		return "bot", name
	end
	if string.find(string.lower(name), "bot") then
		return "bot", name
	end
	return "player", name
end

local function isMeName(name)
	if not name then
		return false
	end
	local a = string.lower(name)
	return a == string.lower(LocalPlayer.Name) or a == string.lower(LocalPlayer.DisplayName)
end

local function enemyDistByName(name, hrp)
	if not name or not hrp then
		return 999
	end
	local alive = workspace:FindFirstChild("Alive")
	if alive then
		local m = alive:FindFirstChild(name)
		if m then
			local p = m:FindFirstChild("HumanoidRootPart")
			if p then
				return (p.Position - hrp.Position).Magnitude
			end
		end
	end
	local plr = Players:FindFirstChild(name)
	if plr and plr.Character then
		local p = plr.Character:FindFirstChild("HumanoidRootPart")
		if p then
			return (p.Position - hrp.Position).Magnitude
		end
	end
	return 999
end

local function nearbyRivals(hrp)
	local n = 0
	local closest, closestD = "", 999
	local alive = workspace:FindFirstChild("Alive")
	if not alive or not hrp then
		return 0, "", 999
	end
	local myChar = LocalPlayer.Character
	for _, m in ipairs(alive:GetChildren()) do
		if m ~= myChar and m:IsA("Model") then
			local p = m:FindFirstChild("HumanoidRootPart")
			if p then
				local d = (p.Position - hrp.Position).Magnitude
				if d <= (CFG.SoloDist or 28) then
					n += 1
					if d < closestD then
						closestD = d
						closest = m.Name
					end
				end
			end
		end
	end
	return n, closest, closestD
end

local function armSpam(label)
	store.spamWho = label or "pocket"
	store.spamUntil = os.clock() + CFG.SpamArm
end

-- New detect: how fast the ball comes back + how far it traveled.
-- Long throw in a crowd goes 40+ studs and takes >0.4s — ignored.
-- Close spam yo-yos inside ~24 studs and returns in <0.28s.
local function updatePhysics(me, dist, speed, fromName)
	local now = os.clock()
	if me then
		if not store.lastMe then
			local away = (store.awaySince > 0) and (now - store.awaySince) or 9
			local peak = store.peakAway or dist
			if away <= CFG.ReturnMax and peak <= CFG.PocketDist and speed >= CFG.MinSpamSpeed then
				store.bounces += 1
			else
				store.bounces = math.max(0, store.bounces - 1)
			end
			if store.bounces >= CFG.NeedBounces then
				armSpam(fromName or "bounce")
			end
			store.detect = ("ret %.2fs peak %.0f spd %.0f x%d"):format(away, peak, speed, store.bounces)
		end
		if dist <= 16 and speed >= CFG.MinSpamSpeed then
			store.pocketFrames += 1
		else
			store.pocketFrames = math.max(0, store.pocketFrames - 2)
		end
		if store.pocketFrames >= CFG.PocketFrames then
			armSpam(fromName or "pocket")
		end
		store.awaySince = 0
		store.peakAway = dist
	else
		if store.lastMe then
			store.awaySince = now
			store.peakAway = dist
			store.pocketFrames = 0
		elseif store.awaySince > 0 then
			store.peakAway = math.max(store.peakAway or 0, dist)
		end
		if store.awaySince > 0 and now - store.awaySince > 0.55 then
			store.bounces = 0
			store.spamWho = ""
			store.spamUntil = 0
		end
		if dist >= CFG.LeaveDist then
			store.bounces = 0
			store.spamUntil = 0
		end
		store.detect = ("away peak %.0f"):format(store.peakAway or dist)
	end
	store.lastMe = me
	if now < store.spamUntil then
		store.detect = ("SPAM %s"):format(store.spamWho)
	end
end

local function canFight(char)
	if not char then
		return false
	end
	if char:GetAttribute("DoNotParry") or char:GetAttribute("ChargingAdrenaline") then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		return false
	end
	local alive = workspace:FindFirstChild("Alive")
	if alive then
		return char.Parent == alive
	end
	return true
end

local function samplePing()
	local ping = 0
	pcall(function()
		ping = (Stats.Network.ServerStatsItem["Data Ping"]:GetValue() or 0) / 1000
	end)
	if ping <= 0 then
		pcall(function()
			ping = LocalPlayer:GetNetworkPing() or 0
		end)
	end
	if ping > 2 then
		ping = ping / 1000
	end
	store.ping = math.clamp(ping, 0, 0.3)
	return store.ping
end

local function timeToHit(ball, hrp)
	local part = ballPart(ball)
	if not part then
		return 9, 999, 0, false
	end
	local dist = (part.Position - hrp.Position).Magnitude
	local vel = ballVel(ball)
	local speed = ballSpeed(ball)
	if speed < 1 then
		speed = vel.Magnitude
	end
	local closing = false
	local tth = 9
	if speed > 1 then
		local toMe = hrp.Position - part.Position
		local mag = math.max(toMe.Magnitude, 1e-3)
		local approach = vel:Dot(toMe / mag)
		closing = approach > 4 or dist < (store.lastDist - 0.15)
		if approach > 1 then
			tth = (dist / approach) - store.ping * 0.45
		else
			tth = (dist / speed) - store.ping * 0.45
		end
	end
	return tth, dist, speed, closing
end

local lastPress = 0
local function vimKey(key, hold)
	if not VIM then
		return
	end
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
	end)
	task.delay(hold, function()
		pcall(function()
			VIM:SendKeyEvent(false, key, false, game)
		end)
	end)
end

local function vimMouse1(hold)
	if not VIM then
		if typeof(mouse1click) == "function" then
			pcall(mouse1click)
		end
		return
	end
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(960, 540)
	local x = math.floor(vp.X * 0.5)
	local y = math.floor(vp.Y * 0.5)
	pcall(function()
		VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
	end)
	task.delay(hold, function()
		pcall(function()
			VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
		end)
	end)
end

local function pressF()
	local now = os.clock()
	if now - lastPress < 0.08 then
		return false
	end
	lastPress = now
	local hold = CFG.Hold + math.random() * 0.012
	vimKey(Enum.KeyCode.F, hold)
	return true
end

local function spamPass()
	local now = os.clock()
	if now - store.lastSpamAt < (CFG.SpamGap or 0.05) then
		return false
	end
	store.lastSpamAt = now
	local hold = 0.02
	local i = store.keyIdx
	store.keyIdx = 3 - i -- 1 <-> 2
	if i == 1 then
		vimKey(Enum.KeyCode.F, hold)
	else
		vimMouse1(hold)
	end
	return true
end

local function swing(reason, panic)
	local now = os.clock()
	local cd = panic and CFG.PanicCooldown or CFG.Cooldown
	store.lockUntil = now + cd
	store.armed = false
	store.leftFar = false
	store.parries += 1
	store.why = reason
	pressF()
end

local function remainingWait()
	local t = (store.readyAt or 0) - os.clock()
	if t < 0 then
		return 0
	end
	return t
end

local function tick()
	if not STATE.alive() then
		return
	end
	local waitLeft = remainingWait()
	if waitLeft > 0 then
		store.why = ("load %.0fs"):format(waitLeft)
		return
	end
	if not CFG.On and not CFG.AutoSpam then
		store.why = "off"
		return
	end
	samplePing()
	local char = LocalPlayer.Character
	if not canFight(char) then
		store.why = "lobby"
		store.armed = true
		store.leftFar = true
		store.spamWho = ""
		store.spamUntil = 0
		store.bounces = 0
		store.pocketFrames = 0
		store.lastMe = false
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local ball = getBall()
	if not hrp or not ball then
		store.why = "no ball"
		return
	end
	local tth, dist, speed, closing = timeToHit(ball, hrp)
	local me = targetingMe(ball)
	local now = os.clock()
	local from = ball and attrName(ball:GetAttribute("from") or ball:GetAttribute("From"))
	updatePhysics(me, dist, speed, from)

	if store.lastTargetMe and not me then
		store.armed = true
		store.leftFar = true
	end
	store.lastTargetMe = me
	if dist >= CFG.RearmDist and now >= store.lockUntil then
		store.armed = true
		store.leftFar = true
	end
	store.lastDist = dist

	-- spam only while the ball is still in the close pocket we detected
	local pocket = now < store.spamUntil and dist <= CFG.KeepDist and speed >= (CFG.MinSpamSpeed * 0.7)
	if CFG.AutoSpam and pocket and (me or closing) then
		if me then
			store.spamUntil = now + CFG.SpamArm
		end
		spamPass()
		store.why = ("spam d=%.0f v=%.0f"):format(dist, speed)
		return
	end
	if not CFG.On then
		return
	end

	if now < store.lockUntil then
		store.why = "lock"
		return
	end
	if not store.armed then
		store.why = "spent"
		return
	end
	if CFG.OnlyMe and not me then
		store.why = "not me"
		return
	end

	local win = math.clamp(CFG.React + speed * 0.00035, CFG.React, CFG.ReactMax)
	local panic = dist <= CFG.PanicDist and (closing or dist < 12)
	local eta = closing and tth >= -0.02 and tth <= win
	local near = dist <= CFG.NearDist and closing and tth <= win + 0.05

	if panic then
		swing(("panic d=%.0f"):format(dist), true)
		return
	end
	if eta or near then
		swing(("hit d=%.0f t=%.2f"):format(dist, tth), false)
		return
	end
	store.why = ("wait d=%.0f t=%.2f me=%s"):format(dist, tth, tostring(me))
end

----------------------------------------------------------------
-- Tiny panel (not WindUI)
----------------------------------------------------------------
local function paint()
	if store.toggleLbl then
		store.toggleLbl.Text = CFG.On and "Auto Parry  ON" or "Auto Parry  OFF"
		store.toggleLbl.BackgroundColor3 = CFG.On and Color3.fromRGB(30, 140, 70) or Color3.fromRGB(90, 40, 40)
	end
	if store.spamLbl then
		local live = os.clock() < store.spamUntil
		store.spamLbl.Text = CFG.AutoSpam and (live and "Spam Back  LIVE" or "Spam Back  ON") or "Spam Back  OFF"
		store.spamLbl.BackgroundColor3 = (CFG.AutoSpam and live) and Color3.fromRGB(180, 90, 20)
			or (CFG.AutoSpam and Color3.fromRGB(30, 90, 140) or Color3.fromRGB(90, 40, 40))
	end
	if store.detectLbl then
		store.detectLbl.Text = store.detect or "detect —"
	end
	if store.status then
		local w = remainingWait()
		if w > 0 then
			store.status.Text = ("wait %.0fs — no parry yet"):format(w)
		else
			store.status.Text = store.why or ""
		end
	end
end

local function makeBtn(parent, y)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 26)
	btn.Position = UDim2.fromOffset(8, y)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	return btn
end

local function makeGui()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("BBHubGui")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BBHubGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromOffset(230, 148)
	frame.Position = UDim2.new(0, 16, 0.5, -74)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 20)
	title.Position = UDim2.fromOffset(8, 4)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(230, 230, 235)
	title.Text = "Blade Ball"
	title.Parent = frame

	store.toggleLbl = makeBtn(frame, 26)
	store.toggleLbl.MouseButton1Click:Connect(function()
		CFG.On = not CFG.On
		store.armed = true
		store.leftFar = true
		paint()
	end)

	store.spamLbl = makeBtn(frame, 56)
	store.spamLbl.MouseButton1Click:Connect(function()
		CFG.AutoSpam = not CFG.AutoSpam
		paint()
	end)

	local det = Instance.new("TextLabel")
	det.BackgroundTransparency = 1
	det.Size = UDim2.new(1, -12, 0, 18)
	det.Position = UDim2.fromOffset(8, 86)
	det.Font = Enum.Font.Gotham
	det.TextSize = 12
	det.TextXAlignment = Enum.TextXAlignment.Left
	det.TextColor3 = Color3.fromRGB(200, 170, 80)
	det.Text = "detect —"
	det.Parent = frame
	store.detectLbl = det

	local st = Instance.new("TextLabel")
	st.BackgroundTransparency = 1
	st.Size = UDim2.new(1, -12, 0, 32)
	st.Position = UDim2.fromOffset(8, 106)
	st.Font = Enum.Font.Gotham
	st.TextSize = 12
	st.TextXAlignment = Enum.TextXAlignment.Left
	st.TextYAlignment = Enum.TextYAlignment.Top
	st.TextWrapped = true
	st.TextColor3 = Color3.fromRGB(160, 160, 170)
	st.Text = "boot"
	st.Parent = frame
	store.status = st
	store.gui = gui
	paint()
end

makeGui()
store.why = ("load %.0fs"):format(remainingWait())
paint()

pcall(function()
	RunService:UnbindFromRenderStep(STEP)
end)

task.spawn(function()
	if not game:IsLoaded() then
		pcall(function()
			game.Loaded:Wait()
		end)
		store.readyAt = os.clock() + (tonumber(CFG.LoadWait) or 60)
	end
	local waitFor = store.readyAt - os.clock()
	if waitFor > 0 then
		task.wait(waitFor)
	end
	if not STATE.alive() then
		return
	end
	pcall(function()
		RunService:UnbindFromRenderStep(STEP)
	end)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Input.Value, tick)
	store.parryBound = true
	store.why = "ready"
	print("[BBHub] load wait done · parry armed")
end)

STATE.connect(UserInputService.InputBegan, function(input, gp)
	if gp then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightControl then
		CFG.On = not CFG.On
		store.armed = true
		store.leftFar = true
		paint()
	elseif input.KeyCode == Enum.KeyCode.RightShift then
		if store.gui then
			store.gui.Enabled = not store.gui.Enabled
		end
	end
end)

STATE.connect(RunService.Heartbeat, function()
	if math.floor(os.clock() * 8) % 2 == 0 then
		paint()
	end
end)

g.__BB_HUB_CLEAN = function()
	pcall(function()
		RunService:UnbindFromRenderStep(STEP)
	end)
	if store.gui then
		pcall(function()
			store.gui:Destroy()
		end)
		store.gui = nil
	end
	if STATE._kill then
		pcall(STATE._kill)
	end
end
STATE.onCleanup(g.__BB_HUB_CLEAN)

print("[BBHub] loaded · waiting " .. tostring(CFG.LoadWait) .. "s before parry")

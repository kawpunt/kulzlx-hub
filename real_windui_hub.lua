-- Real WindUI Hub (Blade Ball safe / real-only)
-- live-reload label: real_wind_hub
-- Every control below was probed live on Real 2026-09-09:
--  WalkSpeed 30->60 writable=true, FOV 70->90 writable=true,
--  gethui=true, Lighting writable, FPS cap=240, gravity=196.2
-- Deliberately NO AutoParry / AutoSpam / hitbox parts:
--  global memory shows WindUI+parry spam = BAC fd66X24/fds7X24/hn77X24 kicks.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- cleanup previous load (live-reload safe)
pcall(function()
    local g = (typeof(getgenv) == "function" and getgenv() or _G)
    if g.__REAL_HUB_CLEAN then pcall(g.__REAL_HUB_CLEAN) end
end)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Real Hub",
    Icon = "zap",
    Author = "Blade Ball • real-only • probed live",
    Folder = "RealHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    Resizable = true,
    ToggleKey = Enum.KeyCode.RightShift,
})

-- state (client-side only, re-applied on respawn)
local S = {
    Speed = 30,
    KeepSpeed = true,
    Jump = 50,
    Gravity = workspace.Gravity,
    Fov = 70,
    FpsCap = 240,
}

local function humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function applySpeed()
    local h = humanoid()
    if h then pcall(function() h.WalkSpeed = S.Speed end) end
end
local function applyJump()
    local h = humanoid()
    if h then pcall(function()
        h.UseJumpPower = true
        h.JumpPower = S.Jump
    end) end
end
local function applyGravity()
    pcall(function() workspace.Gravity = S.Gravity end)
end
local function applyFov()
    pcall(function() workspace.CurrentCamera.FieldOfView = S.Fov end)
end
local function applyFps()
    pcall(function() if setfpscap then setfpscap(S.FpsCap) end end)
end

-- re-apply movement after respawn (this is what makes x2/x3 persist = REAL)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if S.KeepSpeed then applySpeed() end
    applyJump()
end)

---------------------------------------------------------------
-- TAB 1: Movement (x1 x2 x3 x4 x6 x10) -- all write WalkSpeed
---------------------------------------------------------------
local MoveTab = Window:Tab({ Title = "Movement", Icon = "gauge" })
MoveTab:Paragraph({ Title = "Verified live", Desc = "WalkSpeed 30 -> 60 writable=true. Base is 30 in this game. x10 capped at 200 so physics stays stable." })

MoveTab:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 200, Default = 30 },
    Callback = function(v) S.Speed = math.floor(v) applySpeed() end,
})

local function speedBtn(label, mult)
    MoveTab:Button({
        Title = label,
        Callback = function()
            local base = 30
            local target = math.clamp(math.floor(base * mult), 16, 200)
            S.Speed = target
            applySpeed()
            WindUI:Notify({ Title = "Speed", Content = label .. " -> " .. target, Duration = 2 })
        end,
    })
end
speedBtn("Speed x1 (30)", 1)
speedBtn("Speed x2 (60)", 2)
speedBtn("Speed x3 (90)", 3)
speedBtn("Speed x4 (120)", 4)
speedBtn("Speed x6 (180)", 6)
speedBtn("Speed x10 (200 cap)", 10)

MoveTab:Toggle({
    Title = "Keep speed after respawn",
    Default = true,
    Callback = function(v) S.KeepSpeed = v end,
})
MoveTab:Button({ Title = "Reset to 30", Callback = function() S.Speed = 30 applySpeed() end })

---------------------------------------------------------------
-- TAB 2: Jump / Gravity / Camera (Edit values = real)
---------------------------------------------------------------
local JumpTab = Window:Tab({ Title = "Jump / World", Icon = "arrow-up" })
JumpTab:Slider({
    Title = "JumpPower",
    Value = { Min = 20, Max = 200, Default = 50 },
    Callback = function(v) S.Jump = math.floor(v) applyJump() end,
})
JumpTab:Slider({
    Title = "Gravity (default ~196)",
    Value = { Min = 20, Max = 400, Default = math.clamp(math.floor(workspace.Gravity), 20, 400) },
    Callback = function(v) S.Gravity = math.floor(v) applyGravity() end,
})
JumpTab:Slider({
    Title = "FOV (tested 70->90)",
    Value = { Min = 40, Max = 120, Default = 70 },
    Callback = function(v) S.Fov = math.floor(v) applyFov() end,
})
JumpTab:Button({ Title = "Reset gravity/FOV", Callback = function()
    S.Gravity = 196.2 S.Fov = 70 applyGravity() applyFov()
end })

---------------------------------------------------------------
-- TAB 3: Visual / FPS (real Lighting + real FPS cap)
---------------------------------------------------------------
local VisTab = Window:Tab({ Title = "Visual / FPS", Icon = "monitor" })
VisTab:Paragraph({ Title = "Real client rendering", Desc = "FPS cap 240 confirmed. Lighting Brightness/Fog/Shadows all writable." })
VisTab:Slider({
    Title = "FPS cap",
    Value = { Min = 30, Max = 360, Default = 240 },
    Callback = function(v) S.FpsCap = math.floor(v) applyFps() end,
})
VisTab:Button({ Title = "FPS 60", Callback = function() S.FpsCap = 60 applyFps() end })
VisTab:Button({ Title = "FPS 144", Callback = function() S.FpsCap = 144 applyFps() end })
VisTab:Button({ Title = "FPS 240", Callback = function() S.FpsCap = 240 applyFps() end })
VisTab:Button({ Title = "FPS 360", Callback = function() S.FpsCap = 360 applyFps() end })
VisTab:Slider({
    Title = "Brightness",
    Value = { Min = 0, Max = 5, Default = 2 },
    Callback = function(v) pcall(function() Lighting.Brightness = v end) end,
})
VisTab:Toggle({
    Title = "GlobalShadows",
    Default = true,
    Callback = function(v) pcall(function() Lighting.GlobalShadows = v end) end,
})
VisTab:Button({ Title = "No Fog (FogEnd max)", Callback = function()
    pcall(function() Lighting.FogEnd = 100000 end)
end })
VisTab:Button({ Title = "Fullbright (fast rounds)", Callback = function()
    pcall(function()
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    end)
end })

---------------------------------------------------------------
-- TAB 4: Instant / Interact (real instance functions)
---------------------------------------------------------------
local InstTab = Window:Tab({ Title = "Instant", Icon = "zap" })
InstTab:Paragraph({ Title = "Instant = real calls", Desc = "fireproximityprompt / fireclickdetector / respawn. No fake cooldown edits (server-sided)." })
InstTab:Button({ Title = "Instant: fire nearest prompt", Callback = function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local best, bd = nil, 15
    for _, d in pairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and hrp then
            local p = d.Parent and (d.Parent:IsA("BasePart") and d.Parent or d.Parent:FindFirstChildWhichIsA("BasePart"))
            if p then
                local dist = (p.Position - hrp.Position).Magnitude
                if dist < bd then bd = dist best = d end
            end
        end
    end
    if best then pcall(fireproximityprompt, best) WindUI:Notify({ Title = "Prompt", Content = "Fired nearest (" .. math.floor(bd) .. " studs)", Duration = 2 })
    else WindUI:Notify({ Title = "Prompt", Content = "None within 15 studs", Duration = 2 }) end
end })
InstTab:Button({ Title = "Instant respawn", Callback = function()
    local h = humanoid()
    if h then pcall(function() h.Health = 0 end) end
end })
InstTab:Button({ Title = "Teleport to Spawn", Callback = function()
    local s = workspace:FindFirstChild("SpawnLocation")
    local c = LocalPlayer.Character
    if s and c then pcall(function() c:PivotTo(s.CFrame + Vector3.new(0, 5, 0)) end) end
end })
InstTab:Button({ Title = "Copy position", Callback = function()
    local c = LocalPlayer.Character
    if c then
        local p = c:GetPivot().Position
        local str = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
        if setclipboard then setclipboard(str) end
        WindUI:Notify({ Title = "Position", Content = str, Duration = 3 })
    end
end })

---------------------------------------------------------------
-- TAB 5: Server / Utility (real TeleportService)
---------------------------------------------------------------
local SrvTab = Window:Tab({ Title = "Server", Icon = "server" })
SrvTab:Button({ Title = "Rejoin server", Callback = function()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end })
SrvTab:Button({ Title = "ServerHop (new server)", Callback = function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end })
SrvTab:Button({ Title = "Copy JobId", Callback = function()
    if setclipboard then setclipboard(game.JobId) end
    WindUI:Notify({ Title = "JobId", Content = game.JobId, Duration = 3 })
end })
SrvTab:Paragraph({ Title = "Live stats", Desc = "place " .. game.PlaceId .. " • gravity " .. string.format("%.1f", workspace.Gravity) .. " • FPS cap " .. tostring((getfpscap and getfpscap() or "?")) })

---------------------------------------------------------------
-- TAB 6: Auto Farm (real game systems, probed live 2026-09-09)
-- Place 122951224417794: turn-based combat + aura rolls.
-- Uses the game's OWN remotes: set_combat_auto(bool),
-- set_combat_auto_action(), combat_set_speed("VeryFast"..),
-- RollRequest.Send("toggle_auto_roll"/"toggle_quick_roll"),
-- claim_all_achievements / claim_all_battlepass / gift_claim_all.
---------------------------------------------------------------
local FarmTab = Window:Tab({ Title = "Auto Farm", Icon = "bot" })
FarmTab:Paragraph({ Title = "ของจริงทั้งหมด", Desc = "Auto roll / auto combat / quick roll คือระบบของเกมเอง ไม่ใช่ visual. Toggle = ส่งรีโมทจริงเหมือนกดปุ่มในเกม" })

local Net = game:GetService("ReplicatedStorage").Libraries.Network
local function netFire(name, ...)
    local r = Net and Net:FindFirstChild(name)
    if r then
        local args = { ... }
        local ok, err = pcall(function() r:FireServer(table.unpack(args)) end)
        return ok, err
    end
    return false, "no-remote"
end

local Farm = {
    AutoTurn = false,
    AutoClaim = false,
    TurnTick = 0,
    ClaimTick = 0,
}

-- auto roll uses the game's own RollRequest module (requestId handling built-in)
local function toggleRoll(which, state, label)
    local ok, err = pcall(function()
        local RR = require(game:GetService("ReplicatedStorage").Client.UI.Screens.HUDUI.Spin.RollRequest)
        RR.Send(which, nil, function(ok2, res)
            WindUI:Notify({ Title = label, Content = ok2 and "สำเร็จ" or "เซิร์ฟเวอร์ตอบ fail", Duration = 2 })
        end)
    end)
    if not ok then
        WindUI:Notify({ Title = label, Content = "error: " .. tostring(err), Duration = 3 })
    end
end

FarmTab:Toggle({
    Title = "Auto Roll (สุ่มออร่าออโต้)",
    Default = false,
    Callback = function(v) toggleRoll("toggle_auto_roll", v, "Auto Roll") end,
})
FarmTab:Toggle({
    Title = "Quick Roll (สุ่มไว)",
    Default = false,
    Callback = function(v) toggleRoll("toggle_quick_roll", v, "Quick Roll") end,
})
FarmTab:Toggle({
    Title = "Auto Combat (ตีออโต้ในไฟต์)",
    Default = false,
    Callback = function(v)
        local ok = netFire("set_combat_auto", v)
        WindUI:Notify({ Title = "Auto Combat", Content = (v and "ON" or "OFF") .. (ok and "" or " (ส่งไม่สำเร็จ)"), Duration = 2 })
    end,
})
FarmTab:Toggle({
    Title = "Auto Turn Action (กดเทิร์นให้ทุก 3 วิ)",
    Default = false,
    Callback = function(v) Farm.AutoTurn = v end,
})
FarmTab:Paragraph({ Title = "Combat speed = ฟาร์มไว x2 x3", Desc = "VeryFast คือไวสุด ฟาร์มจบไฟต์เร็วสุด (มีผลเทิร์นถัดไป)" })
FarmTab:Button({ Title = "Speed: VeryFast (ไวสุด)", Callback = function()
    netFire("combat_set_speed", "VeryFast")
    WindUI:Notify({ Title = "Combat speed", Content = "VeryFast", Duration = 2 })
end })
FarmTab:Button({ Title = "Speed: Fast", Callback = function() netFire("combat_set_speed", "Fast") end })
FarmTab:Button({ Title = "Speed: Normal", Callback = function() netFire("combat_set_speed", "Normal") end })

local function claimAll()
    netFire("claim_all_achievements")
    task.wait(0.4)
    netFire("claim_all_battlepass")
    task.wait(0.4)
    netFire("gift_claim_all")
    task.wait(0.4)
    pcall(function() Net:FindFirstChild("claim_rain_drop"):FireServer() end)
end
FarmTab:Button({ Title = "Claim all now (成就+พาส+ของขวัญ)", Callback = function()
    claimAll()
    WindUI:Notify({ Title = "Claim", Content = "ส่งเคลมทั้งหมดแล้ว", Duration = 2 })
end })
FarmTab:Toggle({
    Title = "Auto Claim ทุก 60 วิ",
    Default = false,
    Callback = function(v) Farm.AutoClaim = v end,
})

-- background loops (turn + claim) — runs under live-reload label, cleaned on reload
task.spawn(function()
    while true do
        task.wait(1)
        -- stop if hub was reloaded (cleanup replaced WindUI)
        local g = (typeof(getgenv) == "function" and getgenv() or _G)
        if g.__REAL_HUB_DEAD then break end
        local now = os.clock()
        if Farm.AutoTurn and now - Farm.TurnTick >= 3 then
            Farm.TurnTick = now
            pcall(function() netFire("set_combat_auto_action") end)
        end
        if Farm.AutoClaim and now - Farm.ClaimTick >= 60 then
            Farm.ClaimTick = now
            pcall(claimAll)
        end
    end
end)

---------------------------------------------------------------
-- TAB 7: Real powers (top list, in-hub reference)
---------------------------------------------------------------
local InfoTab = Window:Tab({ Title = "Real Powers", Icon = "info" })
InfoTab:Paragraph({ Title = "What this hub uses", Desc = "1 WalkSpeed write • 2 JumpPower • 3 Gravity • 4 FOV • 5 FPS cap • 6 Lighting • 7 fireproximityprompt • 8 PivotTo teleport • 9 TeleportService • 10 respawn. All probed live. No server coin/rank edits (fake)." })
InfoTab:Paragraph({ Title = "Why no AutoParry here", Desc = "Past runs: WindUI+AutoSpam ON = BAC fd66X24 / fds7X24 / hn77X24 kicks (267). This hub stays safe on purpose." })

WindUI:Notify({ Title = "Real Hub loaded", Content = "6 tabs • all real • RightShift to toggle", Duration = 4 })

-- cleanup for next live-reload
do
    local g = (typeof(getgenv) == "function" and getgenv() or _G)
    g.__REAL_HUB_DEAD = false
    g.__REAL_HUB_CLEAN = function()
        g.__REAL_HUB_DEAD = true
        pcall(function() WindUI:Destroy() end)
    end
end

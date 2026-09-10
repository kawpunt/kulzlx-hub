-- Dungeon Quest Reborn — auto farm v1 (headless, no menu yet)
-- Place 77649408247578 / Universe 9931749389
-- What this does: kill-aura style farm using the game's REAL attack path
--   M1 = Accessory Weapon RemoteEvent + weaponUsed:FireServer()
--   Q/E = abilityUsed:FireServer(slot, tool)
-- Honest limits (checked via MCP):
--   * instant kill: NO — damage is server-side, weaponUsed takes no args
--   * inf items: NO — addItemToInvy is OnClientInvoke (server -> client reward), not client -> server
--   * auto farm / kill aura / ESP / auto-replay: YES

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("remotes")
local weaponUsed = remotes:WaitForChild("weaponUsed")
local abilityUsed = remotes:WaitForChild("abilityUsed")

local CFG = getgenv().DQ_CFG or {
    Enabled = true,
    SwingRate = 0.25,      -- seconds between swings
    AuraRange = 60,        -- studs: teleport to enemy if within this
    AutoAbilities = true,
    AbilityRate = 3,
    ESP = true,
}
getgenv().DQ_CFG = CFG

local function alive()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return c ~= nil and h ~= nil and h.Health > 0
end

local function peaceful()
    local v = LocalPlayer:FindFirstChild("peaceful")
    return v and v.Value == true
end

local function hrp()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function weaponAccessory()
    local c = LocalPlayer.Character
    if not c then return nil end
    for _, j in ipairs(c:GetChildren()) do
        if j:IsA("Accessory") and j:FindFirstChild("Weapon") then
            return j
        end
    end
    return nil
end

local function swingOnce()
    if not alive() then return false end
    if peaceful() then return false end
    local c = LocalPlayer.Character
    if not c then return false end
    local busy = c:FindFirstChild("busyCasting")
    if busy and busy.Value ~= false then return false end
    local acc = weaponAccessory()
    if not acc then return false end
    pcall(function()
        acc:FindFirstChildOfClass("RemoteEvent"):FireServer()
    end)
    pcall(function()
        weaponUsed:FireServer()
    end)
    return true
end

local function useAbilities()
    if not CFG.AutoAbilities then return end
    for _, slot in ipairs({ "q", "e" }) do
        local tool = nil
        for _, v in ipairs(LocalPlayer.Backpack:GetChildren()) do
            local s = v:FindFirstChild("abilitySlot")
            if s and s.Value == slot then
                local cd = v:FindFirstChild("cooldown")
                if not (cd and cd.Value > 0) then
                    tool = v
                    break
                end
            end
        end
        if tool then
            pcall(function() tool.localEvent:Fire() end)
            pcall(function() abilityUsed:FireServer(slot, tool) end)
        end
    end
end

local function nearestEnemy(maxDist)
    local folder = Workspace:FindFirstChild("enemies")
    if not folder then return nil, nil end
    local root = hrp()
    if not root then return nil, nil end
    local best, bestD = nil, maxDist or math.huge
    for _, m in ipairs(folder:GetChildren()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        local eroot = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
        if h and h.Health > 0 and eroot then
            local d = (eroot.Position - root.Position).Magnitude
            if d < bestD then
                best, bestD = m, d
            end
        end
    end
    return best, bestD
end

-- ESP (Drawing, cleaned up on reload)
local espCache = {}
STATE.onCleanup(function()
    for _, d in pairs(espCache) do
        pcall(function() d:Remove() end)
    end
    table.clear(espCache)
end)

local function espTick()
    if not CFG.ESP then return end
    if typeof(Drawing) ~= "table" or typeof(Drawing.new) ~= "function" then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local folder = Workspace:FindFirstChild("enemies")
    if not folder then return end
    local seen = {}
    for _, m in ipairs(folder:GetChildren()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            local eroot = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if eroot then
                seen[m] = true
                local d = espCache[m]
                if not d then
                    d = Drawing.new("Text")
                    d.Center = true
                    d.Outline = true
                    d.Size = 14
                    espCache[m] = d
                end
                local v, on = cam:WorldToViewportPoint(eroot.Position + Vector3.new(0, 3, 0))
                if on and v.Z > 0 then
                    d.Visible = true
                    d.Position = Vector2.new(v.X, v.Y)
                    d.Text = string.format("%s %d/%d", m.Name, math.floor(h.Health), math.floor(h.MaxHealth))
                else
                    d.Visible = false
                end
            end
        end
    end
    for m, d in pairs(espCache) do
        if not seen[m] then
            pcall(function() d:Remove() end)
            espCache[m] = nil
        end
    end
end

-- main loops
local lastSwing = 0
local lastAbility = 0

STATE.connect(RunService.Heartbeat, function()
    if not STATE.alive() then return end
    if not CFG.Enabled then return end
    pcall(espTick)
    if not alive() then return end
    -- stick to nearest enemy
    local enemy, dist = nearestEnemy(CFG.AuraRange)
    if enemy then
        local eroot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
        local root = hrp()
        if eroot and root and dist > 8 then
            pcall(function()
                root.CFrame = eroot.CFrame + Vector3.new(0, 2, 4)
            end)
        end
    end
    if tick() - lastSwing >= CFG.SwingRate then
        lastSwing = tick()
        swingOnce()
    end
    if tick() - lastAbility >= CFG.AbilityRate then
        lastAbility = tick()
        pcall(useAbilities)
    end
end)

print("[DQ] auto farm v1 ON — swing + aura + ESP. getgenv().DQ_CFG.Enabled=false to pause")

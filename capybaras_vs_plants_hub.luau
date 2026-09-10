-- Capybaras VS Plants — WindUI hub
-- live-reload label: cvp_hub
-- Remotes probed from live decompile (place 104973076655377 / v6661)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local LR = rawget(getfenv(), "STATE")
local genv = (typeof(getgenv) == "function" and getgenv()) or _G
if not LR and genv.__CVP_HUB_CLEAN then
    pcall(genv.__CVP_HUB_CLEAN)
end

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "CVP Hub",
    Icon = "leaf",
    Author = "Capybaras VS Plants • live remotes",
    Folder = "CVPHub",
    Size = UDim2.fromOffset(620, 500),
    Theme = "Dark",
    Resizable = true,
    ToggleKey = Enum.KeyCode.RightShift,
})

local SHOP_EGGS = {
    "Capybara Egg",
    "Alpha Capybara Egg",
    "Archer Capybara Egg",
    "Magic Capybara Egg",
    "Ghost Capybara Egg",
    "Golem Capybara Egg",
    "Robot Capybara Egg",
    "Disco Capybara Egg",
    "Angel Capybara Egg",
    "Dragon Capybara Egg",
}

local SHOP_GEAR = {
    "Hatch Hammer",
    "Nametag",
    "Mutation Sponge",
    "Boombox",
    "Bizarre Stopwatch",
    "Trading Ticket",
    "Level Up Loaf",
}

local PLAYTIME = {
    "Reward1", "Reward2", "Reward3", "Reward4", "Reward5",
    "Reward6", "Reward7", "Reward8", "Reward9", "Reward10", "Reward11",
}

local S = genv.__CVP_HUB_S or {
    AutoFarm = false,
    AutoCollect = false,
    AutoHatch = false,
    AutoPlacePlants = false,
    AutoPlaceEggs = false,
    AutoBuy = false,
    AutoRewards = false,
    AutoGrow = false,
    AutoSellPlants = false,
    FarmDelay = 0.45,
    EggName = "Capybara Egg",
    GearName = "Hatch Hammer",
    Code = "",
    Speed = 30,
    KeepSpeed = true,
    PlaceCF = nil,
}
genv.__CVP_HUB_S = S

local function alive()
    if LR and LR.alive then
        return LR.alive()
    end
    return genv.__CVP_HUB_S == S
end

local cleanups = {}
local function onCleanup(fn)
    if LR and LR.onCleanup then
        LR.onCleanup(fn)
    else
        table.insert(cleanups, fn)
    end
end

local function teardown()
    S.AutoFarm = false
    S.AutoCollect = false
    S.AutoHatch = false
    S.AutoPlacePlants = false
    S.AutoPlaceEggs = false
    S.AutoBuy = false
    S.AutoRewards = false
    S.AutoGrow = false
    S.AutoSellPlants = false
    for i = #cleanups, 1, -1 do
        pcall(cleanups[i])
        cleanups[i] = nil
    end
    pcall(function()
        if Window and Window.Destroy then
            Window:Destroy()
        elseif Window and Window.Close then
            Window:Close()
        end
    end)
end
if LR and LR.onCleanup then
    LR.onCleanup(teardown)
end
genv.__CVP_HUB_CLEAN = teardown

local function notify(title, content)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content, Duration = 2.5 })
    end)
end

local function fire(name, ...)
    local r = Remotes:FindFirstChild(name)
    if not r then
        return false
    end
    if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
        return pcall(function(...)
            r:FireServer(...)
        end, ...)
    end
    local ok, res = pcall(function(...)
        return r:InvokeServer(...)
    end, ...)
    return ok, res
end

local function money()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local m = ls and ls:FindFirstChild("Money")
    return (m and m.Value) or 0
end

local function myPlot()
    local plots = workspace:FindFirstChild("World")
    plots = plots and plots:FindFirstChild("Map") and plots.Map:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    local uid = LocalPlayer.UserId
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("Owner") == uid then
            return plot
        end
    end
    return nil
end

local function placedFolder(kind)
    local map = workspace:FindFirstChild("World")
    map = map and map:FindFirstChild("Map")
    if not map then
        return nil
    end
    local folder = map:FindFirstChild(kind)
    return folder and folder:FindFirstChild("Server")
end

local function ownedModels(kind)
    local folder = placedFolder(kind)
    local out = {}
    if not folder then
        return out
    end
    local uid = LocalPlayer.UserId
    for _, m in ipairs(folder:GetChildren()) do
        if m:GetAttribute("Owner") == uid then
            table.insert(out, m)
        end
    end
    return out
end

local function cfgValue(model, name)
    local cfg = model:FindFirstChild("ServerConfiguration")
    local v = cfg and cfg:FindFirstChild(name)
    return v and v.Value
end

local function eggCost(name)
    local ed = Modules:FindFirstChild("EggData")
    local folder = ed and ed:FindFirstChild(name)
    local cost = folder and folder:FindFirstChild("Cost")
    return (cost and cost.Value) or 0
end

local function gearCost(name)
    local gd = Modules:FindFirstChild("GearData")
    local folder = gd and gd:FindFirstChild(name)
    local cost = folder and folder:FindFirstChild("Cost")
    return (cost and cost.Value) or 0
end

local function humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function hrp()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tools()
    local list = {}
    local function grab(container)
        if not container then
            return
        end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                table.insert(list, t)
            end
        end
    end
    grab(LocalPlayer:FindFirstChild("Backpack"))
    grab(LocalPlayer.Character)
    return list
end

local function findTool(pred)
    for _, t in ipairs(tools()) do
        if pred(t) then
            return t
        end
    end
    return nil
end

local function equip(tool)
    local h = humanoid()
    if not (h and tool) then
        return false
    end
    pcall(function()
        h:EquipTool(tool)
    end)
    return tool.Parent == LocalPlayer.Character
end

local function clickOnce()
    if mouse1click then
        pcall(mouse1click)
        return
    end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function activateEquipped()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function()
            tool:Activate()
        end)
    end
    clickOnce()
end

-- GetMouseCF is InvokeClient from the server when you click with an egg/tower equipped
do
    local mouseRemote = Remotes:FindFirstChild("GetMouseCF")
    if mouseRemote then
        local mouse = LocalPlayer:GetMouse()
        local fn = function()
            return S.PlaceCF or mouse.Hit
        end
        if LR and LR.override then
            LR.override(mouseRemote, "OnClientInvoke", fn)
        else
            mouseRemote.OnClientInvoke = fn
        end
    end
end

---------------------------------------------------------------
-- Actions (real remotes)
---------------------------------------------------------------
local function collectMoney()
    fire("CollectionMachine")
    for _, plant in ipairs(ownedModels("PottedPlants")) do
        fire("CollectMoneyFromPlant", plant.Name)
    end
end

local function hatchAll()
    local n = 0
    for _, egg in ipairs(ownedModels("PlacedItems")) do
        if cfgValue(egg, "Type") == "Egg" then
            fire("Hatch", egg.Name)
            local prompt
            for _, d in ipairs(egg:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Name == "HatchPrompt" then
                    prompt = d
                    break
                end
            end
            if prompt and fireproximityprompt then
                pcall(fireproximityprompt, prompt)
            end
            n += 1
        end
    end
    return n
end

local function emptyPots(plot)
    local empty = {}
    if not plot then
        return empty
    end
    local garden = plot:FindFirstChild("Garden")
    local pots = garden and garden:FindFirstChild("Pots")
    if not pots then
        return empty
    end
    for _, pot in ipairs(pots:GetChildren()) do
        local num = tonumber(pot.Name:match("%d+"))
        if num and not pot:GetAttribute("Occupied") then
            table.insert(empty, { inst = pot, n = num })
        end
    end
    table.sort(empty, function(a, b)
        return a.n < b.n
    end)
    return empty
end

local function plantTool()
    return findTool(function(t)
        return t:GetAttribute("isPlant") == true
    end)
end

local function eggTool()
    return findTool(function(t)
        if t:GetAttribute("isPlant") or t:GetAttribute("isGear") then
            return false
        end
        local n = t.Name
        return n:find("Egg", 1, true) ~= nil
    end)
end

local function placePlants()
    local plot = myPlot()
    local pots = emptyPots(plot)
    if #pots == 0 then
        return 0
    end
    local n = 0
    for _, pot in ipairs(pots) do
        local tool = plantTool()
        if not tool then
            break
        end
        equip(tool)
        task.wait(0.08)
        fire("PotInteract", pot.n)
        n += 1
        task.wait(0.12)
    end
    return n
end

local function purchasedLanes(plot)
    local owned = {}
    if not plot then
        return owned
    end
    local ta = plot:FindFirstChild("TowerArea")
    if ta then
        for _, m in ipairs(ta:GetChildren()) do
            local n = tonumber(m.Name:match("%d+"))
            if n and m.Name:find("Purchased", 1, true) == 1 then
                owned[n] = true
            end
        end
    end
    if not next(owned) then
        owned[4] = true
    end
    return owned
end

local function occupiedLanes()
    local used = {}
    for _, m in ipairs(ownedModels("PlacedItems")) do
        local lane = cfgValue(m, "Lane")
        if typeof(lane) == "number" then
            used[lane] = m
        end
    end
    return used
end

local function laneCFrame(plot, lane)
    local wps = plot and plot:FindFirstChild("Waypoints")
    local wp = wps and wps:FindFirstChild("Lane" .. tostring(lane))
    if wp then
        local cf = wp:IsA("BasePart") and wp.CFrame or wp:GetPivot()
        return cf + Vector3.new(0, 2.2, 0)
    end
    return nil
end

local function placeEggs()
    local plot = myPlot()
    if not plot then
        return 0
    end
    local owned = purchasedLanes(plot)
    local used = occupiedLanes()
    local n = 0
    for lane = 1, 7 do
        if owned[lane] and not used[lane] then
            local tool = eggTool()
            if not tool then
                break
            end
            local cf = laneCFrame(plot, lane)
            if not cf then
                break
            end
            S.PlaceCF = cf
            local root = hrp()
            if root then
                pcall(function()
                    root.CFrame = cf + Vector3.new(0, 3, 0)
                end)
            end
            equip(tool)
            task.wait(0.12)
            activateEquipped()
            task.wait(0.18)
            n += 1
        end
    end
    S.PlaceCF = nil
    return n
end

local function buyNamed(name)
    fire("BuyItem", name)
end

local function claimPlaytime()
    for _, id in ipairs(PLAYTIME) do
        fire("ClaimPlaytimeReward", id)
    end
end

local function pickupAll(kind)
    local n = 0
    local remote = (kind == "Totem") and "PickUpTotem" or "PickUp"
    for _, m in ipairs(ownedModels("PlacedItems")) do
        if cfgValue(m, "Type") == kind then
            fire(remote, m.Name)
            n += 1
        end
    end
    return n
end

local function useGearOn(remoteName, models)
    local n = 0
    for _, m in ipairs(models) do
        fire(remoteName, m)
        n += 1
        if n % 8 == 0 then
            task.wait()
        end
    end
    return n
end

local function tpTo(cf)
    local root = hrp()
    if root and cf then
        pcall(function()
            root.CFrame = cf + Vector3.new(0, 4, 0)
        end)
    end
end

local function applySpeed()
    local h = humanoid()
    if h then
        pcall(function()
            h.WalkSpeed = S.Speed
        end)
    end
end

if LR and LR.connect then
    LR.connect(LocalPlayer.CharacterAdded, function()
        task.wait(0.4)
        if S.KeepSpeed then
            applySpeed()
        end
    end)
else
    local c = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.4)
        if S.KeepSpeed then
            applySpeed()
        end
    end)
    onCleanup(function()
        c:Disconnect()
    end)
end

---------------------------------------------------------------
-- Farm loop (yields; never tight-spins)
---------------------------------------------------------------
task.spawn(function()
    while alive() do
        local busy = S.AutoFarm or S.AutoCollect or S.AutoHatch or S.AutoPlacePlants
            or S.AutoPlaceEggs or S.AutoBuy or S.AutoRewards or S.AutoGrow or S.AutoSellPlants
        if busy then
            if S.AutoFarm or S.AutoCollect then
                collectMoney()
            end
            if S.AutoFarm or S.AutoHatch then
                hatchAll()
            end
            if S.AutoFarm or S.AutoPlacePlants then
                placePlants()
            end
            if S.AutoFarm or S.AutoPlaceEggs then
                placeEggs()
            end
            if S.AutoFarm or S.AutoBuy then
                if money() >= eggCost(S.EggName) then
                    buyNamed(S.EggName)
                end
            end
            if S.AutoRewards then
                fire("ClaimDailyReward")
                claimPlaytime()
            end
            if S.AutoGrow then
                fire("RequestGrowth")
            end
            if S.AutoSellPlants then
                fire("Sell", "bulkSell", "Plant")
            end
        end
        task.wait(math.max(0.2, S.FarmDelay))
    end
end)

---------------------------------------------------------------
-- UI
---------------------------------------------------------------
local Farm = Window:Tab({ Title = "Auto Farm", Icon = "sprout" })
Farm:Paragraph({
    Title = "Server-authoritative",
    Desc = "Collect = CollectionMachine. Hatch = Hatch(eggName). Buy = BuyItem(name). Place plants = PotInteract(n). Place eggs = GetMouseCF hook + tool Activate. No client money fakes.",
})
Farm:Toggle({
    Title = "Full auto farm",
    Desc = "Collect + hatch + place plants/eggs + buy selected egg",
    Default = false,
    Callback = function(v)
        S.AutoFarm = v
        notify("Farm", v and "ON" or "OFF")
    end,
})
Farm:Toggle({
    Title = "Auto collect money",
    Default = false,
    Callback = function(v)
        S.AutoCollect = v
    end,
})
Farm:Toggle({
    Title = "Auto hatch eggs",
    Default = false,
    Callback = function(v)
        S.AutoHatch = v
    end,
})
Farm:Toggle({
    Title = "Auto place plants in empty pots",
    Default = false,
    Callback = function(v)
        S.AutoPlacePlants = v
    end,
})
Farm:Toggle({
    Title = "Auto place eggs on empty lanes",
    Default = false,
    Callback = function(v)
        S.AutoPlaceEggs = v
    end,
})
Farm:Toggle({
    Title = "Auto buy selected egg",
    Default = false,
    Callback = function(v)
        S.AutoBuy = v
    end,
})
Farm:Toggle({
    Title = "Auto claim daily + playtime",
    Default = false,
    Callback = function(v)
        S.AutoRewards = v
    end,
})
Farm:Toggle({
    Title = "Auto grow tree",
    Default = false,
    Callback = function(v)
        S.AutoGrow = v
    end,
})
Farm:Slider({
    Title = "Farm delay (s)",
    Value = { Min = 0.2, Max = 2, Default = 0.45 },
    Callback = function(v)
        S.FarmDelay = v
    end,
})
Farm:Dropdown({
    Title = "Egg to buy",
    Values = SHOP_EGGS,
    Value = S.EggName,
    Callback = function(v)
        S.EggName = v
    end,
})

local Instant = Window:Tab({ Title = "Instant", Icon = "zap" })
Instant:Button({
    Title = "Collect all plant money",
    Callback = function()
        collectMoney()
        notify("Collect", "CollectionMachine fired")
    end,
})
Instant:Button({
    Title = "Hatch all placed eggs",
    Callback = function()
        notify("Hatch", tostring(hatchAll()) .. " eggs")
    end,
})
Instant:Button({
    Title = "Place plants in empty pots",
    Callback = function()
        notify("Pots", tostring(placePlants()) .. " placed")
    end,
})
Instant:Button({
    Title = "Place eggs on empty lanes",
    Callback = function()
        notify("Lanes", tostring(placeEggs()) .. " placed")
    end,
})
Instant:Button({
    Title = "Equip best plants",
    Callback = function()
        fire("EquipBestPlants")
        notify("Plants", "EquipBestPlants")
    end,
})
Instant:Button({
    Title = "Grow tree (RequestGrowth)",
    Callback = function()
        local ok, res = fire("RequestGrowth")
        notify("Tree", tostring(res or ok))
    end,
})
Instant:Button({
    Title = "Skip tutorial",
    Callback = function()
        fire("SkipTutorial")
        notify("Tutorial", "SkipTutorial fired")
    end,
})
Instant:Button({
    Title = "Claim daily reward",
    Callback = function()
        fire("ClaimDailyReward")
        notify("Daily", "ClaimDailyReward fired")
    end,
})
Instant:Button({
    Title = "Claim all playtime rewards",
    Callback = function()
        claimPlaytime()
        notify("Playtime", "Reward1-11 fired")
    end,
})
Instant:Button({
    Title = "Resolve offline earnings",
    Callback = function()
        fire("GetOfflineEarnings")
        fire("ResolveOfflineEarnings")
        notify("Offline", "resolve fired")
    end,
})

local Shop = Window:Tab({ Title = "Shop", Icon = "shopping-cart" })
Shop:Dropdown({
    Title = "Egg",
    Values = SHOP_EGGS,
    Value = S.EggName,
    Callback = function(v)
        S.EggName = v
    end,
})
Shop:Button({
    Title = "Buy selected egg",
    Callback = function()
        buyNamed(S.EggName)
        notify("Buy", S.EggName .. " ($" .. tostring(eggCost(S.EggName)) .. ")")
    end,
})
Shop:Button({
    Title = "Buy cheapest (Capybara Egg $100)",
    Callback = function()
        buyNamed("Capybara Egg")
    end,
})
Shop:Dropdown({
    Title = "Gear",
    Values = SHOP_GEAR,
    Value = S.GearName,
    Callback = function(v)
        S.GearName = v
    end,
})
Shop:Button({
    Title = "Buy selected gear",
    Callback = function()
        buyNamed(S.GearName)
        notify("Buy", S.GearName .. " ($" .. tostring(gearCost(S.GearName)) .. ")")
    end,
})
Shop:Button({
    Title = "Buy Hatch Hammer ($1000)",
    Callback = function()
        buyNamed("Hatch Hammer")
    end,
})
Shop:Input({
    Title = "Redeem code",
    Placeholder = "code",
    Callback = function(v)
        S.Code = v
    end,
})
Shop:Button({
    Title = "Redeem",
    Callback = function()
        if S.Code == "" then
            notify("Code", "enter a code first")
            return
        end
        local ok, res = fire("RedeemCode", S.Code)
        notify("Code", tostring(res or ok))
    end,
})

local Sell = Window:Tab({ Title = "Sell", Icon = "banknote" })
Sell:Button({
    Title = "Bulk sell plants",
    Callback = function()
        fire("Sell", "bulkSell", "Plant")
        notify("Sell", "bulkSell Plant")
    end,
})
Sell:Button({
    Title = "Bulk sell capybaras",
    Callback = function()
        fire("Sell", "bulkSell", "Capybara")
        notify("Sell", "bulkSell Capybara")
    end,
})
Sell:Button({
    Title = "Sell equipped item",
    Callback = function()
        fire("Sell", "equippedItem")
        notify("Sell", "equippedItem")
    end,
})
Sell:Toggle({
    Title = "Auto bulk-sell plants (farm loop)",
    Default = false,
    Callback = function(v)
        S.AutoSellPlants = v
    end,
})
Sell:Button({
    Title = "Pick up all towers",
    Callback = function()
        notify("Pickup", tostring(pickupAll("Tower")) .. " towers")
    end,
})
Sell:Button({
    Title = "Pick up all eggs",
    Callback = function()
        notify("Pickup", tostring(pickupAll("Egg")) .. " eggs")
    end,
})
Sell:Button({
    Title = "Pick up all totems",
    Callback = function()
        notify("Pickup", tostring(pickupAll("Totem")) .. " totems")
    end,
})

local Gear = Window:Tab({ Title = "Gear", Icon = "hammer" })
Gear:Paragraph({
    Title = "Uses equipped-item remotes",
    Desc = "Raygun/MegaRaygun/Capyccino/LevelLoaf fire the hovered model id. These delete or feed the target on the server.",
})
Gear:Button({
    Title = "Raygun all my towers/eggs/plants",
    Callback = function()
        local n = 0
        n += useGearOn("Raygun", ownedModels("PlacedItems"))
        n += useGearOn("Raygun", ownedModels("PottedPlants"))
        notify("Raygun", tostring(n) .. " targets")
    end,
})
Gear:Button({
    Title = "Mega Raygun all my stuff",
    Callback = function()
        local n = 0
        n += useGearOn("MegaRaygun", ownedModels("PlacedItems"))
        n += useGearOn("MegaRaygun", ownedModels("PottedPlants"))
        notify("MegaRaygun", tostring(n) .. " targets")
    end,
})
Gear:Button({
    Title = "Capyccino all towers (skip ability)",
    Callback = function()
        notify("Capyccino", tostring(useGearOn("Capyccino", ownedModels("PlacedItems"))))
    end,
})
Gear:Button({
    Title = "Level loaf all towers",
    Callback = function()
        notify("Loaf", tostring(useGearOn("LevelLoaf", ownedModels("PlacedItems"))))
    end,
})

local Fuse = Window:Tab({ Title = "Fuse / Misc", Icon = "combine" })
Fuse:Button({
    Title = "Fuse: place equipped capybara",
    Callback = function()
        fire("FuseAction", "Place", "Capybara")
    end,
})
Fuse:Button({
    Title = "Fuse: place equipped plant",
    Callback = function()
        fire("FuseAction", "Place", "Plant")
    end,
})
Fuse:Button({
    Title = "Fuse: skip wait",
    Callback = function()
        fire("FuseAction", "Skip")
    end,
})
Fuse:Button({
    Title = "Fuse: collect result",
    Callback = function()
        fire("FuseAction", "Collect")
    end,
})
Fuse:Button({
    Title = "TP to my plot",
    Callback = function()
        local plot = myPlot()
        local p = plot and plot:FindFirstChild("TPPart")
        if p then
            tpTo(p.CFrame)
        else
            notify("TP", "plot not found")
        end
    end,
})
Fuse:Button({
    Title = "TP to egg shop",
    Callback = function()
        local map = workspace:FindFirstChild("World")
        map = map and map:FindFirstChild("Map")
        local shop = map and map:FindFirstChild("EggShop")
        if shop then
            tpTo(shop:GetPivot())
        end
    end,
})
Fuse:Button({
    Title = "TP to sell shop",
    Callback = function()
        local map = workspace:FindFirstChild("World")
        map = map and map:FindFirstChild("Map")
        local shop = map and map:FindFirstChild("SellShop")
        if shop then
            tpTo(shop:GetPivot())
        end
    end,
})
Fuse:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 120, Default = 30 },
    Callback = function(v)
        S.Speed = math.floor(v)
        applySpeed()
    end,
})
Fuse:Toggle({
    Title = "Keep speed after respawn",
    Default = true,
    Callback = function(v)
        S.KeepSpeed = v
    end,
})
Fuse:Button({
    Title = "Rejoin this server",
    Callback = function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end,
})

notify("CVP Hub", "RightShift to toggle. Plot " .. (myPlot() and myPlot().Name or "?") .. "  $" .. tostring(money()))

setfpscap(25)
-- Auto Farm + Auto Crate - MM2 (Simplified & Clean)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local SETTINGS = {
    Enabled = true,
    MoveSpeed = 20,
    CollectionRadius = 4.0,
    LoopDelay = 0.1,
    MaxBagCoins = 40,
    AutoRespawn = true,
    YOffset = -2,
}

-- ================= 🚫 NOCLIP + АНТИГРАВИТАЦИЯ =================
local noclipActive = false

local function enableNoClip()
    noclipActive = true
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
    end
end

local function disableNoClip()
    noclipActive = false
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

RunService.Heartbeat:Connect(function()
    if not noclipActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0) -- Простая антигравитация
    end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end)

-- ================= 📡 ОБНАРУЖЕНИЕ РАУНДА =================
local isRoundActive = false

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")
local roundStart = gameplay and gameplay:FindFirstChild("RoundStart")

if roundStart and roundStart:IsA("RemoteEvent") then
    roundStart.OnClientEvent:Connect(function()
        isRoundActive = true
        enableNoClip()
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    isRoundActive = false
    disableNoClip()
    local hum = char:WaitForChild("Humanoid")
    hum.Died:Connect(function()
        isRoundActive = false
        disableNoClip()
    end)
end)

-- ================= 🛠️ ВСПОМОГАТЕЛЬНЫЕ =================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getBagCoins()
    local path = {"MainGUI", "Lobby", "Dock", "CoinBags", "Container", "Coin", "CurrencyFrame", "Icon", "Coins"}
    local obj = LocalPlayer:FindFirstChild("PlayerGui")
    for _, name in ipairs(path) do
        if not obj then return 0 end
        obj = obj:FindFirstChild(name)
    end
    if obj and obj:IsA("TextLabel") then
        return tonumber(string.match(obj.Text, "%d+")) or 0
    end
    return 0
end

-- ================= 💀 РЕСПАВН =================
local isRespawning = false

local function forceRespawn()
    if isRespawning then return end
    isRespawning = true
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Dead)
            hum.Health = 0
        end)
    end
    
    task.wait(3)
    isRespawning = false
end

-- ================= 🪙 ИГНОР МОНЕТ =================
local collectedCoins = {}
local MAX_IGNORED = 10
local IGNORE_DUR = 3.0

local function isCollected(coin)
    local now = tick()
    for _, d in ipairs(collectedCoins) do 
        if d.coin == coin and now < d.time + IGNORE_DUR then return true end 
    end
    return false
end

local function markCollected(coin)
    table.insert(collectedCoins, {coin = coin, time = tick()})
    if #collectedCoins > MAX_IGNORED then table.remove(collectedCoins, 1) end
end

local function getNearestCoin(map, hrp)
    local container = map:FindFirstChild("CoinContainer")
    if not container then return nil, math.huge end
    
    local target, minDist = nil, math.huge
    for _, part in ipairs(container:GetChildren()) do
        if part:IsA("BasePart") and part.Name:lower():find("coin") and not isCollected(part) then
            local dist = (part.Position - hrp.Position).Magnitude
            if dist < minDist then 
                minDist = dist
                target = part 
            end
        end
    end
    return target, minDist
end

-- ================= 🏃 TWEEN =================
local currentTween = nil

local function tweenToTarget(hrp, targetPos)
    if currentTween then pcall(function() currentTween:Cancel() end) end
    
    local dist = (targetPos - hrp.Position).Magnitude
    local moveTime = math.max(dist / SETTINGS.MoveSpeed, 0.1)
    local tweenInfo = TweenInfo.new(moveTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    
    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    currentTween:Play()
end

-- ================= 📦 АВТО-КЕЙСЫ =================
local Shop = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")
local OpenCrate = Shop:WaitForChild("OpenCrate")
local BoxController = Shop:WaitForChild("BoxController")

local boxes = {"KnifeBox1", "KnifeBox2", "KnifeBox3", "KnifeBox4", "KnifeBox5", "GunBox1", "GunBox3"}
local currencies = {"Coins", "Gems", "Key"}

local function openRandomCrate()
    local boxId = boxes[math.random(1, #boxes)]
    for _, currency in ipairs(currencies) do
        local ok, result = pcall(function()
            return OpenCrate:InvokeServer(boxId, "MysteryBox", currency)
        end)
        if ok and result then
            pcall(function() BoxController:Fire({{MysteryBoxId = boxId, RewardedItemId = result}}) end)
            return true
        end
    end
    return false
end

task.spawn(function()
    while SETTINGS.Enabled do
        if openRandomCrate() then
            task.wait(2.5)
        else
            task.wait(5)
        end
    end
end)

-- ================= 🛡️ ANTI-AFK =================
task.spawn(function()
    while task.wait(120) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
        end)
    end
end)

-- ================= 🔄 ГЛАВНЫЙ ЦИКЛ =================
task.spawn(function()
    while SETTINGS.Enabled do
        pcall(function()
            if not isRoundActive then task.wait(1) return end
            
            local hrp = getHRP()
            if not hrp then task.wait(1) return end
            
            -- Защита от падения в бездну
            if hrp.Position.Y < -50 then
                hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
                task.wait(2)
                return
            end
            
            -- Респавн при полном мешке
            if getBagCoins() >= SETTINGS.MaxBagCoins then
                if SETTINGS.AutoRespawn then forceRespawn() end
                task.wait(3)
                return
            end
            
            -- Поиск карты и монеты
            local map = nil
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:FindFirstChild("CoinContainer") then map = obj; break end
            end
            if not map then task.wait(0.1) return end
            
            local coin, dist = getNearestCoin(map, hrp)
            if not coin then task.wait(0.1) return end
            
            local targetPos = Vector3.new(coin.Position.X, coin.Position.Y + SETTINGS.YOffset, coin.Position.Z)
            if dist <= SETTINGS.CollectionRadius then
                markCollected(coin)
                return
            end
            
            tweenToTarget(hrp, targetPos)
        end)
        task.wait(SETTINGS.LoopDelay)
    end
end)

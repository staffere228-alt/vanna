--[[
Auto Farm + Auto Crate - MM2 | FINAL BUILD + RECONNECT FIX | NO SUMMER
- Скорость 20 studs/sec
- АВТО-КЕЙСЫ: только обычные кейсы, без Summer2026Box
- РЕСПАВН: Health=0 + ChangeState(Dead)
- ПУТЬ К МОНЕТАМ: MainGUI.Lobby.Dock.CoinBags...
- NoClip ULTIMATE + Антигравитация
- YOffset = -3
- Исправленный reconnect под 319 / 317 / 304
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ================= 🛠️ СЕРВИСЫ =================
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local CoreGui = nil
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    wait()
    LocalPlayer = Players.LocalPlayer
end

-- ================= ⚙️ НАСТРОЙКИ =================
local SETTINGS = {
    Enabled = true,
    MoveSpeed = 20,
    CollectionRadius = 4.0,
    LoopDelay = 0.1,
    MaxBagCoins = 40,
    AutoRespawn = true,
    SpawnWaitTime = 3.0,
    YOffset = -3,
    ReconnectDelay = 2,

    -- Авто-кейсы
    AutoCrate = true,
    CrateMode = "All", -- All / Random / Off (All теперь означает только обычные кейсы)
    CrateDelay = 0.7,
    CrateFailDelay = 1.0,
}

local MAX_IGNORED = 10
local IGNORE_DUR = 3.0
local isReconnecting = false
local isRespawning = false

-- ================= 🔌 RECONNECT FIX =================
local RECONNECT_CODES = {
    ["319"] = true,
    ["317"] = true,
    ["304"] = true,
    ["267"] = true,
    ["279"] = true,
    ["529"] = true,
}

local RECONNECT_PHRASES = {
    "disconnected",
    "connection",
    "timed out",
    "timeout",
    "network",
    "unable to connect",
    "server has shut down",
    "check your internet",
}

local function isDisconnectText(text)
    text = tostring(text or "")
    if text == "" then
        return false, nil
    end

    for code in pairs(RECONNECT_CODES) do
        if text:find(code, 1, true) then
            return true, "code " .. code
        end
    end

    local lower = text:lower()
    for _, phrase in ipairs(RECONNECT_PHRASES) do
        if lower:find(phrase, 1, true) then
            return true, "phrase " .. phrase
        end
    end

    return false, nil
end

local function forceReconnect(reason)
    if isReconnecting then
        return
    end

    isReconnecting = true
    warn("🔌 [RECONNECT] Причина: " .. tostring(reason))

    spawn(function()
        wait(SETTINGS.ReconnectDelay)

        for attempt = 1, 6 do
            local ok, err = pcall(function()
                TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
            end)

            if not ok then
                ok, err = pcall(function()
                    TeleportService:Teleport(game.PlaceId)
                end)
            end

            if ok then
                warn("🔌 [RECONNECT] Teleport вызван, попытка: " .. attempt)
                return
            end

            warn("🔌 [RECONNECT] Попытка " .. attempt .. " ошибка: " .. tostring(err))
            wait(1.5 * attempt)
        end

        warn("🔌 [RECONNECT] TeleportService не смог перезапустить. Нужен внешний auto-rejoin или ручной перезаход.")
        wait(20)
        isReconnecting = false
    end)

    -- Страховка от вечного isReconnecting = true
    spawn(function()
        wait(25)
        isReconnecting = false
    end)
end

-- Ловим ErrorMessageChanged, если он вообще сработает
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(errorMessage)
        local hit, why = isDisconnectText(errorMessage)
        if hit then
            forceReconnect("ErrorMessageChanged: " .. tostring(why))
        end
    end)
end)

-- Ловим системные ошибки через CoreGui / RobloxPromptGui
pcall(function()
    if not CoreGui then
        warn("⚠️ [RECONNECT] CoreGui недоступен, prompt-ловушка не будет работать.")
        return
    end

    local function scanObject(obj)
        pcall(function()
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local hit, why = isDisconnectText(obj.Text)
                if hit then
                    forceReconnect("Prompt: " .. tostring(why))
                end
            end
        end)
    end

    local function hookRoot(root)
        pcall(function()
            if root:GetAttribute("RC_HOOKED") then
                return
            end

            root:SetAttribute("RC_HOOKED", true)

            for _, desc in ipairs(root:GetDescendants()) do
                scanObject(desc)
            end

            root.DescendantAdded:Connect(scanObject)
        end)
    end

    local function attachPromptGui(promptGui)
        hookRoot(promptGui)

        local overlay = promptGui:FindFirstChild("promptOverlay")
        if overlay then
            hookRoot(overlay)

            overlay.ChildAdded:Connect(function(child)
                wait(0.1)
                hookRoot(child)
            end)
        end
    end

    local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
    if promptGui then
        attachPromptGui(promptGui)
    end

    CoreGui.ChildAdded:Connect(function(child)
        if child.Name == "RobloxPromptGui" then
            wait(0.1)
            attachPromptGui(child)
        end
    end)
end)

-- Дополнительно ловим сетевые события, если они доступны
pcall(function()
    local NetworkClient = game:GetService("NetworkClient")

    pcall(function()
        NetworkClient.ConnectionFailed:Connect(function(message)
            forceReconnect("NetworkClient.ConnectionFailed: " .. tostring(message))
        end)
    end)

    pcall(function()
        NetworkClient.Disconnected:Connect(function(message)
            forceReconnect("NetworkClient.Disconnected: " .. tostring(message))
        end)
    end)
end)

-- Перестраховка через PlayerRemoving
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        forceReconnect("PlayerRemoving")
    end
end)

-- Перестраховка через OnTeleport
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed or state == Enum.TeleportState.Started then
        forceReconnect("OnTeleport: " .. tostring(state))
    end
end)

-- Перестраховка через Heartbeat
local consecutiveFailures = 0
RunService.Heartbeat:Connect(function()
    if not LocalPlayer or not LocalPlayer.Parent then
        consecutiveFailures = consecutiveFailures + 1
        if consecutiveFailures >= 5 and not isReconnecting then
            forceReconnect("Heartbeat: LocalPlayer missing")
        end
    else
        consecutiveFailures = 0
    end
end)

-- ================= 🖱️ ВЫБОР УСТРОЙСТВА =================
local function selectDevice()
    while wait(0.1) do
        local DeviceSelectGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("DeviceSelect")
        if DeviceSelectGui then
            local Container = DeviceSelectGui:WaitForChild("Container")
            local button = Container:WaitForChild("Phone"):WaitForChild("Button")
            local bp = button.AbsolutePosition
            local bs = button.AbsoluteSize

            VirtualInputManager:SendMouseButtonEvent(bp.X + bs.X / 2, bp.Y + bs.Y / 2, 0, true, game, 1)
            wait(0.1)
            VirtualInputManager:SendMouseButtonEvent(bp.X + bs.X / 2, bp.Y + bs.Y / 2, 0, false, game, 1)
            break
        end
    end
end

spawn(selectDevice)
wait(10)

-- ================= 🔄 СОСТОЯНИЕ =================
local isRoundActive = false
local collectedCoins = {}
local currentTween = nil
local isMoving = false

-- ================= 🚫 NOCLIP ULTIMATE + АНТИГРАВИТАЦИЯ =================
local noclipActive = false
local antiGravForce = nil

local function setupAntiGravity(hrp)
    if antiGravForce then
        pcall(function()
            antiGravForce:Destroy()
        end)
    end

    local att = hrp:FindFirstChild("AntiGravAttachment")
    if not att then
        att = Instance.new("Attachment")
        att.Name = "AntiGravAttachment"
        att.Parent = hrp
    end

    local mass = hrp.AssemblyMass
    if mass <= 0 then
        mass = 5
    end

    local vf = Instance.new("VectorForce")
    vf.Name = "AntiGravity"
    vf.Attachment0 = att
    vf.Force = Vector3.new(0, mass * 196.2, 0)
    vf.RelativeTo = Enum.ActuatorRelativeTo.World
    vf.ApplyAtCenterOfMass = true
    vf.Parent = hrp

    antiGravForce = vf
end

local function removeAntiGravity()
    if antiGravForce then
        pcall(function()
            antiGravForce:Destroy()
        end)
        antiGravForce = nil
    end
end

local function applyUltimateNoClip(character)
    if not character then
        return
    end

    pcall(function()
        PhysicsService:RegisterCollisionGroup("UltimateNC")
        PhysicsService:CollisionGroupSetCollidable("UltimateNC", "Default", false)
    end)

    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true

        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)

        for _, state in ipairs({
            Enum.HumanoidStateType.GettingUp,
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.Freefall,
            Enum.HumanoidStateType.Jumping,
            Enum.HumanoidStateType.Landed,
            Enum.HumanoidStateType.Running,
            Enum.HumanoidStateType.RunningNoPhysics,
            Enum.HumanoidStateType.Seated,
            Enum.HumanoidStateType.Swimming,
        }) do
            pcall(function()
                hum:SetStateEnabled(state, false)
            end)
        end
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Massless = true

            pcall(function()
                part.CollisionGroup = "UltimateNC"
            end)
        end
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and not antiGravForce then
        setupAntiGravity(hrp)
    end
end

local function enableNoClip()
    if noclipActive then
        return
    end

    noclipActive = true
end

local function disableNoClip()
    if not noclipActive then
        return
    end

    noclipActive = false

    if currentTween then
        pcall(function()
            currentTween:Cancel()
        end)
        currentTween = nil
    end

    isMoving = false
    removeAntiGravity()

    local char = LocalPlayer.Character
    if not char then
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false

        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)

        for _, state in ipairs({
            Enum.HumanoidStateType.GettingUp,
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.Freefall,
            Enum.HumanoidStateType.Jumping,
            Enum.HumanoidStateType.Landed,
            Enum.HumanoidStateType.Running,
            Enum.HumanoidStateType.RunningNoPhysics,
            Enum.HumanoidStateType.Seated,
            Enum.HumanoidStateType.Swimming,
        }) do
            pcall(function()
                hum:SetStateEnabled(state, true)
            end)
        end
    end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
            part.Massless = false

            pcall(function()
                part.CollisionGroup = "Default"
            end)
        end
    end
end

RunService.Heartbeat:Connect(function()
    if noclipActive then
        pcall(function()
            applyUltimateNoClip(LocalPlayer.Character)

            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and antiGravForce then
                local mass = hrp.AssemblyMass
                if mass <= 0 then
                    mass = 5
                end

                antiGravForce.Force = Vector3.new(0, mass * 196.2, 0)
            end
        end)
    end
end)

-- ================= 📡 ОБНАРУЖЕНИЕ РАУНДА =================
local function setupRoundDetection()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local gameplay = remotes and remotes:FindFirstChild("Gameplay")
    local roundStart = gameplay and gameplay:FindFirstChild("RoundStart")

    if roundStart and roundStart:IsA("RemoteEvent") then
        roundStart.OnClientEvent:Connect(function()
            isRoundActive = true
            enableNoClip()
        end)
    else
        delay(3, function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                isRoundActive = true
                enableNoClip()
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    isRoundActive = false
    disableNoClip()

    wait(1)

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            isRoundActive = false
            disableNoClip()
        end)
    end
end)

-- Если уже есть персонаж при запуске
if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    delay(5, function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            isRoundActive = true
            enableNoClip()
        end
    end)
end

-- ================= 🛠️ ВСПОМОГАТЕЛЬНЫЕ =================
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getBagCoins()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return 0
    end

    local function sf(p, n)
        return p and p:FindFirstChild(n)
    end

    local obj = sf(sf(sf(sf(sf(sf(sf(sf(
        playerGui,
        "MainGUI"),
        "Lobby"),
        "Dock"),
        "CoinBags"),
        "Container"),
        "Coin"),
        "CurrencyFrame"),
        "Icon")

    if obj then
        obj = obj:FindFirstChild("Coins")
    end

    if not obj then
        return 0
    end

    local text = obj:IsA("TextLabel") and obj.Text or ""
    return tonumber(string.match(text, "%d+") or "0") or 0
end

-- ================= 💀 РЕСПАВН =================
local function forceRespawn()
    if isRespawning then
        print("⚠️ Респавн уже идёт...")
        return
    end

    isRespawning = true
    print("💀 Запуск респавна...")

    local char = LocalPlayer.Character
    if not char then
        print("❌ Нет персонажа!")
        isRespawning = false
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        print("❌ Нет Humanoid!")
        isRespawning = false
        return
    end

    if currentTween then
        pcall(function()
            currentTween:Cancel()
        end)
        currentTween = nil
    end

    isMoving = false

    print("💀 Применяю ChangeState(Dead) + Health=0...")
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Dead)
        hum.Health = 0
    end)

    print("⏳ Ожидание респавна (" .. SETTINGS.SpawnWaitTime .. " сек)...")
    wait(SETTINGS.SpawnWaitTime)

    local newChar = LocalPlayer.Character
    if newChar and newChar ~= char then
        print("✅ Новый персонаж появился!")

        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            enableNoClip()
            print("✅ NoClip включён")
        end
    else
        print("⚠️ Персонаж не изменился, пробую Destroy...")
        pcall(function()
            char:Destroy()
        end)

        wait(2)

        local retryChar = LocalPlayer.Character
        if retryChar then
            local retryHrp = retryChar:WaitForChild("HumanoidRootPart", 5)
            if retryHrp then
                enableNoClip()
                print("✅ NoClip включён после retry")
            end
        else
            warn("❌ Респавн не удался, пробую reconnect...")
            forceReconnect("Respawn failed")
        end
    end

    isRespawning = false
    print("✅ Респавн завершён")
end

-- ================= 🪙 ИГНОР МОНЕТ =================
local function isCollected(coin)
    local now = tick()

    for _, d in ipairs(collectedCoins) do
        if d.coin == coin and now < d.time + IGNORE_DUR then
            return true
        end
    end

    return false
end

local function markCollected(coin)
    table.insert(collectedCoins, {coin = coin, time = tick()})

    if #collectedCoins > MAX_IGNORED then
        table.remove(collectedCoins, 1)
    end
end

local function getNearestCoin(map, hrp)
    if not map or not hrp then
        return nil, math.huge
    end

    local container = map:FindFirstChild("CoinContainer")
    if not container then
        return nil, math.huge
    end

    local target, minDist = nil, math.huge

    for _, part in next, container:GetChildren() do
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

-- ================= 🚀 TWEEN =================
local function tweenToTarget(hrp, targetPos)
    if currentTween then
        pcall(function()
            currentTween:Cancel()
        end)
    end

    local dist = (targetPos - hrp.Position).Magnitude
    local moveTime = math.max(dist / SETTINGS.MoveSpeed, 0.1)
    local tweenInfo = TweenInfo.new(moveTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    isMoving = true

    currentTween.Completed:Connect(function()
        isMoving = false
        currentTween = nil
    end)

    currentTween:Play()
end

-- ================= 📦 АВТО-КЕЙСЫ =================
local Shop = nil
local OpenCrate = nil
local BoxController = nil

local function refreshCrateRemotes()
    pcall(function()
        local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not Remotes then
            return
        end

        Shop = Remotes:FindFirstChild("Shop")
        if not Shop then
            return
        end

        OpenCrate = Shop:FindFirstChild("OpenCrate")
        BoxController = Shop:FindFirstChild("BoxController")
    end)
end

refreshCrateRemotes()

-- Обычные кейсы
local RANDOM_BOXES = {
    "KnifeBox1",
    "KnifeBox2",
    "KnifeBox3",
    "KnifeBox4",
    "KnifeBox5",
    "GunBox1",
    "GunBox3",
}

local RANDOM_CURRENCIES = {
    "Coins",
    "Gems",
    "Key",
}

local function fireBoxController(payload)
    if not BoxController then
        return
    end

    pcall(function()
        if typeof(BoxController.FireServer) == "function" then
            BoxController:FireServer(payload)
        elseif typeof(BoxController.InvokeServer) == "function" then
            BoxController:InvokeServer(payload)
        end
    end)
end

local function tryOpenCrate(boxId, currency)
    if not OpenCrate then
        return false, nil
    end

    local ok, item = pcall(function()
        return OpenCrate:InvokeServer(boxId, "MysteryBox", currency)
    end)

    if ok and item ~= nil and item ~= false then
        fireBoxController({{
            MysteryBoxId = boxId,
            RewardedItemId = item,
        }})

        print("✅ [CRATE] Кейс: " .. tostring(boxId) .. " | Валюта: " .. tostring(currency) .. " | Выпало: " .. tostring(item))
        return true, item
    end

    return false, nil
end

local function openRandomCrate()
    for _, boxId in ipairs(RANDOM_BOXES) do
        for _, currency in ipairs(RANDOM_CURRENCIES) do
            local success, item = tryOpenCrate(boxId, currency)
            if success then
                return true, boxId, currency, item
            end
        end
    end

    return false
end

spawn(function()
    if not SETTINGS.AutoCrate or SETTINGS.CrateMode == "Off" then
        print("📦 [CRATE] Авто-кейсы выключены")
        return
    end

    local timeout = 0
    while SETTINGS.Enabled and timeout < 30 and (not OpenCrate or not BoxController) do
        refreshCrateRemotes()
        wait(1)
        timeout = timeout + 1
    end

    if not OpenCrate or not BoxController then
        warn("❌ [CRATE] Не найдены ремменты OpenCrate/BoxController. Авто-кейсы остановлены.")
        return
    end

    print("🔥 [CRATE] Авто-открытие обычных кейсов: " .. tostring(SETTINGS.CrateMode))

    local waitingForCurrency = false

    while SETTINGS.Enabled do
        local success = false

        if SETTINGS.CrateMode == "Random" then
            success = openRandomCrate()

        elseif SETTINGS.CrateMode == "All" then
            -- All теперь означает только обычные кейсы
            success = openRandomCrate()

        else
            if not waitingForCurrency then
                warn("❌ [CRATE] Неизвестный CrateMode: " .. tostring(SETTINGS.CrateMode))
                waitingForCurrency = true
            end

            wait(2)
        end

        if success then
            if waitingForCurrency then
                print("💰 [CRATE] Снова есть валюта/ключи, продолжаю открывать.")
                waitingForCurrency = false
            end

            wait(SETTINGS.CrateDelay)
        else
            if not waitingForCurrency then
                warn("⏳ [CRATE] Пока не удалось открыть ни один кейс. Продолжаю без остановки.")
                waitingForCurrency = true
            end

            wait(SETTINGS.CrateFailDelay)
        end
    end
end)

-- ================= 🛡️ ANTI-AFK =================
spawn(function()
    while wait(120) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
        end)
    end
end)

-- ================= 🎯 ГЛАВНЫЙ ЦИКЛ =================
setupRoundDetection()

local coinCounter = 0
local lastTarget = nil

spawn(function()
    print("✅ AUTO FARM + AUTO CRATE ACTIVE")
    print("   Speed: " .. SETTINGS.MoveSpeed .. " | YOffset: " .. SETTINGS.YOffset)
    print("   💀 Респавн: при " .. SETTINGS.MaxBagCoins .. " монетах")
    print("   📦 Авто-кейсы: только обычные")
    print("   🎯 Путь: MainGUI.Lobby.Dock.CoinBags...")
    print("")

    while SETTINGS.Enabled do
        pcall(function()
            if not isRoundActive then
                wait(1)
                return
            end

            local hrp = getHRP()
            if not hrp then
                wait(1)
                return
            end

            if hrp.Position.Y < -50 then
                if currentTween then
                    currentTween:Cancel()
                    currentTween = nil
                end

                isMoving = false
                hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
                wait(2)
                return
            end

            local currentBag = getBagCoins()

            if currentBag >= SETTINGS.MaxBagCoins then
                print("🎒 [FARM] МЕШОК ПОЛНЫЙ: " .. currentBag .. "/" .. SETTINGS.MaxBagCoins)

                if currentTween then
                    currentTween:Cancel()
                    currentTween = nil
                end

                isMoving = false

                if SETTINGS.AutoRespawn and not isRespawning then
                    forceRespawn()
                end

                wait(SETTINGS.SpawnWaitTime)
                return
            end

            local map
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:FindFirstChild("CoinContainer") then
                    map = obj
                    break
                end
            end

            if not map then
                wait(SETTINGS.LoopDelay)
                return
            end

            local coin, dist = getNearestCoin(map, hrp)

            if not coin then
                lastTarget = nil
                wait(SETTINGS.LoopDelay)
                return
            end

            local targetPos = Vector3.new(
                coin.Position.X,
                coin.Position.Y + SETTINGS.YOffset,
                coin.Position.Z
            )

            if dist <= SETTINGS.CollectionRadius then
                markCollected(coin)
                lastTarget = nil
                coinCounter = coinCounter + 1

                if coinCounter % 10 == 0 then
                    print("💰 [FARM] Собрано: " .. coinCounter .. " | Мешок: " .. currentBag .. "/" .. SETTINGS.MaxBagCoins)
                end

                return
            end

            if not isMoving or lastTarget ~= coin then
                lastTarget = coin
                tweenToTarget(hrp, targetPos)
            end
        end)

        wait(SETTINGS.LoopDelay)
    end
end)

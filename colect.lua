-- 📦 SCRIPT 1: AUTO ACCEPT & COLLECT + AUTO DECLINE AFTER 10 SEC
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trade = ReplicatedStorage:WaitForChild("Trade")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local AcceptRequest = Trade:WaitForChild("AcceptRequest")
local UpdateTrade   = Trade:WaitForChild("UpdateTrade")
local AcceptTrade   = Trade:WaitForChild("AcceptTrade")
local StartTrade    = Trade:WaitForChild("StartTrade")
local DeclineTrade  = Trade:WaitForChild("DeclineTrade")

-- ⚙️ НАСТРОЙКИ
local SETTINGS = {
    DeclineAfterSeconds = 10,   -- если трейд висит дольше 10 секунд — отклоняем
    CheckInterval = 0.5,        -- как часто проверять зависший трейд
    PostDeclineCooldown = 2,    -- пауза после отклонения
    AcceptInterval = 0.35,      -- как часто пытаться принять трейд
    Debug = false,              -- включи true, если нужно посмотреть, что приходит в UpdateTrade
}

local isInTrade = false
local currentLastOffer = nil
local latestTradeData = nil
local tradePartner = nil
local tradeStartTime = nil
local cooldownUntil = 0
local partnerAccepted = false

-- 🧹 Сброс состояния трейда
local function resetTradeState(reason)
    isInTrade = false
    currentLastOffer = nil
    latestTradeData = nil
    tradePartner = nil
    tradeStartTime = nil
    partnerAccepted = false

    if reason then
        print("🧹 Trade state reset:", reason)
    end
end

local function debugPrint(...)
    if SETTINGS.Debug then
        print(...)
    end
end

-- 🔍 Ищем в таблице что-то похожее на accepted / ready / confirmed
local function deepFindAccepted(tbl, depth)
    depth = depth or 0

    if type(tbl) ~= "table" or depth > 5 then
        return false
    end

    for key, value in pairs(tbl) do
        local keyLower = tostring(key):lower()

        if keyLower:find("accept") or keyLower:find("ready") or keyLower:find("confirm") then
            if value == true or value == 1 or tostring(value):lower() == "true" then
                return true
            end
        end

        if type(value) == "table" then
            if deepFindAccepted(value, depth + 1) then
                return true
            end
        end
    end

    return false
end

-- 📦 Безопасная отправка RemoteEvent
local function safeFire(remote, ...)
    pcall(function()
        remote:FireServer(...)
    end)
end

-- ✅ Пробуем подтвердить трейд разными вариантами
local function tryAcceptTrade()
    -- Вариант 1: просто AcceptTrade
    safeFire(AcceptTrade)

    -- Вариант 2: если есть LastOffer
    if currentLastOffer ~= nil then
        safeFire(AcceptTrade, currentLastOffer)
        safeFire(AcceptTrade, game.PlaceId * 3, currentLastOffer)
    end

    -- Вариант 3: если есть Offer внутри последнего UpdateTrade
    if type(latestTradeData) == "table" then
        if latestTradeData.Offer ~= nil then
            safeFire(AcceptTrade, latestTradeData.Offer)
            safeFire(AcceptTrade, game.PlaceId * 3, latestTradeData.Offer)
        end

        if latestTradeData.LastOffer ~= nil and latestTradeData.LastOffer ~= currentLastOffer then
            safeFire(AcceptTrade, latestTradeData.LastOffer)
            safeFire(AcceptTrade, game.PlaceId * 3, latestTradeData.LastOffer)
        end
    end
end

-- 🔄 Отслеживание начала трейда
StartTrade.OnClientEvent:Connect(function(data, partnerName)
    isInTrade = true
    tradePartner = partnerName
    currentLastOffer = nil
    latestTradeData = nil
    partnerAccepted = false
    tradeStartTime = os.clock()

    print("✅ Trade started with " .. tostring(partnerName))
end)

-- ❌ Сервер сказал, что трейд отклонён/закрыт
DeclineTrade.OnClientEvent:Connect(function()
    resetTradeState("DeclineTrade event received")
    cooldownUntil = os.clock() + SETTINGS.PostDeclineCooldown
    print("❌ Trade declined/ended")
end)

-- 🎉 Сервер сказал, что трейд завершён
AcceptTrade.OnClientEvent:Connect(function()
    resetTradeState("AcceptTrade event received")
    print("🎉 Trade completed! Items collected.")
end)

-- 📡 Перехват обновлений трейда
UpdateTrade.OnClientEvent:Connect(function(data)
    latestTradeData = data

    if SETTINGS.Debug then
        print("📦 UpdateTrade raw data:", data)

        if type(data) == "table" then
            for k, v in pairs(data) do
                print("   Key:", tostring(k), "| Type:", typeof(v), "| Value:", tostring(v))
            end
        end
    end

    if type(data) == "table" then
        if data.LastOffer ~= nil then
            currentLastOffer = data.LastOffer
            debugPrint("📌 Found LastOffer")
        end

        if data.Offer ~= nil then
            currentLastOffer = data.Offer
            debugPrint("📌 Found Offer")
        end

        if deepFindAccepted(data) then
            partnerAccepted = true
            debugPrint("🟢 Detected partner accepted trade")
        end
    end
end)

-- 🔹 Ловим входящие запросы
task.spawn(function()
    while task.wait(1.2) do
        if not isInTrade and os.clock() >= cooldownUntil then
            safeFire(AcceptRequest)
        end
    end
end)

-- 🔹 Авто-подтверждение трейда
task.spawn(function()
    while task.wait(SETTINGS.AcceptInterval) do
        if isInTrade and os.clock() >= cooldownUntil then
            -- Пытаемся принять, если есть хоть какие-то данные о трейде
            if currentLastOffer ~= nil or partnerAccepted or latestTradeData ~= nil then
                tryAcceptTrade()
            end
        end
    end
end)

-- ⏰ Анти-зависание: если трейд висит дольше 10 секунд — отклоняем
task.spawn(function()
    while task.wait(SETTINGS.CheckInterval) do
        if isInTrade and tradeStartTime then
            local elapsed = os.clock() - tradeStartTime

            if elapsed >= SETTINGS.DeclineAfterSeconds then
                print("⏰ Trade with " .. tostring(tradePartner) .. " stuck for " .. math.floor(elapsed) .. "s. Declining...")

                safeFire(DeclineTrade)

                -- Если сервер не прислал событие DeclineTrade, принудительно сбрасываем состояние
                task.delay(1.5, function()
                    if isInTrade then
                        resetTradeState("Force reset after Decline timeout")
                        cooldownUntil = os.clock() + SETTINGS.PostDeclineCooldown
                    end
                end)
            end
        end
    end
end)

print("🟢 Script 1 Loaded: Auto-Accept & Collect + Auto Decline after 10s")

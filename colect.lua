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
}

local isInTrade = false
local currentLastOffer = nil
local tradePartner = nil
local tradeStartTime = nil
local cooldownUntil = 0

-- 🧹 Сброс состояния трейда
local function resetTradeState(reason)
    isInTrade = false
    currentLastOffer = nil
    tradePartner = nil
    tradeStartTime = nil

    if reason then
        print("🧹 Trade state reset:", reason)
    end
end

-- 🔄 Отслеживание состояния трейда
StartTrade.OnClientEvent:Connect(function(data, partnerName)
    isInTrade = true
    tradePartner = partnerName
    currentLastOffer = nil
    tradeStartTime = os.clock()

    print(`✅ Trade started with {partnerName}`)
end)

DeclineTrade.OnClientEvent:Connect(function()
    resetTradeState("DeclineTrade event received")
    cooldownUntil = os.clock() + SETTINGS.PostDeclineCooldown
    print("❌ Trade declined/ended")
end)

AcceptTrade.OnClientEvent:Connect(function()
    resetTradeState("AcceptTrade event received")
    print("🎉 Trade completed! Items collected.")
end)

-- 📡 Перехват LastOffer от сервера
UpdateTrade.OnClientEvent:Connect(function(data)
    if data and data.LastOffer then
        currentLastOffer = data.LastOffer
    end
end)

-- 🔹 Ловим входящие запросы
task.spawn(function()
    while task.wait(1.2) do
        if not isInTrade and os.clock() >= cooldownUntil then
            pcall(function()
                AcceptRequest:FireServer()
            end)
        end
    end
end)

-- 🔹 Авто-подтверждение трейда
task.spawn(function()
    while task.wait(0.25) do
        if isInTrade and currentLastOffer then
            pcall(function()
                AcceptTrade:FireServer(game.PlaceId * 3, currentLastOffer)
            end)
        end
    end
end)

-- ⏰ Анти-зависание: если трейд висит дольше 10 секунд — отклоняем
task.spawn(function()
    while task.wait(SETTINGS.CheckInterval) do
        if isInTrade and tradeStartTime then
            local elapsed = os.clock() - tradeStartTime

            if elapsed >= SETTINGS.DeclineAfterSeconds then
                print(`⏰ Trade with {tostring(tradePartner)} stuck for {math.floor(elapsed)}s. Declining...`)

                pcall(function()
                    DeclineTrade:FireServer()
                end)

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

-- 📦 AUTO ACCEPT TRADE + DECLINE AFTER 10 SEC
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trade = ReplicatedStorage:WaitForChild("Trade")

local AcceptRequest = Trade:WaitForChild("AcceptRequest")
local UpdateTrade   = Trade:WaitForChild("UpdateTrade")
local AcceptTrade   = Trade:WaitForChild("AcceptTrade")
local StartTrade    = Trade:WaitForChild("StartTrade")
local DeclineTrade  = Trade:WaitForChild("DeclineTrade")

local isInTrade = false
local lastOffer = nil
local tradeStartTime = 0

local function resetTrade()
    isInTrade = false
    lastOffer = nil
    tradeStartTime = 0
end

-- Трейд начался
StartTrade.OnClientEvent:Connect(function(data, partnerName)
    isInTrade = true
    lastOffer = nil
    tradeStartTime = os.clock()
    print("✅ Trade started")
end)

-- Трейд отклонён/закрыт
DeclineTrade.OnClientEvent:Connect(function()
    resetTrade()
    print("❌ Trade declined/ended")
end)

-- Трейд завершён
AcceptTrade.OnClientEvent:Connect(function()
    resetTrade()
    print("🎉 Trade completed")
end)

-- Получаем обновления трейда
UpdateTrade.OnClientEvent:Connect(function(data)
    if not isInTrade then
        isInTrade = true
        tradeStartTime = os.clock()
    end

    if type(data) == "table" then
        lastOffer = data.LastOffer or data.Offer or lastOffer
    else
        lastOffer = data
    end
end)

-- Принимаем входящие запросы
task.spawn(function()
    while task.wait(1) do
        if not isInTrade then
            pcall(function()
                AcceptRequest:FireServer()
            end)
        end
    end
end)

-- Постоянно подтверждаем трейд
task.spawn(function()
    while task.wait(0.3) do
        if isInTrade then
            pcall(function()
                AcceptTrade:FireServer()
            end)

            if lastOffer ~= nil then
                pcall(function()
                    AcceptTrade:FireServer(game.PlaceId * 3, lastOffer)
                end)
            end
        end
    end
end)

-- Если трейд висит дольше 10 секунд — отклоняем
task.spawn(function()
    while task.wait(0.5) do
        if isInTrade and tradeStartTime ~= 0 then
            local elapsed = os.clock() - tradeStartTime

            if elapsed >= 10 then
                print("⏰ Trade stuck for 10s, declining...")

                pcall(function()
                    DeclineTrade:FireServer()
                end)

                task.delay(1, function()
                    if isInTrade then
                        resetTrade()
                    end
                end)
            end
        end
    end
end)

print("🟢 Auto Accept + Decline after 10s loaded")

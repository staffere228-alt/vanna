-- 📦 SCRIPT 1: AUTO ACCEPT & COLLECT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trade = ReplicatedStorage:WaitForChild("Trade")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local AcceptRequest = Trade:WaitForChild("AcceptRequest")
local UpdateTrade   = Trade:WaitForChild("UpdateTrade")
local AcceptTrade   = Trade:WaitForChild("AcceptTrade")
local StartTrade    = Trade:WaitForChild("StartTrade")
local DeclineTrade  = Trade:WaitForChild("DeclineTrade")

local isInTrade = false
local currentLastOffer = nil
local tradePartner = nil

-- 🔄 Отслеживание состояния трейда
StartTrade.OnClientEvent:Connect(function(data, partnerName)
    isInTrade = true
    tradePartner = partnerName
    currentLastOffer = nil
    print(`✅ Trade started with {partnerName}`)
end)

DeclineTrade.OnClientEvent:Connect(function()
    isInTrade = false
    currentLastOffer = nil
    tradePartner = nil
    print("❌ Trade declined/ended")
end)

AcceptTrade.OnClientEvent:Connect(function()
    isInTrade = false
    currentLastOffer = nil
    tradePartner = nil
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
        if not isInTrade then
            pcall(function() AcceptRequest:FireServer() end)
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

print("🟢 Script 1 Loaded: Auto-Accept & Collect")

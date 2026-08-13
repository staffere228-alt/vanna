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

-- ==========================================================
-- ▶ ANTI-AFK + RECONNECT
-- ==========================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Ждём LocalPlayer, если вдруг ещё не доступен
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local VirtualUser
pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local SETTINGS = {
    ReconnectDelay = 3, -- задержка перед реконнектом в секундах
}

local isReconnecting = false

-- Анти-АФК
spawn(function()
    while wait(120) do
        pcall(function()
            if VirtualUser then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(math.random(100, 800), math.random(100, 600)))
            end
        end)
    end
end)

-- Реконнект
local function forceReconnect(reason)
    if isReconnecting then return end

    -- Чтобы в Studio не пытался телепортировать и не блокировал скрипт
    if RunService:IsStudio() then
        warn("🔌 Reconnect skipped in Studio: " .. tostring(reason))
        return
    end

    isReconnecting = true
    print("🔌 Reconnecting: " .. tostring(reason))

    spawn(function()
        wait(SETTINGS.ReconnectDelay)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)

    while true do
        wait(1)
        if not LocalPlayer or not LocalPlayer.Parent then
            break
        end
    end
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(errorMessage)
        if errorMessage and errorMessage ~= "" then
            forceReconnect("Error: " .. errorMessage)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        forceReconnect("PlayerRemoving")
    end
end)

LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed or state == Enum.TeleportState.Started then
        forceReconnect("OnTeleport: " .. tostring(state))
    end
end)

local consecutiveFailures = 0
RunService.Heartbeat:Connect(function()
    if not LocalPlayer or not LocalPlayer.Parent then
        consecutiveFailures = consecutiveFailures + 1
        if consecutiveFailures >= 3 and not isReconnecting then
            forceReconnect("Heartbeat")
        end
    else
        consecutiveFailures = 0
    end
end)

print("🟢 Anti-AFK + Reconnect loaded")

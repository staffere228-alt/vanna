setfpscap(25)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local SPEED, RADIUS, YOFF = 20, 4, -2
local active, tween = false, nil

-- NoClip + антигравитация
RunService.Heartbeat:Connect(function()
    if not active then return end
    local c = LP.Character if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then h.PlatformStand = true end
    for _, p in c:GetDescendants() do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
end)

-- Раунд
local rs = RS:FindFirstChild("Remotes")
local gp = rs and rs:FindFirstChild("Gameplay")
local rnd = gp and gp:FindFirstChild("RoundStart")
if rnd then rnd.OnClientEvent:Connect(function() active = true end) end

LP.CharacterAdded:Connect(function(c)
    active = false
    c:WaitForChild("Humanoid").Died:Connect(function() active = false end)
end)

-- Главный цикл
task.spawn(function()
    while true do
        task.wait(0.1)
        if not active then continue end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        if hrp.Position.Y < -50 then
            hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
            continue
        end

        local map
        for _, o in workspace:GetChildren() do
            if o:FindFirstChild("CoinContainer") then map = o break end
        end
        if not map then continue end

        local cc = map.CoinContainer
        local best, bd = nil, math.huge
        for _, p in cc:GetChildren() do
            if p:IsA("BasePart") and p.Name:lower():find("coin") then
                local d = (p.Position - hrp.Position).Magnitude
                if d < bd then bd = d best = p end
            end
        end
        if not best then continue end

        if bd <= RADIUS then continue end -- подберётся само

        local tp = Vector3.new(best.Position.X, best.Position.Y + YOFF, best.Position.Z)
        if tween then tween:Cancel() end
        tween = TweenService:Create(hrp,
            TweenInfo.new(math.max(bd / SPEED, 0.1), Enum.EasingStyle.Linear),
            {CFrame = CFrame.new(tp)})
        tween:Play()
    end
end)

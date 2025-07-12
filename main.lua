-- Отримуємо сервіси
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Змінні для стану функцій
local highlightsEnabled = true
local aimbotEnabled = false
local bunnyHopEnabled = false
local showFOV = true
local aimTarget = "Head" -- "Head", "Torso", "Feet"
local teammateColor = Color3.fromRGB(0, 255, 0)
local enemyColor = Color3.fromRGB(255, 0, 0)
local currentTab = "Visuals"
local aimbotKey = Enum.UserInputType.MouseButton2
local menuKey = Enum.KeyCode.Insert
local smoothness = 0.15 -- Плавність аіму (0.1 - дуже плавно, 0.5 - швидко)
local headOffset = Vector3.new(0, 0.3, 0) -- Зсув вище голови
local fov = 120 -- Поле зору (чим менше, тим точніше)
local maxDistance = 1000 -- Максимальна дистанція аіму

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = showFOV
fovCircle.Radius = fov
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

-- Функція для ESP (підсвітка гравців)
local function createESP(player)
    if not highlightsEnabled then return end
    if not player.Character then return end

    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not humanoid then return end

    local isTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
    local color = isTeammate and teammateColor or enemyColor

    -- Highlight
    local highlight = character:FindFirstChild("PlayerHighlight") or Instance.new("Highlight")
    highlight.Name = "PlayerHighlight"
    highlight.FillColor = color
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = character
    highlight.Parent = character

    -- BillboardGui (ім'я + HP)
    local billboard = rootPart:FindFirstChild("NameTag") or Instance.new("BillboardGui")
    billboard.Name = "NameTag"
    billboard.Size = UDim2.new(0, 100, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = rootPart

    local nameLabel = billboard:FindFirstChild("NameLabel") or Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 20
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = billboard

    local healthLabel = billboard:FindFirstChild("HealthLabel") or Instance.new("TextLabel")
    healthLabel.Name = "HealthLabel"
    healthLabel.Size = UDim2.new(1, 0, 0.5, 0)
    healthLabel.Position = UDim2.new(0, 0, 0.5, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = "HP: " .. math.floor(humanoid.Health) .. "/" .. humanoid.MaxHealth
    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLabel.TextStrokeTransparency = 0
    healthLabel.TextSize = 16
    healthLabel.Font = Enum.Font.SourceSans
    healthLabel.Parent = billboard

    humanoid.HealthChanged:Connect(function(health)
        healthLabel.Text = "HP: " .. math.floor(health) .. "/" .. humanoid.MaxHealth
    end)
end

-- Видалення ESP
local function removeESP(player)
    if player.Character then
        local highlight = player.Character:FindFirstChild("PlayerHighlight")
        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        local billboard = rootPart and rootPart:FindFirstChild("NameTag")

        if highlight then highlight:Destroy() end
        if billboard then billboard:Destroy() end
    end
end

-- Покращений аімбот
local function aimbot()
    if not aimbotEnabled or not UserInputService:IsMouseButtonPressed(aimbotKey) then return end
    
    local closestTarget = nil
    local closestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
            if not isTeammate then
                local targetPart = player.Character:FindFirstChild(aimTarget)
                if targetPart then
                    local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
                    if screenPos.Z > 0 then -- Перевірка, чи гравець у полі зору
                        local distance = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                        if distance < closestDistance and distance < fov then
                            closestDistance = distance
                            closestTarget = targetPart
                        end
                    end
                end
            end
        end
    end
    
    if closestTarget then
        local targetPos = closestTarget.Position
        if aimTarget == "Head" then
            targetPos = targetPos + headOffset
        elseif aimTarget == "Torso" then
            targetPos = targetPos + Vector3.new(0, 0.5, 0)
        elseif aimTarget == "Feet" then
            targetPos = targetPos - Vector3.new(0, 1.5, 0)
        end
        
        local currentCFrame = Camera.CFrame
        local newCFrame = CFrame.new(currentCFrame.Position, targetPos)
        Camera.CFrame = currentCFrame:Lerp(newCFrame, smoothness)
    end
end

-- Bunny Hop
local function bunnyHop()
    if bunnyHopEnabled and UserInputService:IsKeyDown(Enum.KeyCode.Space) and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
            humanoid.Jump = true
        end
    end
end

-- Оновлення FOV Circle
local function updateFOV()
    fovCircle.Visible = showFOV and aimbotEnabled
    fovCircle.Radius = fov
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

-- Меню
local function createMenu()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomCheatMenu"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 350)
    frame.Position = UDim2.new(0.5, -150, 0.5, -175)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    topBar.BorderSizePixel = 0
    topBar.Parent = frame
    
    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 6)
    topCorner.Parent = topBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0.5, -100, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Cheat Menu"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = topBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 1, 0)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 14
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = topBar
    closeButton.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)
    
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, -20, 0, 30)
    tabFrame.Position = UDim2.new(0, 10, 0, 35)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = frame
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -75)
    contentFrame.Position = UDim2.new(0, 10, 0, 70)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = frame
    
    local tabs = {
        Visuals = Instance.new("TextButton"),
        Aimbot = Instance.new("TextButton"),
        Movement = Instance.new("TextButton")
    }

    for name, tab in pairs(tabs) do
        tab.Size = UDim2.new(0.33, -5, 1, 0)
        tab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        tab.Text = name
        tab.TextColor3 = Color3.fromRGB(255, 255, 255)
        tab.TextSize = 14
        tab.Font = Enum.Font.Gotham
        tab.BorderSizePixel = 0
        tab.Parent = tabFrame
        
        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tab
        
        tab.MouseButton1Click:Connect(function()
            currentTab = name
            for _, t in pairs(tabs) do 
                t.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            end
            tab.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            for _, child in pairs(contentFrame:GetChildren()) do child.Visible = false end
            if contentFrame:FindFirstChild(name) then contentFrame:FindFirstChild(name).Visible = true end
        end)
    end
    
    tabs.Visuals.Position = UDim2.new(0, 0, 0, 0)
    tabs.Aimbot.Position = UDim2.new(0.33, 0, 0, 0)
    tabs.Movement.Position = UDim2.new(0.66, 0, 0, 0)
    tabs.Visuals.BackgroundColor3 = Color3.fromRGB(80, 80, 90)

    -- Вкладка Visuals
    local visualsFrame = Instance.new("Frame")
    visualsFrame.Name = "Visuals"
    visualsFrame.Size = UDim2.new(1, 0, 1, 0)
    visualsFrame.BackgroundTransparency = 1
    visualsFrame.Visible = true
    visualsFrame.Parent = contentFrame
    
    local function createToggle(text, yPos, state, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 30)
        button.Position = UDim2.new(0, 0, 0, yPos)
        button.BackgroundColor3 = state and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
        button.Text = text .. ": " .. (state and "ON" or "OFF")
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.Gotham
        button.Parent = visualsFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            state = not state
            button.BackgroundColor3 = state and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
            button.Text = text .. ": " .. (state and "ON" or "OFF")
            callback(state)
        end)
    end
    
    createToggle("ESP Highlight", 0, highlightsEnabled, function(state)
        highlightsEnabled = state
        for _, player in ipairs(Players:GetPlayers()) do
            removeESP(player)
            if highlightsEnabled then createESP(player) end
        end
    end)
    
    createToggle("Show FOV Circle", 40, showFOV, function(state)
        showFOV = state
        updateFOV()
    end)

    -- Вкладка Aimbot
    local aimbotFrame = Instance.new("Frame")
    aimbotFrame.Name = "Aimbot"
    aimbotFrame.Size = UDim2.new(1, 0, 1, 0)
    aimbotFrame.BackgroundTransparency = 1
    aimbotFrame.Visible = false
    aimbotFrame.Parent = contentFrame
    
    createToggle("Aimbot", 0, aimbotEnabled, function(state)
        aimbotEnabled = state
        updateFOV()
    end)
    
    -- Налаштування FOV
    local fovFrame = Instance.new("Frame")
    fovFrame.Size = UDim2.new(1, 0, 0, 60)
    fovFrame.Position = UDim2.new(0, 0, 0, 40)
    fovFrame.BackgroundTransparency = 1
    fovFrame.Parent = aimbotFrame
    
    local fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(1, 0, 0, 20)
    fovLabel.Position = UDim2.new(0, 0, 0, 0)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Text = "FOV: " .. fov
    fovLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fovLabel.TextSize = 14
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left
    fovLabel.Parent = fovFrame
    
    local fovSlider = Instance.new("TextButton")
    fovSlider.Size = UDim2.new(1, 0, 0, 30)
    fovSlider.Position = UDim2.new(0, 0, 0, 25)
    fovSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    fovSlider.Text = ""
    fovSlider.Parent = fovFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = fovSlider
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((fov - 50) / 150, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    fill.BorderSizePixel = 0
    fill.Parent = fovSlider
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = fill
    
    fovSlider.MouseButton1Down:Connect(function(x)
        local percent = math.clamp((x - fovSlider.AbsolutePosition.X) / fovSlider.AbsoluteSize.X, 0, 1)
        fov = math.floor(50 + percent * 150)
        fill.Size = UDim2.new((fov - 50) / 150, 0, 1, 0)
        fovLabel.Text = "FOV: " .. fov
        updateFOV()
    end)

    -- Вкладка Movement
    local movementFrame = Instance.new("Frame")
    movementFrame.Name = "Movement"
    movementFrame.Size = UDim2.new(1, 0, 1, 0)
    movementFrame.BackgroundTransparency = 1
    movementFrame.Visible = false
    movementFrame.Parent = contentFrame
    
    createToggle("Bunny Hop", 0, bunnyHopEnabled, function(state)
        bunnyHopEnabled = state
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        if input.KeyCode == menuKey then
            frame.Visible = not frame.Visible
        end
    end)
end

-- Ініціалізація
createMenu()

-- Оновлення
RunService.RenderStepped:Connect(function()
    aimbot()
    bunnyHop()
    updateFOV()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESP(player)
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.1)
        createESP(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        removeESP(player)
        if highlightsEnabled then createESP(player) end
    end
end)

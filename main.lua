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
local aimTarget = "Head" -- Можливі значення: "Head", "Torso", "Feet"
local teammateColor = Color3.fromRGB(0, 255, 0) -- Початковий колір для тиммейтів
local enemyColor = Color3.fromRGB(255, 0, 0) -- Початковий колір для ворогів
local debugMode = false -- Вимкнене відладочне виведення
local currentTab = "Visuals" -- Поточна вкладка
local aimbotKey = Enum.UserInputType.MouseButton2 -- Клавіша для аімботу
local menuKey = Enum.KeyCode.Insert -- Клавіша для меню
local smoothness = 0.15 -- Плавність аімботу (менше = плавніше)
local headOffset = Vector3.new(0, 0.3, 0) -- Зсув вище голови

-- Функція для створення ESP (підсвітки або тексту)
local function createESP(player)
    if not highlightsEnabled then
        removeESP(player)
        return
    end

    if player.Character then
        local character = player.Character
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart or not humanoid then 
            if debugMode then print("Немає root part або humanoid для " .. player.Name) end
            return 
        end

        local isTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
        if debugMode then print(player.Name .. " команда: " .. tostring(player.Team) .. ", команда LocalPlayer: " .. tostring(LocalPlayer.Team) .. ", Чи тиммейт: " .. tostring(isTeammate)) end

        -- Визначаємо колір підсвітки залежно від команди
        local fillColor = isTeammate and teammateColor or enemyColor

        -- Створюємо Highlight
        local highlight = character:FindFirstChild("PlayerHighlight")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "PlayerHighlight"
            highlight.FillColor = fillColor
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- Білий контур
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Adornee = character
            highlight.Parent = character
        else
            highlight.FillColor = fillColor
        end

        -- Створюємо BillboardGui для імені та HP
        local billboard = humanoidRootPart:FindFirstChild("NameTag")
        if not billboard then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "NameTag"
            billboard.Size = UDim2.new(0, 100, 0, 70) -- Збільшуємо висоту для HP
            billboard.StudsOffset = Vector3.new(0, 3, 0) -- Розташування над головою
            billboard.AlwaysOnTop = true
            billboard.Parent = humanoidRootPart

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
            nameLabel.Position = UDim2.new(0, 0, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = player.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            nameLabel.TextStrokeTransparency = 0
            nameLabel.TextSize = 20
            nameLabel.Font = Enum.Font.SourceSansBold
            nameLabel.Parent = billboard

            local healthLabel = Instance.new("TextLabel")
            healthLabel.Name = "HealthLabel"
            healthLabel.Size = UDim2.new(1, 0, 0.5, 0)
            healthLabel.Position = UDim2.new(0, 0, 0.5, 0)
            healthLabel.BackgroundTransparency = 1
            healthLabel.Text = "HP: " .. math.floor(humanoid.Health) .. "/" .. humanoid.MaxHealth
            healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            healthLabel.TextStrokeTransparency = 0
            healthLabel.TextSize = 16
            healthLabel.Font = Enum.Font.SourceSans
            healthLabel.Parent = billboard

            -- Оновлення HP при зміні
            humanoid.HealthChanged:Connect(function(health)
                healthLabel.Text = "HP: " .. math.floor(health) .. "/" .. humanoid.MaxHealth
            end)

            humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
                healthLabel.Text = "HP: " .. math.floor(humanoid.Health) .. "/" .. humanoid.MaxHealth
            end)
        end

        player:GetPropertyChangedSignal("Team"):Connect(function()
            if player.Character then
                local newHighlight = character:FindFirstChild("PlayerHighlight")
                if newHighlight then
                    local newIsTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
                    newHighlight.FillColor = newIsTeammate and teammateColor or enemyColor
                end
            end
        end)
    end
end

-- Функція для видалення ESP
local function removeESP(player)
    if player.Character then
        local character = player.Character
        local highlight = character:FindFirstChild("PlayerHighlight")
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local billboard = humanoidRootPart and humanoidRootPart:FindFirstChild("NameTag")

        if highlight then
            highlight:Destroy()
        end
        if billboard then
            billboard:Destroy()
        end
    end
end

-- Покращений аімбот
local function aimbot()
    if not aimbotEnabled or not UserInputService:IsMouseButtonPressed(aimbotKey) or not LocalPlayer.Character then return end
    
    local target = nil
    local shortestDistance = math.huge
    local maxDistance = 1000 -- Максимальна дистанція для аімботу
    local fov = 120 -- Поле зору
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
            if not isTeammate then
                local targetPart = player.Character:FindFirstChild(aimTarget)
                if targetPart then
                    local screenPoint = Camera:WorldToViewportPoint(targetPart.Position)
                    if screenPoint.Z > 0 then -- Перевірка, чи об'єкт перед камерою
                        local distance = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
                        local realDistance = (Camera.CFrame.Position - targetPart.Position).Magnitude
                        
                        -- Перевірка FOV та дистанції
                        if distance < shortestDistance and distance < fov and realDistance < maxDistance then
                            shortestDistance = distance
                            target = targetPart
                        end
                    end
                end
            end
        end
    end
    
    if target then
        local targetPosition = target.Position
        
        -- Додаємо зсув залежно від цілі
        if aimTarget == "Head" then
            targetPosition = targetPosition + headOffset -- Зсув вище голови
        elseif aimTarget == "Torso" then
            targetPosition = targetPosition + Vector3.new(0, 0.5, 0) -- Зсув для тулуба
        elseif aimTarget == "Feet" then
            targetPosition = targetPosition - Vector3.new(0, 1.5, 0) -- Зсув для ніг
        end
        
        -- Плавний аім
        local currentCFrame = Camera.CFrame
        local newCFrame = CFrame.new(currentCFrame.Position, targetPosition)
        Camera.CFrame = currentCFrame:Lerp(newCFrame, smoothness)
    end
end

-- Банни хоп
local function bunnyHop()
    if bunnyHopEnabled and UserInputService:IsKeyDown(Enum.KeyCode.Space) and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            humanoid.Jump = true
        end
    end
end

-- Покращене меню
local function createMenu()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomMenu"
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
    title.Text = "Custom Cheat Menu"
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
    
    local function createToggleButton(name, yPos, state, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 30)
        button.Position = UDim2.new(0, 0, 0, yPos)
        button.BackgroundColor3 = state and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
        button.Text = name .. ": " .. (state and "ON" or "OFF")
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
            button.Text = name .. ": " .. (state and "ON" or "OFF")
            callback(state)
        end)
        
        return button
    end
    
    local function createColorPicker(name, yPos, currentColor, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 60)
        frame.Position = UDim2.new(0, 0, 0, yPos)
        frame.BackgroundTransparency = 1
        frame.Parent = visualsFrame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 14
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local colorBox = Instance.new("TextButton")
        colorBox.Size = UDim2.new(0, 50, 0, 30)
        colorBox.Position = UDim2.new(0, 0, 0, 25)
        colorBox.BackgroundColor3 = currentColor
        colorBox.Text = ""
        colorBox.Parent = frame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = colorBox
        
        local colors = {
            Color3.fromRGB(255, 0, 0),   -- Red
            Color3.fromRGB(0, 255, 0),   -- Green
            Color3.fromRGB(0, 0, 255),   -- Blue
            Color3.fromRGB(255, 255, 0), -- Yellow
            Color3.fromRGB(255, 0, 255), -- Purple
            Color3.fromRGB(0, 255, 255), -- Cyan
            Color3.fromRGB(255, 255, 255) -- White
        }
        
        colorBox.MouseButton1Click:Connect(function()
            for i, color in ipairs(colors) do
                if currentColor == color then
                    currentColor = colors[(i % #colors) + 1]
                    break
                end
            end
            colorBox.BackgroundColor3 = currentColor
            callback(currentColor)
        end)
    end
    
    -- Тумблери для Visuals
    local highlightToggle = createToggleButton("ESP Highlight", 0, highlightsEnabled, function(state)
        highlightsEnabled = state
        for _, player in ipairs(Players:GetPlayers()) do
            removeESP(player)
            if highlightsEnabled then createESP(player) end
        end
    end)
    
    -- Колірні пікери
    createColorPicker("Teammate Color", 40, teammateColor, function(color)
        teammateColor = color
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local highlight = player.Character:FindFirstChild("PlayerHighlight")
                if highlight and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                    highlight.FillColor = teammateColor
                end
            end
        end
    end)
    
    createColorPicker("Enemy Color", 110, enemyColor, function(color)
        enemyColor = color
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local highlight = player.Character:FindFirstChild("PlayerHighlight")
                if highlight and (not LocalPlayer.Team or not player.Team or LocalPlayer.Team ~= player.Team) then
                    highlight.FillColor = enemyColor
                end
            end
        end
    end)

    -- Вкладка Aimbot
    local aimbotFrame = Instance.new("Frame")
    aimbotFrame.Name = "Aimbot"
    aimbotFrame.Size = UDim2.new(1, 0, 1, 0)
    aimbotFrame.BackgroundTransparency = 1
    aimbotFrame.Visible = false
    aimbotFrame.Parent = contentFrame
    
    -- Тумблер для Aimbot
    local aimbotToggle = createToggleButton("Aimbot", 0, aimbotEnabled, function(state)
        aimbotEnabled = state
    end)
    
    -- Вибір цілі
    local targetFrame = Instance.new("Frame")
    targetFrame.Size = UDim2.new(1, 0, 0, 60)
    targetFrame.Position = UDim2.new(0, 0, 0, 40)
    targetFrame.BackgroundTransparency = 1
    targetFrame.Parent = aimbotFrame
    
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, 0, 0, 20)
    targetLabel.Position = UDim2.new(0, 0, 0, 0)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "Aimbot Target: " .. aimTarget
    targetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetLabel.TextSize = 14
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = targetFrame
    
    local targetButton = Instance.new("TextButton")
    targetButton.Size = UDim2.new(0, 80, 0, 30)
    targetButton.Position = UDim2.new(0, 0, 0, 25)
    targetButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    targetButton.Text = "Change"
    targetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetButton.TextSize = 14
    targetButton.Font = Enum.Font.Gotham
    targetButton.Parent = targetFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = targetButton
    
    targetButton.MouseButton1Click:Connect(function()
        if aimTarget == "Head" then aimTarget = "Torso"
        elseif aimTarget == "Torso" then aimTarget = "Feet"
        else aimTarget = "Head" end
        targetLabel.Text = "Aimbot Target: " .. aimTarget
    end)
    
    -- Налаштування плавності
    local smoothFrame = Instance.new("Frame")
    smoothFrame.Size = UDim2.new(1, 0, 0, 60)
    smoothFrame.Position = UDim2.new(0, 0, 0, 110)
    smoothFrame.BackgroundTransparency = 1
    smoothFrame.Parent = aimbotFrame
    
    local smoothLabel = Instance.new("TextLabel")
    smoothLabel.Size = UDim2.new(1, 0, 0, 20)
    smoothLabel.Position = UDim2.new(0, 0, 0, 0)
    smoothLabel.BackgroundTransparency = 1
    smoothLabel.Text = "Smoothness: " .. string.format("%.2f", smoothness)
    smoothLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    smoothLabel.TextSize = 14
    smoothLabel.Font = Enum.Font.Gotham
    smoothLabel.TextXAlignment = Enum.TextXAlignment.Left
    smoothLabel.Parent = smoothFrame
    
    local smoothSlider = Instance.new("TextButton")
    smoothSlider.Size = UDim2.new(1, 0, 0, 30)
    smoothSlider.Position = UDim2.new(0, 0, 0, 25)
    smoothSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    smoothSlider.Text = ""
    smoothSlider.Parent = smoothFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = smoothSlider
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(smoothness / 0.3, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    fill.BorderSizePixel = 0
    fill.Parent = smoothSlider
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = fill
    
    smoothSlider.MouseButton1Down:Connect(function(x)
        local percent = math.clamp((x - smoothSlider.AbsolutePosition.X) / smoothSlider.AbsoluteSize.X, 0, 1)
        smoothness = math.floor(percent * 0.3 * 100) / 100
        fill.Size = UDim2.new(smoothness / 0.3, 0, 1, 0)
        smoothLabel.Text = "Smoothness: " .. string.format("%.2f", smoothness)
    end)

    -- Вкладка Movement
    local movementFrame = Instance.new("Frame")
    movementFrame.Name = "Movement"
    movementFrame.Size = UDim2.new(1, 0, 1, 0)
    movementFrame.BackgroundTransparency = 1
    movementFrame.Visible = false
    movementFrame.Parent = contentFrame
    
    -- Тумблер для Bunny Hop
    local bunnyToggle = createToggleButton("Bunny Hop", 0, bunnyHopEnabled, function(state)
        bunnyHopEnabled = state
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        if input.KeyCode == menuKey then
            frame.Visible = not frame.Visible
        end
    end)
end

-- Ініціалізація меню
createMenu()

-- Оновлення функцій
RunService.RenderStepped:Connect(function()
    aimbot()
    bunnyHop()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            createESP(player)
        end
    end
end)

-- Обробка нових гравців
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.1)
        createESP(player)
    end)
end)

-- Обробка виходу гравців
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- Оновлення при зміні команди
LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        removeESP(player)
        if highlightsEnabled then createESP(player) end
    end
end)

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
local debugMode = false -- Увімкнення відладочного виведення
local currentTab = "Visuals" -- Поточна вкладка
local aimThroughWalls = false
local fovEnabled = false
local fovRadius = 100 -- Default FOV radius in pixels
local aimbotKey = Enum.UserInputType.MouseButton2-- Default aimbot key
local edgeJumpEnabled = false

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

-- Функція для перевірки видимості (для опції "цілитися через стіни")
local function isTargetVisible(targetPosition)
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = (targetPosition - rayOrigin).Unit * 1000
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if debugMode and raycastResult then print("Raycast hit: " .. (raycastResult.Instance.Name or "Unknown")) end
    return not raycastResult
end

-- Аимбот
local function aimbot()
    if not aimbotEnabled or not UserInputService:IsMouseButtonPressed(aimbotKey) or not LocalPlayer.Character then return end
    local target = nil
    local shortestDistance = math.huge
    local mousePosition = Vector2.new(Mouse.X, Mouse.Y)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then -- Check if player is alive
                local isTeammate = LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team
                if not isTeammate then
                    local targetPart = player.Character:FindFirstChild(aimTarget)
                    if targetPart then
                        local screenPoint = Camera:WorldToScreenPoint(targetPart.Position)
                        local distance = (mousePosition - Vector2.new(screenPoint.X, screenPoint.Y)).Magnitude
                        if distance <= fovRadius and distance < shortestDistance then
                            if aimThroughWalls or isTargetVisible(targetPart.Position) then
                                shortestDistance = distance
                                target = targetPart
                            end
                        end
                    end
                end
            end
        end
    end
    if target then
        local targetPosition = target.Position
        if aimTarget == "Torso" then
            targetPosition = targetPosition - Vector3.new(0, 1, 0) -- Зсув нижче для тулуба
        elseif aimTarget == "Feet" then
            targetPosition = targetPosition - Vector3.new(0, 3, 0) -- Зсув нижче для ніг
        end
        local currentCFrame = Camera.CFrame
        local newCFrame = CFrame.new(currentCFrame.Position, Vector3.new(targetPosition.X, targetPosition.Y + 1, targetPosition.Z))
        Camera.CFrame = currentCFrame:Lerp(newCFrame, 0.1) -- Плавний перехід
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

-- Edge Jump
local function edgeJump()
    if edgeJumpEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and rootPart then
            local rayOrigin = rootPart.Position + Vector3.new(0, 2, 0) -- Slightly above player
            local rayDirection = -Vector3.new(0, 1, 0) -- Downward
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            local raycastResult = workspace:Raycast(rayOrigin, rayDirection * 3, raycastParams)
            if not raycastResult and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                humanoid.Jump = true
            end
        end
    end
end

-- Створюємо GUI для меню
local function createMenu()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomMenu"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 500) -- Increased size
    frame.Position = UDim2.new(0.5, -150, 0.1, 0)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 50))
    }
    gradient.Parent = frame
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(150, 70, 200)
    frame.Parent = screenGui

    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 0, 50)
    tabFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    tabFrame.BorderSizePixel = 0
    tabFrame.Parent = frame

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -70) -- Adjusted for padding
    contentFrame.Position = UDim2.new(0, 10, 0, 60)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = frame

    local tabs = {
        Visuals = Instance.new("TextButton"),
        Aimbot = Instance.new("TextButton"),
        Movement = Instance.new("TextButton")
    }

    for name, tab in pairs(tabs) do
        tab.Size = UDim2.new(0.33, 0, 1, 0)
        tab.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        tab.Text = name
        tab.TextColor3 = Color3.fromRGB(200, 200, 255)
        tab.TextSize = 16
        tab.Font = Enum.Font.SourceSansBold
        tab.BorderSizePixel = 0
        tab.Parent = tabFrame
        tab.MouseButton1Click:Connect(function()
            currentTab = name
            for _, t in pairs(tabs) do t.BackgroundColor3 = Color3.fromRGB(60, 60, 90) end
            tab.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
            for _, child in pairs(contentFrame:GetChildren()) do child.Visible = false end
            if contentFrame:FindFirstChild(name) then contentFrame:FindFirstChild(name).Visible = true end
        end)
    end

    tabs.Visuals.Position = UDim2.new(0, 0, 0, 0)
    tabs.Aimbot.Position = UDim2.new(0.33, 0, 0, 0)
    tabs.Movement.Position = UDim2.new(0.66, 0, 0, 0)
    tabs.Visuals.BackgroundColor3 = Color3.fromRGB(80, 80, 110)

    -- Вкладка Visuals
    local visualsFrame = Instance.new("Frame")
    visualsFrame.Name = "Visuals"
    visualsFrame.Size = UDim2.new(1, 0, 1, 0)
    visualsFrame.BackgroundTransparency = 1
    visualsFrame.Visible = true
    visualsFrame.Parent = contentFrame

    local toggleHighlight = Instance.new("TextButton")
    toggleHighlight.Size = UDim2.new(0.8, 0, 0.1, 0)
    toggleHighlight.Position = UDim2.new(0.1, 0, 0.05, 0)
    toggleHighlight.Text = highlightsEnabled and "Вимкнути підсвітку" or "Увімкнути підсвітку"
    toggleHighlight.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleHighlight.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    toggleHighlight.BorderColor3 = Color3.fromRGB(150, 70, 200)
    toggleHighlight.TextSize = 14
    toggleHighlight.Font = Enum.Font.SourceSansBold
    toggleHighlight.Parent = visualsFrame
    toggleHighlight.MouseButton1Click:Connect(function()
        highlightsEnabled = not highlightsEnabled
        toggleHighlight.Text = highlightsEnabled and "Вимкнути підсвітку" or "Увімкнути підсвітку"
        for _, player in ipairs(Players:GetPlayers()) do
            removeESP(player)
            if highlightsEnabled then createESP(player) end
        end
    end)

    local teammateColorLabel = Instance.new("TextLabel")
    teammateColorLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
    teammateColorLabel.Position = UDim2.new(0.1, 0, 0.2, 0)
    teammateColorLabel.BackgroundTransparency = 1
    teammateColorLabel.Text = "Колір тиммейтів: " .. teammateColor:ToHex()
    teammateColorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    teammateColorLabel.TextSize = 14
    teammateColorLabel.Font = Enum.Font.SourceSansBold
    teammateColorLabel.Parent = visualsFrame

    local teammateColorButton = Instance.new("TextButton")
    teammateColorButton.Size = UDim2.new(0.8, 0, 0.1, 0)
    teammateColorButton.Position = UDim2.new(0.1, 0, 0.3, 0)
    teammateColorButton.Text = "Змінити колір тиммейтів"
    teammateColorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    teammateColorButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    teammateColorButton.BorderColor3 = Color3.fromRGB(150, 70, 200)
    teammateColorButton.TextSize = 14
    teammateColorButton.Font = Enum.Font.SourceSansBold
    teammateColorButton.Parent = visualsFrame
    teammateColorButton.MouseButton1Click:Connect(function()
        local colors = {
            Color3.fromRGB(0, 255, 0), -- Green
            Color3.fromRGB(0, 0, 255), -- Blue
            Color3.fromRGB(255, 255, 0), -- Yellow
            Color3.fromRGB(255, 0, 255), -- Purple
            Color3.fromRGB(255, 255, 255) -- White
        }
        for i, color in ipairs(colors) do
            if teammateColor == color then
                teammateColor = colors[(i % #colors) + 1]
                break
            end
        end
        if teammateColor == nil then teammateColor = colors[1] end
        teammateColorLabel.Text = "Колір тиммейтів: " .. teammateColor:ToHex()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local highlight = player.Character:FindFirstChild("PlayerHighlight")
                if highlight and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                    highlight.FillColor = teammateColor
                end
            end
        end
    end)

    local enemyColorLabel = Instance.new("TextLabel")
    enemyColorLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
    enemyColorLabel.Position = UDim2.new(0.1, 0, 0.45, 0)
    enemyColorLabel.BackgroundTransparency = 1
    enemyColorLabel.Text = "Колір ворогів: " .. enemyColor:ToHex()
    enemyColorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    enemyColorLabel.TextSize = 14
    enemyColorLabel.Font = Enum.Font.SourceSansBold
    enemyColorLabel.Parent = visualsFrame

    local enemyColorButton = Instance.new("TextButton")
    enemyColorButton.Size = UDim2.new(0.8, 0, 0.1, 0)
    enemyColorButton.Position = UDim2.new(0.1, 0, 0.55, 0)
    enemyColorButton.Text = "Змінити колір ворогів"
    enemyColorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    enemyColorButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    enemyColorButton.BorderColor3 = Color3.fromRGB(150, 70, 200)
    enemyColorButton.TextSize = 14
    enemyColorButton.Font = Enum.Font.SourceSansBold
    enemyColorButton.Parent = visualsFrame
    enemyColorButton.MouseButton1Click:Connect(function()
        local colors = {
            Color3.fromRGB(255, 0, 0), -- Red
            Color3.fromRGB(0, 0, 255), -- Blue
            Color3.fromRGB(255, 255, 0), -- Yellow
            Color3.fromRGB(255, 0, 255), -- Purple
            Color3.fromRGB(255, 255, 255) -- White
        }
        for i, color in ipairs(colors) do
            if enemyColor == color then
                enemyColor = colors[(i % #colors) + 1]
                break
            end
        end
        if enemyColor == nil then enemyColor = colors[1] end
        enemyColorLabel.Text = "Колір ворогів: " .. enemyColor:ToHex()
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

    local toggleAimbot = Instance.new("TextButton")
    toggleAimbot.Size = UDim2.new(0.8, 0, 0.1, 0)
    toggleAimbot.Position = UDim2.new(0.1, 0, 0.05, 0)
    toggleAimbot.Text = aimbotEnabled and "Вимкнути аімбот" or "Увімкнути аімбот"
    toggleAimbot.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleAimbot.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    toggleAimbot.BorderColor3 = Color3.fromRGB(150, 70, 200)
    toggleAimbot.TextSize = 14
    toggleAimbot.Font = Enum.Font.SourceSansBold
    toggleAimbot.Parent = aimbotFrame
    toggleAimbot.MouseButton1Click:Connect(function()
        aimbotEnabled = not aimbotEnabled
        toggleAimbot.Text = aimbotEnabled and "Вимкнути аімбот" or "Увімкнути аімбот"
    end)

    local aimTargetLabel = Instance.new("TextLabel")
    aimTargetLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
    aimTargetLabel.Position = UDim2.new(0.1, 0, 0.2, 0)
    aimTargetLabel.BackgroundTransparency = 1
    aimTargetLabel.Text = "Ціль аімботу: " .. aimTarget
    aimTargetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimTargetLabel.TextSize = 14
    aimTargetLabel.Font = Enum.Font.SourceSansBold
    aimTargetLabel.Parent = aimbotFrame

    local aimTargetButton = Instance.new("TextButton")
    aimTargetButton.Size = UDim2.new(0.8, 0, 0.1, 0)
    aimTargetButton.Position = UDim2.new(0.1, 0, 0.3, 0)
    aimTargetButton.Text = "Змінити ціль"
    aimTargetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimTargetButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    aimTargetButton.BorderColor3 = Color3.fromRGB(150, 70, 200)
    aimTargetButton.TextSize = 14
    aimTargetButton.Font = Enum.Font.SourceSansBold
    aimTargetButton.Parent = aimbotFrame
    aimTargetButton.MouseButton1Click:Connect(function()
        if aimTarget == "Head" then aimTarget = "Torso"
        elseif aimTarget == "Torso" then aimTarget = "Feet"
        else aimTarget = "Head" end
        aimTargetLabel.Text = "Ціль аімботу: " .. aimTarget
    end)

    local toggleWallAim = Instance.new("TextButton")
    toggleWallAim.Size = UDim2.new(0.8, 0, 0.1, 0)
    toggleWallAim.Position = UDim2.new(0.1, 0, 0.45, 0)
    toggleWallAim.Text = aimThroughWalls and "Вимкнути цілення через стіни" or "Увімкнути цілення через стіни"
    toggleWallAim.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleWallAim.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    toggleWallAim.BorderColor3 = Color3.fromRGB(150, 70, 200)
    toggleWallAim.TextSize = 14
    toggleWallAim.Font = Enum.Font.SourceSansBold
    toggleWallAim.Parent = aimbotFrame
    toggleWallAim.MouseButton1Click:Connect(function()
        aimThroughWalls = not aimThroughWalls
        toggleWallAim.Text = aimThroughWalls and "Вимкнути цілення через стіни" or "Увімкнути цілення через стіни"
    end)

    local fovToggle = Instance.new("TextButton")
    fovToggle.Size = UDim2.new(0.8, 0, 0.1, 0)
    fovToggle.Position = UDim2.new(0.1, 0, 0.6, 0)
    fovToggle.Text = fovEnabled and "Сховати FOV" or "Показати FOV"
    fovToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    fovToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    fovToggle.BorderColor3 = Color3.fromRGB(150, 70, 200)
    fovToggle.TextSize = 14
    fovToggle.Font = Enum.Font.SourceSansBold
    fovToggle.Parent = aimbotFrame
    fovToggle.MouseButton1Click:Connect(function()
        fovEnabled = not fovEnabled
        fovToggle.Text = fovEnabled and "Сховати FOV" or "Показати FOV"
    end)

    local fovSliderLabel = Instance.new("TextLabel")
    fovSliderLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
    fovSliderLabel.Position = UDim2.new(0.1, 0, 0.75, 0)
    fovSliderLabel.BackgroundTransparency = 1
    fovSliderLabel.Text = "FOV Radius: " .. fovRadius
    fovSliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fovSliderLabel.TextSize = 14
    fovSliderLabel.Font = Enum.Font.SourceSansBold
    fovSliderLabel.Parent = aimbotFrame

    local fovSlider = Instance.new("TextButton")
    fovSlider.Size = UDim2.new(0.8, 0, 0.05, 0)
    fovSlider.Position = UDim2.new(0.1, 0, 0.85, 0)
    fovSlider.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
    fovSlider.BorderColor3 = Color3.fromRGB(150, 70, 200)
    fovSlider.Parent = aimbotFrame
    local sliderHandle = Instance.new("Frame")
    sliderHandle.Size = UDim2.new(0, 10, 1, 0)
    sliderHandle.BackgroundColor3 = Color3.fromRGB(200, 100, 255)
    sliderHandle.Position = UDim2.new((fovRadius - 50) / 150, 0, 0, 0)
    sliderHandle.Parent = fovSlider
    sliderHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local connection
            connection = RunService.RenderStepped:Connect(function()
                local mousePos = UserInputService:GetMouseLocation().X - fovSlider.AbsolutePosition.X
                local newValue = math.clamp(mousePos / fovSlider.AbsoluteSize.X * 150 + 50, 50, 200)
                fovRadius = math.floor(newValue)
                sliderHandle.Position = UDim2.new((fovRadius - 50) / 150, 0, 0, 0)
                fovSliderLabel.Text = "FOV Radius: " .. fovRadius
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    connection:Disconnect()
                end
            end)
        end
    end)

    local aimbotKeyLabel = Instance.new("TextLabel")
    aimbotKeyLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
    aimbotKeyLabel.Position = UDim2.new(0.1, 0, 0.95, 0)
    aimbotKeyLabel.BackgroundTransparency = 1
    aimbotKeyLabel.Text = "Aimbot Key: " .. aimbotKey.Name
    aimbotKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimbotKeyLabel.TextSize = 14
    aimbotKeyLabel.Font = Enum.Font.SourceSansBold
    aimbotKeyLabel.Parent = aimbotFrame

    local rebindAimbotKey = Instance.new("TextButton")
    rebindAimbotKey.Size = UDim2.new(0.8, 0, 0.1, 0)
    rebindAimbotKey.Position = UDim2.new(0.1, 0, 1.05, 0)
    rebindAimbotKey.Text = "Rebind Aimbot Key"
    rebindAimbotKey.TextColor3 = Color3.fromRGB(255, 255, 255)
    rebindAimbotKey.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    rebindAimbotKey.BorderColor3 = Color3.fromRGB(150, 70, 200)
    rebindAimbotKey.TextSize = 14
    rebindAimbotKey.Font = Enum.Font.SourceSansBold
    rebindAimbotKey.Parent = aimbotFrame
    local rebindingAimbot = false
    rebindAimbotKey.MouseButton1Click:Connect(function()
        if not rebindingAimbot then
            rebindingAimbot = true
            rebindAimbotKey.Text = "Press new key..."
            local connection
            connection = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton then
                    aimbotKey = input.KeyCode or input.UserInputType
                    aimbotKeyLabel.Text = "Aimbot Key: " .. aimbotKey.Name
                    rebindingAimbot = false
                    rebindAimbotKey.Text = "Rebind Aimbot Key"
                    connection:Disconnect()
                end
            end)
        end
    end)

    -- Вкладка Movement
    local movementFrame = Instance.new("Frame")
    movementFrame.Name = "Movement"
    movementFrame.Size = UDim2.new(1, 0, 1, 0)
    movementFrame.BackgroundTransparency = 1
    movementFrame.Visible = false
    movementFrame.Parent = contentFrame

    local toggleBunnyHop = Instance.new("TextButton")
    toggleBunnyHop.Size = UDim2.new(0.8, 0, 0.1, 0)
    toggleBunnyHop.Position = UDim2.new(0.1, 0, 0.05, 0)
    toggleBunnyHop.Text = bunnyHopEnabled and "Вимкнути банни хоп" or "Увімкнути банни хоп"
    toggleBunnyHop.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBunnyHop.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    toggleBunnyHop.BorderColor3 = Color3.fromRGB(150, 70, 200)
    toggleBunnyHop.TextSize = 14
    toggleBunnyHop.Font = Enum.Font.SourceSansBold
    toggleBunnyHop.Parent = movementFrame
    toggleBunnyHop.MouseButton1Click:Connect(function()
        bunnyHopEnabled = not bunnyHopEnabled
        toggleBunnyHop.Text = bunnyHopEnabled and "Вимкнути банни хоп" or "Увімкнути банни хоп"
    end)

    local toggleEdgeJump = Instance.new("TextButton")
    toggleEdgeJump.Size = UDim2.new(0.8, 0, 0.1, 0)
    toggleEdgeJump.Position = UDim2.new(0.1, 0, 0.2, 0)
    toggleEdgeJump.Text = edgeJumpEnabled and "Вимкнути edge jump" or "Увімкнути edge jump"
    toggleEdgeJump.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleEdgeJump.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    toggleEdgeJump.BorderColor3 = Color3.fromRGB(150, 70, 200)
    toggleEdgeJump.TextSize = 14
    toggleEdgeJump.Font = Enum.Font.SourceSansBold
    toggleEdgeJump.Parent = movementFrame
    toggleEdgeJump.MouseButton1Click:Connect(function()
        edgeJumpEnabled = not edgeJumpEnabled
        toggleEdgeJump.Text = edgeJumpEnabled and "Вимкнути edge jump" or "Увімкнути edge jump"
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        if input.KeyCode == Enum.KeyCode.Insert then
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
    edgeJump()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            createESP(player)
        end
    end

    -- Draw FOV circle if enabled
    if fovEnabled then
        local fovGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("FOVGui")
        if not fovGui then
            fovGui = Instance.new("ScreenGui")
            fovGui.Name = "FOVGui"
            fovGui.Parent = LocalPlayer:FindFirstChild("PlayerGui")
            fovGui.ResetOnSpawn = false

            local fovCircle = Instance.new("Frame")
            fovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
            fovCircle.Position = UDim2.new(0.5, -fovRadius, 0.5, -fovRadius)
            fovCircle.BackgroundTransparency = 0.7
            fovCircle.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            fovCircle.BorderSizePixel = 2
            fovCircle.BorderColor3 = Color3.fromRGB(0, 255, 0)
            fovCircle.Parent = fovGui

            local circleMask = Instance.new("UICorner")
            circleMask.CornerRadius = UDim.new(0, fovRadius)
            circleMask.Parent = fovCircle
        else
            fovGui:FindFirstChild("Frame").Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
            fovGui:FindFirstChild("Frame").Position = UDim2.new(0.5, -fovRadius, 0.5, -fovRadius)
            fovGui:FindFirstChild("Frame"):FindFirstChild("UICorner").CornerRadius = UDim.new(0, fovRadius)
        end
    else
        local fovGui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("FOVGui")
        if fovGui then
            fovGui:Destroy()
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

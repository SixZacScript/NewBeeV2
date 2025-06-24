local HiveGui = {}
HiveGui.__index = HiveGui

function HiveGui:new()
    local self = setmetatable({}, HiveGui)

    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "HiveGridGui"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    -- Container for Grid and Close Button
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"

    local posString = game.Players.LocalPlayer:GetAttribute("HiveGuiPos")
    if posString then
        local xScale, xOffset, yScale, yOffset = string.match(posString, "([^,]+),([^,]+),([^,]+),([^,]+)")
        self.MainFrame.Position = UDim2.new(tonumber(xScale), tonumber(xOffset), tonumber(yScale), tonumber(yOffset))
    else
        self.MainFrame.Position = UDim2.new(1, -10, 0.5, 0) -- Default to right side
    end
    self.MainFrame.AnchorPoint = Vector2.new(1, 0.5)


    self.MainFrame.BackgroundTransparency = 0
    self.MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    self.MainFrame.BorderSizePixel = 2
    self.MainFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    self.MainFrame.ZIndex = 1000
    self.MainFrame.Parent = self.ScreenGui

    -- เพิ่ม UICorner ให้ MainFrame
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = self.MainFrame

    -- Title Bar สำหรับ Drag
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 30)
    self.TitleBar.Position = UDim2.new(0, 0, 0, 0)
    self.TitleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    self.TitleBar.ZIndex = 1001
    self.TitleBar.Parent = self.MainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = self.TitleBar

    -- Title Text
    self.TitleText = Instance.new("TextLabel")
    self.TitleText.Name = "TitleText"
    self.TitleText.Size = UDim2.new(1, -60, 1, 0)
    self.TitleText.Position = UDim2.new(0, 10, 0, 0)
    self.TitleText.BackgroundTransparency = 1
    self.TitleText.Text = "Hive Grid"
    self.TitleText.TextColor3 = Color3.new(1, 1, 1)
    self.TitleText.TextScaled = true
    self.TitleText.Font = Enum.Font.GothamBold
    self.TitleText.ZIndex = 1002
    self.TitleText.Parent = self.TitleBar

    -- Grid Frame
    self.GridFrame = Instance.new("Frame")
    self.GridFrame.Name = "GridFrame"
    self.GridFrame.Position = UDim2.new(0, 10, 0, 40)
    self.GridFrame.BackgroundTransparency = 1
    self.GridFrame.ZIndex = 1001
    self.GridFrame.Parent = self.MainFrame

    -- Close Button
    self.CloseButton = Instance.new("TextButton")
    self.CloseButton.Name = "CloseButton"
    self.CloseButton.Size = UDim2.new(0, 25, 0, 25)
    self.CloseButton.Position = UDim2.new(1, -30, 0, 3)
    self.CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    self.CloseButton.TextColor3 = Color3.new(1, 1, 1)
    self.CloseButton.Text = "×"
    self.CloseButton.TextScaled = true
    self.CloseButton.Font = Enum.Font.GothamBold
    self.CloseButton.ZIndex = 1002
    self.CloseButton.Parent = self.TitleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = self.CloseButton

    self.CloseButton.MouseButton1Click:Connect(function()
        self.ScreenGui:Destroy()
    end)

    -- ตัวแปรสำหรับเก็บข้อมูล grid
    self.gridButtons = {}
    self.maxX = 0
    self.maxY = 0
    self.cellSize = 50
    self.cellPadding = 3
    self.isFinalized = false -- ใช้เพื่อป้องกันการเปลี่ยน maxY หลังจาก finalize

    -- เพิ่ม Drag functionality
    self:makeDraggable()

    return self
end

function HiveGui:makeDraggable()
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    
    local dragging = false
    local dragStart = nil
    local startPos = nil

    local function update(input)
        local delta = input.Position - dragStart
        local newPosition = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        self.MainFrame.Position = newPosition
    end

    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
            
            local tween = TweenService:Create(self.MainFrame, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            })
            tween:Play()
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false

                    local endTween = TweenService:Create(self.MainFrame, TweenInfo.new(0.1), {
                        BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                    })
                    endTween:Play()

                    local pos = self.MainFrame.Position
                    local posString = string.format("%f,%d,%f,%d", pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset)
                    game.Players.LocalPlayer:SetAttribute("HiveGuiPos", posString)

                end
            end)

        end
    end)

    self.TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                update(input)
            end
        end
    end)
end
function HiveGui:createGrid(x, y, beeData, isSelected)
    if not x or not y then 
        warn("X and Y coordinates are required!")
        return 
    end

    if not self.isFinalized then
        if x > self.maxX then self.maxX = x end
        if y > self.maxY then self.maxY = y end
    end

    local posKey = x .. "," .. y

    if self.gridButtons[posKey] then
        self.gridButtons[posKey]:Destroy()
    end

    local btn = Instance.new("ImageButton")
    btn.Name = "GridButton_" .. x .. "_" .. y
    btn.Size = UDim2.new(0, self.cellSize, 0, self.cellSize)
    btn.BackgroundColor3 = beeData.isGifted and Color3.fromRGB(255, 240, 110) or Color3.fromRGB(255, 255, 255)
    btn.ImageColor3 = beeData.Decal.Color3
    btn.BackgroundTransparency = beeData.Decal and 0 or 0.7
    btn.BorderSizePixel = 0
    btn.Image = beeData.Decal.Texture or "rbxassetid://0"
    btn.ScaleType = Enum.ScaleType.Fit
    btn.ZIndex = 1001

    local posX = (x - 1) * (self.cellSize + self.cellPadding)
    local posY = (self.maxY - y) * (self.cellSize + self.cellPadding)
    btn.Position = UDim2.new(0, posX, 0, posY)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = btn

    local originalColor = btn.BackgroundColor3

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    end)

    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = originalColor
    end)

    -- Label for position on top
    local beeNameLabel = Instance.new("TextLabel")
    beeNameLabel.Name = "PositionLabel"
    beeNameLabel.Size = UDim2.new(1, 0, 0, 10)
    beeNameLabel.Position = UDim2.new(0, 0, 0, 0)  -- Top of the button
    beeNameLabel.BackgroundTransparency = 0.5
    beeNameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    beeNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    beeNameLabel.Font = Enum.Font.SourceSansBold

    beeNameLabel.TextScaled = true
    beeNameLabel.Text = beeData.type
    beeNameLabel.ZIndex = 1100
    beeNameLabel.Parent = btn

    -- Add "Selected" label if selected
    if isSelected then
        local selectedLabel = Instance.new("TextLabel")
        selectedLabel.Name = "SelectedLabel"
        selectedLabel.Size = UDim2.new(1, 0, 0, 20)
        selectedLabel.Position = UDim2.new(0, 0, 1, -20) -- Bottom of the button
        selectedLabel.BackgroundTransparency = 0.5
        selectedLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        selectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectedLabel.Font = Enum.Font.SourceSansBold
        selectedLabel.TextSize = 14
        selectedLabel.Text = "Selected"
        selectedLabel.ZIndex = 1100
        selectedLabel.Parent = btn
    end

    btn.MouseButton1Click:Connect(function()
        self.ScreenGui:Destroy()
        if self.OnGridClick then
            self.OnGridClick(x, y)
        end
    end)

    btn.Parent = self.GridFrame
    self.gridButtons[posKey] = btn
end
function HiveGui:DestroyGui()
    self.ScreenGui:Destroy()
end
function HiveGui:finalizeGrid()
    self.isFinalized = true
    self:updateFrameSize()
    self:repositionAllButtons()
end

-- Function สำหรับอัพเดทขนาดของ Frame
function HiveGui:updateFrameSize()
    local margin = 20
    local titleBarHeight = 30
    local closeButtonSpace = 10

    -- คำนวณขนาดที่ต้องการ
    local gridWidth = (self.cellSize * self.maxX) + (self.cellPadding * (self.maxX - 1)) + margin
    local gridHeight = (self.cellSize * self.maxY) + (self.cellPadding * (self.maxY - 1)) + margin + titleBarHeight + closeButtonSpace

    -- จำกัดขนาดสูงสุด
    local maxWidth = self.ScreenGui.AbsoluteSize.X * 0.8
    local maxHeight = self.ScreenGui.AbsoluteSize.Y * 0.8

    if gridWidth > maxWidth then
        local scale = maxWidth / gridWidth
        self.cellSize = self.cellSize * scale
        gridWidth = maxWidth
        gridHeight = gridHeight * scale
    end

    if gridHeight > maxHeight then
        local scale = maxHeight / gridHeight
        self.cellSize = self.cellSize * scale
        gridWidth = gridWidth * scale
        gridHeight = maxHeight
    end

    -- ตั้งค่าขนาดของ MainFrame
    self.MainFrame.Size = UDim2.new(0, gridWidth, 0, gridHeight)

    -- ตั้งค่าขนาดของ GridFrame
    local gridFrameWidth = gridWidth - margin
    local gridFrameHeight = gridHeight - titleBarHeight - closeButtonSpace - margin
    self.GridFrame.Size = UDim2.new(0, gridFrameWidth, 0, gridFrameHeight)
end

-- Function สำหรับจัดตำแหน่งปุ่มใหม่ทั้งหมด
function HiveGui:repositionAllButtons()
    for posKey, btn in pairs(self.gridButtons) do
        local coords = string.split(posKey, ",")
        local x = tonumber(coords[1])
        local y = tonumber(coords[2])

        local posX = (x - 1) * (self.cellSize + self.cellPadding)
        local posY = (self.maxY - y) * (self.cellSize + self.cellPadding)
        
        btn.Size = UDim2.new(0, self.cellSize, 0, self.cellSize)
        btn.Position = UDim2.new(0, posX, 0, posY)
    end
end

-- Function สำหรับลบ grid ในตำแหน่งที่กำหนด
function HiveGui:removeGrid(x, y)
    local posKey = x .. "," .. y
    if self.gridButtons[posKey] then
        self.gridButtons[posKey]:Destroy()
        self.gridButtons[posKey] = nil
    end
end

-- Function สำหรับล้าง grid ทั้งหมด
function HiveGui:clearAllGrids()
    for _, btn in pairs(self.gridButtons) do
        btn:Destroy()
    end
    self.gridButtons = {}
    self.maxX = 0
    self.maxY = 0
    self.isFinalized = false
end

return HiveGui
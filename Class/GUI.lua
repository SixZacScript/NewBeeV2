-- Quest GUI Module
local GUI = {}
GUI.__index = GUI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Utility to create UI elements
local function create(instanceType, props)
    local obj = Instance.new(instanceType)
    for prop, value in pairs(props) do
        obj[prop] = value
    end
    return obj
end

function GUI.new()
    local self = setmetatable({}, GUI)

    local player = Players.LocalPlayer
    local gui = create("ScreenGui", {
        Name = "QuestGUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        Parent = player:WaitForChild("PlayerGui")
    })

    local container = create("Frame", {
        Name = "Container",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0.01, 0, 0.99, 0),
        Size = UDim2.new(0.18, 0, 0, 0),
        BackgroundTransparency = 1,
        Parent = gui,
        AutomaticSize = Enum.AutomaticSize.Y
    })

    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 6),
        Parent = container
    })

    self.gui = gui
    self.container = container
    self.components = {}
    return self
end

function GUI:createStatus(text)
    local frame = create("Frame", {
        Name = "StatusFrame",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.5,
        LayoutOrder = 0,
        Parent = self.container
    })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })

    local label = create("TextLabel", {
        Name = "StatusLabel",
        Size = UDim2.new(1, -10, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency = 1,
        Text = text or "Status: Ready",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextScaled = true,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = frame
    })

    self.components.statusLabel = label
    return label
end

function GUI:createQuestInfo(data)
    local frame = create("Frame", {
        Name = "QuestInfo",
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.6,
        LayoutOrder = 1,
        Parent = self.container
    })

    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })
    create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Color3.fromRGB(255, 255, 255),
        Thickness = 1,
        Transparency = 0.85,
        Parent = frame
    })

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = frame
    })

    local prevBtn = create("TextButton", {
        Name = "PrevButton",
        Size = UDim2.new(0.15, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BackgroundTransparency = 0.7,
        Text = "◀",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextScaled = true,
        Parent = frame
    })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = prevBtn })

    local contentFrame = create("Frame", {
        Name = "QuestContent",
        BackgroundTransparency = 1,
        Size = UDim2.new(0.7, 0, 1, 0),
        Parent = frame
    })

    local title = create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -10, 0.35, 0),
        Position = UDim2.new(0, 5, 0, 4),
        BackgroundTransparency = 1,
        Text = data.title or "📜 No Quest",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextWrapped = true,
        ClipsDescendants = false,
        TextTruncate = Enum.TextTruncate.None,
        TextColor3 = Color3.fromRGB(255, 215, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = contentFrame
    })

    local content = create("TextLabel", {
        Name = "Content",
        Size = UDim2.new(1, -10, 0.5, 0),
        Position = UDim2.new(0, 5, 0.35, 0),
        BackgroundTransparency = 1,
        Text = data.content or "No active quest available",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextWrapped = true,
        ClipsDescendants = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = Color3.fromRGB(230, 230, 230),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = contentFrame
    })

    local progressBar = create("Frame", {
        Name = "ProgressBar",
        Size = UDim2.new(1, -10, 0, 14),
        Position = UDim2.new(0, 5, 1, -16),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BorderSizePixel = 0,
        Parent = contentFrame
    })
    create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = progressBar })

    local fill = create("Frame", {
        Name = "Fill",
        Size = UDim2.new(math.clamp(data.progress or 0, 0, 1), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 150, 255),
        BorderSizePixel = 0,
        Parent = progressBar
    })
    create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = fill })

    local percent = create("TextLabel", {
        Name = "PercentLabel",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = true,
        Text = string.format("%.2f%%", (data.progress or 0) * 100),
        Parent = progressBar
    })

    local nextBtn = create("TextButton", {
        Name = "NextButton",
        Size = UDim2.new(0.15, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BackgroundTransparency = 0.7,
        Font = Enum.Font.GothamBold,
        Text = "▶",
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextScaled = true,
        Parent = frame
    })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = nextBtn })

    self.components.title = title
    self.components.content = content
    self.components.progress = fill
    self.components.progressLabel = percent
    self.components.prev = prevBtn
    self.components.next = nextBtn
end

function GUI:updateQuest(data)
    if self.components.title then self.components.title.Text = data.title or "📜 No Quest" end
    if self.components.content then self.components.content.Text = data.content or "No active quest available" end
    if self.components.progress then
        TweenService:Create(self.components.progress, TweenInfo.new(0.3), {
            Size = UDim2.new(math.clamp(data.progress or 0, 0, 1), 0, 1, 0)
        }):Play()
    end
    if self.components.progressLabel then
        self.components.progressLabel.Text = string.format("%.2f%%", (data.progress or 0) * 100)
    end
end

function GUI:connectButton(name, callback)
    local button = self.components[name:lower()]
    if button and callback then
        return button.MouseButton1Click:Connect(callback)
    end
end

return GUI

local HttpService = game:GetService('HttpService')
local WP = game:GetService('Workspace')
local BalloonsFolder  = WP:FindFirstChild("Balloons")
loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
local FluentLibrary = shared.ModuleLoader:load(_G.URL.."/UI/WindowLua.lua")
local SaveManager = shared.ModuleLoader:load(_G.URL.."/UI/SaveManager.lua")
local InterfaceManager = shared.ModuleLoader:load(_G.URL.."/UI/InterfaceManager.lua")
local BeesModule = shared.ModuleLoader:load(_G.URL.."/Data/Bee.lua")

local FluentUI = {}
FluentUI.__index = FluentUI
shared.FluentLib = FluentLibrary
local DEFAULT_CONFIG = {
    Title = "Bee Swarm 1.0.0",
    SubTitle = "by SixZac",
    TabWidth = 125,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    ToggleKey = Enum.KeyCode.F
}

function FluentUI.new()
    local self = setmetatable({}, FluentUI)
    self.Fluent = FluentLibrary
    self.Window = self.Fluent:CreateWindow({
        Title = DEFAULT_CONFIG.Title .. " | " ,
        SubTitle = DEFAULT_CONFIG.SubTitle,
        TabWidth = DEFAULT_CONFIG.TabWidth,
        Size = DEFAULT_CONFIG.Size,
        Acrylic = DEFAULT_CONFIG.Acrylic,
        Theme = DEFAULT_CONFIG.Theme,
        MinimizeKey = DEFAULT_CONFIG.ToggleKey
    })

    self.npcHelper = shared.helper.Npc
    self.Options = self.Fluent.Options
    self.Tabs = {}

    self:createDefaultTabs()
    self:initMainTab()
    self:initPlayerTab()
    self:initQuestTab()
    self:initHiveTab()
    self:initSettingTab()

    SaveManager:SetLibrary(self.Fluent)
    InterfaceManager:SetLibrary(self.Fluent)
    InterfaceManager:SetFolder("FluentScriptHub")
    SaveManager:SetFolder("FluentScriptHub/specific-game")

    InterfaceManager:BuildInterfaceSection(self.Tabs.Settings)
    SaveManager:BuildConfigSection(self.Tabs.Settings)
    self.Window:SelectTab(1)

    if self.afkConnection then self.afkConnection:Disconnect() end
    self.afkConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    SaveManager:LoadAutoloadConfig()
    return self
end

function FluentUI:createDefaultTabs()
    self.Tabs.Main = self.Window:AddTab({Title = "Main", Icon = "home"})
    self.Tabs.Player = self.Window:AddTab({Title = "Player", Icon = "user"})
    self.Tabs.Quest = self.Window:AddTab({Title = "Quest", Icon = "book"})
    self.Tabs.Hive = self.Window:AddTab({Title = "Hive", Icon = "circle"})
    self.Tabs.Settings = self.Window:AddTab({
        Title = "Settings",
        Icon = "settings"
    })
end

function FluentUI:initMainTab()

    self.FieldDropdown = self.Tabs.Main:AddDropdown("FieldDropdown", {
        Title = "Select Field",
        Values = shared.helper.Field:getAllFieldDisplayNames(),
        Multi = false,
        Default = 1,
    })
    self.autoFarmToggle = self.Tabs.Main:AddToggle("autoFarm", {
        Title = "Auto Farm",
        Default = false
    })
    self.autoDig = self.Tabs.Main:AddToggle("autoDig", {
        Title = "Auto Dig",
        Default = false
    })

    self.PollenInfo = self.Tabs.Main:AddParagraph({
        Title = "🌾 Pollen Collection",
        Content = "Rate/sec: 0\nHourly: 0\nDaily: 0\nTotal: 0"
    })

    self.HoneyInfo = self.Tabs.Main:AddParagraph({
        Title = "🍯 Honey Production",
        Content = "Rate/sec: 0\nHourly: 0\nDaily: 0\nTotal: 0"
    })
    self.sessionTimeInfo = self.Tabs.Main:AddParagraph({
        Title = "⏱️ Session Time",
        Content = "00:00:00"
    })



    
    -- ==================================
    self.autoDig:OnChanged(function(value)
        shared.main.autoDig = value
        if not value then return end
        task.spawn(function()
            while shared.main.autoDig do
                if not shared.helper.Player:isCapacityFull() then
                    local Event = game:GetService("ReplicatedStorage").Events.ToolCollect
                    Event:FireServer()
                end
                task.wait(0.4)
            end
        end)
    end)

    self.autoFarmToggle:OnChanged(function(val)
        task.spawn(function()
            if shared.Bot then 
                if val then shared.Bot:start() end
                if not val then shared.Bot:stop() end
            end
        end)
       
    end)

    
   self.FieldDropdown:OnChanged(function(value)
        self:onFieldChange(value)
    end)

    
end

function FluentUI:initPlayerTab()
    self.walkSpeedSlider = self.Tabs.Player:AddSlider("WalkSpeedSlider", {
        Title = "WalkSpeed",
        Description = "Adjust player walk speed",
        Default = shared.main.WalkSpeed,
        Min = shared.main.defaultWalkSpeed,
        Max = 70,
        Rounding = 0,
        Callback = function(Value)
            shared.main.WalkSpeed = Value
            if shared.helper.Player then shared.helper.Player:updateStats() end
        end
    })

    self.jumpPowerSlider = self.Tabs.Player:AddSlider("JumpPowerSlider", {
        Title = "JumpPower",
        Description = "Adjust player jump power",
        Default = shared.main.JumpPower,
        Min = shared.main.defaultJumpPower,
        Max = 100,
        Rounding = 0,
        Callback = function(Value)
            shared.main.JumpPower = Value
            if shared.helper.Player then shared.helper.Player:updateStats() end
        end
    })
    self.Tabs.Player:AddKeybind("BackToHiveBind", {
        Title = "Back To Hive",
        Mode = "Toggle",
        Default = "B",
        Callback = function()
            if shared.Bot and shared.Bot.Hive then
                local pos = shared.Bot.Hive:getHivePosition()
                
                if shared.Bot and shared.Bot.isStart then 
                    shared.Bot:stop()
                    self.autoFarmToggle:SetValue(false)
                    self.Fluent:Notify({Title = "Bot", Content = "Bot stopped", Duration = 3})
                 end
                shared.helper.Player:tweenTo(pos, 1)
            end
        end
    })
    self.Tabs.Player:AddKeybind("ToggleBotBind", {
        Title = "Toggle Bot",
        Mode = "Toggle",
        Default = "Q",
        Callback = function()
            if not shared.Bot then return end
            if shared.Bot.isStart then
                self.autoFarmToggle:SetValue(false)
            else
                self.autoFarmToggle:SetValue(true)
            end
        end
    })



end

function FluentUI:initQuestTab()
    local questTab = self.Tabs.Quest

    self.doNpcQuestDropdown = questTab:AddDropdown("MultiDropdown", {
        Title = "Do NPC Quests",
        Description = "Select NPCs to do quests.",
        Values = self.npcHelper:getNpcNames(),
        Multi = true,
        Default = {},
    })

    self.autoQuestToggle = questTab:AddToggle("autoQuestToggle", {
        Title = "Auto Quest",
        Default = false
    })

    local bestFieldSection = questTab:AddSection("Best Field")
    local bestFieldEnabled = shared.helper.Field:getBestFieldIndexesByType()
    self.bestWhiteField = bestFieldSection:AddDropdown("bestWhiteField", {
        Title = "⬜",
        Values = shared.helper.Field:getAllFieldDisplayNames(),
        Multi = false,
        Default = bestFieldEnabled[1], --17
    })
    self.bestBlueField = bestFieldSection:AddDropdown("bestBlueField", {
        Title = "🟦",
        Values = shared.helper.Field:getAllFieldDisplayNames(),
        Multi = false,
        Default = bestFieldEnabled[2], --12
    })
    self.bestRedField = bestFieldSection:AddDropdown("bestRedField", {
        Title = "🟥",
        Values = shared.helper.Field:getAllFieldDisplayNames(),
        Multi = false,
        Default = bestFieldEnabled[3], --18
    })
    
    self.bestWhiteField:OnChanged(function(Value)
        shared.helper.Field:setBestFieldByFieldType("White", Value)
    end)
    self.bestBlueField:OnChanged(function(Value)
        shared.helper.Field:setBestFieldByFieldType("Blue", Value)
    end)
    self.bestRedField:OnChanged(function(Value)
        shared.helper.Field:setBestFieldByFieldType("Red", Value)
    end)
end


function FluentUI:initHiveTab()
    local hiveTab = self.Tabs.Hive
    local bestFieldSection = hiveTab:AddSection("Auto jelly")

    local function encodeSelection(data)
        local selected = {}
        for key in pairs(data) do
            table.insert(selected, key)
        end
        return selected
    end

    local jellySelectedBee = bestFieldSection:AddDropdown("jellySelectedBee", {
        Title = "Select Bees",
        Values = BeesModule:getAllBees(),
        Multi = true,
        Default = {},
    })
    
    jellySelectedBee:OnChanged(function(bees)
        local selectedBees = encodeSelection(bees)
        shared.main.autoJelly.selectedBees = selectedBees
    end)

    local jellySelectedRare = bestFieldSection:AddDropdown("jellySelectedRare", {
        Title = "Select Rarities",
        Values = BeesModule:getAllRarityTypes(),
        Multi = true,
        Default = {},
    })

    jellySelectedRare:OnChanged(function(types)
        local selectedTypes = encodeSelection(types)
        shared.main.autoJelly.selectedTypes = selectedTypes
    end)

    bestFieldSection:AddInput("jellyRowPos", {
        Title = "Hive Row (X)",
        Default = "1",
        Placeholder = "Enter hive row (X)",
        Numeric = true,
        Finished = false,
        Callback = function(X)
            shared.main.autoJelly.X = X
        end
    })

    bestFieldSection:AddInput("jellyColumnPos", {
        Title = "Hive Column (Y)",
        Default = "1",
        Placeholder = "Enter hive column (Y)",
        Numeric = true,
        Finished = false,
        Callback = function(Y)
            shared.main.autoJelly.Y = Y
           
        end
    })

    self.jellyAnyGifted = bestFieldSection:AddToggle("jellyAnyGifted", {
        Title = "Stop at Any Gifted Bee",
        Default = false,
        Callback = function(value)
            shared.main.autoJelly.anyGifted = value
        end
    })

    self.jellyStartButton = nil
    self.jellyStartButton = bestFieldSection:AddButton({
        Title = "Start",
        Callback = function()
            if shared.main.autoJelly.isRunning then
                BeesModule:stopAutoJelly()
                self.jellyStartButton:SetTitle("Start")
            else
                BeesModule:startAutoJelly()
                self.jellyStartButton:SetTitle("Stop")
            end
        end
    })


    local beeToolsSection = hiveTab:AddSection("Bee Tools")
    self.selectedBeeInfo = beeToolsSection:AddParagraph({
        Title = "Selected Bee",
        Content = "-"
    })

    local rowPos = beeToolsSection:AddInput("rowPos", {
        Title = "Hive Row (X)",
        Default = "1",
        Placeholder = "Enter hive row (X)",
        Numeric = true,
        Finished = false,
        Callback = function(Value)
            shared.main.BeeTab.row = Value or 1
            shared.helper.Bee:setCurrentBee()
        end
    })

    local columnPos = beeToolsSection:AddInput("columnPos", {
        Title = "Hive Column (Y)",
        Default = "1",
        Placeholder = "Enter hive column (Y)",
        Numeric = true,
        Finished = false,
        Callback = function(Value)
            shared.main.BeeTab.column = Value or 1
            shared.helper.Bee:setCurrentBee()
        end
    })

    local feedAmount = beeToolsSection:AddInput("feedAmount", {
        Title = "Amount to Feed",
        Default = "1",
        Placeholder = "Enter amount",
        Numeric = true,
        Finished = false, 
        Callback = function(Value)
            shared.main.BeeTab.amount  = tonumber(Value)
        end
    })

    local foodType = beeToolsSection:AddDropdown("foodType", {
        Title = "Select Food Type",
        Values = {
            "Treat", "SunflowerSeed", "Strawberry", "Pineapple",
            "Blueberry", "Bitterberry", "MoonCharm"
        },
        Multi = false,
        Default = 1,
    })

    beeToolsSection:AddButton({
        Title = "Feed Bee",
        Description = "Click to feed the selected bee",
        Callback = function(Value)
            shared.helper.Bee:feedBee()
        end
    })
    beeToolsSection:AddButton({
        Title = "🍪 Feed treat to Lowest Level Bee",
        Description = "Click to feed the lowest level bee",
        Callback = function()
            local beeHelper = shared.helper.Bee
            beeHelper:refreshData()
            
            local bee = beeHelper:getLowestLevelBee()
            if bee then
                local HivePosition = bee.HivePosition
                local X = HivePosition.X
                local Y = HivePosition.Y
                local foodAmount = shared.main.BeeTab.amount

                self.Window:Dialog({
                    Title = "Confirm Feed",
                    Content = string.format(
                        "Are you sure you want to feed %d Treat(s) to the lowest level bee at position (%d, %d)?",
                        foodAmount, X, Y
                    ),
                    Buttons = {
                        {
                            Title = "✅ Confirm",
                            Callback = function()
                               beeHelper:feedBee(X, Y,foodAmount, "Treat" , false)
                            end
                        },
                        { Title = "❌ Cancel" }
                    }
                })
            else
                self.Window:Dialog({
                    Title = "No Bee Found",
                    Content = "There is no bee available to feed.",
                    Buttons = {
                        { Title = "OK" }
                    }
                })
            end
        end
    })


    foodType:OnChanged(function(Value)
        shared.main.BeeTab.foodType = Value
    end)

    feedAmount:OnChanged(function()
        
    end)
end

function FluentUI:initSettingTab()
    self.hideDecorations = self.Tabs.Settings:AddToggle("hideDecorations", {
        Title = "Hide Decorations",
        Default = true
    })

    self.hideBalloon = self.Tabs.Settings:AddToggle("hideBalloon", {
        Title = "Hide Balloon",
        Default = false
    })

    local folders = {
        workspace:FindFirstChild("Gates"),
        workspace:FindFirstChild("FieldDecos"),
        workspace:FindFirstChild("Decorations"),
        workspace:FindFirstChild("Invisible Walls"),
        workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Fences")
    }

    local skipModels = {
        EggMachine = true,
        JumpGames = true
    }

    local function setPartVisibility(part, val)
        part.CanCollide = not val
        part.Transparency = val and 0.75 or 0
        part.CastShadow = not val
    end

    self.hideBalloon:OnChanged(function(val)
        for _, part in ipairs(BalloonsFolder:GetDescendants()) do
            local class = part.ClassName
            if part:IsA("BasePart") then
                part.Transparency = val and 1 or 0.6
                part.CastShadow = not val
            elseif class == "Beam" or class == "BillboardGui" or class == "ParticleEmitter" then
                part.Enabled = not val
            end
        end
    end)

    self.hideDecorations:OnChanged(function(val)
        for _, folder in ipairs(folders) do
            if not folder then continue end

            for _, part in ipairs(folder:GetDescendants()) do
                if not part:IsA("BasePart") then continue end
                
                if part.Name == "Stump" or (part.Parent and part.Parent.Name == "Stump") then
                    continue
                end
                local ancestorModel = part:FindFirstAncestorWhichIsA("Model")
                if ancestorModel and skipModels[ancestorModel.Name] then continue end

                if ancestorModel and ancestorModel:FindFirstChild("Mushroom") then
                    local primaryPart = ancestorModel.PrimaryPart
                    if primaryPart then
                        setPartVisibility(primaryPart, val)
                    end
                else
                    setPartVisibility(part, val)
                end
            end
        end
    end)
end



function FluentUI:addTab(name, config)
    if self.Tabs[name] then
        warn("Tab '" .. name .. "' already exists")
        return self.Tabs[name]
    end

    self.Tabs[name] = self.Window:AddTab(config)
    return self.Tabs[name]
end

function FluentUI:isAutoFarmEnabled()
    return self.Options and self.Options.autoFarm and
               self.Options.autoFarm.Value or false
end

function FluentUI:setAutoFarm(enabled)
    if self.autoFarmToggle then self.autoFarmToggle:SetValue(enabled) end
end
function FluentUI:onFieldChange(field)
   shared.helper.Field:SetCurrentField(field)
    
end

function FluentUI:destroy()

    self.autoFarmToggle = nil
    self.toggleKeyBind = nil

    if self.Tabs then
        for name in pairs(self.Tabs) do
            self.Tabs[name] = nil
        end
    end

    self.Options = nil
    self.Window = nil
    self.Fluent = nil
    self.Tabs = nil
end


return FluentUI

local UserInputService = game:GetService('UserInputService')
local HiveGuiModule =  shared.ModuleLoader:load(_G.URL.."/Class/Hive-Gui.lua")
local SERVICES = {
    HttpService = game:GetService('HttpService'),
    Workspace = game:GetService('Workspace'),
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    VirtualUser = game:GetService("VirtualUser")
}

local DEFAULT_CONFIG = {
    Title = "Bee Swarm 1.0.0",
    SubTitle = "by SixZac",
    TabWidth = 125,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    ToggleKey = Enum.KeyCode.F
}

local FOOD_TYPES = {
    "Treat", "SunflowerSeed", "Strawberry", "Pineapple",
    "Blueberry", "Bitterberry", "MoonCharm"
}

local SKIP_MODELS = {
    EggMachine = true,
    JumpGames = true,
    Stump = true,
    StarAmuletBuilding = true
}

-- Core FluentUI Class
local FluentUI = {}
FluentUI.__index = FluentUI

-- Dependencies
local function loadDependencies()
    return {
        FluentLibrary = shared.ModuleLoader:load(_G.URL.."/UI/WindowLua.lua"),
        SaveManager = shared.ModuleLoader:load(_G.URL.."/UI/SaveManager.lua"),
        InterfaceManager = shared.ModuleLoader:load(_G.URL.."/UI/InterfaceManager.lua"),
        BeesModule = shared.ModuleLoader:load(_G.URL.."/Data/Bee.lua")
    }
end

-- Utility Functions
local function encodeSelection(data)
    local selected = {}
    for key in pairs(data) do
        table.insert(selected, key)
    end
    return selected
end

local function setPartVisibility(part, isHidden)
    part.CanQuery = false
    part.CanCollide = not isHidden
    part.Transparency = isHidden and 1 or 0
    part.CastShadow = not isHidden
end

-- Main Constructor
function FluentUI.new()
    local self = setmetatable({}, FluentUI)
    local deps = loadDependencies()
    
    self:_initializeCore(deps)
    self:_setupWindow()
    self:_createTabs()
    self:_initializeAllTabs()
    self:_setupManagers(deps)
    self:_setupAntiAFK()
    
    deps.SaveManager:LoadAutoloadConfig()
    return self
end

-- Core Initialization
function FluentUI:_initializeCore(deps)
    self.Fluent = deps.FluentLibrary
    self.SaveManager = deps.SaveManager
    self.InterfaceManager = deps.InterfaceManager
    self.BeesModule = deps.BeesModule
    self.npcHelper = shared.helper.Npc
    self.Tabs = {}
    shared.FluentLib = deps.FluentLibrary
end

function FluentUI:_setupWindow()
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    local width, height, tabWidth
    local viewportSize = workspace.CurrentCamera.ViewportSize

    if isMobile then
        width = math.clamp(viewportSize.X * 0.9, 300, 500)
        height = math.clamp(viewportSize.Y * 0.5, 300, 400)
        tabWidth = 100
        self:createFloatingButton()
    else
        width = math.clamp(viewportSize.X * 0.6, 300, 600)
        height = math.clamp(viewportSize.Y * 0.6, 300, 500)
        tabWidth = 160
    end
    self.Window = self.Fluent:CreateWindow({
        Title = DEFAULT_CONFIG.Title .. " | updated",
        SubTitle = DEFAULT_CONFIG.SubTitle,
        TabWidth = tabWidth,
        Size = UDim2.fromOffset(width, height),
        Acrylic = DEFAULT_CONFIG.Acrylic,
        Theme = DEFAULT_CONFIG.Theme,
        MinimizeKey = DEFAULT_CONFIG.ToggleKey
    })
    self.Options = self.Fluent.Options
end

function FluentUI:_createTabs()
    local tabConfigs = {
        {name = "Main", title = "Main", icon = "grid"},
        {name = "Player", title = "Player", icon = "user"},
        {name = "Planter", title = "Planter", icon = "sprout"},
        {name = "Hive", title = "Hive", icon = "home"},
        {name = "Misc", title = "Miscellaneous", icon = "star"},
        {name = "Stats", title = "Statistics", icon = "bar-chart"},
        {name = "Settings", title = "Settings", icon = "settings"}
        -- {name = "Token", title = "Token Setting", icon = "coins"},
        -- {name = "Quest", title = "Quest", icon = "book"},
        -- {name = "Combat", title = "Combat", icon = "sword"},
    }
    
    for _, config in ipairs(tabConfigs) do
        self.Tabs[config.name] = self.Window:AddTab({
            Title = config.title,
            Icon = config.icon
        })
    end
end

function FluentUI:_initializeAllTabs()
    self:_initMainTab()
    self:_initPlayerTab()
    self:_initPlanterTab()
    self:_initHiveTab()
    self:_initMiscTab()
    self:_initStatsTab()
    self:_initSettingsTab()
    -- self:_initTokenTab()
    -- self:_initCombatTab()
    -- self:_initQuestTab()
end

function FluentUI:_setupManagers(deps)
    deps.SaveManager:SetLibrary(self.Fluent)
    deps.InterfaceManager:SetLibrary(self.Fluent)
    deps.InterfaceManager:SetFolder("FluentScriptHub")
    deps.SaveManager:SetFolder("FluentScriptHub/specific-game")
    
    deps.InterfaceManager:BuildInterfaceSection(self.Tabs.Settings)
    deps.SaveManager:BuildConfigSection(self.Tabs.Settings)
    
    self:_setIgnoreIndexes(deps.SaveManager)
    self.Window:SelectTab(1)
end

function FluentUI:_setIgnoreIndexes(saveManager)
    saveManager:SetIgnoreIndexes({
        "jellySelectedBee", "jellySelectedRare", "jellyRowPos", "jellyColumnPos",
        "jellyAnyGifted","jellyNewGifted", "rowPos", "columnPos", "feedAmount", "foodType"
    })
end

function FluentUI:_setupAntiAFK()
    if self.afkConnection then 
        self.afkConnection:Disconnect() 
    end
    
    self.afkConnection = SERVICES.Players.LocalPlayer.Idled:Connect(function()
        SERVICES.VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        SERVICES.VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

-- Tab Initialization Methods
function FluentUI:_initMainTab()
    local mainTab = self.Tabs.Main
    
    -- Field Selection
    self.FieldDropdown = mainTab:AddDropdown("FieldDropdown", {
        Title = "🌾 Select Field",
        Values = shared.helper.Field:getAllFieldDisplayNames(),
        Multi = false,
        Default = 1,
    })
    
    -- Main Toggles
    self:_createMainToggles(mainTab)
    
    -- Event Handlers
    self:_setupMainEventHandlers()
end

function FluentUI:_createMainToggles(mainTab)
    local mainSection = mainTab:AddSection("Farm section")
    self.autoFarmToggle = mainSection:AddToggle("autoFarm", {
        Title = "Auto Farm",
        Default = false
    })
    
    self.autoDig = mainSection:AddToggle("autoDig", {
        Title = "Auto Dig",
        Default = false
    })
    
    self.autoSprinkler = mainSection:AddToggle("autoSprinkler", {
        Title = "Auto Sprinkler",
        Default = false,
        Callback = function(val)
            shared.main.autoSprinkler = val
        end
    })
    self.autoFarmSprout = mainSection:AddToggle("autoFarmSprout", {
        Title = "Farm Sprout",
        Default = false,
        Callback = function(val)
            shared.main.Farm.autoFarmSprout = val
        end
    })
    self.autoFarmBubble = mainSection:AddToggle("autoFarmBubble", {
        Title = "Farm Bubble",
        Default = false,
        Callback = function(val)
            shared.main.autoFarmBubble = val
        end
    })
    self.ignoreHoneyToken = mainSection:AddToggle("ignoreHoneyToken", {
        Title = "Ignore Honey Tokens",
        Description = "Ignore honey tokens while farming/do quest",
        Default = shared.main.ignoreHoneyToken,
        Callback = function(val)
            shared.main.ignoreHoneyToken = val
        end
    })
    
    local balloonSection = mainTab:AddSection("Balloon section")
    self.autoConvertBalloon = balloonSection:AddToggle("autoConvertBalloon", {
        Title = "Auto Convert Hive Balloon",
        Description = "🎈 Automatically converts the hive balloon when it's available.",
        Default = false,
        Callback = function(val)
            shared.main.autoConvertBalloon = val
        end
    })

    self.convertAtBlessing = balloonSection:AddSlider("convertAtBlessing", {
        Title = "Convert At Blessing",
        Description = "🔁 Starts converting balloon when blessing count reaches this value.",
        Default = 1,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Callback = function(Value)
            shared.main.convertAtBlessing = Value
        end
    })

 


    

end

function FluentUI:_setupMainEventHandlers()
    self.autoDig:OnChanged(function(value)
        shared.main.autoDig = value
        if value then
            self:_startAutoDigLoop()
        end
    end)
    
    self.autoFarmToggle:OnChanged(function(val)
        task.spawn(function()
            if shared.Bot then
                if val then 
                    shared.Bot:start() 
                else 
                    shared.Bot:stop() 
                end
            end
        end)
    end)
    
    self.FieldDropdown:OnChanged(function(value)
        self:onFieldChange(value)
    end)
end

function FluentUI:_startAutoDigLoop()
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local GuiService = game:GetService("GuiService")
    task.spawn(function()
       
        -- while shared.main.autoDig do

        --     if not shared.helper.Player:isCapacityFull() and (shared.Bot and shared.Bot.isStart) then
        --         local screenSize = GuiService:GetScreenResolution()
        --         local y = screenSize.Y

        --         VirtualInputManager:SendMouseButtonEvent(0, y, 0, true, game, 1)
        --         VirtualInputManager:SendMouseButtonEvent(0, y, 0, false, game, 1)
        --     end
        --     task.wait(.25)
        -- end

        while shared.main.autoDig do
            if not shared.helper.Player:isCapacityFull() then
                local Event = SERVICES.ReplicatedStorage.Events.ToolCollect
                Event:FireServer()
            end
            task.wait(0.4)
        end
    end)
end

function FluentUI:_initPlayerTab()
    local playerTab = self.Tabs.Player
    
    -- Equipment Section
    local equipmentSection = playerTab:AddSection("Equipment")
    self:_createEquipmentControls(equipmentSection)
    
    -- Movement Section
    local movementSection = playerTab:AddSection("Movement")
    self:_createMovementControls(movementSection)
    
    -- Keybinds Section
    local keybindsSection = playerTab:AddSection("Key bind")
    self:_createKeybinds(keybindsSection)
end
function FluentUI:_initPlanterTab()
    local planterTab = self.Tabs.Planter
    local PlanterConfig = shared.main.Planter
    local Slots = PlanterConfig.Slots

    self.autoPlanterToggle = planterTab:AddToggle("autoPlanterToggle", {
        Title = "Enable Auto Planters",
        Description = "Automatically manage planter placement and harvesting.",
        Default = PlanterConfig.autoPlanterEnabled or false,
        Callback = function(value)
            PlanterConfig.autoPlanterEnabled = value
        end
    })

    local activePlanterSection = planterTab:AddSection("Active Planters")
    self.activePlanterSlot1 = activePlanterSection:AddParagraph({
        Title = "Planter Slot 1",
        Content = "No planter is currently placed."
    })
    self.activePlanterSlot2 = activePlanterSection:AddParagraph({
        Title = "Planter Slot 2",
        Content = "No planter is currently placed."
    })
    self.activePlanterSlot3 = activePlanterSection:AddParagraph({
        Title = "Planter Slot 3",
        Content = "No planter is currently placed."
    })

    for i = 1, 3 do
        local section = planterTab:AddSection("Auto Planter Slot " .. i)

        self["autoPlanter" .. i] = section:AddDropdown("autoPlanter" .. i, {
            Title = "Select Planter Type",
            Values = {'None', "Paper", "Plastic", "Blue Clay", "Red Clay", "Candy", "Tacky", "Pesticide"},
            Multi = false,
            Default = 1,
            Callback = function(planter)
                Slots[i].PlanterType = planter
            end
        })

        self["autoPlanter" .. i .. "Field"] = section:AddDropdown("autoPlanter" .. i .. "Field", {
            Title = "Select Field",
            Values = shared.helper.Field:getAllFieldDisplayNames(),
            Multi = false,
            Default = 1,
            Callback = function(field)  
                Slots[i].Field = field
            end
        })

        self["autoPlanter" .. i .. "HarvestAt"] = section:AddSlider("autoPlanter" .. i .. "HarvestAt", {
            Title = "Harvest At",
            Description = "Automatically harvest the planter at a certain growth percentage.",
            Default = Slots[i].HarvestAt or 100,
            Min = 1,
            Max = 100,
            Rounding = 0,
            Callback = function(value)
                Slots[i].HarvestAt = tonumber(value)
            end
        })
    end
end


function FluentUI:_createEquipmentControls(section)
    self.autoHoneyMask = section:AddToggle("autoHoneyMask", {
        Title = "Auto Honey Mask",
        Description = "Automatically equip Honey Mask when converting",
        Default = shared.main.Equip.autoHoneyMask,
        Callback = function(val)
            shared.main.Equip.autoHoneyMask = val
        end
    })
    local playerHelper = shared.helper.Player
    local equipedMask = playerHelper:getEqupipedMask()
    local maskIndex =  playerHelper:getMaskIndex(equipedMask)
    self.defaultMask = section:AddDropdown("defaultMask", {
        Title = "Default mask",
        Values = playerHelper:getPlayerMasks(),
        Multi = false,
        Default = maskIndex,
        Callback = function(mask)
            shared.main.Equip.defaultMask = mask
            playerHelper:equipMask(mask)
        end
    })
end

function FluentUI:_createMovementControls(section)
    self.walkSpeedSlider = section:AddSlider("WalkSpeedSlider", {
        Title = "WalkSpeed",
        Description = "Adjust player walk speed",
        Default = shared.main.WalkSpeed,
        Min = shared.main.defaultWalkSpeed,
        Max = 70,
        Rounding = 0,
        Callback = function(Value)
            shared.main.WalkSpeed = Value
            if shared.helper.Player then 
                shared.helper.Player:updateStats() 
            end
        end
    })
    
    self.jumpPowerSlider = section:AddSlider("JumpPowerSlider", {
        Title = "JumpPower",
        Description = "Adjust player jump power",
        Default = shared.main.JumpPower,
        Min = shared.main.defaultJumpPower,
        Max = 100,
        Rounding = 0,
        Callback = function(Value)
            shared.main.JumpPower = Value
            if shared.helper.Player then 
                shared.helper.Player:updateStats() 
            end
        end
    })
end

function FluentUI:_createKeybinds(section)
    section:AddKeybind("BackToHiveBind", {
        Title = "Back To Hive",
        Mode = "Toggle",
        Default = "B",
        Callback = function()
            self:_handleBackToHive()
        end
    })
    
    section:AddKeybind("ToggleBotBind", {
        Title = "Toggle Bot",
        Mode = "Toggle",
        Default = "Q",
        Callback = function()
            self:_handleToggleBot()
        end
    })
end

function FluentUI:_handleBackToHive()
    if shared.Bot and shared.Bot.Hive then
        local pos = shared.Bot.Hive:getHivePosition()
        
        if shared.Bot and shared.Bot.isStart then 
            shared.Bot:stop()
            self.autoFarmToggle:SetValue(false)
            self.Fluent:Notify({
                Title = "Bot", 
                Content = "Bot stopped", 
                Duration = 3
            })
        end
        shared.helper.Player:tweenTo(pos, 1)
    end
end

function FluentUI:_handleToggleBot()
    if not shared.Bot then return end
    
    if shared.Bot.isStart then
        self.autoFarmToggle:SetValue(false)
    else
        self.autoFarmToggle:SetValue(true)
    end
end

function FluentUI:_initQuestTab()
    local questTab = self.Tabs.Quest
    
    -- NPC Quest Selection
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
    
    -- Best Fields Section
    local bestFieldSection = questTab:AddSection("Best Field")
    self:_createBestFieldDropdowns(bestFieldSection)
end

function FluentUI:_createBestFieldDropdowns(section)
    local bestFieldEnabled = shared.helper.Field:getBestFieldIndexesByType()
    local fieldConfigs = {
        {name = "bestWhiteField", title = "⬜", default = bestFieldEnabled[1], type = "White"},
        {name = "bestBlueField", title = "🟦", default = bestFieldEnabled[2], type = "Blue"},
        {name = "bestRedField", title = "🟥", default = bestFieldEnabled[3], type = "Red"}
    }
    
    for _, config in ipairs(fieldConfigs) do
        self[config.name] = section:AddDropdown(config.name, {
            Title = config.title,
            Values = shared.helper.Field:getAllFieldDisplayNames(),
            Multi = false,
            Default = config.default,
        })
        
        self[config.name]:OnChanged(function(Value)
            shared.helper.Field:setBestFieldByFieldType(config.type, Value)
        end)
    end
end

function FluentUI:_initHiveTab()
    local hiveTab = self.Tabs.Hive
    
    -- Auto Jelly Section
    local autoJellySection = hiveTab:AddSection("Auto jelly")
    self:_createAutoJellyControls(autoJellySection)
end

function FluentUI:_initMiscTab()
    local MiscTab = self.Tabs.Misc
    
    local fieldboostSection = MiscTab:AddSection("Field Boosts Section")
    self.fieldboosts = fieldboostSection:AddDropdown("fieldboosts", {
        Title = "🚀 Select a Field Boost",
        Values = {"Red Field Booster" , "Blue Field Booster", "Field Booster"},
        Description = "Automatically uses the selected field boost.",
        Multi = true,
        Default = {},
         Callback = function(Value)
            local toys = {}
            for toyName, value in pairs(Value) do
                table.insert(toys, toyName)
            end
            shared.main.Farm.fieldBoost = toys
        end
    })

    local MemoryMatchSection = MiscTab:AddSection("Memory Match Section")
    self.memoryMatches = MemoryMatchSection:AddDropdown("memoryMatches", {
        Title = "🧠 Select Memory Matches",
        Values = {"Memory Match", "Mega Memory Match", "Night Memory Match", "Extreme Memory Match"},
        Description = "Automatically play selected Memory Matches.",
        Multi = true,
        Default = {},
        Callback = function(Value)
            local memoryMatchs = {}
            for name, _ in pairs(Value) do
                table.insert(memoryMatchs, name)
            end
            shared.main.Misc.memoryMatchs = memoryMatchs
        end
    })


end

function FluentUI:_initTokenTab()
    local TokenTab = self.Tabs.Token
    local tokenPrioritySection = TokenTab:AddSection("Edit Token Priority")

    -- Create a sorted list of tokens by Priority DESC
    local sortedTokens = {}
    for name, token in pairs(shared.TokenDataModule.tokens) do
        table.insert(sortedTokens, {Name = name, Token = token})
    end
    table.sort(sortedTokens, function(a, b)
        return a.Token.Priority > b.Token.Priority
    end)

    -- Add inputs in sorted order
    for _, entry in ipairs(sortedTokens) do
        local name, token = entry.Name, entry.Token
        tokenPrioritySection:AddInput("priority_" .. name, {
            Title = name,
            Default = token.Priority,
            Placeholder = "Enter priority",
            Numeric = true,
            Finished = false,
            Callback = function(value)
                local num = tonumber(value)
                if num then
                    token.Priority = num
                    print("Updated", name, "to priority", num)
                else
                    warn("Invalid number for token:", name)
                end
            end
        })
    end

    -- local tokenList = tokenPrioritySection:AddDropdown("tokenList", {
    --     Title = "Select a token to edit",
    --     Values = shared.TokenDataModule:getAllTokenNames(),
    --     Multi = false,
    --     Default = 1,
    -- })

    -- local tokenPriority = tokenPrioritySection:AddInput("tokenPriority", {
    --     Title = "Token Priority",
    --     Default = 1,
    --     Placeholder = "Enter a number",
    --     Numeric = true,
    --     Finished = false, 
    --     Callback = function(Value)
    --         print("Token priority input changed:", Value)
    --     end
    -- })

    -- local saveButton = tokenPrioritySection:AddButton({
    --     Title = "Press to Save Data",
    --     Callback = function()

    --     end
    -- })

    -- local tokenDataSection = TokenTab:AddSection("Token Data")
    -- self.tokenInfo = tokenDataSection:AddParagraph({
    --     Title = "Token Info",
    --     Content = shared.TokenDataModule:getFormattedTokenList()
    -- })
end


function FluentUI:_initStatsTab()
    local StatsTab = self.Tabs.Stats
    local statisticsSection = StatsTab:AddSection("Statistics")

    self.HoneyInfo = statisticsSection:AddParagraph({
        Title = "🍯 Honey Production",
        Content = "Hourly: 0\nDaily: 0\nTotal: 0"
    })

    self.tokenCollectedInfo = statisticsSection:AddParagraph({
        Title = "🎯 Tokens Collected",
        Content = "-"
    })

    self.sessionTimeInfo = statisticsSection:AddParagraph({
        Title = "⏱️ Session Time",
        Content = "00:00:00"
    })

   
end

function FluentUI:_initCombatTab()
    local combatTab = self.Tabs.Combat

    self.autoHuntMonster = combatTab:AddToggle("autoHuntMonster", {
        Title = "Auto Hunt Monsters",
        Description = "⚔️ Automatically hunts spawned monsters on the map.",
        Default = false,
        Callback = function(val)
            shared.main.Monster.autoHunt = val
        end
    })

    local monsterToHuntSection = combatTab:AddSection("Monsters to hunt")
    self.monsterToHunt = monsterToHuntSection:AddDropdown("monsterToHunt", {
        Title = "Select Monsters",
        Description = "📋 Choose which monsters to hunt automatically.",
        Values = { "Ladybug", "Rhino Beetle","Spider", "Mantis", "Werewolf", "Scorpion"},
        Multi = true,
        Default = {},
        Callback = function(val)
            local monsters = {}
            for monsterName, value in pairs(val) do
                table.insert(monsters, monsterName)
            end
            shared.main.Monster.monsters = monsters
            -- print(HttpService:JSONEncode(monsters))
        end
    })
    local monsterStatusSection = combatTab:AddSection("Monsters Status")
    self.monsterStatusInfo = monsterStatusSection:AddParagraph({
        Title = "Monster Status",
        Content = table.concat({
            "Spider: 🔴 Cooldown", 
            "Ladybug: 🔴 Cooldown", 
            "Rhino Beetle: 🔴 Cooldown", 
            "Mantis: 🔴 Cooldown", 
            "Werewolf: 🔴 Cooldown",
            "Scorpion: 🔴 Cooldown",
        }, "\n")
    })

    local autoViciousbeeSection = combatTab:AddSection("Auto Vicious bee")
    self.autoViciousbee = autoViciousbeeSection:AddToggle("autoViciousbee", {
        Title = "Auto Hunt Vicious bee",
        Description = "⚔️ Automatically hunts vicious bee on the map.",
        Default = false,
        Callback = function(val)
            shared.main.Monster.vicious.autoViciousbee = val
        end
    })
    self.viciousMaxLevel = autoViciousbeeSection:AddSlider("viciousMaxLevel", {
        Title = "Max Level",
        Default = 1,
        Min = 1,
        Max = 12,
        Rounding = 0,
        Callback = function(Value)
            shared.main.Monster.vicious.maxLevel = Value
        end
    })

end


function FluentUI:_createAutoJellyControls(section)
    -- Bee Selection
    local jellySelectedBee = section:AddDropdown("jellySelectedBee", {
        Title = "Select Bees",
        Values = self.BeesModule:getAllBees(),
        Multi = true,
        Default = {},
    })
    
    jellySelectedBee:OnChanged(function(bees)
        shared.main.autoJelly.selectedBees = encodeSelection(bees)
    end)
    
    -- Rarity Selection
    local jellySelectedRare = section:AddDropdown("jellySelectedRare", {
        Title = "Select Rarities",
        Values = self.BeesModule:getAllRarityTypes(),
        Multi = true,
        Default = {},
    })
    
    jellySelectedRare:OnChanged(function(types)
        shared.main.autoJelly.selectedTypes = encodeSelection(types)
    end)
    self.openBeeSlot = section:AddButton({
        Title = "Select Bee Slot",
        Description = "Selected Bee Slot: (" ..  1 .. ", " .. 1 .. ")",
        Callback = function()
            local Bees = shared.helper.Hive:getAllBees()
            if self.hiveGUI then 
                self.hiveGUI:DestroyGui()
                self.hiveGUI = nil
                return
            end


            self.hiveGUI = HiveGuiModule:new()

            for _, beeData in pairs(Bees) do
                local x, y = beeData.X, beeData.Y
                local isSelected = shared.main.autoJelly.X == x and shared.main.autoJelly.Y == y
                if x and y then
                    self.hiveGUI:createGrid(x, y, beeData, isSelected)
                end
            end

            self.hiveGUI:finalizeGrid()

            self.hiveGUI.OnGridClick = function(x, y)
                shared.main.autoJelly.X = x
                shared.main.autoJelly.Y = y
                self.openBeeSlot:SetDesc("Selected Bee Slot: (" .. x .. ", " .. y .. ")")
                if self.hiveGUI then 
                    self.hiveGUI:DestroyGui()
                    self.hiveGUI = nil
                end
            end

        end
    })

    -- Any Gifted Toggle
    self.jellyAnyGifted = section:AddToggle("jellyAnyGifted", {
        Title = "Stop at Any Gifted Bee",
        Description = "🟡 Stops auto jelly when any bee becomes gifted, even if it's already owned.",
        Default = false,
        Callback = function(value)
            shared.main.autoJelly.anyGifted = value
            if value and self.jellyNewGifted then
                self.jellyNewGifted:SetValue(false)
            end
        end
    })

    -- New Gifted Toggle
    self.jellyNewGifted = section:AddToggle("jellyNewGifted", {
        Title = "Stop at New Gifted Bee",
        Description = "🟣 Stops auto jelly only if the gifted bee is new and not already owned.",
        Default = false,
        Callback = function(value)
            shared.main.autoJelly.newGifted = value
            if value and self.jellyAnyGifted then
                self.jellyAnyGifted:SetValue(false)
            end
        end
    })


    -- Start/Stop Button
    self:_createJellyStartButton(section)
end

function FluentUI:_createJellyStartButton(section)
    self.jellyStartButton = section:AddButton({
        Title = "Start",
        Callback = function()
            if shared.main.autoJelly.isRunning then
                self.BeesModule:stopAutoJelly()
                self.jellyStartButton:SetTitle("Start")
            else
                if self.hiveGUI then self.hiveGUI:DestroyGui() self.hiveGUI = nil end
                self.BeesModule:startAutoJelly()
                self.jellyStartButton:SetTitle("Stop")
            end
        end
    })
end


function FluentUI:_handleFeedLowestLevelBee()
    local beeHelper = shared.helper.Bee
    beeHelper:refreshData()
    
    local bee = beeHelper:getLowestLevelBee()
    if not bee then
        self:_showDialog("No Bee Found", "There is no bee available to feed.", {{"OK"}})
        return
    end
    
    local HivePosition = bee.HivePosition
    local X, Y = HivePosition.X, HivePosition.Y
    local foodAmount = shared.main.BeeTab.amount
    
    self:_showDialog(
        "Confirm Feed",
        string.format("Are you sure you want to feed %d Treat(s) to the lowest level bee at position (%d, %d)?", foodAmount, X, Y),
        {
            {
                "✅ Confirm",
                function()
                    beeHelper:feedBee(X, Y, foodAmount, "Treat", false)
                end
            },
            {"❌ Cancel"}
        }
    )
end

function FluentUI:_showDialog(title, content, buttons)
    local dialogButtons = {}
    for _, button in ipairs(buttons) do
        table.insert(dialogButtons, {
            Title = button[1],
            Callback = button[2]
        })
    end
    
    self.Window:Dialog({
        Title = title,
        Content = content,
        Buttons = dialogButtons
    })
end

function FluentUI:_initSettingsTab()
    local settingsTab = self.Tabs.Settings
    
    -- Hide Decorations Toggle
    self.hideDecorations = settingsTab:AddToggle("hideDecorations", {
        Title = "Hide Decorations",
        Default = true
    })
    
    self.hideDecorations:OnChanged(function(val)
        self:_toggleDecorations(val)
    end)
    
    -- Hide Balloon Toggle
    self.hideBalloon = settingsTab:AddToggle("hideBalloon", {
        Title = "Hide Balloon",
        Default = false
    })
    
    self.hideBalloon:OnChanged(function(val)
        self:_toggleBalloons(val)
    end)
end

function FluentUI:_toggleBalloons(isHidden)
    local balloonsFolder = SERVICES.Workspace:FindFirstChild("Balloons")
    if not balloonsFolder then return end
    
    for _, part in ipairs(balloonsFolder:GetDescendants()) do
        local className = part.ClassName
        if part:IsA("BasePart") then
            part.Transparency = isHidden and 1 or 0.6
            part.CastShadow = not isHidden
        elseif className == "Beam" or className == "BillboardGui" or className == "ParticleEmitter" then
            part.Enabled = not isHidden
        end
    end
end

function FluentUI:_toggleDecorations(isHidden)
    local folders = {
        workspace:FindFirstChild("Gates"),
        workspace:FindFirstChild("FieldDecos"),
        workspace:FindFirstChild("Decorations"),
        workspace:FindFirstChild("Invisible Walls"),
        workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Fences")
    }
    
    for _, folder in ipairs(folders) do
        if not folder then continue end
        
        for _, part in ipairs(folder:GetDescendants()) do
            if not part:IsA("BasePart") then continue end
            if self:_shouldSkipPart(part) then continue end
            
            local ancestorModel = part:FindFirstAncestorWhichIsA("Model")
            if ancestorModel then
                if SKIP_MODELS[ancestorModel.Name] then continue end
                
                if ancestorModel:FindFirstChild("Mushroom") then
                    local primaryPart = ancestorModel.PrimaryPart
                    if primaryPart then
                        setPartVisibility(primaryPart, isHidden)
                    end
                else
                    setPartVisibility(part, isHidden)
                end
            else
                setPartVisibility(part, isHidden)
            end
        end
    end
end

function FluentUI:_shouldSkipPart(part)
    
    return part.Name == "Stump" or (part.Parent and part.Parent.Name == "Stump") or part.Name == "StarAmuletBuilding" or (part.Parent and part.Parent.Name == "StarAmuletBuilding") or part.Name == "TrapTunnel" or (part.Parent and part.Parent.Name == "TrapTunnel")
end

-- Public Methods
function FluentUI:addTab(name, config)
    if self.Tabs[name] then
        warn("Tab '" .. name .. "' already exists")
        return self.Tabs[name]
    end
    
    self.Tabs[name] = self.Window:AddTab(config)
    return self.Tabs[name]
end

function FluentUI:isAutoFarmEnabled()
    return self.Options and self.Options.autoFarm and self.Options.autoFarm.Value or false
end

function FluentUI:setAutoFarm(enabled)
    if self.autoFarmToggle then 
        self.autoFarmToggle:SetValue(enabled) 
    end
end

function FluentUI:onFieldChange(field)
    shared.helper.Field:SetCurrentField(field)
end

function FluentUI:destroy()
    -- Clean up connections
    if self.afkConnection then
        self.afkConnection:Disconnect()
        self.afkConnection = nil
    end
    
    -- Clean up references
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
function FluentUI:createFloatingButton()
    local button = Instance.new("TextButton")
    button.Name = "FloatingButton"
    button.Size = UDim2.fromOffset(80, 50)
    button.Position = UDim2.new(1, -20, 0, 20)
    button.AnchorPoint = Vector2.new(1, 0)

    
    -- Background styling
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    button.AutoButtonColor = false
    button.Text = "Open UI"
    button.TextColor3 = Color3.fromRGB(230, 230, 230)
    button.Font = Enum.Font.GothamSemibold
    button.TextScaled = true
    button.ZIndex = 999

    -- Rounded corners
    local uicorner = Instance.new("UICorner", button)
    uicorner.CornerRadius = UDim.new(0, 12)

    -- Hover effect
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end)

    button.Parent = game.Players.LocalPlayer.PlayerGui:FindFirstChild("ScreenGui")

    local dragging = false
    local dragStart, startPos

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    button.MouseButton1Click:Connect(function()
        self.Window:Minimize()
    end)
end


return FluentUI
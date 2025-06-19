_G.isGithub = true

if _G.isGithub then
    _G.URL = "https://raw.githubusercontent.com/SixZacScript/NewBeeV2/master"
    shared.ModuleLoader = loadstring(game:HttpGet(_G.URL..'/Helpers/ModuleLoader.lua'))()
else
    _G.URL = "NewBeeV2"
    shared.ModuleLoader = loadstring(readfile(_G.URL..'/Helpers/ModuleLoader.lua'))()
end
-- 

local GUIHelperModule = shared.ModuleLoader:load(_G.URL.."/Class/GUI.lua")
local PlayerModule = shared.ModuleLoader:load(_G.URL.."/Helpers/Player.lua")
local MonsterModule = shared.ModuleLoader:load(_G.URL.."/Helpers/Monster.lua")
local FieldModule = shared.ModuleLoader:load(_G.URL.."/Helpers/Field.lua")
local NPCsModule = shared.ModuleLoader:load(_G.URL.."/Data/NPCs.lua")
local BeeModule = shared.ModuleLoader:load(_G.URL.."/Class/Bee.lua")
local GUIHelper = GUIHelperModule.new()
GUIHelper:loading("Loading data...")

-- GUIHelper:createQuestInfo({
--     title = "📜 No active quest",
--     content  = "No active quest available",
--     progress = 0
-- })
shared.onDestroy = function()
    shared.ModuleLoader:destroyAll()
end



shared.main = {
    WalkSpeed = 70,
    JumpPower = 80,
    defaultWalkSpeed = 16,
    defaultJumpPower = 50,
    autoQuest = false,
    autoDig = false,
    autoFarmBubble = false,
    autoSprinkler = false,
    ignoreHoneyToken = false,

    -- Balloon Section
    autoConvertBalloon = false,
    convertAtBlessing = 1,
    
    statusText = GUIHelper:createStatus(),
    Monster = {
        autoHunt = false,
        vicious = {
            autoViciousbee = false,
            maxLevel = 1
        },
        monsters = {},
    },
    Planter = {
        autoPlanterEnabled = false,
        Slots = {
            {
                PlanterType = "None",
                Field = nil,
                HarvestAt = 100,
                Placed = false,
            },
            {
                PlanterType = "None",
                Field = nil,
                HarvestAt = 100,
                Placed = false,
            },
            {
                PlanterType = "None",
                Field = nil,
                HarvestAt = 100,
                Placed = false,
            }
        },
        Actives = {

        }
        
    },
    Equip = {
        autoHooneyMask = false,
        defaultMask = nil,
    },
    BeeTab = {
        row = 1,
        column = 1,
        amount = 1,
        foodType = "Treat",
        currentBee = nil
    },
    autoJelly = {
        X = 1,
        Y = 1,
        selectedTypes = {},
        selectedBees = {},
        anyGifted = false,
        newGifted = false,
        isRunning = false,
    }
}


shared.helper = {
    GUIHelper = GUIHelper,
    Player = PlayerModule.new(),
    Monster = MonsterModule.new(),
    Field = FieldModule.new(),
    Npc = NPCsModule.new(),
    Bee = BeeModule.new()
}

-- Load modules
shared.TokenDataModule = shared.ModuleLoader:load(_G.URL.."/Data/Tokens.lua")
local QuestHelper = shared.ModuleLoader:load(_G.URL.."/Class/Quest.lua")
local FluentModule = shared.ModuleLoader:load(_G.URL.."/UI/Window.lua")
local HiveModule = shared.ModuleLoader:load(_G.URL.."/Helpers/Hive.lua")
local BotModule = shared.ModuleLoader:load(_G.URL.."/Class/Bot.lua")
shared.Fluent = FluentModule.new()
shared.helper.Hive = HiveModule.new()
shared.helper.Quest = QuestHelper.new() 
shared.Bot = BotModule.new()

GUIHelper:stopLoading()
shared.main.Hive = shared.helper.Hive:initHive()



if not _G.isGithub then
    loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
end
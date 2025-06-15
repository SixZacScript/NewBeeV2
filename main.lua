shared.ModuleLoader = loadstring(readfile('NewBeeV2/Helpers/ModuleLoader.lua'))()
local GUIHelperModule = shared.ModuleLoader:load("NewBeeV2/Class/GUI.lua")
local PlayerModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Player.lua")
local MonsterModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Monster.lua")
local FieldModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Field.lua")
local NPCsModule = shared.ModuleLoader:load("NewBeeV2/Data/NPCs.lua")
local BeeModule = shared.ModuleLoader:load("NewBeeV2/Class/Bee.lua")
local GUIHelper = GUIHelperModule.new()
GUIHelper:createQuestInfo({
    title = "📜 No active quest",
    content  = "No active quest available",
    progress = 0
})
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
    statusText = GUIHelper:createStatus(),
    BeeTab = {
        row = 1,
        column = 1,
        amount = 1,
        foodType = "Treat",
        currentBee = nil
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
shared.TokenDataModule = shared.ModuleLoader:load("NewBeeV2/Data/Tokens.lua")
local QuestHelper = shared.ModuleLoader:load("NewBeeV2/Class/Quest.lua")
local FluentModule = shared.ModuleLoader:load("NewBeeV2/UI/Window.lua")
local HiveModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Hive.lua")
local BotModule = shared.ModuleLoader:load("NewBeeV2/Class/Bot.lua")
shared.Fluent = FluentModule.new()
shared.helper.Hive = HiveModule.new()
shared.helper.Quest = QuestHelper.new() 
shared.Bot = BotModule.new()

-- intial hive after all
shared.main.Hive = shared.helper.Hive:initHive()



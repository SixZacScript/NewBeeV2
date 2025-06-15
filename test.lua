local HttpService = game:GetService("HttpService") 
local RetrievePlayerStats = game.ReplicatedStorage.Events.RetrievePlayerStats
local QuestService = require(game.ReplicatedStorage.Quests)


local questName = "Bouncing Around Biomes"
local playerStats = RetrievePlayerStats:InvokeServer() 
local activeQuestData = QuestService:GetActiveData(questName, playerStats)
local progression = QuestService:GetProgression(
    QuestService:Get(questName).Tasks, 
    playerStats,
    activeQuestData and activeQuestData.StartValues,
    questName
)


local jsonData = HttpService:JSONEncode(progression)

-- Save to file
local saveSuccess, saveError = pcall(function()
    writefile("progression.json", jsonData)
end)



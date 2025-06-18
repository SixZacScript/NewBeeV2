local Rep = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerItemPackEvent = Rep.Events.ServerItemPackEvent
local ServerMonsterEvent = Rep.Events.ServerMonsterEvent

local QuestHelper = {}
QuestHelper.__index = QuestHelper

function QuestHelper.new()
    local self = setmetatable({}, QuestHelper)
    self.QuestService = require(Rep.Quests)
    self.allQuests = self.QuestService:GetAllQuests()
    self.playerStats = shared.helper.Player:getPlayerStats()
    self.activeQuest = {}
    self.questHistory = {}
    self.currentQuest = nil
    self.currentTask = nil
    self.isCompleted = false
    self.monsterEvent = {}
    self.collectedStatics = {
        startTime = tick(),
        totalCollectedPollen = 0,
        totalConvertHoney = 0,
        highestPollenPerSec = 0
    }

    self:_setupEventHandlers()
    self:startCollectionRateUpdater()
    return self
end

function QuestHelper:_setupEventHandlers()
    local Fluent = shared.Fluent

    local main = shared.main
    local helperNpc = shared.helper.Npc


    Fluent.autoQuestToggle:OnChanged(function(value)
        main.autoQuest = value
        if not value then return self:clearCurrentQuest() end
        self:getAvailableTask()
    end)

    Fluent.doNpcQuestDropdown:OnChanged(function(value)
        helperNpc:updateDoQuest(value)
        if main.autoQuest then
            self:getAvailableTask()
        end
    end)
    ServerMonsterEvent.OnClientEvent:Connect(function(data)
          self:onMonsterEvent(data)
    end)
    ServerItemPackEvent.OnClientEvent:Connect(function(eventType, data)
        
        self:onServerGiveEvent(eventType ,data)
    end)

    if shared.helper.GUIHelper then
        local GUIHelper = shared.helper.GUIHelper
        GUIHelper:connectButton("Prev", function()
            if self.currentQuest and not self.isCompleted then
                self:selectPreviousTask()
            end
        end)

        GUIHelper:connectButton("Next", function()
            if self.currentQuest and not self.isCompleted then
                self:selectNextTask()
            end
        end)

    end
end


function QuestHelper:getActiveQuest()
    self.activeQuest = {}
    self.playerStats = shared.helper.Player:getPlayerStats()
    if not self.playerStats or not self.playerStats.Quests or not self.playerStats.Quests.Active then
        warn("Invalid playerStats data")
        return {}, false
    end

    local activeNPC, status  = shared.helper.Npc:getDoQuestNpcNames()
    if not status then return {} , false end
    

    for _, quest in ipairs(self.playerStats.Quests.Active) do 
        local questName = quest.Name
        local questData = self:getQuestDataByName(questName)
        if questData and questData.NPC then
 
            local progress = self:getQuestProgress(questName, questData.Tasks)
            local nextQuestData = self:getNextQuest(questName)
            if progress then 
                for index, taskData in pairs(questData.Tasks) do
                    taskData.progress = progress[index]
                end
            end

            questData.canDo = activeNPC[questData.NPC] and true or false 
            questData.isCompleted = self:isQuestCompleted(questData) 
            questData.NextQuest = nextQuestData and nextQuestData.Name or nil

            self.activeQuest[questName] = questData;
        end

        if questData and questData.isCompleted and questData.NextQuest and questData.canDo then
            self:submitQuest(questData)
        end
        
    end

    writefile("activeQeusts.json", HttpService:JSONEncode(self.activeQuest))
    return self.activeQuest, true
end

function QuestHelper:getQuestProgress(questName, questTask)
    local playerStats = self.playerStats
    local success, result = pcall(function()
        local activeQuestData = self.QuestService:GetActiveData(questName, playerStats)

        if not activeQuestData then
            error("activeQuestData is nil")
            return false
        end

        if type(questTask) ~= "table" then
            error("Tasks is not a table (or nil)")
              return false
        end

        if type(activeQuestData.StartValues) ~= "table" then
            error("StartValues is not a table (or nil)")
              return false
        end

        return self.QuestService:GetProgression(
            questTask,
            playerStats,
            activeQuestData.StartValues,
            questName
        )
    end)

    if not success then
        -- warn("Failed to get quest progress for:", questName, result)
        return nil
    end
    return result
end

function QuestHelper:getQuestDataByName(questName)
    local success, result = pcall(function()
        for _, quest in ipairs(self.allQuests) do
            if quest.Name == questName and quest.NPC then
                local nextQuestData = self:getNextQuest(questName)
                return quest, nextQuestData
            end
        end
    end)
    if not success then
        warn("Failed to get quest data by name:", questName, result)
        return nil
    end
    return result
end

function QuestHelper:isQuestCompleted(quest)
    local allTaskCompleted = true
    for i = #quest.Tasks, 1, -1 do
        local taskData = quest.Tasks[i]
        if taskData.progress and taskData.progress[1] < 1 then
            self.currentTask = taskData
            allTaskCompleted = false
            break
        end
    end
    return allTaskCompleted
end

function QuestHelper:submitQuest(quest)
    local nextQuest = quest.NextQuest
    local completeQuestEvent = game:GetService("ReplicatedStorage").Events.CompleteQuest
    completeQuestEvent:FireServer(quest.Name)

    if nextQuest then
        local giveQuestEvent = game:GetService("ReplicatedStorage").Events.GiveQuest
        giveQuestEvent:FireServer(nextQuest)
    end
    self.activeQuest[quest.Name] = nil

    if self.currentQuest and quest.Name == self.currentQuest.Name then
        self:clearCurrentQuest()
        return self:getAvailableTask()
    end
end

function QuestHelper:getNextQuest(completedQuestName)
    local success, result = pcall(function()
        for _, quest in ipairs(self.allQuests) do
            if quest.Requirements then
                for _, requirement in ipairs(quest.Requirements) do
                    if requirement.Type == "Completed Quests" then
                        for _, requiredQuestName in ipairs(requirement.Quests) do
                            if requiredQuestName == completedQuestName then
                                return quest
                            end
                        end
                    end
                end
            end
        end
        return nil
    end)
    if not success then
        warn("Failed to get next quest for:", completedQuestName, result)
        return nil
    end
    return result
end



function QuestHelper:startCollectionRateUpdater()
    task.spawn(function()
        while true do
            task.wait(1)

            local PollenStats = self.collectedStatics
            if not PollenStats or PollenStats.startTime <= 0 then continue end

            local elapsedTime = tick() - PollenStats.startTime
            if elapsedTime <= 0 then continue end

            -- Pollen PollenStats
            if PollenStats.totalCollectedPollen > 0 and shared.Fluent and shared.Fluent.PollenInfo then
                local pollenPerSec = PollenStats.totalCollectedPollen / elapsedTime
                local pollenPerHour = pollenPerSec * 3600
                local pollenPerDay = pollenPerSec * 86400

                if pollenPerSec > PollenStats.highestPollenPerSec then
                    PollenStats.highestPollenPerSec = pollenPerSec
                end

                shared.Fluent.PollenInfo:SetDesc(string.format(
                    "Rate/sec: %s\nHourly: %s\nDaily: %s\nTotal: %s\nPeak/sec: %s",
                    shared.TokenDataModule:formatNumber(pollenPerSec, 2),
                    shared.TokenDataModule:formatNumber(pollenPerHour, 2),
                    shared.TokenDataModule:formatNumber(pollenPerDay, 2),
                    shared.TokenDataModule:formatNumber(PollenStats.totalCollectedPollen, 2),
                    shared.TokenDataModule:formatNumber(PollenStats.highestPollenPerSec, 2)
                ))
            end

            -- Honey PollenStats
            if PollenStats.totalConvertHoney > 0 and shared.Fluent and shared.Fluent.HoneyInfo then
                local honeyPerSec = PollenStats.totalConvertHoney / elapsedTime
                local honeyPerHour = honeyPerSec * 3600
                local honeyPerDay = honeyPerSec * 86400

                shared.Fluent.HoneyInfo:SetDesc(string.format(
                    "Rate/sec: %s\nHourly: %s\nDaily: %s\nTotal: %s",
                    shared.TokenDataModule:formatNumber(honeyPerSec, 2),
                    shared.TokenDataModule:formatNumber(honeyPerHour, 2),
                    shared.TokenDataModule:formatNumber(honeyPerDay, 2),
                    shared.TokenDataModule:formatNumber(PollenStats.totalConvertHoney, 2)
                ))
            end
        end
    end)
end
function QuestHelper:onMonsterEvent(data)
    local Action = data.Action
    if Action == "Kill" and self.currentQuest then
        local monsterType = data.MonsterType
        for questName, questData in pairs(self.activeQuest) do
            for _, taskData in pairs(questData.Tasks) do 
                if taskData.Type == "Defeat Monsters" and taskData.MonsterType == monsterType then
                    taskData.progress[2] = math.min(taskData.progress[2] + 1, taskData.progress[3])
                    taskData.progress[1] = math.min(taskData.progress[2] / taskData.progress[3], 1.0)
                end
            end
        end
        
    end
    if Action == "Kill" then
        local killTime = data.KillTime
        local timeString = os.date("!%Y-%m-%d %H:%M:%S", killTime + (7 * 3600))
        data.thaitime = timeString
        table.insert(self.monsterEvent,data)
        writefile('monsterEvent.json',HttpService:JSONEncode(self.monsterEvent))
    end

end
function QuestHelper:onServerGiveEvent(eventType, data)
    local success, result = xpcall(function()
        -- Early exit for non-Give events
        if eventType ~= "Give" then return end
        
        local category = data.C
        local amount = data.A
        
        -- Handle Honey conversion
        if category == "Honey" then
            self.collectedStatics.totalConvertHoney += amount
            return
        end

        -- Handle Collect Pollen statistics
        if category == "Pollen" then
            local pollenRealAmount = data.R or amount
            self.collectedStatics.totalCollectedPollen += pollenRealAmount

        end

        -- Process Pollen events for current quest only
        if category ~= "Pollen" or not self.currentQuest then return end

        local pollenRealAmount = data.R or amount
        if typeof(pollenRealAmount) ~= "number" then return end
        
        local pollenZone = data.Z
        local pollenColor = data.L
        local allTasks = self.currentQuest.Tasks
        local allCompleted = true

        for _, taskData in pairs(allTasks) do
            if taskData.Type == "Collect Pollen" then
                -- Check if pollen matches task requirements
                local matchZone = taskData.Zone and pollenZone == taskData.Zone
                local matchColor = taskData.Color and pollenColor == taskData.Color
                local noSpecifics = not taskData.Zone and not taskData.Color

                if matchZone or matchColor or noSpecifics then
                    taskData.progress = self:updateProgress(taskData, pollenRealAmount)
                end
            end

            -- Check completion status
            if taskData.progress[1] < 1 then
                allCompleted = false
            end
        end

        self.isCompleted = allCompleted

        -- Handle task progression
        if self.currentTask and self.currentTask.progress[1] >= 1 and not allCompleted then
            print("current task completed, finding next quest")
            self:getAvailableTask()
        end

        self:updateDisplay()
    end, debug.traceback)

    if not success then
        warn("Error in onServerGiveEvent:\n" .. result)
    end
end
function QuestHelper:updateProgress(taskData, amount)
    if not taskData then return warn("no task found") end
    local currentProgress = taskData.progress[2]
    local maxProgress = taskData.progress[3]
    taskData.progress[2] = math.min(currentProgress + amount, maxProgress)
    taskData.progress[1] = taskData.progress[2] / maxProgress
    return taskData.progress
end
function QuestHelper:getAvailableTask()
    local allActiveQuests = self:getActiveQuest()
    if not allActiveQuests then return false end

    local fallbackTask = nil

    for _, questData in pairs(allActiveQuests) do
        if not questData.canDo then continue end

        for _, taskData in pairs(questData.Tasks or {}) do
            if taskData.progress[1] >= 1 then continue end

            if taskData.Type == "Defeat Monsters" then
                local canHunt = shared.helper.Monster:canHuntMonster(taskData.MonsterType)
                if canHunt then
                    self:setQuest(questData, taskData)
                    return questData
                elseif not fallbackTask then
                    fallbackTask = {questData = questData, taskData = taskData}
                end
            elseif taskData.Type == "Collect Pollen" or taskData.Type == "Collect Tokens" then
                self:setQuest(questData, taskData)
                return questData
            end
        end
    end

    if fallbackTask then
        self:setQuest(fallbackTask.questData, fallbackTask.taskData)
        return fallbackTask.questData
    end

    return false
end




function QuestHelper:selectPreviousTask()
    if not self.currentQuest or not self.currentQuest.Tasks or not self.currentTask then return end

    local lastTask = nil
    for _, task in ipairs(self.currentQuest.Tasks) do
        if task == self.currentTask then
            break
        end
        if task.progress and task.progress[1] < 1 then
            lastTask = task
        end
    end

    if lastTask then
        self.currentTask = lastTask
        self:updateDisplay()
    end
end
function QuestHelper:selectNextTask()
    if not self.currentQuest or not self.currentQuest.Tasks or not self.currentTask then return end
    local foundCurrent = false
    for _, task in ipairs(self.currentQuest.Tasks) do
        if task == self.currentTask then
            foundCurrent = true
        elseif foundCurrent and task.progress and task.progress[1] < 1 then
            self.currentTask = task
            self:updateDisplay()
            return
        end
    end
end

function QuestHelper:setQuest(quest ,task, isCompleted)
    self.currentQuest = quest
    self.currentTask = task
    self.isCompleted = isCompleted
    self:updateDisplay()
end

function QuestHelper:clearCurrentQuest()
    self.currentQuest = nil
    self.currentTask = nil
    self.isCompleted = false
    self:updateDisplay()
end

function QuestHelper:updateDisplay()
    local success, err = pcall(function()
        task.defer(function() -- ✨ Run GUI updates safely in UI thread
            if not self.currentQuest or not self.currentTask or not self.currentTask.progress then
                return shared.helper.GUIHelper:updateQuest({
                    title = "📜 No active quest",
                    content  = "No active quest available",
                    progress = 0
                })
            end

            local desc = self.currentTask.Description
            local descIsNULL = HttpService:JSONEncode(desc) == "null"
            local progress = self.currentTask.progress
            local current = progress[2] or 0
            local total = progress[3] or 1
            local percentage = progress[1] or 0 
            local questName = self.currentQuest.Name or "Unknown Quest"
            local npcName = self.currentQuest.NPC or "Unknown NPC"

            local taskDescription = descIsNULL and 
                (self.currentTask.Type .. " ➤ " .. (self.currentTask.Zone or self.currentTask.Color or "???")) or desc
            local currentFomat = shared.TokenDataModule:formatNumber(current, 1)
            local totalFomat = shared.TokenDataModule:formatNumber(total, 1)
            shared.helper.GUIHelper:updateQuest({
                title = "🌟 " .. questName .. "  |  👤 NPC: " .. npcName,
                content = "📌 Task: " .. taskDescription..'\n'.. currentFomat .. '/'..totalFomat,
                progress = percentage
            })
        end)
    end)

    if not success then
        warn("❌ [QuestHelper:updateDisplay] Error:", err)
    end
end





return QuestHelper

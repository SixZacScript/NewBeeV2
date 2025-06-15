local Rep = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerItemPackEvent = Rep.Events.ServerItemPackEvent

local QuestHelper = {}
QuestHelper.__index = QuestHelper

function QuestHelper.new()
    local self = setmetatable({}, QuestHelper)
    self.QuestService = require(Rep.Quests)
    self.allQuests = self.QuestService:GetAllQuests()
    self.playerStats = shared.helper.Player:getPlayerStats()
    self.activeQuest = {}
    self.PollenData = {}
    self.currentQuest = nil
    self.currentTask = nil
    self.isCompleted = false

    self.collectedStatics = {
        startTime = tick(),
        totalCollectedPollen = 0,
        totalConvertHoney = 0,
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
        self:selectCurrentQuestAndTask()
    end)

    Fluent.doNpcQuestDropdown:OnChanged(function(value)
        helperNpc:updateDoQuest(value)
        if main.autoQuest then
            self:selectCurrentQuestAndTask()
        end
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
        return self.activeQuest, false
    end

    local activeNPC, status  = shared.helper.Npc:getDoQuestNpcNames()
    if not status then return self.activeQuest , false end

    for index, quest in ipairs(self.playerStats.Quests.Active) do 
        local questName = quest.Name
        local questData = self:getQuestDataByName(questName)
        if questData then
            if activeNPC[questData.NPC] then
                local progress = self:getQuestProgress(questName, questData.Tasks)
                local nextQuestData = self:getNextQuest(questName)
                if progress then 
                    for index, taskData in pairs(questData.Tasks) do
                        taskData.progress = progress[index]
                    end
                end
                if nextQuestData then questData.NextQuest = nextQuestData.Name end

                self.activeQuest[questName] = questData;
            else
                self.activeQuest[questName] = nil
            end
        end
    end

    writefile("activeQeusts.json", HttpService:JSONEncode(self.activeQuest))
    return self.activeQuest, true
end

function QuestHelper:getQuestProgress(questName,questTask)
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

function QuestHelper:selectCurrentQuestAndTask(currentQuestName)
    local success, err = xpcall(function()
        local activeQuest, status = self:getActiveQuest()
        if not status then
            self:clearCurrentQuest()
            shared.helper.GUIHelper:updateQuest({
                title = "📜 No active quest",
                content  = "No active quest available",
                progress = 0
            })
            return nil
        end

        if self.currentTask then return end

        self.isCompleted = false

        local selectedQuestName, selectedQuest = nil, nil
        for name, quest in pairs(activeQuest) do
            if not currentQuestName then
                selectedQuestName = name
                selectedQuest = quest
                break
            elseif currentQuestName and name ~= currentQuestName then
                selectedQuestName = name
                selectedQuest = quest
                break
            end
        end

        if not selectedQuest then
            self:clearCurrentQuest()
            shared.helper.GUIHelper:updateQuest({
                title = "📜 No active quest",
                content  = "No active quest available",
                progress = 0
            })
            return
        end

        self.currentQuest = selectedQuest
        local allTaskCompleted = true

        for i = #selectedQuest.Tasks, 1, -1 do
            local task = selectedQuest.Tasks[i]
            if task.progress and task.progress[1] < 1 then
                self.currentTask = task
                allTaskCompleted = false
                break
            end
        end

        if allTaskCompleted then
            self.currentTask = selectedQuest.Tasks[1]
            self.isCompleted = true
        end
        self:updateDisplay()

        return selectedQuest
    end, debug.traceback)

    if not success then
        warn("[QuestHelper] Failed to select current quest and task:\n" .. err)
    end
end



function QuestHelper:getNextAvailableTask()
    if not self.currentQuest or not self.currentQuest.Tasks then return nil end
    for _, taskData in ipairs(self.currentQuest.Tasks) do
        if taskData ~= self.currentTask and taskData.progress and taskData.progress[1] < 1 then
            return taskData
        end
    end
    return nil
end

function QuestHelper:startCollectionRateUpdater()
    task.spawn(function()
        while true do
            task.wait(1)

            local stats = self.collectedStatics
            if not stats or stats.startTime <= 0 then continue end

            local elapsedTime = tick() - stats.startTime
            if elapsedTime <= 0 then continue end

            -- Pollen Stats
            if stats.totalCollectedPollen > 0 and shared.Fluent and shared.Fluent.PollenInfo then
                local pollenPerSec = stats.totalCollectedPollen / elapsedTime
                local pollenPerHour = pollenPerSec * 3600
                local pollenPerDay = pollenPerSec * 86400

                shared.Fluent.PollenInfo:SetDesc(string.format(
                    "Rate/sec: %s\nHourly: %s\nDaily: %s\nTotal: %s",
                    shared.TokenDataModule:formatNumber(pollenPerSec, 2),
                    shared.TokenDataModule:formatNumber(pollenPerHour),
                    shared.TokenDataModule:formatNumber(pollenPerDay),
                    shared.TokenDataModule:formatNumber(stats.totalCollectedPollen)
                ))
            end

            -- Honey Stats
            if stats.totalConvertHoney > 0 and shared.Fluent and shared.Fluent.HoneyInfo then
                local honeyPerSec = stats.totalConvertHoney / elapsedTime
                local honeyPerHour = honeyPerSec * 3600
                local honeyPerDay = honeyPerSec * 86400

                shared.Fluent.HoneyInfo:SetDesc(string.format(
                    "Rate/sec: %s\nHourly: %s\nDaily: %s\nTotal: %s",
                    shared.TokenDataModule:formatNumber(honeyPerSec, 2),
                    shared.TokenDataModule:formatNumber(honeyPerHour),
                    shared.TokenDataModule:formatNumber(honeyPerDay),
                    shared.TokenDataModule:formatNumber(stats.totalConvertHoney)
                ))
            end
        end
    end)
end




function QuestHelper:onServerGiveEvent(eventType, data)
    local success, result = xpcall(function()
        if not  self.PollenData[eventType] then
             self.PollenData[eventType] = {data}
        else
            table.insert(self.PollenData[eventType], data)
        end

        if eventType == 'Give' and data.C == "Honey" then
            self.collectedStatics.totalConvertHoney += data.A
            return
        end

        if eventType ~= "Give" or not self.currentQuest then return end
        
        local allTasks = self.currentQuest.Tasks
        local PollenRealAmount = data.R
        local PollenZone = data.Z
        local PollenColor = data.L
        
        -- Early validation
        if typeof(PollenRealAmount) ~= "number" then return end
        self.collectedStatics.totalCollectedPollen += PollenRealAmount

        -- Update matching tasks and check completion in single loop
        local allCompleted = true
        for _, taskData in pairs(allTasks) do
            -- Update progress for matching tasks
            if PollenZone == taskData.Zone or PollenColor == taskData.Color then
                taskData.progress[2] = math.min(taskData.progress[2] + PollenRealAmount, taskData.progress[3])
                taskData.progress[1] = math.min(taskData.progress[2] / taskData.progress[3], 1.0)
            end
            
            -- Check if this task is incomplete
            if taskData.progress[1] < 1 then allCompleted = false end
        end

        -- Handle completion logic
        self.isCompleted = allCompleted
        if self.currentTask and self.currentTask.progress[1] >= 1 and not self.isCompleted then
            print("current task completed find next quest")
            local newTask = self:getNextAvailableTask()
            if newTask then
                self.currentTask = newTask
            else
                self:clearCurrentQuest()
                return self:selectCurrentQuestAndTask()
            end
        end

        self:updateDisplay()
    end, debug.traceback)

    if not success then
        warn("Error in onServerGiveEvent:\n" .. result)
    end
    -- writefile("PollenData.json",HttpService:JSONEncode(self.PollenData))
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

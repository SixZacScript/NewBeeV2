-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Modules
local TaskManager = shared.ModuleLoader:load("NewBeeV2/Class/Task.lua")
local TokenHelper = shared.ModuleLoader:load("NewBeeV2/Class/Token.lua")

-- Constants
local MONSTER_RADIUS = 30

-- Bot Class
local Bot = {}
Bot.__index = Bot

Bot.States = {
    STOP = "❌ STOPPED",
    FARMING = "🌾 Farming",
    CONVERTING = "⚗️ Converting",
    COLLECTING = "📦 Collecting",
    AVOID_MONSTER = "👾 Avoiding monster",
    SUBMIT_QUEST = "📜 Submitting quest",
}

function Bot.new()
    local self = setmetatable({}, Bot)
    
    -- Cache frequently accessed objects
    self.Field = shared.helper.Field
    self.player = shared.helper.Player
    self.Hive = shared.helper.Hive
    self.questHelper = shared.helper.Quest
    
    -- State management
    self.isStart = false
    self.currentState = Bot.States.STOP
    
    -- Optimization: Pre-allocate tables
    self.realTimeConnections = {}
    
    -- Initialize managers
    self.taskManager = TaskManager.new(self)
    self.tokenHelper = TokenHelper.new(self)
    
    -- Configuration
    self.tokenCheckEnabled = true
    self.monsterInRadius = MONSTER_RADIUS
    
    -- Cached values to reduce property access
    self.bestToken = nil
    self.currentField = self.Field.fieldPart
    
    return self
end

function Bot:start()
    if self.isStart then return end
    self.isStart = true

    self.Hive:waitUntilHiveClaimed(30)
    self:setState(Bot.States.FARMING)
    self:setupRealtimeCheck()
    self:syncCurrentField()

    -- Kill old thread if exists
    if self.mainLoopThread and coroutine.status(self.mainLoopThread) ~= "dead" then
        warn("Previous main loop still running. Aborting duplicate start.")
        return
    end

    if self.mainLoopThread then return end

    self.mainLoopThread = task.spawn(function()
        self:mainLoopRunner()
        self.mainLoopThread = nil
    end)

end

function Bot:stop()
    self.isStart = false
    self:setState(Bot.States.STOP)

    for _, conn in pairs(self.realTimeConnections) do 
        if conn then conn:Disconnect() end
    end
    table.clear(self.realTimeConnections)

    if self.player then
        self.player:stopMoving()
        self.player:disableWalking(false)
        self.player:setCharacterAnchored(false)
    end

    if self.taskManager then self.taskManager:clearDebugVisual() end

    self.bestToken = nil
    self.mainLoopThread = nil
end

function Bot:setupRealtimeCheck()
    if self.realTimeConnections.mainCheck then
        self.realTimeConnections.mainCheck:Disconnect()
    end

    self.realTimeConnections.mainCheck = RunService.Heartbeat:Connect(function()
        if not self.isStart or self:isSubmittingQuest() then return end
        
        local isBusy = self:isBusy()
        local hasTask = self.questHelper.currentTask ~= nil
        
        -- Token checking optimization
        if self.tokenCheckEnabled and not isBusy then
            self:checkForNearbyTokens()
        end
        
        -- Field sync optimization
        if not isBusy and not hasTask then
            self:syncCurrentField()
        end
    end)
end

function Bot:syncCurrentField()
    local newField = self.Field.fieldPart
    if self.currentField ~= newField then
        self.currentField = newField
        self.bestToken = nil
        if self.currentState ~= Bot.States.CONVERTING then
            self:setState(Bot.States.FARMING)
        end
    end
end

function Bot:checkForNearbyTokens()
    local rootPart = self.player.rootPart
    if not rootPart then return end
    
    local token = self.tokenHelper:getBestNearbyToken(rootPart.Position)
    
    if token ~= self.bestToken then
        self.bestToken = token
        if token then
            self:setState(Bot.States.COLLECTING)
        elseif self.currentState == Bot.States.COLLECTING then
            self:setState(Bot.States.FARMING)
        end
    end
end

function Bot:mainLoopRunner()
    while self.isStart do
        -- Wait for valid player state
        while self.isStart and not self.player:isValid() do
            task.wait()
        end
        
        if self.isStart then
            self:runMainLoop()
        end
        
        task.wait()
    end
end

function Bot:runMainLoop()
    -- Early returns for blocking states
    if self:isSubmittingQuest() or self:isAvoidMonster() then 
        return 
    end
    
    -- Handle quest logic
    if self:isAutoQuest() then
        local questResult = self:handleQuestLogic()
        if questResult then return end
    end

    -- Handle conversion priority
    if self.player:isCapacityFull() and not self:isConverting() then
        self:convertAndReturn()
        return
    end
    
    if self:isConverting() then return end
    -- Handle farming and collecting
    self:handleFarmingAndCollecting()
end

function Bot:convertAndReturn()
    self:setState(Bot.States.CONVERTING)
    self.taskManager:convertPollen()
    self.taskManager:returnToField()
end

function Bot:handleQuestLogic()
    local currentTask = self.questHelper.currentTask
    if not currentTask then 
        return false
    end
    
    if self.questHelper.isCompleted then
        self:setState(Bot.States.SUBMIT_QUEST)
        self.taskManager:submitQuest(self.questHelper.currentQuest)
        return true
    end

    local targetField = self:determineQuestField(currentTask)
    if targetField then
        self.currentField = targetField
    end
    
    return false
end

function Bot:determineQuestField(task)
    if task.Zone then
        return self.Field:getField(task.Zone)
    elseif task.Color then
        return self.Field:getBestFieldByType(task.Color)
    else
        return self.Field:getField()
    end
end

function Bot:handleFarmingAndCollecting()
    if self:isCollecting() and self.bestToken then
        self.taskManager:collectToken({
            type = "collectToken",
            data = { token = self.bestToken },
            cancelled = not self.isStart
        })
        return
    end
    
    if self:isFarming() then
        if not self.player:isPlayerInField(self.currentField) then
            self.bestToken = nil
            self.taskManager:returnToField()
        else
            self.taskManager:walkTo({
                data = {
                    position = self.Field:getRandomFieldPosition(self.currentField)
                }
            })
        end
    end
end

-- Optimized state checking methods
function Bot:setState(state) 
    if self.currentState ~= state then
        self.currentState = state
        if shared.main.statusText then
            shared.main.statusText.Text = "Status: " .. state
        end 
    end
end

function Bot:getState() 
    return self.currentState 
end

-- Consolidated busy state check
function Bot:isBusy()
    return self:isConverting() or self:isAvoidMonster() or self:isSubmittingQuest()
end

-- State checking methods (optimized with direct comparisons)
function Bot:isAutoQuest() 
    return shared.main.autoQuest == true 
end

function Bot:isSubmittingQuest() 
    return self.currentState == Bot.States.SUBMIT_QUEST 
end

function Bot:isRunning() 
    return self.isStart 
end

function Bot:isFarming() 
    return self.currentState == Bot.States.FARMING 
end

function Bot:isConverting() 
    return self.currentState == Bot.States.CONVERTING 
end

function Bot:isAvoidMonster() 
    return self.currentState == Bot.States.AVOID_MONSTER 
end

function Bot:isCollecting() 
    return self.currentState == Bot.States.COLLECTING 
end


function Bot:destroy()
    self:stop()
    
    -- Clear all references
    self.taskManager = nil
    self.tokenHelper = nil
    self.player = nil
    self.Hive = nil
    self.Field = nil
    self.questHelper = nil
    self.bestToken = nil
    self.currentField = nil
    
    -- Clear the metatable
    setmetatable(self, nil)
end

return Bot
-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TaskManager = shared.ModuleLoader:load("NewBeeV2/Class/Task.lua")
local TokenHelper = shared.ModuleLoader:load("NewBeeV2/Class/Token.lua")
local taskTypeData = {}
-- Bot Class
local Bot = {}
Bot.__index = Bot

Bot.States = {
    IDLE = "IDLE",
    STOP = "STOP",
    FARMING = "FARMING",
    CONVERTING = "CONVERTING",
    COLLECTING = "COLLECTING",
    AVOID_MONSTER = "AVOID_MONSTER",
    KILL_MONSTER = "KILL_MONSTER",
    DO_QUEST = "DO_QUEST",
    SUBMITTING_QUEST = "SUBMITTING_QUEST",
}

Bot.StateDisplay = {
    IDLE = "💤 Idle",
    STOP = "❌ STOPPED",
    FARMING = "🌾 Farming",
    CONVERTING = "⚗️ Converting",
    COLLECTING = "📦 Collecting",
    AVOID_MONSTER = "👾 Avoiding monster",
    KILL_MONSTER = "👾 Killing monster",
    DO_QUEST = "📜 Doing quest",
    SUBMITTING_QUEST = "📜 Submitting quest",
}

local commonTransitions = {Bot.States.FARMING, Bot.States.STOP, Bot.States.IDLE}

Bot.StateMachine = {
    [Bot.States.IDLE] = {
        Bot.States.CONVERTING,
        Bot.States.COLLECTING,
        Bot.States.AVOID_MONSTER,
        Bot.States.KILL_MONSTER,
        Bot.States.DO_QUEST,
        Bot.States.SUBMITTING_QUEST,
        unpack(commonTransitions)
    },
    [Bot.States.FARMING] = {
        Bot.States.CONVERTING,
        Bot.States.COLLECTING,
        Bot.States.AVOID_MONSTER,
        Bot.States.KILL_MONSTER,
        Bot.States.DO_QUEST,
        Bot.States.SUBMITTING_QUEST,
        unpack(commonTransitions)
    },

    [Bot.States.CONVERTING] = {
        unpack(commonTransitions)
    },

    [Bot.States.COLLECTING] = {
        Bot.States.CONVERTING,
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.AVOID_MONSTER,
        Bot.States.SUBMITTING_QUEST,
        Bot.States.STOP,
        Bot.States.IDLE
    },

    [Bot.States.AVOID_MONSTER] = {
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.COLLECTING,
        Bot.States.IDLE,
        Bot.States.STOP
    },

    [Bot.States.KILL_MONSTER] = {
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.STOP
    },

    [Bot.States.DO_QUEST] = {
        Bot.States.CONVERTING,
        Bot.States.COLLECTING,
        Bot.States.FARMING,
        Bot.States.AVOID_MONSTER,
        Bot.States.SUBMITTING_QUEST,
        Bot.States.IDLE,
        Bot.States.STOP
    },

    [Bot.States.SUBMITTING_QUEST] = {
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.IDLE,
        Bot.States.STOP
    },

      [Bot.States.STOP] = {
        Bot.States.IDLE
    }
}
function Bot.new()
    local self = setmetatable({}, Bot)
    self.isStart = false
    self.currentState = Bot.States.STOP
    self.currentField = shared.helper.Field:getField()
    self.lastState = nil
    self.mainLoopThread = nil
    self.taskQueue = {}
    self.connections = {
        died = nil,
        interval = nil
    }
    self.monsterCount = 0
    self.canUseClock = false

    -- Helpers 
    self.plr = shared.helper.Player
    self.Hive = shared.helper.Hive
    self.questHelper = shared.helper.Quest
    self.taskManager = TaskManager.new(self)
    self.tokenHelper = TokenHelper.new(self)

    self:setupRealtime()
    self:startIntervalTask()
    return self
end
function Bot:startIntervalTask()
    if self.connections.interval then self.connections.interval:Disconnect() end
    self._lastTick = tick()
    self._lastHourTick = tick()

    self.connections.interval = RunService.Heartbeat:Connect(function()
        -- Trigger every 1 second
        if tick() - self._lastTick >= 1 then
            self._lastTick = tick()
        end

        -- Trigger every 1 hour
        if tick() - self._lastHourTick >= 3600 then
            self._lastHourTick = tick()
            self.canUseClock = true
            print("⏰ 1 hour passed: canUseClock set to true")
        end
    end)
end


function Bot:start()
    if self.isStart then return end
    self.isStart = true
    self.currentState = Bot.States.IDLE

    -- Start main loop
    self.mainLoopThread = task.spawn(function() self:mainLoopRunner() end)

    if self.connections.died then self.connections.died:Disconnect() end
    local humanoid = self.plr:getHumanoid()
    if humanoid then
        self.connections.died = humanoid.Died:Connect(function()
            warn("⚰️ Player died. Resetting bot.")
            self:onPlayerDied()
        end)
    end
end

function Bot:stop()
    self.isStart = false
    self.token = nil
    self.currentState = self:setState(Bot.States.STOP)

    if self.mainLoopThread then
        task.cancel(self.mainLoopThread)
        self.mainLoopThread = nil
    end
    self.plr:stopMoving()
    
end
function Bot:setupRealtime()
    if self.connections.realtime then self.connections.realtime:Disconnect() end

    self.connections.realtime = RunService.Heartbeat:Connect(function()
        self.monsterCount = shared.helper.Monster:getCloseMonsterCount(40)
    
        if self.currentField ~= shared.helper.Field:getField() and not self:isBusy() then
            self.currentField = shared.helper.Field:getField()
        end
        if self.plr and self.plr.rootPart then
            self.token = self.tokenHelper:getBestNearbyToken(self.plr.rootPart.Position)
        end

    end)
end
function Bot:mainLoopRunner()
    while self.isStart do
        self:runMainLoop()
        task.wait()
    end
end

function Bot:runMainLoop()
    -- Check if bot should stop
    if not self.isStart then return end

    -- Process task queue
    if #self.taskQueue > 0 then
        local currentTask = self.taskQueue[1]
        local taskCompleted = self:processTask(currentTask)

        if taskCompleted then table.remove(self.taskQueue, 1) end
        return
    end

    -- Check for new tasks based on current state and conditions
    self:checkForNewTasks()
end

function Bot:processTask(taskData)
    if not taskData or not taskData.type then return true end
    local taskType = taskData.type


    if taskType == "farming" then
        return self:handleFarmingTask(taskData)
    elseif taskType == "collecting" then
        return self:handleCollectingTask(taskData)
    elseif taskType == "converting" then
        return self:handleConvertingTask(taskData)
    elseif taskType == "avoiding_monster" then
        return self:handleAvoidMonsterTask(taskData)
    elseif taskType == "killing_monster" then
        return self:handleKillMonsterTask(taskData)
    elseif taskType == "shouldDoQuest" then
        return self:handleDoingQuest(taskData)
    elseif taskType == "shouldSubmitQuest" then
        return self:handleSubmitQuest(taskData)
    end

    return true -- Unknown task type, mark as completed
end

function Bot:checkForNewTasks()
    -- Priority order: urgent tasks first

    -- Check for monster threats
    if self:shouldAvoidMonster() then
        self:addTask({type = "avoiding_monster", priority = 1})
        return
    end

    -- Check for conversion needs
    if self:shouldConvert() then
        self:addTask({type = "converting", priority = 2})
        return
    end

    -- Check for quest completion
    if self:shouldDoQuest() then
        self:addTask({type = "shouldDoQuest", priority = 3})
        return
    end
    -- Check for token collection
    if self:shouldCollectTokens() then
        self:addTask({type = "collecting", priority = 4})
        return
    end

    if self:shouldSubmitQuest() then
        self:addTask({type = "shouldSubmitQuest", priority = 5})
        return
    end

    -- Check for monster killing (quest requirement)
    if self:shouldKillMonster() then
        self:addTask({type = "killing_monster", priority = 6})
        return
    end

 

    -- Default to farming
    if self:shouldFarm() then
        self:addTask({type = "farming", priority = 7})
        return
    end
end

function Bot:addTask(task)
    -- Insert task based on priority (lower number = higher priority)
    local inserted = false
    for i, existingTask in ipairs(self.taskQueue) do
        if task.priority < existingTask.priority then
            table.insert(self.taskQueue, i, task)
            inserted = true
            break
        end
    end

    if not inserted then table.insert(self.taskQueue, task) end
end

function Bot:handleFarmingTask(taskData)
    if not self.plr or not self.plr:isValid() then return true end
    self:setState(Bot.States.FARMING)
    self.currentField = shared.helper.Field:getField()
    return self.taskManager:doFarming()
end

function Bot:handleCollectingTask(...)
    if not self.token or not self.token.instance then return true end

    self:setState(Bot.States.COLLECTING)
    local targetToken = self.token

    self:moveTo(targetToken.position, {
        timeout = 3,
        speed = shared.main.WalkSpeed,
        onBreak = function(breakFunc)
            local conn
            conn = RunService.Heartbeat:Connect(function()
                local currentToken = self.tokenHelper:getBestNearbyToken(self.plr.rootPart.Position)
                if currentToken and currentToken.instance and currentToken ~= targetToken then
                    conn:Disconnect()
                    breakFunc()
                    task.spawn(function()
                        self:addTask({type = "collecting", priority = 4})
                    end)
                end
            end)
            return conn
        end
    })

    self:returnToLastState()
    return true
end


function Bot:handleConvertingTask(task)
    self:setState(Bot.States.CONVERTING)
    self.taskManager:convertPollen()
    self:setState(Bot.States.IDLE)
    return true
end

function Bot:handleAvoidMonsterTask()
    self:setState(Bot.States.AVOID_MONSTER)

    local humanoid = self.plr:getHumanoid()
    if not humanoid then return false end

    humanoid:MoveTo(self.plr.rootPart.Position)

    local lastJumpTime = tick()

    while self.monsterCount > 0 do
        if tick() - lastJumpTime >= 1.25 then
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            lastJumpTime = tick()
        end
        task.wait(0.1)
    end

    self:setState(Bot.States.IDLE)
    return true
end



function Bot:handleKillMonsterTask(task)
    self:setState(Bot.States.KILL_MONSTER)
    -- TODO: Implement monster killing logic
    return false
end

function Bot:determineQuestField(task)
    if task.Zone then
        return shared.helper.Field:getField(task.Zone)
    elseif task.Color then
        return shared.helper.Field:getBestFieldByType(task.Color)
    else
        return shared.helper.Field:getField()
    end
end

function Bot:handleDoingQuest()
    local currentQuest = self.questHelper.currentQuest
    local currentTask = self.questHelper.currentTask

    if not shared.main.autoQuest then
        warn("Auto quest is disabled")
        return true
    end
    if not currentQuest or not currentTask then
        warn("No current quest assigned (early exit)")
        return true
    end

    if self.questHelper.isCompleted then
        warn("Quest is completed, skipping")
        return true
    end

    self:setState(Bot.States.DO_QUEST)
    self.currentField = self:determineQuestField(currentTask)

    -- Collect Pollen = active farming behavior
    if currentTask.Type == "Collect Pollen" then
        return self.taskManager:doFarming()
    end

    -- Log task to file
    taskTypeData[currentTask.Type] = currentTask
    writefile('taskType.json', HttpService:JSONEncode(taskTypeData))

    -- Try next task if nothing else to do
    local nextTask = self.questHelper:getNextAvailableTask()
    if nextTask then
        self.questHelper.currentTask = nextTask
        self.questHelper:updateDisplay()
        return false
    end

    -- Try new quest
    if currentQuest then
        local questName = currentQuest.Name
        self.questHelper:clearCurrentQuest()
        self.questHelper:selectCurrentQuestAndTask(questName)
        warn("No task available, trying new quest")
    end

    self:setState(Bot.States.IDLE)
    return true
end



function Bot:handleSubmitQuest(task)
    self:setState(Bot.States.SUBMITTING_QUEST)
    return self.taskManager:submitQuest(self.questHelper.currentQuest)
end

-- Condition checking methods (to be implemented)
function Bot:shouldAvoidMonster()
    return self.monsterCount > 0
end

function Bot:shouldSubmitQuest()
    local questService = self.questHelper
    local isCompleted = questService.currentQuest and questService.currentTask and questService.isCompleted
    return isCompleted
end

function Bot:shouldDoQuest()
    if self.plr:isCapacityFull() then return false end

    local q = self.questHelper
    if not q.currentQuest or not q.currentTask or q.isCompleted then
        return false
    end

    if self:shouldAvoidMonster() then
        return false
    end
    if self:shouldCollectTokens() then
        return false
    end
    if not shared.main.autoQuest then
        return false
    end
    return true
end



function Bot:shouldKillMonster()
    -- TODO: Check if monster killing is required for quest
    return false
end

function Bot:shouldConvert() return self.plr:isCapacityFull() and self.isStart end

function Bot:shouldCollectTokens()
    local hasToken = self.token and self.token.instance and not self.token.touched
    local inField = self.plr:isPlayerInField(self.currentField)
    return hasToken and inField
end

function Bot:shouldFarm()
    -- Don't farm if bot is stopped
    if not self.isStart then return false end

    -- Don't farm if currently busy with higher priority tasks
    if self.currentState == Bot.States.CONVERTING or self.currentState ==
        Bot.States.AVOID_MONSTER or self.currentState == Bot.States.KILL_MONSTER or
        self.currentState == Bot.States.DO_QUEST then return false end

    -- Don't farm if inventory is full (should convert first)
    if self:shouldConvert() then return false end

    -- Don't farm if there are tokens to collect
    if self:shouldCollectTokens() then return false end

    -- Farm if idle or already farming
    if self.currentState == Bot.States.IDLE or self.currentState == Bot.States.FARMING then return true end

    return false
end

function Bot:moveTo(targetPosition, options)
    options = options or {}
    local timeout = options.timeout or 5
    local onBreak = options.onBreak

    -- Early validation
    if not (self.plr and self.plr.rootPart and self.plr:isValid()) then
        warn("Player validation failed")
        return false
    end

    local humanoid = self.plr.humanoid
    if not humanoid then
        warn("Humanoid not found")
        return false
    end

    humanoid:MoveTo(targetPosition)

    local startTime = tick()
    local finished = false
    local broken = false
    local connections = {}

    -- Movement completion handler
    connections.move = humanoid.MoveToFinished:Connect(function(reached)
        finished = reached
    end)

    -- Break handler setup
    if onBreak and type(onBreak) == "function" then
        connections.breakConn = onBreak(function()
            broken = true
        end)
    end

    -- Main wait loop
    while not finished and not broken do
        if tick() - startTime > timeout then
            -- Cleanup connections
            for _, conn in pairs(connections) do
                if conn then conn:Disconnect() end
            end
            warn("⏱️ MoveTo timeout")
            return false
        end
        
        -- Check if player is still valid during movement
        if not self.plr:isValid() then
            -- Cleanup connections
            for _, conn in pairs(connections) do
                if conn then conn:Disconnect() end
            end
            warn("Player became invalid during movement")
            return false
        end
        
        task.wait()
    end

    -- Cleanup connections
    for _, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end

    return finished and not broken
end

function Bot:returnToLastState()
    if self.lastState and self.lastState ~= self.currentState then
        self:setState(self.lastState)
    end
end

function Bot:setState(newState)
    if self.currentState == newState then return end

    local allowed = Bot.StateMachine[self.currentState]
    if allowed and not table.find(allowed, newState) then
        warn("Invalid state transition: " .. self.currentState .. " → " ..newState)
        return
    end

    self.lastState = self.currentState
    self.currentState = newState
    shared.main.statusText.Text = "Status: " .. self.StateDisplay[newState] or
                                      "Unknown State"
end

function Bot:getState() return self.currentState end

function Bot:isRunning() return self.isStart == true end
function Bot:isConverting() return self.currentState == self.States.CONVERTING end
function Bot:isDoingQuest() return self.currentState == self.States.DO_QUEST end
function Bot:isCollecting() return self.currentState == self.States.COLLECTING end
function Bot:isSubmittingQuest() return self.currentState == self.States.SUBMITTING_QUEST end
function Bot:isBusy()
    return self:isConverting() or self:isDoingQuest() or self:isCollecting() or self:isSubmittingQuest()
end

function Bot:onPlayerDied()
    self:stop()

    -- Wait until the player respawns (basic check)
    task.spawn(function()
        while not self.plr:isValid() or not self.plr:getHumanoid() do
            task.wait(1)
        end

        -- Delay to allow full load
        task.wait(1.5)

        -- Auto-restart bot after respawn
        self:start()
    end)
end

function Bot:destroy()
    self:stop()
    self.taskQueue = nil
end

return Bot

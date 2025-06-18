-- Services
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TaskManager = shared.ModuleLoader:load(_G.URL.."/Class/Task.lua")
local TokenHelper = shared.ModuleLoader:load(_G.URL.."/Class/Token.lua")

-- Bot Class
local Bot = {}
Bot.__index = Bot

-- Configuration
Bot.Config = {
    UPDATE_INTERVAL = 0.05,
    MOVEMENT_THRESHOLD = 4,
    MOVEMENT_TIMEOUT = 5,
    TOKEN_UPDATE_DISTANCE = 5,
    MONSTER_CHECK_RADIUS = 40,
    CLOCK_COOLDOWN = 3600, -- 1 hour
    SESSION_UPDATE_INTERVAL = 1,
    JUMP_COOLDOWN = 1.25,
}

-- States
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
    USE_WEALTH_CLOCK = "USE_WEALTH_CLOCK",
    AUTO_PLANTER = "AUTO_PLANTER",

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
    USE_WEALTH_CLOCK = "⏱️ Using wealth clock",
    AUTO_PLANTER = "🪴 Auto Planter",

}

-- State Machine
local commonTransitions = {Bot.States.FARMING, Bot.States.USE_WEALTH_CLOCK, Bot.States.AUTO_PLANTER, Bot.States.STOP, Bot.States.IDLE}

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
        Bot.States.USE_WEALTH_CLOCK,
        Bot.States.AUTO_PLANTER,
        Bot.States.IDLE,
        Bot.States.STOP,
    },
    [Bot.States.AVOID_MONSTER] = {
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.COLLECTING,
        Bot.States.USE_WEALTH_CLOCK,
        Bot.States.AUTO_PLANTER,
        Bot.States.IDLE,
        Bot.States.STOP
    },
    [Bot.States.KILL_MONSTER] = {
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.USE_WEALTH_CLOCK,
        Bot.States.AUTO_PLANTER,
        Bot.States.STOP
    },
    [Bot.States.DO_QUEST] = {
        Bot.States.CONVERTING,
        Bot.States.COLLECTING,
        Bot.States.FARMING,
        Bot.States.AVOID_MONSTER,
        Bot.States.SUBMITTING_QUEST,
        Bot.States.USE_WEALTH_CLOCK,
        Bot.States.AUTO_PLANTER,
        Bot.States.IDLE,
        Bot.States.STOP
    },
    [Bot.States.SUBMITTING_QUEST] = {
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.USE_WEALTH_CLOCK,
        Bot.States.AUTO_PLANTER,
        Bot.States.IDLE,
        Bot.States.STOP
    },
    [Bot.States.USE_WEALTH_CLOCK] = {
        Bot.States.CONVERTING,
        Bot.States.FARMING,
        Bot.States.DO_QUEST,
        Bot.States.AVOID_MONSTER,
        Bot.States.SUBMITTING_QUEST,
        Bot.States.AUTO_PLANTER,
        Bot.States.IDLE,
        Bot.States.STOP,
    },
    [Bot.States.AUTO_PLANTER] = {
        Bot.States.FARMING,
        Bot.States.CONVERTING,
        Bot.States.DO_QUEST,
        Bot.States.AVOID_MONSTER,
        Bot.States.SUBMITTING_QUEST,
        Bot.States.IDLE,
        Bot.States.STOP
    },

    [Bot.States.STOP] = {
        Bot.States.IDLE
    }
}

-- Constructor
function Bot.new()
    local self = setmetatable({}, Bot)
    
    -- Core state
    self.isStart = false
    self.currentState = Bot.States.STOP
    self.lastState = nil
    self.mainLoopThread = nil
    
    -- Task management
    self.taskQueue = {}
    self.taskHandlers = self:initializeTaskHandlers()
    
    -- Connections
    self.connections = {}
    
    -- Cache variables
    self.currentField = shared.helper.Field:getField()
    self.monsterCount = 0
    self.canUseClock = false
    self.lastTokenUpdatePos = nil
    self.token = nil
    
    -- Timing
    self.sessionStartTime = tick()
    self.lastTick = tick()
    self.lastHourTick = tick()
    self.lastJumpTime = 0
    
    -- Helpers
    self.plr = shared.helper.Player
    self.Hive = shared.helper.Hive
    self.questHelper = shared.helper.Quest
    self.taskManager = TaskManager.new(self)
    self.tokenHelper = TokenHelper.new(self)
    
    -- Initialize
    self.plr:equipMask()
    self:setupRealtime()
    self:startIntervalTask()
    
    return self
end

-- Task Handler Initialization
function Bot:initializeTaskHandlers()
    return {
        farming = self.handleFarmingTask,
        collecting = self.handleCollectingTask,
        converting = self.handleConvertingTask,
        planter =  self.handlePlanter,
        avoiding_monster = self.handleAvoidMonsterTask,
        killing_monster = self.handleKillMonsterTask,
        shouldDoQuest = self.handleDoingQuest,
        shouldSubmitQuest = self.handleSubmitQuest,
        shouldUseWealthClock = self.handleWealthClock,
    }
end

-- Interval Task Management
function Bot:startIntervalTask()
    if self.connections.interval then 
        self.connections.interval:Disconnect() 
    end
    
    self.connections.interval = RunService.Heartbeat:Connect(function()
        local now = tick()
        
        -- Update session time every second
        if now - self.lastTick >= Bot.Config.SESSION_UPDATE_INTERVAL then
            self.lastTick = now
            self:updateSessionTime()
        end
        
        -- Enable clock usage every hour
        if now - self.lastHourTick >= Bot.Config.CLOCK_COOLDOWN + 15 then
            self.lastHourTick = now
            self.canUseClock = true
        end
    end)
end

function Bot:updateSessionTime()
    local elapsed = tick() - self.sessionStartTime
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = math.floor(elapsed % 60)
    local formattedTime = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    
    if shared.Fluent and shared.Fluent.sessionTimeInfo then
        shared.Fluent.sessionTimeInfo:SetDesc(formattedTime)
    end
end

-- Optimized Real-time Updates
function Bot:setupRealtime()
    if self.connections.realtime then 
        self.connections.realtime:Disconnect() 
    end
    
    local lastUpdate = 0
    
    self.connections.realtime = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - lastUpdate < Bot.Config.UPDATE_INTERVAL then 
            return 
        end
        lastUpdate = now
        
        -- Update monster count
        self.monsterCount = shared.helper.Monster:getCloseMonsterCount(Bot.Config.MONSTER_CHECK_RADIUS)
        
        -- Update field if changed and not busy
        local currentField = shared.helper.Field:getField()
        if self.currentField ~= currentField and not self:isBusy() then
            self.currentField = currentField
        end

        if not shared.main.autoQuest and self.currentState == self.States.DO_QUEST then
            self:setState(self.States.IDLE)
        end

        -- Update token position only if player moved significantly
        if self.plr and self.plr.rootPart then
            local pos = self.plr.rootPart.Position
            
            -- ใช้ distance check ที่เรียบง่าย
            local shouldUpdateToken = not self.lastTokenUpdatePos or 
                                    math.abs(pos.X - self.lastTokenUpdatePos.X) > Bot.Config.TOKEN_UPDATE_DISTANCE or
                                    math.abs(pos.Z - self.lastTokenUpdatePos.Z) > Bot.Config.TOKEN_UPDATE_DISTANCE
            
            if shouldUpdateToken then
                self.token = self.tokenHelper:getBestNearbyToken(pos)
                self.lastTokenUpdatePos = pos
            end
        end
    end)
end

-- Bot Control
function Bot:start()
    if self.isStart then return end
    self.isStart = true
    self.currentState = Bot.States.IDLE
    
    -- Start main loop
    self.mainLoopThread = task.spawn(function() 
        self:safeExecute(self.mainLoopRunner, "mainLoopRunner", self) 
    end)
    
    -- Setup death handler
    self:setupDeathHandler()
end



-- Main Loop
function Bot:mainLoopRunner()
    while self.isStart do
        self:runMainLoop()
        task.wait()
    end
end

function Bot:runMainLoop()
    if not self.isStart then return end
    
    -- Process task queue
    if #self.taskQueue > 0 then
        local currentTask = self.taskQueue[1]
        local taskCompleted = self:processTask(currentTask)
        
        if taskCompleted then 
            table.remove(self.taskQueue, 1) 
        end
        return
    end
    
    -- Check for new tasks
    self:checkForNewTasks()
end

function Bot:stop()
    self.isStart = false
    self.token = nil
    self.taskQueue = {} -- ✅ Clear all pending tasks immediately
    self:setState(Bot.States.STOP, true)

    if self.mainLoopThread then
        task.cancel(self.mainLoopThread)
        self.mainLoopThread = nil
    end

    if self.plr then
        self.plr:stopMoving()
        self.plr:equipMask()
    end
end


function Bot:setupDeathHandler()
    if self.connections.died then 
        self.connections.died:Disconnect() 
    end
    
    local humanoid = self.plr:getHumanoid()
    if humanoid then
        self.connections.died = humanoid.Died:Connect(function()
            warn("⚰️ Player died. Resetting bot.")
            self:onPlayerDied()
        end)
    end
end
-- Task Processing
function Bot:processTask(taskData)
    if not taskData or not taskData.type then return true end
    
    local handler = self.taskHandlers[taskData.type]
    if handler then
        return self:safeExecute(handler, `processTask({taskData.type})`, self, taskData)
    end
    
    warn(`Unknown task type: {taskData.type}`)
    return true
end

function Bot:evaluateConditions()
    local hasToken = self.token and self.token.instance and not self.token.touched
    local inField = self.plr:isPlayerInField(self.currentField)
    
    return {
        hasMonster = self.monsterCount > 0,
        canUseClock = self.canUseClock and self.currentState ~= Bot.States.USE_WEALTH_CLOCK,
        shouldConvert = self.plr:isCapacityFull() and self.isStart,
        hasTokens = hasToken and inField and self.token.tokenField == self.currentField,
        canHarvestPlanter = self.shouldDoPlanter(),
        questAvailable = self:shouldDoQuest(),
        questCompleted = self:shouldSubmitQuest(),
        shouldKillMonster = self:shouldKillMonster(),
        shouldFarm = self:shouldFarm()
    }
end

-- Optimized Task Prioritization
function Bot:checkForNewTasks()
    local conditions = self:evaluateConditions()

    if conditions.hasMonster then
        self:addTask({type = "avoiding_monster", priority = 1})
    elseif conditions.canUseClock then
        self:addTask({type = "shouldUseWealthClock", priority = 2})
    elseif conditions.shouldConvert then
        self:addTask({type = "converting", priority = 3})
    elseif conditions.canHarvestPlanter then
        self:addTask({type = "planter", priority = 4})
    elseif conditions.questAvailable then
        self:addTask({type = "shouldDoQuest", priority = 5})
    elseif conditions.hasTokens then
        self:addTask({type = "collecting", priority = 6})
    elseif conditions.questCompleted then
        self:addTask({type = "shouldSubmitQuest", priority = 7})
    elseif conditions.shouldKillMonster then
        self:addTask({type = "killing_monster", priority = 8})
    elseif conditions.shouldFarm then
        self:addTask({type = "farming", priority = 9})
    else
        print("⚠️ No conditions met, forcing farming task")
        self:addTask({type = "farming", priority = 9})
    end
end


function Bot:addTask(task)
    -- ใช้ simple priority check แทน binary search
    if #self.taskQueue == 0 then
        table.insert(self.taskQueue, task)
        return
    end
    
    -- หา priority สูงสุดที่มีอยู่
    local highestPriority = self.taskQueue[1].priority or 999
    
    if (task.priority or 999) < highestPriority then
        -- priority สูงกว่า ใส่หน้าสุด
        table.insert(self.taskQueue, 1, task)
    else
        -- priority ต่ำกว่า ใส่ท้ายสุด
        table.insert(self.taskQueue, task)
    end
end

-- Task Handlers
function Bot:handleFarmingTask(taskData)
    if not self:validatePlayer() then return true end
    
    self:setState(Bot.States.FARMING)
    self.currentField = shared.helper.Field:getField()
    return self.taskManager:doFarming()
end

function Bot:handleCollectingTask(taskData)
    if not self.token or not self.token.instance then return true end

    self:setState(Bot.States.COLLECTING)
    local targetToken = self.token

    local reached = self:moveTo(targetToken.position, {
        timeout = 3,
        speed = shared.main.WalkSpeed,
    })

    while self.isStart do
        local currentToken = self.tokenHelper:getBestNearbyToken(self.plr.rootPart.Position)

        -- ถ้า token เปลี่ยน
        if currentToken and currentToken.instance and currentToken ~= targetToken then
            self.token = currentToken -- ตั้งใหม่ แล้วให้ bot ไปจัดการเอง
            break
        end

        -- ถ้าเดินถึงเป้าหมายหรือหมดเวลา
        if reached then break end

        task.wait()
    end

    self:returnToLastState()
    return true
end




function Bot:handleConvertingTask(taskData)
    self:setState(Bot.States.CONVERTING)
    self.taskManager:convertPollen()
    self:setState(Bot.States.IDLE)
    return true
end
function Bot:handlePlanter()
    self:setState(Bot.States.AUTO_PLANTER)
    
    if not shared.main.Planter.autoPlanterEnabled then 
        self:setState(Bot.States.IDLE)
        return true 
    end

    local playerHelper = self.plr
    local planterToPlace = playerHelper:getPlanterToPlace()
    local planterToHarvest = playerHelper:getCanHarvestPlanter()

    if planterToPlace then
        return self.taskManager:placePlanter()
    elseif planterToHarvest then
        return self.taskManager:harvestPlanter()
    end 

    self:setState(Bot.States.IDLE)
    return true
end

function Bot:handleAvoidMonsterTask(taskData)
    self:setState(Bot.States.AVOID_MONSTER)
    
    local humanoid = self.plr:getHumanoid()
    if not humanoid then return false end
    
    humanoid:MoveTo(self.plr.rootPart.Position)
    
    while self.monsterCount > 0 do
        local now = tick()
        if now - self.lastJumpTime >= Bot.Config.JUMP_COOLDOWN then
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            self.lastJumpTime = now
        end
        task.wait(0.1)
    end
    
    self:setState(Bot.States.IDLE)
    return true
end

function Bot:handleKillMonsterTask(taskData)
    self:setState(Bot.States.KILL_MONSTER)
    -- TODO: Implement monster killing logic
    return false
end

function Bot:handleDoingQuest(taskData)
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
    
    if self:shouldSubmitQuest() then
        warn("Quest is completed, skipping")
        return true
    end
    self:setState(Bot.States.DO_QUEST)
    
    self.currentField = self:determineQuestField(currentTask)
    if currentTask.Type == "Collect Pollen" or currentTask.Type == "Collect Tokens" then
        return self.taskManager:doFarming()
    end


    if currentTask.Type == "Defeat Monsters" then
        return self.taskManager:doHunting()
    end


    -- local nextQuest = self.questHelper:getAvailableTask()
    -- if nextQuest then
    --     return false
    -- end
    
    self:setState(Bot.States.IDLE)
    return true
end

function Bot:handleSubmitQuest(taskData)
    self:setState(Bot.States.SUBMITTING_QUEST)
    return self.taskManager:submitQuest(self.questHelper.currentQuest)
end

function Bot:handleWealthClock(taskData)
    if self.currentState == Bot.States.USE_WEALTH_CLOCK then return false end
    
    self:setState(Bot.States.USE_WEALTH_CLOCK)
    
    local clockPos = Vector3.new(330.5519104003906, 48.43824005126953, 191.44041442871094)
    
    self.plr:tweenTo(clockPos, 1, function()
        task.wait(1)
        
        -- Simulate E key press
        for _, state in ipairs({true, false}) do
            VirtualInputManager:SendKeyEvent(state, Enum.KeyCode.E, false, game)
        end
        
        task.wait(1)
        self.canUseClock = false
        self:setState(Bot.States.IDLE)
    end)
    
    return not self.canUseClock
end

-- Helper Methods
function Bot:determineQuestField(task)
    if task.Zone then
        return shared.helper.Field:getField(task.Zone)
    elseif task.Color then
        return shared.helper.Field:getBestFieldByType(task.Color)
    else
        return shared.helper.Field:getField()
    end
end

function Bot:validatePlayer()
    return self.plr and self.plr.rootPart and self.plr:isValid()
end

function Bot:validateMovement()
    return self:validatePlayer() and self.plr.humanoid
end

-- Optimized Movement
function Bot:moveTo(targetPosition, options)
    options = options or {}
    
    if not self:validateMovement() then 
        warn("Movement validation failed")
        return false 
    end
    
    -- Check if already close to target
    local currentPos = self.plr.rootPart.Position
    local threshold = options.threshold or Bot.Config.MOVEMENT_THRESHOLD
    if (currentPos - targetPosition).Magnitude < threshold then
        return true
    end
    
    local humanoid = self.plr.humanoid
    local timeout = options.timeout or Bot.Config.MOVEMENT_TIMEOUT
    
    humanoid:MoveTo(targetPosition)
    
    return self:waitForMovement(timeout, options.onBreak)
end

function Bot:waitForMovement(timeout, onBreak)
    local startTime = tick()
    local finished = false
    local broken = false
    local connections = {}
    
    -- Movement completion handler
    local humanoid = self.plr.humanoid
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
            self:cleanupConnections(connections)
            warn("⏱️ MoveTo timeout")
            return true
        end
        
        if not self:validatePlayer() then
            self:cleanupConnections(connections)
            warn("Player became invalid during movement")
            return true
        end
        
        task.wait()
    end
    
    self:cleanupConnections(connections)
    return true
end

function Bot:cleanupConnections(connections)
    for _, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
end

-- Condition Checking (Optimized)
function Bot:shouldAvoidMonster()
    return self.monsterCount > 0
end

function Bot:shouldUseWealthClock()
    return self.canUseClock and self.currentState ~= Bot.States.USE_WEALTH_CLOCK
end
function Bot:shouldDoPlanter()
    if not shared.main.Planter.autoPlanterEnabled then return false end

    local playerHelper = shared.helper.Player
    local canHarvestPlanter = playerHelper:getCanHarvestPlanter()
    local planterToPlace = playerHelper:getPlanterToPlace()

    return canHarvestPlanter or planterToPlace
end


function Bot:shouldSubmitQuest()
    local canSumit =  self.questHelper.currentQuest and self.questHelper.currentTask and self.questHelper.isCompleted
    return canSumit
end

function Bot:shouldDoQuest()
    if self.plr:isCapacityFull() or not shared.main.autoQuest or self:shouldAvoidMonster() or self:shouldCollectTokens() then
        return false
    end

    local q = self.questHelper

    -- if q.currentTask and q.currentTask.Type == "Defeat Monsters" then
    --     local canHunt, fieldName = shared.helper.Monster:canHuntMonster(q.currentTask.MonsterType)
    --     if not canHunt or not fieldName then 
    --         if self.currentState == self.States.DO_QUEST then
    --             self:setState(self.States.FARMING)
    --         end
    --         print("false here 2")
    --         return false
    --     end
    -- end
    -- print( q.currentQuest , q.currentTask , not q.isCompleted)
    return q.currentQuest and q.currentTask and not q.isCompleted
end

function Bot:shouldKillMonster()
    -- TODO: Implement monster killing logic
    return false
end

function Bot:shouldConvert()
    return self.plr:isCapacityFull() and self.isStart
end

function Bot:shouldCollectTokens()
    if not self.token or not self.token.instance or self.token.touched then
        return false
    end
    
    local inField = self.plr:isPlayerInField(self.currentField)
    return inField and self.token.tokenField == self.currentField
end

function Bot:shouldFarm()
    if not self.isStart or 
       self:shouldConvert() or 
       self:shouldCollectTokens() then
        return false
    end
    
    local busyStates = {
        [Bot.States.CONVERTING] = true,
        [Bot.States.AVOID_MONSTER] = true,
        [Bot.States.KILL_MONSTER] = true,
        [Bot.States.DO_QUEST] = true
    }
    
    if busyStates[self.currentState] then
        return false
    end
    
    return self.currentState == Bot.States.IDLE or 
           self.currentState == Bot.States.FARMING
end

-- State Management
function Bot:setState(newState, force)
    if self.currentState == newState and not force then 
        return true 
    end
    
    -- Validate transition
    if not force then
        local allowed = Bot.StateMachine[self.currentState]
        if not (allowed and table.find(allowed, newState)) then
            warn(`Invalid transition: {self.currentState} → {newState}`)
            return false
        end
    end
    
    self.lastState = self.currentState
    self.currentState = newState
    self:updateStatusDisplay()
    
    return true
end

function Bot:updateStatusDisplay()
    if shared.main and shared.main.statusText then
        shared.main.statusText.Text = "Status: " .. (self.StateDisplay[self.currentState] or "Unknown State")
    end
end

function Bot:returnToLastState()
    if self.lastState and self.lastState ~= self.currentState then
        self:setState(self.lastState)
    end
end

-- State Queries
function Bot:getState() 
    return self.currentState 
end

function Bot:isRunning() 
    return self.isStart == true 
end

function Bot:isConverting() 
    return self.currentState == Bot.States.CONVERTING 
end

function Bot:isDoingQuest() 
    return self.currentState == Bot.States.DO_QUEST 
end

function Bot:isCollecting() 
    return self.currentState == Bot.States.COLLECTING 
end

function Bot:isSubmittingQuest() 
    return self.currentState == Bot.States.SUBMITTING_QUEST 
end

function Bot:isBusy()
    local busyStates = {
        [Bot.States.CONVERTING] = true,
        [Bot.States.DO_QUEST] = true,
        [Bot.States.COLLECTING] = true,
        [Bot.States.SUBMITTING_QUEST] = true
    }
    return busyStates[self.currentState] or false
end

-- Error Handling
function Bot:safeExecute(func, context, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn(`Error in {context}: {result}`)
        self:setState(Bot.States.IDLE, true)
        return false
    end
    return result
end

-- Event Handlers
function Bot:onPlayerDied()
    self:stop()
    
    task.spawn(function()
        self.taskManager.placedField = nil
        self.taskManager.placedCount = 0

        -- Wait for respawn
        while not self:validatePlayer() do
            task.wait(1)
        end
        
        -- Wait for full load
        task.wait(1.5)
        
        -- Auto-restart
        self:start()
    end)
end

-- Cleanup
function Bot:cleanup()
    -- Clear task queue
    self.taskQueue = {}
    
    -- Disconnect all connections
    for name, connection in pairs(self.connections) do
        if connection then
            connection:Disconnect()
            self.connections[name] = nil
        end
    end
    
    -- Clear references
    self.token = nil
    self.lastTokenUpdatePos = nil
    self.taskHandlers = nil
end

function Bot:destroy()
    self:stop()
    self:cleanup()
    setmetatable(self, nil)
end

return Bot
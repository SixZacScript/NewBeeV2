-- Services
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TaskManager = shared.ModuleLoader:load(_G.URL.."/Class/Task.lua")
local TokenHelper = shared.ModuleLoader:load(_G.URL.."/Class/Token.lua")
local MemoryMatchHelper =  shared.ModuleLoader:load(_G.URL.."/Class/MemoryMatch.lua")
local SimplePath =  shared.ModuleLoader:load(_G.URL.."/Helpers/Move.lua")
local WP = game:GetService("Workspace")
-- Bot Class
local Bot = {}
Bot.__index = Bot

-- Configuration
Bot.Config = {
    UPDATE_INTERVAL = 0.05,
    MOVEMENT_THRESHOLD = 4,
    MOVEMENT_TIMEOUT = 5,
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
    AVOID_MONSTER = "AVOID_MONSTER",
    KILL_MONSTER = "KILL_MONSTER",
    -- DO_QUEST = "DO_QUEST",
    USE_WEALTH_CLOCK = "USE_WEALTH_CLOCK",
    AUTO_PLANTER = "AUTO_PLANTER",
    USE_TOY = "USE_TOY",

}

Bot.StateDisplay = {
    IDLE = "💤 Idle",
    STOP = "❌ STOPPED",
    FARMING = "🌾 Farming",
    CONVERTING = "⚗️ Converting",
    AVOID_MONSTER = "👾 Avoiding monster",
    KILL_MONSTER = "👾 Killing monster",
    -- DO_QUEST = "📜 Doing quest",
    USE_WEALTH_CLOCK = "⏱️ Using wealth clock",
    AUTO_PLANTER = "⚠️ Auto Planter",
    USE_TOY = "⚠️ Use Toy",

}

-- State Machine
local commonTransitions = {Bot.States.FARMING, Bot.States.USE_WEALTH_CLOCK, Bot.States.USE_TOY, Bot.States.AUTO_PLANTER, Bot.States.STOP, Bot.States.IDLE}

Bot.StateMachine = {
    [Bot.States.IDLE] = {
        Bot.States.CONVERTING,
        Bot.States.AVOID_MONSTER,
        Bot.States.KILL_MONSTER,
        -- Bot.States.DO_QUEST,
        unpack(commonTransitions)
    },
    [Bot.States.FARMING] = {
        Bot.States.CONVERTING,
        Bot.States.AVOID_MONSTER,
        Bot.States.KILL_MONSTER,
        -- Bot.States.DO_QUEST,
        unpack(commonTransitions)
    },
    [Bot.States.CONVERTING] = {
        unpack(commonTransitions)
    },
    [Bot.States.AVOID_MONSTER] = {
        -- Bot.States.DO_QUEST,
        unpack(commonTransitions)
    },
    [Bot.States.KILL_MONSTER] = {
        -- Bot.States.DO_QUEST,
        unpack(commonTransitions)
    },
    -- [Bot.States.DO_QUEST] = {
    --     Bot.States.CONVERTING,
    --     Bot.States.FARMING,
    --     Bot.States.AVOID_MONSTER,
    --  
    --     Bot.States.USE_WEALTH_CLOCK,
    --     Bot.States.AUTO_PLANTER,
    --     Bot.States.IDLE,
    --     Bot.States.STOP
    -- },

    [Bot.States.USE_WEALTH_CLOCK] = {
        Bot.States.CONVERTING,
        Bot.States.FARMING,
        -- Bot.States.DO_QUEST,
        Bot.States.AVOID_MONSTER,
        Bot.States.AUTO_PLANTER,
        Bot.States.IDLE,
        Bot.States.STOP,
    },
    [Bot.States.AUTO_PLANTER] = {
        Bot.States.FARMING,
        Bot.States.CONVERTING,
        -- Bot.States.DO_QUEST,
        Bot.States.AVOID_MONSTER,
        Bot.States.IDLE,
        Bot.States.STOP
    },
    [Bot.States.USE_TOY] = {
        Bot.States.AUTO_PLANTER,
        Bot.States.FARMING,
        Bot.States.CONVERTING,
        -- Bot.States.DO_QUEST,
        Bot.States.AVOID_MONSTER,
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
        converting = self.handleConvertingTask,
        planter =  self.handlePlanter,
        avoiding_monster = self.handleAvoidMonsterTask,
        killing_monster = self.handleKillMonsterTask,
        -- shouldDoQuest = self.handleDoingQuest,
        shouldUseWealthClock = self.handleWealthClock,
        shouldUseToy = self.handleUseToy
    }
end


function Bot:startIntervalTask()
    local COOLDOWN = 2700
    task.spawn(function()
        
        while true do
            local now = tick()
            local currentTime = os.time()
            
            -- Enable clock usage every hour
            if now - self.lastHourTick >= Bot.Config.CLOCK_COOLDOWN + 15 then
                self.lastHourTick = now
                self.canUseClock = true
            end
            
            -- Check toys
            local selectedToys = shared.main.Farm.fieldBoost
            if selectedToys and self.isStart then
                local ToyTimes = self.plr.plrStats.ToyTimes
                local needsRefresh = false
                
                for _, toyName in pairs(selectedToys) do
                    local usedTime = ToyTimes[toyName]
                    
                    if not usedTime or (currentTime - usedTime) >= COOLDOWN then
                        self.taskManager:useFieldBoost(toyName)
                        needsRefresh = true
                    end
                end
                
                if needsRefresh then
                    ToyTimes = self.plr:getPlayerStats().ToyTimes
                end
            end
            
            task.wait(1) 
        end
    
    end)

    -- task.spawn(function()
    --     task.wait(5)
    --     print("started")
    --     self.path = SimplePath.new(self.plr.character, {
    --         AgentRadius = 3,
    --         AgentHeight = 6,
    --         AgentCanJump = true,
    --         AgentCanClimb = true,
    --         WaypointSpacing = 1,
    --         Costs = {
    --             Climb = 2  -- Cost of the climbing path; default is 1
    --         }
    --     })
    --     self.path.Visualize = true
    --     self.path:Run(Vector3.new(268.6293029785156, 99.5068130493164, 19.66912841796875))

    --     self.path.Reached:Connect(function(agent, lastWaypoint)
    --         print("Reached final target", agent, lastWaypoint.Position)
    --     end)

    --     self.path.WaypointReached:Connect(function(agent, fromWaypoint, toWaypoint)
    --         print("Reached waypoint:", toWaypoint.Position)
    --     end)

    --     self.path.Blocked:Connect(function(agent, blockedWaypoint)
    --         print("Path blocked at:", blockedWaypoint.Position)
    --     end)

    --     self.path.Error:Connect(function(errorType)
    --         warn("Path error:", errorType)
    --     end)

    -- end)
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
        

        self.monsterCount = shared.helper.Monster:getCloseMonsterCount(Bot.Config.MONSTER_CHECK_RADIUS)
        local currentField = shared.helper.Field:getField()
        if self.currentField ~= currentField and not self:isBusy() then
            self.currentField = currentField
        end

        if not shared.main.autoQuest and self.currentState == self.States.DO_QUEST then
            self:setState(self.States.IDLE)
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
            if self.isStart then
                warn("⚰️ Player died. Resetting bot.")
                self:onPlayerDied()
            end
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
    return {
        hasMonster = self.monsterCount > 0,
        canUseClock = self.canUseClock and self.currentState ~= Bot.States.USE_WEALTH_CLOCK,
        shouldConvert = self.plr:isCapacityFull() and self.isStart,
        canHarvestPlanter = self.shouldDoPlanter(),
        -- questAvailable = self:shouldDoQuest(),
        shouldKillMonster = self:shouldKillMonster(),
        shouldFarm = self:shouldFarm(),
        shouldUseToy = self:shouldUseToy()
    }
end

-- Optimized Task Prioritization
function Bot:checkForNewTasks()
    local conditions = self:evaluateConditions()

    if conditions.hasMonster then
        self:addTask({type = "avoiding_monster", priority = 1})
    elseif conditions.canUseClock then
        self:addTask({type = "shouldUseWealthClock", priority = 2})
    elseif conditions.shouldUseToy then
        self:addTask({type = "shouldUseToy", priority = 3})
    elseif conditions.shouldConvert then
        self:addTask({type = "converting", priority = 4})
    elseif conditions.canHarvestPlanter then
        self:addTask({type = "planter", priority = 5})
    -- elseif conditions.questAvailable then
    --     self:addTask({type = "shouldDoQuest", priority = 6})
    elseif conditions.shouldKillMonster then
        self:addTask({type = "killing_monster", priority = 9})
    elseif conditions.shouldFarm then
        self:addTask({type = "farming", priority = 10})
    else
        print("⚠️ No conditions met, forcing farming task")
        self:addTask({type = "farming", priority = 10})
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

function Bot:handleKillMonsterTask()
    self:setState(self.States.KILL_MONSTER)
    -- local MonsterList = shared.helper.Monster:getAvailableMonster()
    -- local monsterInField = {}

    -- for _, monster in pairs(MonsterList) do
    --     if not monsterInField[monster.field] then monsterInField[monster.field] = {} end
    --     table.insert(monsterInField[monster.field], monster)
    -- end

    -- for fieldName, monsters  in pairs(monsterInField) do
    --     local fieldPart = shared.helper.Field:getField(fieldName)
    --     self.taskManager:returnToField({Position = fieldPart.Position, Player = self.plr})
    --     task.wait(0.5)
    --     for index, monster in pairs(monsters) do
    --         local startTime = tick()
    --         repeat
    --             local targetModel = shared.helper.Monster:getMonsterModel(monster.monsterType)
    --             if targetModel  and (monster and fieldPart.Name == "Pine Tree Forest") then
    --                 local distance = shared.helper.Monster:getDistanceToMonster(targetModel)
    --                 if distance and distance > 30 then
    --                     local root = self.plr.rootPart
    --                     local direction = (targetModel.PrimaryPart.Position - root.Position).Unit
    --                     local nextPos = root.Position + direction * 10
    --                     self.plr.humanoid:MoveTo(nextPos)
    --                 end
    --             end
    --             self.plr.humanoid.Jump = true
    --             task.wait(1.5)
    --         until monster.timerLabel.Visible or not self.isStart or (tick() - startTime) > 60 -- 1 min
    --     end
        
    --     if self.isStart then task.wait(.5) end

    --     local startTime = tick()
    --     local timeout = 30 
    --     local tokens = self.tokenHelper:getTokensByField(fieldPart, {igoreSkill = true, ignoreBubble = true})
    --     repeat
    --         tokens = self.tokenHelper:getTokensByField(fieldPart, {igoreSkill = true, ignoreBubble = true})
    --         if #tokens > 0 then

    --             self.taskManager:collectTokenByList(tokens)
    --         end
    --         task.wait()
    --     until #tokens == 0 or (tick() - startTime) > timeout
                

    -- end

    self:setState(self.States.IDLE)
    return true
end


function Bot:handleDoingQuest(taskData)
--     local currentQuest = self.questHelper.currentQuest
--     local currentTask = self.questHelper.currentTask

--     if not shared.main.autoQuest then
--         warn("Auto quest is disabled")
--         return true
--     end
    
--     if not currentQuest or not currentTask then
--         warn("No current quest assigned (early exit)")
--         return true
--     end
    
--     if self:shouldSubmitQuest() then
--         warn("Quest is completed, skipping")
--         return true
--     end
--     self:setState(Bot.States.DO_QUEST)
    
--     self.currentField = self:determineQuestField(currentTask)
--     if currentTask.Type == "Collect Pollen" or currentTask.Type == "Collect Tokens" then
--         return self.taskManager:doFarming()
--     end


--     if currentTask.Type == "Defeat Monsters" then
--         return self.taskManager:doHunting()
--     end


--     -- local nextQuest = self.questHelper:getAvailableTask()
--     -- if nextQuest then
--     --     return false
--     -- end
    
--     self:setState(Bot.States.IDLE)
    return true
end


function Bot:handleUseToy()
    self:setState(Bot.States.USE_TOY)
    
    return false
end

function Bot:handleWealthClock(taskData)
    if self.currentState == Bot.States.USE_WEALTH_CLOCK then return false end
    
    self:setState(Bot.States.USE_WEALTH_CLOCK)
    
    local clockPos = Vector3.new(330.5519104003906, 48.43824005126953, 191.44041442871094)
    local completed = false
    self.plr:tweenTo(clockPos, 1, function()
        task.wait(1)
        
        -- Simulate E key press
        for _, state in ipairs({true, false}) do
            VirtualInputManager:SendKeyEvent(state, Enum.KeyCode.E, false, game)
        end
        
        task.wait(1)
        self.canUseClock = false
        completed = true
        self:setState(Bot.States.IDLE)
    end)

    while not completed and self.isStart do
        task.wait(1)
    end

    return true
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

function Bot:shouldUseToy()
    local ToysReadyTouse = {}
    local selectedToys = shared.main.Misc.memoryMatchs or {}
    local ToyTimes = self.plr.plrStats.ToyTimes
    local currentTime = os.time()

    for _, toyname in pairs(selectedToys) do
        local toyData = MemoryMatchHelper:getData(toyname)
        local lastUsedTime = ToyTimes[toyname]

        if toyData then
            if not lastUsedTime then
                table.insert(ToysReadyTouse, toyname)
            else
                local isReady = (currentTime - lastUsedTime) >= toyData.cooldown
                if isReady then table.insert(ToysReadyTouse, toyname) end
            end
        end
    end

    -- return #ToysReadyTouse > 0
    return false
end


-- function Bot:shouldDoQuest()
--     if self.plr:isCapacityFull() or not shared.main.autoQuest or self:shouldAvoidMonster()  then
--         return false
--     end

--     local q = self.questHelper
--     return q.currentQuest and q.currentTask and not q.isCompleted
-- end

function Bot:shouldKillMonster()
    -- if not shared.main.Monster.autoHunt then return false end
    -- local monsters = shared.helper.Monster:getAvailableMonster()
    -- if monsters then return true end
    
    return false
end

function Bot:shouldConvert()
    return self.plr:isCapacityFull() and self.isStart
end

function Bot:shouldFarm()
    if not self.isStart or self:shouldConvert()  then
        return false
    end
    
    local busyStates = {
        [Bot.States.CONVERTING] = true,
        [Bot.States.AVOID_MONSTER] = true,
        [Bot.States.KILL_MONSTER] = true,
        -- [Bot.States.DO_QUEST] = true
    }
    
    if busyStates[self.currentState] then
        return false
    end
    
    return self.currentState == Bot.States.IDLE or self.currentState == Bot.States.FARMING
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


function Bot:isSubmittingQuest() 
    return self.currentState == Bot.States.SUBMITTING_QUEST 
end

function Bot:isBusy()
    local busyStates = {
        [Bot.States.CONVERTING] = true,
        -- [Bot.States.DO_QUEST] = true,
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
    self.lastTokenUpdatePos = nil
    self.taskHandlers = nil
end

function Bot:destroy()
    self:stop()
    self:cleanup()
    setmetatable(self, nil)
end

return Bot
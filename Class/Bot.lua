-- Bot.lua
local TaskManager = shared.ModuleLoader:load("NewBeeV2/Class/Task.lua")
local StateManager = shared.ModuleLoader:load("NewBeeV2/Class/State.lua")
local TaskExecutor = shared.ModuleLoader:load("NewBeeV2/Class/TaskExc.lua")

local Bot = {}
Bot.__index = Bot

function Bot.new()
    local self = setmetatable({}, Bot)
    
    -- Player references
    self.Field = shared.helper.Field
    self.player = shared.helper.Player
    self.Hive = shared.helper.Hive
    
    -- Initialize managers
    self.taskManager = TaskManager.new()
    self.stateManager = StateManager.new()
    self.taskExecutor = TaskExecutor.new(self)
    self.TaskTypes = TaskManager.TaskTypes
    -- Bot state
    self.isRunning = false
    self.updateLoop = nil
    
    -- Configuration
    self.config = {
        moveSpeed = 16,
        collectRadius = 10,
        attackRange = 15,
        idleTimeout = 5
    }
    
    return self
end

-- Main bot loop
function Bot:update()
    if not self.isRunning  then return end

    if self.taskManager.currentTask and self.taskManager.currentTask.status == "canceled" then
        self.taskManager.currentTask = nil
        self.stateManager:setState(self.stateManager.States.IDLE)
    end

    if self.taskManager.currentTask and self.taskManager.currentTask.status == "completed" then
        self.taskManager.currentTask = nil
    end

    if self.taskManager.currentTask then
        -- print(self.taskManager.currentTask.status)
        local isNotCompleted =self.taskManager.currentTask.status ~= "completed"
        if isNotCompleted then
            local taskComplete = self.taskExecutor:executeTask(self.taskManager.currentTask)
            if taskComplete then
                self.taskManager.currentTask = nil
            end
        end
    end

    if not self.taskManager.currentTask then
        self.taskManager.currentTask = self.taskManager:getNextTask()
        if not self.taskManager.currentTask then
            self.stateManager:setState(self.stateManager.States.IDLE)
        end
    end

    self:updateState()
end


function Bot:updateState()
    local States = self.stateManager.States
    
    if self.stateManager:getState() == States.IDLE then
        if self.stateManager:getStateTime() > self.config.idleTimeout then
            -- Do something when idle too long
        end
    elseif self.stateManager:getState() == States.MOVING then
        if self.stateManager:getStateTime() > 10 then -- 10 second timeout
            self.stateManager:setState(States.IDLE)
            if self.taskManager.currentTask then
                self.taskManager.currentTask.status = "failed"
                self.taskManager.currentTask = nil
            end
        end
    end
end
function Bot:startFarmingLoop(locations)
    repeat task.wait() until self.Hive.hive
    if not self.player:isPlayerInField(self.Field:getField()) then
        local data = {
            position = self.Field:getFieldPosition(),
            moveType = "tween",
        }
        self.taskManager:addTask(self.TaskTypes.MOVE_TO, data)
    end

    task.spawn(function()
        repeat
            local isConverting = self.stateManager:isConverting()
            print(isConverting)
            if self.taskManager:getTaskCount() == 0 then
                if self.player:isCapacityFull() and not isConverting then
                    self:convertPollen()
                elseif not isConverting then
                    self:randomWalkInField()
                end
                
            end
            task.wait()
        until not self.isRunning
    end)

  
end


function Bot:start()
    if self.isRunning then return end
    
    self.isRunning = true
    self.stateManager:setState(self.stateManager.States.IDLE)
   
    self.updateLoop = game:GetService("RunService").Heartbeat:Connect(function()
        self:update()
    end)

    self:startFarmingLoop()
end

function Bot:stop()
    if not self.isRunning then return end
    
    self.isRunning = false
    self.stateManager:setState(self.stateManager.States.PAUSED)
    
    if self.updateLoop then
        self.updateLoop:Disconnect()
        self.updateLoop = nil
    end
    
    print("Bot stopped")
end

function Bot:destroy()
    self:stop()
    self.taskManager:clearTasks()
    print("Bot destroyed")
end

-- Task management wrapper functions
function Bot:addTask(taskType, data)
    return self.taskManager:addTask(taskType, data)
end

function Bot:cancelCurrentTask()
    local success, info = self.taskManager:cancelCurrentTask()
    if success then
        if self.taskManager.currentTask then
            self.taskExecutor:cleanupTask({type = info.type, data = {}})
        end
        self.stateManager:setState(self.stateManager.States.IDLE)
        print("Canceled current task: " .. info.type .. " (ID: " .. info.id .. ")")
    else
        print(info) -- Error message
    end
    return success
end

function Bot:cancelTask(taskId)
    local success, info = self.taskManager:cancelTask(taskId)
    if success then
        print("Canceled task: " .. info.type .. " (ID: " .. info.id .. ")")
    else
        print(info) -- Error message
    end
    return success
end

function Bot:cancelAllTasks()
    local canceledTasks = self.taskManager:cancelAllTasks()
    self.stateManager:setState(self.stateManager.States.IDLE)
    print("Canceled " .. #canceledTasks .. " tasks")
    return #canceledTasks
end

function Bot:emergencyStop()
    print("EMERGENCY STOP activated!")

    self:stopLoop()
    self:cancelAllTasks()
    self.player:stopMoving()
    self.stateManager:setState(self.stateManager.States.PAUSED)
    
    return true
end

-- State management wrapper functions
function Bot:onStateChange(state, callback)
    self.stateManager:onStateChange(state, callback)
end

function Bot:getState()
    return self.stateManager:getState()
end

function Bot:isIdle()
    return self.stateManager:isIdle()
end

-- Utility functions
function Bot:convertPollen()
    self.stateManager:setState(self.stateManager.States.CONVERT)
    return self:addTask(TaskManager.TaskTypes.CONVERT)
end

function Bot:randomWalkInField(position)
    local randomPos = self.Field:getRandomFieldPosition()
    return self:addTask(TaskManager.TaskTypes.MOVE_TO, {position = randomPos, moveType = "walk"})
end

function Bot:moveToPosition(position)
    return self:addTask(TaskManager.TaskTypes.MOVE_TO, {position = position})
end

function Bot:collectItem(item)
    return self:addTask(TaskManager.TaskTypes.COLLECT_ITEM, {item = item})
end

function Bot:attackTarget(target)
    return self:addTask(TaskManager.TaskTypes.ATTACK_TARGET, {target = target})
end

function Bot:wait(duration)
    return self:addTask(TaskManager.TaskTypes.WAIT, {duration = duration})
end

function Bot:getTaskInfo()
    return {
        current = self.taskManager:getCurrentTaskInfo(),
        queued = self.taskManager:getQueuedTasks(),
        total = self.taskManager:getTaskCount()
    }
end

return Bot
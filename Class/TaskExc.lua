local Services = {
    Workspace = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local TaskExecutor = {}
TaskExecutor.__index = TaskExecutor

function TaskExecutor.new(bot)
    local self = setmetatable({}, TaskExecutor)
    self.bot = bot
    
    return self
end

function TaskExecutor:executeTask(task)
    if not task then return false end

    if task.status == "executing" then
        return false
    end

    if task.status ~= "executing" then
        task.status = "executing"
    end

    local TaskTypes = shared.ModuleLoader:load("NewBeeV2/Class/Task.lua").TaskTypes
        
    if task.type == TaskTypes.MOVE_TO then
        return  self:executeMoveTask(task)
    elseif task.type == TaskTypes.CONVERT then
        return  self:executeConvertTask(task)
    elseif task.type == TaskTypes.COLLECT_ITEM then
        return  self:executeCollectTask(task)
    elseif task.type == TaskTypes.ATTACK_TARGET then
        return  self:executeAttackTask(task)
    elseif task.type == TaskTypes.WAIT then
        return  self:executeWaitTask(task)
    end

    return false
end

function TaskExecutor:executeConvertTask(tk)
    local player = self.bot.player
    local hive = self.bot.Hive
    local stateManager = self.bot.stateManager
    local hivePosition = hive:getHivePosition()

    player:tweenTo(hivePosition, 1, function()
        task.wait(1)
        Services.ReplicatedStorage.Events.PlayerHiveCommand:FireServer("ToggleHoneyMaking")

        local startTime = tick()
        local timeoutDuration = 180
        while player.Pollen > 0 and tk.status ~= "canceled" do
            task.wait(0.2)
            if tick() - startTime >= timeoutDuration then break end
        end

        task.wait(5)

        local fieldPos = self.bot.Field:getFieldPosition()
        player:tweenTo(fieldPos, 1, function()
            tk.status = "completed"
            stateManager:setState(stateManager.States.IDLE)
        end)
    end)

    return tk.status == "completed" 
end

function TaskExecutor:executeMoveTask(tk)
    local targetPosition = tk.data.position
    local moveType = tk.data.moveType
    if not targetPosition then return false end

    local player = self.bot.player
    self.bot.stateManager:setState(self.bot.stateManager.States.MOVING)


    if moveType == "tween" then
        player:tweenTo(targetPosition, 1, function()
            tk.status = "completed"
        end)
    else
        player:moveTo(targetPosition, function()
            tk.status = "completed"
        end)
    end

    return tk.status == "completed"
end


function TaskExecutor:executeLoopCompleteTask(task)
    print("Loop iteration completed")
    
    -- Trigger next loop iteration
    self.bot:executeLoop()
    
    task.status = "completed"
    return true
end

function TaskExecutor:executeCollectTask(task)
    local targetItem = task.data.item
    if not targetItem then return false end
    
    self.bot.stateManager:setState(self.bot.stateManager.States.COLLECTING)
    
    -- Add your collection logic here
    task.status = "completed"
    return true
end

function TaskExecutor:executeAttackTask(task)
    local target = task.data.target
    if not target then return false end
    
    self.bot.stateManager:setState(self.bot.stateManager.States.ATTACKING)
    
    -- Add your attack logic here
    task.status = "completed"
    return true
end

function TaskExecutor:executeWaitTask(task)
    local waitTime = task.data.duration or 1
    
    if not task.startTime then
        task.startTime = tick()
        self.bot.stateManager:setState(self.bot.stateManager.States.IDLE)
    end
    
    if tick() - task.startTime >= waitTime then
        task.status = "completed"
        return true
    end
    
    return false
end

function TaskExecutor:cleanupTask(task)
    local TaskTypes = require(script.Parent.TaskManager).TaskTypes
    
    if task.type == TaskTypes.MOVE_TO then
        local player = self.bot.player
        if player and player.Character and player.Character.Humanoid then
            player.Character.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
        end
    elseif task.type == TaskTypes.COLLECT_ITEM then
        -- Stop any collection animations or processes
    elseif task.type == TaskTypes.ATTACK_TARGET then
        -- Stop attacking
    elseif task.type == TaskTypes.WAIT then
        -- Nothing special needed for wait tasks
    end
    
    if task.startTime then
        task.startTime = nil
    end
end

return TaskExecutor
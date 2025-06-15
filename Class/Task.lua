local Services = {
    Workspace = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}
local Folders = {
    Monsters = Services.Workspace:FindFirstChild("Monsters")
}
local TaskManager = {}
TaskManager.__index = TaskManager

local COLLECTION_TIMEOUT = 5
local COLLECTION_RETRIES = 2
local Logger = {
    INFO = "INFO",
    WARN = "WARN", 
    ERROR = "ERROR",
    SUCCESS = "SUCCESS"
}

function TaskManager.new(bot)
    local self = setmetatable({}, TaskManager)
    self.bot = bot
    self.Field = bot.Field
    self.hive = bot.Hive
    self.collectedToken = {}
    self.debugVisual = nil
    return self
end

-- Task.lua
function TaskManager:submitQuest(currentQuest)
    if not currentQuest then
        warn("Submit fail: current quest not found.")
        self.bot:setState(self.bot.States.FARMING)
        return false
    end

    local currentQuestName = currentQuest.Name
    if not currentQuestName then
        warn("Submit fail: current quest name is nil.")
        self.bot:setState(self.bot.States.FARMING)
        return false
    end

    local nextQuest = currentQuest.NextQuest
    local completeQuestEvent = game:GetService("ReplicatedStorage").Events.CompleteQuest
    completeQuestEvent:FireServer(currentQuestName)
    task.wait(1) 

    if nextQuest then
        local giveQuestEvent = game:GetService("ReplicatedStorage").Events.GiveQuest
        giveQuestEvent:FireServer(nextQuest)
        task.wait(1) 
    end
    
    
    self.bot.questHelper:clearCurrentQuest()
    self.bot.questHelper:selectCurrentQuestAndTask()
    self.bot:setState(self.bot.States.IDLE)
    return true
end

function TaskManager:returnToField(data)
    if not data.Position then return warn('Failed returnToField becuz Position is nil') end
    if not data.Player then return warn('Failed returnToField player not found') end

    local player = data.Player
    local fieldPosition = data.Position + Vector3.new(0, 4, 0)
    local thread = coroutine.running()

    player:tweenTo(fieldPosition, 1, function()
        task.wait(.5)
        
        if data.Callback and typeof(data.Callback) == "function" then data.Callback() end
        coroutine.resume(thread)
    end)

    return coroutine.yield()
end

function TaskManager:getDistanceToMonster(monster)
    if not monster or not monster.PrimaryPart or not self.bot.player:isValid() then
        return nil
    end
    
    local playerPosition = self.bot.player.rootPart.Position
    local monsterPosition = monster.PrimaryPart.Position
    
    return (playerPosition - monsterPosition).Magnitude
end

function TaskManager:avoidMonsterAsync(monster)
    self.bot:setState(self.bot.States.AVOID_MONSTER)

    if not monster or not self.bot.player:isValid() then
        self.bot:setState(self.bot.States.FARMING)
        return false
    end

    local character = self.bot.player.character
    local humanoid = self.bot.player.humanoid
    self.bot.plr:stopMoving()

    local lastJumpTime = tick()
    local jumpCooldown = 1.5

    local function isMonsterValid(mon)
        return mon and mon.Parent and mon.PrimaryPart
    end
    local isPlayerValid = function()
        return self.bot.player:isValid()
    end
    while self.bot:isRunning() and isMonsterValid(monster) and isPlayerValid do
        if shared.helper.Monster:getCloseMonsterCount(self.bot.monsterInRadius) <= 0 then
            break
        end
        if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            local now = tick()
            if now - lastJumpTime >= jumpCooldown then
                humanoid.Jump = true
                lastJumpTime = now
            end
        end
        task.wait(0.1)
    end

    if not isMonsterValid(monster) then
        while isPlayerValid and humanoid.FloorMaterial == Enum.Material.Air do
            task.wait()
        end
    end

    self.bot:setState(self.bot.States.FARMING)  
    return true
end


function TaskManager:doFarming()
    local player = self.bot.plr
    if not player then return false end
    local currentField = self.bot.currentField

    local randomPosition = shared.helper.Field:getRandomFieldPosition(currentField)
    if not player:isPlayerInField(currentField) then
        self.bot.token = nil
        self:returnToField({ Position = currentField.Position, Player = player })
    end
    
    self.bot:moveTo(randomPosition, {
        timeout = 5,
        onBreak = function(breakFunc)
            local runService = game:GetService("RunService")
            local tokenCheckConnection

            tokenCheckConnection = runService.Heartbeat:Connect(function()
                if tokenCheckConnection then
                    tokenCheckConnection:Disconnect()
                end
                if self.bot.token then
                    if tokenCheckConnection then tokenCheckConnection:Disconnect() end
                    breakFunc()
                end
            end)
        end
    })
    return true
end



function TaskManager:convertPollen()
    if not self.bot.plr:isCapacityFull() then 
        return false 
    end
    local player = self.bot.plr
    local thread = coroutine.running()
    local bot = self.bot

    player:tweenTo(self.hive:getHivePosition(), 1, function()
        if not bot:isRunning() then 
            warn("bot is not running")
            coroutine.resume(thread, false)
            return 
        end
        
        player:disableWalking(true)
        task.wait(1)
        Services.ReplicatedStorage.Events.PlayerHiveCommand:FireServer("ToggleHoneyMaking")

        local startTime = tick()
        local timeout = 180
        local player = player
        local botValid = bot:isConverting() and bot:isRunning()
        while player.Pollen > 0 and botValid and (tick() - startTime < timeout) do
            task.wait()
        end

        if bot:isRunning() then task.wait(5) end
        player:disableWalking(false)
        coroutine.resume(thread, true)
    end)

    return coroutine.yield()
end

function TaskManager:handleKillingMonster(taskData, bot)
    local thread = coroutine.running()
    local targetMonster = taskData.MonsterType
    local canHunt, fieldName = bot.monsterHelper:canHuntMonster(targetMonster)

    -- If can't hunt now, try switching task
    if not canHunt then 
        local newTask = bot.questHelper:getNextAvailableTask()
        if newTask then
            bot.questHelper.currentTask = newTask
            bot.questHelper:updateDisplay()
        end
        coroutine.resume(thread, false) 
        return coroutine.yield()
    end

    local fieldPosition = bot.Field:getFieldPosition(fieldName)
    print("change state to KILL_MONSTER")
    bot:setState(bot.States.KILL_MONSTER)
    print("chaded state : ",bot.currentState)

    bot.player:tweenTo(fieldPosition, 1, function()
        task.wait(0.5)
        local player = bot.player
        local humanoid = player.humanoid

        while bot.isStart and player:isValid() and bot.monsterHelper:canHuntMonster(targetMonster) do
            task.wait(1)
            if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end
        end

        bot:revertToLastState()
        coroutine.resume(thread, true)
    end)

    return coroutine.yield()
end


function TaskManager:clearDebugVisual()
    if self.debugVisual then
        self.debugVisual:Destroy()
        self.debugVisual = nil
    end
end

function TaskManager:walkTo(taskObj)
    self:clearDebugVisual()
    local player = self.bot.plr
    local rootPart = player.rootPart
    local humanoid = player.humanoid
    local targetPosition = taskObj.data.position
    local taskType = taskObj.data.type or "Unknow"
    local timeout = taskObj.data.timeout or 5

    if not rootPart or not humanoid or not targetPosition then return warn("humanoid not found") end

    local reached = false
    local startTime = tick()
    local isRunning = true
    local moveConn,cancelConn
    self.debugVisual = player:debugVisual(targetPosition, taskType == "collectToken" and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
    humanoid:MoveTo(targetPosition)

    local function cleanup()
        self:clearDebugVisual()
        if moveConn then 
            moveConn:Disconnect() 
            moveConn = nil
        end
        if cancelConn then 
            cancelConn:Disconnect() 
            cancelConn = nil
        end
    end

    moveConn = humanoid.MoveToFinished:Connect(function()
        reached = true
        cleanup()
    end)

    cancelConn = Services.RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if not self.bot:isRunning() or (currentTime - startTime > timeout) then
            isRunning = false
            player:stopMoving()
            cleanup()
        end
    end)

    repeat
        task.wait()
    until reached or not isRunning

    cleanup()
    return reached
end



function Logger:log(level, message, data)
    local timestamp = os.date("%H:%M:%S")
    local prefix = {
        [self.INFO] = "ℹ️",
        [self.WARN] = "⚠️", 
        [self.ERROR] = "❌",
        [self.SUCCESS] = "✅"
    }
    
    print(string.format("[%s] %s %s", timestamp, prefix[level] or "•", message))
    
    if data then
        for key, value in pairs(data) do
            print(string.format("  • %s: %s", key, tostring(value)))
        end
    end
end

function TaskManager:validateTokenData(taskObj)
    if not taskObj then
        return false, "Task object is nil"
    end
    
    if not taskObj.data then
        return false, "Task data is missing"
    end
    
    if not taskObj.data.token then
        return false, "Token data is missing"
    end
    
    return true, nil
end

function TaskManager:calculateTokenMetrics(token, playerPosition)
    local tokenPosition = token.position
    local distance = (tokenPosition - playerPosition).Magnitude
    local age = tick() - (token.SpawnTime or tick())
    
    return {
        position = tokenPosition,
        distance = math.round(distance * 100) / 100,
        age = math.round(age * 100) / 100,
        efficiency = token.priority / math.max(distance, 1) 
    }
end


function TaskManager:attemptTokenCollection(token, retries)
    retries = retries or COLLECTION_RETRIES
    local humanoid = self.bot.player.humanoid
    local lastSpeed = shared.main.WalkSpeed

    if token.priority >= 80 then
        shared.main.WalkSpeed = 100
        humanoid.WalkSpeed = 100
    end
    local success = false
    for attempt = 1, retries do
        success = self:walkTo({
            data = {
                type = "collectToken",
                position = token.Position,
                timeout = COLLECTION_TIMEOUT
            }
        })
        if success then break end

        if attempt < retries then
            Logger:log(Logger.WARN, string.format("Collection attempt %d failed, retrying...", attempt))
            task.wait(0.5)
        end
    end

    shared.main.WalkSpeed = lastSpeed
    humanoid.WalkSpeed = lastSpeed
    return success
end



function TaskManager:collectToken(taskObj)
    local token = taskObj.data.token
    local rootPart = self.bot.player.rootPart

    if not token or not rootPart then
        return false
    end

    local isValid, errorMsg = self:validateTokenData(taskObj)
    if not isValid then
        warn(errorMsg)
        return false
    end

    local playerPosition = rootPart.Position
    local metrics = self:calculateTokenMetrics(token, playerPosition)
    token.Position = metrics.position

    if not self:attemptTokenCollection(token) then
        return false
    end

    return true
end



return TaskManager
local Services = {
    Workspace = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}

local placeSprinklerEvent = game:GetService("ReplicatedStorage").Events.PlayerActivesCommand
local TaskManager = {}
TaskManager.__index = TaskManager

function TaskManager.new(bot)
    local self = setmetatable({}, TaskManager)
    self.bot = bot
    self.Field = bot.Field
    self.hive = bot.Hive
    self.collectedToken = {}
    self.placedField = nil
    self.debugVisual = nil
    return self
end

-- Task.lua
function TaskManager:submitQuest(currentQuest)
    if not currentQuest then
        warn("Submit fail: current quest not found.")
        self.bot:setState(self.bot.States.FARMING)
        return true
    end

    local currentQuestName = currentQuest.Name
    if not currentQuestName then
        warn("Submit fail: current quest name is nil.")
        self.bot:setState(self.bot.States.FARMING)
        return true
    end
    
    local nextQuest = shared.helper.Quest:submitQuest(currentQuest)
    if nextQuest then
        self.bot:setState(self.bot.States.IDLE)
    else
        self.bot:setState(self.bot.States.FARMING)
    end
    
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

function TaskManager:doHunting()
    local currentTask = self.bot.questHelper.currentTask
    local monsterType = currentTask.MonsterType
    local canHunt, fieldName = shared.helper.Monster:canHuntMonster(monsterType)

    if not canHunt or not fieldName then 
        self.bot:setState(self.bot.States.FARMING)
        return true
    end
    local fieldPart = shared.helper.Field:getField(fieldName)
    self:returnToField({Position = fieldPart.Position, Player = self.bot.plr})
    local monsterList = shared.helper.Monster:getMonsterByType(monsterType)
    local startTime = tick()
    repeat
        monsterList = shared.helper.Monster:getMonsterByType(monsterType)
        task.wait()
    until #monsterList > 0 or tick() - startTime >= 60

    if #monsterList == 0 then 
        self.bot:setState(self.bot.States.IDLE)
        return true
    end

    for index, value in pairs(monsterList) do
        local targetMonster = monsterList[index]
        repeat
            if not targetMonster or not targetMonster:IsDescendantOf(workspace) then
                break
            end

            self.bot.plr.humanoid.Jump = true
            task.wait(1.5)
        until not targetMonster and not self.bot.plr:isValid()
        
    end
    task.wait(.5)

    local tokens = self.bot.tokenHelper:getTokensByField(fieldPart)
    self:collectTokenByList(tokens)

    self.bot.questHelper:getAvailableTask()
    self.bot:setState(self.bot.States.IDLE)
    return true
end
function TaskManager:placePlanter()
    local playerHelper = self.bot.plr
    local planterToPlace = playerHelper:getPlanterToPlace() -- is slot
    if not planterToPlace or not planterToPlace.Field then 
        self.bot:setState(self.bot.States.IDLE)
        return  true
    end

    local targetField = planterToPlace.Field
    local originalFieldName = shared.helper.Field:getOriginalFieldName(targetField)


    local fieldPart = shared.helper.Field:getField(originalFieldName)
    local EventCmd = game:GetService("ReplicatedStorage").Events
    local placeEvt = EventCmd.PlayerActivesCommand

    local completed = false
    local fullName = playerHelper:getPlanterFullName(planterToPlace.PlanterType)
    playerHelper:tweenTo(fieldPart.Position + Vector3.new(0, 3, 0), 1, function()

        task.wait(1)
        placeEvt:FireServer({ Name = fullName })

        completed = true
    end)

    while not completed do
        task.wait(0.1)
    end

    self.bot:setState(self.bot.States.IDLE)
    return true
end
function TaskManager:harvestPlanter()
    local playerHelper = self.bot.plr
    local planterToHarvest = playerHelper:getCanHarvestPlanter()

    local planterPos  = planterToHarvest.Position
    local fullName    = playerHelper:getPlanterFullName(planterToHarvest.Type)
    local field       = shared.helper.Field:getFieldByPosition(planterPos)
    local EventCmd    = game:GetService("ReplicatedStorage").Events
    local harvestEvt  = EventCmd.PlanterModelCollect
    local placeEvt    = EventCmd.PlayerActivesCommand
    
    -- Use a completion flag instead of coroutines
    local completed = false
    playerHelper:tweenTo(planterPos + Vector3.new(0, 4, 0), 1, function()
        task.wait(1)
        harvestEvt:FireServer(planterToHarvest.ActorID)


        task.wait(1)
        placeEvt:FireServer({ Name = fullName })

        task.wait(1)
        if field then
            local tokens =  self.bot.tokenHelper:getTokensByField(field)
            self:collectTokenByList(tokens)
        end

        completed = true
    end)

    -- Wait for completion
    while not completed do
        task.wait(0.1)
    end

    self.bot:setState(self.bot.States.IDLE)
    return true
end

function TaskManager:collectTokenByList(tokens)
    local botPos = self.bot.plr:getPosition()

    local function getSortedValidTokens(tokenList, playerPos)
        local validTokens = {}
        for _, token in ipairs(tokenList) do
            if token and token.position and token.instance then
                table.insert(validTokens, token)
            end
        end
        
        table.sort(validTokens, function(a, b)
            return (a.position - playerPos).Magnitude < (b.position - playerPos).Magnitude
        end)
        
        return validTokens
    end
    tokens = getSortedValidTokens(tokens, botPos)
    for _, token in ipairs(tokens) do
        if token.instance and self.bot.plr:isValid() then
            local humanoid = self.bot.plr.humanoid
            if humanoid then
                local conn
                local reached = false
                conn = humanoid.MoveToFinished:Connect(function()
                    reached = true
                end)

                humanoid:MoveTo(token.position)

                local startTime = tick()
                while not reached and tick() - startTime < 5 do
                    if not self.bot.plr:isValid() then
                        if conn then conn:Disconnect() end
                        return false
                    end
                    task.wait(0.1)
                end

                if conn then conn:Disconnect() end
            end

            task.wait()

            botPos = self.bot.plr:getPosition()
            tokens = getSortedValidTokens(tokens, botPos)
        end
    end
end


function TaskManager:isSprinklerPlaced(field)
    return self.placedField == field
end



function TaskManager:getDistanceFromField(field)
    local player = self.bot.plr
    if not player.rootPart or not field then return nil end

    local origin = player.rootPart.Position
    local direction = Vector3.new(0, -100, 0)

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {field}
    params.FilterType = Enum.RaycastFilterType.Include

    local result = workspace:Raycast(origin, direction, params)

    if result and result.Instance == field then
        return (origin - result.Position).Magnitude
    end

    return nil 
end

function TaskManager:shouldPlaceSprinkler(field, sprinklerName, sprinklerData)
    return sprinklerName
        and sprinklerData
        and shared.main.autoSprinkler
        and not self:isSprinklerPlaced(field)
end

function TaskManager:waitUntilAirborne(humanoid)
    while humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.Parent do
        task.wait()
    end
end

function TaskManager:waitUntilNearGround(humanoid, field, maxDistance)
    while humanoid.FloorMaterial == Enum.Material.Air and humanoid.Parent do
        local distance = self:getDistanceFromField(field)
        if distance and distance <= maxDistance then
            return true
        end
        task.wait()
    end
    return false
end

function TaskManager:getSprinklerPositions(field, sprinklerData)
    local positions = {}
    if not field or not sprinklerData then return positions end

    local center = field.Position
    local count = sprinklerData.count
    local radius = sprinklerData.radius * 2
    local fieldSize = field.Size or Vector3.new(50, 0, 50)

    -- เช็คว่า field กว้างทางแกน X หรือ Z
    local isWideX = fieldSize.X > fieldSize.Z
    local isWideZ = fieldSize.Z > fieldSize.X

    -- คำนวณระยะห่างแบบปรับเองได้ ถ้าไม่มีให้ fallback เป็น radius
    local maxSpacing = math.min(fieldSize.X, fieldSize.Z) * 0.9
    local spacing = math.min(radius * 1.5, maxSpacing)
    

    if count == 1 then
        table.insert(positions, center)

    elseif count == 2 then
        if isWideX then
            table.insert(positions, center + Vector3.new(-spacing/2, 0, 0))
            table.insert(positions, center + Vector3.new(spacing/2, 0, 0))
        elseif isWideZ then
            table.insert(positions, center + Vector3.new(0, 0, -spacing/2))
            table.insert(positions, center + Vector3.new(0, 0, spacing/2))
        else
            table.insert(positions, center + Vector3.new(-spacing/2, 0, 0))
            table.insert(positions, center + Vector3.new(spacing/2, 0, 0))
        end

    elseif count == 3 then
        if isWideX then
            table.insert(positions, center + Vector3.new(-spacing, 0, 0))
            table.insert(positions, center)
            table.insert(positions, center + Vector3.new(spacing, 0, 0))
        elseif isWideZ then
            table.insert(positions, center + Vector3.new(0, 0, -spacing))
            table.insert(positions, center)
            table.insert(positions, center + Vector3.new(0, 0, spacing))
        else
            table.insert(positions, center + Vector3.new(0, 0, -spacing/2))
            table.insert(positions, center + Vector3.new(-spacing/2, 0, spacing/2))
            table.insert(positions, center + Vector3.new(spacing/2, 0, spacing/2))
        end

    elseif count == 4 then
        table.insert(positions, center + Vector3.new(-spacing/2, 0, -spacing/2))
        table.insert(positions, center + Vector3.new(spacing/2, 0, -spacing/2))
        table.insert(positions, center + Vector3.new(-spacing/2, 0, spacing/2))
        table.insert(positions, center + Vector3.new(spacing/2, 0, spacing/2))
    end

    return positions
end



function TaskManager:placeSprinklersByPosition(field, sprinklerData)
    local humanoid = self.bot.plr.humanoid
    local positions = self:getSprinklerPositions(field, sprinklerData)
    local maxToPlace = sprinklerData.count

    for _, pos in ipairs(positions) do
        if self.placedCount >= maxToPlace then break end
        if not self.bot.plr:isValid() or not self.bot:isRunning() then break end

        local reached = self.bot:moveTo(pos)
        if not reached then continue end

        humanoid.Jump = true
        task.wait(0.25)
        self:waitUntilAirborne(humanoid)

        if self:waitUntilNearGround(humanoid, field, 7) then
            placeSprinklerEvent:FireServer({ Name = "Sprinkler Builder" })
            self.placedCount += 1
            self.placedField = field
        end

        task.wait(1)
    end
end
function TaskManager:getSproutAmount(sprout)
    local function cleanNumberString(str)
        local cleaned = str
            :gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
                return c:match("^[%z\1-\127]$") and c or ""
            end)
            :gsub(",", "")
        return tonumber(cleaned)
    end

    local GuiPos = sprout:FindFirstChild("GuiPos")
    if not GuiPos then return 0 end
    local Gui = GuiPos.Gui
    local Frame = Gui.Frame
    local TextLabel = Frame.TextLabel
    return cleanNumberString(TextLabel.Text)

end

function TaskManager:hasSprout()
    local SproutsFolder = workspace.Sprouts
    local bestSprout = nil
    local highestAmount = -math.huge

    for _, Sprout in pairs(SproutsFolder:GetChildren()) do
        if Sprout and Sprout:FindFirstChild("GrowthStep") then
            local amount = self:getSproutAmount(Sprout)
            if amount and amount > highestAmount then
                highestAmount = amount
                bestSprout = Sprout
            end
        end
    end
    if not bestSprout then
        return nil, 0
    end
    return bestSprout, highestAmount
end
function TaskManager:doSprout(sprout, field)
    local player = self.bot.plr
    if not sprout or not field then
        return warn("sprout or field not found: doSprout")
    end

    -- Early exit if not farming sprouts
    if not self.bot.isStart or not shared.main.Farm.autoFarmSprout then
        return false
    end

    -- Ensure player is in correct field
    if not player:isPlayerInField(field) then
        self:returnToField({ Position = field.Position, Player = player })
    end

    -- Handle sprinkler placement
    local sprinklerName, sprinklerData = player:getSprinkler()
    if self:shouldPlaceSprinkler(field, sprinklerName, sprinklerData) then
        self:placeSprinklersByPosition(field, sprinklerData)
    end

    -- Cache frequently used values
    local runService = game:GetService("RunService")
    local tokenHelper = self.bot.tokenHelper
    local bot = self.bot
    
    -- Main sprout farming loop
    while true do
        -- Check exit conditions first
        if self:getSproutAmount(sprout) <= 0 or not bot.isStart or not shared.main.Farm.autoFarmSprout then
            break
        end

        local token = tokenHelper:getBestTokenByField(field)
        local targetPosition = token and token.position or shared.helper.Field:getRandomFieldPosition(field)
        
        bot:moveTo(targetPosition, {
            timeout = 3,
            onBreak = self:createTokenBreakHandler(field, token, runService, tokenHelper)
        })

        if bot:shouldConvert() then return true end

        task.wait()
    end

    -- Optimized cleanup collection
    self:performCleanupCollection(field, tokenHelper, bot)
    
    print("done sprout")
    return true
end

function TaskManager:createTokenBreakHandler(field, currentToken, runService, tokenHelper)
    return function(triggerBreak)
        local conn
        conn = runService.Heartbeat:Connect(function()
            local newToken = tokenHelper:getBestTokenByField(field)
            if newToken ~= currentToken then
                conn:Disconnect()
                triggerBreak()
            end
        end)
    end
end

-- Separate cleanup method for better organization
function TaskManager:performCleanupCollection(field, tokenHelper, bot)
    local startTime = os.clock()
    local cleanupTimeout = 20
    
    while os.clock() - startTime < cleanupTimeout and bot.isStart and shared.main.Farm.autoFarmSprout do
        local token = tokenHelper:getBestTokenByField(field, { ignoreSkill = true })
        if token then
            bot:moveTo(token.position)
        end
        task.wait()
    end
end


function TaskManager:doFarming()
    local player = self.bot.plr
    if not player then return false end

    local currentField = self.bot.currentField
    local randomPosition = shared.helper.Field:getRandomFieldPosition(currentField)

    if self.placedField ~= currentField then
        self.placedField = nil
        self.placedCount = 0
    end

    local Sprout, SproutHealth  = self:hasSprout()
    if Sprout and shared.main.Farm.autoFarmSprout and SproutHealth > 0 then
        local sproutPos = Sprout.Position
        local field = shared.helper.Field:getFieldByPosition(sproutPos)
       if field then return self:doSprout(Sprout, field) end
    end

    if not player:isPlayerInField(currentField) then
        self.bot.token = nil
        self:returnToField({ Position = currentField.Position, Player = player })
    end

    local sprinklerName, sprinklerData = player:getSprinkler()
    if self:shouldPlaceSprinkler(currentField, sprinklerName, sprinklerData) then
        self:placeSprinklersByPosition(currentField, sprinklerData)
    end

    self.bot:moveTo(randomPosition, {
        timeout = 3,
        onBreak = function(triggerBrake)
            local tokenCheckConnection
            tokenCheckConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if self.bot.token or self.bot:shouldAvoidMonster() then
                    if tokenCheckConnection then tokenCheckConnection:Disconnect() end
                    triggerBrake()
                end
            end)
        end
    })

    return true
end

function TaskManager:useFieldBoost(toyName)
    return game:GetService("ReplicatedStorage").Events.ToyEvent:FireServer(toyName)
end

function TaskManager:convertPollen()
    if not self.bot.plr:isCapacityFull() then 
        return false 
    end

    local player = self.bot.plr
    local thread = coroutine.running()
    local bot = self.bot

    if shared.main.Equip.autoHoneyMask then
        player:equipMask("Honey Mask")
    end

    local balloonValue, balloonBlessing = shared.helper.Hive:getBalloonData()
    local blessingThreshold = shared.main.convertAtBlessing or 1
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
        local timeout = 300
        while (player.Pollen > 0 or (shared.main.autoConvertBalloon and balloonValue > 0 and balloonBlessing >= blessingThreshold))
            and bot:isConverting()
            and bot:isRunning()
            and (tick() - startTime < timeout) do

            task.wait(1)
            if shared.main.autoConvertBalloon then
                balloonValue, balloonBlessing = shared.helper.Hive:getBalloonData()
                balloonValue = balloonValue or 0
                balloonBlessing = balloonBlessing or 0
            end
        end
        if bot:isRunning() then task.wait(4) end

        player:disableWalking(false)
        player:equipMask()
        coroutine.resume(thread, true)
    end)

    return coroutine.yield()
end











return TaskManager
local WP = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HiveHelper = {}
HiveHelper.__index = HiveHelper

function HiveHelper.new()
    local self = setmetatable({}, HiveHelper)
    
    self.hive = nil
    self.CellsFolder = nil
    self.isDestroyed = false
    self._connections = {}


    return self
end

function HiveHelper:initHive()
    if self.isDestroyed then return nil end
    self.player = shared.helper.Player
    local player = self.player:getLocalPlayer()
    local character = self.player:getCharacter()
    
    if not player or not character then
        warn("Player or character not available")
        return nil
    end
    
    local honeycombsFolder = WP:FindFirstChild("Honeycombs")
    if not honeycombsFolder then
        warn("Honeycombs folder not found")
        return nil
    end
    
    local currentHive = self:getMyHive()
    if currentHive then 
        self.bees = self:getAllBees()
        return currentHive 
    end

    local closestHive, closestDist = self:_findClosestAvailableHive(honeycombsFolder)
    
    if closestHive then
        self:_claimHive(closestHive, player)
        self.bees = self:getAllBees()
        return closestHive
    else
        print("No available hives found")
        return nil
    end
end

-- Private method to find closest available hive
function HiveHelper:_findClosestAvailableHive(honeycombsFolder)
    local honeycombs = honeycombsFolder:GetChildren()
    local closestHive, closestDist = nil, math.huge
    local rootPart = self.player:getRoot()
    
    if not rootPart then
        warn("Root part not found")
        return nil, math.huge
    end
    
    for _, hive in ipairs(honeycombs) do
        if self:_isHiveAvailable(hive) then
            local base = hive:FindFirstChild("patharrow") and hive.patharrow:FindFirstChild("Base")
            if base then
                local dist = (rootPart.Position - base.Position).Magnitude
                if dist < closestDist then
                    closestHive = hive
                    closestDist = dist
                end
            end
        end
    end
    
    return closestHive, closestDist
end

-- Private method to check if hive is available
function HiveHelper:_isHiveAvailable(hive)
    local owner = hive:FindFirstChild("Owner")
    local patharrow = hive:FindFirstChild("patharrow")
    local base = patharrow and patharrow:FindFirstChild("Base")
    
    return base and (not owner or not owner.Value)
end

-- Private method to claim hive with retry logic
function HiveHelper:_claimHive(hive, player)
    if self.isDestroyed then return end
    
    local base = hive:FindFirstChild("patharrow") and hive.patharrow:FindFirstChild("Base")
    if not base then
        warn("Hive base not found")
        return
    end
    
    local basePos = base.Position + Vector3.new(0, 5, 0)
    
    self.player:tweenTo(basePos,1, function()
        if self.isDestroyed then return end
        
        task.wait(0.2)
        self:_sendClaimInput()
        
        -- Verify claim after delay
        task.delay(0.5, function()
            if self.isDestroyed then return end
            if self:_verifyHiveClaim(player) then
                print("Hive claimed successfully.")
            else
                print("Hive claim failed. Retrying...")
                self:initHive() -- Retry
            end
        end)
    end)
end

-- Private method to send claim input
function HiveHelper:_sendClaimInput()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- Private method to verify hive claim
function HiveHelper:_verifyHiveClaim(player)
    local honeycombsFolder = WP:FindFirstChild("Honeycombs")
    if not honeycombsFolder then return false end
    
    for _, hive in ipairs(honeycombsFolder:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and owner.Value == player then
            self.hive = hive
            self.hiveCells = hive.Cells
            self.CellsFolder = hive.Cells
            return true
        end
    end
    return false
end

-- Get current hive (renamed from getMyComp for clarity)
function HiveHelper:getMyHive()
    if self.isDestroyed then return nil end
    
    local player = self.player:getLocalPlayer()
    if not player then return nil end
    
    local honeycombsFolder = WP:FindFirstChild("Honeycombs")
    if not honeycombsFolder then return nil end
    
    for _, hive in ipairs(honeycombsFolder:GetChildren()) do
        local owner = hive:FindFirstChild("Owner")
        if owner and owner.Value == player then
            self.hive = hive
            self.CellsFolder = hive.Cells
            return hive
        end
    end
    return nil
end

-- Get hive position
function HiveHelper:getHivePosition()
    if self.isDestroyed then return nil end
    
    local currentHive = self:getMyHive()
    if currentHive then
        local base = currentHive:FindFirstChild("patharrow") and currentHive.patharrow:FindFirstChild("Base")
        return base and base.Position + Vector3.new(0, 2, 0)
    end
    return nil
end

-- Check if hive is valid and owned
function HiveHelper:isHiveValid()
    if self.isDestroyed then return false end
    
    local currentHive = self:getMyHive()
    return currentHive ~= nil and currentHive.Parent ~= nil
end

function HiveHelper:getBalloonData()
    if not self.hive then return 0, 0 end
    if not shared.main.autoConvertBalloon then
        return 0, 0
    end

    local balloonValue, blessingCount = 0, 0
    local nearestDistance = 20
    local hivePosition = self:getHivePosition()

    for _, instance in ipairs(workspace.Balloons.HiveBalloons:GetChildren()) do
        local root = instance:FindFirstChild("BalloonRoot")
        if not (root and root:IsA("BasePart")) then continue end

        local distance = (root.Position - hivePosition).Magnitude
        if distance > nearestDistance then continue end

        nearestDistance = distance

        local gui = instance:FindFirstChild("BalloonBody")
            and instance.BalloonBody:FindFirstChild("GuiAttach")
            and instance.BalloonBody.GuiAttach:FindFirstChild("Gui")

        if gui then
            local barLabel = gui:FindFirstChild("Bar") and gui.Bar:FindFirstChild("TextLabel")
            if barLabel then
                local rawText = barLabel.Text
                local cleanedText = rawText:gsub("[^%d]", "")
                
                if cleanedText ~= "" then
                    balloonValue = tonumber(cleanedText) or 0
                end
            end

            local blessingLabel = gui:FindFirstChild("BlessingBar") and gui.BlessingBar:FindFirstChild("TextLabel")
            if blessingLabel then
                blessingCount = tonumber(blessingLabel.Text:match("x(%d+)")) or 0
            end
        end
    end

    return balloonValue, blessingCount
end

function HiveHelper:getAllBees()
    local bees = {}
    if not self.CellsFolder then return {} end

    for _, bee in pairs(self.CellsFolder:GetChildren()) do
   
        local cellType = bee:FindFirstChild("CellType")
        if not cellType or cellType.Value == "Empty" then
            continue
        end

        local beeLevel = 0

        local levelPart = bee:FindFirstChild("LevelPart")
        if levelPart then
            local surfaceGui = levelPart:FindFirstChild("SurfaceGui")
            if surfaceGui then
                local textLabel = surfaceGui:FindFirstChild("TextLabel")
                if textLabel and tonumber(textLabel.Text) then
                    beeLevel = tonumber(textLabel.Text)
                end
            end
        end

        local Faceplate = bee:FindFirstChild("Faceplate")
        local FaceplateDecal = Faceplate and Faceplate:FindFirstChild("Decal")
        local cellID = bee:FindFirstChild("CellID")
        local cellX = bee:FindFirstChild("CellX")
        local cellY = bee:FindFirstChild("CellY")
        local GiftedCell = bee:FindFirstChild("GiftedCell")

        bees[bee] = {
            level = beeLevel,
            type = cellType.Value,
            CellID = cellID and cellID.Value or nil,
            X = cellX and cellX.Value or nil,
            Y = cellY and cellY.Value or nil,
            isGifted = GiftedCell and true or false,
            Decal = FaceplateDecal,
        }
    end

    return bees
end
function HiveHelper:getLowestLevelBee()
    local bees = self:getAllBees()
    local lowestBee = nil
    local lowestLevel = math.huge

    for beeInstance, data in pairs(bees) do
        local level = tonumber(data.level)
        if level and level < lowestLevel then
            lowestLevel = level
            lowestBee = {
                instance = beeInstance,
                level = level,
                type = data.type,
                CellID = data.CellID,
                X = data.X,
                Y = data.Y
            }
        end
    end

    return lowestBee
end

-- Get the actual hive object
function HiveHelper:getHive()
    return self.hive
end

function HiveHelper:waitUntilHiveClaimed(timeout)
    timeout = timeout or 10 
    local startTime = tick()

    while tick() - startTime < timeout do
        if self:getMyHive() then return true end
        task.wait(0.2)
    end

    warn("Timeout: Hive was not claimed in time.")
    return false
end

function HiveHelper:getCellByXY(x, y)
    if not self.CellsFolder then return nil end

    local cellName = string.format("C%d,%d", x, y)
    local cell = self.CellsFolder:FindFirstChild(cellName)

    if cell then
        return cell
    else
        return nil
    end
end


function HiveHelper:destroy()
    if self.isDestroyed then return end

    self.isDestroyed = true

    for _, connection in pairs(self._connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end

    self._connections = {}
    self.player = nil
    self.hive = nil
    self.CellsFolder = nil
    setmetatable(self, nil)
end
return HiveHelper
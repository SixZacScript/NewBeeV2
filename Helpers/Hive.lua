local WP = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local HiveHelper = {}
HiveHelper.__index = HiveHelper

function HiveHelper.new()
    local self = setmetatable({}, HiveHelper)
    self.player = shared.helper.Player
    self.hive = nil
    self.isDestroyed = false
    self._connections = {}
    
    return self
end

function HiveHelper:initHive()
    if self.isDestroyed then return nil end
    
    print("Searching for Hive...")
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
        print("claimed hive")
        return currentHive 
    end

    local closestHive, closestDist = self:_findClosestAvailableHive(honeycombsFolder)
    
    if closestHive then
        self:_claimHive(closestHive, player)
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
    
    local basePos = base.Position + Vector3.new(0, 4, 0)
    
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
        return base and base.Position
    end
    return nil
end

-- Check if hive is valid and owned
function HiveHelper:isHiveValid()
    if self.isDestroyed then return false end
    
    local currentHive = self:getMyHive()
    return currentHive ~= nil and currentHive.Parent ~= nil
end



-- Get the actual hive object
function HiveHelper:getHive()
    return self.hive
end

-- Destroy method for cleanup
function HiveHelper:destroy()
    if self.isDestroyed then return end
    
    print("Destroying HiveHelper...")
    self.isDestroyed = true
    
    -- Disconnect all connections
    for _, connection in pairs(self._connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    self._connections = {}
    
    -- Clear references
    self.player = nil
    self.hive = nil
    
    -- Clear metatable
    setmetatable(self, nil)
    
    print("HiveHelper destroyed")
end
return HiveHelper
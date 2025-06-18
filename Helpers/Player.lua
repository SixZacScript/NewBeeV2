local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PlayerHelper = {}
PlayerHelper.__index = PlayerHelper

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


function PlayerHelper.new()
    local self = setmetatable({}, PlayerHelper)
    self.player = Players.LocalPlayer
    self.player.CameraMaxZoomDistance = 150
    

    self.CoreStats = self.player:WaitForChild("CoreStats")
    self.Pollen = self.CoreStats:WaitForChild("Pollen").Value
    self.Honey = self.CoreStats:WaitForChild("Honey").Value
    self.Capacity = self.CoreStats:WaitForChild("Capacity").Value
    self.Honeycomb = {}
    self.plrStats = {}

    self:getPlayerStats()
    self:_updateCharacter()

    self._characterConnection = self.player.CharacterAdded:Connect(function()
        self:_updateCharacter()
    end)

    self.CoreStats.Pollen.Changed:Connect(function(val) self.Pollen = val end)

    self.CoreStats.Capacity.Changed:Connect(
        function(val) self.Capacity = val end)

    return self
end
function PlayerHelper:isCapacityFull() return self.Pollen >= self.Capacity end
function PlayerHelper:updateStats()
    if self.character and self.humanoid then
        self.humanoid.WalkSpeed = shared.main.WalkSpeed
        self.humanoid.JumpPower = shared.main.JumpPower
    end
end
function PlayerHelper:_updateCharacter()
    self.character = self.player.Character
    if self.character then
        self.humanoid = self.character:WaitForChild("Humanoid")
        self.rootPart = self.character:WaitForChild("HumanoidRootPart")
        self.defaultWalkSpeed = self.humanoid.WalkSpeed
        self.defaultJump = self.humanoid.JumpPower

        if self._enforceStatsConnection then
            self._enforceStatsConnection:Disconnect()
        end
        self._enforceStatsConnection = RunService.Heartbeat:Connect(function()
            if self.humanoid then
                if self.humanoid.JumpPower ~= shared.main.JumpPower then
                    self.humanoid.JumpPower = shared.main.JumpPower
                end
                if self.humanoid.WalkSpeed ~= shared.main.WalkSpeed then
                    self.humanoid.WalkSpeed = shared.main.WalkSpeed
                end
            end
        end)

        local defaultProps = PhysicalProperties.new(2, 1, 0.8, 0.1, 0.2)
        self.rootPart.CustomPhysicalProperties = defaultProps

        self:updateStats()
    else
        self.humanoid = nil
        self.rootPart = nil
    end
end

function PlayerHelper:getLocalPlayer() return self.player end

function PlayerHelper:getCharacter() return self.character end

function PlayerHelper:getHumanoid() return self.humanoid end

function PlayerHelper:isValid()
    return self.player and self.character and self.character.Parent ~= nil and
               self.humanoid and self.humanoid.Health > 0 and self.rootPart and
               self.rootPart.Parent ~= nil
end

function PlayerHelper:stopMoving()
    if not self:isValid() then return end

    if self.currentTween then
        self.currentTween:Cancel()
        self.currentTween = nil
    end

    if self.tweenMonitorConnection then
        self.tweenMonitorConnection:Disconnect()
        self.tweenMonitorConnection = nil
    end
    if #self.blockedParts > 0 then
        for _, part in ipairs(self.blockedParts) do
            if part and part:IsDescendantOf(workspace) then
                part.CanCollide = true
            end
        end
        self.blockedParts = {}
    end
    self.humanoid:Move(Vector3.zero)
    self.humanoid:MoveTo(self.rootPart.Position)
    self:setCharacterAnchored(false)
    self:disableWalking(false)
end


function PlayerHelper:setCharacterAnchored(state)
    if not self:isValid() then return end
    self.rootPart.Anchored = state
end

function PlayerHelper:disableWalking(disable)
    local humanoid = self.humanoid
    if humanoid then
        humanoid.WalkSpeed = disable and 0 or shared.main.WalkSpeed
        humanoid.JumpPower = disable and 0 or shared.main.JumpPower
    end

    if self.player == game.Players.LocalPlayer then
        local ContextActionService = game:GetService("ContextActionService")
        if disable then
            ContextActionService:BindAction("DisableMovement", function()
                return Enum.ContextActionResult.Sink
            end, false, unpack(Enum.PlayerActions:GetEnumItems()))
        else
            ContextActionService:UnbindAction("DisableMovement")
        end
    end
end

function PlayerHelper:getDistanceByPos(pos)
    return (self.rootPart.Position - pos).Magnitude or math.huge
end

function PlayerHelper:tweenTo(targetPosition, duration, callback)
    if not self:isValid() then return false end

    self:setCharacterAnchored(true)

    if self.activeTween then
        self.activeTween:Cancel()
        self.activeTween = nil
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {self.character}
    rayParams.IgnoreWater = true

    self.blockedParts = {}
    local direction = targetPosition - self.rootPart.Position
    local rayResult = workspace:Raycast(self.rootPart.Position, direction, rayParams)

    if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
        rayResult.Instance.CanCollide = false
        table.insert(self.blockedParts, rayResult.Instance)
    end

    -- Create Tween
    local tween = TweenService:Create(self.rootPart, TweenInfo.new(
        duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut
    ), {CFrame = CFrame.new(targetPosition)})

    self.activeTween = tween
    local completed = false

    local function restoreBlockedParts()
        for _, part in ipairs(self.blockedParts) do
            if part and part:IsDescendantOf(workspace) then
                part.CanCollide = true
            end
        end
        self.blockedParts = {}
    end

    local function cleanup()
        if self.tweenMonitorConnection then
            self.tweenMonitorConnection:Disconnect()
            self.tweenMonitorConnection = nil
        end
    end

    self.tweenMonitorConnection = RunService.Heartbeat:Connect(function()
        if completed then return end
        if not self:isValid() then
            completed = true
            tween:Cancel()
            self:setCharacterAnchored(false)
            cleanup()
            restoreBlockedParts()
        end
    end)

    tween.Completed:Connect(function()
        if completed then return end
        completed = true
        self:setCharacterAnchored(false)
        cleanup()
        restoreBlockedParts()
        self.activeTween = nil
        if callback then callback() end
    end)

    tween:Play()
    return true
end


function PlayerHelper:getRoot() return self.rootPart end

function PlayerHelper:isPlayerInField(field)
    if not field or not field:IsA("BasePart") or not self.rootPart then
        return false
    end

    local fieldCenter = Vector3.new(field.Position.X, 0, field.Position.Z)
    local playerPos = Vector3.new(self.rootPart.Position.X, 0, self.rootPart.Position.Z)
    local distance = (fieldCenter - playerPos).Magnitude

    local fieldRadius = math.max(field.Size.X, field.Size.Z) / 2 + 5 
    return distance <= fieldRadius
end

function PlayerHelper:equipMask(mask)
    if not mask and shared.main.Equip.defaultMask then mask = shared.main.Equip.defaultMask end
    if table.find(self.plrStats.Accessories, mask) and mask then
        local Event = game:GetService("ReplicatedStorage").Events.ItemPackageEvent
        Event:InvokeServer("Equip", {Category = "Accessory", Type = mask})
    end
end
function PlayerHelper:getSprinkler()
    if not self.EquippedSprinkler then return end
    local sprinklers = {
        ['Basic Sprinkler'] = {count = 1, radius = 7, power = 7, rate = 5},
        ['Silver Soakers'] = {count = 2, radius = 7, power = 7, rate = 4.5},
        ['Golden Gushers'] = {count = 3, radius = 8, power = 8, rate = 4.5},
        ['Diamond Drenchers'] = {count = 4, radius = 8, power = 9, rate = 4},
        ['The Supreme Saturator'] =  {count = 1, radius = 16, power = 10, rate = 1},
    }

    return self.EquippedSprinkler, sprinklers[self.EquippedSprinkler] 
end
function PlayerHelper:getPlayerStats()
    local success, plrStats = pcall(function()
        local RetrievePlayerStats = Rep.Events.RetrievePlayerStats
        return RetrievePlayerStats:InvokeServer()
    end)
    if not success then
        warn("Failed to retrieve player stats:", plrStats)
        return {}
    end
    self.plrStats = plrStats
    self.Honeycomb = plrStats.Honeycomb
    self.Accessories = plrStats.Accessories or {}
    self.EquippedSprinkler = plrStats.EquippedSprinkler

    writefile("playerStats.json", HttpService:JSONEncode(plrStats))
    return self.plrStats
end

function PlayerHelper:getPlayerMasks()
    local masks = {
        "Helmet", "Propeller Hat", "Beekeeper's Mask",
        "Bubble Mask", "Fire Mask", "Honey Mask",
        "Diamond Mask", "Gummy Mask", "Demon Mask"
    }

    local playerMasks = {}

    if not self or type(self) ~= "table" or not self.Accessories then
        warn("PlayerHelper:getPlayerMasks - self.Accessories is nil or invalid")
        return playerMasks
    end

    for _, mask in pairs(self.Accessories) do
        if typeof(mask) == "string" and table.find(masks, mask) then
            table.insert(playerMasks, mask)
        end
    end

    return playerMasks
end

function PlayerHelper:getMaskIndex(maskName)
    local playerMasks = self:getPlayerMasks()
    for i, name in ipairs(playerMasks) do
        if name == maskName then
            return i
        end
    end
    return nil 
end

function PlayerHelper:getEqupipedMask()
    local plrStats = self:getPlayerStats()
    local EquippedAccessories = plrStats.EquippedAccessories

    return EquippedAccessories.Hat
    
end

function PlayerHelper:destroy()
    if self._enforceStatsConnection then
        self._enforceStatsConnection:Disconnect()
        self._enforceStatsConnection = nil
    end

    if self._characterConnection then
        self._characterConnection:Disconnect()
        self._characterConnection = nil
    end

    self.Honeycomb = nil
    self.plrStats = nil
    self.player = nil
    self.character = nil
    self.humanoid = nil
    self.rootPart = nil
end

return PlayerHelper

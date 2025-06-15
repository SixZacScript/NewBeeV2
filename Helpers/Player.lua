local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local PlayerHelper = {}
PlayerHelper.__index = PlayerHelper

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

function PlayerHelper.new()
    local self = setmetatable({}, PlayerHelper)
    self.player = Players.LocalPlayer

    self.CoreStats = self.player:WaitForChild("CoreStats")
    self.Pollen = self.CoreStats:WaitForChild("Pollen").Value
    self.Honey = self.CoreStats:WaitForChild("Honey").Value
    self.Capacity = self.CoreStats:WaitForChild("Capacity").Value
    self.Honeycomb = {}
    self.plrStats = {}

    self:_updateCharacter()

    self._characterConnection = self.player.CharacterAdded:Connect(function()
        self:_updateCharacter()
    end)
    
    self.CoreStats.Pollen.Changed:Connect(function(val)
        self.Pollen = val
    end)

    self.CoreStats.Capacity.Changed:Connect(function(val)
        self.Capacity = val
    end)

    return self
end
function PlayerHelper:isCapacityFull()
    return self.Pollen >= self.Capacity
end
function PlayerHelper:updateStats()
    if self.character and self.humanoid then
        self.humanoid.WalkSpeed =  shared.main.WalkSpeed
        self.humanoid.JumpPower =  shared.main.JumpPower
    end
end
function PlayerHelper:_updateCharacter()
    self.character = self.player.Character
    if self.character then
        self.humanoid = self.character:WaitForChild("Humanoid")
        self.rootPart = self.character:WaitForChild("HumanoidRootPart")
        self.defaultWalkSpeed = self.humanoid.WalkSpeed
        self.defaultJump = self.humanoid.JumpPower

        if self._enforceStatsConnection then self._enforceStatsConnection:Disconnect() end
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



function PlayerHelper:getLocalPlayer()
    return self.player
end

function PlayerHelper:getCharacter()
    return self.character
end

function PlayerHelper:getHumanoid()
    return self.humanoid
end

function PlayerHelper:isValid()
    return self.player 
        and self.character 
        and self.character.Parent ~= nil 
        and self.humanoid 
        and self.humanoid.Health > 0
        and self.rootPart
        and self.rootPart.Parent ~= nil
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

    self.humanoid:Move(Vector3.zero)
    self.humanoid:MoveTo(self.rootPart.Position)
    self:setCharacterAnchored(false)
    self:disableWalking(false)
end

function PlayerHelper:moveTo(position, callback)
    if not self:isValid() then
        return false
    end

    self.humanoid:MoveTo(position)

    if callback then
        local connection
        connection = self.humanoid.MoveToFinished:Connect(function(reached)
            connection:Disconnect()
            return callback(reached)
        end)
    end

    return true
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
            ContextActionService:BindAction("DisableMovement", function() return Enum.ContextActionResult.Sink end, false,
                unpack(Enum.PlayerActions:GetEnumItems()))
        else
            ContextActionService:UnbindAction("DisableMovement")
        end
    end
end

function PlayerHelper:tweenTo(targetPosition, duration, callback)
    if not self:isValid() then return false end

    self:setCharacterAnchored(true)
    local startPosition = self.rootPart.Position
    local totalDistance = (targetPosition - startPosition).Magnitude
    local speed = totalDistance / duration


    if self.tweenMonitorConnection then
        self.tweenMonitorConnection:Disconnect()
        self.tweenMonitorConnection = nil
    end

    local completed = false
    self.tweenMonitorConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if completed then return end
        if not self:isValid() then
            completed = true
            self:setCharacterAnchored(false)
            self.tweenMonitorConnection:Disconnect()
            self.tweenMonitorConnection = nil
            return
        end

        local currentPosition = self.rootPart.Position
        local direction = (targetPosition - currentPosition)
        local distanceLeft = direction.Magnitude

        if distanceLeft <= 0.1 then
            completed = true
            self.rootPart.CFrame = CFrame.new(targetPosition)
            self:setCharacterAnchored(false)
            self.tweenMonitorConnection:Disconnect()
            self.tweenMonitorConnection = nil
            if callback then callback() end
            return
        end

        local moveStep = math.min(speed * deltaTime, distanceLeft)
        local moveDirection = direction.Unit * moveStep
        self.rootPart.CFrame = CFrame.new(currentPosition + moveDirection)
    end)

    return true
end


function PlayerHelper:getPosition()
    if self:isValid() then
        return self.rootPart.Position
    end
    return nil
end

function PlayerHelper:getCFrame()
    if self:isValid() then
        return self.rootPart.CFrame
    end
    return nil
end

function PlayerHelper:getRoot()
    return self.rootPart
end

function PlayerHelper:isPlayerInField(field)
    if not field or not field:IsA("BasePart") or not self.rootPart then
        return false
    end

    local fieldCenter = Vector3.new(field.Position.X, 0, field.Position.Z)
    local playerPos = Vector3.new(self.rootPart.Position.X, 0, self.rootPart.Position.Z)
    local distance = (fieldCenter - playerPos).Magnitude

    local fieldRadius = math.max(field.Size.X, field.Size.Z) / 2
    return distance <= fieldRadius
end



function PlayerHelper:debugVisual(pos, color)
    local partColor = color or Color3.fromRGB(255, 0, 0)

    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = pos
    part.Anchored = true
    part.CanCollide = false
    part.Color = partColor
    part.Material = Enum.Material.Neon
    part.Name = "MoveToPart"
    part.Parent = workspace.Terrain

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MoveToBillboard"
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = part
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 251, 0)
    label.TextScaled = true
    label.Text = ""
    label.Parent = billboard

    -- Create beam line
    local a0 = Instance.new("Attachment")
    a0.Name = "StartAttachment"
    a0.Parent = self.rootPart

    local a1 = Instance.new("Attachment")
    a1.Name = "EndAttachment"
    a1.Parent = part

    local beam = Instance.new("Beam")
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Width0 = 0.15
    beam.Width1 = 0.15
    beam.FaceCamera = true
    beam.Color = ColorSequence.new(partColor)
    beam.LightEmission = 1
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = a0

    task.spawn(function()
        while part and part.Parent and self:isValid() do
            local distance = (self.rootPart.Position - part.Position).Magnitude
            label.Text = string.format("%.1f studs", distance)
            task.wait(0.1)
        end
    end)
    local distance = (self.rootPart.Position - pos).Magnitude
    local speed = self.humanoid and self.humanoid.WalkSpeed or 16
    local lifetime = math.clamp(distance / speed + 2, 2, 10)
    Debris:AddItem(part, lifetime)

    return part
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

    writefile("playerStats.json",HttpService:JSONEncode(plrStats))
    return self.plrStats
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
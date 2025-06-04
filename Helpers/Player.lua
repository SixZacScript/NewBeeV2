local PlayerHelper = {}
PlayerHelper.__index = PlayerHelper

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

function PlayerHelper.new()
    local self = setmetatable({}, PlayerHelper)
    self.player = Players.LocalPlayer

    self.CoreStats = self.player:WaitForChild("CoreStats")
    self.Pollen = self.CoreStats:WaitForChild("Pollen").Value
    self.Honey = self.CoreStats:WaitForChild("Honey").Value
    self.Capacity = self.CoreStats:WaitForChild("Capacity").Value

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
function  PlayerHelper:isCapacityFull()
    return self.Pollen >= self.Capacity
end
function PlayerHelper:_updateCharacter()
    self.character = self.player.Character
    if self.character then
        self.humanoid = self.character:WaitForChild("Humanoid")
        self.rootPart = self.character:WaitForChild("HumanoidRootPart")
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


    self.humanoid:Move(Vector3.zero)
    self.humanoid:MoveTo(self.rootPart.Position)
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



function PlayerHelper:tweenTo(position, duration, callback)
    if not self:isValid() then
        return false
    end

    local tweenInfo = TweenInfo.new(duration or 1)
    local tween = TweenService:Create(self.rootPart, tweenInfo, {CFrame = CFrame.new(position)})

    if callback then
        tween.Completed:Connect(callback)
    end

    tween:Play()
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
    if not field or not field:IsA("BasePart") then return false end
    local distance = (field.Position - self.rootPart.Position).Magnitude
    local fieldRadius = field.Size.Magnitude / 2
    return distance <= fieldRadius
end

function PlayerHelper:destroy()
    if self._characterConnection then
        self._characterConnection:Disconnect()
        self._characterConnection = nil
    end

    self.player = nil
    self.character = nil
    self.humanoid = nil
    self.rootPart = nil
end

return PlayerHelper
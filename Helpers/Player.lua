local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlanters = require(Rep.LocalPlanters)

local PlanterGrowthTimes = {
    ["Paper Planter"]        = 1  * 3600,   -- 1 h
    ["Ticket Planter"]       = 2  * 3600,   -- 2 h
    ["Plastic Planter"]      = 2  * 3600,   -- 2 h
    ["Sticker Planter"]      = 3  * 3600,   -- 3 h
    ["Festive Planter"]      = 4  * 3600,   -- 4 h
    ["Candy Planter"]        = 4  * 3600,   -- 4 h
    ["Red Clay Planter"]    = 6  * 3600,   -- 6 h (4.5 h if red‑field bonus applies)
    ["Blue Clay Planter"]    = 6  * 3600,   -- 6 h (4.5 h if blue‑field bonus applies)
    ["Tacky Planter"]        = 6  * 3600,   -- 6 h (base) – grows faster in starter zone
    ["Pesticide Planter"]    = 10 * 3600,   -- 10 h
    ["Heat‑Treated Planter"] = 12 * 3600,   -- 12 h
    ["Hydroponic Planter"]   = 12 * 3600,   -- 12 h
    ["Petal Planter"]        = 14 * 3600,   -- 14 h
    ["Planter Of Plenty"]    = 16 * 3600,   -- 16 h
}


local PlayerHelper = {}
PlayerHelper.__index = PlayerHelper

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


function PlayerHelper.new()
    local self = setmetatable({}, PlayerHelper)
    self.player = Players.LocalPlayer
    self.player.CameraMaxZoomDistance = 300
    

    self.CoreStats = self.player:WaitForChild("CoreStats")
    self.Pollen = self.CoreStats:WaitForChild("Pollen").Value
    self.Honey = self.CoreStats:WaitForChild("Honey").Value
    self.Capacity = self.CoreStats:WaitForChild("Capacity").Value
    self.Honeycomb = {}
    self.plrStats = {}
    self.harvestedPlanter = {}

    self:getPlayerStats()
    self:_updateCharacter()

    self._characterConnection = self.player.CharacterAdded:Connect(function()
        self:_updateCharacter()
    end)

    self.CoreStats.Pollen.Changed:Connect(function(val) self.Pollen = val end)
    self.CoreStats.Capacity.Changed:Connect(function(val) self.Capacity = val end)


    self:setupPlanterListener()
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
function PlayerHelper:getPosition()
    return self.rootPart.Position
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


function PlayerHelper:formatTime(seconds)
    seconds = math.floor(seconds or 0)
    local h  = math.floor(seconds / 3600)
    local m  = math.floor((seconds % 3600) / 60)
    local s  = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
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

function PlayerHelper:isStarterZone(fieldName)
    local starterZones = {
        ["Sunflower Field"] = true,
        ["Dandelion Field"] = true,
        ["Mushroom Field"] = true,
        ["Clover Field"] = true
    }
    return starterZones[fieldName] or false
end

function PlayerHelper:getPlanterMaxGrowthTime(planter)
    local planterType = self:getPlanterFullName(planter.Type)
    local fieldName = shared.helper.Field:getOriginalFieldName(planter.Field)
    local baseTime = PlanterGrowthTimes[planterType]
    if not baseTime then return nil end

    local fieldType = shared.helper.Field:getFieldTypeByName(fieldName)
    if planterType == "Red Clay Planter" and fieldType == "Red" then
        return baseTime * 0.75 
    elseif planterType == "Blue Clay Planter" and fieldType == "Blue" then
        return baseTime * 0.75 
    elseif planterType == "Tacky Planter" and self:isStarterZone(fieldName) then
        return baseTime * 0.5 
    end

    return baseTime
end


function PlayerHelper:getPlanterRemainingTime(planter)
    local total = self:getPlanterMaxGrowthTime(planter)
    if not total then return nil end
    return math.max(0, total * (1 - planter.GrowthPercent))
end
function PlayerHelper:getPlanterFullName(shortName)
    local fullNameMap = {
        ['Paper']        = "Paper Planter",
        ['Ticket']       = "Ticket Planter",
        ['Sticker']      = "Sticker Planter",
        ['Festive']      = "Festive Planter",
        ['Plastic']      = "Plastic Planter",
        ['Candy']        = "Candy Planter",
        ["Red Clay"] = "Red Clay Planter",
        ["Blue Clay"]= "Blue Clay Planter",
        ['Tacky']        = "Tacky Planter",
        ['Pesticide']    = "Pesticide Planter",
        ["Heat-Treated"] = "Heat‑Treated Planter",
        ['Hydroponic']   = "Hydroponic Planter",
        ['Petal']        = "Petal Planter",
        ["Planter Of Plenty"] = "Planter Of Plenty"
    }

    return fullNameMap[shortName] or (shortName .. " Planter")
end

function PlayerHelper:getCanHarvestPlanter()
    local allPlanters = self:getActivePlanter()

    for _, planter in ipairs(allPlanters) do
        if planter.canHarvest then return planter end
    end

    return nil
end


function PlayerHelper:getPlanterToPlace()
    local allPlanters = self:getActivePlanter()
    local slots = shared.main.Planter.Slots

    for _, slot in ipairs(slots) do
        if slot.PlanterType == "None" then continue end
        local found = false
        for _, planter in ipairs(allPlanters) do
            if planter.Type == slot.PlanterType then
                found = true
                break
            end
        end

        if not found then
            return slot
        end
    end

    return nil
end

function PlayerHelper:getActivePlanter()
    local myPlanters = debug.getupvalue(LocalPlanters.LoadPlanter, 4)
    local Planters = {}
    local slotConfig = shared.main.Planter.Slots

    for _, planter in ipairs(myPlanters) do
        if planter.Owner.Name ~= self.player.Name then continue end
        local percent100 = planter.GrowthPercent * 100
        table.insert(Planters, {
            Type = planter.Type,
            Position = planter.Pos,
            ActorID = planter.ActorID,
            GrowthPercent = planter.GrowthPercent,
            percent100 = percent100,
            canHarvest = false,
        })
       
    end

    -- ตรวจสอบว่าควร harvest ไหม
    for _, slot in ipairs(slotConfig) do
        if slot.PlanterType == "None" then continue end
        for _, planter in ipairs(Planters) do
            if slot.PlanterType == planter.Type then
                if planter.percent100 >= slot.HarvestAt then
                    planter.canHarvest = true
                end
                planter.Field = slot.Field
                slot.Placed = true
                break
            else
                slot.Placed = false
            end
        end
    end

    shared.main.Planter.Actives = Planters
    return Planters
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

function PlayerHelper:equipMask(mask)
    if not mask and shared.main.Equip.defaultMask then mask = shared.main.Equip.defaultMask end
    if table.find(self.plrStats.Accessories, mask) and mask then
        local Event = game:GetService("ReplicatedStorage").Events.ItemPackageEvent
        Event:InvokeServer("Equip", {Category = "Accessory", Type = mask})
    end
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

function PlayerHelper:setupPlanterListener()
    task.spawn(function()
        while true do
            local active = self:getActivePlanter()
            local Slots = shared.main.Planter.Slots or {}

            if shared.Fluent then  
                for i = 1, 3 do
                    local slotConfig = Slots[i]
                    local slot = shared.Fluent["activePlanterSlot" .. i]

                    if slot then
                        if slot.PlanterType == "None" then continue end
                        local found = false

                        for _, planter in ipairs(active) do
                            local growthPercent = math.floor(planter.GrowthPercent * 1000) * 0.1

                            if slotConfig.PlanterType == planter.Type then
                                found = true
                                local statusText = string.format(
                                    "%s | Growth: %.1f%%",
                                    planter.Type,
                                    growthPercent
                                )

                                if planter.canHarvest then
                                    statusText = "✅ Ready | " .. statusText
                                else
                                    statusText = "❌ Not ready | " .. statusText
                                end
                                local remainingSec = self:getPlanterRemainingTime(planter)
                                local timeStr = remainingSec and self:formatTime(remainingSec) or "--:--:--"
                                statusText ..= string.format(" | ⏱ %s", timeStr)

                                slot:SetDesc(statusText)
                            end
                        end

                        if not found then
                            slot:SetDesc("No planter is currently placed.")
                        end
                    end
                end
            end

            task.wait(1)
        end
    end)
end



function PlayerHelper:getEstimatedConvertTime()
    if not self.CoreStats then return nil end

    local pollen = self.CoreStats:FindFirstChild("Pollen") and self.CoreStats.Pollen.Value or 0
    local stats = self.plrStats.ModifierCaches
    if not stats then return nil end

    local baseRate = (stats.BaseConversionRate and stats.BaseConversionRate._) or 50
    local convAtHive = (stats.ConversionAtHive and stats.ConversionAtHive._) or 1
    local honeyAtHive = (stats.HoneyAtHive and stats.HoneyAtHive._) or 1

    local convertRate = baseRate * convAtHive * honeyAtHive
    if convertRate <= 0 then return math.huge end

    local seconds = pollen / convertRate
    return math.floor(seconds + 0.5) -- round to nearest second
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

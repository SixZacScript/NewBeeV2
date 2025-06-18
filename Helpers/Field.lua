local FieldHelper = {}
FieldHelper.__index = FieldHelper

local HttpService = game:GetService('HttpService')
local WP = game:GetService('Workspace')
local FlowerZones = WP:FindFirstChild('FlowerZones')

-- Constants
local FIELD_TYPE = {
    WHITE = "White",
    RED = "Red",
    BLUE = "Blue",
}

local FIELD_DATA = {
    {name = "Sunflower Field", emoji = "🌻", type = FIELD_TYPE.WHITE, bestField = false},
    {name = "Dandelion Field", emoji = "🌼", type = FIELD_TYPE.WHITE, bestField = true},
    {name = "Mushroom Field", emoji = "🍄", type = FIELD_TYPE.RED, bestField = true},
    {name = "Clover Field", emoji = "☘️", type = FIELD_TYPE.BLUE, bestField = false},
    {name = "Blue Flower Field", emoji = "💠", type = FIELD_TYPE.BLUE, bestField = true},
    {name = "Spider Field", emoji = "🕷️", type = FIELD_TYPE.WHITE, bestField = false},
    {name = "Strawberry Field", emoji = "🍓", type = FIELD_TYPE.RED, bestField = false},
    {name = "Bamboo Field", emoji = "🎍", type = FIELD_TYPE.BLUE, bestField = false},
    {name = "Pineapple Patch", emoji = "🍍", type = FIELD_TYPE.WHITE, bestField = false},
    {name = "Pumpkin Patch", emoji = "🎃", type = FIELD_TYPE.WHITE, bestField = false},
    {name = "Cactus Field", emoji = "🌵", type = FIELD_TYPE.RED, bestField = false},
    {name = "Pine Tree Forest", emoji = "🌳", type = FIELD_TYPE.BLUE, bestField = false},
    {name = "Ant Field", emoji = "🐜", type = FIELD_TYPE.RED, bestField = false},
    {name = "Rose Field", emoji = "🌹", type = FIELD_TYPE.RED, bestField = false},
    {name = "Stump Field", emoji = "🐌", type = FIELD_TYPE.BLUE, bestField = false},
    {name = "Mountain Top Field", emoji = "⛰️", type = FIELD_TYPE.BLUE, bestField = false},
    {name = "Coconut Field", emoji = "🌴", type = FIELD_TYPE.WHITE, bestField = false},
    {name = "Pepper Patch", emoji = "🌶️", type = FIELD_TYPE.RED, bestField = false},
}

-- Pre-compute field type order for consistent iteration
local FIELD_TYPE_ORDER = {FIELD_TYPE.WHITE, FIELD_TYPE.BLUE, FIELD_TYPE.RED}

-- Optimization constants
local RANDOM_POS_CONFIG = {
    PADDING = 15,
    MIN_DISTANCE = 15,
    MAX_DISTANCE = 50,
    MAX_DISTANCE_FROM_CENTER = 30,
    MAX_ATTEMPTS = 50,
    FALLBACK_DISTANCE = 10,
    MIN_FALLBACK_DISTANCE = 3,
    SAFE_MOVE_DISTANCE = 3,
    ANGLE_STEP = 30
}

function FieldHelper.new()
    local self = setmetatable({}, FieldHelper)
    
    -- Pre-compute maps for O(1) lookups
    self.fieldMap = {}
    self.displayNameToFieldMap = {}
    
    for i, field in ipairs(FIELD_DATA) do
        local displayName = field.emoji .. field.name
        
        self.fieldMap[field.name] = {
            emoji = field.emoji, 
            type = field.type, 
            index = i
        }
        self.displayNameToFieldMap[displayName] = field.name
    end
    
    self.fieldOrder = FIELD_DATA
    self.currentField = "Sunflower Field"
    self.fieldPart = FlowerZones:FindFirstChild("Sunflower Field")
    
    return self
end

function FieldHelper:getField(fieldName)
    return FlowerZones:FindFirstChild(fieldName or self.currentField)
end

function FieldHelper:getAllFieldParts()
    local parts = {}
    for _, field in ipairs(self.fieldOrder) do
        local part = self:getField(field.name)
        if part then
            parts[#parts + 1] = part
        end
    end
    return parts
end

function FieldHelper:getFieldPosition(fieldName)
    local field = self:getField(fieldName)
    return field and (field.Position + Vector3.new(0, 4, 0)) or Vector3.new()
end

function FieldHelper:getFieldEmoji(fieldName)
    local data = self.fieldMap[fieldName]
    return data and data.emoji
end

function FieldHelper:getFieldDisplayName(fieldName)
    local data = self.fieldMap[fieldName]
    return data and (data.emoji .. fieldName) or fieldName
end

function FieldHelper:getOriginalFieldName(displayName)
    return self.displayNameToFieldMap[displayName]
end

function FieldHelper:getAllFieldDisplayNames()
    local displayNames = {}
    for _, field in ipairs(self.fieldOrder) do
        displayNames[#displayNames + 1] = field.emoji .. field.name
    end
    return displayNames
end

function FieldHelper:getAllFields()
    local fields = {}
    for _, field in ipairs(self.fieldOrder) do
        fields[#fields + 1] = field.name
    end
    return fields
end

function FieldHelper:SetCurrentField(displayName)
    local fieldName = self:getOriginalFieldName(displayName)
    if fieldName then
        self.currentField = fieldName
        self.fieldPart = FlowerZones:FindFirstChild(fieldName)
    end
    return self.currentField
end

-- Optimized random position generation with better structure
function FieldHelper:getRandomFieldPosition(targetField)
    local player = shared.helper.Player
    if not targetField then 
        return player.rootPart.Position 
    end

    local currentPos = player.rootPart.Position
    local playerLookDirection = player.rootPart.CFrame.LookVector
    local size, center = targetField.Size, targetField.Position
    
    local config = RANDOM_POS_CONFIG
    
    -- Pre-calculate field boundaries
    local bounds = {
        minX = center.X - size.X/2 + config.PADDING,
        maxX = center.X + size.X/2 - config.PADDING,
        minZ = center.Z - size.Z/2 + config.PADDING,
        maxZ = center.Z + size.Z/2 - config.PADDING
    }

    -- Try to find valid position
    for attempt = 1, config.MAX_ATTEMPTS do
        local angleOffset = math.random(-90, 90) * math.pi / 180
        local cos_angle, sin_angle = math.cos(angleOffset), math.sin(angleOffset)
        
        local forwardDir = Vector3.new(
            playerLookDirection.X * cos_angle - playerLookDirection.Z * sin_angle,
            0,
            playerLookDirection.X * sin_angle + playerLookDirection.Z * cos_angle
        )
        
        local maxDistanceInDirection = self:calculateMaxDistance(currentPos, forwardDir, bounds, config.MAX_DISTANCE)
        
        if maxDistanceInDirection >= config.MIN_DISTANCE then
            local distance = math.random(config.MIN_DISTANCE, math.floor(maxDistanceInDirection))
            local newPos = self:constrainPosition(currentPos + forwardDir * distance, center, bounds, config.MAX_DISTANCE_FROM_CENTER, currentPos.Y)
            
            -- Validate position
            local directionToNewPos = (newPos - currentPos).Unit
            local dotProduct = playerLookDirection:Dot(directionToNewPos)
            
            if dotProduct >= 0 and (newPos - currentPos).Magnitude >= config.MIN_DISTANCE then
                return newPos
            end
        end
    end

    -- Optimized fallback
    return self:getFallbackPosition(currentPos, playerLookDirection, center, bounds, config)
end

-- Helper method to calculate maximum distance in a direction
function FieldHelper:calculateMaxDistance(currentPos, direction, bounds, maxDistance)
    local maxDist = maxDistance
    
    if direction.X > 0 then
        maxDist = math.min(maxDist, (bounds.maxX - currentPos.X) / direction.X)
    elseif direction.X < 0 then
        maxDist = math.min(maxDist, (bounds.minX - currentPos.X) / direction.X)
    end
    
    if direction.Z > 0 then
        maxDist = math.min(maxDist, (bounds.maxZ - currentPos.Z) / direction.Z)
    elseif direction.Z < 0 then
        maxDist = math.min(maxDist, (bounds.minZ - currentPos.Z) / direction.Z)
    end
    
    return math.max(0, maxDist)
end

-- Helper method to constrain position within bounds and distance from center
function FieldHelper:constrainPosition(pos, center, bounds, maxDistFromCenter, y)
    -- Constrain to center distance
    local distFromCenter = (pos - center).Magnitude
    if distFromCenter > maxDistFromCenter then
        local dirToPos = (pos - center).Unit
        pos = center + dirToPos * maxDistFromCenter
    end
    
    -- Constrain to bounds
    return Vector3.new(
        math.clamp(pos.X, bounds.minX, bounds.maxX),
        y,
        math.clamp(pos.Z, bounds.minZ, bounds.maxZ)
    )
end

-- Optimized fallback position calculation
function FieldHelper:getFallbackPosition(currentPos, lookDirection, center, bounds, config)
    local fallbackPositions = {}
    
    for angle = -90, 90, config.ANGLE_STEP do
        local angleRad = angle * math.pi / 180
        local cos_angle, sin_angle = math.cos(angleRad), math.sin(angleRad)
        
        local testDir = Vector3.new(
            lookDirection.X * cos_angle - lookDirection.Z * sin_angle,
            0,
            lookDirection.X * sin_angle + lookDirection.Z * cos_angle
        )
        
        local maxDist = self:calculateMaxDistance(currentPos, testDir, bounds, config.FALLBACK_DISTANCE)
        
        if maxDist > config.MIN_FALLBACK_DISTANCE then
            local fallbackPos = self:constrainPosition(
                currentPos + testDir * maxDist, 
                center, 
                bounds, 
                config.MAX_DISTANCE_FROM_CENTER, 
                currentPos.Y
            )
            fallbackPositions[#fallbackPositions + 1] = fallbackPos
        end
    end
    
    if #fallbackPositions > 0 then
        return fallbackPositions[math.random(1, #fallbackPositions)]
    end
    
    -- Ultimate fallback
    local towardCenter = (center - currentPos).Unit * config.SAFE_MOVE_DISTANCE
    return self:constrainPosition(currentPos + towardCenter, center, bounds, config.MAX_DISTANCE_FROM_CENTER, currentPos.Y)
end

function FieldHelper:setBestFieldByFieldType(targetFieldType, targetField)
    self:resetBestFieldForType(targetFieldType)
    
    -- Use the fieldName directly instead of display name lookup
    local fieldName = self:getOriginalFieldName(targetField)
    if not fieldName then return end
    
    for _, field in ipairs(self.fieldOrder) do
        if field.type == targetFieldType and field.name == fieldName then
            field.bestField = true
            break
        end
    end
end

function FieldHelper:resetBestFieldForType(targetFieldType)
    for _, field in ipairs(self.fieldOrder) do
        if field.type == targetFieldType then
            field.bestField = false
        end
    end
end

function FieldHelper:getBestFieldByType(fieldType)
    for _, field in ipairs(self.fieldOrder) do
        if field.bestField and field.type == fieldType then
            return self:getField(field.name)
        end
    end
    return nil
end

function FieldHelper:getBestFieldIndexesByType()
    local bestFieldIndexesMap = {}
    
    -- Single pass to find best fields
    for index, field in ipairs(self.fieldOrder) do
        if field.bestField then
            bestFieldIndexesMap[field.type] = index
        end
    end

    -- Use pre-defined order instead of recreating it
    local orderedIndexes = {}
    for _, fieldType in ipairs(FIELD_TYPE_ORDER) do
        orderedIndexes[#orderedIndexes + 1] = bestFieldIndexesMap[fieldType]
    end

    return orderedIndexes
end

function FieldHelper:getFieldByPosition(position)
    if not position then return nil end

    local closestField = nil
    local minDistance = math.huge

    for _, field in ipairs(self.fieldOrder) do
        local part = self:getField(field.name)
        if part and part:IsA("BasePart") then
            local distance = (part.Position - position).Magnitude
            if distance < minDistance then
                minDistance = distance
                closestField = part
            end
        end
    end

    return closestField
end

function FieldHelper:destroy()
    self.fieldMap = nil
    self.fieldOrder = nil
    self.displayNameToFieldMap = nil
end

return FieldHelper
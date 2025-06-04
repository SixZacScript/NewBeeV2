local FieldHelper = {}
FieldHelper.__index = FieldHelper
local WP = game:GetService('Workspace')
local FlowerZones = WP:FindFirstChild('FlowerZones')

local FIELD_DATA = {
    {"Sunflower Field", "🌻"},
    {"Dandelion Field", "🌼"},
    {"Mushroom Field", "🍄"},
    {"Clover Field", "☘️"},
    {"Blue Flower Field", "🌿"},
    {"Spider Field", "🕸️"},
    {"Strawberry Field", "🍓"},
    {"Bamboo Field", "🎌"},
    {"Pineapple Patch", "🍍"},
    {"Pumpkin Patch", "🎃"},
    {"Cactus Field", "🌵"},
    {"Pine Tree Forest", "🌳"},
    {"Rose Field", "🌹"},
    {"Stump Field", "🩵"},
    {"Mountain Top Field", "⛰️"},
    {"Coconut Field", "🫕"},
    {"Pepper Patch", "🌶️"}
}

-- Constructor
function FieldHelper.new()
    local self = setmetatable({}, FieldHelper)
    self.currentField = "Sunflower Field"
    self.fieldMap = FIELD_DATA
    return self
end
function FieldHelper:getField()
    local field = FlowerZones:FindFirstChild(self.currentField)
    return field
end
function FieldHelper:getFieldPosition()
    local field = self:getField()
    return field.Position + Vector3.new(0, 4, 0)
end
function FieldHelper:getFieldEmoji(fieldName)
    for _, data in ipairs(self.fieldMap) do
        if data[1] == fieldName then
            return data[2]
        end
    end
    return nil
end

function FieldHelper:getFieldDisplayName(fieldName)
    local emoji = self:getFieldEmoji(fieldName)
    if emoji then
        return emoji .. fieldName
    end
    return fieldName
end
function FieldHelper:getOriginalFieldName(displayName)
    for _, data in ipairs(self.fieldMap) do
        if data[2] .. data[1] == displayName then
            return data[1]
        end
    end
    return nil
end
function FieldHelper:getAllFieldDisplayNames()
    local displayNames = {}
    for _, data in ipairs(self.fieldMap) do
        table.insert(displayNames, data[2] .. data[1])
    end
    return displayNames
end

function FieldHelper:getAllFields()
    local fields = {}
    for _, data in ipairs(self.fieldMap) do
        table.insert(fields, data[1])
    end
    return fields
end
function FieldHelper:SetCurrentField(displayName)
    local fieldName = self:getOriginalFieldName(displayName)
    self.currentField = fieldName
    return fieldName
end

function FieldHelper:getRandomFieldPosition()
    local field = self:getField()
    local player = shared.helper.Player
    if not field then return player.rootPart.Position end
    
    local currentPos = player.rootPart.Position
    local size, center = field.Size, field.Position
    local padding = 15
    local y = currentPos.Y
    

    local maxDistance = 30
    local attempts = 0
    local maxAttempts = 20
    
    repeat
        attempts = attempts + 1
        
        -- Generate random position within field bounds
        local x = center.X + math.random(-size.X / 2 + padding, size.X / 2 - padding)
        local z = center.Z + math.random(-size.Z / 2 + padding, size.Z / 2 - padding)
        local newPos = Vector3.new(x, currentPos.Y, z)
        
        -- Check if the distance is within the max distance
        local distance = (newPos - currentPos).Magnitude
        if distance <= maxDistance then
            return newPos
        end
        
    until attempts >= maxAttempts
    
    -- Fallback: generate position within max distance circle, constrained by field bounds
    local angle = math.random() * 2 * math.pi
    local radius = math.random() * maxDistance
    
    local x = currentPos.X + radius * math.cos(angle)
    local z = currentPos.Z + radius * math.sin(angle)
    
    -- Clamp to field boundaries
    x = math.max(center.X - size.X / 2 + padding, math.min(center.X + size.X / 2 - padding, x))
    z = math.max(center.Z - size.Z / 2 + padding, math.min(center.Z + size.Z / 2 - padding, z))
    
    return Vector3.new(x, currentPos.Y, z)
end

function FieldHelper:destroy()
    self.fieldMap = nil
    self.Fields = nil
end

return FieldHelper

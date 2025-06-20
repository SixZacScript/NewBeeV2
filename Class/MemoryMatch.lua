local Rep = game:GetService("ReplicatedStorage")
local Toys = workspace.Toys
local MemoryMatchHelper = {}
MemoryMatchHelper.__index = MemoryMatchHelper

function MemoryMatchHelper.new(memoryMatchName)
    local self = setmetatable({}, MemoryMatchHelper)
    local valid, modelOrErr = self:validateModel(memoryMatchName)
    assert(valid, modelOrErr)

    self.Model = modelOrErr
    self.Name = memoryMatchName
    -- self.isCooldownOver = self:isCooldownOver()
    return self
end
function MemoryMatchHelper:getData(name)
    if not name then assert(name, "getData Name not found") end
    local MemoryMatchData = {
        ['Memory Match'] = { cooldown = 7200, cost = 25000 }, --2hr 25k
        ['Mega Memory Match'] = { cooldown = 14400, cost = 500000 }, --4hr 500k
        ['Night Memory Match'] = { cooldown = 28800, cost = 5000000 }, --8hr 5m
        ['Extreme Memory Match'] = { cooldown = 28800, cost = 25000000 }, -- 8hr 25m
    }
    return MemoryMatchData[name]
end
function MemoryMatchHelper:validateModel(memoryMatchName)
    local model = Toys:FindFirstChild(memoryMatchName)
    if model then
        return true, model
    else
        return false, ("Model '%s' not found in Toys"):format(memoryMatchName)
    end
end

function MemoryMatchHelper:getPlatform()
    local platform = self.Model:FindFirstChild("Platform")
    assert(platform, "Platform not found")
    return platform
end

function MemoryMatchHelper:getPlatformPosition()
    local platform = self:getPlatform()
    return platform.Position + Vector3.new(0, 3, 0)
end

function MemoryMatchHelper:getMemoryMatchTime()
    local success, plrStats = pcall(function()
        local RetrievePlayerStats = Rep.Events.RetrievePlayerStats
        return RetrievePlayerStats:InvokeServer()
    end)
    if not success then
        warn("Failed to retrieve player stats:", plrStats)
        return {}
    end
    if not plrStats.ToyTimes[self.Name] then
        assert(plrStats.ToyTimes, "Can't not get Memory match time")
    end

    return plrStats.ToyTimes[self.Name]
end

-- function MemoryMatchHelper:isCooldownOver()
--     local toyTime = self:getMemoryMatchTime()
--     local data = self:getData(self.Name)
--     if not toyTime or not data then 
--         warn("not toyTime or not data in isCooldownOver")
--         return false 
--     end

--     local cooldown = data.cooldown
--     local now = os.time() 
--     return now >= (toyTime + cooldown)
-- end

function MemoryMatchHelper:destroy()
    local self = setmetatable({}, MemoryMatchHelper)

    return self
end
return MemoryMatchHelper
local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local ServerItemPackEvent = Rep.Events.ServerItemPackEvent
local ServerMonsterEvent = Rep.Events.ServerMonsterEvent

local Statistics = {}
Statistics.__index = Statistics

function Statistics.new()
    local self = setmetatable({}, Statistics)
    self.data = {}
    self.TokenData = {}
    self.honeyPerMinute = {}
    self.connections = {}
    self.sessionStartTime = tick()

    self:startInterval()
    self:setupConnection()
    return self
end

function Statistics:setupConnection()

    self.connectionsItemPackEvent = ServerItemPackEvent.OnClientEvent:Connect(function(eventType, data)
        local category = data.C
        local amount = data.A
        if eventType ~= "Give" then return end
        if category == "Honey" then 
            self:increment(category, amount)
        elseif category == "Pollen" then 
            self:increment(category, data.R or data.A)
        end

    end)
end


function Statistics:startInterval()
    task.spawn(function()
        while true do
            self:updateSessionTime()
            self:updateHoneyInfoDisplay()
            self:updateTokenDisplay()
            task.wait(1)
        end
    end)
end

function Statistics:increment(statName, amount)
    amount = amount or 1
    self.data[statName] = (self.data[statName] or 0) + amount

    if statName == "Honey" then
        local now = tick()
        local minuteStart = math.floor(now / 60) * 60

        if minuteStart == self.currentMinuteStart then
            self.currentMinuteHoney = self.currentMinuteHoney + amount
        else
            -- push old minute data and shift table
            table.insert(self.honeyPerMinute, self.currentMinuteHoney)
            if #self.honeyPerMinute > 60 then
                table.remove(self.honeyPerMinute, 1)
            end
            self.currentMinuteStart = minuteStart
            self.currentMinuteHoney = amount
        end
    end
end


-- Set a stat
function Statistics:set(statName, value)
    self.data[statName] = value
end

-- Get a stat
function Statistics:get(statName)
    return self.data[statName] or 0
end

-- Reset a stat
function Statistics:reset(statName)
    self.data[statName] = 0
end

-- Remove a stat
function Statistics:remove(statName)
    self.data[statName] = nil
end

-- Return all stats
function Statistics:getAll()
    return self.data
end

-- Clear all stats
function Statistics:clear()
    self.data = {}
end

-- Get session time in seconds
function Statistics:getSessionTime()
    return tick() - self.sessionStartTime
end

-- Set token data
function Statistics:setToken(name, amount)
    self.TokenData[name] = amount
end

-- Get token data
function Statistics:getToken(name)
    return self.TokenData[name] or 0
end

function Statistics:incrementToken(name, amount)
    amount = amount or 1
    self.TokenData[name] = (self.TokenData[name] or 0) + amount

    -- Track tokens per minute
    self.TokenMinuteHistory = self.TokenMinuteHistory or {}
    local minuteKey = math.floor(tick() / 60)
    
    self.TokenMinuteHistory[name] = self.TokenMinuteHistory[name] or {}
    self.TokenMinuteHistory[name][minuteKey] = (self.TokenMinuteHistory[name][minuteKey] or 0) + amount
end


function Statistics:getHoneyRate()
    local honey = self:get("Honey")
    local sessionTime = self:getSessionTime()
    local hours = sessionTime / 3600
    local days = sessionTime / 86400

    local perHour = hours > 0 and (honey / hours) or 0
    local perDay = days > 0 and (honey / days) or 0

    return perHour, perDay
end
function Statistics:getTokenRatePerMinute(name)
    self.TokenMinuteHistory = self.TokenMinuteHistory or {}
    local history = self.TokenMinuteHistory[name]
    if not history then return 0 end

    local lastMinute = math.floor(tick() / 60) - 1
    return history[lastMinute] or 0
end

function Statistics:updateHoneyInfoDisplay()
    if shared.Fluent and shared.Fluent.HoneyInfo and shared.TokenDataModule then
        local perHour, perDay = self:getHoneyRate()
        local perHourFormatted = shared.TokenDataModule:formatNumber(perHour, 2)
        local perDayFormatted = shared.TokenDataModule:formatNumber(perDay, 2)
        local totalFormatted = shared.TokenDataModule:formatNumber(self:get("Honey"), 2)

        local displayText = "Hourly: " .. perHourFormatted .. "\nDaily: " .. perDayFormatted .. "\nTotal: " .. totalFormatted
        shared.Fluent.HoneyInfo:SetDesc(displayText)
    end
end


function Statistics:updateSessionTime()
    local elapsed = tick() - self.sessionStartTime
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = math.floor(elapsed % 60)
    local formattedTime = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    
    if shared.Fluent and shared.Fluent.sessionTimeInfo then
        shared.Fluent.sessionTimeInfo:SetDesc(formattedTime)
    end
end

function Statistics:updateTokenDisplay()
    if shared.Fluent and shared.Fluent.tokenCollectedInfo then
        local tokens = {}
        for name, amount in pairs(self.TokenData) do
            table.insert(tokens, {Name = name, Amount = amount})
        end
        table.sort(tokens, function(a, b) return a.Amount > b.Amount end)

        local lines = {}
        for _, token in ipairs(tokens) do
            local rate = self:getTokenRatePerMinute(token.Name)
            local line = string.format("%-10s : %-6d | last min: %d", token.Name, token.Amount, rate)
            table.insert(lines, line)
        end

        shared.Fluent.tokenCollectedInfo:SetDesc(table.concat(lines, "\n"))
    end
end



return Statistics

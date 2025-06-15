local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local BeeStatsModule = Rep.BeeStats
local BeeStats = require(BeeStatsModule)

local BeeHelper = {}
BeeHelper.__index = BeeHelper

-- Cache frequently accessed services and modules
local RetrievePlayerStats = Rep.Events.RetrievePlayerStats
local ConstructHiveCellFromEgg = Rep.Events.ConstructHiveCellFromEgg

function BeeHelper.new()
    local self = setmetatable({}, BeeHelper)
    self.plrStats = nil
    self.honeycomb = nil
    self.allBees = nil
    self.currentBee = nil
    
    -- Initialize data
    if not self:getPlayerStats() then
        warn("BeeHelper: Failed to initialize - could not retrieve player stats")
        return nil
    end
    
    self.honeycomb = self:getHoneycomb()
    self.allBees = self:getAllBees()
    self.currentBee = self:setCurrentBee()
    
    return self
end

function BeeHelper:setCurrentBee()
    local beeStats = shared.main.BeeTab
    if not beeStats or not beeStats.row or not beeStats.column then 
        return nil
    end

    local currentBee = self:getBeeByPosition(beeStats.row, beeStats.column)
    if not currentBee then
        return nil
    end

    beeStats.currentBee = currentBee

    -- Async UI update with better error handling
    task.spawn(function()
        local timeout = 0
        repeat 
            task.wait(0.1)
            timeout += 0.1
        until (shared.Fluent and shared.Fluent.selectedBeeInfo) or timeout > 5

        if shared.Fluent and shared.Fluent.selectedBeeInfo then
            local success, err = pcall(function()
                shared.Fluent.selectedBeeInfo:SetDesc(
                    string.format("%s | Level: %s", currentBee.Type or "Unknown", tostring(currentBee.Lvl or 0))
                )
            end)
            if not success then
                warn("BeeHelper: Failed to update UI:", err)
            end
        end
    end)

    return currentBee
end

function BeeHelper:getCurrentBee()
    -- Use cached current bee if available, fallback to shared reference
    return self.currentBee or (shared.main.Hive and shared.main.Hive.currentBee)
end

function BeeHelper:getStats(bee, playerData)
    if not bee or not playerData then
        return {}
    end

    local beeStats = {}
    
    -- Batch stat calculations with error handling
    local statFunctions = {
        Attack = BeeStats.GetAttack,
        ConversionRate = BeeStats.GetConversionRate,
        ConversionSpeed = BeeStats.GetConversionSpeed,
        GatherSpeed = BeeStats.GetGatherSpeed,
        MaxEnergy = BeeStats.GetMaxEnergy,
        Movespeed = BeeStats.GetMovespeed,
        CriticalChance = BeeStats.GetCriticalChance,
        CriticalPower = BeeStats.GetCriticalPower,
        SuperCritChance = BeeStats.GetSuperCritChance,
        SuperCritPower = BeeStats.GetSuperCritPower,
        CooldownReduction = BeeStats.GetCooldownReduction
    }
    
    for statName, statFunction in pairs(statFunctions) do
        local success, result = pcall(statFunction, bee, playerData)
        beeStats[statName] = success and result or 0
    end
    
    -- Handle special cases
    local success, gatherAmounts, gatherMultipliers = pcall(BeeStats.GetGatherAmounts, bee, playerData)
    if success then
        beeStats.GatherAmounts = gatherAmounts
        beeStats.GatherMultipliers = gatherMultipliers
    else
        beeStats.GatherAmounts = {}
        beeStats.GatherMultipliers = {}
    end
    
    -- Stats that don't require playerData
    beeStats.InstantConversion = pcall(BeeStats.GetInstantConversion, bee) and BeeStats.GetInstantConversion(bee) or 0
    beeStats.Beequip = pcall(BeeStats.GetBeequip, bee) and BeeStats.GetBeequip(bee) or {}
    beeStats.Tags = pcall(BeeStats.GetTags, bee) and BeeStats.GetTags(bee) or {}
    beeStats.Mutations = pcall(BeeStats.GetMutations, bee) and BeeStats.GetMutations(bee) or {}

    return beeStats
end

function BeeHelper:getPlayerStats()
    if self.plrStats then
        return self.plrStats -- Return cached stats
    end
    
    local success, plrStats = pcall(function()
        return RetrievePlayerStats:InvokeServer()
    end)
    
    if not success then
        warn("BeeHelper: Failed to retrieve player stats:", plrStats)
        return false
    end
    
    self.plrStats = plrStats
    return self.plrStats
end

function BeeHelper:getHoneycomb()
    if self.honeycomb then
        return self.honeycomb -- Return cached honeycomb
    end
    
    if not self.plrStats then
        self:getPlayerStats()
    end
    
    self.honeycomb = self.plrStats and self.plrStats.Honeycomb or {}
    return self.honeycomb
end

function BeeHelper:feedBee(customRow, customColumn, customAmount, customFoodType)
    local beeTab = shared.main.BeeTab
    if not beeTab then 
        warn("BeeHelper: BeeTab not found")
        return false
    end

    local row = customRow or tonumber(beeTab.row) or 1
    local column = customColumn or tonumber(beeTab.column) or 1
    local amount = customAmount or tonumber(beeTab.amount) or 1
    local foodType = customFoodType or beeTab.foodType or "Treat"

    local success, result = pcall(function()
        return ConstructHiveCellFromEgg:InvokeServer(row, column, foodType, amount, false)
    end)
    
    if not success then
        warn("BeeHelper: Failed to feed bee:", result)
        return false
    end
    
    return true
end

function BeeHelper:getLowestLevelBee()
    local allBees = self:getAllBees()
    if not allBees or #allBees == 0 then
        warn("BeeHelper: No bees found to evaluate lowest level")
        return nil
    end

    table.sort(allBees, function(a, b)
        return (a.Lvl or 0) < (b.Lvl or 0)
    end)

    return allBees[1]
end


function BeeHelper:getBeeByPosition(x, y)
    local honeycomb = self:getHoneycomb()
    if not honeycomb then return nil end
    
    local xKey = "x" .. tostring(x)
    local yKey = "y" .. tostring(y)

    return honeycomb[xKey] and honeycomb[xKey][yKey] or nil
end

function BeeHelper:getAllBees()
    if self.allBees then
        return self.allBees -- Return cached bees
    end
    
    local playerData = self:getPlayerStats()
    local honeycomb = self:getHoneycomb()
    
    if not playerData or not honeycomb then
        warn("BeeHelper: Cannot get all bees - missing data")
        return {}
    end
    
    local allBees = {}
    
    for xCoord, yCoordsTable in pairs(honeycomb) do
        if type(yCoordsTable) == 'table' then
            for yCoord, beeData in pairs(yCoordsTable) do
                if type(beeData) == 'table' then
                    local beeLevel = beeData.Lvl
                    local x = tonumber(string.match(tostring(xCoord), "%d+"))
                    local y = tonumber(string.match(tostring(yCoord), "%d+"))
                    
                    if x and y then
                        -- Create a copy to avoid modifying original data
                        local beeCopy = {}
                        for k, v in pairs(beeData) do
                            beeCopy[k] = v
                        end
                        
                        beeCopy.Stats = self:getStats(beeData, playerData)
                        beeCopy.HivePosition = { X = x, Y = y }
                        table.insert(allBees, beeCopy)
                    end
                end
            end
        end
    end
    
    -- Optional: Save to file with error handling
    local success, jsonData = pcall(HttpService.JSONEncode, HttpService, allBees)
    if success then
        local writeSuccess = pcall(writefile, 'optimized_bee_data.json', jsonData)
        if not writeSuccess then
            warn("BeeHelper: Failed to write bee data to file")
        end
    else
        warn("BeeHelper: Failed to encode bee data to JSON")
    end
    
    self.allBees = allBees
    return allBees
end

-- Utility methods
function BeeHelper:refreshData()
    self.plrStats = nil
    self.honeycomb = nil
    self.allBees = nil
    self.currentBee = nil
    
    self:getPlayerStats()
    self.honeycomb = self:getHoneycomb()
    self.allBees = self:getAllBees()
    self.currentBee = self:setCurrentBee()
end

function BeeHelper:getBeeCount()
    return self.allBees and #self.allBees or 0
end

function BeeHelper:findBeesByType(beeType)
    if not self.allBees then return {} end
    
    local foundBees = {}
    for _, bee in ipairs(self.allBees) do
        if bee.Type == beeType then
            table.insert(foundBees, bee)
        end
    end
    return foundBees
end

function BeeHelper:destroy()
    self.plrStats = nil
    self.honeycomb = nil
    self.allBees = nil
    self.currentBee = nil
end

return BeeHelper
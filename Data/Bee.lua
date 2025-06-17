local HttpService = game:GetService("HttpService")
local BeeModule = {}

local bees = {
    "Basic Bee", "Bomber Bee", "Brave Bee", "Bumble Bee", "Cool Bee", "Hasty Bee",
    "Looker Bee", "Rad Bee", "Rascal Bee", "Stubborn Bee",
    "Bubble Bee", "Bucko Bee", "Commander Bee", "Demo Bee",
    "Exhausted Bee", "Fire Bee", "Frosty Bee", "Honey Bee",
    "Rage Bee", "Riley Bee", "Shocked Bee",
    "Baby Bee", "Carpenter Bee", "Demon Bee", "Diamond Bee",
    "Lion Bee", "Music Bee", "Ninja Bee", "Shy Bee",
    "Buoyant Bee", "Fuzzy Bee", "Precise Bee",
    "Spicy Bee", "Tadpole Bee", "Vector Bee",
    "Bear Bee", "Cobalt Bee", "Crimson Bee", "Digital Bee",
    "Festive Bee", "Gummy Bee", "Photon Bee",
    "Puppy Bee", "Tabby Bee", "Vicious Bee", "Windy Bee"
}

local eventBees = {
    "Bear Bee", "Cobalt Bee", "Crimson Bee", "Digital Bee",
    "Festive Bee", "Gummy Bee", "Photon Bee",
    "Puppy Bee", "Tabby Bee", "Vicious Bee", "Windy Bee"
}

local rarityMap = {
    Common = {"Basic Bee"},
    Rare = {
        "Bomber Bee", "Brave Bee", "Bumble Bee", "Cool Bee", "Hasty Bee",
        "Looker Bee", "Rad Bee", "Rascal Bee", "Stubborn Bee"
    },
    Epic = {
        "Bubble Bee", "Bucko Bee", "Commander Bee", "Demo Bee",
        "Exhausted Bee", "Fire Bee", "Frosty Bee", "Honey Bee",
        "Rage Bee", "Riley Bee", "Shocked Bee"
    },
    Legendary = {
        "Baby Bee", "Carpenter Bee", "Demon Bee", "Diamond Bee",
        "Lion Bee", "Music Bee", "Ninja Bee", "Shy Bee"
    },
    Mythic = {
        "Buoyant Bee", "Fuzzy Bee", "Precise Bee",
        "Spicy Bee", "Tadpole Bee", "Vector Bee"
    },
    Event = eventBees
}

local beeMap = {}
for _, beeName in ipairs(bees) do
    local key = beeName:gsub("%s+", ""):lower()
    beeMap[beeName] = key
end

function BeeModule.getBeeMap()
    return beeMap
end

function BeeModule:normalizeName(name)
    return name:gsub("%s+", ""):lower()
end

function BeeModule.getAllBees(exclude)
    local excludeSet = {}
    for _, ex in ipairs(exclude or eventBees) do
        excludeSet[ex] = true
    end
    local filtered = {}
    for _, bee in ipairs(bees) do
        if not excludeSet[bee] then
            table.insert(filtered, bee)
        end
    end
    return filtered
end

function BeeModule:getBeeRarity(beeName)
    for rarity, list in pairs(rarityMap) do
        for _, name in ipairs(list) do
            if self:normalizeName(name) == beeName then
                return rarity
            end
        end
    end
    return "Unknown"
end

function BeeModule.getRareBees()
    local rareBees = {}
    local excludeSet = {}
    for _, bee in ipairs(eventBees) do
        excludeSet[bee] = true
    end
    for _, bee in ipairs(rarityMap.Rare) do
        if not excludeSet[bee] then
            table.insert(rareBees, bee)
        end
    end
    return rareBees
end

function BeeModule.getAllRarityTypes()
    return {"Common", "Rare", "Epic", "Legendary", "Mythic"}
end
function BeeModule:isBeeSelected(bee)
    for _, beeName in pairs(shared.main.autoJelly.selectedBees) do
        local name = self:normalizeName(beeName)
        local targetName = self:normalizeName(bee)
        if name == targetName then
            return true
        end
    end

    return false
end

function BeeModule:doJelly(X, Y)
    local Event = game:GetService("ReplicatedStorage").Events.ConstructHiveCellFromEgg
    local success, result = pcall(function()
        return Event:InvokeServer(tonumber(X), tonumber(Y), "RoyalJelly", 1, false)
    end)
    
    if success then
        return result
    else
        warn("Server call failed:", result)
        return 0 -- or handle the error as needed
    end
end

function BeeModule:startAutoJelly()
    if self._jellyThread and coroutine.status(self._jellyThread) ~= "dead" then return end
    
    local autoJelly = shared.main.autoJelly
    local X, Y = autoJelly.X, autoJelly.Y
    local selectedTypes = autoJelly.selectedTypes
    local cellModel = shared.helper.Hive:getCellByXY(X, Y)
    
    if not cellModel then return self:stopAutoJelly("Unknown cell.") end
    
    autoJelly.isRunning = true
    self._jellyThread = coroutine.create(function()
        while autoJelly.isRunning do
            if autoJelly.X ~= X or autoJelly.Y ~= Y then 
                return self:stopAutoJelly("Cell changed while auto jelly was running.") 
            end
            
            local jellyCount = self:doJelly(X, Y)
            
            -- Add a small wait to prevent overwhelming the server
            wait(0.1) -- or task.wait(0.1) in newer versions
            
            cellModel = shared.helper.Hive:getCellByXY(X, Y)
            local hasGiftedCell = cellModel:FindFirstChild("GiftedCell")
            local beeName = cellModel.CellType.Value
            local beeRarity = self:getBeeRarity(self:normalizeName(beeName))
            
            local isTargetBee = self:isBeeSelected(beeName) or table.find(selectedTypes, beeRarity) or (autoJelly.anyGifted and hasGiftedCell)
            
            if isTargetBee then return self:stopAutoJelly("✅Found target bee✅") end
            if jellyCount <= 0 then return self:stopAutoJelly("Out of jelly") end
        end
        self._jellyThread = nil
    end)
    
    coroutine.resume(self._jellyThread)
end

function BeeModule:stopAutoJelly(reason)
    shared.main.autoJelly.isRunning = false
    shared.Fluent.jellyStartButton:SetTitle("Start")

    if coroutine.status(self._jellyThread) == "dead" then
        self._jellyThread = nil
    end

    if reason then
        shared.FluentLib:Notify({
            Title = "Auto Jelly Stopped",
            Content = reason,
            Duration = 3
        })
    end
end



return BeeModule

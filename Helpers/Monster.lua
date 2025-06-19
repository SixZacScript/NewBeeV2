local HttpService = game:GetService("HttpService")
local WP = game:GetService("Workspace")
local MonstersFolder = WP:FindFirstChild("Monsters")
local MonsterSpawnersFolder = WP:FindFirstChild("MonsterSpawners")
local MonsterHelper = {}
local spawnerKey = {
    ["MushroomBush"] = "Mushroom Field",
    ["Ladybug Bush"] = "Clover Field",
    ["Ladybug Bush 2"] = "Strawberry Field",
    ["Ladybug Bush 3"] = "Strawberry Field",

    ["PineappleBeetle"] = "Pineapple Patch",
    ["PineappleMantis1"] = "Pineapple Patch",

    ["ForestMantis1"] = "Pine Tree Forest",
    ["ForestMantis2"] = "Pine Tree Forest",

    ["Rhino Bush"] = "Clover Field",
    ["Rhino Cave 1"] = "Blue Flower Field",
    ["Rhino Cave 2"] = "Bamboo Field",
    ["Rhino Cave 3"] = "Bamboo Field",

    ['Spider Cave'] = "Spider Field",

    ["RoseBush"] = "Rose Field",
    ["RoseBush2"] = "Rose Field",

    ['WerewolfCave'] = "Cactus Field",

    ['StumpSnail'] = "Stump Field",
    ["CoconutCrab"] = "Coconut Field",
}

MonsterHelper.__index = MonsterHelper

function MonsterHelper.new()
    local self = setmetatable({}, MonsterHelper)
    self.Monsters = {}
    self.connections = {} 
    self.availableMonsters = {}
    self.spawnerKey = spawnerKey
    self:setupListener()
    return self
end
function MonsterHelper:getMonsterByType(monsterType)
    local monsters = {}
    for index, monster in pairs(self.Monsters) do
        if monster and monster.MonsterType and monster.MonsterType.Value == monsterType then
            table.insert(monsters, monster)
        end
    end
    return monsters
end
function MonsterHelper:checkMonsterForTarget(monster)
    if not self:playerValid() then return end
    
    for _, descendant in ipairs(monster:GetDescendants()) do
        if descendant.Name == "Target" and descendant:IsA("ObjectValue") then
            if descendant.Value == shared.helper.Player.character then
                if not table.find(self.Monsters, monster) then
                    table.insert(self.Monsters, monster)
                end
            end
            break -- Found Target, no need to continue
        end
    end
end

function MonsterHelper:getThaiTimeString(unixTimestamp)
    local utcTime = os.date("!*t", unixTimestamp)
    utcTime.hour = utcTime.hour + 7

    -- Adjust for overflow
    if utcTime.hour >= 24 then
        utcTime.hour = utcTime.hour - 24
        utcTime.day = utcTime.day + 1
    end

    return string.format("%04d-%02d-%02d %02d:%02d:%02d", utcTime.year, utcTime.month, utcTime.day, utcTime.hour, utcTime.min, utcTime.sec)
end

function MonsterHelper:setupListener()
    self.connections.folderChildAdded = MonstersFolder.ChildAdded:Connect(function(monster)
        -- Simply check all descendants for Target
        task.spawn(function()
            task.wait(0.25)
            self:checkMonsterForTarget(monster)
        end)
        
    end)

    self.connections.folderChildRemoved = MonstersFolder.ChildRemoved:Connect(function(monster)
        local index = table.find(self.Monsters, monster)
        if index then 
            table.remove(self.Monsters, index) 
        end
    end)

    local monsterList = { "Ladybug", "Rhino Beetle","Spider", "Mantis", "Werewolf", "Scorpion"}
    task.spawn(function()
        while true do
            local monsters = self:getMonsterTime()
            self.availableMonsters = {}
            local spawnedTypes = {}
            local cooldownTimes = {}
            local lines = {}

            -- เช็ค spawn และเก็บเวลาที่น้อยที่สุดของแต่ละ monsterType
            for fieldName, fieldMonsters in pairs(monsters) do
                for _, monsterData in ipairs(fieldMonsters) do
                    if not table.find(monsterList, monsterData.monsterType) then continue end
                    local mt = monsterData.monsterType
                    if monsterData.isSpawned then
                        spawnedTypes[mt] = true
                        if not self.availableMonsters[mt] then
                            self.availableMonsters[mt] = {monsterData}
                        else
                            table.insert(self.availableMonsters[mt], monsterData)
                        end
                    else
                        if not cooldownTimes[mt] or monsterData.time < cooldownTimes[mt] then
                            cooldownTimes[mt] = monsterData.time
                        end
                    end
                end
            end

            -- สร้างบรรทัดแสดงผล
            for mt, _ in pairs(spawnedTypes) do
                table.insert(lines, string.format("🟢 | %s ", mt))
            end

            for mt, time in pairs(cooldownTimes) do
                if not spawnedTypes[mt] then
                    table.insert(lines, string.format("🔴 | %s", time))
                end
            end

            -- แสดงผล
            if shared.Fluent and shared.Fluent.monsterStatusInfo then
                shared.Fluent.monsterStatusInfo:SetDesc(table.concat(lines, "\n"))
            end

            task.wait(10)
        end
    end)




end

function MonsterHelper:playerValid()
    return shared.helper.Player:isValid()
end

function MonsterHelper:getCloseMonsterCount(targetDistance)
    local count = 0
    local char = shared.helper.Player.character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not self:playerValid() then return 0 end
    for _, monster in ipairs(self.Monsters) do
        local mRoot = monster.PrimaryPart
        if mRoot then
            local distance = (mRoot.Position - root.Position).Magnitude
            if distance <= targetDistance then
                count += 1

            end
        end

    end
    return count
end


function MonsterHelper:getMonsterTime()
    local monsters = {}
    for _, spawner in ipairs(MonsterSpawnersFolder:GetChildren()) do
        local monsterTypeObj = spawner:FindFirstChild("MonsterType")
        local attachment = spawner:FindFirstChildWhichIsA("Attachment")
        if monsterTypeObj and attachment then
            local monsterType = monsterTypeObj.Value
            local timerLabel = attachment:FindFirstChild("TimerGui") and attachment.TimerGui:FindFirstChild("TimerLabel")

            if timerLabel then
                local key = spawnerKey[spawner.Name]
                local isSpawned = not timerLabel.Visible
                
                if not key then continue end
                if not monsters[key] then
                    monsters[key] = {}
                end

                local updated = false
                for _, entry in ipairs(monsters[key]) do
                    if entry.spawner == spawner.Name then
                        -- Update existing entry
                        entry.isSpawned = isSpawned
                        entry.time = isSpawned and "00:00" or timerLabel.Text
                        entry.timerLabel = timerLabel
                        entry.spawner = spawner.Name
                        updated = true
                        break
                    end
                end

                if not updated then
                    table.insert(monsters[key], {
                        monsterType = monsterType,
                        isSpawned = isSpawned,
                        time = isSpawned and "00:00" or timerLabel.Text,
                        field = key,
                        timerLabel = timerLabel,
                        spawner = spawner.Name
                    })
                end
            end
        end
    end
    return monsters
end




function MonsterHelper:canHuntMonster(monsterName)
    local spawner = {}
    local canHuntMonster = {}
    for _, part in ipairs(MonsterSpawnersFolder:GetChildren()) do
        local hasMonsterType = part:FindFirstChild('MonsterType')
        if not hasMonsterType then continue end
        table.insert(spawner, part)
    end

    for _, spawnerPart in ipairs(spawner) do
        local MonsterType = spawnerPart.MonsterType
        if monsterName == MonsterType.Value then
            local Attachment = spawnerPart:FindFirstChildWhichIsA('Attachment')
            if Attachment then
                local TimerGui = Attachment.TimerGui
                local TimerLabel = TimerGui.TimerLabel
                if not TimerLabel.Visible then
                    table.insert(canHuntMonster, spawnerKey[spawnerPart.Name])
                end
            end
        end
    end
    if #canHuntMonster > 0 then return true , canHuntMonster[1] end
    return false, nil
end

function MonsterHelper:getAvailableMonster()
    local availableMonsters = self.availableMonsters or {}
    local targetMonsters = shared.main.Monster.monsters or {}

    for _, targetName in pairs(targetMonsters) do
        local monster = availableMonsters[targetName]
        if monster then return monster end
    end

    return nil
end
function MonsterHelper:getDistanceToMonster(monsterModel)
    local player = game.Players.LocalPlayer
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local monsterRootPart = monsterModel.PrimaryPart
    
    if not monsterRootPart then
        return nil
    end
    local newPosMonster = Vector3.new(monsterRootPart.Position.X, playerPosition.Y, monsterRootPart.Position.Z)
    return (playerPosition - newPosMonster).Magnitude
end

function MonsterHelper:getMonsterModel(typeName)
    local targetTypeName = string.lower(typeName:gsub("%s+", ""))
    local localPlayerCharacter = game.Players.LocalPlayer.Character
    for _, monster in pairs(MonstersFolder:GetChildren()) do
        if monster:IsA("Model")  then
            local monsterType = monster:FindFirstChild("MonsterType")
            local targetObject = monster:FindFirstChild("Target")
            
            if monsterType and targetObject then
                if targetObject.Value == localPlayerCharacter and string.lower(monsterType.Value:gsub("%s+", "")) == targetTypeName then
                    return monster
                end
            end
        end
    end
    
    return nil
end

function MonsterHelper:destroy()
    if self.connections.folderChildAdded then
        self.connections.folderChildAdded:Disconnect()
    end
    if self.connections.folderChildRemoved then
        self.connections.folderChildRemoved:Disconnect()
    end
    if self.connections.trackingCoroutine then
        task.cancel(self.connections.trackingCoroutine)
    end
    self.spawnerKey = nil
    table.clear(self.Monsters)
    table.clear(self.connections)
end

return MonsterHelper
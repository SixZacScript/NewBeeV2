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

    local monsterList = {"Ladybug", "Rhino Beetle", "Spider", "Mantis", "Werewolf"}
    task.spawn(function()
        while true do
            local monsters = self:getMonsterTime()
            local lines = {}

            for _, monsterName in ipairs(monsterList) do
                local data = monsters[monsterName]
                if data then
                    if data.isSpawned then
                        self.availableMonsters[monsterName] = data
                        table.insert(lines, string.format("%s | 🟢", monsterName))
                    else
                        table.insert(lines, string.format("%s | %s | 🔴", monsterName, data.time))
                    end
                else
                    table.insert(lines, string.format("%s | N/A | 🔴", monsterName))
                end
            end

            if shared.Fluent and shared.Fluent.monsterStatusInfo then
                shared.Fluent.monsterStatusInfo:SetDesc(table.concat(lines, "\n"))
            end
                
            task.wait(1)
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
                local isSpawned = not timerLabel.Visible
                local current = monsters[monsterType]

                if not current then
                    monsters[monsterType] = {
                        isSpawned = false,
                        time = timerLabel.Text,
                        field = spawnerKey[spawner.Name] -- เพิ่มฟิลด์นี้
                    }
                end

                if isSpawned then
                    monsters[monsterType].isSpawned = true
                    monsters[monsterType].time = "00:00"
                    monsters[monsterType].field = spawnerKey[spawner.Name] -- อัปเดตฟิลด์ถ้ามีการเกิด
                else
                    if not monsters[monsterType].isSpawned then
                        monsters[monsterType].time = timerLabel.Text
                        monsters[monsterType].field = spawnerKey[spawner.Name]
                    end
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
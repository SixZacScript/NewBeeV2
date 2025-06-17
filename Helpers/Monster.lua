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
end

function MonsterHelper:playerValid()
    return shared.helper.Player:isValid()
end

function MonsterHelper:getCloseMonsterCount(targetDistance)
    local count = 0
    local char = shared.helper.Player.character
    local hum = shared.helper.Player.humanoid
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
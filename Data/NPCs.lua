local WP = game:GetService('Workspace')
local NPCsFolder = WP:FindFirstChild("NPCs") 

local npcHelper = {}
npcHelper.__index = npcHelper

function npcHelper.new()
    local self = setmetatable({}, npcHelper)
    
    self.NPCs = {
        ["Black Bear"] = {doQuest = false, displayOrder = 1},
        ["Panda Bear"] = {doQuest = false, displayOrder = 2},
        ["Brown Bear"] = {doQuest = false, displayOrder = 3},
        ["Polar Bear"] = {doQuest = false, displayOrder = 4},
        ["Science Bear"] = {doQuest = false, displayOrder = 5},
        ["Mother Bear"] = {doQuest = false, displayOrder = 6},
        ["Spirit Bear"] = {doQuest = false, displayOrder = 7},
        ["Riley Bee"] = {doQuest = false, displayOrder = 8},
        ["Bucko Bee"] = {doQuest = false, displayOrder = 9},
        ["Honey Bee"] = {doQuest = false, displayOrder = 10},
    }

    return self
end

function npcHelper:getNpcNames()
    local npcList = {}
    
    for name, data in pairs(self.NPCs) do
        table.insert(npcList, { name = name, displayOrder = data.displayOrder or math.huge})
    end

    table.sort(npcList, function(a, b)
        if a.displayOrder ~= b.displayOrder then
            return a.displayOrder < b.displayOrder
        else
            return a.name < b.name 
        end
    end)

    
    local orderedNames = {}
    for _, npcData in ipairs(npcList) do
        table.insert(orderedNames, npcData.name)
    end

    return orderedNames
end
function npcHelper:getNPCModel(npcName)
    local npc =  NPCsFolder:FindFirstChild(npcName)
    if not npc then
        warn('no npc found for: ', npcName)
       return 
    end
    return npc
end
function npcHelper:getDoQuestNpcNames()
    local questingNpcs = {}
    local hasNPC = false
    for name, data in pairs(self.NPCs) do
        if data.doQuest then
            questingNpcs[name] = true
            hasNPC = true
        end
    end
    return questingNpcs, hasNPC
end

function npcHelper:updateDoQuest(newQuestStates)
    for npcName, npcData in pairs(self.NPCs) do
        if newQuestStates[npcName] ~= nil then
            npcData.doQuest = newQuestStates[npcName]
        else
            npcData.doQuest = false
        end
    end
end
function npcHelper:getDoQuestValue(npcName)
    local npc = self.NPCs[npcName]
    if npc then
        return npc.doQuest
    end
    return nil
end

function npcHelper:destroy()
    self.NPCs = nil
    setmetatable(self, nil) 
end

return npcHelper

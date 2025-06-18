local u1 = require(game.ReplicatedStorage.RepeatQuests)
require(game.ReplicatedStorage.StatReqs)
local v2 = script:WaitForChild("TaskTypes")
local v3 = { "Description", "GetStat" }
local u4 = {}
local u5 = {}
for _, v6 in ipairs(v2:GetChildren()) do
    local v7 = require(v6)
    v7.Name = v6.Name
    for _, v8 in pairs(v3) do
        if not v7[v8] then
            error("Task definition \"" .. v6.Name .. " does not have " .. v8)
        end
    end
    u4[v6.Name] = v7
end
function u5.GetTaskTypes(_) --[[Anonymous function at line 76]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    return u4
end
local u9 = require(game.ReplicatedStorage.StatReqs)
u9.GetTypes()
local u10 = {}
local u11 = {}
local u12 = {
    ["Requirements"] = {},
    ["Description"] = "",
    ["Repeatable"] = false,
    ["Tasks"] = {},
    ["Rewards"] = {}
}
local v13 = script:WaitForChild("Quests")
local function u30(p14) --[[Anonymous function at line 137]]
    --[[
    Upvalues:
        [1] = u10
        [2] = u12
        [3] = u11
        [4] = u4
    --]]
    if not (p14.Name and (p14.Rewards and p14.Tasks)) then
        error("invalid quest")
    end
    if u10[p14.Name] then
        error("there is already a quest named " .. p14.Name)
    else
        for v15, v16 in pairs(u12) do
            if not p14[v15] then
                p14[v15] = v16
            end
        end
        p14.ID = #u11 + 1
        local v17 = u11
        table.insert(v17, p14)
        u10[p14.Name] = p14
        local v18 = p14.Tasks
        if type(v18) ~= "function" then
            for _, u19 in ipairs(p14.Tasks) do
                local u20 = u4[u19.Type]
                if u20 == nil then
                    error("No task definition with name " .. u19.Type)
                end
                local v21, v22 = u20.Validate(u19)
                if not v21 then
                    error(v22)
                end
                local v23 = u19.Amount
                if v23 then
                    local v24 = u19.Amount
                    v23 = type(v24) ~= "number"
                end
                if not v23 then
                    v23 = u19.Pack and u19.Pack.Type
                    if v23 then
                        local v25 = u19.Pack.Type
                        v23 = type(v25) ~= "string"
                    end
                end
                local v26
                if v23 then
                    v26 = nil
                else
                    v26 = u20.Description(u19)
                    if type(v26) == "function" then
                        v23 = true
                    end
                end
                if v23 then
                    function u19.Description(p27) --[[Anonymous function at line 205]]
                        --[[
                        Upvalues:
                            [1] = u20
                            [2] = u19
                        --]]
                        return u20.Description(u19, p27)
                    end
                else
                    if v26 == "function" then
                        warn("error task", u19)
                        error("the prefetched desc is a function")
                    end
                    u19.Description = v26
                end
                if u20.ProgressDescription then
                    u19.ProgressDescription = u20.ProgressDescription
                end
            end
        end
        local v28 = p14.Rewards
        if type(v28) == "table" then
            for _, v29 in ipairs(p14.Rewards) do
                if v29.Category == "Honey" then
                    v29.Alert = true
                    v29.Logged = true
                end
            end
        end
    end
end
for _, v31 in ipairs(v13:GetChildren()) do
    local v32 = require(v31)
    v32.Name = v31.Name
    u30(v32)
end
local v33 = u1.GetQuests()
for _, v34 in ipairs(v33) do
    u30(v34)
end
function u5.Create(_, p35) --[[Anonymous function at line 293]]
    --[[
    Upvalues:
        [1] = u30
    --]]
    u30(p35)
end
function u5.GetAllQuests(_) --[[Anonymous function at line 303]]
    --[[
    Upvalues:
        [1] = u11
    --]]
    return u11
end
function u5.Get(_, p36) --[[Anonymous function at line 305]]
    --[[
    Upvalues:
        [1] = u10
    --]]
    return u10[p36]
end
function u5.GetByID(_, p37) --[[Anonymous function at line 307]]
    --[[
    Upvalues:
        [1] = u11
    --]]
    return u11[p37]
end
function u5.NameToID(_, p38) --[[Anonymous function at line 309]]
    --[[
    Upvalues:
        [1] = u10
    --]]
    local v39 = u10[p38]
    if v39 == nil then
        return nil
    else
        return v39.ID
    end
end
function u5.IDToName(_, p40) --[[Anonymous function at line 316]]
    --[[
    Upvalues:
        [1] = u11
    --]]
    local v41 = u11[p40]
    if v41 == nil then
        return nil
    else
        return v41.Name
    end
end
function u5.ResolveTasks(p42, p43) --[[Anonymous function at line 324]]
    local v44 = p42.Tasks
    if type(v44) == "function" then
        v44 = v44(p43)
    end
    return v44
end
function u5.FlaggedComplete(_, p45, p46) --[[Anonymous function at line 342]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    if not p46 then
        return false
    end
    if u5:Get(p45) == nil then
        return false
    end
    for _, v47 in ipairs(p46.Quests.Completed) do
        if v47 == p45 then
            return true
        end
    end
    return false
end
function u5.GetActiveData(_, p48, p49) --[[Anonymous function at line 358]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    if not p49 then
        return nil
    end
    if u5:Get(p48) == nil then
        return nil
    end
    local v50 = nil
    for _, v51 in ipairs(p49.Quests.Active) do
        if v51.Name == p48 then
            return v51
        end
    end
    return v50
end
function u5.ActivatedQuests(_, p52, p53) --[[Anonymous function at line 380]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    return u5:FlaggedComplete(p52, p53) or u5:GetActiveData(p52, p53) ~= nil
end
function u5.GetActiveRepeatable(_, p54, p55) --[[Anonymous function at line 386]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    for _, v56 in ipairs(p55.Quests.Active) do
        local v57 = u5:Get(v56.Name)
        if v57 and v57.Pool == p54 then
            return v56
        end
    end
    return nil
end
function u5.GetProgression(_, p58, p59, p60, p61) --[[Anonymous function at line 402]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    local v62 = {}
    if type(p58) == "function" then
        p58 = p58(p59)
    end
    for v63, v64 in ipairs(p58) do
        local v65
        if p60 then
            v65 = p60[v63]
        else
            v65 = v64.StartValue
        end
        if not v65 then
            if v64.Type == "Catch Falling Beesmas Lights" then
                p60[v63] = 0
                v65 = 0
            else
                v65 = u4[v64.Type].GetStat(v64, p59, true)
            end
        end
        if v64.Type == "Get Score" then
            if p60 then
                p60[v63] = 0
                v65 = 0
            else
                v65 = 0
            end
        end
        local v66 = u4[v64.Type]
        if not v66 then
            local v67 = warn
            local v68 = v64.Type
            v67("No quest task type of name " .. tostring(v68))
        end
        local v69 = v66.GetStat(v64, p59) or 0
        local v70 = v69 - v65
        if v70 < 0 then
            if p60 then
                p60[v63] = v69
            end
            v70 = 0
            if game:GetService("RunService"):IsClient() and p61 then
                require(game.ReplicatedStorage.Events).ClientCall("CompleteQuest", p61)
            end
        end
        local v71 = v64.Amount
        if v71 then
            if type(v71) ~= "number" then
                v71 = v71(p59)
            end
        else
            local v72 = u4[v64.Type]
            v71 = not v72.GetGoal and 1 or v72.GetGoal(v64, p59)
        end
        local v73 = v70 / v71
        v62[v63] = { v73 > 1 and 1 or v73, v70, v71 }
    end
    return v62
end
function u5.Progress(_, p74, p75) --[[Anonymous function at line 514]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    local v76 = u5:GetActiveData(p74, p75)
    if v76 == nil then
        return nil
    else
        local v77 = u5:Get(p74)
        if v77 then
            return u5:GetProgression(v77.Tasks, p75, v76.StartValues, p74)
        else
            return nil
        end
    end
end
function u5.CanComplete(_, p78, p79) --[[Anonymous function at line 533]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    local v80 = u5:Get(p78)
    if not v80 then
        return false
    end
    if v80.Hidden then
        return false
    end
    if not v80.Repeatable and u5:FlaggedComplete(v80.Name, p79) then
        return false
    end
    local v81 = u5:Progress(v80.Name, p79)
    if v81 == nil then
        return false
    end
    for _, v82 in ipairs(v81) do
        if v82[1] < 1 then
            return false
        end
    end
    return true
end
function u5.CheckRequirements(_, p83, p84) --[[Anonymous function at line 591]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u9
    --]]
    local v85 = u5:Get(p83)
    if v85 ~= nil then
        return u9.Check(p84, v85.Requirements)
    end
    warn("there is no quest ", p83, debug.traceback())
    return false
end
function u5.Activate(_, p86, p87, p88) --[[Anonymous function at line 605]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u4
    --]]
    local v89 = u5:Get(p86)
    if not v89 then
        return false
    end
    if not v89.Repeatable and u5:FlaggedComplete(p86, p87) then
        return false
    end
    if u5:GetActiveData(p86, p87) then
        return false
    end
    if not (p88 or u5:CheckRequirements(p86, p87)) then
        return false
    end
    local v90 = u5.ResolveTasks(v89, p87)
    local v91 = {
        ["Name"] = p86,
        ["StartValues"] = {}
    }
    for v92, v93 in ipairs(v90) do
        v91.StartValues[v92] = u4[v93.Type].GetStat(v93, p87, true)
    end
    local v94 = p87.Quests.Active
    table.insert(v94, v91)
    if v89.Pool then
        if not p87.Quests.PoolTimers then
            p87.Quests.PoolTimers = {}
        end
        p87.Quests.PoolTimers[v89.Pool] = require(game.ReplicatedStorage.OsTime)()
    end
    return true
end
function u5.GetStartStatForTask(p95, p96) --[[Anonymous function at line 671]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    return u4[p96.Type].GetStat(p96, p95, true)
end
function u5.GetTaskDescription(p97, p98) --[[Anonymous function at line 678]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    return u4[p98.Type].Description(p98, p97)
end
function u5.GetPoolTimer(_, p99, p100) --[[Anonymous function at line 685]]
    if not p100.Quests.PoolTimers then
        p100.Quests.PoolTimers = {}
    end
    return p100.Quests.PoolTimers[p99] or 0
end
function u5.GetPoolState(_, p101, p102) --[[Anonymous function at line 702]]
    --[[
    Upvalues:
        [1] = u1
        [2] = u5
    --]]
    if not u1.GetPool(p101) then
        print("no such pool: ", p101)
        return nil, "Unqualified"
    end
    local v103 = u5:GetActiveRepeatable(p101, p102)
    if v103 then
        return v103.Name, "Ongoing"
    end
    local v104 = u1.GetPoolCooldown(p101)
    if v104 > 0.01 then
        local v105 = u5:GetPoolTimer(p101, p102)
        local v106 = require(game.ReplicatedStorage.OsTime)() - v105
        if v106 < v104 then
            return nil, "Cooldown", v104 - v106
        end
    end
    local v107 = u1.GetPool(p101)
    if p101 == "Sticker-Seeker" then
        print("poolQuests", v107)
    end
    for _, v108 in ipairs(v107) do
        if u5:CheckRequirements(v108, p102) then
            if p101 == "Sticker-Seeker" then
                print("i qualify for quest ", v108)
            end
            return nil, "New"
        end
    end
    return nil, "Unqualified"
end
function u5.GiveQuestFromPool(_, p109, p110) --[[Anonymous function at line 773]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u1
    --]]
    local v111, v112, v113 = u5:GetPoolState(p109, p110)
    print("trying to give quest from pool ", p109)
    print("questName", v111, "msg", v112, "info", v113)
    if v112 ~= "New" then
        return false
    end
    local v114 = u1.GetPool(p109)
    local v115 = {}
    for _, v116 in ipairs(v114) do
        if u5:CheckRequirements(v116, p110) then
            table.insert(v115, v116)
        end
    end
    print("valid quests", v115)
    local v117 = #v115
    local v118
    if v117 == 1 then
        v118 = v115[1]
    else
        if not p110.Quests.PoolLastQuests then
            p110.Quests.PoolLastQuests = {}
        end
        local v119 = p110.Quests.PoolLastQuests[p109]
        if not v119 then
            v119 = "none"
        end
        repeat
            v118 = v115[math.random(v117)]
        until v118 ~= v119
    end
    return u5:Activate(v118, p110, true), u5:NameToID(v118), v118
end
function u5.FulfillTasks(_, p120, p121) --[[Anonymous function at line 829]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u4
    --]]
    local v122 = nil
    if type(p120) == "string" then
        v122 = u5:Get(p120)
    elseif type(p120) == "number" then
        v122 = u5:GetByID(p120)
    end
    if v122 then
        local v123 = require(game.ServerStorage.PlayerTools).GetStats(p121)
        if v123 then
            local v124 = u5.ResolveTasks(v122, v123)
            for _, v125 in ipairs(v124) do
                local v126 = u4[v125.Type]
                if v126.Fulfill then
                    v126.Fulfill(v125, p121)
                end
            end
        end
    else
        return
    end
end
function u5.FulfillQuests(_, p127) --[[Anonymous function at line 857]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    print("fulfill quests for player " .. p127.Name)
    local v128 = require(game.ServerStorage.PlayerStatManager):GetStats(p127)
    local v129 = v128.Quests.Active
    for _, v130 in ipairs(v129) do
        u5:FulfillTasks(v130.Name, p127)
    end
    require(game.ServerStorage.PlayerTools).CacheReset(p127, v128)
end
function u5.ConvertFileIDsToNames(_, p131) --[[Anonymous function at line 880]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    local v132 = p131.Quests
    for _, v133 in ipairs(v132.Active) do
        v133.Name = u5:IDToName(v133.ID)
        v133.ID = nil
    end
    local v134 = {}
    for _, v135 in ipairs(v132.Completed) do
        local v136 = u5
        table.insert(v134, v136:IDToName(v135))
    end
    v132.Completed = v134
end
function u5.CleanStats(_, _) --[[Anonymous function at line 903]] end
return u5

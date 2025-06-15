local u1 = {}
game:GetService("TweenService")
local u2 = {}
function u1.GetPlayerCollectiblePositionsByTag(p3) --[[Anonymous function at line 12]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    return u2[p3]
end
local v4 = script:GetChildren()
local v5 = {
    "Validate",
    "Effect",
    "Description",
    "Visuals",
    "Sound"
}
local function v6() --[[Anonymous function at line 20]]
    return nil
end
local u7 = {}
for _, v8 in ipairs(v4) do
    if v8:IsA("ModuleScript") then
        local v9 = require(v8)
        v9.Name = v8.Name
        for _, v10 in ipairs(v5) do
            if v9[v10] == nil then
                v9[v10] = v6
            end
        end
        u7[v8.Name] = v9
    end
end
function u1.CategoryOf(p11) --[[Anonymous function at line 49]]
    --[[
    Upvalues:
        [1] = u7
    --]]
    if p11.Type then
        return u7[p11.Type]
    end
    for _, v12 in pairs(u7) do
        if v12.Validate(p11) then
            return v12
        end
    end
    return nil
end
for _, u13 in ipairs(v5) do
    u1[u13] = function(p14, p15) --[[Anonymous function at line 65]]
        --[[
        Upvalues:
            [1] = u1
            [2] = u13
        --]]
        local v16 = u1.CategoryOf(p14)
        if v16 == nil then
            return nil
        else
            return v16[u13](p14, p15)
        end
    end
end
local u17 = {}
local u18 = 0
local function u21(p19) --[[Anonymous function at line 93]]
    local v20 = p19.Targets
    if not v20 then
        if p19.Target then
            return { p19.Target }
        end
        v20 = require(game.ServerStorage.PlayerTools).GetPlayers()
    end
    return v20
end
function u1.GetTargets(p22) --[[Anonymous function at line 108]]
    --[[
    Upvalues:
        [1] = u21
    --]]
    return u21(p22)
end
function u1.GetVisuals(p23) --[[Anonymous function at line 113]]
    --[[
    Upvalues:
        [1] = u1
    --]]
    local v24 = u1.CategoryOf(p23)
    if v24 == nil then
        return nil
    else
        return v24.Visuals(p23)
    end
end
function u1.Make(p25) --[[Anonymous function at line 125]]
    --[[
    Upvalues:
        [1] = u1
        [2] = u18
        [3] = u21
        [4] = u17
    --]]
    local v26 = u1.CategoryOf(p25)
    if v26 == nil then
        return nil
    end
    local v27 = {
        ["IsActive"] = true,
        ["ID"] = u18,
        ["Def"] = p25,
        ["Target"] = p25.Target,
        ["Targets"] = p25.Targets,
        ["Collected"] = false,
        ["OnCollect"] = p25.OnCollect,
        ["Start"] = tick(),
        ["GetTargets"] = u21
    }
    u18 = u18 + 1
    for v28, v29 in pairs(p25) do
        v27[v28] = v29
    end
    if not v27.Permanent then
        if not v27.Dur then
            v27.Dur = 10
        end
        v27.DespawnTime = tick() + v27.Dur
    end
    if v27.Item then
        if v27.Item.Category == "Eggs" then
            local v30 = require(game.ReplicatedStorage.EggTypes).Get(v27.Item.Type)
            if v30 then
                local v31 = true
                if v27.Tags then
                    for _, v32 in ipairs(v27.Tags) do
                        if v32 == v30.DisplayName then
                            v31 = false
                            break
                        end
                    end
                else
                    v27.Tags = {}
                end
                if v31 then
                    local v33 = v27.Tags
                    local v34 = v30.DisplayName
                    table.insert(v33, v34)
                end
            end
        elseif v27.Item.Category == "Sticker" then
            if not v27.Tags then
                v27.Tags = {}
            end
            local v35 = true
            for _, v36 in ipairs(v27.Tags) do
                if v36 == "Sticker" then
                    v35 = false
                    break
                end
            end
            if v35 then
                local v37 = v27.Tags
                table.insert(v37, "Sticker")
            end
        end
        if v27.Item.TreasureID ~= nil then
            v27.TreasureID = v27.Item.TreasureID
        end
        if v27.Item.Tags then
            if not v27.Tags then
                v27.Tags = {}
            end
            for _, v38 in ipairs(v27.Item.Tags) do
                local v39 = v27.Tags
                table.insert(v39, v38)
            end
        end
        if v27.Item.AlwaysCollect then
            v27.AlwaysCollect = true
        end
    end
    local v40 = p25.Color
    local v41 = p25.Icon
    local v42 = p25.IconColor
    local v43, v44, v45
    if v40 == nil or (v41 == nil or v42 == nil) then
        local v46, v47
        v43, v44, v45, v46, v47 = v26.Visuals(p25)
        if v40 ~= nil then
            v43 = v40
        end
        if v41 ~= nil then
            v44 = v41
        end
        if v42 ~= nil then
            v45 = v42
        end
        if v46 then
            v27.Glow = true
        end
        if v47 then
            v27.Sparkles = true
        end
    else
        v45 = v42
        v44 = v41
        v43 = v40
    end
    if v43 == nil then
        v43 = Color3.new(0, 0, 0)
    end
    local v48 = v44 == nil and "rbxassetid://107187190" or v44
    local v49 = {
        ["ID"] = v27.ID,
        ["Pos"] = v27.Pos,
        ["SpawnTime"] = tick(),
        ["Dur"] = v27.Dur,
        ["Color"] = v43,
        ["Icon"] = v48,
        ["IconColor"] = v45,
        ["Glow"] = v27.Glow or nil,
        ["Sparkles"] = v27.Sparkles or nil,
        ["SilentSpawn"] = v27.SilentSpawn or nil
    }
    if v27.Rainbow or v27.Item and v27.Item.Category == "Sticker" then
        v49.Rainbow = true
    end
    if v27.Item and v27.Item.Type == "GamesEventShine" then
        v49.Transparent = true
    end
    if v27.TreasureID then
        v49.TreasureID = v27.TreasureID
    end
    v27.SpawnParams = v49
    local v50 = u21(v27)
    local v51 = require(game.ReplicatedStorage.Events)
    for _, v52 in ipairs(v50) do
        if v52.Parent then
            v51.ServerCall("CollectibleEvent", v52, "Spawn", v49)
        end
    end
    local v53 = u17
    table.insert(v53, v27)
    return v27
end
function u1.Destroy(p54, p55) --[[Anonymous function at line 307]]
    --[[
    Upvalues:
        [1] = u1
        [2] = u21
    --]]
    if p54.IsActive then
        if p54.AlwaysCollect then
            print("DESTROYING an ALWAYS COLLECT collectible", p54)
        end
        if p54.AlwaysCollect and (not p54.Collected and (p54.Target or p54.Targets and #p54.Targets >= 1)) then
            print("forcing player to collect ", p54)
            u1.Collect(p54, u21(p54)[1])
        else
            p54.IsActive = false
            local v56 = u21(p54)
            if not p55 then
                local v57 = require(game.ReplicatedStorage.Events)
                for _, v58 in ipairs(v56) do
                    if v58.Parent then
                        v57.ServerCall("CollectibleEvent", v58, "Destroy", p54.ID)
                    end
                end
            end
            if p54.RespawnDelay then
                local u59 = p54.Def
                spawn(function() --[[Anonymous function at line 338]]
                    --[[
                    Upvalues:
                        [1] = u59
                        [2] = u1
                    --]]
                    wait(u59.RespawnDelay)
                    u1.Make(u59)
                end)
            end
        end
    else
        return
    end
end
function u1.GetLastCollectedPositionByTag(p60, p61) --[[Anonymous function at line 350]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    local v62 = u2[p60]
    if v62 then
        return v62[p61]
    else
        return nil
    end
end
function u1.Collect(p63, p64) --[[Anonymous function at line 358]]
    return require(game.ServerStorage.CollectiblesServer).Collect(p63, p64)
end
function u1.FetchForTarget(p65) --[[Anonymous function at line 367]]
    --[[
    Upvalues:
        [1] = u17
    --]]
    local v66 = {}
    for _, v67 in ipairs(u17) do
        local v68 = v67.Targets
        if v67.Target == p65 or v68 ~= nil and (#v68 == 1 and v68[1] == p65) then
            table.insert(v66, v67)
        end
    end
    return v66
end
function u1.GetActiveCollectibles() --[[Anonymous function at line 385]]
    --[[
    Upvalues:
        [1] = u17
    --]]
    return u17
end
function u1.FetchValidForTarget(p69) --[[Anonymous function at line 392]]
    --[[
    Upvalues:
        [1] = u17
    --]]
    local v70 = {}
    for _, v71 in ipairs(u17) do
        local v72 = v71.Targets
        local v73 = v72 == nil
        if not v73 then
            for _, v74 in ipairs(v72) do
                if v74 == p69 then
                    v73 = true
                    break
                end
            end
        end
        if v73 then
            table.insert(v70, v71)
        end
    end
    return v70
end
local function u91() --[[Anonymous function at line 425]]
    --[[
    Upvalues:
        [1] = u17
        [2] = u21
        [3] = u1
    --]]
    if #u17 > 0 then
        local v75, v76 = require(game.ServerStorage.PlayerTools).GetPositions()
        tick()
        local v77 = 0
        local v78 = {}
        for _, v79 in ipairs(u17) do
            if v79.IsActive then
                local v80 = u21(v79)
                if v80 == nil then
                    v80 = v76
                end
                local v81 = v79.Pos
                local v82 = nil
                local v83 = false
                for _, v84 in ipairs(v80) do
                    local v85 = v75[v84]
                    if v85 then
                        v83 = true
                        local v86 = v85 - v81
                        if v86:Dot(v86) < 25 then
                            if v82 then
                                table.insert(v82, v84)
                            else
                                v82 = { v84 }
                            end
                        end
                    end
                end
                if v82 then
                    local v87
                    if #v82 > 1 then
                        v87 = v82[math.random(#v82)]
                    else
                        v87 = v82[1]
                    end
                    local v88 = v75[v87]
                    local v89
                    if v88 then
                        v89 = require(game.ServerStorage.CollectiblesServer).RegisterCollect(v87, v88, nil, v79)
                    else
                        v89 = false
                    end
                    if v89 then
                        u1.Collect(v79, v87)
                    end
                end
                if not v79.Collected then
                    if v83 or v79.Permanent then
                        local v90
                        if v79.Permanent or tick() - v79.Start < v79.Dur then
                            v90 = true
                        else
                            u1.Destroy(v79, true)
                            v90 = false
                        end
                        if v90 then
                            v77 = v77 + 1
                            v78[v77] = v79
                        end
                    else
                        u1.Destroy(v79)
                    end
                end
            end
        end
        u17 = v78
    end
end
function u1.Update() --[[Anonymous function at line 537]]
    --[[
    Upvalues:
        [1] = u91
    --]]
    local v92, v93 = pcall(u91)
    if not v92 then
        warn(v93)
    end
end
function u1.InitPlayer(p94) --[[Anonymous function at line 555]]
    --[[
    Upvalues:
        [1] = u2
        [2] = u17
    --]]
    u2[p94] = {}
    local v95 = require(game.ReplicatedStorage.Events)
    for _, v96 in ipairs(u17) do
        local v97 = v96.Targets == nil
        if not v97 and (#v96.Targets == 1 and v96.Targets[1] == p94) and true or v97 then
            v95.ServerCall("CollectibleEvent", p94, "Spawn", v96.SpawnParams)
        end
    end
end
function u1.RemovePlayer(p98) --[[Anonymous function at line 583]]
    --[[
    Upvalues:
        [1] = u1
        [2] = u2
    --]]
    local v99 = u1.FetchForTarget(p98)
    if #v99 > 0 then
        for _, v100 in ipairs(v99) do
            if v100.AlwaysCollect then
                u1.Collect(v100, p98)
            end
        end
    end
    u2[p98] = nil
end
function u1.DestroyBeeAbilitiesForPlayer(p101) --[[Anonymous function at line 604]]
    --[[
    Upvalues:
        [1] = u1
    --]]
    local v102 = u1.FetchForTarget(p101)
    if #v102 > 0 then
        for _, v103 in ipairs(v102) do
            if v103.FromBeeAbility then
                u1.Destroy(v103)
            end
        end
    end
end
return u1

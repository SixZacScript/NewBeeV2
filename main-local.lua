local u1 = {}
local u2 = game:GetService("Players")
local u3 = Instance.new("Folder")
u3.Name = "Planters"
u3.Parent = workspace
local u4 = script.PlanterBulbStart.Size
local u5 = script.PlanterBulb.Size
local u6 = script.PlanterBulbStart.Color
local u7 = script.PlanterBulb.Color
local u8 = Color3.fromRGB(186, 51, 54)
local u9 = {}
local u10 = {}
function u1.AlignPlanterBulb(p11) --[[Anonymous function at line 37]]
    local v12 = p11.PotModel.Soil.BulbAttach.WorldPosition
    local v13 = p11.BulbPart
    local v14 = v13.Size.Y * 0.5
    local v15 = v12 + Vector3.new(0, v14, 0)
    local v16 = v13.CFrame.LookVector
    v13.CFrame = CFrame.new(v15, v15 + v16)
end
function u1.MovePlanter(p17, p18) --[[Anonymous function at line 57]]
    --[[
    Upvalues:
        [1] = u1
    --]]
    if p17.Active then
        p17.Pos = p18
        local _, v19 = p17.PotModel:GetBoundingBox()
        local v20 = p17.PotModel:FindFirstChild("Soil")
        local v21 = 1 + v19.Y
        local v22 = p18 + Vector3.new(0, v21, 0)
        local v23 = v20.CFrame.LookVector
        p17.PotModel:SetPrimaryPartCFrame(CFrame.new(v22, v22 + v23))
        u1.AlignPlanterBulb(p17)
    end
end
function u1.SetPlanterGrowthPercent(p24, p25, _) --[[Anonymous function at line 76]]
    --[[
    Upvalues:
        [1] = u4
        [2] = u5
        [3] = u1
    --]]
    if p24.Active then
        p24.GrowthPercent = math.clamp(p25, 0, 1)
        local v26 = require(game.ReplicatedStorage.PlanterTypes)
        local v27 = v26.Get(p24.Type)
        math.pow(p25, 1.8)
        local v28 = u4:Lerp(u5 * (v27.BulbSizeFactor or 1), p25)
        local v29 = p24.BulbPart
        local v30 = v29.Size
        v29.Size = v28
        u1.AlignPlanterBulb(p24)
        u1.UpdatePlanterColor(p24)
        if p24.IsMine then
            local v31 = p25 * 1000
            local v32 = math.floor(v31) * 0.1
            local v33 = require(game.ReplicatedStorage.Utils.FloatRound)(v32, 2)
            local v34 = v28 / v30
            p24.Gui.Parent.Position = p24.Gui.Parent.Position * v34
            local v35 = tostring(v33)
            if math.floor(v33) == v33 then
                v35 = v35 .. ".0"
            end
            p24.Gui.Bar.TextLabel.Text = v26.Get(p24.Type).DisplayName .. " (" .. v35 .. "%)"
            p24.Gui.Bar.FillBar.Size = UDim2.new(p25, 0, 1, 0)
            if p25 >= 1 then
                p24.Gui.Bar.FillBar.BackgroundColor3 = Color3.fromRGB(31, 231, 68)
            end
        end
    else
        return
    end
end
function u1.UpdatePlanterColor(p36) --[[Anonymous function at line 127]]
    --[[
    Upvalues:
        [1] = u6
        [2] = u7
        [3] = u8
    --]]
    if p36.Active then
        local v37 = u6:Lerp(u7, p36.GrowthPercent)
        local v38 = p36.FieldDeg
        if v38 > 0.01 then
            local v39 = math.pow(v38, 0.4)
            v37 = v37:Lerp(u8, (math.min(v39, 0.8)))
        end
        p36.BulbPart.Color = v37
    end
end
function u1.LoadPlanter(p40, p41, p42, p43, p44, p45, p46, p47) --[[Anonymous function at line 159]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u1
        [3] = u2
        [4] = u10
        [5] = u3
        [6] = u9
    --]]
    local u48 = {
        ["Active"] = true,
        ["Pos"] = nil,
        ["IsMine"] = false,
        ["ActorID"] = p40,
        ["Owner"] = p41,
        ["Type"] = p43,
        ["GrowthPercent"] = -1,
        ["FieldDeg"] = p45 or 0,
        ["Glittered"] = p46 or false,
        ["Puffshroom"] = p47 or false,
        ["PotModel"] = nil,
        ["BulbPart"] = nil,
        ["Gui"] = nil,
        ["PotModel"] = require(game.ReplicatedStorage.PlanterTypes).Get(p43).PotModel:Clone()
    }
    u48.PotModel.PrimaryPart = u48.PotModel.Soil
    local v49 = u48.PotModel:FindFirstChild("RainbowTag", true)
    if v49 then
        local v50 = v49.Parent
        require(game.ReplicatedStorage.RainbowPartAnimator).AddPart(v50, {
            ["SkipParticles"] = true
        })
    end
    local v51 = script.PlanterBulb:Clone()
    v51.Size = u5
    u48.BulbPart = v51
    local u52 = Instance.new("NumberValue")
    u52.Name = "GrowthPercent"
    u52.Value = p44
    u52:GetPropertyChangedSignal("Value"):Connect(function() --[[Anonymous function at line 230]]
        --[[
        Upvalues:
            [1] = u1
            [2] = u48
            [3] = u52
        --]]
        u1.SetPlanterGrowthPercent(u48, u52.Value)
    end)
    u52.Parent = u48.BulbPart
    u48.IsMine = u2.LocalPlayer == p41
    if u48.IsMine then
        u48.Gui = u48.BulbPart["Gui Attach"]["Planter Gui"]
        local v53 = u10
        table.insert(v53, u48)
    else
        v51["Gui Attach"]:Destroy()
    end
    u1.MovePlanter(u48, p42)
    u1.SetPlanterGrowthPercent(u48, p44)
    u48.PotModel.Parent = u3
    u48.BulbPart.Parent = u3
    if p46 then
        u48.BulbPart.Sparkles.Enabled = true
    end
    if p47 then
        u48.BulbPart.PuffshroomSpores.Enabled = true
    end
    u9[p40] = u48
end
function u1.UnloadPlanter(p54) --[[Anonymous function at line 275]]
    --[[
    Upvalues:
        [1] = u9
        [2] = u10
    --]]
    local v55 = u9[p54]
    if v55 then
        if v55.Active then
            v55.Active = nil
            v55.BulbPart:Destroy()
            v55.PotModel:Destroy()
            u9[v55.ActorID] = nil
            local v56 = {}
            for _, v57 in ipairs(u10) do
                if v57.ActorID ~= p54 then
                    table.insert(v56, v57)
                end
            end
            u10 = v56
        end
    else
        return
    end
end
function u1.UpdatePlanter(p58, p59, p60) --[[Anonymous function at line 298]]
    --[[
    Upvalues:
        [1] = u9
        [2] = u1
    --]]
    local v61 = u9[p58]
    if v61 then
        if v61.Active then
            v61.Glittered = v61.Glittered or p60
            u1.SetPlanterGrowthPercent(v61, p59)
        end
    else
        return
    end
end
function u1.RegisterListeners() --[[Anonymous function at line 312]]
    --[[
    Upvalues:
        [1] = u1
        [2] = u9
    --]]
    local v62 = require(game.ReplicatedStorage.Events)
    v62.ClientListen("PlanterModelLoad", function(p63, p64, p65, p66, p67, p68, p69, p70) --[[Anonymous function at line 318]]
        --[[
        Upvalues:
            [1] = u1
        --]]
        u1.LoadPlanter(p63, p64, p65, p66, p67, p68, p69, p70)
    end)
    v62.ClientListen("PlanterModelUnload", function(p71) --[[Anonymous function at line 322]]
        --[[
        Upvalues:
            [1] = u1
        --]]
        u1.UnloadPlanter(p71)
    end)
    local u72 = game:GetService("TweenService")
    local u73 = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    v62.ClientListen("PlanterModelGrow", function(p74, p75, p76, p77, p78) --[[Anonymous function at line 329]]
        --[[
        Upvalues:
            [1] = u9
            [2] = u72
            [3] = u73
        --]]
        local v79 = u9[p74]
        if v79 and v79.Active then
            if p76 and not v79.BulbPart.Sparkles.Enabled then
                v79.BulbPart.Sparkles.Enabled = true
            end
            if p78 then
                v79.BulbPart.PuffshroomSpores.Enabled = true
            end
            if p75 then
                v79.FieldDeg = p77
                u72:Create(v79.BulbPart.GrowthPercent, u73, {
                    ["Value"] = p75
                }):Play()
            end
        else
            return
        end
    end)
end
function u1.AnimatePlacement(_) --[[Anonymous function at line 376]] end
function u1.AnimateCollection(_) --[[Anonymous function at line 380]] end
function u1.CheckForNearbyHarvestablePlanters(p80, p81) --[[Anonymous function at line 387]]
    --[[
    Upvalues:
        [1] = u10
    --]]
    local v82 = not p81 and 144 or p81 * p81
    for _, v83 in ipairs(u10) do
        if v83.Active and (not v83.Collected and v83.GrowthPercent >= 0.00005) then
            local v84 = p80 - v83.Pos
            if v84:Dot(v84) <= v82 then
                return v83
            end
        end
    end
    return nil
end
function u1.PromptCollect(p85) --[[Anonymous function at line 410]]
    --[[
    Upvalues:
        [1] = u9
    --]]
    local v86 = u9[p85]
    if v86 and v86.Active then
        if v86.Collected then
            return false
        elseif require(game.ReplicatedStorage.ClientStatTools).CheckIfRoboBearChallengeRoundIsRunning() then
            return
        elseif v86.GrowthPercent >= 1 or require(game.ReplicatedStorage.Gui.QuestionBox).Ask("Harvest the Planter before it\'s done growing?") then
            v86.Collected = true
            require(game.ReplicatedStorage.Events).ClientCall("PlanterModelCollect", p85)
        end
    else
        return false
    end
end
return u1

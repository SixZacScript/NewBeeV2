local ModuleLoaderHelper = {}
local loadedModules = {}
-- local WP = game:GetService("Workspace")
-- local lader = Instance.new('TrussPart',WP)
-- lader.CFrame = CFrame.new(60, 4.5, 217.352615, -4.37113883e-08, -1, 0, 1, -4.37113883e-08, 0, 0, 0, 1)
-- lader.Anchored = true
-- lader.Size = Vector3.new(25.5, 5, 5)



-- local function applyModifiersToParts(parent)
--     for _, part in pairs(parent:GetDescendants()) do
--         if part:IsA("BasePart") then
--             -- Remove old modifier if exists
--             local oldMod = part:FindFirstChildOfClass("PathfindingModifier")
--             if oldMod then oldMod:Destroy() end
            
--             local modifier = Instance.new("PathfindingModifier")
--             modifier.PassThrough = true
--             modifier.Parent = part
            
--             part.CanQuery = false
--             part.CanCollide = false
--         end
--     end
-- end

-- local function findTarget(parent, targetName)
--     local target = parent:FindFirstChild(targetName)
--     if target then return target end
--     return parent:FindFirstChild(targetName, true)
-- end

-- local targets = {"Territories", "Flowers", "FlowerZones", "Gates", "Decorations", "Fences", "Walls"}
-- for _, targetName in ipairs(targets) do
--     local target = findTarget(WP, targetName)
--     if target then
--         applyModifiersToParts(target)
--     else
--         warn("Target '" .. targetName .. "' not found in WP")
--     end
-- end


function ModuleLoaderHelper:destroy(path)
    local module = loadedModules[path]
    if module and typeof(module.destroy) == "function" then
        pcall(function() module:destroy() end)
    end
    loadedModules[path] = nil
end

function ModuleLoaderHelper:load(path)
    self:destroy(path)
    if _G.isGithub then
        loadedModules[path] = loadstring(game:HttpGet(path))()
    else
        loadedModules[path] = loadstring(readfile(path))()
    end
    return loadedModules[path]
end

function ModuleLoaderHelper:get(path)
    return loadedModules[path]
end

function ModuleLoaderHelper:destroyAll()
    for path, module in pairs(loadedModules) do
        if module and typeof(module.destroy) == "function" then
            pcall(function() module:destroy() end)
        end
        loadedModules[path] = nil
    end
end
return ModuleLoaderHelper

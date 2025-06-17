local ModuleLoaderHelper = {}
local loadedModules = {}

function ModuleLoaderHelper:destroy(path)
    local module = loadedModules[path]
    if module and typeof(module.destroy) == "function" then
        pcall(function() module:destroy() end)
    end
    loadedModules[path] = nil
end

function ModuleLoaderHelper:load(path)
    self:destroy(path)
    local result = game:HttpGet(path)
    if not result then
        warn("Failed to load module: " .. path)
        return nil
    end

    local chunk, err = loadstring(result)
    if not chunk then
        warn("Failed to compile module: " .. path .. " | " .. tostring(err))
        return nil
    end

    loadedModules[path] = chunk()
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

function ModuleLoaderHelper:waitForLoad(count)
    repeat
        task.wait()
        print(self:getLoadedCount())
    until self:getLoadedCount() >= count
end

function ModuleLoaderHelper:getLoadedCount()
    local total = 0
    for _ in pairs(loadedModules) do
        total += 1
    end
    return total
end

return ModuleLoaderHelper

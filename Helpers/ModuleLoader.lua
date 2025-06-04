-- ModuleLoaderHelper.lua

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
    loadedModules[path] = loadstring(readfile(path))()
    return loadedModules[path]
end

function ModuleLoaderHelper:get(path)
    return loadedModules[path]
end

return ModuleLoaderHelper

-- ModuleLoaderHelper.lua
local url = "https://raw.githubusercontent.com/SixZacScript/NewBeeV2/refs/heads/master/"

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

function ModuleLoaderHelper:destroyAll()
    for path, module in pairs(loadedModules) do
        if module and typeof(module.destroy) == "function" then
            pcall(function() module:destroy() end)
        end
        loadedModules[path] = nil
    end
end
return ModuleLoaderHelper

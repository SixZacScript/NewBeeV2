local FluentUI = {}
FluentUI.__index = FluentUI

local FLUENT_URL =
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
local DEFAULT_CONFIG = {
    Title = "Bee Swarm",
    SubTitle = "by SixZac",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    ToggleKey = Enum.KeyCode.LeftControl
}

local FluentLibrary = nil

local function getFluentLibrary()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
    if not FluentLibrary then
        local success, result = pcall(function()
            return loadstring(game:HttpGet(FLUENT_URL))()
        end)

        if success then
            FluentLibrary = result
        else
            error("Failed to load Fluent library: " .. tostring(result))
        end
    end
    return FluentLibrary
end

function FluentUI.new(config)
    local self = setmetatable({}, FluentUI)

    config = config or {}
    for key, value in pairs(DEFAULT_CONFIG) do
        if config[key] == nil then config[key] = value end
    end

    self.currentToggleKey = config.ToggleKey

    self.Fluent = getFluentLibrary()

    self.Window = self.Fluent:CreateWindow({
        Title = config.Title .. " " .. self.Fluent.Version,
        SubTitle = config.SubTitle,
        TabWidth = config.TabWidth,
        Size = config.Size,
        Acrylic = config.Acrylic,
        Theme = config.Theme,
        MinimizeKey = self.currentToggleKey
    })

    self.Options = self.Fluent.Options
    self.Tabs = {}

    self:createDefaultTabs()
    self:initMainTab()
    self.Window:SelectTab(1)

    return self
end

function FluentUI:createDefaultTabs()
    self.Tabs.Main = self.Window:AddTab({Title = "Main", Icon = "home"})
    self.Tabs.Settings = self.Window:AddTab({
        Title = "Settings",
        Icon = "settings"
    })
end

function FluentUI:initMainTab()
    local weakSelf = setmetatable({self}, {__mode = "v"})
    self.FieldDropdown = self.Tabs.Main:AddDropdown("FieldDropdown", {
        Title = "Select Field",
        Values = shared.helper.Field:getAllFieldDisplayNames(),
        Multi = false,
        Default = 1,
    })
    self.autoFarmToggle = self.Tabs.Main:AddToggle("autoFarm", {
        Title = "Auto Farm",
        Default = false
    })

    
    -- ==================================
    self.autoFarmToggle:OnChanged(function()
        local instance = weakSelf[1]
        if instance and instance.Options then
            print("Auto Farm toggled:", instance.Options.autoFarm.Value)
        end
    end)
   self.FieldDropdown:OnChanged(function(value)
        self:onFieldChange(value)
    end)

end


function FluentUI:addTab(name, config)
    if self.Tabs[name] then
        warn("Tab '" .. name .. "' already exists")
        return self.Tabs[name]
    end

    self.Tabs[name] = self.Window:AddTab(config)
    return self.Tabs[name]
end

function FluentUI:isAutoFarmEnabled()
    return self.Options and self.Options.autoFarm and
               self.Options.autoFarm.Value or false
end

function FluentUI:setAutoFarm(enabled)
    if self.autoFarmToggle then self.autoFarmToggle:SetValue(enabled) end
end
function FluentUI:onFieldChange(field)
   shared.helper.Field:SetCurrentField(field)
    
end
function FluentUI:destroy()

    if self.autoFarmToggle then self.autoFarmToggle = nil end

    if self.toggleKeyBind then self.toggleKeyBind = nil end

    for name, _ in pairs(self.Tabs) do self.Tabs[name] = nil end

    self.Options = nil
    self.Window = nil
    self.Fluent = nil
    self.Tabs = nil
    self.currentToggleKey = nil
end

return FluentUI

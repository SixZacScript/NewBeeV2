shared.ModuleLoader = loadstring(readfile('NewBeeV2/Helpers/ModuleLoader.lua'))()

shared.helper = shared.helper or {}
shared.main = shared.main or {}

-- Load modules
local FluentModule = shared.ModuleLoader:load("NewBeeV2/UI/Window.lua")
local PlayerModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Player.lua")
local HiveModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Hive.lua")
local FieldModule = shared.ModuleLoader:load("NewBeeV2/Helpers/Field.lua")
local BotModule = shared.ModuleLoader:load("NewBeeV2/Class/Bot.lua")

shared.helper.Field = FieldModule.new() -- init first
shared.Fluent = FluentModule.new()

-- Helpers
shared.helper.Player = PlayerModule.new()
shared.helper.Hive = HiveModule.new()

-- Class
shared.Bot = BotModule.new()

-- Main
shared.main.Hive = shared.helper.Hive:initHive()


shared.Bot:start()  

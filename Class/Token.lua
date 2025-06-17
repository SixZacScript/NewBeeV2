local TokenDataModule = shared.ModuleLoader:load(_G.URL.."/Data/Tokens.lua")
local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local Events = Rep.Events
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local CollectiblesDisplayFolder = Instance.new("Folder")
CollectiblesDisplayFolder.Name = "ActiveCollectiblesDisplay"
CollectiblesDisplayFolder.Parent = Workspace

-- Enhanced configuration system
local CONFIG = {
    -- Visual settings
    COLORS = {
        GOLD = Color3.fromRGB(255, 216, 21),
        YELLOW = Color3.fromRGB(255, 238, 0),
        GREEN = Color3.fromRGB(0, 255, 0),
        RED = Color3.fromRGB(255, 0, 0),
        WHITE = Color3.fromRGB(255, 255, 255),
        BUBBLE_DEFAULT = Color3.fromRGB(100, 150, 255),
    },
    
    -- Field and region settings
    FIELD = {
        EXPAND_BY = 3,
        HEIGHT = 13,
        CHECK_BOUNDS = true,
    },
    
    -- Token behavior settings
    TOKEN = {
        defaultSIZE = Vector3.new(2,2,2),
        VISUALIZATION_LIFETIME = 15,
        HIGH_PRIORITY_THRESHOLD = 80,
        MAX_RETRY_ATTEMPTS = 3,
        CLEANUP_DELAY = 1,
        SELECTION_BOX_THICKNESS = 0.05,
        SELECTION_BOX_TRANSPARENCY = 1,
        SIMPART_TRANSPARENCY = 1,
        AUTO_CLEANUP_INTERVAL = 30, -- seconds
    },
    
    -- Bubble settings
    BUBBLE = {
        GOLD_PRIORITY = 8,
        NORMAL_PRIORITY = 6,
        LIFETIME = 4,
        SIZE = Vector3.new(10,10,10),
    },
    
    -- Smart scoring system
    SCORING = {
        SMART_GET_NEAR_SKILL_TOKEN_BOOST = 100.0,
        CLUSTER_RADIUS = 15,
        BLOCK_RAYCAST_SCORE = 500.0,
        PRIORITY_WEIGHTS = {
            distance = 2.0,
            priority = 1.5,
            age = 0.5,
            accessibility = 3.0,
            clustering = 1.5,
        },
    },
    
    -- Performance settings
    PERFORMANCE = {
        MAX_ACTIVE_TOKENS = 100,
        CLEANUP_BATCH_SIZE = 10,
        UPDATE_FREQUENCY = 0.1, -- seconds between updates
    },
    
    -- File settings
    FILES = {
        UNKNOWN_TOKENS = "UnknownTokens.json",
        TOKEN_DATA = "tokenData.json",
        CONFIG_FILE = "TokenHelperConfig.json",
    },
    
    -- Debug settings
    DEBUG = {
        ENABLED = false,
        LOG_TOKEN_EVENTS = false,
        LOG_PERFORMANCE = false,
    },
}

-- Token class with improved memory management
local Token = {}
Token.__index = Token

function Token.new(id, name, instance, priority, isSkill, position)
    local self = setmetatable({
        id = id or 0,
        name = name or "Unknown",
        instance = instance,
        priority = priority or 1,
        isSkill = isSkill or false,
        position = position,
        touched = false,
        spawnTime = tick(),
        maxTry = CONFIG.TOKEN.MAX_RETRY_ATTEMPTS,
        currentTry = 0,
        _connections = {},
        _cleanupScheduled = false,
    }, Token)

    if instance then
        self:_setupSelectionBox()
        self:_setupTouchHandler()
    end

    return self
end

function Token:_setupSelectionBox()
    if not self.instance then return end
    
    local box = Instance.new("SelectionBox")
    box.Name = "TokenSelectionBox"
    box.Adornee = self.instance
    box.LineThickness = CONFIG.TOKEN.SELECTION_BOX_THICKNESS
    box.SurfaceColor3 = CONFIG.COLORS.GREEN
    box.Color3 = CONFIG.COLORS.GREEN
    box.SurfaceTransparency = CONFIG.TOKEN.SELECTION_BOX_TRANSPARENCY
    box.Transparency = CONFIG.TOKEN.SELECTION_BOX_TRANSPARENCY
    box.Parent = self.instance
    
    self.selectionBox = box
end

function Token:_setupTouchHandler()
    if not self.instance then return end
    
    local connection = self.instance.Touched:Connect(function()
        self:_onTouched()
    end)
    
    table.insert(self._connections, connection)
end

function Token:_onTouched()
    if self.selectionBox then
        self.selectionBox.Color3 = CONFIG.COLORS.RED
        self.selectionBox.SurfaceColor3 = CONFIG.COLORS.RED
    end
    
    self.touched = true
    
    if not self._cleanupScheduled then
        self._cleanupScheduled = true
        task.spawn(function()
            task.wait(CONFIG.TOKEN.CLEANUP_DELAY)
            if self.instance and self.instance:IsDescendantOf(workspace) then
                if self.selectionBox then
                    self.selectionBox.SurfaceColor3 = CONFIG.COLORS.YELLOW
                    self.selectionBox.Color3 = CONFIG.COLORS.YELLOW
                end
                self.touched = false
            end
            self._cleanupScheduled = false
        end)
    end
end

function Token:cleanup()
    -- Disconnect all connections
    for _, connection in ipairs(self._connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self._connections = {}
    
    -- Clean up selection box
    if self.selectionBox then
        self.selectionBox:Destroy()
        self.selectionBox = nil
    end
    
    -- Clean up instance
    if self.instance then
        self.instance:Destroy()
        self.instance = nil
    end
    
    -- Clear references
    self.position = nil
    self._cleanupScheduled = false
end

function Token:isValid()
    return self.instance and self.instance.Parent and not self.touched and self.tokenField == shared.Bot.currentField
end



-- Enhanced TokenHelper with memory leak prevention
local TokenHelper = {}
TokenHelper.__index = TokenHelper

function TokenHelper.new(bot)
    local self = setmetatable({}, TokenHelper)
    self.bot = bot
    self.player = shared.helper.Player
    self.useSimpleDistanceLogic = false
    self.activeTokens = {}
    self.collectedTokenData = {}
    self._connections = {}
    self._lastCleanup = tick()
    self._updateConnection = nil
    
    self:_loadConfig()
    self:initialize()
    self:_startPeriodicCleanup()
    
    return self
end

function TokenHelper:_loadConfig()
    -- Load user configuration if it exists
    if isfile(CONFIG.FILES.CONFIG_FILE) then
        local success, userConfig = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG.FILES.CONFIG_FILE))
        end)
        
        if success and userConfig then
            self:_mergeConfig(CONFIG, userConfig)
        end
    end
end

function TokenHelper:getTokensByField(field)
    if not field  then return {} end

    local tokensInField = {}
    for _, token in pairs(self.activeTokens) do
        if token.tokenField == field then
            table.insert(tokensInField, token)
        end
    end

    return tokensInField
end

function TokenHelper:_mergeConfig(base, override)
    for key, value in pairs(override) do
        if type(value) == "table" and type(base[key]) == "table" then
            self:_mergeConfig(base[key], value)
        else
            base[key] = value
        end
    end
end

function TokenHelper:initialize()
    self:setupTokenHandling()
    self:setupBubbleHandling()
    
    if CONFIG.DEBUG.ENABLED then
        print("[TokenHelper] Initialized with config:", HttpService:JSONEncode(CONFIG))
    end
end

function TokenHelper:_startPeriodicCleanup()
    self._updateConnection = RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - self._lastCleanup >= CONFIG.TOKEN.AUTO_CLEANUP_INTERVAL then
            self:_performPeriodicCleanup()
            self._lastCleanup = now
        end
    end)
end

function TokenHelper:_performPeriodicCleanup()
    local cleaned = 0
    local toRemove = {}
    
    for serverID, token in pairs(self.activeTokens) do
        if not token:isValid() or (tick() - token.spawnTime) > CONFIG.TOKEN.VISUALIZATION_LIFETIME then
            table.insert(toRemove, serverID)
            cleaned = cleaned + 1
            
            if cleaned >= CONFIG.PERFORMANCE.CLEANUP_BATCH_SIZE then
                break
            end
        end
    end
    
    for _, serverID in ipairs(toRemove) do
        self:removeToken(serverID)
    end
    
    if CONFIG.DEBUG.LOG_PERFORMANCE and cleaned > 0 then
        print(string.format("[TokenHelper] Cleaned up %d tokens, %d active", cleaned, self:getActiveTokenCount()))
    end
end

function TokenHelper:createSimPart(position, color, name)
    local isBubble = name == "Bubble"
    local simToken = Instance.new("Part")
    simToken.Size = isBubble and CONFIG.BUBBLE.SIZE or CONFIG.TOKEN.defaultSIZE
    simToken.Position = position
    simToken.Color = color or CONFIG.COLORS.WHITE
    simToken.Anchored = true
    simToken.CanTouch = true
    simToken.Shape = isBubble and Enum.PartType.Ball or Enum.PartType.Ball 
    simToken.CanCollide = false
    simToken.Transparency = CONFIG.TOKEN.SIMPART_TRANSPARENCY
    simToken.Name = name or "Token"
    simToken.Parent = CollectiblesDisplayFolder
    return simToken
end

function TokenHelper:removeToken(tokenServerID)
    local token = self.activeTokens[tokenServerID]
    if token then
        token:cleanup()
        self.activeTokens[tokenServerID] = nil
        
        if CONFIG.DEBUG.LOG_TOKEN_EVENTS then
            print(string.format("[TokenHelper] Removed token %s", tostring(tokenServerID)))
        end
    end
end

function TokenHelper:setupBubbleHandling()
    local Event = Rep.Events.LocalFX
    
    local connection = Event.OnClientEvent:Connect(function(type, data)
        if type == "Bubble" and data.Action == "Spawn" then
            self:_handleBubbleSpawn(data)
        elseif type == "Bubble" and data.Action == "Pop" then
            self:_handleBubblePop(data)
        end
    end)
    
    table.insert(self._connections, connection)
end

function TokenHelper:_handleBubbleSpawn(data)
    local position = data.Pos
    local serverID = data.ID
    
    if not self:isPositionInBounds(position, shared.Bot.currentField) then return end
    if self:getActiveTokenCount() >= CONFIG.PERFORMANCE.MAX_ACTIVE_TOKENS then return end
    
    local simPart = self:createSimPart(position, CONFIG.COLORS.BUBBLE_DEFAULT, "Bubble")
    local gameToken = Token.new(serverID, "Bubble", simPart, CONFIG.BUBBLE.NORMAL_PRIORITY, false, position)
    self.activeTokens[serverID] = gameToken
    
    -- Schedule automatic cleanup
    task.delay(CONFIG.BUBBLE.LIFETIME, function()
        self:removeToken(serverID)
    end)
    
    if CONFIG.DEBUG.LOG_TOKEN_EVENTS then
        print(string.format("[TokenHelper] Spawned bubble %s at %s", tostring(serverID), tostring(position)))
    end
end

function TokenHelper:_handleBubblePop(data)
    local serverID = data.ID
    if self.activeTokens[serverID] then
        self:removeToken(serverID)
    end
end

function TokenHelper:setupTokenHandling()
    local connection = Events.CollectibleEvent.OnClientEvent:Connect(function(action, tokenParams)
        if action == "Spawn" then
            self:_handleTokenSpawn(tokenParams)
        elseif action == "Collect" then
            self:_handleTokenCollect(tokenParams)
        else
            warn("[TokenHelper] Unknown action:", action)
        end
    end)
    
    table.insert(self._connections, connection)
end

function TokenHelper:_handleTokenSpawn(tokenParams)
    local position = tokenParams.Pos
    local color = tokenParams.Color
    local serverID = tokenParams.ID
    local icon = tokenParams.Icon
    local duration = tokenParams.Dur
    
    if self:getActiveTokenCount() >= CONFIG.PERFORMANCE.MAX_ACTIVE_TOKENS then return end
    
    local assetID = self:extractAssetID(icon)
    local name, tokenData = TokenDataModule:getTokenById(assetID)

    local simPart = self:createSimPart(position, color, name)
    local gameToken = Token.new(
        tokenData.id,
        name,
        simPart,
        tokenData.Priority,
        tokenData.isSkill,
        position
    )
    local allFieldParts = shared.helper.Field:getAllFieldParts()
    for index, fieldPart in pairs(allFieldParts) do
        local isInBound = self:isPositionInBounds(position, fieldPart)
        if isInBound then
            gameToken.tokenField = fieldPart
        end
    end

    task.delay(duration, function()
        self:removeToken(serverID)
    end)
    
    self.activeTokens[serverID] = gameToken
    
    if CONFIG.DEBUG.LOG_TOKEN_EVENTS then
        print(string.format("[TokenHelper] Spawned token %s (%s) at %s", name, tostring(serverID), tostring(position)))
    end
end

function TokenHelper:_handleTokenCollect(tokenParams)
    local serverID = tokenParams.ID
    local collectedToken = self.activeTokens[serverID]
    
    if collectedToken then
        self:_updateCollectedStats(collectedToken)
        if CONFIG.DEBUG.LOG_TOKEN_EVENTS then
            print(string.format("[TokenHelper] Collected token %s (%s)", collectedToken.name, tostring(serverID)))
        end
    end
    
    self:removeToken(serverID)
end


function TokenHelper:isPositionInBounds(position, field)
    if not CONFIG.FIELD.CHECK_BOUNDS or not field then return true end

    local size = field.Size
    local center = field.Position

    local min = center - size / 2
    local max = center + size / 2

    return (
        position.X >= min.X and position.X <= max.X and
        position.Z >= min.Z and position.Z <= max.Z
    )
end

function TokenHelper:_updateCollectedStats(token)
    local tokenID = token.id
    local tokenName = token.name
    
    local stats = self.collectedTokenData[tokenID] or {
        token_id = tokenID,
        token_name = tokenName,
        total = 0,
        last_collected_at = nil,
    }
    
    stats.total = stats.total + 1
    stats.last_collected_at = os.time()
    self.collectedTokenData[tokenID] = stats
    
    -- Save data with error handling
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(self.collectedTokenData)
        -- writefile(CONFIG.FILES.TOKEN_DATA, json)
    end)
    
    if not success and CONFIG.DEBUG.ENABLED then
        warn("[TokenHelper] Failed to save token data:", err)
    end
end

function TokenHelper:getBestNearbyToken()
    if not self.player:isValid() or not self.player.rootPart then return nil end
    
    local playerRoot = self.player.rootPart
    local bestToken = nil
    local bestValue = math.huge
    
    for _, tokenData in pairs(self.activeTokens) do
        if self:isTokenCollectable(tokenData) then
            local value = self.useSimpleDistanceLogic 
                and (tokenData.position - playerRoot.Position).Magnitude
                or self:calculateSmartTokenScore(tokenData, playerRoot)
                
            if value < bestValue then
                bestValue = value
                bestToken = tokenData
            end
        end
    end
    
    return bestToken
end

function TokenHelper:isTokenCollectable(tokenData)
    -- ingore honey token if it's enabled
    if shared.main.ignoreHoneyToken and tokenData.id == 1472135114 then
        return false
    end

    return tokenData and tokenData:isValid()
end

function TokenHelper:calculateSmartTokenScore(tokenData, playerRoot)
    local weights = CONFIG.SCORING.PRIORITY_WEIGHTS
    if not tokenData or not tokenData.position or not playerRoot or not playerRoot.Position then
        return math.huge
    end
    
    local distance = (tokenData.position - playerRoot.Position).Magnitude
    local priority = tokenData.priority or 1
    local age = tick() - tokenData.spawnTime
    local isSkill = tokenData.isSkill or false
    
    local score = (distance * weights.distance)
    score = score - (priority * weights.priority)
    score = score - (age * weights.age)
    
    if isSkill then
        score = score - CONFIG.SCORING.SMART_GET_NEAR_SKILL_TOKEN_BOOST
    end
    
    return score
end

function TokenHelper:extractAssetID(url)
    if not url then return nil end
    local id = string.match(url, "rbxassetid://(%d+)") or string.match(url, "[&?]id=(%d+)")
    return tonumber(id)
end

function TokenHelper:getActiveTokenCount()
    local count = 0
    for _ in pairs(self.activeTokens) do
        count = count + 1
    end
    return count
end

function TokenHelper:getConfig()
    return CONFIG
end

function TokenHelper:updateConfig(newConfig)
    self:_mergeConfig(CONFIG, newConfig)
    
    -- Save updated config
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(CONFIG)
        writefile(CONFIG.FILES.CONFIG_FILE, json)
    end)
    
    if not success and CONFIG.DEBUG.ENABLED then
        warn("[TokenHelper] Failed to save config:", err)
    end
end

function TokenHelper:destroy()
    -- Disconnect update connection
    if self._updateConnection then
        self._updateConnection:Disconnect()
        self._updateConnection = nil
    end
    
    -- Disconnect all event connections
    for _, connection in ipairs(self._connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self._connections = {}
    
    -- Clean up all tokens
    for _, tokenData in pairs(self.activeTokens) do
        tokenData:cleanup()
    end
    self.activeTokens = {}
    
    -- Clear data
    self.collectedTokenData = nil
    
    -- Clean up display folder
    if CollectiblesDisplayFolder then
        CollectiblesDisplayFolder:Destroy()
    end
    
    if CONFIG.DEBUG.ENABLED then
        print("[TokenHelper] Destroyed and cleaned up")
    end
end

return TokenHelper
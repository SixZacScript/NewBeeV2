-- StateManager.lua
local StateManager = {}
StateManager.__index = StateManager

-- State definitions
StateManager.States = {
    IDLE = "idle",
    MOVING = "moving",
    CONVERTING = "converting",
    COLLECTING = "collecting",
    ATTACKING = "attacking",
    RETURNING = "returning",
    PAUSED = "paused",
    LOOPING = "looping"
}
function StateManager.new()
    local self = setmetatable({}, StateManager)
    self.currentState = StateManager.States.IDLE
    self.previousState = nil
    self.stateStartTime = tick()
    self.stateCallbacks = {}
    
    return self
end

function StateManager:setState(newState)
    if self.currentState == newState then return end
    
    self.previousState = self.currentState
    self.currentState = newState
    self.stateStartTime = tick()
    
    -- Call state change callback if exists
    if self.stateCallbacks[newState] then
        self.stateCallbacks[newState](self)
    end
    if newState == StateManager.States.IDLE then
        shared.helper.Player:stopMoving()
    end
    -- print("State changed: " .. tostring(self.previousState) .. " -> " .. tostring(newState))
end

function StateManager:getState()
    return self.currentState
end

function StateManager:getPreviousState()
    return self.previousState
end

function StateManager:getStateTime()
    return tick() - self.stateStartTime
end

function StateManager:onStateChange(state, callback)
    self.stateCallbacks[state] = callback
end

function StateManager:isIdle()
    return self.currentState == StateManager.States.IDLE
end

function StateManager:isConverting()
    return self.currentState == StateManager.States.CONVERTING
end
function StateManager:isPaused()
    return self.currentState == StateManager.States.PAUSED
end

return StateManager
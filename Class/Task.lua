-- TaskManager.lua
local TaskManager = {}
TaskManager.__index = TaskManager

-- Task type definitions
TaskManager.TaskTypes = {
    MOVE_TO = "move_to",
    CONVERT = "convert_pollen",
    COLLECT_ITEM = "collect_item",
    ATTACK_TARGET = "attack_target",
    WAIT = "wait"
}

function TaskManager.new()
    local self = setmetatable({}, TaskManager)
    self.taskQueue = {}
    self.currentTask = nil
    self.taskIdCounter = 0
    
    return self
end

-- Task Creation
function TaskManager:createTask(taskType, data)
    self.taskIdCounter = self.taskIdCounter + 1
    return {
        type = taskType,
        data = data or {},
        id = self.taskIdCounter,
        status = "pending",
        startTime = nil,
        pausedAt = nil
    }
end

function TaskManager:addTask(taskType, data)
    local task = self:createTask(taskType, data)
    table.insert(self.taskQueue, task)
    return task.id
end

-- Task Queue Management
function TaskManager:getNextTask()
    if #self.taskQueue > 0 then
        return table.remove(self.taskQueue, 1)
    end
    return nil
end

function TaskManager:removeTask(taskId)
    for i, task in ipairs(self.taskQueue) do
        if task.id == taskId then
            table.remove(self.taskQueue, i)
            return true
        end
    end
    return false
end

function TaskManager:clearTasks()
    self.taskQueue = {}
    self.currentTask = nil
end

-- Task Information
function TaskManager:getTaskCount()
    return #self.taskQueue
end

function TaskManager:getCurrentTaskInfo()
    if self.currentTask then
        return {
            type = self.currentTask.type,
            status = self.currentTask.status,
            data = self.currentTask.data,
            id = self.currentTask.id
        }
    end
    return nil
end

function TaskManager:getQueuedTasks()
    local tasks = {}
    for _, task in ipairs(self.taskQueue) do
        table.insert(tasks, {
            id = task.id,
            type = task.type,
            status = task.status
        })
    end
    return tasks
end

-- Task Cancellation
function TaskManager:cancelCurrentTask()
    if not self.currentTask then
        return false, "No current task to cancel"
    end
    
    local canceledTask = self.currentTask
    canceledTask.status = "canceled"
    
    local taskInfo = {
        id = canceledTask.id,
        type = canceledTask.type
    }
    
    self.currentTask = nil
    return true, taskInfo
end

function TaskManager:cancelTask(taskId)
    -- Check if it's the current task
    if self.currentTask and self.currentTask.id == taskId then
        return self:cancelCurrentTask()
    end
    
    -- Check in task queue
    for i, task in ipairs(self.taskQueue) do
        if task.id == taskId then
            task.status = "canceled"
            local taskInfo = {id = task.id, type = task.type}
            table.remove(self.taskQueue, i)
            return true, taskInfo
        end
    end
    
    return false, "Task not found"
end

function TaskManager:cancelTasksByType(taskType)
    local canceledTasks = {}
    
    -- Cancel current task if it matches
    if self.currentTask and self.currentTask.type == taskType then
        local success, taskInfo = self:cancelCurrentTask()
        if success then
            table.insert(canceledTasks, taskInfo)
        end
    end
    
    -- Cancel matching tasks in queue
    for i = #self.taskQueue, 1, -1 do
        local task = self.taskQueue[i]
        if task.type == taskType then
            task.status = "canceled"
            table.insert(canceledTasks, {id = task.id, type = task.type})
            table.remove(self.taskQueue, i)
        end
    end
    
    return canceledTasks
end

function TaskManager:cancelAllTasks()
    local canceledTasks = {}
    
    -- Cancel current task
    if self.currentTask then
        local success, taskInfo = self:cancelCurrentTask()
        if success then
            table.insert(canceledTasks, taskInfo)
        end
    end
    
    -- Cancel all queued tasks
    for _, task in ipairs(self.taskQueue) do
        task.status = "canceled"
        table.insert(canceledTasks, {id = task.id, type = task.type})
    end
    
    self.taskQueue = {}
    return canceledTasks
end

-- Task Pause/Resume
function TaskManager:pauseCurrentTask()
    if not self.currentTask then
        return false, "No current task to pause"
    end
    
    self.currentTask.status = "paused"
    self.currentTask.pausedAt = tick()
    
    return true, {
        id = self.currentTask.id,
        type = self.currentTask.type
    }
end

function TaskManager:resumeCurrentTask()
    if not self.currentTask or self.currentTask.status ~= "paused" then
        return false, "No paused task to resume"
    end
    
    self.currentTask.status = "executing"
    
    -- Adjust timing if needed
    if self.currentTask.pausedAt and self.currentTask.startTime then
        local pausedDuration = tick() - self.currentTask.pausedAt
        self.currentTask.startTime = self.currentTask.startTime + pausedDuration
    end
    
    self.currentTask.pausedAt = nil
    
    return true, {
        id = self.currentTask.id,
        type = self.currentTask.type
    }
end

-- Task Validation
function TaskManager:canCancelTask(task)
    if task.data and task.data.critical then
        return false
    end
    return true
end

function TaskManager:getCancelableTasksInfo()
    local info = {
        current = nil,
        queued = {}
    }
    
    if self.currentTask then
        info.current = {
            id = self.currentTask.id,
            type = self.currentTask.type,
            cancelable = self:canCancelTask(self.currentTask)
        }
    end
    
    for _, task in ipairs(self.taskQueue) do
        table.insert(info.queued, {
            id = task.id,
            type = task.type,
            cancelable = self:canCancelTask(task)
        })
    end
    
    return info
end

return TaskManager
-- LocalScript (Client-side)
local HttpService = game:GetService("HttpService")
local Rep = game:GetService("ReplicatedStorage")
local Events = Rep.Events -- Assuming this is your Events module
local CollectiblesDisplayFolder = Instance.new("Folder")
CollectiblesDisplayFolder.Name = "ActiveCollectiblesDisplay"
CollectiblesDisplayFolder.Parent = workspace -- Or a dedicated folder for visuals

local activeCollectibleParts = {} -- Table to store references to the actual parts by collectible ID

-- Function to handle spawning a collectible visual
Events.CollectibleEvent.OnClientEvent:Connect(function(action, spawnParams)
    if action == "Spawn" then
        local collectibleID = spawnParams.ID
        local collectiblePart = Instance.new("Part")
        collectiblePart.Name = "Collectible_" .. collectibleID
        collectiblePart.Position = spawnParams.Pos
        collectiblePart.Color = spawnParams.Color
        collectiblePart.Size = Vector3.new(2, 2, 2) -- Example size
        collectiblePart.Anchored = true
        collectiblePart.CanCollide = false


        collectiblePart.Parent = CollectiblesDisplayFolder 
        activeCollectibleParts[collectibleID] = collectiblePart

        print(collectibleID)

    elseif action == "Collect" then
        print(HttpService:JSONEncode(spawnParams))
        local collectibleID = spawnParams 
        local partToDestroy = activeCollectibleParts[collectibleID]
        if partToDestroy then
            partToDestroy:Destroy()
            activeCollectibleParts[collectibleID] = nil -- Remove reference
            print("Client: Destroyed collectible visual with ID:", collectibleID)
        end
    else 
        print(action)
    end
end)


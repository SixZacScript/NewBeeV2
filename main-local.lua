function getNearestBalloonRoot(HivePosition)
    local nearestBalloon = nil
    local nearestDistance = math.huge

    local hiveBalloons = workspace.Balloons.HiveBalloons:GetChildren()

    for _, balloonInstance in ipairs(hiveBalloons) do
        local root = balloonInstance:FindFirstChild("BalloonRoot")
        if root and root:IsA("BasePart") then
            local distance = (root.Position - HivePosition.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestBalloon = root
            end
        end
    end

    return nearestBalloon
end


print(getNearestBalloonRoot(Vector3.new(-150.47103881835938, 6.156343936920166, 329.9034729003906)))
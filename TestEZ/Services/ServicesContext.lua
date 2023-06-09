--[[
    Create tycoons for each test case
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(beforeEach, afterEach, afterAll): ()
    require(script.Parent.PrepareServices)()
    
    local Knit = require(ReplicatedStorage.Packages.Knit)
    local TycoonService = Knit.GetService("TycoonService")

    local player: Player = game.Players.LocalPlayer
    
    beforeEach(function(): ()
        TycoonService:_playerAdded(player)
    end)

    afterEach(function(): ()
        for _, tycoon: Model in ipairs(workspace.Tycoons:GetChildren()) do
            if tycoon.Name ~= "Template" then
                tycoon:Destroy()
            end
        end
    end)
    
    afterAll(function(): ()
        local template: Model = ReplicatedStorage:FindFirstChild("Template")

        if template then
            template.Parent = workspace.Tycoons
        end
    end)
end
--[[
    Creates a tycoon for each player to join the game and createa handler for purchasing pads
]]

------------------------------Roblox Services-----------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)

------------------------------Constants-----------------------------------

local OWNER_ATTR: string = "Owner"
local AREA_TAKEN_ATTR: string = "Taken"
local TYCOONS: Folder
local TYCOON_TEMPLATE: Model

------------------------------Service Dependencies-----------------------------------

local PadService

------------------------------Knit Service-----------------------------------

local TycoonService = Knit.CreateService({
    Name = "TycoonService"
})

------------------------------Local Functions-----------------------------------

-- find a tycoon that hasnt been taken by another player yet
local function getUntakenArea(): Part
    local untakenArea: Part

    for _, area: Part in ipairs(workspace.TycoonAreas:GetChildren()) do
        if not area:GetAttribute(AREA_TAKEN_ATTR) then
            untakenArea = area
            break
        end
    end

    return untakenArea
end

------------------------------Public Methods-----------------------------------

-- get the tycoon with the matching userid attribute as the player passed
function TycoonService:GetTycoonFromPlayer(player: Player): Model
    for _, tycoon: Model in ipairs(TYCOONS:GetChildren()) do
        local matchingUserId: boolean = tycoon:GetAttribute(OWNER_ATTR) == player.UserId
        
        if matchingUserId then
            return tycoon
        end
    end
end

------------------------------Private Methods-----------------------------------

-- create a tycoon for the player that just joined and remove it when they leave
function TycoonService:_playerAdded(player: Player): ()
    local tycoon: Model = TYCOON_TEMPLATE:Clone()

    local takenArea: BasePart = getUntakenArea()
    takenArea:SetAttribute(AREA_TAKEN_ATTR, true)

    -- set target references to be the template's
    -- roblox studio will keep the references to the template but the roblox client will not
    for _, pad: Model in ipairs(tycoon.Pads:GetChildren()) do
        pad.Target.Value = TYCOON_TEMPLATE.Buildings[pad.Target.Value.Name]
    end

    tycoon:SetAttribute(OWNER_ATTR, player.UserId)
    tycoon.Buildings:ClearAllChildren() -- dont need them until the player buys them
    
    tycoon:PivotTo(takenArea.CFrame)
    tycoon.Name = "Tycoon"

    tycoon.Parent = TYCOONS

    player.RespawnLocation = tycoon.Spawn

    local trove = Trove.new()

    trove:Add(function(): ()
        takenArea:SetAttribute(AREA_TAKEN_ATTR)
    end)

    trove:Connect(player.AncestryChanged, function(_, newParent: Instance?): ()
        if newParent then
            return
        end

        trove:Destroy()
    end)

    trove:Add(function(): ()
        -- special case, itll error if the tycoon destroying caused the trove to be destroyed
        -- but we still need to make sure the tycoon is cleaned up
        local success: boolean, fail: string = pcall(function(): ()
            tycoon:Destroy()
        end)

        if not success then
            warn(fail)
        end
    end)

    trove:AttachToInstance(tycoon)

    PadService:CreatePadHandler(tycoon)
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime services
function TycoonService:KnitInit(): ()
	PadService = Knit.GetService("PadService")
end

-- start up logic
function TycoonService:KnitStart(): ()
    TYCOONS = workspace:WaitForChild("Tycoons", 15)

    if not TYCOONS then
        error("Failed to find tycoons in the workspace")
    end

    TYCOON_TEMPLATE = TYCOONS:WaitForChild("Template", 10)

    if not TYCOON_TEMPLATE then
        error("Failed to find tycoon template")
    end

    TYCOON_TEMPLATE.Parent = ReplicatedStorage

    -- for test ez
    if not RunService:IsRunning() then
        return
    end

    Players.PlayerAdded:Connect(function(player: Player): ()
        TycoonService:_playerAdded(player)
    end)

    for _, player: Player in ipairs(Players:GetPlayers()) do
        TycoonService:_playerAdded(player)
    end
end

return TycoonService
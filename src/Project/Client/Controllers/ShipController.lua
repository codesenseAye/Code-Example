--[[
    Allow the player to control and move their ship
]]

------------------------------Roblox Services-----------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Types-----------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Timer = require(ReplicatedStorage.Packages.Timer)

------------------------------Constants-----------------------------------

local MAXIMUM_DIRECTION_CHANGE_INTERVAL: number = 0.1

local OWNER_ATTR: string = "Owner"

local TYCOON_TEMPLATE: Model
local TYCOONS: Model

------------------------------Fields-----------------------------------

local pilotingTrove = Trove.new()
local piloting: boolean = false

------------------------------Service & Controller Dependencies-----------------------------------

local ShipHudController
local ToolbarController
local ShipService
local GunController

------------------------------Knit Service-----------------------------------

local ShipController = Knit.CreateController({
    Name = "ShipController"
})

------------------------------Local Functions-----------------------------------

-- set the enabled state of all state types except a couple import ones to the state provided on the humanoid specified
local function toggleHumanoidStates(humanoid: Humanoid, state: boolean): ()
    local states: Enum.HumanoidStateType = Enum.HumanoidStateType

    for _, stateType: Enum in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
        if stateType ~= states.None and stateType ~= states.PlatformStanding and stateType ~= states.Dead then
            humanoid:SetStateEnabled(stateType, state)
        end
    end
end

-- uses ik controls to place the players hands on the ships helm
-- looks cool when the helm turns
local function putHandsOnHelm(char: Model, ship: Model): Types.Trove
    local trove = Trove.new()
    trove:AttachToInstance(char)

    local rightIKControl: IKControl = Instance.new("IKControl")
    local leftIKControl: IKControl = Instance.new("IKControl")

    rightIKControl.ChainRoot = char.RightUpperArm
    leftIKControl.ChainRoot = char.LeftUpperArm

    rightIKControl.EndEffector = char.RightHand
    leftIKControl.EndEffector = char.LeftHand

    rightIKControl.Target = ship.Wheel.PrimaryPart.RightHand
    leftIKControl.Target = ship.Wheel.PrimaryPart.LeftHand

    rightIKControl.Parent = char
    leftIKControl.Parent = char

    trove:Add(rightIKControl)
    trove:Add(leftIKControl)

    return trove
end

-- handles the ship door transparency, initiating piloting, toggles userinterfaces and exiting piloting
local function myShipAdded(ship: Model): ()
    local helm: Model = ship:WaitForChild("Wheel")
    local helmPrimaryPart: Part = helm.PrimaryPart

    if not helmPrimaryPart then
        helm:GetPropertyChangedSignal("PrimaryPart"):Wait()
        helmPrimaryPart = helm.PrimaryPart
    end

    local pilotAttachment: Attachment = helmPrimaryPart:WaitForChild("PilotAttachment")
    local pilotProximityPrompt: ProximityPrompt = pilotAttachment:WaitForChild("Pilot")
    pilotProximityPrompt.Enabled = true

    local shipTrove = Trove.new()
    shipTrove:AttachToInstance(ship)

    local tycoon: Model = ship.Parent.Parent

    local door: Part = ship:WaitForChild("Door")
    local templateConnect: Vector3 = TYCOON_TEMPLATE.Buildings.ShipAccessBridge.Connect

    local connectOffset: CFrame = TYCOON_TEMPLATE.Baseplate.CFrame:ToObjectSpace(templateConnect.CFrame)
    
    local connectionBridgePos: Vector3 = tycoon.Baseplate.CFrame * connectOffset

    -- the ship door should be invisible when close to the bridge and visible when away from it
    -- a liveliness thing
    shipTrove:Add(Timer.Simple(0.5, function(): ()
        local dist: number = (connectionBridgePos.Position - door.Position).Magnitude

        if dist > 25 then
            door.LocalTransparencyModifier = -1
        else
            door.LocalTransparencyModifier = 1
        end
    end))

    --#region ship pilot initate / cancel controls

    pilotProximityPrompt.Triggered:Connect(function(): ()
        -- make sure the call is successful before we disable the prompt
        if not ShipController:SetPiloting(ship) then
            return
        end

        ShipHudController:SetState(true)
        ToolbarController:SetState(false)

        pilotProximityPrompt.Enabled = false

        pilotingTrove:Add(function(): ()
            pilotProximityPrompt.Enabled = true

            ShipHudController:SetState(false)
            ToolbarController:SetState(true)
        end)
    end)

    -- mobile input is in the shiphudcontroller
    shipTrove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean): ()
        if gameProcessed then
            return
        end

        if input.KeyCode ~= pilotProximityPrompt.KeyboardKeyCode then
            return
        end

        if pilotProximityPrompt.Enabled then
            return
        end

        ShipController:SetPiloting()
    end)

    --#endregion ship pilot initate / cancel controls
end

-- detect when a specific special model (a ship) has been added to the tycoon passed
local function myTycoonAdded(tycoon: Model): ()
    local special: Folder = tycoon:WaitForChild("Special", 10)

    if not special then
        warn("Failed to find special folder inside tycoon:", tycoon:GetFullName())
        return
    end

    local function specialAdded(specialModel: Model): ()
        if specialModel.Name ~= "Ship" then
            return
        end

        myShipAdded(specialModel)
    end

    special.ChildAdded:Connect(specialAdded)

    for _, specialModel: Model in ipairs(special:GetChildren()) do
        specialAdded(specialModel)
    end
end

-- manage the tycoon passed as long as its our tycoon
local function tycoonAdded(tycoon: Model): ()
    local ownerUserId: number = tycoon:GetAttribute(OWNER_ATTR)

    if not ownerUserId then
        -- this shouldnt happen
        warn("Tycoon has no owner:", tycoon:GetFullName())
        return
    end
    
    if ownerUserId ~= Knit.Player.UserId then
        return
    end

    -- this is our tycoon
    myTycoonAdded(tycoon)
end

------------------------------Public Methods-----------------------------------

-- sets the piloting state of the ship passed, no ship means stop piloting
function ShipController:SetPiloting(ship: Model?): boolean
    pilotingTrove:Clean()

    if not ship then
        return false
    end
    
    GunController:ToggleGun(false)

    local char: Model = Knit.Player.Character
    local rootPart: Part = char.PrimaryPart
    local humanoid: Humanoid = char.Humanoid

    local charHeight: number = (rootPart.Size.Y / 2) + humanoid.HipHeight
    pilotingTrove:Add(putHandsOnHelm(char, ship))

    piloting = true
    ShipService:TogglePiloting(ship, true, charHeight)

    pilotingTrove:Add(function(): ()
        piloting = false
        ShipService:TogglePiloting(ship, false)
    end)

    ShipController:_handlePiloting(ship, rootPart, humanoid)
    return true
end

-- simply returns whether or not the player is controlling a ship right now
function ShipController:IsPiloting(): boolean
    return piloting
end

------------------------------Private Methods-----------------------------------

-- sets the humanoid state types so that the ship doesnt spazz out because physics
-- and detects changes in the humanoid move direction for movement of the ship
-- (easiest way to get cross platform move controls)
function ShipController:_handlePiloting(ship: Model, rootPart: Part, humanoid: Humanoid): ()
    pilotingTrove:AttachToInstance(rootPart)

    toggleHumanoidStates(humanoid, false)
    humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)

    pilotingTrove:Add(function(): ()
        toggleHumanoidStates(humanoid, true)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)

    local changingDir: boolean = false

    pilotingTrove:Connect(humanoid:GetPropertyChangedSignal("MoveDirection"), function(): ()
        if changingDir then
            return
        end
        
        -- so we dont call the server method too quickly
        changingDir = true

        task.delay(MAXIMUM_DIRECTION_CHANGE_INTERVAL, function(): ()
            changingDir = false

            ShipService:SetMovement(ship, humanoid.MoveDirection)
        end)
    end)

    pilotingTrove:Connect(humanoid:GetPropertyChangedSignal("Health"), function(): ()
        -- incase they get shot, immediately take them out of piloting
        -- not necessary to be secure i believe
        ShipController:SetPiloting()
    end)
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime controllers / services
function ShipController:KnitInit(): ()
    ShipHudController = Knit.GetController("ShipHudController")
    ToolbarController = Knit.GetController("ToolbarController")
	ShipService = Knit.GetService("ShipService")
	GunController = Knit.GetController("GunController")
end

-- start up logic
function ShipController:KnitStart(): ()
    TYCOONS = workspace:WaitForChild("Tycoons", 15)

    if not TYCOONS then
        error("Failed to find tycoons in the workspace")
    end

    TYCOON_TEMPLATE = ReplicatedStorage:WaitForChild("Template", 15)

    if not TYCOON_TEMPLATE then
        error("Failed to get tycoon template")
    end

    TYCOONS.ChildAdded:Connect(tycoonAdded)

    for _, tycoon: Model in ipairs(TYCOONS:GetChildren()) do
        task.spawn(tycoonAdded, tycoon)
    end
end

return ShipController
--[[
    Handles controlling the player's gun and making special vfx for it
]]

------------------------------Roblox Services-----------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Types-----------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)

------------------------------Constants-----------------------------------

local OWNER_ATTR: string = "Owner"
local GUN_STATE_ATTR: string = "GunState"
local IS_KINEMATIC_ATTR: string = "Kinematic"
local LAST_SHOT_ATTR: string = "LastShot"

local UNLOCK_GUN_SPECIAL_NAME: string = "Ship"
local GUN_NAME: string = "Blunderbuss"

local RECOIL_TIME: number = 0.065

local TYCOONS: Folder

------------------------------Fields-----------------------------------

local myTycoon: Model
local myTycoonAdded: BindableEvent = Instance.new("BindableEvent")

------------------------------Service & Controller Dependencies-----------------------------------

local GunService
local ShipController

------------------------------Knit Service-----------------------------------

local GunController = Knit.CreateController({
    Name = "GunController",
})

------------------------------Local Functions-----------------------------------

-- set our "myTycoon" variable and fire a signal that it changed
local function tycoonAdded(tycoon: Model): ()
    local tycoonOwnerUserId: number = tycoon:GetAttribute(OWNER_ATTR)

    if not tycoonOwnerUserId then
        -- this shouldnt happen
        warn("Tycoon does not have an owner:" .. tycoon:GetFullName())
        return
    end

    if tycoonOwnerUserId ~= Knit.Player.UserId then
        return
    end

    myTycoon = tycoon
    myTycoonAdded:Fire()
end

-- simply weld a part to another
local function weldPart(part0: Part, part1: Part): ()
    local weld: WeldConstraint = Instance.new("WeldConstraint")
    weld.Part0 = part0
    weld.Part1 = part1
    weld.Parent = part0
end

--handle all platform controls for shooting and request the server to fire on proper input
local function handleGunInput(blunderbuss: Model): ()
    local trove = Trove.new()
    trove:AttachToInstance(blunderbuss)

    -- derive the shoot direction from the position on the screen the user wishes to shoot the gun at
    -- and the request the server to fire in that direction
    local function shoot(x: number, y: number): ()
        local ray: Ray = workspace.CurrentCamera:ScreenPointToRay(x, y)
        local dir: Vector3 = ray.Direction

        GunService:RequestShoot(blunderbuss.PrimaryPart.Barrel.WorldPosition, dir)
    end

    --#region handle all platform controls for shooting the gun

    trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean): ()
        if gameProcessed then
            return
        end

        local inputType: Enum.UserInputType = input.UserInputType

        if inputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        shoot(input.Position.X, input.Position.Y)
    end)

    trove:Connect(UserInputService.TouchTap, function(taps: {Vector2}, gameProcessed: boolean): ()
        if gameProcessed then
            return
        end

        local tap: Vector2 = taps[1]
        shoot(tap.X, tap.Y)
    end)

    --#endregion handle all platform controls for shooting the gun
end

--#region gun special VFX

-- make a sound and instantly emit one tenth of  all particles in the barrel
local function emitGunParticleEffects(blunderbuss: Model): ()
    blunderbuss.PrimaryPart.Shot:Play()

    for _, particleEmitter: ParticleEmitter in ipairs(blunderbuss.PrimaryPart.VFX:GetChildren()) do
        if not particleEmitter:IsA("ParticleEmitter") then
            continue
        end

        -- one tenth because the rate is per full second and can be very high (which could easily cause lag)
        particleEmitter:Emit(particleEmitter.Rate / 10)
    end
end

-- play particle effects on the gun when it is fired via attributes
-- if this is our gun a servo will fling back the gun so to replicate recoil
-- doing this on any other client will not work as we are not the network owner and our physics wont work
local function handleGunVFX(char: Model, blunderbuss: Model): ()
    local trove = Trove.new()
    trove:AttachToInstance(blunderbuss)

    -- detect last shot attribute changing

    local shotNum: number = 0

    local function lastShotChanged(): ()
        shotNum += 1
        local localShotNum: number = shotNum

        if not char:GetAttribute(LAST_SHOT_ATTR) then
            return
        end

        emitGunParticleEffects(blunderbuss)

        -- this signifies its not our gun so stop here because it will not work
        if not blunderbuss.PrimaryPart.Servo.Enabled then
            return
        end

        blunderbuss.PrimaryPart.Servo.TargetAngle = 45
        blunderbuss.Back.Back.TargetPosition = -2

        task.delay(RECOIL_TIME, function(): ()
            if localShotNum ~= shotNum or not blunderbuss.Parent then
                return
            end
    
            blunderbuss.PrimaryPart.Servo.TargetAngle = 0
            blunderbuss.Back.Back.TargetPosition = 0
        end)
    end

    trove:Connect(char:GetAttributeChangedSignal(LAST_SHOT_ATTR), lastShotChanged)
end

-- weld a gun to the character passed and setup inverse kinematic controls
-- initiate systems for playing vfx
local function toggleGunModel(char: Model, modelName: string, state: boolean): ()
    local blunderbuss: Model = char:FindFirstChild("Gun")

    if blunderbuss then
        blunderbuss:Destroy()
    end

    if not state then
        return
    end

    --#region basic pose

    local poseModel: Model = ReplicatedStorage.Assets[GUN_NAME][GUN_NAME .. modelName .. "Pose"]
    blunderbuss = poseModel.Gun:Clone()
    blunderbuss.Parent = char

    local trove = Trove.new()
    trove:AttachToInstance(blunderbuss)

    local offset: CFrame = poseModel.Rig.PrimaryPart.CFrame:ToObjectSpace(blunderbuss.Root.CFrame)
    blunderbuss:PivotTo(char.PrimaryPart.CFrame * offset)

    weldPart(blunderbuss.Root, char.UpperTorso)

    --#endregion basic pose

    if not poseModel:GetAttribute(IS_KINEMATIC_ATTR) then
        return
    end

    --#region ik control

    local rightIKControl: IKControl = Instance.new("IKControl")
    local leftIKControl: IKControl = Instance.new("IKControl")

    local rightPole: Part = poseModel.Rig.RightPole:Clone()
    local rightPoleOffset: CFrame = poseModel.Rig.PrimaryPart.CFrame:ToObjectSpace(poseModel.Rig.RightPole.CFrame)
    rightPole.CFrame = char.PrimaryPart.CFrame * rightPoleOffset
    rightPole.Parent = blunderbuss

    weldPart(rightPole, char.PrimaryPart)

    local leftPole: Part = poseModel.Rig.LeftPole:Clone()
    local leftPoleOffset: CFrame = poseModel.Rig.PrimaryPart.CFrame:ToObjectSpace(poseModel.Rig.LeftPole.CFrame)
    leftPole.CFrame = char.PrimaryPart.CFrame * leftPoleOffset
    leftPole.Parent = blunderbuss

    weldPart(leftPole, char.PrimaryPart)

    rightIKControl.Pole = rightPole
    leftIKControl.Pole = leftPole

    rightIKControl.SmoothTime = 0
    leftIKControl.SmoothTime = 0

    rightIKControl.ChainRoot = char.RightUpperArm
    rightIKControl.EndEffector = char.RightHand

    leftIKControl.ChainRoot = char.LeftUpperArm
    leftIKControl.EndEffector = char.LeftHand

    rightIKControl.Target = blunderbuss.PrimaryPart.RightHand
    leftIKControl.Target = blunderbuss.PrimaryPart.LeftHand

    rightIKControl.Parent = blunderbuss
    leftIKControl.Parent = blunderbuss

    --#endregion ik control

    handleGunVFX(char, blunderbuss)

    -- its not our character so constraints wont work
    -- weld it instead (otherwise the gun will not follow the character)
    if char ~= Knit.Player.Character then
        local weld: Weld = Instance.new("Weld")
        weld.Part0 = blunderbuss.PrimaryPart
        weld.Part1 = blunderbuss.Root
        weld.Parent = blunderbuss

        blunderbuss.Back:Destroy()
        blunderbuss.PrimaryPart.Servo.Enabled = false

        return
    end

    handleGunInput(blunderbuss)
end

--#endregion gun special VFX

-- detect when a character has a gun equipped and render its state via poses specified in `assets.Blunderbuss`
-- the poses can be easily modified by a non-programmer
local function characterAdded(char: Model): ()
    local rootPart: Part = char.PrimaryPart

    if not rootPart then
        char:GetPropertyChangedSignal("PrimaryPart"):Wait()
        rootPart = char.PrimaryPart
    end

    do -- necessary to put the gun on their back
        local upperTorso: MeshPart = char:WaitForChild("UpperTorso", 10)

        if not upperTorso then
            warn("Failed to get uppertorso on character:" .. char:GetFullName())
            return
        end
    end

    -- often the character wont have a parent for a frame
    if not char.Parent then
        char.AncestryChanged:Wait()
    end

    local trove = Trove.new()
    trove:AttachToInstance(char)

    local function gunStateChanged(): ()
        local gunState: boolean = char:GetAttribute(GUN_STATE_ATTR)

        if not gunState then
            toggleGunModel(char, "Unequipped", true)
        else
            toggleGunModel(char, "Equipped", true)
        end
    end

    trove:Connect(char:GetAttributeChangedSignal(GUN_STATE_ATTR), gunStateChanged)
    gunStateChanged()
end

-- manage every character that this player will have
local function playerAdded(player: Player): ()
    local char: Model = player.Character
    player.CharacterAdded:Connect(characterAdded)

    if char then
        characterAdded(char)
    end
end

------------------------------Public Methods-----------------------------------

-- simply checks if the client player has unlocked their special model required to use the gun
function GunController:IsGunUnlocked(): boolean
    if myTycoon and myTycoon.Special:FindFirstChild(UNLOCK_GUN_SPECIAL_NAME) then
        return true
    end

    return false
end

-- runs the callback passed when the user is able to use their gun
function GunController:OnGunUnlocked(callback: () -> ()): ()
    if GunController:IsGunUnlocked() then
        callback()
        return
    end

    Promise.new(function(resolve: Types.PromiseResolve): ()
        if not myTycoon then
            myTycoon.Event:Wait()
        end

        resolve()
    end):andThen(function(): ()
        local childAddedConn: RBXScriptConnection
        
        local unlocked = function(): ()
            childAddedConn:Disconnect()
            callback()
        end

        childAddedConn = myTycoon.Special.ChildAdded:Connect(function(specialModel: Model): ()
            if specialModel.Name ~= UNLOCK_GUN_SPECIAL_NAME then
                return
            end

            unlocked()
        end)
        
        if not GunController:IsGunUnlocked() then
            return
        end

        unlocked()
    end)
end

-- sets the state of the gun to the opposite of its current state unless a specific state is passed
-- does not allow the player to equip their gun if they are piloting a ship
function GunController:ToggleGun(state: boolean?): ()
    if not GunController:IsGunUnlocked() then
        -- this shouldnt happen
        return
    end

    local char: Model = Knit.Player.Character
    
    state = if state ~= nil then
        not state
    else
        char:GetAttribute(GUN_STATE_ATTR)

    if ShipController:IsPiloting() and not state then
        return
    end

    GunService:SetGunState(not state)
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime controllers / services
function GunController:KnitInit(): ()
	GunService = Knit.GetService("GunService")
	ShipController = Knit.GetController("ShipController")
end

-- start up logic
function GunController:KnitStart(): ()
    TYCOONS = workspace:WaitForChild("Tycoons", 10)

    if not TYCOONS then
        error("Failed to find tycoons in the workspace")
    end

    Players.PlayerAdded:Connect(playerAdded)

    for _, player: Player in ipairs(Players:GetPlayers()) do
        task.spawn(playerAdded, player)
    end

    TYCOONS.ChildAdded:Connect(tycoonAdded)

    for _, tycoon: Model in ipairs(TYCOONS:GetChildren()) do
        task.spawn(tycoonAdded, tycoon)
    end
end

return GunController
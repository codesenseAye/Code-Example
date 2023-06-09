--[[
    Handles moving the player's ships on request and piloting them / attaching the player to them
]]

------------------------------Roblox Services-----------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Timer = require(ReplicatedStorage.Packages.Timer)

------------------------------Constants-----------------------------------

local OWNER_ATTR: string = "Owner"
local SHIP_CONTROL_NUM_ATTR: string = "ShipControlNum"
local ORIGINAL_MASSLESS_ATTR: string = "OriginalMassless"
local TYCOONS: Folder

------------------------------Knit Service-----------------------------------

local ShipService = Knit.CreateService({
    Name = "ShipService"
})

------------------------------Local Functions-----------------------------------

-- go through every part in the character to see if it has an attribute storing the original state
-- then set it back and remove that attribute
local function revertMassless(char: Model): ()
    for _, part: Part | MeshPart in ipairs(char:GetDescendants()) do
        if not part:IsA("BasePart") then
            continue
        end
        
        local original: boolean = part:GetAttribute(ORIGINAL_MASSLESS_ATTR)
        
        if original == nil then
            continue
        end
        
        part:SetAttribute(ORIGINAL_MASSLESS_ATTR)
        part.Massless = original
    end
end

-- turn on every part's massless property and stores it original value in an attribute
local function setMassless(char: Model): ()
    for _, part: Part | MeshPart in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local original: boolean = part.Massless
            part.Massless = true

            part:SetAttribute(ORIGINAL_MASSLESS_ATTR, original)
        end
    end
end

-- securely checks to see if the player owns the ship passed
local function confirmPlayerOwnsShip(player: Player, ship: Model): boolean
    local tycoon: Model = ship.Parent.Parent

    if tycoon.Parent ~= TYCOONS then
        -- hm sus ඞඞඞ
        warn("Suspicious player v1:" .. player.Name)
        return false
    end

    local tycoonOwnerUserId: number = tycoon:GetAttribute(OWNER_ATTR)

    if tycoonOwnerUserId ~= player.UserId then
        -- HMMMMMMMMM ඞඞඞඞඞඞ
        warn("Suspicious player v2:" .. player.Name)
        return false
    end

    return true
end

----------------------------Client Methods------------------------------

-- securely lets the player move their ship around the direction passed
-- allows for as minimal calls to this function as possible
function ShipService.Client:SetMovement(player: Player, ship: Model, dir: Vector3): ()
    if not confirmPlayerOwnsShip(player, ship) then
        return
    end

    if typeof(dir) ~= "Vector3" then
        -- sus ඞ
        -- they couldve passed a table with a .Unit index to set that goal part whereever they want hm
        return
    end

    -- see if the player is activately piloting the ship, otherwise nono
    local weld: WeldConstraint = ship:FindFirstChild("PlayerWeld")

    if not weld then
        return
    end

    -- make sure we dont have more than one instance of the ship moving code running at the same time 
    -- by incrementing an attribute changed each time and listening for it to change later
    local shipControlNum: number = ship:GetAttribute(SHIP_CONTROL_NUM_ATTR)

    if not shipControlNum then
        shipControlNum = 0
    end

    shipControlNum += 1
    ship:SetAttribute(SHIP_CONTROL_NUM_ATTR, shipControlNum)

    local movementTrove = Trove.new()
    movementTrove:AttachToInstance(ship)

    movementTrove:Connect(ship:GetAttributeChangedSignal(SHIP_CONTROL_NUM_ATTR), function(): ()
        local currentShipControlNum: number = ship:GetAttribute(SHIP_CONTROL_NUM_ATTR)

        if currentShipControlNum ~= shipControlNum then
            movementTrove:Destroy()
        end
    end)

    -- make sure they cant go nuts
    dir = dir.Unit * 10

    if dir ~= dir then
        ship.Goal.CFrame = ship.PlayerStands.CFrame
        ship.Wheel.PrimaryPart.Servo.TargetAngle = 0
        return
    end

    movementTrove:Add(Timer.Simple(0.1, function(): ()
        if shipControlNum ~= ship:GetAttribute(SHIP_CONTROL_NUM_ATTR) then
            movementTrove:Destroy()
            return
        end

        local newPos: Vector3 = ship.PlayerStands.Position + dir
        local diff: number = ship.PlayerStands.CFrame.RightVector:Dot(dir.Unit)

        ship.Wheel.PrimaryPart.Servo.TargetAngle = diff * 45 -- nice user feedback
        ship.Goal.CFrame = CFrame.new(newPos, newPos + dir)
    end))
end

-- set the state of player piloting this ship
-- and weld the player to it if they wish to start piloting
function ShipService.Client:TogglePiloting(player: Player, ship: Model, state: boolean, charHeight: number): ()
    if not confirmPlayerOwnsShip(player, ship) then
        return
    end

    local weld: WeldConstraint = ship:FindFirstChild("PlayerWeld")

    if weld then
        weld:Destroy()
    end

    local char: Model = player.Character

    revertMassless(char)
    
    ship:SetAttribute(SHIP_CONTROL_NUM_ATTR)
    ship.Goal.CFrame = ship.PlayerStands.CFrame

    if not state then
        ship.Wheel.PrimaryPart.Servo.TargetAngle = 0
        return
    end

    local rootPart: Part = char.PrimaryPart

    if not rootPart then
        error("Failed to get rootpart of character:" .. player:GetFullName())
    end

    charHeight = math.abs(charHeight)

    -- we need to request the client to give us their height because the server will not have an accurate value
    -- best we can do is cap it
    -- no character should probably have a height taller than this
    if charHeight > 10 then
        warn("Player passed in a suspiciously high height value for piloting their ship")
        return
    end

    rootPart.CFrame = ship.PlayerStands.Attachment.WorldCFrame + (Vector3.yAxis * charHeight)

    setMassless(char)

    weld = Instance.new("WeldConstraint")
    weld.Part0 = rootPart
    weld.Part1 = ship.PlayerStands
    weld.Name = "PlayerWeld"
    weld.Parent = ship
end

------------------------------Public Methods-----------------------------------

-- toggle the visibility of the ship's upgrades based on them owning a gamepass
function ShipService:ManageShipThrusters(tycoon: Model, ship: Model): ()
    local tycoonOwnerUserId: number = tycoon:GetAttribute(OWNER_ATTR)
    local ownerPlayer: Player = Players:GetPlayerByUserId(tycoonOwnerUserId)

    local trove = Trove.new()
    trove:AttachToInstance(ship)

    local defaultShipSpeed: number = ship.PlayerStands.AlignPosition.MaxVelocity
    local boostedShipSpeed: number = defaultShipSpeed * 5

    local shipThrustersGamepassAttr: string = "HasShipThrustersGamepass"

    local function shipThrustersChanged(): ()
        local ownsShipThrusters: boolean = ownerPlayer:GetAttribute(shipThrustersGamepassAttr)

        ship.PlayerStands.AlignPosition.MaxVelocity = ownsShipThrusters and boostedShipSpeed or defaultShipSpeed
    
        for _, upgradeInstance: Part | Fire in ipairs(ship.Upgrades.ShipThrusters:GetDescendants()) do
            if upgradeInstance:IsA("Fire") then
                upgradeInstance.Enabled = ownsShipThrusters
            elseif upgradeInstance:IsA("BasePart") then
                upgradeInstance.Transparency = ownsShipThrusters and 0 or 1
            end
        end
    end

    trove:Connect(ownerPlayer:GetAttributeChangedSignal(shipThrustersGamepassAttr), shipThrustersChanged)
    shipThrustersChanged()
end

------------------------------Lifetime Methods-----------------------------------

-- start up logic
function ShipService:KnitStart(): ()
    TYCOONS = workspace:WaitForChild("Tycoons", 10)

    if not TYCOONS then
        error("Failed to get tycoons in the workspace")
    end
end

return ShipService
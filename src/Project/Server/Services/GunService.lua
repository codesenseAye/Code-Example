--[[
    Manages requests from player's to shoot their guns and handles knockback
]]

------------------------------Roblox Services-----------------------------------

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Timer = require(ReplicatedStorage.Packages.Timer)

------------------------------Constants-----------------------------------

local GUN_STATE_ATTR: string = "GunState"
local LAST_SHOT_ATTR: string = "LastShot"
local UNLOCK_GUN_SPECIAL_NAME: string = "Ship"
local RAY_DIRECTION_ATTR: string = "RayDirection"
local RAY_ORIGIN_ATTR: string = "RayOrigin"
local RESPONSIBLE_FOR_KILL_ATTR: string = "PlayerResponsibleForKill"
local GUN_HIT_ATTR: string = "GunHit"

local MAXIMUM_SHOOT_DISTANCE: number = 100
local MINIMUM_SHOOT_INTERVAL: number = 2
local GUN_RAYS: number = 30
local GUN_DAMAGE_AMOUNT: number = 25
local MAXIMUM_GUN_BULLET_SPREAD: number = math.pi / 6

local GUN_RAYS_FOLDER: Folder

------------------------------Service Dependencies-----------------------------------

local DataService
local TycoonService

------------------------------Knit Service-----------------------------------

local GunService = Knit.CreateService({
    Name = "GunService"
})

------------------------------Local Functions-----------------------------------

-- sets the network ownership of the character depending on the state passed
-- its also necessary to change the enabled humanoid states (minding some important ones)
local function setKnockbackable(char: Model, state: boolean): ()
    local player: Player = Players:GetPlayerFromCharacter(char)
    local humanoid: Humanoid = char.Humanoid
    local stateTypes: Enum.HumanoidStateType = Enum.HumanoidStateType

    for _, stateType: Enum.HumanoidStateType in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
        if stateType ~= stateTypes.None and state ~= stateTypes.Ragdoll and state ~= stateTypes.Dead then
            humanoid:SetStateEnabled(stateType, not state)
        end
    end

    for _, part: Part in ipairs(char:GetDescendants()) do
        if not part:IsA("BasePart") then
            continue
        end

        if not part:CanSetNetworkOwnership() then
            continue
        end

        part:SetNetworkOwner(if not state then player else nil)
    end
end

-- apply an impulse to the char in the direction passed
-- also applies damage and sets an attribute for detecting who killed who
-- unequips the players weapon as well
local function knockbackChar(char: Model, dir: Vector3, responsiblePlayer: Player): ()
    local humanoid: Humanoid = char.Humanoid
    local rootPart: BasePart = char.PrimaryPart

    if not rootPart then
        return
    end

    -- last hit gets the kill
    char:SetAttribute(RESPONSIBLE_FOR_KILL_ATTR, responsiblePlayer.UserId)

    setKnockbackable(char, true)
    humanoid:TakeDamage(GUN_DAMAGE_AMOUNT)

    task.defer(function(): ()
        if not rootPart.Parent then
            return
        end

        local assemblyMass: number = rootPart.AssemblyMass
        local knockbackDir: Vector3 = (dir.Unit + Vector3.yAxis) * 50

        humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
        rootPart:ApplyImpulse(knockbackDir * assemblyMass)
        rootPart:ApplyAngularImpulse(knockbackDir * assemblyMass)
    end)

    local trove = Trove.new()
    trove:AttachToInstance(char)

    trove:Add(Timer.Simple(1, function(): ()
        setKnockbackable(char, false)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end))

    -- cant have a gun while being flinged
    -- which incorporates a kind of extra necessary action to fighting that makes it more engaging
    char:SetAttribute(GUN_STATE_ATTR)
end

--load the players character
-- so that we dont have to rely on roblox's unreliable character spawning system
local function respawnCharacter(player: Player): ()
    task.spawn(function(): ()
        player:LoadCharacter()
    end)
end

-- make a folder with attributes for data so that the client can render a hitscan effect
-- for as minimal network data transfer as possible (as there should be a lot)
local function createVisibleRay(rayOrigin: Vector3, rayDir: Vector3)
    local gunRay: Folder = Instance.new("Folder")
    gunRay:SetAttribute(RAY_ORIGIN_ATTR, rayOrigin)
    gunRay:SetAttribute(RAY_DIRECTION_ATTR, rayDir)
    gunRay.Name = "Ray"
    gunRay.Parent = GUN_RAYS_FOLDER

    Debris:AddItem(gunRay, 5)
end

-- set an attribute on the instance hit so that the client can do some special VFX like balloons popping etc
local function makeGunHitAttr(shotResult: RaycastResult): ()
    local hit: Part = shotResult.Instance

    if hit:GetAttribute(GUN_HIT_ATTR) then
        return
    end

    hit:SetAttribute(GUN_HIT_ATTR, true)

    task.delay(1, function(): ()
        if not hit or not hit.Parent then
            return
        end

        -- allow for the attribute to be set again now
        hit:SetAttribute(GUN_HIT_ATTR)
    end)
end

-- make a bunch of hitscan shots with lots of spread and knockback + damage any player that is hit 
local function doShot(rayOrigin: Vector3, rayDir: Vector3, player: Player): ()
    local raycastParams: RaycastParams = RaycastParams.new()
    -- raycastParams.FilterDescendantsInstances = {player.Character}
    -- is it more fun if you can nail yourself randomly if youre not careful? realism 🤌
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local charsHit: {Model} = {}
    local rand: Random = Random.new()

    for _ = 1, GUN_RAYS do
        local spread: CFrame = CFrame.Angles(
            rand:NextNumber(-1, 1) * MAXIMUM_GUN_BULLET_SPREAD,
            rand:NextNumber(-1, 1) * MAXIMUM_GUN_BULLET_SPREAD,
            rand:NextNumber(-1, 1) * MAXIMUM_GUN_BULLET_SPREAD
        )
        
        local shot: CFrame = CFrame.new(rayOrigin, rayOrigin + rayDir) * spread

        local shotDir: Vector3 = shot.LookVector * MAXIMUM_SHOOT_DISTANCE
        createVisibleRay(rayOrigin, shotDir)

        local shotResult: RaycastResult = workspace:Raycast(rayOrigin, shotDir, raycastParams)
    
        if shotResult then
            makeGunHitAttr(shotResult)

            --#region make sure we actually hit a player
            local charHit: Model = shotResult.Instance:FindFirstAncestorWhichIsA("Model")
            
            if not charHit then
                continue
            end
            
            local playerHit: Player? = Players:GetPlayerFromCharacter(charHit)

            if not playerHit then
                continue
            end
            --#endregion make sure we actually hit a player

            -- make sure we dont hit the same character twice
            if table.find(charsHit, charHit) then
                continue
            end

            table.insert(charsHit, charHit)
        end
    end

    for _, hitChar: Model in ipairs(charsHit) do
        knockbackChar(hitChar, rayDir, player)
    end
end

-- manage each character and detect when they die so that the responsible player for killing them can be awarded
local function characterAdded(char: Model): ()
    local trove = Trove.new()
    local humanoid: Humanoid = char:WaitForChild("Humanoid", 15)

    if not humanoid then
        warn("Failed to find humanoid in character:" .. char:GetFullName())
        return
    end

    local rootPart: Part = char.PrimaryPart

    if not rootPart then
        char:GetPropertyChangedSignal("PrimaryPart"):Wait()
        rootPart = char.PrimaryPart
    end

    local ownerPlayer: Player = Players:GetPlayerFromCharacter(char)

    trove:Add(function(): ()
        respawnCharacter(ownerPlayer)

        local responsiblePlayerUserId: number = char:GetAttribute(RESPONSIBLE_FOR_KILL_ATTR)

        if not responsiblePlayerUserId then
            return
        end

        local player: Player? = Players:GetPlayerByUserId(responsiblePlayerUserId)

        if not player then
            return
        end

        if player == ownerPlayer then
            -- nice try lol
            return
        end

        local data = DataService:GetPlayerData(player)
        data.kills += 1
    end)

    -- it happens sometimes when the character is loading
    if not char.Parent then
        char.AncestryChanged:Wait()
    end

    --.Destroying doesnt fire when the rootpart falls out of the world
    -- which is what trove.AttachToInstance uses
    trove:Connect(rootPart.AncestryChanged, function(_, newParent: Instance?): ()
        if newParent then
            return
        end

        trove:Destroy()
    end)

    trove:Connect(humanoid:GetPropertyChangedSignal("Health"), function(): ()
        if humanoid.Health <= 0 then
            trove:Destroy()
        end
    end)
end

-- manage every character that this player has including the current one
local function playerAdded(player: Player): ()
    local char: Model = player.Character
    player.CharacterAdded:Connect(characterAdded)

    if char then
        characterAdded(char)
    else
        respawnCharacter(player)
    end
end

----------------------------Client Methods------------------------------

-- set the state of gun but check if they unlocked the gun first and their character is eligible (rootpart exists etc)
function GunService.Client:SetGunState(player: Player, state: boolean): ()
    local tycoon: Model = TycoonService:GetTycoonFromPlayer(player)

    if not tycoon then
        warn("Player does not have a tycoon:" .. player:GetFullName())
        return
    end

    if not tycoon.Special:FindFirstChild(UNLOCK_GUN_SPECIAL_NAME) then
        -- sus ඞ, the client code shouldnt allow this to happen hm 🤨🤨
        warn("Player has not unlocked their gun:" .. player:GetFullName())
        return
    end

    local char: Model = player.Character

    if not char then
        warn("Player does not have a character to set gun state:" .. player:GetFullName())
        return
    end

    if not char.PrimaryPart then
        warn("Player did not have a primary part:" .. player:GetFullName())
        return
    end

    if typeof(state) ~= "boolean" then
        warn("Gun state passed was not a boolean: " .. player:GetFullName())
        return
    end

    char:SetAttribute(GUN_STATE_ATTR, state)
end

-- process a request for the player to fire their gun
-- checking if they have a gun equipped, ratelimiting, and making sure the data they pass in isnt absurd
function GunService.Client:RequestShoot(player: Player, suggestedOrigin: Vector3, dir: Vector3): ()
    local char: Model = player.Character

    if not char:GetAttribute(GUN_STATE_ATTR) then
        return
    end

    local rootPart: Part = char.PrimaryPart

    if not rootPart then
        warn("Primary was not present for character:" .. player:GetFullName())
        return
    end

    local lastShot: number = char:GetAttribute(LAST_SHOT_ATTR)
    local serverTimeNow: number = workspace:GetServerTimeNow() -- extremely precise synced clock time

    if lastShot and lastShot + MINIMUM_SHOOT_INTERVAL > serverTimeNow then
        -- too soon
        return
    end

    char:SetAttribute(LAST_SHOT_ATTR, serverTimeNow)

    if typeof(dir) ~= "Vector3" then
        -- sus ඞ
        return
    end

    dir = dir.Unit

    local rayOrigin: Vector3 = rootPart.Position

    -- can possibly include a suggested origin by the player
    -- if its too far from their rootpart then just ignore it for safety

    if (suggestedOrigin - rayOrigin).Magnitude < 10 then
        rayOrigin = suggestedOrigin
    else
        warn("Players suggested gun shot origin was too far:" .. player:GetFullName())
    end

    doShot(rayOrigin, dir, player)
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime services
function GunService:KnitInit(): ()
    DataService = Knit.GetService("DataService")
	TycoonService = Knit.GetService("TycoonService")
end

-- start up logic
function GunService:KnitStart(): ()
    GUN_RAYS_FOLDER = Instance.new("Folder")
    GUN_RAYS_FOLDER.Name = "GunRays"
    GUN_RAYS_FOLDER.Parent = workspace

    Players.PlayerAdded:Connect(playerAdded)

    for _, player: Player in ipairs(Players:GetPlayers()) do
        task.spawn(playerAdded, player)
    end
end

return GunService
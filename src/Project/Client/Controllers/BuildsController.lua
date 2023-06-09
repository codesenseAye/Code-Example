--[[
    Creates the final build after the player purchases one of the pads and does a cool effect
]]

------------------------------Roblox Services-----------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Constants-----------------------------------

local OWNER_ATTR: string = "Owner"

local TYCOONS: Model
local TYCOON_TEMPLATE: Model

local DONT_DO_BUILD_EFFECTS_THRESHOLD_DISTANCE: number = 300

------------------------------Fields-----------------------------------

local gameStarted: number = os.clock()

------------------------------Service & Controller Dependencies-----------------------------------

local SoundController
local PurchaseController

------------------------------Knit Service-----------------------------------

local BuildsController = Knit.CreateController({
    Name = "BuildsController"
})

------------------------------Local Functions-----------------------------------

--#region building vfx

-- asynchronously tween each set of tweens in order so that it looks something vaguely lego'y
-- this function yields
local function tweenTweenGroups(tweenGroups: {{() -> TweenBase}}): ()
    for _, tweenGroup: {() -> TweenBase} in ipairs(tweenGroups) do
        local finishedNum: number = 0
        local allFinished: BindableEvent = Instance.new("BindableEvent")

        local function tweenCompleted(): ()
            finishedNum += 1

            if finishedNum >= #tweenGroup then
                allFinished:Fire()
            end
        end

        for _, tween: () -> TweenBase in ipairs(tweenGroup) do
            tween = tween()
            tween:Play()

            tween.Completed:Connect(tweenCompleted)
        end

        if #tweenGroup > 0 then
            allFinished.Event:Wait()
        end

        allFinished:Destroy()
    end
end

-- fade in the build model passed with a special VFX and play a sound
local function tweenBuildParts(build: Model): ()
    local buildRootPos: Vector3 = build:GetPivot().Position
    local tweenGroups: {{() -> TweenBase}} = {}
    local buildTweenInfo: TweenInfo

    for _, part: BasePart in ipairs(build:GetDescendants()) do
        local isPart: boolean = part:IsA("BasePart")
        local tweenGroup: {TweenBase} = {}

        if part:IsA("Decal") or isPart then
            -- we use localtransparencymodifier so we dont need to store the original transparency at all
            -- and it works with things other than baseparts
            part.LocalTransparencyModifier = 1

            local transparencyInfo: {[string]: number} = {
                LocalTransparencyModifier = 0
            }

            local tween: () -> TweenBase = function(): ()
                return TweenService:Create(part, buildTweenInfo, transparencyInfo)
            end
            
            table.insert(tweenGroup, tween)
        end
        
        if not isPart then
            table.insert(tweenGroups, tweenGroup)
            continue
        end

        local unitOffset: Vector3 = (part.Position - buildRootPos).Unit

        if unitOffset ~= unitOffset then -- in the case the rootpos is on top of this part such as the primary part
            unitOffset = Vector3.yAxis
        end

        -- have the part start outward from where its suppose to be
        -- then tween inward
        part.CFrame = part.CFrame + (unitOffset * 10)

        local tween: () -> TweenBase = function(): TweenBase
            return TweenService:Create(part, buildTweenInfo, {
                CFrame = part.CFrame - (unitOffset * 10)
            })
        end

        table.insert(tweenGroup, tween)
        table.insert(tweenGroups, tweenGroup)
    end

    local timeForEachGroup: number = (1 / #tweenGroups) * 1.5
    buildTweenInfo = TweenInfo.new(timeForEachGroup, Enum.EasingStyle.Linear)

    tweenTweenGroups(tweenGroups)

     -- to make sure we dont play the build sfx 100 times when they first join lol
     if gameStarted + 5 > os.clock() then
        return
    end

    -- make it feel like its legos lol
    SoundController:PlaySound("Build", buildRootPos)
end

--#endregion building vfx

-- create the client sided build but dont play any special vfx the player isnt anywhere near it
-- such as other players
local function makeBuild(tycoon: Model, build: Model): ()
    local char: Model = Knit.Player.Character
    local actualBuild: Model = TYCOON_TEMPLATE.Buildings[build.Name]:Clone()

    local templateBaseplate: Part = TYCOON_TEMPLATE.Baseplate
    local offset: CFrame = templateBaseplate.CFrame:ToObjectSpace(actualBuild:GetPivot())

    actualBuild:PivotTo(tycoon.Baseplate.CFrame * offset)

    if char then
        local rootPart: BasePart = char.PrimaryPart
        local dist: number = math.huge

        if rootPart then
            dist = (tycoon.Baseplate.Position - rootPart.Position).Magnitude
        end
        
        if dist > DONT_DO_BUILD_EFFECTS_THRESHOLD_DISTANCE then
            actualBuild.Parent = build
            return
        end
    end

    actualBuild.Parent = build
    tweenBuildParts(actualBuild)
end

-- detect when a new build is added to the tycoon and handle the products folder if its our tycoon
local function tycoonAdded(tycoon: Model): ()
    local buildings: Model = tycoon:WaitForChild("Buildings", 10)

    if not buildings then
        warn("Failed to find buildings in the tycoon:" .. tycoon:GetFullName())
        return
    end

    buildings.ChildAdded:Connect(function(build: Model): ()
        makeBuild(tycoon, build)
    end)

    for _, build: Model in ipairs(buildings:GetChildren()) do
        makeBuild(tycoon, build)
    end

    local ownerUserId: number = tycoon:GetAttribute(OWNER_ATTR)

    -- its unlikely the player will need the products on other islands
    if ownerUserId == Knit.Player.UserId then
        PurchaseController:HandleTycoonProducts(tycoon)
    end
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime controllers
function BuildsController:KnitInit(): ()
	SoundController = Knit.GetController("SoundController")
	PurchaseController = Knit.GetController("PurchaseController")
end

-- start up logic
function BuildsController:KnitStart(): ()
    TYCOONS = workspace:WaitForChild("Tycoons", 10)

    if not TYCOONS then
        error("Failed to find tycoons in the workspace")
    end

    TYCOON_TEMPLATE = ReplicatedStorage:WaitForChild("Template", 15)

    if not TYCOON_TEMPLATE then
        error("Failed to find tycoon template")
    end

    TYCOONS.ChildAdded:Connect(tycoonAdded)

    for _, tycoon: Model in ipairs(TYCOONS:GetChildren()) do
        -- incase any of them are held up or error it doesnt mess up all of the other ones
        task.spawn(tycoonAdded, tycoon)
    end
end

return BuildsController
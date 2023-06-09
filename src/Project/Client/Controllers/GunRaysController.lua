--[[
    Handles rendering the visuals of the bullet hitscans
]]

------------------------------Roblox Services-----------------------------------

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Constants-----------------------------------

local RAY_DIRECTION_ATTR: string = "RayDirection"
local RAY_ORIGIN_ATTR: string = "RayOrigin"

local GUN_RAYS_FOLDER: Folder
local RAY_TWEEN_INFO: TweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear)

------------------------------Knit Service-----------------------------------

local GunRaysController = Knit.CreateController({
    Name = "GunRaysController"
})

------------------------------Local Functions-----------------------------------

-- create a visual hitscan ray and fade it in / out quickly
local function gunRayAdded(gunRay: Folder): ()
    local rayOrigin: Vector3 = gunRay:GetAttribute(RAY_ORIGIN_ATTR)
    local rayDir: Vector3 = gunRay:GetAttribute(RAY_DIRECTION_ATTR)
    
    local rayLength: number = rayDir.Magnitude

    local ray: Part = Instance.new("Part")
    ray.Size = Vector3.new(0.2, 0.2, rayLength)
    ray.CFrame = CFrame.new(rayOrigin + (rayDir / 2), rayOrigin + rayDir)
    ray.Color = Color3.fromRGB(252, 255, 68)
    ray.Anchored = true
    ray.CanCollide = false
    ray.Transparency = 0.5
    ray.Parent = gunRay

    TweenService:Create(ray, RAY_TWEEN_INFO, {
        Transparency = 1
    }):Play()

    Debris:AddItem(ray, 1)
end

------------------------------Lifetime Methods-----------------------------------

-- start up logic
function GunRaysController:KnitStart(): ()
    GUN_RAYS_FOLDER = workspace:WaitForChild("GunRays", 15)

    if not GUN_RAYS_FOLDER then
        error("Failed to find the gun rays folder in the workspace")
    end

    GUN_RAYS_FOLDER.ChildAdded:Connect(gunRayAdded)

    for _, gunRay: Folder in ipairs(GUN_RAYS_FOLDER:GetChildren()) do
        gunRayAdded(gunRay)
    end
end

return GunRaysController
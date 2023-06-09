--[[
    A basic sound controller
]]

------------------------------Roblox Services-----------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)

------------------------------Knit Service-----------------------------------

local SoundController = Knit.CreateController({
    Name = "SoundController"
})

------------------------------Public Methods-----------------------------------

-- play the sound passed (should be located in Assets.Sounds somewhere) and at the location passed 
-- (no location means no rolloff / its parented to workspace)
function SoundController:PlaySound(soundName: string, location: Vector3?): ()
    local sound: Sound = ReplicatedStorage.Assets.Sounds:FindFirstChild(soundName, true)

    if not sound then
        warn("Failed to find sound from sound name:", soundName)
        return
    end

    local newSound: Sound = sound:Clone()

    if location then
        local locationPart: Part = Instance.new("Part")
        locationPart.Size = Vector3.one
        locationPart.CFrame = CFrame.new(location)
        locationPart.Anchored = true
        locationPart.Transparency = 1
        locationPart.Parent = workspace

        newSound.Parent = locationPart

        local locationTrove = Trove.new()

        -- not using trove.AttachToInstance because it uses the destroying signal
        locationTrove:Connect(newSound.AncestryChanged, function(_, newParent: Instance): ()
            if newParent then
                return
            end

            locationTrove:Destroy()
        end)

        locationTrove:Add(function(): ()
            if not locationPart.Parent then
                return
            end

            locationPart:Destroy()
        end)
    else
        newSound.Parent = workspace
    end

    newSound.Looped = false
    newSound.PlayOnRemove = true

    -- wait until the parent is no longer locked
    task.defer(function(): ()
        newSound:Destroy()
    end)
end

return SoundController
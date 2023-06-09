--[[
    Very basic knit execution sequence for services
    includes the ability to execute when the game is not running (for TestEZ)
    Possible additions could include:
    specific load order such as unitys load priorities
    verbosity settings
    etc
]]

---------------------------Roblox Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

----------------------------Knit------------------------------

local Knit

--#region test ez setup
-- we need to do this because the knitclient will remove the knitserver file when it runs

local knitSplitter: ModuleScript = ReplicatedStorage.Packages._Index["sleitnick_knit@1.5.1"].knit
local originalSplitter: ModuleScript = knitSplitter:FindFirstChild("knit")

local oldKnitPackage: ModuleScript = ReplicatedStorage.Packages.Knit
ReplicatedStorage.Packages.Knit:Clone().Parent = ReplicatedStorage.Packages
oldKnitPackage:Destroy()

if not RunService:IsRunning() then
    -- bypass knits server / client check because itll think our studio client is the roblox client

    Knit = require(knitSplitter)
else
    -- incase we forgot to reconnect rojo everything doesnt collapse
    if originalSplitter then
        originalSplitter.Parent = originalSplitter.Parent.Parent

        for _, moduleScript: ModuleScript in ipairs(knitSplitter:GetChildren()) do
            if moduleScript == originalSplitter then
                continue
            end
            
            moduleScript.Parent = originalSplitter
        end
        
        knitSplitter:Destroy()
        knitSplitter = originalSplitter
    end

    Knit = require(ReplicatedStorage.Packages.Knit)
end

--#endregion test ez setup

----------------------------Add Controllers------------------------------------

Knit.AddServicesDeep(ServerScriptService.Knit.Services)

----------------------------Start Knit------------------------------------

Knit.Start():andThen(function(): ()
    print("Server started!")
end):catch(function(error: string?): ()
    warn(tostring(error))
end)
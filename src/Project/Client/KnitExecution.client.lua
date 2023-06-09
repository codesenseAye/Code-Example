--[[
    Very basic knit execution sequence for controllers
    Possible additions could include:
    specific load order such as unitys load priorities
    verbosity settings
    etc
]]

---------------------------Roblox Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------Knit------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

----------------------------Add Controllers------------------------------------

Knit.AddControllersDeep(Knit.Player.PlayerScripts.Knit.Controllers)

----------------------------Start Knit------------------------------------

Knit.Start():andThen(function(): ()
    print("Client started!")
end):catch(function(error: string?): ()
    warn(tostring(error))
end)
--[[
    A very basic gui controller
    Additions to this could be a button wrapper for effects / sounds
]]

---------------------------Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------Types----------------------------

local Types = require(ReplicatedStorage.Shared.Types)

---------------------------Knit----------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

---------------------------Util----------------------------

local Promise = require(ReplicatedStorage.Packages.Promise)

---------------------------Knit Controller----------------------------

local GuiController = Knit.CreateController({
    Name = "GuiController"
})

---------------------------Private Methods----------------------------

-- sets an attribute on the ui module found to signal the await func
function GuiController:_activateGui(guiName: string): ()
    return Promise.new(function(resolve: Types.PromiseResolve, reject: Types.PromiseReject): ()
        local controllerName: string = guiName .. "Controller"
        local knitController = Knit.GetController(controllerName)

        if not knitController then
            reject("Could not find controller:" .. guiName)
            return
        end

        local screenGui: ScreenGui = Knit.Player.PlayerGui:WaitForChild(guiName, 10)

        if not screenGui then
            reject("Failed to startup gui module:" .. controllerName)
            return
        end

        screenGui.ResetOnSpawn = false -- i dont believe using this is ever necessary

        knitController:GuiLoaded(screenGui)
        resolve(screenGui)
    end):catch(function(e: string?): ()
        warn(tostring(e))
    end)
end

---------------------------Knit Lifetime Methods----------------------------

-- activate UI in a specific order for the current circumstances
function GuiController:KnitStart(): ()
    GuiController:_activateGui("Hud"):await()
    GuiController:_activateGui("Toolbar"):await()
    GuiController:_activateGui("ShipHud"):await()
    GuiController:_activateGui("Notification"):await()
end

return GuiController
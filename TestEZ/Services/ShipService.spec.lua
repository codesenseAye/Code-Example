--[[
    Test elements of the players using ships
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

return function(): ()
    require(script.Parent.ServicesContext)(beforeEach, afterEach, afterAll)
    
    local Knit = require(ReplicatedStorage.Packages.Knit)

    local ShipService = Knit.GetService("ShipService")
    local TycoonService = Knit.GetService("TycoonService")

    local player: Player = game.Players.LocalPlayer

    describe("trying to pilot a ship without one", function(): ()
        it("shouldnt work", function(): ()
            expect(function(): ()
                ShipService.Client:TogglePiloting(player)
            end).to.throw()

            expect(function(): ()
                ShipService.Client:SetMovement(player)
            end).to.throw()
        end)
    end)

    describe("piloting and moving a ship", function(): ()
        it("should work", function(): ()
            local tycoon: Model = TycoonService:GetTycoonFromPlayer(player)
            
            local fakeChar: Model = ReplicatedStorage.Assets.Blunderbuss.BlunderbussUnequippedPose.Rig:Clone()
            fakeChar.Parent = workspace
            Debris:AddItem(fakeChar, 5)
            
            player.Character = fakeChar
                
            local ship: Model = ReplicatedStorage.Assets.FinalBuildReplacements.Ship:Clone()
            ship.Parent = tycoon.Special
        
            expect(function(): ()
                ShipService.Client:TogglePiloting(player, ship)
            end).to.never.throw()

            expect(function(): ()
                ShipService.Client:SetMovement(player, ship, Vector3.xAxis)
            end).to.never.throw()

            fakeChar:Destroy()
        end)
    end)

    describe("managing a ship", function(): ()
        it("should work", function(): ()
            expect(function(): ()
                local tycoon: Model = TycoonService:GetTycoonFromPlayer(player)
                
                local ship: Model = ReplicatedStorage.Assets.FinalBuildReplacements.Ship:Clone()
                ship.Parent = tycoon.Special

                ShipService:ManageShipThrusters(tycoon, ship)
            end).never.to.throw()
        end)
    end)
end
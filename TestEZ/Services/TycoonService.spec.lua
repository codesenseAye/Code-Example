--[[
    Test elements of tycoon service to confirm that it atleast partially works
    this is never the same as testing the real game
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(): ()
    require(script.Parent.ServicesContext)(beforeEach, afterEach, afterAll)
    
    local Knit = require(ReplicatedStorage.Packages.Knit)
    
    local TycoonService = Knit.GetService("TycoonService")
    local player: Player = game.Players.LocalPlayer

    describe("the tycoon lifecycle", function(): ()
        it("should get a tycoon", function(): ()
            expect(TycoonService:GetTycoonFromPlayer(player)).to.be.a("userdata")
        end)
    end)
end
--[[
    Make sure the paycheck service methods work
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(): ()
    require(script.Parent.PrepareServices)()

    local Knit = require(ReplicatedStorage.Packages.Knit)
    local PaycheckService = Knit.GetService("PaycheckService")

    local player: Player = game.Players.LocalPlayer

    describe("the only way the player gets money", function(): ()
        it("should return how much the player got", function(): ()
            expect(PaycheckService.Client:RequestPaycheck(player)).to.be.ok()
        end)
    end)
end
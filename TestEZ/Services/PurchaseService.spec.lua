--[[
    Make sure the purchaseservice methods work
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(): ()
    require(script.Parent.PrepareServices)()
    
    local Knit = require(ReplicatedStorage.Packages.Knit)
    local PurchaseService = Knit.GetService("PurchaseService")

    describe("fetching gamepasses", function(): ()
        it("should return details about the gamepasses", function(): ()
            expect(PurchaseService:GetGamepass("ShipThrusters")).to.be.ok()
            expect(PurchaseService:GetGamepass("AutoCollect")).to.be.ok()
        end)
    end)

    describe("fetching developer products", function(): ()
        it("should return details about the developer products", function(): ()
            expect(PurchaseService:GetProduct(1543739916)).to.be.ok()
        end)
    end)
end
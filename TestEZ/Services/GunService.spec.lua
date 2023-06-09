--[[
    Test elements of tycoon service to confirm that it atleast partially works
    this is never the same as testing the real game
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

return function(): ()
    require(script.Parent.ServicesContext)(beforeEach, afterEach, afterAll)
    
    local Knit = require(ReplicatedStorage.Packages.Knit)

    local GunService = Knit.GetService("GunService")
    local TycoonService = Knit.GetService("TycoonService")

    local player: Player = game.Players.LocalPlayer

    -- gets the players tycoon and makes a fake character so that we can call the ship service methods
    local function getAShip(): Model
        local tycoon: Model = TycoonService:GetTycoonFromPlayer(player)
            
        local fakeChar: Model = ReplicatedStorage.Assets.Blunderbuss.BlunderbussUnequippedPose.Rig:Clone()
        fakeChar.Parent = workspace
        Debris:AddItem(fakeChar, 5)
        
        player.Character = fakeChar
            
        local ship: Model = ReplicatedStorage.Assets.FinalBuildReplacements.Ship:Clone()
        ship.Parent = tycoon.Special

        task.defer(function(): ()
            fakeChar:Destroy()
        end)

        return fakeChar
    end

    describe("using a gun", function(): ()
        it("equipping the gun", function(): ()
            getAShip()
        
            expect(function(): ()
                GunService.Client:SetGunState(player, true)
            end).to.never.throw()
        end)

        it("shooting the gun", function(): ()
            local fakeChar: Model = getAShip()
            
            expect(function(): ()
                GunService.Client:RequestShoot(player, fakeChar.PrimaryPart.Position, Vector3.zAxis)
            end).to.never.throw()
        end)

        -- sus 
        it("trying to exploit the gun", function(): ()
            getAShip()
            
            local exploitivePosition: Vector3 = Vector3.new(500, 0, 0)

            expect(GunService.Client:RequestShoot(player, exploitivePosition, Vector3.xAxis)).never.to.be.ok()
        end)
        
        it("unequipping the gun", function(): ()
            getAShip()
        
            expect(function(): ()
                GunService.Client:SetGunState(player, false)
            end).to.never.throw()
        end)

        workspace.GunRays:Destroy()
    end)
end
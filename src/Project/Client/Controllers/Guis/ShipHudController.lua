--[[
    A small interface for when the user is piloting their ship
]]

------------------------------Roblox Services-----------------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Types-----------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

------------------------------Fields-----------------------------------

local shipHud: ScreenGui

------------------------------Service & Controller Dependencies-----------------------------------

local ShipController
local PurchaseController

------------------------------Knit Service-----------------------------------

local ShipHudController = Knit.CreateController({
    Name = "ShipHudController"
})

------------------------------Public Methods-----------------------------------

-- manage player controls for their ship and updating / prompting the ship thrusters gamepass
function ShipHudController:GuiLoaded(...: ScreenGui): ()
    shipHud = ...
    
    shipHud.CenterBottom.Tooltip.Label.MouseButton1Down:Connect(function(): ()
        ShipController:SetPiloting()
    end)

    --#region advertise special gamepass

    -- toggle the ship thrusters button off when the already have it
    local shipThrustersGamepass: Types.Purchase = PurchaseController:GetGamepass("ShipThrusters")
    local shipThrustersAttr: string = PurchaseController:GetGamepassAttributeName("ShipThrusters")

    local function ownsShipThrustersChanged(): ()
        local ownsShipThrusters: boolean = Knit.Player:GetAttribute(shipThrustersAttr)

        if not ownsShipThrusters then
            return
        end

        shipHud.CenterBottom.Tooltip.SpeedGamepass.Visible = false
    end

    Knit.Player:GetAttributeChangedSignal(shipThrustersAttr):Connect(ownsShipThrustersChanged)
    ownsShipThrustersChanged()

    shipHud.CenterBottom.Tooltip.SpeedGamepass.MouseButton1Down:Connect(function(): ()
        MarketplaceService:PromptGamePassPurchase(Knit.Player, shipThrustersGamepass.purchaseId)
        -- then handle changing the max speed and visibility of the boosters on the server
    end)

    --#endregion advertise special gamepass
end

-- disable / enable the ship hud gui
function ShipHudController:SetState(state: boolean): ()
    -- if false then unequip the blunderbuss
    shipHud.Enabled = state
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime controllers
function ShipHudController:KnitInit(): ()
	ShipController = Knit.GetController("ShipController")
	PurchaseController = Knit.GetController("PurchaseController")
end

return ShipHudController
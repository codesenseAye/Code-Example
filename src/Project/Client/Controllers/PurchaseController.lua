--[[
    Helps you not have to hardcode gamepass/devproduct ids in your code
    The data for what gamepasses and devproducts there are is in shared.data.purchases
    Throws an error if you try to reference a gamepass or devproduct that doesnt exist in the purchases data
    Has helper functions to get whether or not a player owns a specific gamepass
--]]

---------------------------Services----------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------Knit----------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

---------------------------Util----------------------------

-- intentionally left out type declarations to allow for vsc to use type inference from "require"
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

---------------------------Constants----------------------------

local IS_GAMEPASS_ATTR: string = "Gamepass"
local IS_DEVELOPER_PRODUCT_ATTR: string = "DevProduct"

-----------------------------Fields-----------------------------

local Purchase = require(ReplicatedStorage.Shared.Data.Purchases)

------------------------Knit Controller-------------------------

local PurchaseController = Knit.CreateController{
    Name = "PurchaseController"
}

------------------------Local Functions-------------------------

-- the data inside the purchase table is in the explicit types definition data file
local function getPurchaseFromName(purchaseType: string, purchaseName: number): Types.Purchase
    local gamepassPurchase: Types.Purchase
    local purchases: {Types.Purchase} = Purchase[purchaseType]

    for _, purchase: Types.Purchase in pairs(purchases) do
        if purchase.purchaseName ~= purchaseName then
            continue
        end

        gamepassPurchase = purchase
    end

    if not gamepassPurchase then
        error(`Purchase not found in {purchaseType} by: {purchaseName}`)
    end
    
    return gamepassPurchase
end

-- manage the tycoon product model in a tycoon
-- prompt the player with its purchase or make its pad disappear if its for example a gamepass and they own it
local function tycoonProductAdded(product: Model): ()
    local promptPurchasePad: Model = product:WaitForChild("PromptPurchasePad", 10)

    if not promptPurchasePad then
        warn("Failed to find prompt purchase pad in product:" .. product:GetFullName())
        return
    end

    local lastPrompted: number = 0

    promptPurchasePad.PrimaryPart.Touched:Connect(function(part: BasePart): ()
        local char: Model = part:FindFirstAncestorOfClass("Model")

        if char ~= Knit.Player.Character then
            return
        end

        local now: number = os.clock()

        if lastPrompted + 1 > now then
            return
        end

        lastPrompted = now

        -- similar yet different methods for prompting the player with the purchase
        -- any benefits from making these a shared function would be nullified by the short line length
        if product:GetAttribute(IS_GAMEPASS_ATTR) then
            local purchase: Types.Purchase = PurchaseController:GetGamepass(product.Name)
            MarketplaceService:PromptGamePassPurchase(Knit.Player, purchase.purchaseId)
        elseif product:GetAttribute(IS_DEVELOPER_PRODUCT_ATTR) then
            local purchase: Types.Purchase = PurchaseController:GetProduct(product.Name)
            MarketplaceService:PromptProductPurchase(Knit.Player, purchase.purchaseId)
        end
    end)

    -- cant make the pay disappear if its a devproduct since you can buy it multiple times
    if not product:GetAttribute(IS_GAMEPASS_ATTR) then
        return
    end

    local boughtGamepassTrove = Trove.new()
    boughtGamepassTrove:AttachToInstance(promptPurchasePad)

    local gamepassAttr: string = PurchaseController:GetGamepassAttributeName(product.Name)

    local function gamepassOwnedChanged(): ()
        local ownsGamepass: boolean = Knit.Player:GetAttribute(gamepassAttr)

        if not ownsGamepass then
            return
        end

        promptPurchasePad:Destroy()
    end

    boughtGamepassTrove:Connect(Knit.Player:GetAttributeChangedSignal(gamepassAttr), gamepassOwnedChanged)
    gamepassOwnedChanged()
end

------------------------Public Functions------------------------

-- used to get a boolean for whether or not the player owns a gamepass
-- can be used to listen to when a player buys a gamepass
-- (GetAttributeChangedSignal(getGamepassAttributeName(gamepassName)))
function PurchaseController:GetGamepassAttributeName(gamepassName: string): string
    local gamepassData: Types.Purchase = PurchaseController:GetGamepass(gamepassName)
    local attributeName: string = `Has{gamepassData.purchaseName}Gamepass`

    return attributeName
end

-- errors if it cannot find the purchase
-- signals to you quickly that you typed in the devproduct name incorrectly
function PurchaseController:GetProduct(devproductName: string): Types.Purchase
    return getPurchaseFromName("DevProducts", devproductName)
end

-- errors if it cannot find the purchase
-- signals to you quickly that you typed in the gamepass name incorrectly
-- duplicated from :GetProduct so that we have comments on both through signature help / hover on Roblox LSP
function PurchaseController:GetGamepass(gamepassName: string): Types.Purchase
    return getPurchaseFromName("Gamepasses", gamepassName)
end

-- should only be called by buildscontroller
function PurchaseController:HandleTycoonProducts(tycoon: Model): ()
    local products: Folder = tycoon:WaitForChild("Products")
    products.ChildAdded:Connect(tycoonProductAdded)

    for _, product: Model in ipairs(products:GetChildren()) do
        task.spawn(tycoonProductAdded, product)
    end
end

return PurchaseController
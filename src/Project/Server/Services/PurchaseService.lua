--[[
    Handles developer product purchases and detecting when a player owns a gamepass
    Helps you not have to hardcode gamepass/devproduct ids in your code
    The data for what gamepasses and devproducts there are is in shared.data.purchases
    Gamepass ownership can be verified on the client through attributes on their player object
    Developer product processes happen through registered callbacks
]]

----------------------------Services-----------------------------

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

----------------------------Knit-----------------------------

local Types = require(ReplicatedStorage.Shared.Types)
local Knit = require(ReplicatedStorage.Packages.Knit)

----------------------------Utils-----------------------------

-- intentionally left out type declarations to allow for vsc to use type inference from "require"
local Promise = require(ReplicatedStorage.Packages.Promise)

----------------------------Fields-----------------------------

local processors: {[string]: (receipt: {[string]: any}) -> Enum.ProductPurchaseDecision} = {}
local Purchases = require(ReplicatedStorage.Shared.Data.Purchases)

----------------------------Knit Service-----------------------------

local PurchaseService = Knit.CreateService({
    Name = "PurchaseService"
})

----------------------------Local Functions-----------------------------

-- returns a purchase type table by checking a specified index against a value provided
local function getPurchaseFromData(purchaseType: string, purchaseData: any, purchaseIndex: string): Types.Purchase
    local purchase: Types.Purchase
    local purchases: {Types.Purchase} = Purchases[purchaseType]

    for _, otherPurchase: Types.Purchase in pairs(purchases) do
        if otherPurchase[purchaseIndex] ~= purchaseData then
            continue
        end

        purchase = otherPurchase
    end

    return purchase
end

-- return the purchase table from the purchase id
local function getPurchaseFromId(purchaseType: string, purchaseId: number): Types.Purchase
    return getPurchaseFromData(purchaseType, purchaseId, "purchaseId")
end

-- return the purchase table from the purchase name
local function getPurchaseFromName(purchaseType: string, purchaseName: string): Types.Purchase
    return getPurchaseFromData(purchaseType, purchaseName, "purchaseName")
end

-- returns a modified version of the gamepass name string that removes everything except a-z & A-Z
-- this will be the string on the player object
local function getAttributeSafeGamepassName(gamepassName: string): string
    return `Has{gamepassName:gsub("%W+", "")}Gamepass`
end

-- sets the gamepass ownership attribute on the player object
-- you can pass the unsafe version of the gamepass name to this function
-- option to override the gamepass ownership state otherwise will query the current status
local function setGamepassOwned(player: Player, gamepassName: string, gamepassId: number, hasOverride: boolean?): ()
    local doesHaveGamepass: boolean = hasOverride

    if doesHaveGamepass == nil then
        doesHaveGamepass = PurchaseService:HasGamepass(player, gamepassId):expect()
    end

    player:SetAttribute(getAttributeSafeGamepassName(gamepassName), doesHaveGamepass)
    return doesHaveGamepass
end

-- called whenever a player is finished purchasing (or not purchased) a gamepass
-- sets their ownership status to an attribute
local function gamepassPurchased(
    player: Player, gamepassId: number, purchased: boolean
): ()
    if not purchased then
        return
    end

    local gamepassPurchase: Types.Purchase = getPurchaseFromId("Gamepasses", gamepassId)

    if not gamepassPurchase then
        warn("Couldn't find gamepass for purchase. Id: " .. tostring(gamepassId))
        return
    end

    -- notify the player with an attribute
    setGamepassOwned(player, gamepassPurchase.purchaseName, gamepassPurchase.purchaseId, true)
end

-- this needs to happen for gamepasses purchased outside of the game client
-- set the ownership of each gamepass when a player joins
local function playerAdded(player: Player): ()
    for _, gamepassPurchase: Types.Purchase in pairs(Purchases.Gamepasses) do
        local gamepassName: string = gamepassPurchase.purchaseName
        setGamepassOwned(player, gamepassName, gamepassPurchase.purchaseId)
    end
end

----------------------------Public Methods-----------------------------

-- returns the purchase found with the product id (specifically only developer products)
function PurchaseService:GetProduct(purchaseId: number): Types.Purchase
    return getPurchaseFromId("DevProducts", purchaseId)
end

-- returns the purchase found with the gamepass id (specifically only gamepasses)
function PurchaseService:GetGamepass(gamepassName: number): Types.Purchase
    return getPurchaseFromName("Gamepasses", gamepassName)
end

-- register a callback with an id
-- this callback is ran whenever a product is purchased
function PurchaseService:LinkProcessReceipt(
    callback: (receipt: {[string]: any}) -> Enum.ProductPurchaseDecision, processorId: string
): ()
    local processor: (receipt: {[string]: any}) -> () = processors[processorId]

    if processor then
        error("Processor already exists for id specified. Id: " .. processorId)
    end

    processors[processorId] = callback
end

-- safely and securely check if the player owns the gamepass passed
-- via 2 separate methods (attributes then an api call)
function PurchaseService:HasGamepass(player: Player, gamepassId: number): Types.Promise<boolean>
    local promise: Types.Promise<boolean> = Promise.new(function(
        resolve: Types.PromiseResolve, reject: Types.PromiseReject
    ): ()
        -- check to see if the gamepass purchase data exists
        local gamepassPurchase: Types.Purchase? = PurchaseService:_getGamepass(gamepassId)

        if not gamepassPurchase then
            warn("Unable to find gamepass: " .. tostring(gamepassId))
            return reject("Failed to find gamepass.")
        end
        
        -- check if the player owns the gamepass via attributes
        local gamepassAttribute: boolean = getAttributeSafeGamepassName(gamepassPurchase.purchaseName)
        local ownedAttribute: boolean = player:GetAttribute(gamepassAttribute)

        if ownedAttribute then
            return resolve(true)
        end

        resolve(MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId))
    end)

    return promise:catch(function(error: string?): ()
        warn(tostring(error))
    end)
end

----------------------------Private Methods----------------------------------

-- returns the purchase found with the product id (specifically only gamepasses)
function PurchaseService:_getGamepass(purchaseId: number): Types.Purchase
    return getPurchaseFromId("Gamepasses", purchaseId)
end

----------------------------Lifetime Methods-----------------------------

-- connect to important signals
function PurchaseService:KnitStart(): ()
    Players.PlayerAdded:Connect(playerAdded)

    for _, player: Player in ipairs(Players:GetPlayers()) do
        task.spawn(playerAdded, player)
    end

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(gamepassPurchased)
end

----------------------------Global Events Listener Assignment-----------------------------

-- for test ez, you cant assign the process receipt callback when not running the game
if not RunService:IsRunning() then
    return PurchaseService
end

-- handle a dev product purchase by finding its registered callback
MarketplaceService.ProcessReceipt = function(receipt: {[string]: any}): Enum.ProductPurchaseDecision
    local player: Player = Players:GetPlayerByUserId(receipt.PlayerId)

    if not player then
        warn("Player not found in game for receipt processing: " .. tostring(receipt.PlayerId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local purchase: Types.Purchase? = PurchaseService:GetProduct(receipt.ProductId)

    if not purchase then
        warn("Product not found by id: " .. tostring(receipt.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    for _, processor: Types.ReceiptProcessor in pairs(processors) do
        local response: Enum.ProductPurchaseDecision = processor(player, purchase)

        if response == Enum.ProductPurchaseDecision.PurchaseGranted then
            return response
        end
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end

return PurchaseService
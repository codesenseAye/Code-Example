--[[
    Describes all of the available items for purchase in the game
]]

local purchases: {
    [string]: {
        [string]: {[string]: number | table}
    }
} = {
    -- list the gamepasses and their ids
    Gamepasses = {
        AutoCollect = 178238774,
        ShipThrusters = 178238868,
    },

    -- list all of the dev products and the data associated with them
    -- for example a coins purchase which should include the data for how many coins to give
    DevProducts = {
        TimeTravel = {
            purchaseId = 1544304215,
            purchaseData = {}
        },
    }
}

-- add the purchase name / purchase id data afterward to reduce repetition
for gamepassName: string, gamepassId: number in pairs(purchases.Gamepasses) do
    purchases.Gamepasses[gamepassName] = {
        purchaseName = gamepassName,
        purchaseId = gamepassId
    }
end

-- add the purchase name data afterward to reduce repetition
for productName: string in pairs(purchases.DevProducts) do
    purchases.DevProducts[productName].purchaseName = productName
end

return purchases
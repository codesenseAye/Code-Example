--[[
	The data that all players will initially start with
]]

local defaultData = {
	money = 0,
	paycheck = 0,
	kills = 0,
	paycheckWithdrawAmount = 0,
	padsPurchased = {}
}

-- recursively freeze all table elements in the table passed and itself
local function freezeData(t: {[string]: any}): ()
	table.freeze(t)

	for _, value: any in pairs(t) do
		if typeof(value) == "table" then
			freezeData(value)
		end
	end
end

-- make sure the default data cannot change during runtime
-- attempting to change any value will result in an error and be immediately apparent to the developer
freezeData(defaultData)

return defaultData

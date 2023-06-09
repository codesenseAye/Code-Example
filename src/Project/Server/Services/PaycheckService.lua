--[[
	Handles steadily increasing their withdraw amount and giving the player their paychecks when they request it
]]

---------------------------Roblox Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

----------------------------Knit------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

----------------------------Types------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

---------------------------Constants----------------------------

local PAYCHECK_UPDATE_INTERVAL: number = 1

----------------------------Util------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Timer = require(ReplicatedStorage.Packages.Timer)

----------------------------Service/Controller Dependencies------------------------------

local DataService
local PurchaseService

---------------------------Knit Service----------------------------

local PaycheckService = Knit.CreateService({
	Name = "PaycheckService"
})

------------------------Local Functions-------------------------

-- wait 2 seconds after the player joins to start giving them a paycheck (because it was like that in the original)
-- give a paycheck at a regular interval and check to see if they have the auto collect gamepass for a bypass
local function onPlayerAdded(player: Player): ()
	local playerTrove = Trove.new()
	
	playerTrove:Connect(player.AncestryChanged, function(_, newParent: Instance?): ()
		if newParent then
			return
		end

		playerTrove:Destroy()
	end)

	local initialDelayTimer: RBXScriptConnection
	initialDelayTimer = playerTrove:Add(Timer.Simple(PAYCHECK_UPDATE_INTERVAL * 2, function(): ()
		initialDelayTimer:Disconnect()

		playerTrove:Add(Timer.Simple(PAYCHECK_UPDATE_INTERVAL, function(): ()
			local paycheck: number = DataService:GetPaycheck(player)
			local newPaycheckWithdraw: number = DataService:GetPaycheckWithdrawAmount(player) + paycheck
			
			DataService:SetPaycheckWithdrawAmount(player, newPaycheckWithdraw)
		end, true))
	end))

	--#region auto collect gamepass functionality

	local autoCollectPurchase: Types.Purchase = PurchaseService:GetGamepass("AutoCollect")

	playerTrove:Add(Timer.Simple(PAYCHECK_UPDATE_INTERVAL * 2, function(): ()
		local ownsAutoCollect: boolean = PurchaseService:HasGamepass(player, autoCollectPurchase.purchaseId):expect()

		if not ownsAutoCollect then
			return
		end

		PaycheckService.Client:RequestPaycheck(player)
	end))

	--#endregion auto collect gamepass functionality
end

----------------------------Client Methods------------------------------

-- stores/resets the paycheck withdraw amount they currently have then adds their withdraw amount to their data
function PaycheckService.Client:RequestPaycheck(player: Player): number
	local paycheck: number = DataService:GetPaycheckWithdrawAmount(player)

	DataService:SetPaycheckWithdrawAmount(player, 0)
	DataService:AddMoney(player, paycheck)

	return paycheck
end

------------------------Lifetime Methods------------------------

-- set global service variables
function PaycheckService:KnitInit(): ()
	DataService = Knit.GetService("DataService")
	PurchaseService = Knit.GetService("PurchaseService")
end

-- detect when a player joins and create a receipt processor for the time travel devproduct
function PaycheckService:KnitStart(): ()
	Players.PlayerAdded:Connect(onPlayerAdded)

	for _, player: Player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	--#region dev products for paychecks

	PurchaseService:LinkProcessReceipt(function(player: Player, purchase: Types.Purchase): Enum.ProductPurchaseDecision
		if purchase.purchaseName ~= "TimeTravel" then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local paycheckMultiplier: number = ((60 / PAYCHECK_UPDATE_INTERVAL) * 60) * 12
		-- 12 hours of paychecks

		local paycheck: number = DataService:GetPaycheck(player)
		paycheck *= paycheckMultiplier

		local paycheckWithdraw: number = DataService:GetPaycheckWithdrawAmount(player)
		paycheckWithdraw += paycheck
		
		DataService:SetPaycheckWithdrawAmount(player, paycheckWithdraw)

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end, "TimeTravel")

	--#endregion dev products for paychecks
end

return PaycheckService
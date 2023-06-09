--[[
	Shows data about how how much money the player has or how many kills they got etc
]]

---------------------------Roblox Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

----------------------------Knit------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

----------------------------Service/Controller Dependencies------------------------------

local DataController
local SoundController

---------------------------Knit Controller----------------------------

local HudController = Knit.CreateController({
	Name = "HudController"
})

------------------------Public Methods------------------------

-- find all ui elements we need and then update the labels with datacontroller events
function HudController:GuiLoaded(hud: ScreenGui): ()
	local rightMiddleFrame: Frame = hud:WaitForChild("RightMiddle")
	local currencies: Frame = rightMiddleFrame:WaitForChild("Currencies")
	local moneyLabel: TextLabel = currencies:WaitForChild("Money")
	local killsLabel: TextLabel = currencies:WaitForChild("Kills"):WaitForChild("Kills")

	local moneyKey: string = "money"
	
	DataController:OnValueChanged(Knit.Player, moneyKey, function(money: number): ()
		moneyLabel.Text = `{money} $`
	end, true)

	local killsKey: string = "kills"
	local lastKills: number
	
	DataController:OnValueChanged(Knit.Player, killsKey, function(kills: number): ()
		if lastKills then
			-- play a amusing sound when the player gets a kill
			SoundController:PlaySound("KillBell")
		end

		lastKills = kills
		killsLabel.Text = tostring(kills)
	end, true)
end

------------------------Lifetime Methods------------------------

-- set global controller variables
function HudController:KnitInit(): ()
	DataController = Knit.GetController("DataController")
	SoundController = Knit.GetController("SoundController")
end

return HudController
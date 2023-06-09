--[[
    Manages the players unlocking their buildings in their tycoons
	Also manages special case buildings such as the ship which needs to be rigged 
	so it cant be tweened together on the client
]]

------------------------------Services-----------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Types-----------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

----------------------------Util------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Timer = require(ReplicatedStorage.Packages.Timer)

------------------------------Constants-----------------------------------

local IS_FINISHED_ATTR: string = "IsFinished"
local OWNER_ATTR: string = "Owner"
local PROCESSED_ATTR: string = "Processed"

local TYCOON_TEMPLATE: Model
local TYCOONS: Folder

----------------------------Service/Controller Dependencies------------------------------

local DataService
local TycoonService
local ShipService

------------------------------Knit Service-----------------------------------

local PadService = Knit.CreateService({
	Name = "PadService",

	Client = {
		UnlockedBuild = Knit.CreateSignal()
	}
})

------------------------Local Functions-------------------------

-- we do this because .Destroying isnt called when you fall out of the world
-- trove.AttachToInstance uses it
local function attachTrove(trove: Types.Trove, object: Instance): ()
	trove:Connect(object.AncestryChanged, function(_, newParent: Instance?): ()
		if newParent then
			return
		end

		trove:Destroy()
	end)
end

-- put the replacement model in the tycoon pased and remove the previous one if there was one
-- and activate any special serversided logic
local function buildReplacementModel(tycoon: Model, replacementModel: Model): ()
	local templateBuild: Model = TYCOON_TEMPLATE.Buildings[replacementModel.Name]
	
	local templateBaseplate: Part = TYCOON_TEMPLATE.Baseplate
	local offset: CFrame = templateBaseplate.CFrame:ToObjectSpace(templateBuild:GetPivot())

	local buildingModel: Model = tycoon.Buildings:FindFirstChild(replacementModel.Name)

	if buildingModel then
		buildingModel:Destroy()
	end

	local existingReplacementModel: Model = tycoon.Special:FindFirstChild(replacementModel.Name)

	if existingReplacementModel then
		existingReplacementModel:Destroy()
	end

	replacementModel:PivotTo(tycoon.Baseplate.CFrame * offset)
	replacementModel.Parent = tycoon.Special
	
	if replacementModel.Name == "Ship" then
		ShipService:ManageShipThrusters(tycoon, replacementModel)
	end
end

-- specifically for the "ship" build, so we can replace it with the rigged version
local function checkForBuildReplacement(tycoon: Model, buildingModelName: string): ()
	local replacementModel: Model = ReplicatedStorage.Assets.FinalBuildReplacements:FindFirstChild(buildingModelName)

	if not replacementModel then
		return
	end

	replacementModel = replacementModel:Clone()

	local ownerPlayerUserId: number = tycoon:GetAttribute(OWNER_ATTR)
	local ownerPlayer: Player = Players:GetPlayerByUserId(ownerPlayerUserId)

	--#region spawn the ship whenever the players character is added or removed
	local trove = Trove.new()
	trove:AttachToInstance(tycoon)

	local buildTrove = Trove.new()

	buildTrove:Connect(ownerPlayer.CharacterAdded, function(): ()
		buildTrove:Destroy()
	end)

	buildTrove:Add(function(): ()
		if ownerPlayer.Parent then
			trove:Destroy()

			-- something went wrong or the player's character respawned
			checkForBuildReplacement(tycoon, buildingModelName)
		end
	end)

	local char: Model = ownerPlayer.Character or ownerPlayer.CharacterAdded:Wait()
	attachTrove(buildTrove, char)

	trove:Add(Timer.Simple(1, function(): ()
		trove:Destroy()

		buildReplacementModel(tycoon, replacementModel)
	end))

	--#endregion spawn the ship whenever the players character is added or removed
end

-- mark the pad as purchased in the players data and make a blank model in the buildings folder (for the client)
-- and check to see if its a special model (such as ship) for different action
local function buildFromPad(player: Player, pad: Model)
	local tycoon: Model = TycoonService:GetTycoonFromPlayer(player)
	local targetName: string = pad.Target.Value.Name

	-- we add an empty model as a signal to the clients to create it on their end
	-- and do effects etc
	local buildingModel: Model = Instance.new("Model")
	buildingModel.Name = targetName
	buildingModel.Parent = tycoon.Buildings

	-- dont forget to deskin your tycoon pads
	pad.Skin:Destroy()
	pad.Pad:Destroy()
	pad:SetAttribute(IS_FINISHED_ATTR, true)

	-- we wont need the billboard if its adornee is gone
	pad.BillboardGui:Destroy()

	local data: {[string]: any} = DataService:GetPlayerData(player)
	data.padsPurchased[targetName] = true

	checkForBuildReplacement(tycoon, buildingModel.Name)
end

-- get the player object of the tycoon passed
local function getTycoonOwner(tycoon: Model): Player?
	local ownerUserId: number = tycoon:GetAttribute(OWNER_ATTR)
	local ownerPlayer: Player = Players:GetPlayerByUserId(ownerUserId)

	if not ownerPlayer then
		error("Failed to get owner player of tycoon: " .. tycoon:GetFullName())
	end

	return ownerPlayer
end

-- parent / unparent the pad depending on whether or not the pads dependency object has a special attribute
local function attachToPadDependencyChanges(tycoon: Model, pad: Model): ()
	local dependencyFinishedTrove = Trove.new()
	dependencyFinishedTrove:AttachToInstance(tycoon)

	local function dependencyChanged(): ()
		dependencyFinishedTrove:Clean()

		local dependency: Model? = pad.Dependency.Value
		
		if not dependency then
			pad.Parent = tycoon.Pads
			return
		end

		local dependencyAttrChanged: RBXScriptSignal = dependency:GetAttributeChangedSignal(IS_FINISHED_ATTR)
		dependencyFinishedTrove:Connect(dependencyAttrChanged, dependencyChanged)

		local isFinished: boolean = dependency:GetAttribute(IS_FINISHED_ATTR)
		
		if not isFinished then
			pad.Parent = nil
			return
		end

		pad.Parent = tycoon.Pads
	end

	pad.Dependency:GetPropertyChangedSignal("Value"):Connect(dependencyChanged)

	-- to avoid a parent locked error
	task.defer(function(): ()
		if not tycoon:IsDescendantOf(workspace) then
			return
		end

		dependencyChanged()
	end)
end

-- create a billboard for the pad passed that shows its display name / cost (alias for 0 = "free")
local function addPadBillboard(pad: Model): ()
	local padBillboard: BillboardGui = ReplicatedStorage.Assets.PadBillboard:Clone()
	padBillboard.Frame.TitleLabel.Text = pad.DisplayName.Value

	local cost: number = pad.Cost.Value
	local costLabel: TextLabel = padBillboard.Frame.BottomFrame.OuterBottomFrame.InnerBottomFrame.BottomLabel

	if cost <= 0 then
		costLabel.Text = "Free"
	else
		costLabel.Text = cost
	end

	padBillboard.Adornee = pad.Pad
	padBillboard.Name = "BillboardGui"
	padBillboard.Parent = pad
end

-- detect when the pad has been touched by the owner of the tycoon
-- see if they have enough money to buy it then do so
-- making any changes to their paychecks etc
local function padAdded(pad: Model): ()
	-- make sure the same pad doesnt keep getting connections when its readded at "attachToPadDependencyChanges"
	if pad:GetAttribute(PROCESSED_ATTR) then
		return
	end

	pad:SetAttribute(PROCESSED_ATTR, true)
	
	local tycoon: Model = pad.Parent.Parent
	local ownerPlayer: Player = getTycoonOwner(tycoon)

	addPadBillboard(pad)
	attachToPadDependencyChanges(tycoon, pad)

	local data: {[string]: any} = DataService:GetPlayerData(ownerPlayer)
	local targetName: string = pad.Target.Value.Name

	-- if the player already bought it from a previous session
	if data.padsPurchased[targetName] then
		buildFromPad(ownerPlayer, pad)
		return
	end

	pad.Pad.Touched:Connect(function(hit: Part)
		local dependency: Model? = pad.Dependency.Value

		if dependency and not dependency:GetAttribute(IS_FINISHED_ATTR) then
			return
		end

		local character: Model = hit.Parent
		local player: Player? = Players:GetPlayerFromCharacter(character)

		-- check to make sure this player is the owner of this particular tycoon
		if not player or player ~= ownerPlayer then
			return
		end

		local cost: number = pad.Cost.Value
		local money: number = DataService:GetMoney(ownerPlayer)

		if money < cost then
			-- player cannot afford this pad
			return
		end

		--#region buying the pad
		local newPaycheck: number = DataService:GetPaycheck(player) + pad.PaycheckIncrease.Value
		DataService:SetPaycheck(player, newPaycheck)

		DataService:SubtractMoney(ownerPlayer, cost)

		PadService.Client.UnlockedBuild:Fire(ownerPlayer, pad.Name)
		buildFromPad(player, pad)
		--#endregion buying the pad
	end)
end

------------------------Public Methods------------------------

-- find all pads in the tycoon passed so that the player can purchase them
function PadService:CreatePadHandler(tycoon: Model): ()
	local pads: Folder = tycoon.Pads

	tycoon.Buildings:ClearAllChildren()
	pads.ChildAdded:Connect(padAdded)

	for _, pad: Model in ipairs(pads:GetChildren()) do
		padAdded(pad)
	end
end

------------------------Lifetime Methods------------------------

-- set global service variables
function PadService:KnitInit(): ()
	DataService = Knit.GetService("DataService")
	TycoonService = Knit.GetService("TycoonService")
	ShipService = Knit.GetService("ShipService")
end

-- set global variables that we will need later
function PadService:KnitStart(): ()
	TYCOONS = workspace:WaitForChild("Tycoons", 10)

	if not TYCOONS then
		error("Failed to find tycoons in workspace")
	end

	-- assuming tycoon service is successful
	TYCOON_TEMPLATE = ReplicatedStorage:WaitForChild("Template", 15)

	if not TYCOON_TEMPLATE then
		warn("Failed to get the tycoon template")
	end
end

return PadService
--[[
	Handles the function of the player collecting their paychecks and some effects for the machines
]]

---------------------------Roblox Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

----------------------------Knit------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

----------------------------Util------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Timer = require(ReplicatedStorage.Packages.Timer)

---------------------------Constants----------------------------

local OWNER_ATTR: string = "Owner"
local BALLOON_POPPING_ATTR: string = "Popping"
local GUN_HIT_ATTR: string = "GunHit"
local MINIMUM_COLLECT_INTERVAL: number = 1
local TYCOONS: Folder

----------------------------Service/Controller Dependencies------------------------------

local PaycheckService
local DataController
local SoundController

---------------------------Knit Controller----------------------------

local PaycheckMachineController = Knit.CreateController({
	Name = "PaycheckMachineController"
})

------------------------Local Functions-------------------------

--#region vfx for the paycheck machines

-- make the balloon small at first and tween it back to its original state
local function regenerateBalloon(balloon: Model, originalCF: CFrame, originalSize: Vector3): ()
	balloon.PrimaryPart.CFrame = originalCF * CFrame.new(0, -originalSize.Y / 2, 0)
	balloon.PrimaryPart.Size = Vector3.zero

	local regenerateTweenInfo: TweenInfo = TweenInfo.new(2, Enum.EasingStyle.Cubic)

	TweenService:Create(balloon.PrimaryPart, regenerateTweenInfo, {
		CFrame = originalCF,
		Size = originalSize,

		Transparency = 0
	}):Play()

	local trove = Trove.new()
	trove:AttachToInstance(balloon)

	trove:Add(Timer.Simple(regenerateTweenInfo.Time + 5, function(): ()
		trove:Destroy()
		balloon:SetAttribute(BALLOON_POPPING_ATTR)
	end))
end

-- make some sounds + grow the balloon out, then fade it out and then regrow it
local function popPaycheckMachineBalloon(balloon: Model): ()
	if balloon:GetAttribute(BALLOON_POPPING_ATTR) then
		return
	end

	balloon:SetAttribute(BALLOON_POPPING_ATTR, true)
	SoundController:PlaySound("Inflate", balloon.PrimaryPart.Position)

	local trove = Trove.new()
	trove:AttachToInstance(balloon)

	local originalCF: CFrame = balloon.PrimaryPart.CFrame
	local originalSize: Vector3 = balloon.PrimaryPart.Size

	local growingSize: Vector3 = originalSize * 1.2
	local growingTweenInfo: TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart)

	TweenService:Create(balloon.PrimaryPart, growingTweenInfo, {
		CFrame = originalCF * CFrame.new(0, growingSize.Y / 2, 0),
		Size = growingSize
	}):Play()

	-- wait for the time for the pop
	local growingFinisherTimerConn: RBXScriptConnection
	growingFinisherTimerConn = trove:Add(Timer.Simple(growingTweenInfo.Time / 2, function(): ()
		growingFinisherTimerConn:Disconnect()

		growingSize *= 2
		SoundController:PlaySound("Pop", balloon.PrimaryPart.Position)

		local popTweenInfo: TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad)

		TweenService:Create(balloon.PrimaryPart, popTweenInfo, {
			CFrame = originalCF * CFrame.new(0, growingSize.Y / 2, 0),
			Size = growingSize,
			Transparency = 1
		}):Play()

		-- wait a bit to regrow the balloon back
		trove:Add(Timer.Simple(popTweenInfo.Time + 0.5, function(): ()
			trove:Destroy()
			regenerateBalloon(balloon, originalCF, originalSize)
		end))
	end))
end

-- wait for balloons in the paycheck machine to get a gun hit boolean attr and then pop them
local function paycheckMachineBalloonPopFromGun(paycheckMachine: Model): ()
	local trove = Trove.new()
	trove:AttachToInstance(paycheckMachine)

	--detect any change in the gun hit attr on the balloon and pop it if its true
	local function balloonAdded(balloon: Model): ()
		local balloonPrimaryPart: Part = balloon.PrimaryPart

		if not balloonPrimaryPart then
			balloon:GetPropertyChangedSignal("PrimaryPart"):Wait()
			balloonPrimaryPart = balloon.PrimaryPart
		end

		local function gunHitChanged(): ()
			if not balloon.PrimaryPart:GetAttribute(GUN_HIT_ATTR) then
				return
			end

			popPaycheckMachineBalloon(balloon)
		end

		trove:Connect(balloon.PrimaryPart:GetAttributeChangedSignal(GUN_HIT_ATTR), gunHitChanged)
		gunHitChanged()
	end

	local balloons: Folder = paycheckMachine:WaitForChild("Balloons", 10)

	if not balloons then
		warn("Failed to find balloons in the tycoon:", paycheckMachine:GetFullName())
		return
	end

	balloons.ChildAdded:Connect(balloonAdded)

	for _, balloon: Model in ipairs(balloons:GetChildren()) do
		task.spawn(balloonAdded, balloon)
	end
end

--#endregion vfx for the paycheck machines

--play a coins sound and make some particles
local function doPaycheckMachineEffect(paycheckMachine: Model): ()
	local coinsBank: ParticleEmitter = paycheckMachine.CherryAnchor.CoinsBank
	coinsBank:Emit(coinsBank.Rate / 10)

	SoundController:PlaySound("Coin", paycheckMachine.PrimaryPart.Position)
end

-- looks up at the parents of the part passed until it reaches the workspace or goes nil
local function getCharacterFromWorldPart(part: Part | MeshPart): Model?
	local character: Model = part

	repeat
		character = character.Parent
	until character.Parent == workspace or not character

	return character
end

-- handle the paycheck pad being touched by its owner player and request to cashout
local function paycheckMachineAdded(paycheckMachine: Model): ()
	local pad: BasePart = paycheckMachine.PadComponents:WaitForChild("Pad", 10)
	local lastInteraction: number = 0

	local tycoon: Model = paycheckMachine.Parent.Parent
	local tycoonOwnerUserId: number = tycoon:GetAttribute(OWNER_ATTR)

	paycheckMachineBalloonPopFromGun(paycheckMachine)

	pad.Touched:Connect(function(hit: Part)
		local now: number = os.clock()

		if now - lastInteraction < MINIMUM_COLLECT_INTERVAL then
			return
		end

		local character: Model = getCharacterFromWorldPart(hit)

		-- make sure our character touched the paycheck machine
		if not character or character ~= Knit.Player.Character then
			return
		end

		-- make sure this is our tycoon
		if tycoonOwnerUserId ~= Knit.Player.UserId then
			return
		end

		lastInteraction = now
		PaycheckService:RequestPaycheck()

		-- do effects after the important parts incase this below errors
		doPaycheckMachineEffect(paycheckMachine)
	end)
end

-- update all labels on every paycheck machine the tycoon passed with the amount passed
local function updatePaycheckOnPaycheckMachines(tycoon: Model, amount: number): ()
	local paycheckMachines: Folder = tycoon.PaycheckMachines

	for _, paycheckMachine: Model in ipairs(paycheckMachines:GetChildren()) do
		local moneyLabel: TextLabel? = paycheckMachine:FindFirstChild("MoneyLabel", true)
		-- recursively finding the label is expensive but as long as we only do it here infrequently its fine
		-- might want to change it if there is ever more than 1 paycheck machine

		if not moneyLabel then
			warn("Failed to find money label on paycheck machine:", paycheckMachine:GetFullName())
			continue
		end

		moneyLabel.Text = `{amount} $`
	end
end

-- manage all paycheck machines and updating their withdraw amounts in this tycoon
local function tycoonAdded(tycoon: Model): ()
	local paycheckMachines: Folder = tycoon:WaitForChild("PaycheckMachines", 10)

	if not paycheckMachines then
		warn("Failed to get paycheck machines:" .. tycoon:GetFullName())
		return
	end

	paycheckMachines.ChildAdded:Connect(paycheckMachineAdded)

	for _, paycheckMachine: Model in ipairs(paycheckMachines:GetChildren()) do
		paycheckMachineAdded(paycheckMachine)
	end

	local function paycheckChanged(paycheck: number)
		updatePaycheckOnPaycheckMachines(tycoon, paycheck)
	end

	local trove = Trove.new()
	trove:AttachToInstance(tycoon)

	local paycheckWithdrawAmountKey: string = "paycheckWithdrawAmount" -- always use separate variables for data keys
	trove:Add(DataController:OnValueChanged(Knit.Player, paycheckWithdrawAmountKey, paycheckChanged, true))
end

------------------------Lifetime Methods------------------------

-- set global controller / service variables
function PaycheckMachineController:KnitInit(): ()
	PaycheckService = Knit.GetService("PaycheckService")
	DataController = Knit.GetController("DataController")
	SoundController = Knit.GetController("SoundController")
end

-- initiate logic
function PaycheckMachineController:KnitStart(): ()
	TYCOONS = workspace:WaitForChild("Tycoons", 15)

	if not TYCOONS then
		error("Failed to find tycoons in the workspace")
	end

	TYCOONS.ChildAdded:Connect(tycoonAdded)

	for _, tycoon: Model in ipairs(TYCOONS:GetChildren()) do
		-- using task.spawn here incase something went wrong with one of them
		-- it doesnt stop the loading of all of the others
		task.spawn(tycoonAdded, tycoon)
	end
end

return PaycheckMachineController
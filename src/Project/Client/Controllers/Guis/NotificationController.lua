--[[
    Handles creating notifications for builds and tips
]]

------------------------------Roblox Services-----------------------------------

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Types-----------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)

------------------------------Constants-----------------------------------

local SEPCIAL_MODEL_NOTIFICATION_ATTR: string = "Notification"

------------------------------Fields-----------------------------------

local notification: ScreenGui

------------------------------Service & Controller Dependencies-----------------------------------

local DataController
local PadService

------------------------------Knit Service-----------------------------------

local NotificationController = Knit.CreateController({
    Name = "NotificationController"
})

------------------------------Public Methods-----------------------------------

-- set the global notification screen gui variable
function NotificationController:GuiLoaded(...): ()
    notification = ...
end

-- puts a notification on the screen with the text passed for a specified or unspecified amount of time
function NotificationController:CreateNotification(notificationText: string, presistTime: number): ()
    local notificationFrame: Frame = notification.TopMiddle.Notifications.Template:Clone()
    notificationFrame.LayoutOrder = os.time() -- so that the earliest is at the bottom
    notificationFrame.Label.Text = notificationText
    notificationFrame.Name = "Notification"
    notificationFrame.Parent = notification.TopMiddle.Notifications
    notificationFrame.Visible = true

    Debris:AddItem(notificationFrame, presistTime or 4)
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime controllers / services
function NotificationController:KnitInit(): ()
    DataController = Knit.GetController("DataController")
	PadService = Knit.GetService("PadService")
end

-- start up logic
function NotificationController:KnitStart(): ()
    local lastPaycheckAmount: number
    local paycheckKey: string = "paycheck"

    -- create a notification for whenever the player's paycheck increases
    DataController:OnValueChanged(Knit.Player, paycheckKey, function(paycheck: number): ()
        if lastPaycheckAmount then
            local notificationText: string = `Your paycheck has increased to {math.floor(paycheck)}`
            NotificationController:CreateNotification(notificationText)
        end

        lastPaycheckAmount = paycheck
    end, true)

    local tycoonTemplate: Model = ReplicatedStorage:WaitForChild("Template", 10)

    if not tycoonTemplate then
        error("Failed to get the tycoon template")
    end

    -- put a notification on screen for when the player purchases a pad / unlocks a build
    PadService.UnlockedBuild:Connect(function(buildName: string): ()
        local buildModel: Model = tycoonTemplate.Pads[buildName]
        local notificationText: string = `You unlocked {buildModel.DisplayName.Value}`
        
        -- some building models are specific (the ship for example)
        -- and might need a notification for instructions on how to use it
        local specialModel: Model = ReplicatedStorage.Assets.FinalBuildReplacements:FindFirstChild(buildName)

        if specialModel then
            local specialNotificationText: string = specialModel:GetAttribute(SEPCIAL_MODEL_NOTIFICATION_ATTR)
            if specialNotificationText then
                NotificationController:CreateNotification(specialNotificationText, 15)
            end
        end

        NotificationController:CreateNotification(notificationText)
    end)
end

return NotificationController
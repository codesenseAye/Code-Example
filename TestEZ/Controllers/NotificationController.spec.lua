--[[
    Make sure the notification interface works
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

return function(): ()
    require(script.Parent.PrepareControllers)()

    local Knit = require(ReplicatedStorage.Packages.Knit)
    local NotificationController = Knit.GetController("NotificationController")

    describe("using the notifications", function(): ()
        it("pop up notifications", function(): ()
            local notificationGui: ScreenGui = StarterGui.Notification:Clone()
            notificationGui.Parent = StarterGui
            Debris:AddItem(notificationGui, 2)

            NotificationController:GuiLoaded(notificationGui)
            
            expect(function(): ()
                NotificationController:CreateNotification("testy testy")
            end).never.to.throw()

            local notificationFrame: Frame = notificationGui.TopMiddle.Notifications:FindFirstChild("Notification")
            expect(notificationFrame).to.be.ok()

            expect(function(): ()
                NotificationController:CreateNotification("test again", 10)
            end).never.to.throw()
            
            notificationFrame:Destroy()

            notificationFrame = notificationGui.TopMiddle.Notifications:FindFirstChild("Notification")
            expect(notificationFrame).to.be.ok()
        end)
    end)
end
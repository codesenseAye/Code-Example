--[[
    Handles toggling the players gun on/off and intriguing the player with a tooltip
]]

------------------------------Roblox Services-----------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Constants-----------------------------------

local GUN_STATE_ATTR: string = "GunState"

------------------------------Fields-----------------------------------

local toolbar: ScreenGui
local showTooltipNum: number = 0

------------------------------Service & Controller Dependencies-----------------------------------

local GunController

------------------------------Knit Service-----------------------------------

local ToolbarController = Knit.CreateController({
    Name = "ToolbarController"
})

------------------------------Local Functions-----------------------------------

-- toggle the visibility of the tooltip on the tool passed for a sec
-- currently only works for one tool
local function showTooltip(tool: TextButton): ()
    showTooltipNum += 1
    local localShowTooltipNum: number = showTooltipNum

    tool.Tooltip.Visible = true

    task.delay(1, function(): ()
        if localShowTooltipNum ~= showTooltipNum then
            return
        end

        tool.Tooltip.Visible = false
    end)
end

-- changes the visuals of the gun tool button when its equipped or not equipped
local function myCharacterAdded(char: Model): ()
    local function gunStateChanged(): ()
        local gunState: boolean = char:GetAttribute(GUN_STATE_ATTR)

        toolbar.CenterBottom.Toolbar.Blunderbuss.UIStroke.Color = if not gunState then
            Color3.fromRGB(69, 198, 101)
        else
            Color3.fromRGB(82, 198, 188)

        toolbar.CenterBottom.Toolbar.Blunderbuss.UIStroke.Thickness = if not gunState then
            3
        else
            5
    end

    char:GetAttributeChangedSignal(GUN_STATE_ATTR):Connect(gunStateChanged)
    gunStateChanged()
end

------------------------------Public Methods-----------------------------------

-- manage input on the gun tool button and disabling the backpack
function ToolbarController:GuiLoaded(...: ScreenGui): ()
    toolbar = ...

    local char: Model = Knit.Player.Character
    Knit.Player.CharacterAdded:Connect(myCharacterAdded)

    if char then
        task.spawn(myCharacterAdded, char)
    end
    
    local blunderbuss: TextButton = toolbar.CenterBottom.Toolbar.Blunderbuss

    --#region gun input controls

    blunderbuss.MouseButton1Down:Connect(function(): ()
        if not GunController:IsGunUnlocked() then
            showTooltip(blunderbuss)
            return
        end

        GunController:ToggleGun()
    end)

    UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
        if gameProcessed then
            return
        end

        if input.KeyCode == Enum.KeyCode.One then
            if not GunController:IsGunUnlocked() then
                showTooltip(blunderbuss)
                return
            end

            GunController:ToggleGun()
        end
    end)

    --#endregion gun input controls

    GunController:OnGunUnlocked(function(): ()
        blunderbuss.LockedIcon.Visible = false
        blunderbuss.Locked.Visible = false
    end)

    -- perpetually try to disable the backpack until it works
    -- because sometimes it will not work (coregui not loaded or something)
    local function disableBackpack()
        local success: boolean, fail: string = pcall(function(): ()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end)

        if not success then
            warn(fail)
            task.delay(1, disableBackpack)
        end
    end

    disableBackpack()
end

-- disable / enable the toolbar (for example the ship hud would overlap if this wasnt provided)
function ToolbarController:SetState(state: boolean): ()
    toolbar.Enabled = state
end

------------------------------Lifetime Methods-----------------------------------

-- define global lifetime controllers / services
function ToolbarController:KnitInit(): ()
	GunController = Knit.GetController("GunController")
end

return ToolbarController
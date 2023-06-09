--[[
	A basic data management system that uses ReplicaService and ProfileService
	no set/get methods are necessary thanks to a metamethod system but there are some provided
]]

---------------------------Roblox Services----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

----------------------------Knit------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

----------------------------Types------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

----------------------------Util-----------------------------------

local ReplicaService
local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local ProfileService = require(ServerStorage.Modules.ProfileService)

---------------------------Constants----------------------------

local DEFAULT_DATA = require(ServerStorage.Modules.DefaultData)

local TEST_KEY = "9"
local LIVE_KEY = "11" -- careful with this one

local PROFILE_RETRIEVAL_TIMEOUT: number = 60
local GAME_PROFILE_STORE

----------------------------Fields------------------------------

local PlayerData = {}

---------------------------Knit Service----------------------------

local DataService = Knit.CreateService({
    Name = "DataService",

    PlayerDataLoaded = Signal.new(), --Signal Format: (player: Player) -> ()
    ReleasedPlayerData = Signal.new()
})

------------------------Local Functions-------------------------

-- return a table that is monitored by metamethods
-- so that we dont have to use methods for setting data and instead get a signal from the traditional way
-- this is a bit risky potentially bug wise but its a neat idea
-- !! doing it this way is convenient but it does not help when debugging because there will be no stack trace
local function getShadowData(dataReplica: Types.Replica, data: {[string]: any}): {[string]: any}
	local shadowData = {} -- intentionally empty so that the metamethods go off
	-- doesnt work with anything deeper than 1 index as there wont be metamethods
	-- we dont need that in the current games state
	-- but that is also possible to do in the future

	--#region as minimal infrastructure as possible to make the replica send updates to the client
	setmetatable(shadowData, {
		__newindex = function(_, index: string, value: any): ()
			dataReplica:SetValue(index, value)
		end,
		__index = function(_, index: string): any
			return data[index]
		end
	})
	--#endregion

	return shadowData
end

-- load the data of the player minding sessionlocking and pass it along to the data replica handler
-- release the lock when the playe rleaves
local function onPlayerAdded(player: Player): ()
    local playerProfile: Types.ProfileStore = GAME_PROFILE_STORE:LoadProfileAsync(
        "Player_" .. player.UserId,
        "ForceLoad"
    )

	if playerProfile == nil then
		-- this only happens if the player rejoins too quickly or they are somehow present in two game sessions
		-- prevents duplication exploits and overwriting data resulting in data loss
		player:Kick("Unable to get session-lock on your profile")
		return
	end

	playerProfile:Reconcile()

	playerProfile:ListenToRelease(function()
		local dataKey: string = tostring(player.UserId)
		PlayerData[dataKey] = nil
		
		DataService.ReleasedPlayerData:Fire(player)

		-- the player will only ever see this message if they are somehow present in two servers at the same time
		-- such as in being studio and the roblox client at the same time
		-- preventing data loss

		player:Kick("Your session-lock was released")
	end)

	-- the player left are the data was retrieved
	if not player:IsDescendantOf(Players) then
		playerProfile:Release()
		return
	end

	local playerTrove = Trove.new()

	-- because .Destroying isnt fired when the player leaves so trove.AttachToInstance will not work
	playerTrove:Connect(player.AncestryChanged, function(_, newParent: Instance?): ()
		if newParent then
			return
		end

		playerTrove:Destroy()
	end)

	playerTrove:Add(function(): ()
		warn("Released data:" .. player.Name) -- useful for seeing the traffic of the server at a glance
		-- you can possibly add more to this such as how long they were in the game for example
		-- its a quick metric to confirm there isnt a worst case scenario
		-- like if your players are encountering a game breaking bug as soon as they join

		playerProfile:Release()
	end)

	playerTrove:Add(DataService:_handleDataReplica(player, playerProfile.Data))
	DataService.PlayerDataLoaded:Fire(player)
end

------------------------Public Methods------------------------

-- retrieve the withdraw amount that the player can currently cash out
function DataService:GetPaycheckWithdrawAmount(player): number
	local data = DataService:GetPlayerData(player)
	return data.paycheckWithdrawAmount
end

-- set the withdraw amount that the player can cash out
function DataService:SetPaycheckWithdrawAmount(player, amount): ()
	local data = DataService:GetPlayerData(player)
	data.paycheckWithdrawAmount = amount
end

-- return a table of data that the player has
-- it actually a shadow table (its an empty table with metamethods)
-- this yields incase the player's data isnt ready yet
function DataService:GetPlayerData(player: Player): {[string]: any}
    local dataKey: string = tostring(player.UserId)
	local data = PlayerData[dataKey]

	if not data then
		local dataLoaded = Promise.fromEvent(DataService.PlayerDataLoaded):timeout(PROFILE_RETRIEVAL_TIMEOUT)
		dataLoaded:await()

		data = PlayerData[dataKey]

		if not data then
			error("Failed to get player data: " .. player.Name)
		end

		if not player.Parent then
			error("Player left while waiting for data: " .. player.Name)
		end
	end

	return data
end

-- return the amount of money the player currently has
function DataService:GetMoney(player: Player): number
	local data = DataService:GetPlayerData(player)
	return data.money
end

-- set the amount of money the player has
function DataService:SetMoney(player: Player, amount: number): ()
	local data = DataService:GetPlayerData(player)
	data.money = amount
end

-- return the amount of money the player will get at an interval
function DataService:GetPaycheck(player: Player): number
	local data = DataService:GetPlayerData(player)
	return data.paycheck
end

-- set the amount of money the player should get at an interval
function DataService:SetPaycheck(player: Player, amount: number): ()
	local data = DataService:GetPlayerData(player)
	data.paycheck = amount
end

-- add to the amount of money that the player currently has
function DataService:AddMoney(player: Player, amount: number): ()
	local data = DataService:GetPlayerData(player)
	data.money += amount
end

-- remove money from the player
-- this is not protected from going negative
function DataService:SubtractMoney(player: Player, amount: number): ()
	local data = DataService:GetPlayerData(player)
	data.money -= amount
end

-----------------------Private Methods------------------------

-- create a replica to share the players data over the network (this isnt able to be changed by them its only a copy)
-- sets their playerdata table info to a shadow table (so that we get signals for when it changes) 
function DataService:_handleDataReplica(player: Player, data: {[string]: any}): ()
	local dataKey: string = tostring(player.UserId)
	local replicaClassToken: {[string]: any} = ReplicaService.NewClassToken(dataKey)

	local dataReplica = ReplicaService.NewReplica({
        ClassToken = replicaClassToken,
        Replication = "All",
		-- you can change this to the one player or all players depending on future features (such as trading)
        
		-- referenced assignment so that updating the replica data also updates the profile data
        Data = data
    })

	PlayerData[dataKey] = getShadowData(dataReplica, data)

	local dataTrove = Trove.new()

	dataTrove:Add(function(): ()
		dataReplica:Destroy()
	end)

	return dataTrove
end

------------------------Lifetime Methods------------------------

-- create the game profile store and listen for players joining
function DataService:KnitStart(): ()
	if RunService:IsRunning() then
		ReplicaService = require(ServerScriptService.ReplicaService)

		GAME_PROFILE_STORE = ProfileService.GetProfileStore(
			RunService:IsStudio() and TEST_KEY or LIVE_KEY, --whether we're debugging or this in the live game
			DEFAULT_DATA
		)
	else -- for test ez
		ReplicaService = {NewReplica = function(opts: {[string]: any}): ...any
			local fakeReplica: table = {Data = opts.Data}

			-- simplest functional version for our needs when running testez cases
			function fakeReplica:SetValue(i: string, v: any): ()
				self.Data[i] = v
			end

			return fakeReplica
		end, NewClassToken = function(classTokenStr: string): ()
			return classTokenStr
		end}
		
		onPlayerAdded = function(player: Player): ()
			DataService:_handleDataReplica(player, TableUtil.Copy(DEFAULT_DATA, true))
		end
	end

	-- this format of childadded then getchildren is extremely reliable for never missing a single object
	-- say knit takes a long amount of time to load (like something yielding in a knitinit method) 
	-- and a player joins before its done (just by a slight margin)
	-- the player's experience would be completely destroyed

    Players.PlayerAdded:Connect(onPlayerAdded)

    for _, player: Player in ipairs(Players:GetPlayers()) do
        task.spawn(onPlayerAdded, player)
    end
end

return DataService

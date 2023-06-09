--[[
    Handles receiving data from replicaservice and provides some very basic tools for accessing it
]]

------------------------------Services-----------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------Knit-----------------------------------

local Knit = require(ReplicatedStorage.Packages.Knit)

------------------------------Types-----------------------------------

local Types = require(ReplicatedStorage.Shared.Types)

------------------------------Util-----------------------------------

local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)
local ReplicaController = require(ReplicatedStorage.ReplicaController)

------------------------------Knit Controller-----------------------------------

local DataController = Knit.CreateController({
    Name = "DataController"
})

------------------------------Public Methods-----------------------------------

-- return the table of data the player passed has
function DataController:GetData(player: Player): {[string]: any}
    local success: boolean, dataReplica: Types.Replica = DataController:_getReplica(player):await()
    
    if not success then
        -- warn is in the function called
        return
    end

    -- as a note i believe it is unsafe to pass back a reference to this important table
    -- i would deep copy this data in a real scenario
    return dataReplica.Data
end

-- fire the callback whenever the index in the players data passed changes
function DataController:OnValueChanged(
    player: Player, index: string, callback: (value: any) -> (), runCallbackNow: boolean
): {[string]: any}
    local success: boolean, dataReplica: Types.Replica = DataController:_getReplica(player):await()
    
    if not success then
        -- warn is in the function called
        return
    end
    
    local connectionRef: RBXScriptConnection = dataReplica:ListenToChange(index, callback)

    if runCallbackNow then
        -- the data retrieval could yield and so to match roblox's default :Connect behavior we dont want that
        task.spawn(function(): ()
            local data = DataController:GetData(player)
            callback(data[index])
        end)
    end

    return connectionRef --in case you need to do anything with it later.
end

------------------------------Private Methods-----------------------------------

-- interface with replicacontroller to get the player's data preemptively
function DataController:_getReplica(player: Player): Types.Promise<table>
    local dataKey: string = tostring(player.UserId)

    local dataReplica: Types.Replica = ReplicaController.ReplicaClasses[dataKey]
	local replicaTrove = Trove.new()

	--immediately resolve if possible (just in case)
	if dataReplica then
        replicaTrove:Destroy()
		return Promise.resolve(dataReplica)
	end

    --replica wasnt immediately available so we wait
	local response = Promise.new(function(resolve: Types.PromiseResolve)
		if dataReplica then
			resolve(dataReplica)
			return
		end

		replicaTrove:Add(ReplicaController.ReplicaOfClassCreated(dataKey, resolve))
	end)
	:tap(function()
		-- the replica controller has had time to create the class
		replicaTrove:Destroy()
	end)
	--by this point the replica should exist and if not then something else is very wrong
	:andThen(function(replica: Types.Replica)
		if not replica then
			warn("ReplicaService passed a nil reference on class created. \nTrace:", debug.traceback())
			return Promise.reject()
		end

		return Promise.resolve(replica)
	end, function(error: string?): ()
        warn(tostring(error))
    end)

    local trace: string = debug.traceback()

    response:timeout(10):catch(function(): ()
        warn("Waiting an usually long amount of time for retrieving a replica:", trace)
    end)

	return response
end

------------------------------Lifetime Methods-----------------------------------

-- start up logic
function DataController:KnitStart(): ()
    ReplicaController:RequestData()
end

return DataController
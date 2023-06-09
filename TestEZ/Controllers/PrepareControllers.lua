--[[
    sets up the knit package to work without running the game and preserve its original state
    !!! MAKE SURE TO RECONNECT ROJO AFTER PERFORMING TESTS
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Debris = game:GetService("Debris")

local prepared: boolean = false

-- create a bunch of remote events with the names provided - which should be removed later
-- !! avoid multiple replica remote events in replicatedstorage at the same time or we'll get very inconsistent results
local function batchCreateAliasRemoteEvents(parent: Folder, events: {string}): ()
    for _, eventName: string in ipairs(events) do
        local remoteEvent: RemoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = eventName
        remoteEvent.Parent = parent
    end
end

return function(): ()
    if prepared then
        return
    end

    prepared = true

    local replicaRemoteEventsFolder: Folder = Instance.new("Folder")
    replicaRemoteEventsFolder.Name = "ReplicaRemoteEvents"
    replicaRemoteEventsFolder.Parent = ReplicatedStorage
    
    --not cleaning up this folder creates a inconsistent gameplay experience
    -- two of them means the server can fire events in one folder and the clients are listening in another
    Debris:AddItem(replicaRemoteEventsFolder, 10)

    batchCreateAliasRemoteEvents(replicaRemoteEventsFolder, {
        "Replica_ReplicaRequestData",
        "Replica_ReplicaSetValue",
        "Replica_ReplicaSetValues",
        "Replica_ReplicaArrayInsert",
        "Replica_ReplicaArraySet",
        "Replica_ReplicaArrayRemove",
        "Replica_ReplicaWrite",
        "Replica_ReplicaSignal",
        "Replica_ReplicaSetParent",
        "Replica_ReplicaCreate",
        "Replica_ReplicaDestroy"
    })

    local player: Player = game.Players.LocalPlayer

    local knitSplitter: ModuleScript = ReplicatedStorage.Packages._Index["sleitnick_knit@1.5.1"].knit
    local originalSplitter: ModuleScript = knitSplitter:FindFirstChild(knitSplitter.Name)
    
    if not originalSplitter then
        -- you'll need to reconnect rojo to correct this
        originalSplitter = knitSplitter:Clone()
        originalSplitter:ClearAllChildren()
        originalSplitter.Parent = knitSplitter
    end

    knitSplitter.Source = "return require(script.KnitClient)"

    local knitServerCopy: ModuleScript = knitSplitter:FindFirstChild("knitserver")
    if not knitServerCopy then
        knitServerCopy = knitSplitter.KnitServer:Clone()
        knitServerCopy.Name = knitServerCopy.Name:lower()
        knitServerCopy.Parent = knitSplitter
    end

    local knit: Folder = StarterPlayer.StarterPlayerScripts.Knit:Clone()
    knit.Parent = player.PlayerScripts

    require(player.PlayerScripts.Knit.KnitExecution)

    Debris:AddItem(knit, 2)
end
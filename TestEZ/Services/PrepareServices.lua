--[[
    Prepare the knit framework to be used inside of studio without being run (like a plugin)
    !!! MAKE SURE TO RECONNECT ROJO AFTER PERFORMING TESTS
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local prepared: boolean = false

-- make sure that the knit server modulescript is up to date
-- and the knit splitter's environment is reset (by replacing it)
local function ensureKnitServerIsReady(knitSplitter: ModuleScript): ModuleScript
    local duplicatedKnitSplitter: ModuleScript = knitSplitter:Clone()
    duplicatedKnitSplitter.Parent = knitSplitter.Parent

    knitSplitter:Destroy()
    knitSplitter = duplicatedKnitSplitter

    if knitSplitter:FindFirstChild("KnitServer") then
        return knitSplitter
    end

    local knitServerCopy: ModuleScript = knitSplitter:FindFirstChild("knitserver")
    
    if knitServerCopy then
        knitServerCopy.Name = "KnitServer"
    end

    return knitSplitter
end

return function(): ()
    if prepared then
        return
    end

    prepared = true

    local Knit
    local knitSplitter: ModuleScript = ReplicatedStorage.Packages._Index["sleitnick_knit@1.5.1"].knit

    if not RunService:IsRunning() then
        -- bypass knits server / client check because itll think our studio client is the roblox client
        local originalSplitter: ModuleScript = knitSplitter:FindFirstChild("knit")
        
        if not originalSplitter then
            -- you'll need to reconnect rojo to correct this
            originalSplitter = knitSplitter:Clone()
            originalSplitter:ClearAllChildren()
            originalSplitter.Parent = knitSplitter
        end
    
        knitSplitter.Source = "return require(script.KnitServer)"
        knitSplitter = ensureKnitServerIsReady(knitSplitter)

        Knit = require(knitSplitter)
    end

    -- we need to refresh all of the modulescript environments because the client side needed to require them
    for _, serviceModule: ModuleScript in ipairs(ServerScriptService.Knit.Services:GetChildren()) do
        local newServiceModule: ModuleScript = serviceModule:Clone()
        newServiceModule.Parent = ServerScriptService.Knit.Services

        serviceModule:Destroy()
    end

    -- fake some of the functions on knit so we dont encounter a bunch of errors

    Knit.CreateService = function() return {Client = {}} end
    
    local started: {[string]: boolean} = {}

    Knit.GetService = function(serviceName: string): table
        local service: table = require(ServerScriptService.Knit.Services[serviceName])
        
        if started[serviceName] then
            return service
        end

        started[serviceName] = true

        if service.KnitInit then
            service:KnitInit()
        end

        if service.KnitStart then
            service:KnitStart()
        end

        return service
    end

    require(ServerScriptService.Knit.KnitExecution)
end
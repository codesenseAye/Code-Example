--[[
    Describes common types used among the controllers/services
]]

-------------------------Client Types--------------------------

export type ReplicaController = {
    RequestData: (self: any) -> (),
    ReplicaClasses: {[string]: Replica},
    ReplicaOfClassCreated: (
        replicaToken: string,
        gotReplica: (replica: Replica) -> ()
    ) -> RBXScriptSignal
}

export type ReceiptProcessor = (player: Player, purchase: Purchase) -> Promise<Enum.ProductPurchaseDecision>

-------------------------Server Types--------------------------

export type ProfileStore = {
    Release: () -> (),
    Reconcile: () -> (),
    Data: {[string]: any}
}

export type ReplicaClassToken = string

export type Replica = {
    SetValue: (self: Replica, path: string, value: any) -> (),
    Data: {[any]: any}
}

export type ReplicaService = {
    NewReplica: (
        ClassToken: ReplicaClassToken,
        Replication: string, -- "All", player, {player, ...}
        Data: {[any]: any}
    ) -> (),

    NewClassToken: (tokenStr: string) -> ReplicaClassToken
}

-------------------------Shared Types--------------------------

export type Timer = {Simple: (interval: number, () -> ()) -> RBXScriptConnection}

export type PromiseResolve = (props: any) -> ()

export type PromiseReject = (errorMessage: string?) -> ()

export type PromiseModule = {
    all: ({Promise<any>}) -> Promise<any>,
    allSettled: ({Promise<any>}) -> Promise<any>,
    any: ({Promise<any>}) -> Promise<any>,
    async: (func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<any>,
    defer: (func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<any>,
    delay: (timeToDelay: number) -> Promise<any>,
    each: ({Promise<any>}) -> Promise<any>,
    fromEvent: (RBXScriptSignal, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<any>,
    is: (obj: Promise<any>?) -> boolean,
    new: (func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<any>,
    promisify: () -> Promise<any>,
    prototype: (func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<any>,
    race: ({Promise<any>}) -> Promise<any>,
    reject: (value: any?) -> Promise<any>,
    resolve: (value: any) -> Promise<any>,
    retry: (prom: Promise<any>, maxTimes: number, delayBetween: number) -> Promise<any>,
    some: ({Promise<any>}) -> Promise<any>,
    try: (func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<any>,
}

export type Promise<T> = {
    andThen: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
    andThenCall: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
    andThenReturn: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> any,
    await: () -> (),
    awaitStatus: () -> (),
    awaitValue: () -> any,
    cancel: () -> (),
    catch: (self: any, func: (e: string?) -> ()) -> (),
    done: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
    doneCall: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
    doneReturn: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> (),
    expect: () -> (),
    finally: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
    finallyCall: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
    finallyReturn: (self: any, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> (),
    getStatus: () -> any,
    now: () -> (),
    tap: () -> Promise<T>,
    timeout: (secs: any) -> Promise<T>,
}

export type Trove = {
    Destroy: (self: any) -> (),
    Clean: () -> (),
    AttachToInstance: (self: any, i: Instance) -> Instance,
    Connect: (self: any, signal: RBXScriptSignal, callback: () -> nil) -> RBXScriptConnection,
    Add: (self: any, value: RBXScriptConnection | (() -> ()) | {Destroy: () -> ()} | {Disconnect: () -> ()},
    methodName: string?) -> string?,
    [string]: any
}

export type Knit = {
    GetService: (serviceName: string) -> {[string]: any}?,
    
    GetController: (
        (controllerName: string) -> {[string]: any}?
    )?, -- client only

    Controllers: {
        {[string]: any}
    }?, -- client only
    
    Services: {
        {[string]: any}
    }?, -- server only
}

export type Controller = {
    
}

export type Service = {
    Client: {[string]: () -> () | ValueBase | BindableEvent},
    [string]: () -> () | ValueBase | BindableEvent
}

export type Purchase = {
    purchaseId: number,
    purchaseName: string,
    
    purchaseData: {
        -- define your devproduct data here for ease of use / consistency
        --item: {name: string, amount: number}?,
        [string]: any,
    }?,

    -- optional data (for gamepasses most likely all you need to know is that they have it)
    -- the functionality will be too obscure to define here

    purchaseType: "Gamepass" | "DevProduct"
}

return nil
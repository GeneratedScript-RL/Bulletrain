--!strict

--[=[
	@class framework

	framework is a system-based Roblox framework with automatic client replication.

	The framework provides different APIs depending on context:
	- Server: Use `frameworkServer` for creating services
	- Client: Use `frameworkClient` for creating controllers

	```lua
	-- Server
	local framework: Types.frameworkServer = require(path.to.framework) :: any
	framework.Run()

	-- Client (automatically started)
	local framework: Types.frameworkClient = require(path.to.framework) :: any
	```
]=]

local RunService = game:GetService("RunService")

local Types = require(script.Types)
local Core = require(script.Core)
local Util = require(script.Util)
local Comm = require(script.Core.Comm)

local IS_SERVER = RunService:IsServer()

export type Trove = Types.Trove
export type Signal<T...> = Types.Signal<T...>
export type Connection = Types.Connection
export type RemoteSignal<T...> = Comm.RemoteSignal<T...>
export type ClientRemoteSignal<T...> = Comm.ClientRemoteSignal<T...>
export type RemoteProperty<T> = Comm.RemoteProperty<T>
export type ClientRemoteProperty<T> = Comm.ClientRemoteProperty<T>
export type Service = Types.Service
export type ServiceDefinition = Types.ServiceDefinition
export type Controller = Types.Controller
export type ControllerDefinition = Types.ControllerDefinition
export type frameworkServer = Types.frameworkServer
export type frameworkClient = Types.frameworkClient

if IS_SERVER and Core.Server then
	local Server = Core.Server
	local EnvironmentAllocator = require(script.EnvironmentAllocator)

	local function Run(config: Types.RunConfig?)
		local environment = script:FindFirstChild("Environment")
		if environment then
			EnvironmentAllocator.Allocate(environment)
		end

		local systems = script:FindFirstChild("Systems")
		if systems then
			Server.AddSystems(systems)
		end

		Server.Start(config)
	end

	local framework: Types.frameworkServer = {
		Run = Run,
		Util = Util :: Types.Util,
		Comm = Comm,
		Systems = script.Systems,

		ForEach = Util.ForEach,
		ForEachAsync = Util.ForEachAsync,
		Map = Util.Map,
		Filter = Util.Filter,
		Find = Util.Find :: any,
		Reduce = Util.Reduce,
		Every = Util.Every,
		Some = Util.Some,
		Reverse = Util.Reverse,
		Shuffle = Util.Shuffle,
		Copy = Util.Copy,
		Keys = Util.Keys,
		Values = Util.Values,
		Count = Util.Count,
		Flat = Util.Flat :: any,
		Step = Util.Step,
		StopStep = Util.StopStep,
		GetActiveSteps = Util.GetActiveSteps,
		Defer = Util.Defer,
		Delay = Util.Delay,
		WaitFor = Util.WaitFor :: any,

		EnablePerformanceTracking = Util.EnablePerformanceTracking,
		GetPerformanceData = Util.GetPerformanceData :: any,
		ClearPerformanceData = Util.ClearPerformanceData,
		PrintPerformanceReport = Util.PrintPerformanceReport,
		EstimateMemoryUsage = Util.EstimateMemoryUsage,

		CreateService = Server.CreateService :: any,
		GetService = Server.GetService,
		GetServices = Server.GetServices,
		AddServices = Server.AddServices,
		AddServicesDeep = Server.AddServicesDeep,
		AddSystems = Server.AddSystems,
		AddSystemsDeep = Server.AddSystemsDeep,

		CreateSignal = Server.CreateSignal,
		CreateUnreliableSignal = Server.CreateUnreliableSignal,
		CreateProperty = Server.CreateProperty,

		OnPlayerAdded = Server.OnPlayerAdded,
		OnPlayerRemoving = Server.OnPlayerRemoving,
		OnCharacterAdded = Server.OnCharacterAdded,
		OnCharacterRemoving = Server.OnCharacterRemoving,
		GetPlayerTrove = Server.GetPlayerTrove,
		GetCharacterTrove = Server.GetCharacterTrove,

		Start = Server.Start,
		OnStart = Server.OnStart,
		IsStarted = Server.IsStarted,
	}

	return framework :: any
else
	local Client = Core.Client

	local framework: Types.frameworkClient = {
		Util = Util :: Types.Util,
		Comm = Comm,
		Systems = script.Systems,

		ForEach = Util.ForEach,
		ForEachAsync = Util.ForEachAsync,
		Map = Util.Map,
		Filter = Util.Filter,
		Find = Util.Find :: any,
		Reduce = Util.Reduce,
		Every = Util.Every,
		Some = Util.Some,
		Reverse = Util.Reverse,
		Shuffle = Util.Shuffle,
		Copy = Util.Copy,
		Keys = Util.Keys,
		Values = Util.Values,
		Count = Util.Count,
		Flat = Util.Flat :: any,
		Step = Util.Step,
		StopStep = Util.StopStep,
		GetActiveSteps = Util.GetActiveSteps,
		Defer = Util.Defer,
		Delay = Util.Delay,
		WaitFor = Util.WaitFor :: any,

		EnablePerformanceTracking = Util.EnablePerformanceTracking,
		GetPerformanceData = Util.GetPerformanceData :: any,
		ClearPerformanceData = Util.ClearPerformanceData,
		PrintPerformanceReport = Util.PrintPerformanceReport,
		EstimateMemoryUsage = Util.EstimateMemoryUsage,

		CreateController = Client.CreateController :: any,
		GetController = Client.GetController,
		GetControllers = Client.GetControllers,
		AddControllers = Client.AddControllers,
		AddControllersDeep = Client.AddControllersDeep,
		AddSystems = Client.AddSystems,
		AddSystemsDeep = Client.AddSystemsDeep,

		GetService = Client.GetService,

		OnCharacterAdded = Client.OnCharacterAdded,
		OnCharacterRemoving = Client.OnCharacterRemoving,
		GetCharacterTrove = Client.GetCharacterTrove,
		GetCharacter = Client.GetCharacter,
		Player = Client.Player,

		Start = Client.Start,
		OnStart = Client.OnStart,
		IsStarted = Client.IsStarted,
	}

	return framework :: any
end

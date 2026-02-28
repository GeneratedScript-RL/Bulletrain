--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type PacketCallback = (...any) -> ()
export type FunctionCallback = (...any) -> any

local Network = {}
Network.__index = Network

local REMOTES_FOLDER_NAME = "Remotes"
local RELIABLE_EVENT_NAME = "RemoteEvent"
local UNRELIABLE_EVENT_NAME = "UnreliableRemoteEvent"
local FUNCTION_NAME = "RemoteFunction"

local function getOrCreateRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = REMOTES_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getRemotesFolder(): Folder
	local folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME) :: Folder
	return folder
end

local function ensureRemoteEvent(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = folder
	return re
end

local function ensureUnreliableRemoteEvent(folder: Folder, name: string): UnreliableRemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("UnreliableRemoteEvent") then
		return existing
	end

	local ure = Instance.new("UnreliableRemoteEvent")
	ure.Name = name
	ure.Parent = folder
	return ure
end

local function ensureRemoteFunction(folder: Folder, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end

	local rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = folder
	return rf
end

type NetworkSelf = typeof(setmetatable({}, Network)) & {
	_reliable: RemoteEvent?,
	_unreliable: UnreliableRemoteEvent?,
	_func: RemoteFunction?,
	_reliableSignals: {[string]: BindableEvent},
	_unreliableSignals: {[string]: BindableEvent},
	_functionHandlers: {[string]: FunctionCallback},
}

function Network.new(): NetworkSelf
	local self: NetworkSelf = setmetatable({}, Network) :: any
	self._reliable = nil
	self._unreliable = nil
	self._func = nil
	self._reliableSignals = {}
	self._unreliableSignals = {}
	self._functionHandlers = {}
	return self
end

local singleton = Network.new()

local function getSignal(map: {[string]: BindableEvent}, packetName: string): BindableEvent
	local existing = map[packetName]
	if existing then
		return existing
	end
	local be = Instance.new("BindableEvent")
	be.Name = `Packet_{packetName}`
	map[packetName] = be
	return be
end

function singleton:Init()
	if self._reliable and self._unreliable and self._func then
		return
	end

	if RunService:IsServer() then
		local folder = getOrCreateRemotesFolder()
		self._reliable = ensureRemoteEvent(folder, RELIABLE_EVENT_NAME)
		self._unreliable = ensureUnreliableRemoteEvent(folder, UNRELIABLE_EVENT_NAME)
		self._func = ensureRemoteFunction(folder, FUNCTION_NAME)
	else
		local folder = getRemotesFolder()
		self._reliable = folder:WaitForChild(RELIABLE_EVENT_NAME) :: RemoteEvent
		self._unreliable = folder:WaitForChild(UNRELIABLE_EVENT_NAME) :: UnreliableRemoteEvent
		self._func = folder:WaitForChild(FUNCTION_NAME) :: RemoteFunction
	end

	if RunService:IsServer() then
		local reliable = self._reliable :: RemoteEvent
		local unreliable = self._unreliable :: UnreliableRemoteEvent
		local func = self._func :: RemoteFunction

		reliable.OnServerEvent:Connect(function(player: Player, packetName: string, ...: any)
			local be = getSignal(self._reliableSignals, packetName)
			be:Fire(player, ...)
		end)

		unreliable.OnServerEvent:Connect(function(player: Player, packetName: string, ...: any)
			local be = getSignal(self._unreliableSignals, packetName)
			be:Fire(player, ...)
		end)

		func.OnServerInvoke = function(player: Player, packetName: string, ...: any)
			local handler = self._functionHandlers[packetName]
			if not handler then
				warn(`[Network] Unhandled RemoteFunction packet: {packetName}`)
				return nil
			end
			return handler(player, ...)
		end
	else
		local reliable = self._reliable :: RemoteEvent
		local unreliable = self._unreliable :: UnreliableRemoteEvent
		local func = self._func :: RemoteFunction

		reliable.OnClientEvent:Connect(function(packetName: string, ...: any)
			local be = getSignal(self._reliableSignals, packetName)
			be:Fire(...)
		end)

		unreliable.OnClientEvent:Connect(function(packetName: string, ...: any)
			local be = getSignal(self._unreliableSignals, packetName)
			be:Fire(...)
		end)

		func.OnClientInvoke = function(packetName: string, ...: any)
			local handler = self._functionHandlers[packetName]
			if not handler then
				warn(`[Network] Unhandled RemoteFunction packet: {packetName}`)
				return nil
			end
			return handler(...)
		end
	end
end

function singleton:SubscribeToPacket(packetName: string): RBXScriptSignal
	self:Init()
	return getSignal(self._reliableSignals, packetName).Event
end

function singleton:SubscribeToUnreliablePacket(packetName: string): RBXScriptSignal
	self:Init()
	return getSignal(self._unreliableSignals, packetName).Event
end

function singleton:BindRemoteFunction(packetName: string, callback: FunctionCallback)
	self:Init()
	self._functionHandlers[packetName] = callback
end

-- Server -> Client
function singleton:FireRemoteToClient(player: Player, packetName: string, ...: any)
	self:Init()
	assert(RunService:IsServer(), "FireRemoteToClient can only be called on the server")
	local reliable = self._reliable :: RemoteEvent
	reliable:FireClient(player, packetName, ...)
end

function singleton:FireRemoteToAllClients(packetName: string, ...: any)
	self:Init()
	assert(RunService:IsServer(), "FireRemoteToAllClients can only be called on the server")
	local reliable = self._reliable :: RemoteEvent
	reliable:FireAllClients(packetName, ...)
end

function singleton:FireUnreliableRemoteToClient(player: Player, packetName: string, ...: any)
	self:Init()
	assert(RunService:IsServer(), "FireUnreliableRemoteToClient can only be called on the server")
	local unreliable = self._unreliable :: UnreliableRemoteEvent
	unreliable:FireClient(player, packetName, ...)
end

function singleton:FireUnreliableRemoteToAllClients(packetName: string, ...: any)
	self:Init()
	assert(RunService:IsServer(), "FireUnreliableRemoteToAllClients can only be called on the server")
	local unreliable = self._unreliable :: UnreliableRemoteEvent
	unreliable:FireAllClients(packetName, ...)
end

function singleton:FireRemoteFunctionToClient(player: Player, packetName: string, ...: any): any
	self:Init()
	assert(RunService:IsServer(), "FireRemoteFunctionToClient can only be called on the server")
	local func = self._func :: RemoteFunction
	return func:InvokeClient(player, packetName, ...)
end

-- Client -> Server
function singleton:FireRemoteToServer(packetName: string, ...: any)
	self:Init()
	assert(not RunService:IsServer(), "FireRemoteToServer can only be called on the client")
	local reliable = self._reliable :: RemoteEvent
	reliable:FireServer(packetName, ...)
end

function singleton:FireUnreliableRemoteToServer(packetName: string, ...: any)
	self:Init()
	assert(not RunService:IsServer(), "FireUnreliableRemoteToServer can only be called on the client")
	local unreliable = self._unreliable :: UnreliableRemoteEvent
	unreliable:FireServer(packetName, ...)
end

function singleton:FireRemoteFunctionToServer(packetName: string, ...: any): any
	self:Init()
	assert(not RunService:IsServer(), "FireRemoteFunctionToServer can only be called on the client")
	local func = self._func :: RemoteFunction
	return func:InvokeServer(packetName, ...)
end

return singleton
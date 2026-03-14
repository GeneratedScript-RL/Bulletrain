--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ViewmodelClass = require(script.Parent.Parent.Classes.Viewmodel.Viewmodel)

local ViewmodelService = {}
ViewmodelService.__index = ViewmodelService

function ViewmodelService.new()
	local self = setmetatable({}, ViewmodelService)
	self._enabled = false
	self._vm = nil :: any
	return self
end

local singleton = ViewmodelService.new()

function singleton:Enable()
	if self._enabled then
		return
	end
	self._enabled = true

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	if not camera then
		warn("[ViewmodelService] CurrentCamera missing")
		return
	end

	self._vm = ViewmodelClass.new(player, camera)
	self._vm:Equip("Shotgun")
	self._vm:Start()
end

function singleton:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._vm then
		self._vm:Destroy()
		self._vm = nil
	end
end

function singleton:IsEnabled(): boolean
	return self._enabled
end

function singleton:GetAnimationTarget(): Instance?
	if not self._vm then
		return nil
	end
	return self._vm:GetAnimationTarget()
end

function singleton:PrimaryFire()
	if self._vm then
		self._vm:PrimaryFire()
	end
end

function singleton:Inspect()
	if self._vm then
		self._vm:Inspect()
	end
end

function singleton:Reload()
	if self._vm then
		self._vm:Reload()
	end
end

function singleton:Parry()
	if not self._vm then return end
	if not self._vm._weapon or self._vm._weapon.Name ~= "Knife" then
		self._vm:Equip("Knife")
	end
	self._vm:Parry()
end

function singleton:Equip(name: string)
	if self._vm then
		self._vm:Equip(name)
	end
end

function singleton:Initialize()
	-- No auto-enable; PlayerStateController will enable/disable.
	assert(RunService:IsClient())
end

return singleton

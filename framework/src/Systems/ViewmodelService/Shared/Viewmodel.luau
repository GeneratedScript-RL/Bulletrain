--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shotgun = require(script.Parent.Weapons.Shotgun)
local Knife = require(script.Parent.Weapons.Knife)

export type Weapon = {
	Name: string,
	PrimaryFire: (self: Weapon) -> (),
	Inspect: (self: Weapon) -> (),
	Reload: (self: Weapon) -> (),
	Parry: (self: Weapon) -> (),
	Destroy: (self: Weapon) -> (),
}

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local function getAssetsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets and assets:IsA("Folder") then
		return assets
	end

	return nil
end

local function setModelNoCollide(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Anchored = true
		end
	end
end

function Viewmodel.new(localPlayer: Player, camera: Camera, animationController: any, combatService: any)
	local self = setmetatable({}, Viewmodel)
	self._player = localPlayer
	self._camera = camera
	self._animationController = animationController
	self._combatService = combatService
	self._vmModel = nil :: Model?
	self._weapon = nil :: Weapon?
	self._connection = nil :: RBXScriptConnection?
	return self
end

function Viewmodel:_ensureModelForWeapon(weaponName: string)
	if self._vmModel then
		self._vmModel:Destroy()
		self._vmModel = nil
	end

	local assets = getAssetsFolder()
	if not assets then
		warn("[Viewmodel] ReplicatedStorage.Assets missing")
		return
	end

	local viewmodels = assets:FindFirstChild("Viewmodels")
	if not viewmodels or not viewmodels:IsA("Folder") then
		warn("[Viewmodel] Assets.Viewmodels missing")
		return
	end

	local folderName = if weaponName == "Knife" then "Knifes" else "Shotguns"
	local weaponFolder = viewmodels:FindFirstChild(folderName)
	if not weaponFolder or not weaponFolder:IsA("Folder") then
		warn(("[Viewmodel] Assets.Viewmodels.%s missing"):format(folderName))
		return
	end

	local equippedAttribute = if weaponName == "Knife" then "EquippedKnifeSkin" else "EquippedShotgunSkin"
	local equippedSkin = self._player:GetAttribute(equippedAttribute)

	local template: Instance? = nil
	if type(equippedSkin) == "string" then
		local byName = weaponFolder:FindFirstChild(equippedSkin)
		if byName and byName:IsA("Model") then
			template = byName
		end
	end

	if not template then
		for _, child in weaponFolder:GetChildren() do
			if child:IsA("Model") then
				template = child
				break
			end
		end
	end

	if not template or not template:IsA("Model") then
		warn(("[Viewmodel] No viewmodel model found in %s"):format(weaponFolder:GetFullName()))
		return
	end

	local clone = template:Clone()
	clone.Name = "Viewmodel"
	setModelNoCollide(clone)
	clone.Parent = self._camera
	self._vmModel = clone
end

function Viewmodel:GetAnimationTarget(): Instance?
	local vmModel = self._vmModel
	if not vmModel then
		return nil
	end

	local controller = vmModel:FindFirstChildOfClass("AnimationController")
	if controller then
		return controller
	end

	return vmModel:FindFirstChildOfClass("Humanoid")
end

function Viewmodel:GetEquippedWeaponName(): string?
	local weapon = self._weapon
	if weapon then
		return weapon.Name
	end

	return nil
end

function Viewmodel:Start()
	if self._connection then
		return
	end

	self._connection = RunService.RenderStepped:Connect(function()
		if self._vmModel then
			self._vmModel:PivotTo(self._camera.CFrame * CFrame.Angles(math.rad(180), 0, math.rad(180)))
		end
	end)
end

function Viewmodel:Equip(weaponName: string)
	if self._weapon then
		self._weapon:Destroy()
		self._weapon = nil
	end

	self:_ensureModelForWeapon(weaponName)
	if not self._vmModel then
		return
	end

	if weaponName == "Knife" then
		self._weapon = Knife.new(self._player, self._camera, self._vmModel, self._animationController, self._combatService)
	else
		self._weapon = Shotgun.new(self._player, self._camera, self._vmModel, self._animationController, self._combatService)
	end
end

function Viewmodel:PrimaryFire()
	if self._weapon then
		self._weapon:PrimaryFire()
	end
end

function Viewmodel:Inspect()
	if self._weapon then
		self._weapon:Inspect()
	end
end

function Viewmodel:Reload()
	if self._weapon then
		self._weapon:Reload()
	end
end

function Viewmodel:Parry()
	if self._weapon then
		self._weapon:Parry()
	end
end

function Viewmodel:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	if self._weapon then
		self._weapon:Destroy()
		self._weapon = nil
	end

	if self._vmModel then
		self._vmModel:Destroy()
		self._vmModel = nil
	end
end

return Viewmodel

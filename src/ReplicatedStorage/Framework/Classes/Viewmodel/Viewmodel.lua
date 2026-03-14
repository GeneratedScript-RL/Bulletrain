--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(script.Parent.Parent.Weapons.Shotgun)
local Knife = require(script.Parent.Parent.Weapons.Knife)

export type Weapon = {
	Name: string,
	PrimaryFire: (self: Weapon) -> (),
	Destroy: (self: Weapon) -> (),
}

local Viewmodel = {}
Viewmodel.__index = Viewmodel

function Viewmodel.new(localPlayer: Player, camera: Camera)
	local self = setmetatable({}, Viewmodel)
	self._player = localPlayer
	self._camera = camera
	self._vmModel = nil :: Model?
	self._weapon = nil :: Weapon?
	self._conn = nil :: RBXScriptConnection?
	return self
end

local function getAssetsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets and assets:IsA("Folder") then
		return assets
	end
	return nil
end

local function setModelNoCollide(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
			inst.Anchored = true
		end
	end
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

	local vms = assets:FindFirstChild("Viewmodels")
	if not vms or not vms:IsA("Folder") then
		warn("[Viewmodel] Assets.Viewmodels missing")
		return
	end

	local folderName = (weaponName == "Knife") and "Knifes" or "Shotguns"
	local weaponFolder = vms:FindFirstChild(folderName)
	if not weaponFolder or not weaponFolder:IsA("Folder") then
		warn(("[Viewmodel] Assets.Viewmodels.%s missing"):format(folderName))
		return
	end

	local equippedAttr = (weaponName == "Knife") and "EquippedKnifeSkin" or "EquippedShotgunSkin"
	local equippedSkin = self._player:GetAttribute(equippedAttr)

	local template: Instance? = nil
	if type(equippedSkin) == "string" then
		local byName = weaponFolder:FindFirstChild(equippedSkin)
		if byName and byName:IsA("Model") then
			template = byName
		end
	end

	if not template then
		for _, child in ipairs(weaponFolder:GetChildren()) do
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
	if not self._vmModel then
		return nil
	end
	local controller = self._vmModel:FindFirstChildOfClass("AnimationController")
	if controller then
		return controller
	end
	local humanoid = self._vmModel:FindFirstChildOfClass("Humanoid")
	return humanoid
end

function Viewmodel:Start()
	if self._conn then
		return
	end
	self._conn = RunService.RenderStepped:Connect(function()
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

	if weaponName == "Knife" then
		self._weapon = Knife.new(self._player, self._camera, self._vmModel)
	else
		self._weapon = Shotgun.new(self._player, self._camera, self._vmModel)
	end
end

function Viewmodel:PrimaryFire()
	if self._weapon then
		self._weapon:PrimaryFire()
	end
end

function Viewmodel:Parry()
	if self._weapon and self._weapon.Name == "Knife" then
		self._weapon:Parry()
	end
end

function Viewmodel:Destroy()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
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

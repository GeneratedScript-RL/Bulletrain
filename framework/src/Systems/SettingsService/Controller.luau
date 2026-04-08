--!strict

local Lighting = game:GetService("Lighting")

local root = script.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local MovementSettings = require(root.Shared.Config.MovementSettings)
local SettingsDefaults = require(root.Shared.Settings.Defaults)
local SettingTypes = require(root.Shared.Settings.Types)
local Signal = Dependencies.GetSignal()
local Trove = Dependencies.GetTrove()

type Connection = Types.Connection
type SettingsProfile = SettingTypes.SettingsProfile
type SettingKey = SettingTypes.SettingKey

type EffectState = {
	Enabled: boolean,
}

type MaterialState = {
	Material: Enum.Material,
	MaterialVariant: string,
}

local SettingsController = framework.CreateController({
	Name = "SettingsController",
})

SettingsController._preferences = SettingsDefaults.New() :: SettingsProfile
SettingsController._open = false
SettingsController._frame = nil :: GuiObject?
SettingsController._changed = Signal.new()
SettingsController._trove = nil :: Types.Trove?
SettingsController._soundBaseVolumes = {} :: { [Sound]: number }
SettingsController._effectStates = {} :: { [Instance]: EffectState }
SettingsController._materialStates = {} :: { [BasePart]: MaterialState }
SettingsController._settingsService = nil :: any
SettingsController._playerStateService = nil :: any

local function getCurrentCamera(): Camera?
	return workspace.CurrentCamera
end

local function isLikelyMusicSound(sound: Sound): boolean
	local soundGroup = sound.SoundGroup
	if soundGroup and string.find(string.lower(soundGroup.Name), "music", 1, true) then
		return true
	end

	local current: Instance? = sound
	while current do
		local currentName = string.lower(current.Name)
		if string.find(currentName, "music", 1, true) or string.find(currentName, "song", 1, true) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isEffectInstance(instance: Instance): boolean
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("Smoke")
		or instance:IsA("Fire")
		or instance:IsA("Sparkles")
		or instance:IsA("PostEffect")
end

local function shouldManagePartMaterial(part: BasePart): boolean
	if getCurrentCamera() and part:IsDescendantOf(getCurrentCamera() :: Camera) then
		return false
	end

	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return false
	end

	return true
end

function SettingsController:_applyFrameOpenState()
	local frame = self._frame
	if not frame then
		return
	end

	frame:SetAttribute("OpenOverride", self._open)
end

function SettingsController:_rememberSound(sound: Sound)
	if self._soundBaseVolumes[sound] == nil then
		self._soundBaseVolumes[sound] = sound.Volume
	end
end

function SettingsController:_applySound(sound: Sound)
	self:_rememberSound(sound)

	local masterScale = self._preferences.MasterVolume / 100
	local sfxScale = if isLikelyMusicSound(sound)
		then 1
		else self._preferences.SFXVolume / 100

	local baseVolume = self._soundBaseVolumes[sound] or sound.Volume
	sound.Volume = math.clamp(baseVolume * masterScale * sfxScale, 0, 10)
end

function SettingsController:_rememberEffect(instance: Instance)
	if self._effectStates[instance] ~= nil then
		return
	end

	self._effectStates[instance] = {
		Enabled = ((instance :: any).Enabled :: boolean),
	}
end

function SettingsController:_applyEffect(instance: Instance)
	if not isEffectInstance(instance) then
		return
	end

	self:_rememberEffect(instance)
	local desiredEnabled = if self._preferences.EffectsEnabled
		then (self._effectStates[instance] :: EffectState).Enabled
		else false

	(instance :: any).Enabled = desiredEnabled
end

function SettingsController:_rememberMaterial(part: BasePart)
	if self._materialStates[part] ~= nil or not shouldManagePartMaterial(part) then
		return
	end

	self._materialStates[part] = {
		Material = part.Material,
		MaterialVariant = part.MaterialVariant,
	}
end

function SettingsController:_applyMaterial(part: BasePart)
	if not shouldManagePartMaterial(part) then
		return
	end

	self:_rememberMaterial(part)
	local materialState = self._materialStates[part]
	if not materialState then
		return
	end

	if self._preferences.MaterialsEnabled then
		part.Material = materialState.Material
		part.MaterialVariant = materialState.MaterialVariant
	else
		part.Material = Enum.Material.SmoothPlastic
		part.MaterialVariant = ""
	end
end

function SettingsController:_applyLighting()
	Lighting.GlobalShadows = self._preferences.ShadowsEnabled
end

function SettingsController:_applyFOV()
	MovementSettings.DEFAULT_FOV = self._preferences.FOV
	MovementSettings.SLIDE_FOV = self._preferences.FOV + 10

	local camera = getCurrentCamera()
	if camera then
		camera.FieldOfView = self._preferences.FOV
	end
end

function SettingsController:_applyPreferences()
	self:_applyLighting()
	self:_applyFOV()

	for sound in self._soundBaseVolumes do
		if sound.Parent then
			self:_applySound(sound)
		end
	end

	for instance in self._effectStates do
		if instance.Parent then
			self:_applyEffect(instance)
		end
	end

	for part in self._materialStates do
		if part.Parent then
			self:_applyMaterial(part)
		end
	end
end

function SettingsController:_trackDescendant(descendant: Instance)
	if descendant:IsA("Sound") then
		self:_rememberSound(descendant)
		self:_applySound(descendant)
		return
	end

	if isEffectInstance(descendant) then
		self:_rememberEffect(descendant)
		self:_applyEffect(descendant)
		return
	end

	if descendant:IsA("BasePart") then
		self:_rememberMaterial(descendant)
		self:_applyMaterial(descendant)
	end
end

function SettingsController:_untrackDescendant(descendant: Instance)
	if descendant:IsA("Sound") then
		self._soundBaseVolumes[descendant] = nil
		return
	end

	if isEffectInstance(descendant) then
		self._effectStates[descendant] = nil
		return
	end

	if descendant:IsA("BasePart") then
		self._materialStates[descendant] = nil
	end
end

function SettingsController:_setPreferences(preferences: SettingsProfile)
	self._preferences = SettingsDefaults.Sanitize(preferences)
	self:_applyPreferences()
	self._changed:Fire(self._preferences)
end

function SettingsController:RegisterFrame(frame: GuiObject)
	self._frame = frame
	self:_applyFrameOpenState()
end

function SettingsController:Open()
	self._open = true
	self:_applyFrameOpenState()
end

function SettingsController:Close()
	self._open = false
	self:_applyFrameOpenState()
end

function SettingsController:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function SettingsController:GetPreferences(): SettingsProfile
	return SettingsDefaults.Sanitize(self._preferences)
end

function SettingsController:GetPreference(key: SettingKey): boolean | number
	return (self._preferences :: any)[key]
end

function SettingsController:ObservePreferences(callback: (preferences: SettingsProfile) -> ()): Connection
	callback(self:GetPreferences())
	return self._changed:Connect(callback)
end

function SettingsController:SetPreference(key: string, value: any): boolean
	local success, updatedPreferences = self._settingsService:UpdatePreference(key, value)
	if success and type(updatedPreferences) == "table" then
		self:_setPreferences(updatedPreferences)
		return true
	end

	return false
end

function SettingsController:ResetPreferences(): boolean
	local success, updatedPreferences = self._settingsService:ResetPreferences()
	if success and type(updatedPreferences) == "table" then
		self:_setPreferences(updatedPreferences)
		return true
	end

	return false
end

function SettingsController:Init()
	self._settingsService = framework.GetService("SettingsService")
	self._playerStateService = framework.GetService("PlayerStateService")
end

function SettingsController:Start()
	local trove = Trove.new()
	self._trove = trove

	trove:Add(self._settingsService.Preferences:Observe(function(preferences: SettingsProfile)
		self:_setPreferences(preferences)
	end))

	trove:Add(self._playerStateService.CurrentState:Observe(function(playerState: string)
		if playerState == "Combat" then
			self:Close()
		end
	end))

	trove:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		self:_applyFOV()
	end)

	trove:Connect(game.DescendantAdded, function(descendant: Instance)
		self:_trackDescendant(descendant)
	end)

	trove:Connect(game.DescendantRemoving, function(descendant: Instance)
		self:_untrackDescendant(descendant)
	end)

	for _, descendant in ipairs(game:GetDescendants()) do
		self:_trackDescendant(descendant)
	end
end

return SettingsController

--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local HITMARKER_GUI_NAME = "HitmarkerOverlay"
local HITMARKER_SIZE = 2
local HITMARKER_LIFETIME = 0.18
local HITMARKER_COLOR = Color3.fromRGB(255, 255, 255)
local HITMARKER_ZINDEX = 1000

local HitmarkerController = framework.CreateController({
	Name = "HitmarkerController",
})

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

HitmarkerController._combatService = nil :: any

local function roundToPixel(value: number): number
	return math.floor(value + 0.5)
end

function HitmarkerController:_getOrCreateOverlay(): ScreenGui
	local existing = playerGui:FindFirstChild(HITMARKER_GUI_NAME)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local overlay = Instance.new("ScreenGui")
	overlay.Name = HITMARKER_GUI_NAME
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = HITMARKER_ZINDEX
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Parent = playerGui
	return overlay
end

function HitmarkerController:_showHitmarker(worldPosition: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewportPoint, isOnScreen = camera:WorldToViewportPoint(worldPosition)
	if not isOnScreen or viewportPoint.Z <= 0 then
		return
	end

	local marker = Instance.new("Frame")
	marker.Name = "Hitmarker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromOffset(roundToPixel(viewportPoint.X), roundToPixel(viewportPoint.Y))
	marker.Size = UDim2.fromOffset(HITMARKER_SIZE, HITMARKER_SIZE)
	marker.BackgroundColor3 = HITMARKER_COLOR
	marker.BorderSizePixel = 0
	marker.ZIndex = HITMARKER_ZINDEX
	marker.Parent = self:_getOrCreateOverlay()

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = marker

	task.delay(HITMARKER_LIFETIME, function()
		if marker.Parent then
			marker:Destroy()
		end
	end)
end

function HitmarkerController:Init()
	self._combatService = framework.GetService("CombatService")
end

function HitmarkerController:Start()
	self._combatService.HitConfirmed:Connect(function(worldPosition: Vector3)
		if typeof(worldPosition) ~= "Vector3" then
			return
		end

		self:_showHitmarker(worldPosition)
	end)
end

return HitmarkerController

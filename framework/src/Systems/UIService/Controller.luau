--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local root = script.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local SharedComponents = require(script.Parent.Shared)
local Trove = Dependencies.GetTrove()

type FrameComponentInstance = {
	Destroy: ((self: FrameComponentInstance) -> ())?,
	[string]: any,
}

type FrameDetails = {
	LobbyUI: boolean?,
	CombatUI: boolean?,
	VisibleStates: { [string]: boolean }?,
	DefaultVisible: boolean?,
}

type FrameDictionary = {
	Default: FrameDetails,
	[string]: FrameDetails,
}

type FrameComponentModule = {
	init: (frame: GuiObject) -> FrameComponentInstance,
}

type FrameRecord = {
	Frame: GuiObject,
	Component: FrameComponentInstance?,
	Details: FrameDetails?,
}

local UIController = framework.CreateController({
	Name = "UIController",
})

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local shotgunGameUI: ScreenGui?
local uiTrove: Types.Trove?
local holderFrameTrove: Types.Trove?
local playerStateService: any
local currentPlayerState = "Menu"
local frameRecords = {} :: { [string]: FrameRecord }
local OPEN_OVERRIDE_ATTRIBUTE = "OpenOverride"

local function findShotgunGameUI(): ScreenGui?
	local ui = playerGui:FindFirstChild("ShotgunGameUI")
	if ui and ui:IsA("ScreenGui") then
		return ui
	end
	return nil
end

local function getFrameComponentModule(frameName: string): FrameComponentModule?
	return SharedComponents.FrameComponents[frameName] :: FrameComponentModule?
end

local function getFrameDetails(frameName: string): FrameDetails?
	local frameDictionary = SharedComponents.FrameDictionary :: FrameDictionary
	return frameDictionary[frameName] or frameDictionary.Default
end

local function shouldFrameBeVisible(frameDetails: FrameDetails?, playerState: string): boolean
	if not frameDetails then
		return true
	end

	if frameDetails.VisibleStates then
		return frameDetails.VisibleStates[playerState] == true
	end

	if frameDetails.LobbyUI then
		return playerState ~= "Combat"
	end

	if frameDetails.CombatUI then
		return playerState == "Combat"
	end

	if frameDetails.DefaultVisible ~= nil then
		return frameDetails.DefaultVisible
	end

	return true
end

local function applyFrameVisibility(frameName: string)
	local frameRecord = frameRecords[frameName]
	if not frameRecord then
		return
	end

	local isVisible = shouldFrameBeVisible(frameRecord.Details, currentPlayerState)
	local openOverride = frameRecord.Frame:GetAttribute(OPEN_OVERRIDE_ATTRIBUTE)
	if type(openOverride) == "boolean" then
		isVisible = isVisible and openOverride
	end

	frameRecord.Frame.Visible = isVisible
	frameRecord.Frame:SetAttribute("VisibilityState", currentPlayerState)
end

local function refreshAllFrameVisibility()
	for frameName in frameRecords do
		applyFrameVisibility(frameName)
	end
end

local function destroyFrameRecord(frameName: string)
	local frameRecord = frameRecords[frameName]
	if not frameRecord then
		return
	end

	local component = frameRecord.Component
	if component ~= nil then
		local destroy = component.Destroy
		if destroy then
			destroy(component)
		end
	end

	frameRecords[frameName] = nil
end

local function destroyAllFrameRecords()
	for frameName in frameRecords do
		destroyFrameRecord(frameName)
	end
end

local function unbindHolderFrame()
	if holderFrameTrove then
		holderFrameTrove:Clean()
		holderFrameTrove = nil
	end

	destroyAllFrameRecords()
end

local function unloadFrame(frame: Instance)
	if not frame:IsA("GuiObject") then
		return
	end

	destroyFrameRecord(frame.Name)
end

local function loadFrame(frame: Instance)
	if not frame:IsA("GuiObject") then
		return
	end

	local frameName = frame.Name
	local componentModule = getFrameComponentModule(frameName)
	local component: FrameComponentInstance? = nil
	local frameDetails = getFrameDetails(frameName)

	destroyFrameRecord(frameName)

	if componentModule then
		local ok, componentOrError = pcall(componentModule.init, frame)
		if not ok then
			warn(("[UIController] Failed to initialize frame component '%s': %s"):format(frameName, tostring(componentOrError)))
		else
			component = componentOrError
		end
	end

	frameRecords[frameName] = {
		Frame = frame,
		Component = component,
		Details = frameDetails,
	}

	if holderFrameTrove then
		holderFrameTrove:Connect(frame:GetAttributeChangedSignal(OPEN_OVERRIDE_ATTRIBUTE), function()
			local currentRecord = frameRecords[frameName]
			if currentRecord and currentRecord.Frame == frame then
				applyFrameVisibility(frameName)
			end
		end)
	end

	applyFrameVisibility(frameName)
end

local function bindHolderFrame(holderFrame: GuiObject)
	unbindHolderFrame()

	local trove = Trove.new()
	holderFrameTrove = trove

	for _, frame in ipairs(holderFrame:GetChildren()) do
		loadFrame(frame)
	end

	trove:Connect(holderFrame.ChildAdded, loadFrame)
	trove:Connect(holderFrame.ChildRemoved, unloadFrame)
end

local function unbindShotgunGameUI()
	if uiTrove then
		uiTrove:Clean()
		uiTrove = nil
	end

	unbindHolderFrame()
	shotgunGameUI = nil
end

local function bindShotgunGameUI(ui: ScreenGui)
	if shotgunGameUI == ui then
		return
	end

	unbindShotgunGameUI()
	shotgunGameUI = ui
	local trove = Trove.new()
	uiTrove = trove

	local holderFrame = ui:FindFirstChild("HolderFrame")
	if holderFrame and holderFrame:IsA("GuiObject") then
		bindHolderFrame(holderFrame)
	else
		warn("[UIController] HolderFrame not found in ShotgunGameUI")
	end

	trove:Connect(ui.ChildAdded, function(child: Instance)
		if child.Name == "HolderFrame" and child:IsA("GuiObject") then
			bindHolderFrame(child)
		end
	end)

	trove:Connect(ui.ChildRemoved, function(child: Instance)
		if child.Name == "HolderFrame" then
			unbindHolderFrame()
		end
	end)
end

function UIController:Init()
	playerStateService = framework.GetService("PlayerStateService")
end

function UIController:Start()
	assert(RunService:IsClient(), "UIController must run on the client")

	local trove = Trove.new()

	local initialPlayerState = playerStateService.CurrentState:OnReady(5)
	if type(initialPlayerState) == "string" then
		currentPlayerState = initialPlayerState
	end

	trove:Add(playerStateService.CurrentState:Observe(function(playerState: string)
		currentPlayerState = playerState
		refreshAllFrameVisibility()
	end))

	local existingUI = findShotgunGameUI()
	if existingUI then
		bindShotgunGameUI(existingUI)
	else
		warn("[UIController] ShotgunGameUI not found in PlayerGui")
	end

	trove:Connect(playerGui.ChildAdded, function(child: Instance)
		if child.Name == "ShotgunGameUI" and child:IsA("ScreenGui") then
			bindShotgunGameUI(child)
		end
	end)

	trove:Connect(playerGui.ChildRemoved, function(child: Instance)
		if child == shotgunGameUI then
			unbindShotgunGameUI()
		end
	end)
end

return UIController

--!strict

local root = script.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Trove = Dependencies.GetTrove()

local StatsController = framework.CreateController({
	Name = "StatsController",
})

StatsController._open = false
StatsController._frame = nil :: GuiObject?
StatsController._playerStateService = nil :: any
StatsController._trove = nil :: Types.Trove?

function StatsController:_applyFrameOpenState()
	local frame = self._frame
	if not frame then
		return
	end

	frame:SetAttribute("OpenOverride", self._open)
end

function StatsController:RegisterFrame(frame: GuiObject)
	self._frame = frame
	self:_applyFrameOpenState()
end

function StatsController:Open()
	self._open = true
	self:_applyFrameOpenState()
end

function StatsController:Close()
	self._open = false
	self:_applyFrameOpenState()
end

function StatsController:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function StatsController:Init()
	self._playerStateService = framework.GetService("PlayerStateService")
end

function StatsController:Start()
	local trove = Trove.new()
	self._trove = trove

	trove:Add(self._playerStateService.CurrentState:Observe(function(playerState: string)
		if playerState == "Combat" then
			self:Close()
		end
	end))
end

return StatsController

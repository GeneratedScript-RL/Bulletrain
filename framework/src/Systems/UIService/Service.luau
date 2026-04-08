--!strict

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local UIService = framework.CreateService({
	Name = "UIService",
})

function UIService:Init()
	-- Service initialization
end

function UIService:Start()
	-- Service startup logic
end

return UIService

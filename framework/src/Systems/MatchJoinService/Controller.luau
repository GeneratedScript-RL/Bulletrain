--!strict

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local MatchJoinController = framework.CreateController({
	Name = "MatchJoinController",
})

return MatchJoinController

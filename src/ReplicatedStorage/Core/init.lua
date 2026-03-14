--!strict

local Core = {}

function Core.GetService(name: string)
	local child = script:FindFirstChild(name)
	if not child then
		error(("[Core] Unknown service: %s"):format(name))
	end
	return require(child)
end

return Core

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function safeRequire(moduleScript: ModuleScript)
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn(("[ClientLoader] Failed requiring %s: %s"):format(moduleScript:GetFullName(), tostring(result)))
		return nil
	end
	return result
end

local function initModule(mod: any)
	if type(mod) ~= "table" then
		return
	end
	local init = (mod :: any).Initialize
	if type(init) == "function" then
		local ok, err = pcall(function()
			init(mod)
		end)
		if not ok then
			warn(("[ClientLoader] Initialize failed: %s"):format(tostring(err)))
		end
	end
end

local framework = ReplicatedStorage:WaitForChild("Framework")
local loaded = {}

for _, inst in ipairs(framework:GetDescendants()) do
	if inst:IsA("ModuleScript") then
		local mod = safeRequire(inst)
		if mod ~= nil then
			table.insert(loaded, mod)
		end
	end
end

for _, mod in ipairs(loaded) do
	initModule(mod)
end

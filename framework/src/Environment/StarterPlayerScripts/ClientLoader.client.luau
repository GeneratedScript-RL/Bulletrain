--!nocheck

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local framework = require(ReplicatedStorage:WaitForChild("framework"))
framework.AddSystems(framework.Systems)
framework.Start()

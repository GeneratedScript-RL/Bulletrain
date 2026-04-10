--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Config = require(script.Parent.Shared.Config)

type TextObject = TextLabel | TextButton
type RewardDefinition = {
	Label: string,
	TitleColor: Color3,
}

local EXP_COLOR = Color3.fromRGB(120, 255, 132)
local COIN_COLOR = Color3.fromRGB(255, 213, 94)
local MAX_ACTIVE_ENTRIES = 6
local ENTRY_LIFETIME = 3

local RewardController = framework.CreateController({
	Name = "RewardController",
})

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

RewardController._rewardService = nil :: any
RewardController._nextEntryId = 0
RewardController._activeEntries = {} :: { GuiObject }
RewardController._pendingRewards = {} :: { any }

local function colorToHex(color: Color3): string
	local red = math.floor(color.R * 255 + 0.5)
	local green = math.floor(color.G * 255 + 0.5)
	local blue = math.floor(color.B * 255 + 0.5)
	return string.format("%02X%02X%02X", red, green, blue)
end

local function escapeRichText(text: string): string
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	return escaped
end

local function wrapWithColor(text: string, color: Color3): string
	return string.format('<font color="#%s">%s</font>', colorToHex(color), escapeRichText(text))
end

local function getAssetsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets and assets:IsA("Folder") then
		return assets
	end

	return nil
end

local function findRewardTemplate(): GuiObject?
	local assets = getAssetsFolder()
	if not assets then
		return nil
	end

	local template = assets:FindFirstChild("TextListTemplate")
	if template and template:IsA("GuiObject") then
		return template
	end

	local recursiveTemplate = assets:FindFirstChild("TextListTemplate", true)
	if recursiveTemplate and recursiveTemplate:IsA("GuiObject") then
		return recursiveTemplate
	end

	return nil
end

local function getRewardListFromUi(ui: Instance?): GuiObject?
	if not ui then
		return nil
	end

	local holderFrame = ui:FindFirstChild("HolderFrame")
	if not holderFrame or not holderFrame:IsA("GuiObject") then
		return nil
	end

	local rewardList = holderFrame:FindFirstChild("RewardList")
	if rewardList and rewardList:IsA("GuiObject") then
		return rewardList
	end

	local recursiveRewardList = holderFrame:FindFirstChild("RewardList", true)
	if recursiveRewardList and recursiveRewardList:IsA("GuiObject") then
		return recursiveRewardList
	end

	return nil
end

local function findRewardList(): GuiObject?
	local shotgunGame = playerGui:FindFirstChild("ShotgunGame")
	local rewardList = getRewardListFromUi(shotgunGame)
	if rewardList then
		return rewardList
	end

	local shotgunGameUI = playerGui:FindFirstChild("ShotgunGameUI")
	rewardList = getRewardListFromUi(shotgunGameUI)
	if rewardList then
		return rewardList
	end

	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			rewardList = getRewardListFromUi(child)
			if rewardList then
				return rewardList
			end
		end
	end

	return nil
end

local function findTextObject(container: Instance?): TextObject?
	if not container then
		return nil
	end

	if container:IsA("TextLabel") or container:IsA("TextButton") then
		return container
	end

	local textLabel = container:FindFirstChildWhichIsA("TextLabel", true)
	if textLabel then
		return textLabel
	end

	local textButton = container:FindFirstChildWhichIsA("TextButton", true)
	if textButton then
		return textButton
	end

	return nil
end

local function getPayloadNumber(payload: any, key: string): number
	local value = payload[key]
	if type(value) == "number" then
		return math.max(math.floor(value + 0.5), 0)
	end

	return 0
end

local function getRewardDefinition(rewardId: string): RewardDefinition?
	return (Config.Rewards :: { [string]: RewardDefinition })[rewardId]
end

local function buildRewardText(payload: any): string
	local rewardId = if type(payload.rewardId) == "string" then payload.rewardId else ""
	local rewardDefinition = getRewardDefinition(rewardId)
	local label = if type(payload.label) == "string" and payload.label ~= ""
		then payload.label
		elseif rewardDefinition
			then rewardDefinition.Label
			else "Reward"
	local titleColor = if typeof(payload.titleColor) == "Color3"
		then payload.titleColor
		elseif rewardDefinition
			then rewardDefinition.TitleColor
			else Color3.fromRGB(255, 255, 255)

	local segments = { wrapWithColor(label, titleColor) }
	local xp = getPayloadNumber(payload, "xp")
	local coins = getPayloadNumber(payload, "coins")

	if xp > 0 then
		table.insert(segments, wrapWithColor(("[+%d EXP]"):format(xp), EXP_COLOR))
	end

	if coins > 0 then
		table.insert(segments, wrapWithColor(("[+%d Coins]"):format(coins), COIN_COLOR))
	end

	return table.concat(segments, " ")
end

function RewardController:_trimActiveEntries()
	while #self._activeEntries > MAX_ACTIVE_ENTRIES do
		local oldestEntry = table.remove(self._activeEntries, 1)
		if oldestEntry then
			oldestEntry:Destroy()
		end
	end
end

function RewardController:_removeEntry(entry: GuiObject)
	for index, activeEntry in ipairs(self._activeEntries) do
		if activeEntry == entry then
			table.remove(self._activeEntries, index)
			break
		end
	end

	if entry.Parent then
		entry:Destroy()
	end
end

function RewardController:_showReward(payload: any): boolean
	local rewardList = findRewardList()
	local template = findRewardTemplate()
	if not rewardList or not template then
		return false
	end

	local entry = template:Clone()
	local textObject = findTextObject(entry)
	if not textObject then
		entry:Destroy()
		return false
	end

	self._nextEntryId += 1
	entry.Name = ("RewardEntry_%d"):format(self._nextEntryId)
	entry.Visible = true
	entry.LayoutOrder = -self._nextEntryId
	textObject.RichText = true
	textObject.Text = buildRewardText(payload)

	entry.Parent = rewardList
	table.insert(self._activeEntries, entry)
	self:_trimActiveEntries()

	task.delay(ENTRY_LIFETIME, function()
		self:_removeEntry(entry)
	end)

	return true
end

function RewardController:_flushPendingRewards()
	if #self._pendingRewards == 0 then
		return
	end

	local pendingRewards = self._pendingRewards
	self._pendingRewards = {}

	for _, payload in ipairs(pendingRewards) do
		if not self:_showReward(payload) then
			table.insert(self._pendingRewards, payload)
		end
	end
end

function RewardController:Init()
	self._rewardService = framework.GetService("RewardService")
end

function RewardController:Start()
	self._rewardService.RewardGranted:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		if not self:_showReward(payload) then
			table.insert(self._pendingRewards, payload)
		end
	end)

	playerGui.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == "RewardList" or descendant.Name == "HolderFrame" then
			self:_flushPendingRewards()
		end
	end)

	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == "ShotgunGame" or child.Name == "ShotgunGameUI" then
			self:_flushPendingRewards()
		end
	end)

	task.defer(function()
		self:_flushPendingRewards()
	end)
end

return RewardController

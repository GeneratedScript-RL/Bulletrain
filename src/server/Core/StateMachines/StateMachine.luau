--!strict

export type StateName = string
export type StateChangedCallback = (from: StateName?, to: StateName) -> ()

export type StateMachine = {
	GetState: (self: StateMachine) -> StateName?,
	ChangeState: (self: StateMachine, newState: StateName) -> (),
	Destroy: (self: StateMachine) -> (),
	StateChanged: RBXScriptSignal,
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(initialState: StateName?): StateMachine
	local self = setmetatable({}, StateMachine) :: any
	self._state = initialState
	self._be = Instance.new("BindableEvent")
	self.StateChanged = self._be.Event
	return self
end

function StateMachine:GetState(): StateName?
	return self._state
end

function StateMachine:ChangeState(newState: StateName)
	local old = self._state
	if old == newState then
		return
	end
	self._state = newState
	self._be:Fire(old, newState)
end

function StateMachine:Destroy()
	self._be:Destroy()
end

return StateMachine

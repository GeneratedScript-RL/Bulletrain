--!strict

export type Connection = {
	Disconnect: (Connection) -> (),
}

export type Signal<T...> = {
	Connect: (Signal<T...>, (T...) -> ()) -> Connection,
	Once: (Signal<T...>, (T...) -> ()) -> Connection,
	Fire: (Signal<T...>, T...) -> (),
	Destroy: (Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(_name: string?): Signal<any>
	local self = setmetatable({}, Signal)
	self._bindable = Instance.new("BindableEvent")
	return (self :: any) :: Signal<any>
end

function Signal:Connect(fn)
	return self._bindable.Event:Connect(fn)
end

function Signal:Once(fn)
	local conn
	conn = self._bindable.Event:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	self._bindable:Fire(...)
end

function Signal:Destroy()
	self._bindable:Destroy()
end

return Signal

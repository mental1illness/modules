type Connection = {
	Signal: Signal?,
	Disconnect: (self: Connection) -> ()
}

type Signal = {
	Connections: {[Connection]: (...any) -> ()},
	IsDestroyed: boolean,

	Connect: (self: Signal, Func: (...any) -> ()) -> Connection?,
	Fire: (self: Signal, ...any) -> (),
	Destroy: (self: Signal) -> ()
}

local Signal = {}
Signal.__index = Signal

function Signal.New(): Signal
	local Self = setmetatable({}, Signal) :: any
	Self.Connections = {}
	Self.IsDestroyed = false
	return Self
end

function Signal:Connect(Func: (...any) -> ()): Connection?
	if Self.IsDestroyed then
		return nil
	end

	if type(Func) ~= "function" then
		warn("🖕", 2) 
		return nil
	end

	local Connection: Connection = {} :: any
	local Key = Connection

	Self.Connections[Key] = Func

	function Connection:Disconnect()
		local Sig = Self.Signal
		if Sig then
			Sig.Connections[Key] = nil
			Self.Signal = nil
		end
	end

	Connection.Signal = Self

	return Connection
end

function Signal:Fire(...: any)
	if Self.IsDestroyed then
		return
	end

	for _, Func in pairs(Self.Connections) do
		task.spawn(Func, ...)
	end
end

function Signal:Destroy()
	Self.IsDestroyed = true

	for Key in pairs(Self.Connections) do
		Self.Connections[Key] = nil
	end

	Self.Connections = nil :: any
	setmetatable(Self, nil)
end

return Signal

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
	local self = setmetatable({}, Signal) :: any
	self.Connections = {}
	self.IsDestroyed = false
	return self
end

function Signal:Connect(Func: (...any) -> ()): Connection?
	if self.IsDestroyed then
		return nil
	end

	if type(Func) ~= "function" then
		warn("Function expected", 2)
		return nil
	end

	local Connection: Connection = {} :: any
	local Key = Connection

	self.Connections[Key] = Func

	function Connection:Disconnect()
		local Sig = Connection.Signal
		if Sig then
			Sig.Connections[Key] = nil
			Connection.Signal = nil
		end
	end

	Connection.Signal = self

	return Connection
end

function Signal:Fire(...: any)
	if self.IsDestroyed then
		return
	end

	for _, Func in pairs(self.Connections) do
		task.spawn(Func, ...)
	end
end

function Signal:Destroy()
	self.IsDestroyed = true

	for Key in pairs(self.Connections) do
		self.Connections[Key] = nil
	end

	self.Connections = nil :: any
	setmetatable(self, nil)
end

return Signal

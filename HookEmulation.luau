-- i didn't make this

--[[
	@author depso (depthso)
	@description Hook emulation, used for having middle hooks

	Example usage:
	local Old; Old = Emulation:HookFunction(true, MyFunction, function(...) 
		local Args = {...}
		-- Stuff here

        return Emulation:Unpack(Args)
    end)

	-- Hooks both __namecall and __index
	local Old; Old = Emulation:HookMetaFunc(game.HttpService, "JSONEncode", true, function(IsNameCall: boolean, ...) 
		return Old(...)
	end)
]]

--// Protected functions
local CloneFunc = clonefunction(clonefunction)
local Hookfunc = clonefunction(hookfunction)
local MakeCFunc = clonefunction(newcclosure)
local IsCClosure = clonefunction(iscclosure)
local Unpack = clonefunction(unpack)
local IsHooked = clonefunction(isfunctionhooked)
local RestoreFunc = clonefunction(restorefunction)
local IsExeClosure = clonefunction(isexecutorclosure)
local GetRawMetatable = clonefunction(getrawmetatable)
local GetNameCallMethod = clonefunction(getnamecallmethod)
local Clear = clonefunction(table.clear)
local Maxn = clonefunction(table.maxn)

--// Globals
local GlobalENV = getgenv()

local Module = {
	HookedFunctions = {},
	UnhookedSpoof = {},
	ExeClosureSpoof = {},
	MetaHooks = {},
	UserHooks = {}
}

function Module:Unpack(Args, Length: number?)
	return Unpack(Args, 1, Length or Maxn(Args))
end

function Module:CallReal(Func)
	local HookedFunctions = self.HookedFunctions

	--// Call unhooked
	local Unhooked = HookedFunctions[Func]
	if Unhooked then return Unhooked() end

	--// Call normally if there's no hook
	return Func()
end

function Module:HookFunction(HardArgs: boolean?, Func, NewFunc)
	if not Func then return end

	local UserHooks = self.UserHooks
	local HookedFunctions = self.HookedFunctions
	local Cloned = CloneFunc(Func)
	
	local Callback = function(...)
		local Userhook = UserHooks[Func]

		--// Check for an intercept
		if NewFunc then
			local Responce = {NewFunc(...)}
			if HardArgs or #Responce >= 1 then
				return self:Unpack(Responce)
			end
		end

		--// Pass to the hook made by the user
		if Userhook then
			return Userhook(...)
		end

		--// Unaffected
		return Cloned(...)
	end

	--// Hook function
	local Old = Hookfunc(Func, MakeCFunc(Callback))
	HookedFunctions[Func] = Old

	return Old
end

function Module:HookMetaMethod(Method: string, Callback)
	local Func = GetRawMetatable(game)[Method]
	return self:HookFunction(false, Func, Callback)
end

function Module:HookMetaFunc(Object: Instance, Method: string, HardArgs: boolean, Callback)
	local Methods = self.MetaHooks[Object]
	local Success, Function = pcall(function()
		return Object[Method]
	end)

	--// Check if the method exists
	if not Success then
		return
	end

	--// Check if the object has a methods dict
	if not Methods then
		Methods = {}
		self.MetaHooks[Object] = Methods
	end

	local Wrapped = MakeCFunc(Callback)
	
	--// Asign function to method call
	Methods[Method] = MakeCFunc(function(...)
		return Wrapped(true, ...)
	end)

	--// Hook __index method aka function
	return self:HookFunction(HardArgs, Function, MakeCFunc(function(...)
		return Wrapped(false, ...)
	end))
end

function Module:ProtectFunction(Func)
	self:HookFunction(false, Func)
end

function Module:IsProtectedFunction(Func)
	return self.HookedFunctions[Func]
end

function Module:SpoofUnhooked(Func)
	self.UnhookedSpoof[Func] = true
end
function Module:SpoofExeClosure(Func)
	self.ExeClosureSpoof[Func] = true
end

function Module:Export(Names: {string}, Func)
	for _, Name in Names do
		--// Check if the executor has that function (minor dtc patch)
		local OriginalFunc = GlobalENV[Name]
		if not OriginalFunc then continue end

		--// Prevent hooking
		self:ProtectFunction(OriginalFunc)
		
		--// Clone function
		local Closure = MakeCFunc(CloneFunc(Func))

		--// Patch closure type
		if IsExeClosure(OriginalFunc) then
			self:SpoofExeClosure(Closure)
		end

		--// Set new function
		GlobalENV[Name] = Closure
	end

	--// Prevent memory leak
	Clear(Names)
end

--// clonefunction patch
do
	Module:Export({"clonefunction", "clonefunc", "replaceclosure"}, function(Func)
		--// Allow passthrough if the function is not protected
		local HookProtected = Module:IsProtectedFunction(Func)
		if not HookProtected then 
			return CloneFunc(Func)
		end

		--// New function
		local New = function(...)
			return Func(...)
		end

		--// Convert closure type accordingly

		--// C closure
		if IsCClosure(Func) then
			return MakeCFunc(New)

		--// Lua closure
		else
			return New
		end
	end)
end

--// hookfunction patch
do
	Module:Export({"hookfunction", "hookfunc"}, function(Func, Hook)
		--// Allow passthrough if the function is not protected
		local HookProtected = Module:IsProtectedFunction(Func)
		if not HookProtected then 
			return Hookfunc(Func, Hook)
		end

		--// Set hook
		Module.UserHooks[Func] = Hook

		--// Pretend to return unhooked
		local FakeUnhooked = CloneFunc(Func)
		Module:SpoofUnhooked(FakeUnhooked)

		return FakeUnhooked
	end)
end

--// isfunctionhooked patch
do
	Module:Export({"isfunctionhooked"}, function(Func)
		--// Check for user hook
		if Module.UserHooks[Func] then return true end

		--// Check for spoof
		if Module.UnhookedSpoof[Func] then return false end

		--// Check for protected
		local HookProtected = Module:IsProtectedFunction(Func)
		if HookProtected then return false end

		return IsHooked(Func)
	end)
end

--// restorefunction patch
do
	Module:Export({"restorefunction", "restorefunc"}, function(Func)
		--// Check for user hook
		local UserHook = Module.UserHooks[Func]
		if UserHook then
			Clear(UserHook)
			Module.UserHooks[Func] = nil
			return
		end

		--// Check for protected
		local HookProtected = Module:IsProtectedFunction(Func)
		if HookProtected then 
			return 
		end

		--// Pass
		return RestoreFunc(Func)
	end)
end

--// isexecutorclosure patch
do 
	Module:Export({"isexecutorclosure"}, function(Func)
		--// Check for user hook
		local Spoof = Module.ExeClosureSpoof[Func]
		if Spoof then 
			return false
		end

		--// Pass
		return IsExeClosure(Func)
	end)
end

--// __namecall patch
do 
	Module:HookMetaMethod("__namecall", function(self, ...)
		local Method = GetNameCallMethod()

		local Methods = Module.MetaHooks[self]
		local Func = Methods and Methods[Method]

		if not Func then return end

		--// Intercept
		return Func(self, ...)
	end)
end

return Module

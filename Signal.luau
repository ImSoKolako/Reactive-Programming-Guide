--!strict
--!optimize 2
export type Connection<T...> = {
	Disconnect : (Connection<T...>) -> ();
	
	_fn : (T...) -> ();
	_sig : Signal<T...>;
}
export type Signal<T...> = {Connection<T...>} & {
	Fire : (Signal<T...>,T...) -> ();
	Connect : (Signal<T...>,(T...)->()) -> Connection<T...>;
	Wait : (Signal<T...>) -> T...;
	Once : (Signal<T...>,(T...)->()) -> Connection<T...>;
}

local ThreadPool = {} :: {thread}

local function Run(fn,...)
	local c = coroutine.running()
	xpcall(fn,warn,...)
	table.insert(ThreadPool,c)
end

local function EndlessRun()
	while true do
		Run(coroutine.yield())
	end
end

local function GetThread() : thread
	if #ThreadPool > 0 then
		return table.remove(ThreadPool) :: thread
	end
	local thread = coroutine.create(EndlessRun)
	coroutine.resume(thread)
	return thread
end

local module = {}
module.__index = module

local connectionMt = {}
connectionMt.__index = connectionMt

local function Disconnect<T...>(self : Connection<T...>)
	local sig = self._sig :: {Connection<T...>}
	table.remove(sig,table.find(sig,self)) --можно сделать более эффективнее, но для сохранения порядка можно и на этом закончить
end

local function Fire<T...>(self : Signal<T...>,...:T...) : ()
	
	local connections = table.clone(self) :: {Connection<T...>}
	
	for i,conn in next,connections do
		--conn._fn(...) -- таким образом сохраняется порядок.
		coroutine.resume(GetThread(),conn._fn,...)
	end
	
end

local function Connect<T...>(self : Signal<T...>,fn : (T...)->()) : Connection<T...>
	local connection = setmetatable({_sig=self,_fn = fn},connectionMt) :: Connection<T...>
	
	table.insert(self,connection)
	
	return connection
end

local function Wait<T...>(self : Signal<T...>) : T...
	local thread = coroutine.running()
	local connection : Connection<T...>
	connection = Connect(self,function(...:T...)
		Disconnect(connection)
		task.spawn(thread,...)
	end)
	
	return coroutine.yield()
end

local function Once<T...>(self : Signal<T...>,fn : (T...)->()) : Connection<T...>
	local connection : Connection<T...>
	
	connection = Connect(self,function(...:T...)
		Disconnect(connection)
		fn(...)
	end)
	
	return connection
end


module.Once = Once
module.Fire = Fire
module.Wait = Wait
module.Connect = Connect

connectionMt.Disconnect = Disconnect

return function() : Signal<any>
	return setmetatable({},module) :: Signal<any>
end

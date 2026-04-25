# Reactive-Programming-Guide

Привет, разработчики. В этом видео я поговорю о реактивном программировании и основном его компоненте - события и сигналы.

Начнём конечно же с теории.

Реактивное программирование - это создание программы так, что данные приходят в виде потока. Как, например, вода в водопроводе.

Сигнал это уведомление о произошедшем событии, или же сам источник событий. В привычной терминологии оно является асинхронным. Они являются основной цепью реактивного программирования.

Событие - это сообщение, возникающее во время работы кода.

Подключение - это контейнер с функцией, которая реагирует на подачу сигнала.

Сигналы в луау распространены как двусвязный список. С одной стороны быстрое удаление, но будем честны, у кого-то когда-то было более двадцати подключений к одному сигналу? Поэтому всё же лучше будет использовать массив: намного меньше потраченной памяти и более быстрое прохождение по подключениям.

Сигналы используются повсеместно, так как они невероятно просты, быстры и удобны.

Перейдём к практике и я создам свой очень простой сигнал, он будет основан на массиве и я реализую все методы у аналогичного роблокс инстанса.

начнём с объявления типов:
```lua
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

local module = {}
module.__index = module

local connectionMt = {}
connectionMt.__index = connectionMt
```

Функция подключения:
```lua
local function Connect<T...>(self : Signal<T...>,fn : (T...)->()) : Connection<T...>
	local connection = setmetatable({_sig=self,_fn = fn},connectionMt) :: Connection<T...>
	
	table.insert(self,connection)
	
	return connection
end
```

Wait и Once соответственно:
```lua
local function Wait<T...>(self : Signal<T...>) : T...
	local thread = coroutine.running() -- текущий поток, выполняющий код.
	local connection : Connection<T...>
	connection = Connect(self,function(...:T...)
		Disconnect(connection)
		task.spawn(thread,...)
	end)
	
	return coroutine.yield() --приостанавливает поток пока он не запустится снова при помощи task.spawn выше
end

local function Once<T...>(self : Signal<T...>,fn : (T...)->()) : Connection<T...>
	local connection : Connection<T...>
	
	connection = Connect(self,function(...:T...)
		Disconnect(connection)
		fn(...)
	end)
	
	return connection
end
```

а теперь Fire:
```lua
local function Fire<T...>(self : Signal<T...>,...:T...) : ()	
	for i,conn in next,self do
		conn._fn(...) -- таким образом сохраняется порядок.
	end
end
```
Однако при такой записи будет нарушаться порядок: если происходит отключение - теряется вызов одного из подключений.
В целях обучения представлю максимально простой вариант исправления:
```lua
local connections = table.clone(self) :: {Connection<T...>}
	local connections = table.clone(self) :: {Connection<T...>}
  
	for i,conn in next,connections do
		conn._fn(...) -- таким образом сохраняется порядок.
	end
  ```
Но у нас ещё не реализована асинхронность.
Давайте добавим её! Реализую её я через пул потоков:
```lua
local ThreadPool = {} :: {thread}

local function Run(fn,...)
	local c = coroutine.running()
	xpcall(fn,warn,...) --не error так как он не будет проигрываться.
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
	coroutine.resume(thread) --запускаем, так как coroutine.yield ещё не вызван в EndlessRun
	return thread
end
```
И в fire:
```lua
local function Fire<T...>(self : Signal<T...>,...:T...) : ()
	
	local connections = table.clone(self) :: {Connection<T...>}
	
	for i,conn in next,connections do
		--conn._fn(...) -- таким образом сохраняется порядок.
		coroutine.resume(GetThread(),conn._fn,...)
	end
	
end
```

Также справедлива и критика производительности, однако стоит не забывать, что это лишь учебный сигнал и он приводится как пример.

Однако существует и сущность приоритетной очереди событий. Она имеет преимущество в удобности, а также для управления событиями. Хотя буду честен, я не видел использования, но мне она очень сильно нравится. Напишу пример и для неё:
```lua
--!strict
--!optimize 2
export type Event<T> = {
	name : string;
	value : T;
	_priority : number;
	_next : Event<T>?;
}
local Event = nil :: Event<any>?;
local module = {}

function module.PushEvent<T>(name : string,val : T,priority : number?) : typeof(module)
	local event = {
		name=name;
		val=val;
		_priority=priority or 0;
		_next=Event;
	} :: Event<T>
	
	if not Event then
		Event = event
	else
		local prev = Event
		if prev._priority < event._priority then
			Event = event
			return module
		end
		while prev._next and prev._next._priority >= event._priority do	
			prev = prev._next
		end
		event._next = prev._next
		prev._next = event
	end
	
	return module
end

function module.PopEvent<T>() : Event<T>?
	local event = Event
	if event then
		Event = event._next
		return event
	end
	return nil
end

return table.freeze(module)
```

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

return module

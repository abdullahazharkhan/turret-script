extends RefCounted
class_name RuntimeContext

enum State {
	READY,
	RUNNING,
	PAUSED,
	HALTED,
	ERROR
}

var stack: Array = []
var call_stack: Array = [] # Array of dictionaries: { "ip": int, "local_vars": Array }
var ip: int = 0
var state: int = State.READY
var error_message: String = ""

func reset():
	stack.clear()
	call_stack.clear()
	ip = 0
	state = State.READY
	error_message = ""
	
	# Push the global frame
	call_stack.append({ "ip": -1, "local_vars": [] })

func current_frame() -> Dictionary:
	return call_stack.back()

func ensure_locals(size: int):
	var frame = current_frame()
	var locals = frame["local_vars"]
	while locals.size() <= size:
		locals.append(null)

func get_local(index: int):
	var frame = current_frame()
	if index < frame["local_vars"].size():
		return frame["local_vars"][index]
	return null

func set_local(index: int, value):
	ensure_locals(index)
	current_frame()["local_vars"][index] = value

func push(val):
	stack.append(val)

func pop():
	if stack.is_empty():
		return null
	return stack.pop_back()

func peek():
	if stack.is_empty():
		return null
	return stack.back()

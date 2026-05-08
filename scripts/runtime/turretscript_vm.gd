extends RefCounted

const IRProgram = preload("res://scripts/compiler/ir/ir_program.gd")
const IRInstruction = preload("res://scripts/compiler/ir/ir_instruction.gd")
const RuntimeContext = preload("res://scripts/runtime/data/runtime_context.gd")
const APIAdapter = preload("res://scripts/runtime/turret_api_adapter.gd")

signal log_message(msg: String)
signal runtime_error(msg: String)
signal execution_finished()

var context: RuntimeContext
var program: IRProgram
var api: APIAdapter
var max_ops_per_tick: int = 1000

func _init(p: IRProgram, a: APIAdapter = null):
	program = p
	context = RuntimeContext.new()
	context.reset()
	api = a if a else APIAdapter.new()
	api.log_message.connect(_on_api_log)

func _on_api_log(msg: String):
	emit_signal("log_message", msg)

func _error(msg: String):
	context.state = RuntimeContext.State.ERROR
	context.error_message = msg
	var line = -1
	if context.ip >= 0 and context.ip < program.instructions.size():
		line = program.instructions[context.ip].line
	var err = "Runtime Error at L%d: %s" % [line, msg]
	emit_signal("runtime_error", err)

func run():
	if context.state == RuntimeContext.State.READY:
		if program.functions.has("main"):
			context.ip = program.functions["main"]
		context.state = RuntimeContext.State.RUNNING
		emit_signal("log_message", "--- VM Execution Started ---")
		
	var ops = 0
	while context.state == RuntimeContext.State.RUNNING:
		if ops >= max_ops_per_tick:
			_error("Instruction budget exceeded! Infinite loop detected.")
			break
		
		step()
		ops += 1

func step():
	if context.state != RuntimeContext.State.RUNNING and context.state != RuntimeContext.State.READY:
		return
		
	if context.state == RuntimeContext.State.READY:
		if program.functions.has("main"):
			context.ip = program.functions["main"]
		context.state = RuntimeContext.State.RUNNING
		
	if context.ip >= program.instructions.size():
		context.state = RuntimeContext.State.HALTED
		emit_signal("log_message", "--- VM Execution Finished ---")
		emit_signal("execution_finished")
		return
		
	var inst = program.instructions[context.ip]
	_execute_instruction(inst)

func _execute_instruction(inst):
	context.ip += 1 # Advance IP before execution
	var op = inst.opcode
	var arg = inst.operand
	
	match op:
		IRInstruction.OpCode.PUSH:
			context.push(arg)
		IRInstruction.OpCode.STORE_VAR:
			var val = context.pop()
			context.set_local(arg, val)
		IRInstruction.OpCode.LOAD_VAR:
			var val = context.get_local(arg)
			context.push(val)
		IRInstruction.OpCode.ADD:
			var b = context.pop(); var a = context.pop()
			context.push(a + b)
		IRInstruction.OpCode.SUB:
			var b = context.pop(); var a = context.pop()
			context.push(a - b)
		IRInstruction.OpCode.MUL:
			var b = context.pop(); var a = context.pop()
			context.push(a * b)
		IRInstruction.OpCode.DIV:
			var b = context.pop(); var a = context.pop()
			if typeof(b) == TYPE_INT and b == 0:
				_error("Division by zero")
				return
			context.push(a / b)
		IRInstruction.OpCode.EQ:
			var b = context.pop(); var a = context.pop()
			context.push(a == b)
		IRInstruction.OpCode.NEQ:
			var b = context.pop(); var a = context.pop()
			context.push(a != b)
		IRInstruction.OpCode.LT:
			var b = context.pop(); var a = context.pop()
			context.push(a < b)
		IRInstruction.OpCode.LTE:
			var b = context.pop(); var a = context.pop()
			context.push(a <= b)
		IRInstruction.OpCode.GT:
			var b = context.pop(); var a = context.pop()
			context.push(a > b)
		IRInstruction.OpCode.GTE:
			var b = context.pop(); var a = context.pop()
			context.push(a >= b)
		IRInstruction.OpCode.AND:
			var b = context.pop(); var a = context.pop()
			context.push(a and b)
		IRInstruction.OpCode.OR:
			var b = context.pop(); var a = context.pop()
			context.push(a or b)
		IRInstruction.OpCode.NOT:
			var a = context.pop()
			context.push(not a)
		IRInstruction.OpCode.NEG:
			var a = context.pop()
			context.push(-a)
		IRInstruction.OpCode.JMP:
			context.ip = arg
		IRInstruction.OpCode.JMP_IF_FALSE:
			var cond = context.pop()
			if not cond:
				context.ip = arg
		IRInstruction.OpCode.CALL:
			var func_name = arg[0]
			var argc = arg[1]
			if program.functions.has(func_name):
				var target_ip = program.functions[func_name]
				var frame = { "ip": context.ip, "local_vars": [] }
				var args = []
				for i in range(argc): args.insert(0, context.pop())
				for i in range(argc):
					while frame["local_vars"].size() <= i: frame["local_vars"].append(null)
					frame["local_vars"][i] = args[i]
					
				context.call_stack.append(frame)
				context.ip = target_ip
			else:
				_error("Call to undefined function '%s'" % func_name)
		IRInstruction.OpCode.RET:
			var frame = context.call_stack.pop_back()
			if frame["ip"] == -1:
				context.state = RuntimeContext.State.HALTED
				emit_signal("log_message", "--- VM Execution Finished ---")
				emit_signal("execution_finished")
			else:
				context.ip = frame["ip"]
		IRInstruction.OpCode.LOAD_MEMBER:
			var obj = context.pop()
			if typeof(obj) == TYPE_DICTIONARY:
				if obj.has(arg):
					context.push(obj[arg])
				else:
					_error("Property '%s' not found on dictionary." % str(arg))
			elif typeof(obj) == TYPE_OBJECT:
				if arg in obj:
					context.push(obj.get(arg))
				else:
					_error("Property '%s' not found on object." % str(arg))
			else:
				_error("Cannot access member '%s' on non-object." % str(arg))
		IRInstruction.OpCode.BUILTIN_CALL:
			var func_name = arg[0]
			var argc = arg[1]
			var args = []
			for i in range(argc): args.insert(0, context.pop())
			
			match func_name:
				"get_enemies": context.push(api.get_enemies())
				"nearest": context.push(api.nearest(args[0]))
				"distance": context.push(api.distance(args[0]))
				"shoot": api.shoot(args[0])
				"reload": api.reload()
				"_array_size": context.push(args[0].size() if typeof(args[0]) == TYPE_ARRAY else 0)
				"_array_get": 
					var arr = args[0]
					var idx = args[1]
					if typeof(arr) == TYPE_ARRAY and idx >= 0 and idx < arr.size():
						context.push(arr[idx])
					else:
						_error("Array index out of bounds")
				_:
					_error("Unknown builtin '%s'" % func_name)

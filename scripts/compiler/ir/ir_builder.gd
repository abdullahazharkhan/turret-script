extends RefCounted

const AST = preload("res://scripts/compiler/ast.gd")
const TT = preload("res://scripts/compiler/data/token_type.gd")
const IRInstruction = preload("res://scripts/compiler/ir/ir_instruction.gd")
const IRProgram = preload("res://scripts/compiler/ir/ir_program.gd")

var program: IRProgram
var _local_vars: Array = [] # Stack of scopes (String -> int ID)
var _var_counter: int = 0
var _jump_stack: Array = [] # Stack for jump patching during build

func build(ast_root: AST.Program) -> IRProgram:
	program = IRProgram.new()
	_local_vars.clear()
	_var_counter = 0
	_jump_stack.clear()
	
	_begin_scope()
	_visit(ast_root)
	_end_scope()
	
	return program

func _begin_scope():
	_local_vars.append({})

func _end_scope():
	_local_vars.pop_back()

func _declare_var(name: String) -> int:
	var scope = _local_vars.back()
	var id = _var_counter
	_var_counter += 1
	scope[name] = id
	return id

func _resolve_var(name: String) -> int:
	for i in range(_local_vars.size() - 1, -1, -1):
		if _local_vars[i].has(name):
			return _local_vars[i][name]
	return -1

func _emit(opcode: int, operand = null, line: int = -1) -> int:
	var inst = IRInstruction.new(opcode, operand, line)
	return program.add_instruction(inst)

func _patch_jump(inst_idx: int, target_idx: int):
	program.instructions[inst_idx].operand = target_idx

func _get_line(node: AST.ASTNode) -> int:
	if node and node.span:
		return node.span.line
	return -1

func _visit(node: AST.ASTNode):
	if node == null: return
	
	var ln = _get_line(node)
	
	match node.type:
		"Program":
			for stmt in node.statements: _visit(stmt)
		"VarDecl":
			if node.initializer:
				_visit(node.initializer)
			else:
				# Default uninitialized values
				_emit(IRInstruction.OpCode.PUSH, 0, ln)
				
			var var_id = _declare_var(node.identifier)
			_emit(IRInstruction.OpCode.STORE_VAR, var_id, ln)
			
		"Assignment":
			_visit(node.value)
			var var_id = _resolve_var(node.identifier)
			_emit(IRInstruction.OpCode.STORE_VAR, var_id, ln)
			
		"FunctionDecl":
			var jmp_over = _emit(IRInstruction.OpCode.JMP, -1, ln)
			program.functions[node.identifier] = program.instructions.size()
			
			_begin_scope()
			for p in node.parameters:
				_declare_var(p.name)
				
			_visit(node.body)
			
			if node.return_type == "void":
				_emit(IRInstruction.OpCode.RET, null, ln)
				
			_end_scope()
			_patch_jump(jmp_over, program.instructions.size())
			
		"Block":
			_begin_scope()
			for stmt in node.statements: _visit(stmt)
			_end_scope()
			
		"IfStmt":
			_visit(node.condition)
			var jmp_if_false = _emit(IRInstruction.OpCode.JMP_IF_FALSE, -1, ln)
			_visit(node.then_branch)
			
			var jmp_end = -1
			if node.else_branch:
				jmp_end = _emit(IRInstruction.OpCode.JMP, -1, ln)
				
			_patch_jump(jmp_if_false, program.instructions.size())
			
			if node.else_branch:
				_visit(node.else_branch)
				_patch_jump(jmp_end, program.instructions.size())
				
		"WhileStmt":
			var loop_start = program.instructions.size()
			_visit(node.condition)
			var jmp_end = _emit(IRInstruction.OpCode.JMP_IF_FALSE, -1, ln)
			
			_visit(node.body)
			_emit(IRInstruction.OpCode.JMP, loop_start, ln)
			_patch_jump(jmp_end, program.instructions.size())
			
		"ForEnemyStmt":
			# for enemy e in collection compiles to:
			# arr = collection
			# i = 0
			# while i < array_size(arr):
			#     e = array_get(arr, i)
			#     body()
			#     i = i + 1
			_visit(node.collection)
			
			_begin_scope()
			var array_var = _declare_var(".array_" + str(_var_counter))
			_emit(IRInstruction.OpCode.STORE_VAR, array_var, ln)
			
			var index_var = _declare_var(".index_" + str(_var_counter))
			_emit(IRInstruction.OpCode.PUSH, 0, ln)
			_emit(IRInstruction.OpCode.STORE_VAR, index_var, ln)
			
			var loop_start = program.instructions.size()
			
			# i < array_size(arr)
			_emit(IRInstruction.OpCode.LOAD_VAR, array_var, ln)
			_emit(IRInstruction.OpCode.BUILTIN_CALL, ["_array_size", 1], ln)
			_emit(IRInstruction.OpCode.LOAD_VAR, index_var, ln)
			_emit(IRInstruction.OpCode.GT, null, ln) # array_size > index is equivalent to index < array_size
			
			var jmp_end = _emit(IRInstruction.OpCode.JMP_IF_FALSE, -1, ln)
			
			# e = array_get(arr, i)
			_emit(IRInstruction.OpCode.LOAD_VAR, array_var, ln)
			_emit(IRInstruction.OpCode.LOAD_VAR, index_var, ln)
			_emit(IRInstruction.OpCode.BUILTIN_CALL, ["_array_get", 2], ln)
			
			var loop_var = _declare_var(node.identifier)
			_emit(IRInstruction.OpCode.STORE_VAR, loop_var, ln)
			
			_visit(node.body)
			
			# i = i + 1
			_emit(IRInstruction.OpCode.LOAD_VAR, index_var, ln)
			_emit(IRInstruction.OpCode.PUSH, 1, ln)
			_emit(IRInstruction.OpCode.ADD, null, ln)
			_emit(IRInstruction.OpCode.STORE_VAR, index_var, ln)
			
			_emit(IRInstruction.OpCode.JMP, loop_start, ln)
			_patch_jump(jmp_end, program.instructions.size())
			
			_end_scope()
			
		"ReturnStmt":
			if node.value:
				_visit(node.value)
			_emit(IRInstruction.OpCode.RET, null, ln)
			
		"ExprStmt":
			_visit(node.expression)
			
		"BinaryExpr":
			if node.operator == TT.TK_AND:
				_visit(node.left)
				var jmp_end = _emit(IRInstruction.OpCode.JMP_IF_FALSE_NO_POP, -1, ln)
				_jump_stack.push_back(jmp_end)
				_emit(IRInstruction.OpCode.POP, null, ln) # Pop left if it was true
				_visit(node.right)
				_patch_jump(_jump_stack.pop_back(), program.instructions.size())
			elif node.operator == TT.TK_OR:
				_visit(node.left)
				var jmp_end = _emit(IRInstruction.OpCode.JMP_IF_TRUE_NO_POP, -1, ln)
				_jump_stack.push_back(jmp_end)
				_emit(IRInstruction.OpCode.POP, null, ln) # Pop left if it was false
				_visit(node.right)
				_patch_jump(_jump_stack.pop_back(), program.instructions.size())
			else:
				_visit(node.left)
				_visit(node.right)
				match node.operator:
					TT.TK_PLUS: _emit(IRInstruction.OpCode.ADD, null, ln)
					TT.TK_MINUS: _emit(IRInstruction.OpCode.SUB, null, ln)
					TT.TK_STAR: _emit(IRInstruction.OpCode.MUL, null, ln)
					TT.TK_SLASH: _emit(IRInstruction.OpCode.DIV, null, ln)
					TT.TK_EQ: _emit(IRInstruction.OpCode.EQ, null, ln)
					TT.TK_NEQ: _emit(IRInstruction.OpCode.NEQ, null, ln)
					TT.TK_LT: _emit(IRInstruction.OpCode.LT, null, ln)
					TT.TK_LTE: _emit(IRInstruction.OpCode.LTE, null, ln)
					TT.TK_GT: _emit(IRInstruction.OpCode.GT, null, ln)
					TT.TK_GTE: _emit(IRInstruction.OpCode.GTE, null, ln)
				
		"UnaryExpr":
			_visit(node.right)
			if node.operator == TT.TK_MINUS:
				_emit(IRInstruction.OpCode.NEG, null, ln)
			elif node.operator == TT.TK_NOT:
				_emit(IRInstruction.OpCode.NOT, null, ln)
				
		"LiteralExpr":
			_emit(IRInstruction.OpCode.PUSH, node.value, ln)
			
		"IdentifierExpr":
			var var_id = _resolve_var(node.identifier)
			if var_id != -1:
				_emit(IRInstruction.OpCode.LOAD_VAR, var_id, ln)
				
		"CallExpr":
			for arg in node.arguments:
				_visit(arg)
			
			var builtins = ["get_enemies", "nearest", "distance", "shoot", "reload", "run", "enemy_x", "enemy_y", "enemy_dir_x", "enemy_dir_y", "turret_x", "turret_y", "_array_size", "_array_get"]
			if node.callee in builtins:
				_emit(IRInstruction.OpCode.BUILTIN_CALL, [node.callee, node.arguments.size()], ln)
			else:
				_emit(IRInstruction.OpCode.CALL, [node.callee, node.arguments.size()], ln)
				
		"MemberAccessExpr":
			_visit(node.object)
			_emit(IRInstruction.OpCode.LOAD_MEMBER, node.member, ln)

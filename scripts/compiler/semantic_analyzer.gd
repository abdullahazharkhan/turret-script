extends RefCounted

const AST = preload("res://scripts/compiler/ast.gd")
const TT = preload("res://scripts/compiler/data/token_type.gd")
const TypeInfo = preload("res://scripts/compiler/data/type_info.gd")
const Symbol = preload("res://scripts/compiler/data/symbol.gd")
const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")

var scopes: Array = []
var diagnostics: Array = []
var current_function: AST.FunctionDecl = null
var current_loop_depth: int = 0

func analyze(program: AST.Program) -> Array:
	scopes.clear()
	diagnostics.clear()
	
	_begin_scope()
	_register_builtins()
	
	_visit(program)
	
	var global_scope = scopes[0].values()
	_end_scope()
	return global_scope

func _register_builtins():
	_define("get_enemies", TypeInfo.FunctionType.new([], TypeInfo.ENEMY_ARRAY))
	_define("nearest", TypeInfo.FunctionType.new([TypeInfo.ENEMY_ARRAY], TypeInfo.ENEMY))
	_define("distance", TypeInfo.FunctionType.new([TypeInfo.ENEMY], TypeInfo.INT))
	_define("shoot", TypeInfo.FunctionType.new([TypeInfo.ENEMY], TypeInfo.VOID))
	_define("reload", TypeInfo.FunctionType.new([], TypeInfo.VOID))
	_define("run", TypeInfo.FunctionType.new([TypeInfo.INT, TypeInfo.INT, TypeInfo.INT], TypeInfo.VOID))
	_define("enemy_x", TypeInfo.FunctionType.new([TypeInfo.ENEMY], TypeInfo.INT))
	_define("enemy_y", TypeInfo.FunctionType.new([TypeInfo.ENEMY], TypeInfo.INT))
	_define("enemy_dir_x", TypeInfo.FunctionType.new([TypeInfo.ENEMY], TypeInfo.INT))
	_define("enemy_dir_y", TypeInfo.FunctionType.new([TypeInfo.ENEMY], TypeInfo.INT))
	_define("turret_x", TypeInfo.FunctionType.new([], TypeInfo.INT))
	_define("turret_y", TypeInfo.FunctionType.new([], TypeInfo.INT))
	_define("_array_size", TypeInfo.FunctionType.new([TypeInfo.ENEMY_ARRAY], TypeInfo.INT))
	_define("_array_get", TypeInfo.FunctionType.new([TypeInfo.ENEMY_ARRAY, TypeInfo.INT], TypeInfo.ENEMY))

func _begin_scope():
	scopes.append({})

func _end_scope():
	scopes.pop_back()

func _define(name: String, type_info) -> Symbol:
	var scope = scopes.back()
	if scope.has(name):
		return null # Already declared
	var sym = Symbol.new(name, type_info, scopes.size() - 1)
	scope[name] = sym
	return sym

func _resolve(name: String) -> Symbol:
	for i in range(scopes.size() - 1, -1, -1):
		if scopes[i].has(name):
			return scopes[i][name]
	return null

func _report_error(msg: String, span):
	diagnostics.append(DiagScript.new(DiagScript.LVL_ERROR, msg, span))

func _visit(node: AST.ASTNode):
	if node == null: return
	
	match node.type:
		"Program":
			for stmt in node.statements: _visit(stmt)
		"VarDecl":
			if node.type_name == "var":
				if not node.initializer:
					_report_error("Type inference using 'var' requires an initializer. (Did you mean to explicitly declare 'type name;' ?)", node.span)
					node.type_name = TypeInfo.ERROR
				else:
					_visit(node.initializer)
					node.type_name = node.initializer.resolved_type
			else:
				if node.initializer:
					_visit(node.initializer)
					if not TypeInfo.is_assignable(node.type_name, node.initializer.resolved_type):
						_report_error("Type mismatch: cannot assign '%s' to variable of type '%s'. (Check the variable declaration type)." % [node.initializer.resolved_type, node.type_name], node.span)
			var sym = _define(node.identifier, node.type_name)
			if sym == null:
				_report_error("Variable '%s' is already declared in this scope. (Consider renaming it)." % node.identifier, node.span)
			node.symbol = sym
		"Assignment":
			var sym = _resolve(node.identifier)
			if sym == null:
				_report_error("Undefined variable '%s'. (Did you misspell it or forget to declare it?)" % node.identifier, node.span)
			_visit(node.value)
			if sym and node.value.resolved_type != TypeInfo.ERROR:
				if not TypeInfo.is_assignable(sym.type_info, node.value.resolved_type):
					_report_error("Type mismatch: cannot assign '%s' to variable of type '%s'." % [node.value.resolved_type, sym.type_info], node.span)
		"FunctionDecl":
			var param_types = []
			for p in node.parameters:
				param_types.append(p.type)
			
			var fn_type = TypeInfo.FunctionType.new(param_types, node.return_type)
			var sym = _define(node.identifier, fn_type)
			if sym == null:
				_report_error("Function '%s' is already declared." % node.identifier, node.span)
				
			var prev_fn = current_function
			current_function = node
			
			_begin_scope()
			for p in node.parameters:
				_define(p.name, p.type)
			
			_visit(node.body)
			_end_scope()
			
			current_function = prev_fn
		"Block":
			_begin_scope()
			for stmt in node.statements: _visit(stmt)
			_end_scope()
		"IfStmt":
			_visit(node.condition)
			if node.condition.resolved_type != TypeInfo.BOOL and node.condition.resolved_type != TypeInfo.ERROR:
				_report_error("Condition must be of type 'bool'. (Did you use an assignment '=' instead of equality '==' ?)", node.condition.span)
			_visit(node.then_branch)
			if node.else_branch: _visit(node.else_branch)
		"WhileStmt":
			_visit(node.condition)
			if node.condition.resolved_type != TypeInfo.BOOL and node.condition.resolved_type != TypeInfo.ERROR:
				_report_error("Loop condition must be of type 'bool'.", node.condition.span)
			current_loop_depth += 1
			_visit(node.body)
			current_loop_depth -= 1
		"ForEnemyStmt":
			_visit(node.collection)
			if node.collection.resolved_type != TypeInfo.ENEMY_ARRAY and node.collection.resolved_type != TypeInfo.ERROR:
				_report_error("Can only iterate over 'enemy_array'.", node.collection.span)
			
			_begin_scope()
			_define(node.identifier, TypeInfo.ENEMY)
			current_loop_depth += 1
			_visit(node.body)
			current_loop_depth -= 1
			_end_scope()
		"ReturnStmt":
			if current_function == null:
				_report_error("Cannot return from top-level code.", node.span)
			else:
				var ret_type = TypeInfo.VOID
				if node.value:
					_visit(node.value)
					ret_type = node.value.resolved_type
				if not TypeInfo.is_assignable(current_function.return_type, ret_type):
					_report_error("Return type mismatch: cannot return '%s' from function returning '%s'." % [ret_type, current_function.return_type], node.span)
		"ExprStmt":
			_visit(node.expression)
		"BinaryExpr":
			_visit(node.left)
			_visit(node.right)
			var lt = node.left.resolved_type
			var rt = node.right.resolved_type
			
			if lt == TypeInfo.ERROR or rt == TypeInfo.ERROR:
				node.resolved_type = TypeInfo.ERROR
				return
				
			match node.operator:
				TT.TK_PLUS, TT.TK_MINUS, TT.TK_STAR, TT.TK_SLASH:
					if lt == TypeInfo.INT and rt == TypeInfo.INT:
						node.resolved_type = TypeInfo.INT
					elif node.operator == TT.TK_PLUS and lt == TypeInfo.STRING and rt == TypeInfo.STRING:
						node.resolved_type = TypeInfo.STRING
					else:
						_report_error("Invalid operands for arithmetic operator.", node.span)
						node.resolved_type = TypeInfo.ERROR
				TT.TK_LT, TT.TK_LTE, TT.TK_GT, TT.TK_GTE:
					if lt == TypeInfo.INT and rt == TypeInfo.INT:
						node.resolved_type = TypeInfo.BOOL
					else:
						_report_error("Operands must be 'int' for relational operator.", node.span)
						node.resolved_type = TypeInfo.ERROR
				TT.TK_EQ, TT.TK_NEQ:
					if lt == rt or TypeInfo.is_assignable(lt, rt) or TypeInfo.is_assignable(rt, lt):
						node.resolved_type = TypeInfo.BOOL
					else:
						_report_error("Type mismatch: cannot compare different types ('%s' and '%s')." % [lt, rt], node.span)
						node.resolved_type = TypeInfo.ERROR
				TT.TK_AND, TT.TK_OR:
					if lt == TypeInfo.BOOL and rt == TypeInfo.BOOL:
						node.resolved_type = TypeInfo.BOOL
					else:
						_report_error("Operands must be 'bool' for logical operator.", node.span)
						node.resolved_type = TypeInfo.ERROR
		"UnaryExpr":
			_visit(node.right)
			var rt = node.right.resolved_type
			if rt == TypeInfo.ERROR:
				node.resolved_type = TypeInfo.ERROR
				return
			
			if node.operator == TT.TK_MINUS:
				if rt == TypeInfo.INT: node.resolved_type = TypeInfo.INT
				else:
					_report_error("Operand must be 'int' for unary '-'.", node.span)
					node.resolved_type = TypeInfo.ERROR
			elif node.operator == TT.TK_NOT:
				if rt == TypeInfo.BOOL: node.resolved_type = TypeInfo.BOOL
				else:
					_report_error("Operand must be 'bool' for unary '!'.", node.span)
					node.resolved_type = TypeInfo.ERROR
		"LiteralExpr":
			match node.literal_type:
				TT.TK_INT_LITERAL: node.resolved_type = TypeInfo.INT
				TT.TK_BOOL_LITERAL: node.resolved_type = TypeInfo.BOOL
				TT.TK_STRING_LITERAL: node.resolved_type = TypeInfo.STRING
				TT.TK_NULL_LITERAL: node.resolved_type = TypeInfo.NULL
		"IdentifierExpr":
			var sym = _resolve(node.identifier)
			if sym == null:
				_report_error("Undefined variable '%s'. (Did you misspell it or forget to declare it?)" % node.identifier, node.span)
				node.resolved_type = TypeInfo.ERROR
			else:
				node.symbol = sym
				node.resolved_type = sym.type_info
		"CallExpr":
			var sym = _resolve(node.callee)
			if sym == null:
				_report_error("Undefined function '%s'. (Check the spelling or the Built-in API reference)." % node.callee, node.span)
				node.resolved_type = TypeInfo.ERROR
				for arg in node.arguments: _visit(arg)
				return
				
			if not (sym.type_info is TypeInfo.FunctionType):
				_report_error("'%s' is not a function." % node.callee, node.span)
				node.resolved_type = TypeInfo.ERROR
				for arg in node.arguments: _visit(arg)
				return
				
			var fn_type = sym.type_info
			if node.arguments.size() != fn_type.parameters.size():
				_report_error("Function '%s' expects %d arguments, but got %d." % [node.callee, fn_type.parameters.size(), node.arguments.size()], node.span)
				
			for i in range(node.arguments.size()):
				var arg = node.arguments[i]
				_visit(arg)
				if i < fn_type.parameters.size():
					if not TypeInfo.is_assignable(fn_type.parameters[i], arg.resolved_type):
						_report_error("Argument %d of '%s' expects type '%s' but got '%s'. (Check the API reference for the correct types)." % [i+1, node.callee, fn_type.parameters[i], arg.resolved_type], arg.span)
						
			node.resolved_type = fn_type.return_type
		"MemberAccessExpr":
			_visit(node.object)
			var obj_type = node.object.resolved_type
			if obj_type == TypeInfo.ERROR:
				node.resolved_type = TypeInfo.ERROR
				return
				
			if obj_type == TypeInfo.ENEMY:
				if node.member == "health":
					node.resolved_type = TypeInfo.INT
				elif node.member == "speed":
					node.resolved_type = TypeInfo.INT
				elif node.member == "type":
					node.resolved_type = TypeInfo.STRING
				elif node.member == "id":
					node.resolved_type = TypeInfo.INT
				elif node.member == "alive":
					node.resolved_type = TypeInfo.BOOL
				else:
					_report_error("Property '%s' does not exist on type 'enemy'. Available properties: id, health, type, alive, speed." % node.member, node.span)
					node.resolved_type = TypeInfo.ERROR
			else:
				_report_error("Member access is only supported on 'enemy' objects.", node.span)
				node.resolved_type = TypeInfo.ERROR

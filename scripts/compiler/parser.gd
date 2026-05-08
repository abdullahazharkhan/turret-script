extends RefCounted

const TT = preload("res://scripts/compiler/data/token_type.gd")
const AST = preload("res://scripts/compiler/ast.gd")
const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")

var _tokens: Array
var _current: int = 0
var diagnostics: Array = []

func parse(tokens: Array) -> AST.Program:
	_tokens = tokens
	_current = 0
	diagnostics.clear()

	var program = AST.Program.new()
	while not _is_at_end():
		var stmt = _declaration()
		if stmt != null:
			program.statements.append(stmt)
			
	return program

func _declaration() -> AST.ASTNode:
	# Recursive descent entry point for a statement/declaration
	var result = null
	
	if _match([TT.TK_FUNC]):
		result = _function_declaration()
	elif _match([TT.TK_VAR, TT.TK_TYPE_INT, TT.TK_TYPE_BOOL, TT.TK_TYPE_STRING, TT.TK_TYPE_ENEMY, TT.TK_TYPE_VOID]):
		result = _var_declaration()
	else:
		result = _statement()
		
	if result == null:
		_synchronize()
	return result

func _function_declaration() -> AST.FunctionDecl:
	var func_token = _previous()
	var name = _consume(TT.TK_IDENTIFIER, "Expect function name.")
	_consume(TT.TK_LPAREN, "Expect '(' after function name.")
	
	var parameters = []
	if not _check(TT.TK_RPAREN):
		while true:
			var p_type = _consume_type("Expect parameter type.")
			var p_name = _consume(TT.TK_IDENTIFIER, "Expect parameter name.")
			if p_type != null and p_name != null:
				parameters.append({"name": p_name.lexeme, "type": p_type.lexeme})
			if not _match([TT.TK_COMMA]):
				break
				
	_consume(TT.TK_RPAREN, "Expect ')' after parameters.")
	
	var return_type = "void"
	if _match([TT.TK_ARROW]):
		var rt_token = _consume_type("Expect return type after '->'.")
		if rt_token != null:
			return_type = rt_token.lexeme
			
	_consume(TT.TK_LBRACE, "Expect '{' before function body.")
	var body = _block()
	
	var node = AST.FunctionDecl.new(func_token.span)
	if name != null:
		node.identifier = name.lexeme
	node.parameters = parameters
	node.return_type = return_type
	node.body = body
	return node

func _var_declaration() -> AST.VarDecl:
	var type_token = _previous()
	var name = _consume(TT.TK_IDENTIFIER, "Expect variable name.")
	
	var initializer = null
	if _match([TT.TK_ASSIGN]):
		initializer = _expression()
		
	_consume(TT.TK_SEMICOLON, "Expect ';' after variable declaration.")
	
	var node = AST.VarDecl.new(type_token.span)
	node.type_name = type_token.lexeme
	if name != null:
		node.identifier = name.lexeme
	node.initializer = initializer
	return node

func _statement() -> AST.ASTNode:
	if _match([TT.TK_IF]):
		return _if_statement()
	if _match([TT.TK_WHILE]):
		return _while_statement()
	if _match([TT.TK_FOR]):
		return _for_enemy_statement()
	if _match([TT.TK_RETURN]):
		return _return_statement()
	if _match([TT.TK_LBRACE]):
		return _block()
		
	# Could be an assignment or an expression statement
	# Let's check for Assignment (Identifier "=" Expression)
	if _check(TT.TK_IDENTIFIER) and _check_next(TT.TK_ASSIGN):
		return _assignment()
		
	return _expression_statement()

func _if_statement() -> AST.IfStmt:
	var token = _previous()
	_consume(TT.TK_LPAREN, "Expect '(' after 'if'.")
	var condition = _expression()
	_consume(TT.TK_RPAREN, "Expect ')' after if condition.")
	
	var then_branch = _statement()
	if then_branch is not AST.Block:
		# If the branch isn't a block, wrap it in one to simplify AST and VM logic later
		var wrapper = AST.Block.new(then_branch.span if then_branch else token.span)
		if then_branch: wrapper.statements.append(then_branch)
		then_branch = wrapper
		
	var else_branch = null
	if _match([TT.TK_ELSE]):
		else_branch = _statement()
		if else_branch is not AST.Block:
			var wrapper = AST.Block.new(else_branch.span if else_branch else _previous().span)
			if else_branch: wrapper.statements.append(else_branch)
			else_branch = wrapper
			
	var node = AST.IfStmt.new(token.span)
	node.condition = condition
	node.then_branch = then_branch
	node.else_branch = else_branch
	return node

func _while_statement() -> AST.WhileStmt:
	var token = _previous()
	_consume(TT.TK_LPAREN, "Expect '(' after 'while'.")
	var condition = _expression()
	_consume(TT.TK_RPAREN, "Expect ')' after while condition.")
	
	var body = _statement()
	if body is not AST.Block:
		var wrapper = AST.Block.new(body.span if body else token.span)
		if body: wrapper.statements.append(body)
		body = wrapper
		
	var node = AST.WhileStmt.new(token.span)
	node.condition = condition
	node.body = body
	return node

func _for_enemy_statement() -> AST.ForEnemyStmt:
	var token = _previous()
	_consume(TT.TK_TYPE_ENEMY, "Expect 'enemy' after 'for'.")
	var name = _consume(TT.TK_IDENTIFIER, "Expect loop variable name.")
	_consume(TT.TK_IN, "Expect 'in' after loop variable.")
	_consume(TT.TK_GET_ENEMIES, "Expect 'get_enemies' after 'in'.")
	_consume(TT.TK_LPAREN, "Expect '(' after 'get_enemies'.")
	_consume(TT.TK_RPAREN, "Expect ')' after '('.")
	
	var body = _statement()
	if body is not AST.Block:
		var wrapper = AST.Block.new(body.span if body else token.span)
		if body: wrapper.statements.append(body)
		body = wrapper
		
	var node = AST.ForEnemyStmt.new(token.span)
	if name != null: node.identifier = name.lexeme
	node.body = body
	return node

func _return_statement() -> AST.ReturnStmt:
	var token = _previous()
	var value = null
	if not _check(TT.TK_SEMICOLON):
		value = _expression()
	_consume(TT.TK_SEMICOLON, "Expect ';' after return value.")
	
	var node = AST.ReturnStmt.new(token.span)
	node.value = value
	return node

func _assignment() -> AST.Assignment:
	var name = _consume(TT.TK_IDENTIFIER, "Expect variable name.")
	var assign = _consume(TT.TK_ASSIGN, "Expect '=' after variable name.")
	var value = _expression()
	_consume(TT.TK_SEMICOLON, "Expect ';' after assignment value.")
	
	var node = AST.Assignment.new(name.span if name else assign.span)
	if name != null: node.identifier = name.lexeme
	node.value = value
	return node

func _expression_statement() -> AST.ExprStmt:
	var expr = _expression()
	var token = _previous()
	_consume(TT.TK_SEMICOLON, "Expect ';' after expression.")
	var node = AST.ExprStmt.new(expr.span if expr else token.span)
	node.expression = expr
	return node

func _block() -> AST.Block:
	var token = _previous()
	var node = AST.Block.new(token.span)
	
	while not _check(TT.TK_RBRACE) and not _is_at_end():
		var stmt = _declaration()
		if stmt != null:
			node.statements.append(stmt)
			
	_consume(TT.TK_RBRACE, "Expect '}' after block.")
	return node

# -- Expressions --

func _expression() -> AST.ASTNode:
	return _logical_or()

func _logical_or() -> AST.ASTNode:
	var expr = _logical_and()
	while _match([TT.TK_OR]):
		var operator = _previous().type
		var right = _logical_and()
		var node = AST.BinaryExpr.new(expr.span if expr else null)
		node.left = expr
		node.operator = operator
		node.right = right
		expr = node
	return expr

func _logical_and() -> AST.ASTNode:
	var expr = _equality()
	while _match([TT.TK_AND]):
		var operator = _previous().type
		var right = _equality()
		var node = AST.BinaryExpr.new(expr.span if expr else null)
		node.left = expr
		node.operator = operator
		node.right = right
		expr = node
	return expr

func _equality() -> AST.ASTNode:
	var expr = _relational()
	while _match([TT.TK_EQ, TT.TK_NEQ]):
		var operator = _previous().type
		var right = _relational()
		var node = AST.BinaryExpr.new(expr.span if expr else null)
		node.left = expr
		node.operator = operator
		node.right = right
		expr = node
	return expr

func _relational() -> AST.ASTNode:
	var expr = _additive()
	while _match([TT.TK_LT, TT.TK_LTE, TT.TK_GT, TT.TK_GTE]):
		var operator = _previous().type
		var right = _additive()
		var node = AST.BinaryExpr.new(expr.span if expr else null)
		node.left = expr
		node.operator = operator
		node.right = right
		expr = node
	return expr

func _additive() -> AST.ASTNode:
	var expr = _multiplicative()
	while _match([TT.TK_PLUS, TT.TK_MINUS]):
		var operator = _previous().type
		var right = _multiplicative()
		var node = AST.BinaryExpr.new(expr.span if expr else null)
		node.left = expr
		node.operator = operator
		node.right = right
		expr = node
	return expr

func _multiplicative() -> AST.ASTNode:
	var expr = _unary()
	while _match([TT.TK_STAR, TT.TK_SLASH]):
		var operator = _previous().type
		var right = _unary()
		var node = AST.BinaryExpr.new(expr.span if expr else null)
		node.left = expr
		node.operator = operator
		node.right = right
		expr = node
	return expr

func _unary() -> AST.ASTNode:
	if _match([TT.TK_NOT, TT.TK_MINUS]):
		var operator = _previous()
		var right = _unary()
		var node = AST.UnaryExpr.new(operator.span)
		node.operator = operator.type
		node.right = right
		return node
	return _call()

func _call() -> AST.ASTNode:
	var expr = _primary()
	
	while true:
		if _match([TT.TK_LPAREN]):
			expr = _finish_call(expr)
		elif _match([TT.TK_DOT]):
			var name = _consume(TT.TK_IDENTIFIER, "Expect property name after '.'.")
			var node = AST.MemberAccessExpr.new(_previous().span)
			node.object = expr
			if name: node.member = name.lexeme
			expr = node
		else:
			break
			
	return expr

func _finish_call(callee: AST.ASTNode) -> AST.CallExpr:
	var args = []
	if not _check(TT.TK_RPAREN):
		while true:
			args.append(_expression())
			if not _match([TT.TK_COMMA]):
				break
	
	var paren = _consume(TT.TK_RPAREN, "Expect ')' after arguments.")
	var node = AST.CallExpr.new(callee.span if callee else paren.span)
	if callee is AST.IdentifierExpr:
		node.callee = callee.identifier
	else:
		# If it's a built-in API keyword like shoot
		# We should handle built-ins as PrimaryExpr identifiers
		pass
		
	node.arguments = args
	return node

func _primary() -> AST.ASTNode:
	if _match([TT.TK_BOOL_LITERAL]):
		var token = _previous()
		var n = AST.LiteralExpr.new(token.span)
		n.value = token.literal
		n.literal_type = TT.TK_BOOL_LITERAL
		return n
	
	if _match([TT.TK_INT_LITERAL, TT.TK_STRING_LITERAL]):
		var token = _previous()
		var n = AST.LiteralExpr.new(token.span)
		n.value = token.literal
		n.literal_type = token.type
		return n
		
	if _match([TT.TK_IDENTIFIER, TT.TK_GET_ENEMIES, TT.TK_NEAREST, TT.TK_DISTANCE, TT.TK_SHOOT, TT.TK_RELOAD]):
		var n = AST.IdentifierExpr.new(_previous().span)
		n.identifier = _previous().lexeme
		return n
		
	if _match([TT.TK_LPAREN]):
		var expr = _expression()
		_consume(TT.TK_RPAREN, "Expect ')' after expression.")
		return expr
		
	_error(_peek(), "Expect expression.")
	return null

# -- Helpers --

func _consume_type(message: String):
	if _match([TT.TK_TYPE_INT, TT.TK_TYPE_BOOL, TT.TK_TYPE_STRING, TT.TK_TYPE_ENEMY, TT.TK_TYPE_VOID]):
		return _previous()
	_error(_peek(), message)
	return null

func _match(types: Array) -> bool:
	for type in types:
		if _check(type):
			_advance()
			return true
	return false

func _check(type: int) -> bool:
	if _is_at_end(): return false
	return _peek().type == type

func _check_next(type: int) -> bool:
	if _current + 1 >= _tokens.size(): return false
	return _tokens[_current + 1].type == type

func _advance():
	if not _is_at_end(): _current += 1
	return _previous()

func _is_at_end() -> bool:
	return _peek().type == TT.TK_EOF

func _peek():
	return _tokens[_current]

func _previous():
	return _tokens[_current - 1]

func _consume(type: int, message: String):
	if _check(type): return _advance()
	_error(_peek(), message)
	return null

func _error(token, message: String):
	var span = token.span
	diagnostics.append(DiagScript.new(DiagScript.LVL_ERROR, message, span))

func _synchronize():
	_advance()
	
	while not _is_at_end():
		if _previous().type == TT.TK_SEMICOLON: return
		
		match _peek().type:
			TT.TK_FUNC, TT.TK_IF, TT.TK_WHILE, TT.TK_FOR, TT.TK_RETURN, TT.TK_TYPE_INT, TT.TK_TYPE_BOOL, TT.TK_TYPE_STRING, TT.TK_TYPE_ENEMY:
				return
				
		_advance()

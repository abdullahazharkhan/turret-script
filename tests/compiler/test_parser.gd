extends SceneTree

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const TT = preload("res://scripts/compiler/data/token_type.gd")

func _init():
	print("Running Parser tests...")
	var lexer = LexerScript.new()
	var parser = ParserScript.new()
	
	# Test 1: Basic variable declaration
	var tokens = lexer.tokenize("int ammo = 10;")
	var ast = parser.parse(tokens)
	assert(ast.statements.size() == 1, "Expected 1 statement")
	var decl = ast.statements[0]
	assert(decl.type == "VarDecl")
	assert(decl.identifier == "ammo")
	assert(decl.initializer.type == "LiteralExpr")
	
	# Test 2: Function declaration
	var func_source = """
	func shoot_enemy(enemy target) -> void {
		if (target) {
			shoot(target);
		}
	}
	"""
	tokens = lexer.tokenize(func_source)
	ast = parser.parse(tokens)
	assert(ast.statements.size() == 1)
	var func_decl = ast.statements[0]
	assert(func_decl.type == "FunctionDecl")
	assert(func_decl.identifier == "shoot_enemy")
	assert(func_decl.parameters.size() == 1)
	assert(func_decl.parameters[0].name == "target")
	assert(func_decl.body.statements.size() == 1)
	
	# Test 3: Syntax error recovery
	var err_source = """
	int a = ;
	int b = 5;
	"""
	tokens = lexer.tokenize(err_source)
	ast = parser.parse(tokens)
	assert(parser.diagnostics.size() > 0, "Expected diagnostics")
	assert(ast.statements.size() >= 1, "Expected at least 1 statement after recovery")
	
	print("All Parser tests passed!")
	quit()

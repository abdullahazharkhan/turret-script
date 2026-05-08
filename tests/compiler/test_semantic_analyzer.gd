extends SceneTree

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const SemanticScript = preload("res://scripts/compiler/semantic_analyzer.gd")

func _init():
	print("Running Semantic Analyzer tests...")
	var lexer = LexerScript.new()
	var parser = ParserScript.new()
	var semantic_analyzer = SemanticScript.new()
	
	# Test 1: Valid type checking
	var valid_source = """
	int ammo = 10;
	bool can_shoot = true;
	if (can_shoot && ammo > 0) {
		ammo = ammo - 1;
	}
	"""
	var tokens = lexer.tokenize(valid_source)
	var ast = parser.parse(tokens)
	semantic_analyzer.analyze(ast)
	assert(semantic_analyzer.diagnostics.is_empty(), "Expected no semantic errors")
	
	# Test 2: Invalid type assignment
	lexer.diagnostics.clear()
	parser.diagnostics.clear()
	semantic_analyzer.diagnostics.clear()
	var invalid_assign = "int x = \"hello\";"
	tokens = lexer.tokenize(invalid_assign)
	ast = parser.parse(tokens)
	semantic_analyzer.analyze(ast)
	assert(semantic_analyzer.diagnostics.size() == 1, "Expected type mismatch error")
	assert(semantic_analyzer.diagnostics[0].message.contains("Cannot assign type 'string' to variable of type 'int'"), "Wrong error message")
	
	# Test 3: Invalid condition
	lexer.diagnostics.clear()
	parser.diagnostics.clear()
	semantic_analyzer.diagnostics.clear()
	var invalid_cond = "if (10) {}"
	tokens = lexer.tokenize(invalid_cond)
	ast = parser.parse(tokens)
	semantic_analyzer.analyze(ast)
	assert(semantic_analyzer.diagnostics.size() == 1)
	assert(semantic_analyzer.diagnostics[0].message.contains("Condition must be of type 'bool'"))
	
	# Test 4: Member access
	lexer.diagnostics.clear()
	parser.diagnostics.clear()
	semantic_analyzer.diagnostics.clear()
	var member_access = """
	for enemy e in get_enemies() {
		int h = e.health;
		if (h < 50) {
			shoot(e);
		}
	}
	"""
	tokens = lexer.tokenize(member_access)
	ast = parser.parse(tokens)
	semantic_analyzer.analyze(ast)
	assert(semantic_analyzer.diagnostics.is_empty(), "Expected no semantic errors for member access")
	
	# Test 5: Built-in argument mismatch
	lexer.diagnostics.clear()
	parser.diagnostics.clear()
	semantic_analyzer.diagnostics.clear()
	var invalid_call = "shoot(5);"
	tokens = lexer.tokenize(invalid_call)
	ast = parser.parse(tokens)
	semantic_analyzer.analyze(ast)
	assert(semantic_analyzer.diagnostics.size() == 1)
	assert(semantic_analyzer.diagnostics[0].message.contains("expects type 'enemy' but got 'int'"))
	
	print("All Semantic Analyzer tests passed!")
	quit()

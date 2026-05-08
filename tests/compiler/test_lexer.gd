extends SceneTree

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const TT = preload("res://scripts/compiler/data/token_type.gd")

func _init():
	print("Running Lexer tests...")
	var lexer = LexerScript.new()

	# Test 1: Basic variable declaration
	var tokens = lexer.tokenize("int ammo = 10;")
	assert(tokens.size() == 6, "Expected 6 tokens, got %d" % tokens.size()) # int, ammo, =, 10, ;, EOF
	assert(tokens[0].type == TT.TK_TYPE_INT, "Expected TYPE_INT")
	assert(tokens[1].type == TT.TK_IDENTIFIER, "Expected IDENTIFIER")
	assert(tokens[1].lexeme == "ammo", "Expected 'ammo'")
	assert(tokens[2].type == TT.TK_ASSIGN, "Expected ASSIGN")
	assert(tokens[3].type == TT.TK_INT_LITERAL, "Expected INT_LITERAL")
	assert(tokens[3].literal == 10, "Expected literal 10")
	assert(tokens[4].type == TT.TK_SEMICOLON, "Expected SEMICOLON")
	assert(lexer.diagnostics.is_empty(), "Expected no diagnostics")

	# Test 2: Invalid character
	tokens = lexer.tokenize("int a = 5 $;")
	assert(lexer.diagnostics.size() == 1, "Expected 1 diagnostic")
	assert(lexer.diagnostics[0].message.contains("Unexpected character '$'"), "Expected '$' error")

	# Test 3: Unterminated string
	tokens = lexer.tokenize("string s = \"hello")
	assert(lexer.diagnostics.size() == 1, "Expected 1 diagnostic")
	assert(lexer.diagnostics[0].message.contains("Unterminated string"), "Expected unterminated string error")

	print("All Lexer tests passed!")
	quit()

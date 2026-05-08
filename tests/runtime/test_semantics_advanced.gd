extends SceneTree

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const SemanticScript = preload("res://scripts/compiler/semantic_analyzer.gd")

func _check_semantics(src: String) -> Array:
	var lexer = LexerScript.new()
	var parser = ParserScript.new()
	var semantic = SemanticScript.new()
	
	var tokens = lexer.tokenize(src)
	var ast = parser.parse(tokens)
	if ast == null: return [false, "Parse failed"]
	semantic.analyze(ast)
	
	if semantic.diagnostics.size() > 0:
		return [false, semantic.diagnostics[0].message]
	return [true, "OK"]

func _init():
	print("=== Advanced Semantic Tests ===")
	
	# Test 1: Armor piercing example
	var src1 = """
	func main() {
		var enemies = get_enemies();
		for enemy e in enemies {
			if (e.type == "tank" and distance(e) < 200) {
				shoot(e);
				return;
			}
		}
	}
	"""
	var res1 = _check_semantics(src1)
	assert(res1[0] == true, "T1 Failed: Expected valid semantics. Got: " + res1[1])
	print("[PASS] T1: Armor-Piercing compiles")
	
	# Test 2: Low health priority example
	var src2 = """
	func main() {
		var enemies = get_enemies();
		var best = _array_get(enemies, 0);
		for enemy e in enemies {
			if (e.health < best.health) {
				best = e;
			}
		}
	}
	"""
	var res2 = _check_semantics(src2)
	assert(res2[0] == true, "T2 Failed: Expected valid semantics. Got: " + res2[1])
	print("[PASS] T2: Low-Health Priority compiles")
	
	# Test 3: Intentional type error caught
	var src3 = """
	func main() {
		int threshold = "not a number";
	}
	"""
	var res3 = _check_semantics(src3)
	assert(res3[0] == false, "T3 Failed: Expected type error!")
	assert("Type mismatch" in res3[1], "T3 Failed: Expected 'Type mismatch' message")
	print("[PASS] T3: Intentionally invalid type caught")

	# Test 4: Member access validation
	var src4 = """
	func main() {
		var e = nearest(get_enemies());
		e.invalid_property = 5;
	}
	"""
	var res4 = _check_semantics(src4)
	assert(res4[0] == false, "T4 Failed: Expected missing property error!")
	assert("Property" in res4[1], "T4 Failed: Expected 'Property' error message")
	print("[PASS] T4: Invalid member access caught")

	print("\n=== All Advanced Semantic Tests Passed! ===")
	quit()

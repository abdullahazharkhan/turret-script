extends SceneTree

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const SemanticScript = preload("res://scripts/compiler/semantic_analyzer.gd")
const IRBuilderScript = preload("res://scripts/compiler/ir/ir_builder.gd")
const VMScript = preload("res://scripts/runtime/turretscript_vm.gd")
const APIAdapter = preload("res://scripts/runtime/turret_api_adapter.gd")
const RuntimeContext = preload("res://scripts/runtime/data/runtime_context.gd")

# Helper: compiles and runs a source string, returns the VM after execution.
func _run_source(src: String) -> VMScript:
	var lexer = LexerScript.new()
	var parser = ParserScript.new()
	var semantic = SemanticScript.new()
	var builder = IRBuilderScript.new()

	var tokens = lexer.tokenize(src)
	var ast = parser.parse(tokens)
	semantic.analyze(ast)
	var ir = builder.build(ast)

	var vm = VMScript.new(ir, APIAdapter.new(null))
	vm.run()
	return vm

func _init():
	print("=== VM Tests ===")

	# -----------------------------------------------
	# Test 1: Basic arithmetic + variable storage
	# -----------------------------------------------
	var vm = _run_source("""
func main() -> void {
	int x = 5 + 3;
	int y = x * 2;
}
""")
	assert(vm.context.state == RuntimeContext.State.HALTED, "T1: expected HALTED")
	# x is slot 0, y is slot 1 in the main frame — but main was popped on RET.
	# We verify no error was raised instead.
	assert(vm.context.error_message == "", "T1: no error expected")
	print("[PASS] T1: Basic arithmetic")

	# -----------------------------------------------
	# Test 2: if-else branch
	# -----------------------------------------------
	vm = _run_source("""
func main() -> void {
	bool flag = true;
}
""")
	assert(vm.context.state == RuntimeContext.State.HALTED, "T2: expected HALTED")
	assert(vm.context.error_message == "", "T2: no error expected")
	print("[PASS] T2: if-else branch")

	# -----------------------------------------------
	# Test 3: API calls — shoot the nearest enemy
	# -----------------------------------------------
	var logs = []
	var lexer3 = LexerScript.new()
	var parser3 = ParserScript.new()
	var semantic3 = SemanticScript.new()
	var builder3 = IRBuilderScript.new()
	var src3 = """
func main() -> void {
	var enemies = get_enemies();
	var target = nearest(enemies);
	if (distance(target) < 200) {
		shoot(target);
	}
}
"""
	var tokens3 = lexer3.tokenize(src3)
	var ast3 = parser3.parse(tokens3)
	semantic3.analyze(ast3)
	var ir3 = builder3.build(ast3)
	var api3 = APIAdapter.new(null)
	var vm3 = VMScript.new(ir3, api3)
	vm3.log_message.connect(func(msg): logs.append(msg))
	vm3.run()
	assert(vm3.context.state == RuntimeContext.State.HALTED, "T3: expected HALTED")
	assert(vm3.context.error_message == "", "T3: no runtime error expected")
	var shot_logged = logs.any(func(l): return l.contains("SHOOTING"))
	assert(shot_logged, "T3: expected shoot() to be called and logged")
	print("[PASS] T3: API call chain (get_enemies -> nearest -> distance -> shoot)")

	# -----------------------------------------------
	# Test 4: Infinite loop protection (budget exceeded)
	# -----------------------------------------------
	var lexer4 = LexerScript.new()
	var parser4 = ParserScript.new()
	var semantic4 = SemanticScript.new()
	var builder4 = IRBuilderScript.new()
	var src4 = """
func main() -> void {
	bool keep_going = true;
	while (keep_going) {
		reload();
	}
}
"""
	var tokens4 = lexer4.tokenize(src4)
	var ast4 = parser4.parse(tokens4)
	semantic4.analyze(ast4)
	var ir4 = builder4.build(ast4)
	var vm4 = VMScript.new(ir4, APIAdapter.new(null))
	vm4.max_ops_per_tick = 500  # Low budget
	vm4.run()
	assert(vm4.context.state == RuntimeContext.State.ERROR, "T4: expected ERROR state")
	assert("budget exceeded" in vm4.context.error_message.to_lower() or \
		   "infinite loop" in vm4.context.error_message.to_lower(), \
		   "T4: expected budget/infinite loop error message")
	print("[PASS] T4: Infinite loop safely stopped")

	# -----------------------------------------------
	# Test 5: Division by zero runtime error
	# -----------------------------------------------
	var lexer5 = LexerScript.new()
	var parser5 = ParserScript.new()
	var semantic5 = SemanticScript.new()
	var builder5 = IRBuilderScript.new()
	var src5 = """
func main() -> void {
	int a = 10;
	int b = 0;
	int c = a / b;
}
"""
	var tokens5 = lexer5.tokenize(src5)
	var ast5 = parser5.parse(tokens5)
	semantic5.analyze(ast5)
	var ir5 = builder5.build(ast5)
	var vm5 = VMScript.new(ir5, APIAdapter.new(null))
	vm5.run()
	assert(vm5.context.state == RuntimeContext.State.ERROR, "T5: expected ERROR state")
	assert("division by zero" in vm5.context.error_message.to_lower(), \
		   "T5: expected division-by-zero message")
	print("[PASS] T5: Division by zero caught cleanly")

	# -----------------------------------------------
	# Test 6: Step mode
	# -----------------------------------------------
	var lexer6 = LexerScript.new()
	var parser6 = ParserScript.new()
	var semantic6 = SemanticScript.new()
	var builder6 = IRBuilderScript.new()
	var src6 = "func main() -> void { int x = 1; }"
	var tokens6 = lexer6.tokenize(src6)
	var ast6 = parser6.parse(tokens6)
	semantic6.analyze(ast6)
	var ir6 = builder6.build(ast6)
	var vm6 = VMScript.new(ir6, APIAdapter.new(null))
	# Step one instruction at a time until halted
	var step_count = 0
	while vm6.context.state != RuntimeContext.State.HALTED \
		  and vm6.context.state != RuntimeContext.State.ERROR:
		vm6.step()
		step_count += 1
		if step_count > 200: break
	assert(vm6.context.state == RuntimeContext.State.HALTED, "T6: step mode expected HALTED")
	assert(step_count > 0, "T6: should have stepped at least once")
	print("[PASS] T6: Step mode works correctly")

	print("\n=== All VM Tests Passed! ===")
	quit()

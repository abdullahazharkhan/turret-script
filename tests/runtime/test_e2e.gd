extends SceneTree

const CompilerScript = preload("res://scripts/compiler/compiler.gd")
const TurretScriptVM = preload("res://scripts/runtime/turretscript_vm.gd")
const APIAdapter = preload("res://scripts/runtime/turret_api_adapter.gd")

func _init():
	print("=== End-to-End Pipeline Tests ===")
	
	# Full pipeline test without GameWorld (mock API)
	var src = """
	func main() {
		var enemies = get_enemies();
		var target = nearest(enemies);
		if (distance(target) < 200) {
			shoot(target);
		}
	}
	"""
	
	var compiler = CompilerScript.new()
	var result = compiler.compile(src)
	
	assert(result.success, "E2E Failed: Compilation unsuccessful")
	assert(result.ir != null, "E2E Failed: IR is null")
	
	var vm = TurretScriptVM.new(result.ir, APIAdapter.new(null))
	var error_caught = false
	vm.runtime_error.connect(func(msg): error_caught = true)
	
	vm.run()
	
	assert(not error_caught, "E2E Failed: Runtime error occurred")
	assert(vm.context.state == 3, "E2E Failed: Expected VM to reach HALTED state") # HALTED
	
	print("[PASS] E2E Pipeline: Compiler -> IR -> VM Execution works flawlessly!")
	quit()

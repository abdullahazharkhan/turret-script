extends RefCounted

const INT = "int"
const BOOL = "bool"
const STRING = "string"
const ENEMY = "enemy"
const ENEMY_ARRAY = "enemy_array"
const VOID = "void"
const NULL = "null"
const ERROR = "error"

class FunctionType extends RefCounted:
	var parameters: Array = [] # Array of String types
	var return_type: String
	
	func _init(p: Array, ret: String):
		parameters = p
		return_type = ret

static func is_assignable(target: String, source: String) -> bool:
	if source == ERROR or target == ERROR: return true
	if source == NULL or target == NULL: return true
	return target == source

extends RefCounted

var name: String
var type_info # String or FunctionType
var scope_depth: int
var memory_offset: int = -1 # Used later in IR phase

func _init(n: String, t, depth: int = 0):
	name = n
	type_info = t
	scope_depth = depth

func as_string() -> String:
	var t_str = ""
	if typeof(type_info) == TYPE_STRING: 
		t_str = type_info
	else:
		var ft = type_info
		t_str = "func(" + ", ".join(PackedStringArray(ft.parameters)) + ") -> " + ft.return_type
	return "%s: %s (Depth %d)" % [name, t_str, scope_depth]

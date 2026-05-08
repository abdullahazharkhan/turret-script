extends RefCounted

var instructions: Array = [] # Array of ir_instruction.gd
var constants: Array = []
var functions: Dictionary = {} # String -> Int (start instruction index)

func add_instruction(inst) -> int:
	instructions.append(inst)
	return instructions.size() - 1

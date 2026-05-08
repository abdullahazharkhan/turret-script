extends RefCounted

enum OpCode {
	PUSH,
	STORE_VAR,
	LOAD_VAR,
	ADD, SUB, MUL, DIV,
	EQ, NEQ, LT, LTE, GT, GTE,
	AND, OR, NOT, NEG,
	JMP, JMP_IF_FALSE,
	CALL, BUILTIN_CALL,
	RET,
	LOAD_MEMBER
}

var opcode: int
var operand
var line: int

func _init(op: int, arg = null, ln: int = -1):
	opcode = op
	operand = arg
	line = ln

func as_string() -> String:
	var op_name = OpCode.keys()[opcode]
	var arg_str = ""
	if operand != null:
		arg_str = " " + str(operand)
	
	var ln_str = ""
	if line >= 0:
		ln_str = " ; line " + str(line)
		
	return "%-18s%s" % [op_name + arg_str, ln_str]

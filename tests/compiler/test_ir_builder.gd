extends SceneTree

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const SemanticScript = preload("res://scripts/compiler/semantic_analyzer.gd")
const IRBuilderScript = preload("res://scripts/compiler/ir/ir_builder.gd")
const IRInstruction = preload("res://scripts/compiler/ir/ir_instruction.gd")

func _init():
	print("Running IR Builder tests...")
	var lexer = LexerScript.new()
	var parser = ParserScript.new()
	var semantic_analyzer = SemanticScript.new()
	var ir_builder = IRBuilderScript.new()
	
	# Test 1: Math and var declaration
	var src1 = "int x = 5 + 3;"
	var tokens = lexer.tokenize(src1)
	var ast = parser.parse(tokens)
	semantic_analyzer.analyze(ast)
	var ir = ir_builder.build(ast)
	
	assert(ir.instructions.size() == 4)
	assert(ir.instructions[0].opcode == IRInstruction.OpCode.PUSH and ir.instructions[0].operand == 5)
	assert(ir.instructions[1].opcode == IRInstruction.OpCode.PUSH and ir.instructions[1].operand == 3)
	assert(ir.instructions[2].opcode == IRInstruction.OpCode.ADD)
	assert(ir.instructions[3].opcode == IRInstruction.OpCode.STORE_VAR and ir.instructions[3].operand == 0)
	
	print("All IR Builder tests passed!")
	quit()

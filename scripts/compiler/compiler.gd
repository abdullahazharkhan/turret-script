# Compiler — orchestrates the pipeline stages
extends RefCounted

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const ResultScript = preload("res://scripts/compiler/data/compiler_result.gd")

var lexer
var parser

func _init():
	lexer = LexerScript.new()
	parser = ParserScript.new()

func compile(source: String):
	var result = ResultScript.new()
	var tokens = lexer.tokenize(source)
	
	var ast = null
	if lexer.diagnostics.is_empty():
		ast = parser.parse(tokens)

	result.tokens = tokens
	result.ast = ast
	result.diagnostics = lexer.diagnostics.duplicate()
	if parser:
		result.diagnostics.append_array(parser.diagnostics)
		
	result.success = result.diagnostics.size() == 0

	return result

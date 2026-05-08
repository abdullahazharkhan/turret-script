# Compiler — orchestrates the pipeline stages
extends RefCounted

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ParserScript = preload("res://scripts/compiler/parser.gd")
const SemanticScript = preload("res://scripts/compiler/semantic_analyzer.gd")
const ResultScript = preload("res://scripts/compiler/data/compiler_result.gd")

var lexer
var parser
var semantic_analyzer

func _init():
	lexer = LexerScript.new()
	parser = ParserScript.new()
	semantic_analyzer = SemanticScript.new()

func compile(source: String):
	var result = ResultScript.new()
	var tokens = lexer.tokenize(source)
	
	var ast = null
	var symbols = []
	if lexer.diagnostics.is_empty():
		ast = parser.parse(tokens)
		if parser.diagnostics.is_empty():
			symbols = semantic_analyzer.analyze(ast)

	result.tokens = tokens
	result.ast = ast
	result.symbols = symbols
	result.diagnostics = lexer.diagnostics.duplicate()
	if parser:
		result.diagnostics.append_array(parser.diagnostics)
	if semantic_analyzer:
		result.diagnostics.append_array(semantic_analyzer.diagnostics)
		
	result.success = result.diagnostics.size() == 0

	return result

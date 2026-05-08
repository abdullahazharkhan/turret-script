# Compiler — orchestrates the pipeline stages
extends RefCounted

const LexerScript = preload("res://scripts/compiler/lexer.gd")
const ResultScript = preload("res://scripts/compiler/data/compiler_result.gd")

var lexer

func _init():
	lexer = LexerScript.new()

func compile(source: String):
	var result = ResultScript.new()
	var tokens = lexer.tokenize(source)

	result.tokens = tokens
	result.diagnostics = lexer.diagnostics
	result.success = result.diagnostics.size() == 0

	return result

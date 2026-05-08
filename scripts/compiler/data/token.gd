# Token — no class_name to avoid resolver chains
extends RefCounted

const TT = preload("res://scripts/compiler/data/token_type.gd")

var type: int
var lexeme: String
var literal: Variant
var span # SourceSpan instance

func _init(t: int, lex: String, lit: Variant, s):
	type = t
	lexeme = lex
	literal = lit
	span = s

func as_string() -> String:
	return "[%s] '%s'" % [TT.token_name(type), lexeme]

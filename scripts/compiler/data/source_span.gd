# SourceSpan — no class_name to avoid resolver chains
extends RefCounted

var line: int
var column: int
var start_index: int
var end_index: int

func _init(l: int, c: int, start: int, end_idx: int):
	line = l
	column = c
	start_index = start
	end_index = end_idx

func as_string() -> String:
	return "L%d:C%d" % [line, column]

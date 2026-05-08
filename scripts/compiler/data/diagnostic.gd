# Diagnostic — no class_name to avoid resolver chains
extends RefCounted

const LVL_INFO = 0
const LVL_WARN = 1
const LVL_ERROR = 2

var level: int
var message: String
var span # SourceSpan instance

func _init(l: int, msg: String, s):
	level = l
	message = msg
	span = s

func as_string() -> String:
	var prefix = "Error" if level == LVL_ERROR else ("Warn" if level == LVL_WARN else "Info")
	return "%s: %s at %s" % [prefix, message, span.as_string()]

# CompilerResult — no class_name to avoid resolver chains
extends RefCounted

var success: bool = false
var tokens: Array = []
var diagnostics: Array = []
var ast
var symbols: Array = []
var ir

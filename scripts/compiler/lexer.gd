# Lexer — no class_name to avoid resolver chains
extends RefCounted

const TT = preload("res://scripts/compiler/data/token_type.gd")
const TokenScript = preload("res://scripts/compiler/data/token.gd")
const SpanScript = preload("res://scripts/compiler/data/source_span.gd")
const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")

var _source: String = ""
var _start: int = 0
var _current: int = 0
var _line: int = 1
var _column: int = 1
var _start_col: int = 1

var tokens: Array = []
var diagnostics: Array = []
var keywords: Dictionary = {}

func _init():
	keywords = {
		"if": TT.TK_IF, "else": TT.TK_ELSE,
		"while": TT.TK_WHILE, "for": TT.TK_FOR,
		"func": TT.TK_FUNC, "return": TT.TK_RETURN,
		"enemy": TT.TK_TYPE_ENEMY, "in": TT.TK_IN,
		"int": TT.TK_TYPE_INT, "bool": TT.TK_TYPE_BOOL,
		"string": TT.TK_TYPE_STRING, "void": TT.TK_TYPE_VOID,
		"var": TT.TK_VAR, "null": TT.TK_NULL_LITERAL,
		"get_enemies": TT.TK_GET_ENEMIES, "nearest": TT.TK_NEAREST,
		"distance": TT.TK_DISTANCE, "shoot": TT.TK_SHOOT,
		"reload": TT.TK_RELOAD
	}

func tokenize(source: String) -> Array:
	_source = source
	_start = 0
	_current = 0
	_line = 1
	_column = 1
	tokens.clear()
	diagnostics.clear()

	while not _is_at_end():
		_start = _current
		_start_col = _column
		_scan_token()

	tokens.append(TokenScript.new(TT.TK_EOF, "", null, SpanScript.new(_line, _column, _current, _current)))
	return tokens

func _is_at_end() -> bool:
	return _current >= _source.length()

func _advance() -> String:
	var c = _source[_current]
	_current += 1
	_column += 1
	return c

func _peek() -> String:
	if _is_at_end():
		return ""
	return _source[_current]

func _peek_next() -> String:
	if _current + 1 >= _source.length():
		return ""
	return _source[_current + 1]

func _match(expected: String) -> bool:
	if _is_at_end() or _source[_current] != expected:
		return false
	_current += 1
	_column += 1
	return true

func _add_token(type: int, literal: Variant = null):
	var text = _source.substr(_start, _current - _start)
	var span = SpanScript.new(_line, _start_col, _start, _current)
	tokens.append(TokenScript.new(type, text, literal, span))

func _report_error(msg: String):
	var span = SpanScript.new(_line, _start_col, _start, _current)
	diagnostics.append(DiagScript.new(DiagScript.LVL_ERROR, msg, span))

func _scan_token():
	var c = _advance()
	match c:
		" ", "\r", "\t":
			pass
		"\n":
			_line += 1
			_column = 1
		"(":
			_add_token(TT.TK_LPAREN)
		")":
			_add_token(TT.TK_RPAREN)
		"{":
			_add_token(TT.TK_LBRACE)
		"}":
			_add_token(TT.TK_RBRACE)
		",":
			_add_token(TT.TK_COMMA)
		";":
			_add_token(TT.TK_SEMICOLON)
		".":
			_add_token(TT.TK_DOT)
		"+":
			_add_token(TT.TK_PLUS)
		"-":
			if _match(">"):
				_add_token(TT.TK_ARROW)
			else:
				_add_token(TT.TK_MINUS)
		"*":
			_add_token(TT.TK_STAR)
		"/":
			if _match("/"):
				while _peek() != "\n" and not _is_at_end():
					_advance()
			else:
				_add_token(TT.TK_SLASH)
		"=":
			if _match("="):
				_add_token(TT.TK_EQ)
			else:
				_add_token(TT.TK_ASSIGN)
		"!":
			if _match("="):
				_add_token(TT.TK_NEQ)
			else:
				_add_token(TT.TK_NOT)
		"<":
			if _match("="):
				_add_token(TT.TK_LTE)
			else:
				_add_token(TT.TK_LT)
		">":
			if _match("="):
				_add_token(TT.TK_GTE)
			else:
				_add_token(TT.TK_GT)
		"&":
			if _match("&"):
				_add_token(TT.TK_AND)
			else:
				_report_error("Unexpected character '&'. Did you mean '&&'?")
		"|":
			if _match("|"):
				_add_token(TT.TK_OR)
			else:
				_report_error("Unexpected character '|'. Did you mean '||'?")
		"\"":
			_string()
		_:
			if _is_digit(c):
				_number()
			elif _is_alpha(c):
				_identifier()
			else:
				_report_error("Unexpected character '%s'." % c)

func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"

func _is_alpha(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"

func _is_alphanumeric(c: String) -> bool:
	return _is_alpha(c) or _is_digit(c)

func _string():
	while _peek() != "\"" and not _is_at_end():
		if _peek() == "\n":
			_line += 1
			_column = 1
		_advance()

	if _is_at_end():
		_report_error("Unterminated string.")
		return

	_advance() # closing quote
	var value = _source.substr(_start + 1, _current - _start - 2)
	_add_token(TT.TK_STRING_LITERAL, value)

func _number():
	while _is_digit(_peek()):
		_advance()

	var value_str = _source.substr(_start, _current - _start)
	_add_token(TT.TK_INT_LITERAL, int(value_str))

func _identifier():
	while _is_alphanumeric(_peek()):
		_advance()

	var text = _source.substr(_start, _current - _start)
	if text == "true":
		_add_token(TT.TK_BOOL_LITERAL, true)
	elif text == "false":
		_add_token(TT.TK_BOOL_LITERAL, false)
	elif keywords.has(text):
		_add_token(keywords[text])
	else:
		_add_token(TT.TK_IDENTIFIER, text)

# Token type constants — no class_name, loaded via preload()
# This avoids Godot 4 class resolver issues with enums inside class_name scripts.

const TK_EOF = 0
const TK_ERROR = 1
const TK_IDENTIFIER = 2
const TK_INT_LITERAL = 3
const TK_STRING_LITERAL = 4
const TK_BOOL_LITERAL = 5
const TK_NULL_LITERAL = 6

const TK_IF = 10
const TK_ELSE = 11
const TK_WHILE = 12
const TK_FOR = 13
const TK_FUNC = 14
const TK_RETURN = 15
const TK_ENEMY = 16
const TK_IN = 17

const TK_TYPE_INT = 20
const TK_TYPE_BOOL = 21
const TK_TYPE_STRING = 22
const TK_TYPE_ENEMY = 23
const TK_TYPE_VOID = 24
const TK_VAR = 25

const TK_GET_ENEMIES = 30
const TK_NEAREST = 31
const TK_DISTANCE = 32
const TK_SHOOT = 33
const TK_RELOAD = 34

const TK_LPAREN = 40
const TK_RPAREN = 41
const TK_LBRACE = 42
const TK_RBRACE = 43
const TK_COMMA = 44
const TK_SEMICOLON = 45
const TK_DOT = 46

const TK_ASSIGN = 50
const TK_PLUS = 51
const TK_MINUS = 52
const TK_STAR = 53
const TK_SLASH = 54

const TK_EQ = 60
const TK_NEQ = 61
const TK_LT = 62
const TK_LTE = 63
const TK_GT = 64
const TK_GTE = 65
const TK_AND = 66
const TK_OR = 67
const TK_NOT = 68
const TK_ARROW = 69

const _NAMES = {
	TK_EOF: "EOF", TK_ERROR: "ERROR", TK_IDENTIFIER: "IDENTIFIER",
	TK_INT_LITERAL: "INT_LITERAL", TK_STRING_LITERAL: "STRING_LITERAL",
	TK_BOOL_LITERAL: "BOOL_LITERAL", TK_NULL_LITERAL: "NULL_LITERAL",
	TK_IF: "IF", TK_ELSE: "ELSE", TK_WHILE: "WHILE", TK_FOR: "FOR",
	TK_FUNC: "FUNC", TK_RETURN: "RETURN", TK_ENEMY: "ENEMY", TK_IN: "IN",
	TK_TYPE_INT: "TYPE_INT", TK_TYPE_BOOL: "TYPE_BOOL",
	TK_TYPE_STRING: "TYPE_STRING", TK_TYPE_ENEMY: "TYPE_ENEMY",
	TK_TYPE_VOID: "TYPE_VOID", TK_VAR: "VAR",
	TK_GET_ENEMIES: "GET_ENEMIES", TK_NEAREST: "NEAREST",
	TK_DISTANCE: "DISTANCE", TK_SHOOT: "SHOOT", TK_RELOAD: "RELOAD",
	TK_LPAREN: "LPAREN", TK_RPAREN: "RPAREN",
	TK_LBRACE: "LBRACE", TK_RBRACE: "RBRACE",
	TK_COMMA: "COMMA", TK_SEMICOLON: "SEMICOLON", TK_DOT: "DOT",
	TK_ASSIGN: "ASSIGN", TK_PLUS: "PLUS", TK_MINUS: "MINUS",
	TK_STAR: "STAR", TK_SLASH: "SLASH",
	TK_EQ: "EQ", TK_NEQ: "NEQ", TK_LT: "LT", TK_LTE: "LTE",
	TK_GT: "GT", TK_GTE: "GTE", TK_AND: "AND", TK_OR: "OR",
	TK_NOT: "NOT", TK_ARROW: "ARROW",
}

static func token_name(type: int) -> String:
	if _NAMES.has(type):
		return _NAMES[type]
	return "UNKNOWN(%d)" % type

extends PanelContainer

const TT = preload("res://scripts/compiler/data/token_type.gd")
const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")
const RuntimeContext = preload("res://scripts/runtime/data/runtime_context.gd")

# Stage indices
const STAGE_NONE     = -1
const STAGE_LEXER    = 0
const STAGE_PARSER   = 1
const STAGE_SEMANTIC = 2
const STAGE_IR       = 3
const STAGE_RUNTIME  = 4

# Colours
const COL_PENDING = Color(0.45, 0.45, 0.45)
const COL_RUNNING = Color(1.0,  0.80, 0.0)
const COL_OK      = Color(0.2,  0.85, 0.4)
const COL_ERROR   = Color(0.95, 0.25, 0.25)

# Token category colours
const COL_TOK_KEYWORD  = Color(1.0,  0.48, 0.45)
const COL_TOK_TYPE     = Color(1.0,  0.80, 0.0)
const COL_TOK_LITERAL  = Color(0.40, 0.85, 1.0)
const COL_TOK_API      = Color(0.80, 0.65, 1.0)
const COL_TOK_OP       = Color(0.80, 0.80, 0.80)
const COL_TOK_DEFAULT  = Color(0.9,  0.9,  0.9)

# Node refs
@onready var tabs         = $VBox/Tabs
@onready var lexer_chip   = $VBox/StageBar/LexerChip
@onready var parser_chip  = $VBox/StageBar/ParserChip
@onready var semantic_chip= $VBox/StageBar/SemanticChip
@onready var ir_chip      = $VBox/StageBar/IRChip
@onready var runtime_chip = $VBox/StageBar/RuntimeChip

@onready var token_list   = $VBox/Tabs/Lexer/TokenList
@onready var ast_tree     = $VBox/Tabs/Parser_AST/ASTTree
@onready var symbol_tree  = $VBox/Tabs/Semantic/SemanticSplit/SymbolTree
@onready var diag_list    = $VBox/Tabs/Semantic/SemanticSplit/DiagList
@onready var ir_list      = $VBox/Tabs/IR/IRList
@onready var runtime_state= $VBox/Tabs/Runtime/RuntimeSplit/RuntimeState
@onready var api_log      = $VBox/Tabs/Runtime/RuntimeSplit/APILog

var _chips: Array

func _ready():
	_chips = [lexer_chip, parser_chip, semantic_chip, ir_chip, runtime_chip]
	
	# Set column titles for Token list
	token_list.set_column_title(0, "Type")
	token_list.set_column_title(1, "Lexeme")
	token_list.set_column_title(2, "Line")
	token_list.set_column_title(3, "Col")
	token_list.set_column_expand(0, true)
	token_list.set_column_expand(1, true)
	token_list.set_column_expand_ratio(0, 1.5)
	token_list.set_column_expand_ratio(1, 2)
	token_list.set_column_expand_ratio(2, 0.5)
	token_list.set_column_expand_ratio(3, 0.5)
	
	# Semantic symbol tree columns
	symbol_tree.set_column_title(0, "Name")
	symbol_tree.set_column_title(1, "Type")
	symbol_tree.set_column_title(2, "Scope")
	symbol_tree.set_column_expand(0, true)
	symbol_tree.set_column_expand(1, true)
	symbol_tree.set_column_expand_ratio(0, 2)
	symbol_tree.set_column_expand_ratio(1, 2)
	symbol_tree.set_column_expand_ratio(2, 1)
	
	# Runtime state tree columns
	runtime_state.set_column_title(0, "Key")
	runtime_state.set_column_title(1, "Value")
	runtime_state.set_column_expand(0, true)
	runtime_state.set_column_expand(1, true)
	
	# Wire chip clicks → tab change
	lexer_chip.pressed.connect(func(): tabs.current_tab = 0)
	parser_chip.pressed.connect(func(): tabs.current_tab = 1)
	semantic_chip.pressed.connect(func(): tabs.current_tab = 2)
	ir_chip.pressed.connect(func(): tabs.current_tab = 3)
	runtime_chip.pressed.connect(func(): tabs.current_tab = 4)
	
	reset_all()

func reset_all():
	for i in range(_chips.size()):
		_set_chip(i, "pending", "")
	token_list.clear()
	ast_tree.clear()
	symbol_tree.clear()
	diag_list.clear()
	ir_list.clear()
	runtime_state.clear()
	api_log.clear()

# ─────────────────────────────────────────────
#  Stage chip helpers
# ─────────────────────────────────────────────
func _set_chip(stage: int, status: String, detail: String = ""):
	var chip = _chips[stage]
	var labels = ["① LEXER", "② PARSER", "③ SEMANTIC", "④ IR", "⑤ RUNTIME"]
	var suffix = (" · " + detail) if detail != "" else ""
	chip.text = labels[stage] + suffix
	match status:
		"pending": chip.add_theme_color_override("font_color", COL_PENDING)
		"running": chip.add_theme_color_override("font_color", COL_RUNNING)
		"ok":      chip.add_theme_color_override("font_color", COL_OK)
		"error":   chip.add_theme_color_override("font_color", COL_ERROR)

# ─────────────────────────────────────────────
#  LEXER tab
# ─────────────────────────────────────────────
func show_lexer(tokens: Array, diagnostics: Array):
	var errors = diagnostics.filter(func(d): return d.level == DiagScript.LVL_ERROR)
	
	token_list.clear()
	var root = token_list.create_item()
	root.set_text(0, "Tokens (%d)" % tokens.size())
	
	for tok in tokens:
		var item = token_list.create_item(root)
		var type_name = TT.token_name(tok.type)
		item.set_text(0, type_name)
		item.set_text(1, tok.lexeme)
		item.set_text(2, str(tok.span.line) if tok.span else "?")
		item.set_text(3, str(tok.span.column) if tok.span else "?")
		var col = _token_colour(tok.type)
		item.set_custom_color(0, col)
		item.set_custom_color(1, col)
	
	if errors.is_empty():
		_set_chip(STAGE_LEXER, "ok", "%d tokens" % tokens.size())
		tabs.current_tab = 0
	else:
		_set_chip(STAGE_LEXER, "error", "%d errors" % errors.size())
		tabs.current_tab = 0

func _token_colour(t_type: int) -> Color:
	match t_type:
		TT.TK_IF, TT.TK_ELSE, TT.TK_WHILE, TT.TK_FOR, TT.TK_FUNC, TT.TK_RETURN, TT.TK_IN:
			return COL_TOK_KEYWORD
		TT.TK_TYPE_INT, TT.TK_TYPE_BOOL, TT.TK_TYPE_STRING, TT.TK_TYPE_ENEMY, TT.TK_TYPE_VOID, TT.TK_VAR:
			return COL_TOK_TYPE
		TT.TK_INT_LITERAL, TT.TK_BOOL_LITERAL, TT.TK_STRING_LITERAL:
			return COL_TOK_LITERAL
		TT.TK_GET_ENEMIES, TT.TK_NEAREST, TT.TK_DISTANCE, TT.TK_SHOOT, TT.TK_RELOAD:
			return COL_TOK_API
	return COL_TOK_DEFAULT

# ─────────────────────────────────────────────
#  PARSER / AST tab
# ─────────────────────────────────────────────
func show_ast(ast_root, diagnostics: Array):
	var errors = diagnostics.filter(func(d): return d.level == DiagScript.LVL_ERROR)
	ast_tree.clear()
	
	if ast_root == null:
		_set_chip(STAGE_PARSER, "error", "no AST")
		return
	
	var root = ast_tree.create_item()
	root.set_text(0, "Program")
	_build_ast_tree(ast_root, root)
	
	if errors.is_empty():
		_set_chip(STAGE_PARSER, "ok", "parsed")
		tabs.current_tab = 1
	else:
		_set_chip(STAGE_PARSER, "error", "%d errors" % errors.size())
		tabs.current_tab = 1

func _build_ast_tree(node, parent: TreeItem):
	if node == null: return
	var item: TreeItem
	
	match node.type:
		"Program":
			for s in node.statements: _build_ast_tree(s, parent)
			return
		"VarDecl":
			item = ast_tree.create_item(parent)
			item.set_text(0, "🔷 VarDecl  %s : %s" % [node.identifier, node.type_name])
			item.set_custom_color(0, COL_TOK_TYPE)
			if node.initializer: _build_ast_tree(node.initializer, item)
		"Assignment":
			item = ast_tree.create_item(parent)
			item.set_text(0, "✏️ Assign  %s =" % node.identifier)
			if node.value: _build_ast_tree(node.value, item)
		"FunctionDecl":
			item = ast_tree.create_item(parent)
			var params = ", ".join(PackedStringArray(node.parameters.map(func(p): return p.type + " " + p.name)))
			item.set_text(0, "⚙️ func %s(%s) → %s" % [node.identifier, params, node.return_type])
			item.set_custom_color(0, COL_TOK_API)
			if node.body: _build_ast_tree(node.body, item)
		"Block":
			item = ast_tree.create_item(parent)
			item.set_text(0, "{ }")
			for s in node.statements: _build_ast_tree(s, item)
		"IfStmt":
			item = ast_tree.create_item(parent)
			item.set_text(0, "🔀 if")
			item.set_custom_color(0, COL_TOK_KEYWORD)
			var cond_item = ast_tree.create_item(item); cond_item.set_text(0, "condition")
			_build_ast_tree(node.condition, cond_item)
			var then_item = ast_tree.create_item(item); then_item.set_text(0, "then")
			_build_ast_tree(node.then_branch, then_item)
			if node.else_branch:
				var else_item = ast_tree.create_item(item); else_item.set_text(0, "else")
				_build_ast_tree(node.else_branch, else_item)
		"WhileStmt":
			item = ast_tree.create_item(parent)
			item.set_text(0, "🔁 while")
			item.set_custom_color(0, COL_TOK_KEYWORD)
			var cond_item = ast_tree.create_item(item); cond_item.set_text(0, "condition")
			_build_ast_tree(node.condition, cond_item)
			var body_item = ast_tree.create_item(item); body_item.set_text(0, "body")
			_build_ast_tree(node.body, body_item)
		"ForEnemyStmt":
			item = ast_tree.create_item(parent)
			item.set_text(0, "🎯 for enemy %s" % node.identifier)
			item.set_custom_color(0, COL_TOK_KEYWORD)
			if node.body: _build_ast_tree(node.body, item)
		"ReturnStmt":
			item = ast_tree.create_item(parent)
			item.set_text(0, "↩️ return")
			item.set_custom_color(0, COL_TOK_KEYWORD)
			if node.value: _build_ast_tree(node.value, item)
		"ExprStmt":
			_build_ast_tree(node.expression, parent)
			return
		"BinaryExpr":
			item = ast_tree.create_item(parent)
			item.set_text(0, "BinOp  %s" % TT.token_name(node.operator))
			item.set_custom_color(0, COL_TOK_OP)
			if node.left: _build_ast_tree(node.left, item)
			if node.right: _build_ast_tree(node.right, item)
		"UnaryExpr":
			item = ast_tree.create_item(parent)
			item.set_text(0, "UnaryOp  %s" % TT.token_name(node.operator))
			if node.right: _build_ast_tree(node.right, item)
		"LiteralExpr":
			item = ast_tree.create_item(parent)
			item.set_text(0, "🔢 %s" % str(node.value))
			item.set_custom_color(0, COL_TOK_LITERAL)
		"IdentifierExpr":
			item = ast_tree.create_item(parent)
			item.set_text(0, "📌 %s" % node.identifier)
		"CallExpr":
			item = ast_tree.create_item(parent)
			item.set_text(0, "📞 %s()" % node.callee)
			item.set_custom_color(0, COL_TOK_API)
			for arg in node.arguments: _build_ast_tree(arg, item)
		"MemberAccessExpr":
			item = ast_tree.create_item(parent)
			item.set_text(0, ".%s" % node.member)
			if node.object: _build_ast_tree(node.object, item)

# ─────────────────────────────────────────────
#  SEMANTIC tab
# ─────────────────────────────────────────────
func show_semantic(symbols: Array, diagnostics: Array):
	var errors = diagnostics.filter(func(d): return d.level == DiagScript.LVL_ERROR)
	symbol_tree.clear()
	diag_list.clear()
	
	var root = symbol_tree.create_item()
	root.set_text(0, "Symbols"); root.set_text(1, ""); root.set_text(2, "")
	
	for sym in symbols:
		var item = symbol_tree.create_item(root)
		item.set_text(0, sym.name)
		var t_str = ""
		if typeof(sym.type_info) == TYPE_STRING:
			t_str = sym.type_info
		else:
			var ft = sym.type_info
			t_str = "func(%s)→%s" % [", ".join(PackedStringArray(ft.parameters)), ft.return_type]
		item.set_text(1, t_str)
		item.set_text(2, "depth %d" % sym.scope_depth)
		var col = COL_TOK_API if "func" in t_str else COL_TOK_TYPE
		item.set_custom_color(0, col)
		item.set_custom_color(1, col)
	
	for d in diagnostics:
		var color_str = "red" if d.level == DiagScript.LVL_ERROR else "orange"
		diag_list.add_item(d.as_string())
		var idx = diag_list.item_count - 1
		diag_list.set_item_custom_fg_color(idx, COL_ERROR if d.level == DiagScript.LVL_ERROR else COL_RUNNING)
	
	if errors.is_empty():
		_set_chip(STAGE_SEMANTIC, "ok", "%d symbols" % symbols.size())
		tabs.current_tab = 2
	else:
		_set_chip(STAGE_SEMANTIC, "error", "%d errors" % errors.size())
		tabs.current_tab = 2

# ─────────────────────────────────────────────
#  IR tab
# ─────────────────────────────────────────────
func show_ir(ir_program, diagnostics: Array):
	ir_list.clear()
	
	if ir_program == null:
		_set_chip(STAGE_IR, "error", "no IR")
		return
	
	for i in range(ir_program.instructions.size()):
		var inst = ir_program.instructions[i]
		var text = "[%03d]  %s" % [i, inst.as_string()]
		ir_list.add_item(text)
	
	# Label function boundaries
	for fn_name in ir_program.functions:
		var idx = ir_program.functions[fn_name]
		if idx < ir_list.item_count:
			ir_list.set_item_custom_fg_color(idx, COL_TOK_API)
	
	_set_chip(STAGE_IR, "ok", "%d instructions" % ir_program.instructions.size())
	tabs.current_tab = 3

func highlight_ir_instruction(ip: int):
	for i in range(ir_list.item_count):
		if i == ip:
			ir_list.set_item_custom_fg_color(i, COL_RUNNING)
			ir_list.ensure_current_is_visible()
			ir_list.select(i)
		else:
			var inst = null
			# Check if this is a function boundary  
			var col = COL_TOK_DEFAULT
			ir_list.set_item_custom_fg_color(i, col)

# ─────────────────────────────────────────────
#  RUNTIME tab
# ─────────────────────────────────────────────
func show_runtime_start():
	api_log.clear()
	runtime_state.clear()
	_set_chip(STAGE_RUNTIME, "running", "executing")
	tabs.current_tab = 4

func update_runtime_state(vm):
	var ctx = vm.context
	runtime_state.clear()
	
	# State row
	var state_names = ["READY", "RUNNING", "PAUSED", "HALTED", "ERROR"]
	var r_state = state_names[ctx.state] if ctx.state < state_names.size() else "?"
	var state_item = runtime_state.create_item()
	state_item.set_text(0, "State")
	state_item.set_text(1, r_state)
	var sc = COL_OK if ctx.state == 3 else (COL_ERROR if ctx.state == 4 else COL_RUNNING)
	state_item.set_custom_color(1, sc)
	
	# IP
	var ip_item = runtime_state.create_item()
	ip_item.set_text(0, "IP")
	ip_item.set_text(1, str(ctx.ip))
	
	# Stack
	var stack_root = runtime_state.create_item()
	stack_root.set_text(0, "Stack (%d)" % ctx.stack.size())
	stack_root.set_text(1, "")
	for i in range(ctx.stack.size() - 1, -1, -1):
		var si = runtime_state.create_item(stack_root)
		si.set_text(0, "[%d]" % i)
		si.set_text(1, str(ctx.stack[i]))
	
	# Call stack frames
	var cs_root = runtime_state.create_item()
	cs_root.set_text(0, "Call Stack (%d)" % ctx.call_stack.size())
	for f_idx in range(ctx.call_stack.size() - 1, -1, -1):
		var frame = ctx.call_stack[f_idx]
		var f_item = runtime_state.create_item(cs_root)
		f_item.set_text(0, "Frame %d" % f_idx)
		f_item.set_text(1, "ret→%s" % str(frame.get("ip", "?")))
		var locals = frame.get("local_vars", [])
		for li in range(locals.size()):
			var l_item = runtime_state.create_item(f_item)
			l_item.set_text(0, "  var[%d]" % li)
			l_item.set_text(1, str(locals[li]))
	
	if ctx.state == 3: # HALTED
		_set_chip(STAGE_RUNTIME, "ok", "finished")
	elif ctx.state == 4: # ERROR
		_set_chip(STAGE_RUNTIME, "error", ctx.error_message.left(30))

func log_runtime(msg: String, is_error: bool = false):
	if is_error:
		api_log.append_text("[color=#f44]" + msg + "[/color]\n")
	else:
		api_log.append_text("[color=#aef]" + msg + "[/color]\n")
	tabs.current_tab = 4

# ─────────────────────────────────────────────
#  Diagnostics helper (shared across stages)
# ─────────────────────────────────────────────
func mark_stage_pending(stage: int):
	_set_chip(stage, "pending", "")

func mark_stage_running(stage: int):
	_set_chip(stage, "running", "...")

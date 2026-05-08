extends Node

const CompilerScript = preload("res://scripts/compiler/compiler.gd")
const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")
const TT = preload("res://scripts/compiler/data/token_type.gd")

@onready var ide_panel = $CanvasLayer/HSplitContainer/UIVSplit/IDEPanel
@onready var pipeline_panel = $CanvasLayer/HSplitContainer/UIVSplit/CompilerPipelinePanel
@onready var game_world = $GameWorld

var compiler

func _ready():
	compiler = CompilerScript.new()
	ide_panel.compile_requested.connect(_on_compile_requested)

func _on_compile_requested(source: String):
	var result = compiler.compile(source)
	ide_panel.show_diagnostics(result.diagnostics)
	_update_pipeline_ui(result)

func _update_pipeline_ui(result):
	var lexer_list = pipeline_panel.get_node("Lexer") as ItemList
	lexer_list.clear()
	for token in result.tokens:
		lexer_list.add_item(token.as_string())
		
	var ast_tree = pipeline_panel.get_node("Parser_AST") as Tree
	ast_tree.clear()
	if result.ast != null:
		var root = ast_tree.create_item()
		root.set_text(0, "Program")
		_build_ast_tree(result.ast, root, ast_tree)
		
	var symbol_tree = pipeline_panel.get_node("Symbol Table") as Tree
	symbol_tree.clear()
	var root_sym = symbol_tree.create_item()
	root_sym.set_text(0, "Global Scope")
	for sym in result.symbols:
		var item = symbol_tree.create_item(root_sym)
		item.set_text(0, sym.as_string())

func _build_ast_tree(ast_node, tree_parent: TreeItem, tree: Tree):
	if ast_node == null: return
	
	match ast_node.type:
		"Program":
			for stmt in ast_node.statements:
				_build_ast_tree(stmt, tree_parent, tree)
		"VarDecl":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "VarDecl: %s %s" % [ast_node.type_name, ast_node.identifier])
			if ast_node.initializer:
				_build_ast_tree(ast_node.initializer, item, tree)
		"Assignment":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "Assignment: %s =" % ast_node.identifier)
			if ast_node.value: _build_ast_tree(ast_node.value, item, tree)
		"FunctionDecl":
			var item = tree.create_item(tree_parent)
			var params = ""
			for p in ast_node.parameters:
				params += "%s %s, " % [p.type, p.name]
			item.set_text(0, "FuncDecl: %s(%s) -> %s" % [ast_node.identifier, params, ast_node.return_type])
			if ast_node.body: _build_ast_tree(ast_node.body, item, tree)
		"Block":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "Block")
			for stmt in ast_node.statements: _build_ast_tree(stmt, item, tree)
		"IfStmt":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "IfStmt")
			var cond = tree.create_item(item); cond.set_text(0, "Condition"); _build_ast_tree(ast_node.condition, cond, tree)
			var then_b = tree.create_item(item); then_b.set_text(0, "Then"); _build_ast_tree(ast_node.then_branch, then_b, tree)
			if ast_node.else_branch:
				var else_b = tree.create_item(item); else_b.set_text(0, "Else"); _build_ast_tree(ast_node.else_branch, else_b, tree)
		"WhileStmt":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "WhileStmt")
			var cond = tree.create_item(item); cond.set_text(0, "Condition"); _build_ast_tree(ast_node.condition, cond, tree)
			var body = tree.create_item(item); body.set_text(0, "Body"); _build_ast_tree(ast_node.body, body, tree)
		"ForEnemyStmt":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "ForEnemyStmt: %s" % ast_node.identifier)
			if ast_node.body: _build_ast_tree(ast_node.body, item, tree)
		"ReturnStmt":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "ReturnStmt")
			if ast_node.value: _build_ast_tree(ast_node.value, item, tree)
		"ExprStmt":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "ExprStmt")
			if ast_node.expression: _build_ast_tree(ast_node.expression, item, tree)
		"BinaryExpr":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "BinaryExpr: %s" % TT.token_name(ast_node.operator))
			if ast_node.left: _build_ast_tree(ast_node.left, item, tree)
			if ast_node.right: _build_ast_tree(ast_node.right, item, tree)
		"UnaryExpr":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "UnaryExpr: %s" % TT.token_name(ast_node.operator))
			if ast_node.right: _build_ast_tree(ast_node.right, item, tree)
		"LiteralExpr":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "Literal: %s" % str(ast_node.value))
		"IdentifierExpr":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "Identifier: %s" % ast_node.identifier)
		"CallExpr":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "Call: %s()" % ast_node.callee)
			for arg in ast_node.arguments: _build_ast_tree(arg, item, tree)
		"MemberAccessExpr":
			var item = tree.create_item(tree_parent)
			item.set_text(0, "MemberAccess: .%s" % ast_node.member)
			if ast_node.object: _build_ast_tree(ast_node.object, item, tree)

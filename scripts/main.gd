extends Node

const CompilerScript = preload("res://scripts/compiler/compiler.gd")
const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")

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

extends PanelContainer

signal compile_requested(source_code)

const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")

@onready var compile_btn = $VBoxContainer/Toolbar/CompileButton
@onready var run_btn = $VBoxContainer/Toolbar/RunButton
@onready var step_btn = $VBoxContainer/Toolbar/StepStageButton
@onready var reset_btn = $VBoxContainer/Toolbar/ResetButton
@onready var editor = $VBoxContainer/CodeEditor
@onready var line_col_label = $VBoxContainer/StatusBar/LineColLabel
@onready var diagnostics = $VBoxContainer/DiagnosticsPanel

func _ready():
	compile_btn.pressed.connect(_on_compile_pressed)
	run_btn.pressed.connect(_on_run_pressed)
	step_btn.pressed.connect(_on_step_stage_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)

	editor.caret_changed.connect(_on_caret_changed)
	_setup_syntax_highlighting()
	_on_caret_changed()

func _setup_syntax_highlighting():
	var highlighter = CodeHighlighter.new()

	var keyword_color = Color("#ff7b72")
	var type_color = Color("#ffcc00")
	var string_color = Color("#a5d6ff")
	var comment_color = Color("#8b949e")
	var api_color = Color("#d2a8ff")

	highlighter.add_color_region("\"", "\"", string_color)
	highlighter.add_color_region("//", "", comment_color)

	for kw in ["if", "else", "while", "for", "func", "return", "in", "true", "false"]:
		highlighter.add_keyword_color(kw, keyword_color)

	for type in ["int", "bool", "string", "enemy", "void"]:
		highlighter.add_keyword_color(type, type_color)

	for api in ["get_enemies", "nearest", "distance", "shoot", "reload"]:
		highlighter.add_keyword_color(api, api_color)

	editor.syntax_highlighter = highlighter

func _on_caret_changed():
	var line = editor.get_caret_line() + 1
	var col = editor.get_caret_column() + 1
	line_col_label.text = "Line: %d, Col: %d" % [line, col]

func _on_compile_pressed():
	print("Compile button pressed")
	compile_requested.emit(editor.text)

func _on_run_pressed():
	print("Run button pressed")

func _on_step_stage_pressed():
	print("Step Stage button pressed")

func _on_reset_pressed():
	print("Reset button pressed")

func show_diagnostics(diagnostics_list: Array):
	if diagnostics_list.is_empty():
		diagnostics.text = "[color=green]Compile successful. No errors.[/color]"
	else:
		diagnostics.text = ""
		for d in diagnostics_list:
			var color = "red" if d.level == DiagScript.LVL_ERROR else "orange"
			diagnostics.text += "[color=%s]%s[/color]\n" % [color, d.as_string()]

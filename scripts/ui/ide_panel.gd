extends PanelContainer

signal compile_requested(source_code)
signal run_requested()
signal step_requested()
signal reset_requested()

const DiagScript = preload("res://scripts/compiler/data/diagnostic.gd")

@onready var compile_btn = $VBoxContainer/Toolbar/CompileButton
@onready var run_btn = $VBoxContainer/Toolbar/RunButton
@onready var step_btn = $VBoxContainer/Toolbar/StepStageButton
@onready var reset_btn = $VBoxContainer/Toolbar/ResetButton
@onready var examples_opt = $VBoxContainer/Toolbar/ExamplesOption
@onready var save_btn = $VBoxContainer/Toolbar/SaveButton
@onready var load_btn = $VBoxContainer/Toolbar/LoadButton
@onready var help_btn = $VBoxContainer/Toolbar/HelpButton

@onready var editor = $VBoxContainer/CodeEditor
@onready var line_col_label = $VBoxContainer/StatusBar/LineColLabel
@onready var diagnostics = $VBoxContainer/DiagnosticsPanel
@onready var help_dialog = $HelpDialog

const SAVE_PATH = "user://turret_script_save.txt"

var EXAMPLES = [
	{ "name": "1. Nearest Enemy (Default)", "code": "func main() {\n\tvar enemies = get_enemies();\n\tvar target = nearest(enemies);\n\tif (distance(target) < 200) {\n\t\tshoot(target);\n\t}\n}" },
	{ "name": "2. Low-Health Priority", "code": "func main() {\n\tvar enemies = get_enemies();\n\tif (_array_size(enemies) == 0) { return; }\n\n\tvar best = _array_get(enemies, 0);\n\tfor enemy e in enemies {\n\t\tif (e.health < best.health) {\n\t\t\tbest = e;\n\t\t}\n\t}\n\n\tif (distance(best) < 200) {\n\t\tshoot(best);\n\t}\n}" },
	{ "name": "3. Armor-Piercing (Tank Focus)", "code": "func main() {\n\tvar enemies = get_enemies();\n\tfor enemy e in enemies {\n\t\tif (e.type == \"tank\" and distance(e) < 200) {\n\t\t\tshoot(e);\n\t\t\treturn;\n\t\t}\n\t}\n\n\t// Fallback to nearest\n\tvar target = nearest(enemies);\n\tif (distance(target) < 200) {\n\t\tshoot(target);\n\t}\n}" },
	{ "name": "4. Reload Management", "code": "// Assumes ammo tracking via properties if added, or just periodic reload\nfunc main() {\n\tvar enemies = get_enemies();\n\tvar target = nearest(enemies);\n\t\n\tif (distance(target) > 250) {\n\t\treload(); // Reload while waiting\n\t} else {\n\t\tshoot(target);\n\t}\n}" },
	{ "name": "5. Type Error (Intentionally Invalid)", "code": "func main() {\n\tint threshold = \"not a number\"; // Type mismatch error!\n\tvar enemies = get_enemies();\n\t\n\tif (distance(enemies) < threshold) { // 'distance' expects single enemy\n\t\tshoot(enemies);\n\t}\n}" }
]

func _ready():
	compile_btn.pressed.connect(_on_compile_pressed)
	run_btn.pressed.connect(_on_run_pressed)
	step_btn.pressed.connect(_on_step_stage_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	help_btn.pressed.connect(func(): help_dialog.popup_centered())
	
	examples_opt.add_item("Load Example...")
	for i in range(EXAMPLES.size()):
		examples_opt.add_item(EXAMPLES[i].name)
	examples_opt.item_selected.connect(_on_example_selected)

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
	run_requested.emit()

func _on_step_stage_pressed():
	print("Step Stage button pressed")
	step_requested.emit()

func _on_reset_pressed():
	print("Reset button pressed")
	reset_requested.emit()

func _on_save_pressed():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(editor.text)
		file.close()
		diagnostics.text = "[color=green]Script saved successfully to user://[/color]"
		
func _on_load_pressed():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			editor.text = file.get_as_text()
			file.close()
			diagnostics.text = "[color=green]Script loaded successfully.[/color]"

func _on_example_selected(index: int):
	if index > 0 and index - 1 < EXAMPLES.size():
		editor.text = EXAMPLES[index - 1].code
	examples_opt.select(0)

func show_diagnostics(diagnostics_list: Array):
	if diagnostics_list.is_empty():
		diagnostics.text = "[color=green]Compile successful. No errors.[/color]"
	else:
		diagnostics.text = ""
		for d in diagnostics_list:
			var color = "red" if d.level == DiagScript.LVL_ERROR else "orange"
			diagnostics.text += "[color=%s]%s[/color]\n" % [color, d.as_string()]

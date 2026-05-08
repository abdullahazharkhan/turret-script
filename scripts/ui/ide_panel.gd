extends PanelContainer

func _ready():
	$VBoxContainer/Toolbar/CompileButton.pressed.connect(_on_compile_pressed)
	$VBoxContainer/Toolbar/RunButton.pressed.connect(_on_run_pressed)
	$VBoxContainer/Toolbar/StepStageButton.pressed.connect(_on_step_stage_pressed)
	$VBoxContainer/Toolbar/ResetButton.pressed.connect(_on_reset_pressed)

func _on_compile_pressed():
	print("Compile button pressed")

func _on_run_pressed():
	print("Run button pressed")

func _on_step_stage_pressed():
	print("Step Stage button pressed")

func _on_reset_pressed():
	print("Reset button pressed")

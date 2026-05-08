extends Node

const CompilerScript   = preload("res://scripts/compiler/compiler.gd")
const LexerScript      = preload("res://scripts/compiler/lexer.gd")
const ParserScript     = preload("res://scripts/compiler/parser.gd")
const SemanticScript   = preload("res://scripts/compiler/semantic_analyzer.gd")
const IRBuilderScript  = preload("res://scripts/compiler/ir/ir_builder.gd")
const TurretScriptVM   = preload("res://scripts/runtime/turretscript_vm.gd")
const APIAdapter       = preload("res://scripts/runtime/turret_api_adapter.gd")
const DiagScript       = preload("res://scripts/compiler/data/diagnostic.gd")
const TT               = preload("res://scripts/compiler/data/token_type.gd")

@onready var ide_panel      = $CanvasLayer/HSplitContainer/UIVSplit/IDEPanel
@onready var pipeline_panel = $CanvasLayer/HSplitContainer/UIVSplit/CompilerPipelinePanel
@onready var game_world     = $GameWorld

# Pipeline stages
const STAGE_NONE     = -1
const STAGE_LEXER    = 0
const STAGE_PARSER   = 1
const STAGE_SEMANTIC = 2
const STAGE_IR       = 3
const STAGE_RUNTIME  = 4

var _stage: int = STAGE_NONE

# Individual pipeline components (for step mode)
var _lexer
var _parser
var _semantic
var _ir_builder

# Intermediate results
var _tokens: Array = []
var _ast = null
var _symbols: Array = []
var _ir = null
var _diagnostics: Array = []
var _vm: TurretScriptVM = null

func _ready():
	_lexer     = LexerScript.new()
	_parser    = ParserScript.new()
	_semantic  = SemanticScript.new()
	_ir_builder = IRBuilderScript.new()
	
	ide_panel.compile_requested.connect(_on_compile_requested)
	ide_panel.run_requested.connect(_on_run_requested)
	ide_panel.step_requested.connect(_on_step_requested)
	ide_panel.reset_requested.connect(_on_reset_requested)
	
	if game_world:
		game_world.vm_log.connect(_on_vm_log)
		game_world.vm_error.connect(_on_vm_error)

# ─────────────────────────────────────────────
#  Full compile (Compile button)
# ─────────────────────────────────────────────
func _on_compile_requested(source: String):
	_reset_pipeline()
	pipeline_panel.reset_all()
	
	# ── Stage 1: Lexer ──
	pipeline_panel.mark_stage_running(STAGE_LEXER)
	_tokens = _lexer.tokenize(source)
	_diagnostics = _lexer.diagnostics.duplicate()
	pipeline_panel.show_lexer(_tokens, _diagnostics)
	ide_panel.show_diagnostics(_diagnostics)
	
	if not _lexer.diagnostics.is_empty():
		_stage = STAGE_LEXER
		return
	_stage = STAGE_LEXER
	
	# ── Stage 2: Parser ──
	pipeline_panel.mark_stage_running(STAGE_PARSER)
	_ast = _parser.parse(_tokens)
	var parser_diags = _parser.diagnostics.duplicate()
	_diagnostics.append_array(parser_diags)
	pipeline_panel.show_ast(_ast, parser_diags)
	ide_panel.show_diagnostics(_diagnostics)
	
	if not parser_diags.is_empty():
		_stage = STAGE_PARSER
		return
	_stage = STAGE_PARSER
	
	# ── Stage 3: Semantic ──
	pipeline_panel.mark_stage_running(STAGE_SEMANTIC)
	_symbols = _semantic.analyze(_ast)
	var sem_diags = _semantic.diagnostics.duplicate()
	_diagnostics.append_array(sem_diags)
	pipeline_panel.show_semantic(_symbols, _diagnostics)
	ide_panel.show_diagnostics(_diagnostics)
	
	if not sem_diags.is_empty():
		_stage = STAGE_SEMANTIC
		return
	_stage = STAGE_SEMANTIC
	
	# ── Stage 4: IR ──
	pipeline_panel.mark_stage_running(STAGE_IR)
	_ir = _ir_builder.build(_ast)
	pipeline_panel.show_ir(_ir, [])
	
	if game_world and game_world.has_method("load_program"):
		game_world.load_program(_ir)
		
	_stage = STAGE_IR

# ─────────────────────────────────────────────
#  Full run (Run button)
# ─────────────────────────────────────────────
func _on_run_requested():
	# If we're not fully compiled, try compiling
	if _stage < STAGE_IR:
		_on_compile_requested(ide_panel.editor.text)
		
	if _stage >= STAGE_IR and _ir != null:
		if game_world and game_world.has_method("toggle_simulation"):
			game_world.toggle_simulation()
			if game_world.is_simulating:
				pipeline_panel.show_runtime_start()
				pipeline_panel.log_runtime("--- Simulation Started ---", false)
			else:
				pipeline_panel.log_runtime("--- Simulation Paused ---", false)

# ─────────────────────────────────────────────
#  Step Stage (Step Stage button)
# ─────────────────────────────────────────────
func _on_step_requested():
	var source = ide_panel.editor.text
	
	match _stage:
		STAGE_NONE:
			# Step 1: Lex
			_reset_pipeline()
			pipeline_panel.reset_all()
			pipeline_panel.mark_stage_running(STAGE_LEXER)
			_tokens = _lexer.tokenize(source)
			_diagnostics = _lexer.diagnostics.duplicate()
			pipeline_panel.show_lexer(_tokens, _diagnostics)
			ide_panel.show_diagnostics(_diagnostics)
			_stage = STAGE_LEXER
		STAGE_LEXER:
			if not _lexer.diagnostics.is_empty(): return
			# Step 2: Parse
			pipeline_panel.mark_stage_running(STAGE_PARSER)
			_ast = _parser.parse(_tokens)
			var pd = _parser.diagnostics.duplicate()
			_diagnostics.append_array(pd)
			pipeline_panel.show_ast(_ast, pd)
			ide_panel.show_diagnostics(_diagnostics)
			_stage = STAGE_PARSER
		STAGE_PARSER:
			if not _parser.diagnostics.is_empty(): return
			# Step 3: Semantic
			pipeline_panel.mark_stage_running(STAGE_SEMANTIC)
			_symbols = _semantic.analyze(_ast)
			var sd = _semantic.diagnostics.duplicate()
			_diagnostics.append_array(sd)
			pipeline_panel.show_semantic(_symbols, _diagnostics)
			ide_panel.show_diagnostics(_diagnostics)
			_stage = STAGE_SEMANTIC
		STAGE_SEMANTIC:
			if not _semantic.diagnostics.is_empty(): return
			# Step 4: IR
			pipeline_panel.mark_stage_running(STAGE_IR)
			_ir = _ir_builder.build(_ast)
			pipeline_panel.show_ir(_ir, [])
			_stage = STAGE_IR
			
			# We're intercepting Step in GameWorld now
			if game_world and game_world.has_method("debug_step"):
				game_world.debug_step(0.2)
				if game_world.vm:
					game_world._reset_vm()
					game_world.vm.run()
					pipeline_panel.update_runtime_state(game_world.vm)
					pipeline_panel.highlight_ir_instruction(game_world.vm.context.ip)

# ─────────────────────────────────────────────
#  Reset (Reset button)
# ─────────────────────────────────────────────
func _on_reset_requested():
	_reset_pipeline()
	pipeline_panel.reset_all()
	ide_panel.show_diagnostics([])
	if game_world and game_world.has_method("reset_wave"):
		game_world.reset_wave()

# ─────────────────────────────────────────────
#  VM helpers
# ─────────────────────────────────────────────
func _start_vm():
	var adapter = APIAdapter.new(game_world if game_world and game_world.has_method("get_enemies") else null)
	_vm = TurretScriptVM.new(_ir, adapter)
	_vm.log_message.connect(_on_vm_log)
	_vm.runtime_error.connect(_on_vm_error)
	_vm.execution_finished.connect(_on_vm_finished)
	pipeline_panel.show_runtime_start()
	_stage = STAGE_RUNTIME

func _on_vm_log(msg: String):
	pipeline_panel.log_runtime(msg, false)

func _on_vm_error(msg: String):
	pipeline_panel.log_runtime(msg, true)

func _on_vm_finished():
	pipeline_panel.update_runtime_state(_vm)

# ─────────────────────────────────────────────
#  Internal reset
# ─────────────────────────────────────────────
func _reset_pipeline():
	_stage = STAGE_NONE
	_tokens = []
	_ast = null
	_symbols = []
	_ir = null
	_diagnostics = []
	_vm = null
	_lexer = LexerScript.new()
	_parser = ParserScript.new()
	_semantic = SemanticScript.new()
	_ir_builder = IRBuilderScript.new()

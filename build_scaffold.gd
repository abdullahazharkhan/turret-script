extends SceneTree

func _init():
    print("Building scaffold...")
    
    # 1. GameWorld
    var game_world = Node2D.new()
    game_world.name = "GameWorld"
    var map = Node2D.new()
    map.name = "Map"
    game_world.add_child(map)
    map.owner = game_world
    var turret_pos = Marker2D.new()
    turret_pos.name = "TurretPosition"
    turret_pos.position = Vector2(300, 360)
    game_world.add_child(turret_pos)
    turret_pos.owner = game_world
    var enemy_path = Path2D.new()
    enemy_path.name = "EnemyPath"
    game_world.add_child(enemy_path)
    enemy_path.owner = game_world
    var dbg_label = Label.new()
    dbg_label.name = "DebugLabel"
    dbg_label.text = "Game World Loaded"
    game_world.add_child(dbg_label)
    dbg_label.owner = game_world
    
    var pack_gw = PackedScene.new()
    pack_gw.pack(game_world)
    ResourceSaver.save(pack_gw, "res://scenes/game_world.tscn")
    
    # 2. IDEPanel
    var ide_panel = PanelContainer.new()
    ide_panel.name = "IDEPanel"
    var vbox = VBoxContainer.new()
    vbox.name = "VBoxContainer"
    ide_panel.add_child(vbox)
    vbox.owner = ide_panel
    var toolbar = HBoxContainer.new()
    toolbar.name = "Toolbar"
    vbox.add_child(toolbar)
    toolbar.owner = ide_panel
    
    var btn_compile = Button.new()
    btn_compile.name = "CompileButton"
    btn_compile.text = "Compile"
    toolbar.add_child(btn_compile)
    btn_compile.owner = ide_panel
    
    var btn_run = Button.new()
    btn_run.name = "RunButton"
    btn_run.text = "Run"
    toolbar.add_child(btn_run)
    btn_run.owner = ide_panel
    
    var btn_step = Button.new()
    btn_step.name = "StepStageButton"
    btn_step.text = "Step Stage"
    toolbar.add_child(btn_step)
    btn_step.owner = ide_panel
    
    var btn_reset = Button.new()
    btn_reset.name = "ResetButton"
    btn_reset.text = "Reset"
    toolbar.add_child(btn_reset)
    btn_reset.owner = ide_panel
    
    var editor = TextEdit.new()
    editor.name = "CodeEditor"
    editor.text = "func main() {\n\trun(1, 0, 40);\n\tvar enemies = get_enemies();\n\tvar target = nearest(enemies);\n\tif (distance(target) < 200) {\n\t\tshoot(target);\n\t}\n}"
    editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(editor)
    editor.owner = ide_panel
    
    var diagnostics = RichTextLabel.new()
    diagnostics.name = "DiagnosticsPanel"
    diagnostics.text = "No errors."
    diagnostics.custom_minimum_size = Vector2(0, 100)
    vbox.add_child(diagnostics)
    diagnostics.owner = ide_panel
    
    var pack_ide = PackedScene.new()
    pack_ide.pack(ide_panel)
    ResourceSaver.save(pack_ide, "res://scenes/ui/ide_panel.tscn")
    
    # 3. CompilerPipelinePanel
    var pipeline = TabContainer.new()
    pipeline.name = "CompilerPipelinePanel"
    
    var stage_lexer = ItemList.new()
    stage_lexer.name = "Lexer"
    pipeline.add_child(stage_lexer)
    stage_lexer.owner = pipeline
    
    var stage_ast = Tree.new()
    stage_ast.name = "Parser_AST"
    pipeline.add_child(stage_ast)
    stage_ast.owner = pipeline
    
    var stage_semantic = Tree.new()
    stage_semantic.name = "Semantic"
    pipeline.add_child(stage_semantic)
    stage_semantic.owner = pipeline
    
    var stage_ir = ItemList.new()
    stage_ir.name = "IR"
    pipeline.add_child(stage_ir)
    stage_ir.owner = pipeline
    
    var stage_runtime = RichTextLabel.new()
    stage_runtime.name = "Runtime"
    pipeline.add_child(stage_runtime)
    stage_runtime.owner = pipeline
    
    var pack_pipeline = PackedScene.new()
    pack_pipeline.pack(pipeline)
    ResourceSaver.save(pack_pipeline, "res://scenes/ui/compiler_pipeline_panel.tscn")
    
    # 4. Main
    var main = Node.new()
    main.name = "Main"
    
    var gw_instance = pack_gw.instantiate()
    main.add_child(gw_instance)
    gw_instance.owner = main
    
    var canvas = CanvasLayer.new()
    canvas.name = "CanvasLayer"
    main.add_child(canvas)
    canvas.owner = main
    
    var hsplit = HSplitContainer.new()
    hsplit.name = "HSplitContainer"
    hsplit.anchor_right = 1.0
    hsplit.anchor_bottom = 1.0
    canvas.add_child(hsplit)
    hsplit.owner = main
    
    var left_spacer = Control.new()
    left_spacer.name = "LeftSpacer"
    left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hsplit.add_child(left_spacer)
    left_spacer.owner = main
    
    var ui_vsplit = VSplitContainer.new()
    ui_vsplit.name = "UIVSplit"
    ui_vsplit.custom_minimum_size = Vector2(400, 0)
    hsplit.add_child(ui_vsplit)
    ui_vsplit.owner = main
    
    var ide_instance = pack_ide.instantiate()
    ui_vsplit.add_child(ide_instance)
    ide_instance.owner = main
    ide_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    var pipeline_instance = pack_pipeline.instantiate()
    ui_vsplit.add_child(pipeline_instance)
    pipeline_instance.owner = main
    pipeline_instance.custom_minimum_size = Vector2(0, 300)
    
    var pack_main = PackedScene.new()
    pack_main.pack(main)
    ResourceSaver.save(pack_main, "res://scenes/main.tscn")
    
    print("Done building scaffold.")
    quit()

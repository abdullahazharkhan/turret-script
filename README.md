# TurretScript Compiler Demo

TurretScript is a custom, statically-typed scripting language built entirely in GDScript for Godot 4.x. It features a complete compiler pipeline (Lexer, Parser, Semantic Analyzer, IR Bytecode Generator) and a Virtual Machine (VM) execution engine.

This project serves as an interactive educational tool to demonstrate how programming languages work under the hood.

## Getting Started
1. Open the project in **Godot 4.x**.
2. Open `scenes/main.tscn` and press **Play (F5)**.
3. You will be greeted by the TurretScript IDE.

## Features
- **Live Compiler Pipeline**: As you click **Compile**, your code is transformed through multiple stages. You can inspect each stage in the right panel:
  - **Lexer**: Breaks code into tokens.
  - **Parser**: Builds an Abstract Syntax Tree (AST).
  - **Semantic**: Type-checks variables, functions, and API calls.
  - **IR**: Generates stack-based bytecode instructions.
  - **Runtime**: Displays VM State, Stack, Call Frames, and API Logs.
- **Interactive Turret AI**: Write code to control the Turret in the `GameWorld`. The VM executes your compiled script on a timer to lock onto and shoot enemies.
- **Step Execution**: Use the **Step Stage** button to manually walk through compilation stages or single-step the bytecode execution.

## Syntax & API
TurretScript supports C-style syntax with custom types (`int`, `bool`, `string`, `enemy`, `void`).

**Example Script:**
```c
func main() {
    var enemies = get_enemies();
    var target = nearest(enemies);
    
    // Check if we have a target in range
    if (distance(target) < 200) {
        shoot(target);
    } else {
        reload(); // Reload while waiting
    }
}
```

**Built-in API:**
- `get_enemies() -> array`
- `nearest(array) -> enemy`
- `distance(enemy) -> int`
- `shoot(enemy) -> void`
- `reload() -> void`

**Enemy Properties:**
- `enemy.id`
- `enemy.health`
- `enemy.type` (e.g., "tank", "scout")
- `enemy.alive`

## Controls
- **Compile**: Builds the script.
- **Run**: Toggles the live game simulation (Play/Pause).
- **Step Stage**: Steps the compiler pipeline or the VM execution.
- **Reset**: Resets the current wave of enemies and turret ammo.
- **Keyboard 1, 2, 3**: Changes simulation speed to 1x, 2x, or 4x.

## Known Limitations
- Arrays are natively implemented only for `get_enemies()`. Custom arrays cannot be created.
- Structs and classes are not supported.
- `while (true)` loops will trip the VM's instruction budget guard (infinite loop protection), as the AI executes on a tick-based system.

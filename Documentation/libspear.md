
LibSpear library contains battle MCTS AI logic, along with an implementation of battle mode.
For convenience the precompiled binaries are included in `LibSpear/bin/`. While not an elegant solution, it removes a lot of friction for new contributors. As such, if you don't want to contribute to C++ codebase, the following instructions do not apply.

# How to build LibSpear

Ensure that you have a C++20-compliant compiler and OpenMP libraries installed (e.g. `libgomp` on GCC).
Currently LibSpear can be build using CMake (recommended) or SCons.

## CMake CLI

The following instructions are intended for general use - for VSCode users skip to "VSCode integration" subsection.
To build Libspear using CMake, type the following commands:

```sh
git submodule init  # Downloads dependencies required for building LibSpear as git modules (godot-cpp)
cd LibSpear
mkdir build; cd build;
cmake ..
make
```

Generating `compile_commands.json` for LSP integration is done as usual:

```
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
make
ln -s compile_commands.json ../compile_commands.json
```

After reloading the project the changes should be visible in the editor.

## SCons CLI

To compile the project, run the following command:

```sh
scons
```

If you want to have autocompletion in your LSP/IDE, you can generate CompileDB (compile_commands.json) with a following command:

```sh
scons cdb
```

If you want to debug LibSpear, use the following build command:

```sh
scons debug_symbols=yes optimize=debug
```

After that you can use your favourite debugger and run Godot inside Polyspear's root directory to debug it.

## VSCode integration

In order to have a fully working IntelliSense integration in VSCode, make sure to install 'C/C++' and 'CMake Tools' extensions and make sure to configure/build using the menu on the left sidebar (with the CMake Tools icon). Make sure that the compiler version listed here is recent enough for C++20 support (at least GCC 13). After that you should be able to build project and have working IntelliSense.

## Optimization

The default Debug target may have very poor performance (less than 10% of the release). If you want to use an optimized debug build, use RelWithDebugInfo target.

# Cross-compilation

## On Linux

SCons allows for easy cross-compilation. If you have MinGW-w64 (compiler, e.g. g++ and OpenMP, e.g. `libgomp`) installed (probably available in your distro's repositories under `mingw-w64` name or similar) the following command should *just work*:

```sh
scons target=windows
```

With CMake you need to use custom toolchain files. You can find an example [here](https://www.mingw-w64.org/build-systems/cmake/). You may need to adjust it depending on your setup. You can then generate a project using: 

```sh
cmake -DCMAKE_TOOLCHAIN_FILE=path/to/my/toolchainfile.cmake ..
```

and compile it as usual. Of course make sure you have MinGW and OpenMP development libraries installed.

## On Windows

TODO (might be worth looking into WSL or MSYS2)

# Diagnostics

In config_manager.gd there are currently a few configurable variables. These are also documented in the `config_manager.gd` file:
- `debug_check_fast_bm_integrity` - checks each time a move is done whether results of a move replicated in BattleManagerFast match results in a regular BM.
- `debug_check_bmfast_internals` - enables additional BattleManagerFast internal integrity checks, which may slightly reduce performance
- `debug_mcts_max_saved_fail_replays` - when greater than zero, saves replays from playouts where errors were detected
- `debug_save_failed_bmfast_integrity` - when true, immediately save replays from BattleManagerFast mismatches with an appropriate name with a suffix "BMFast Mismatch"

Additionally, there's a builtin AI move evaluator, which is automatically enabled for spectators and can be toggled with a "/brain" cheat.

# Architecture

LibSpear defines a few classes that are, e.g. `BattleManagerFast`, `BattleMCTSManager`, `TileGridFast`.
To clear things up, classes in LibSpear follow the naming convention:
- C++ `MyClass` without prefix denotes an owned class directly implementing game logic,
- C++ `MyClassCpp` denotes a class exposed in Godot which wraps the non-prefix class and adds getters/setters/other interoperation functions, which however should not be used directly in GDScript,
- GDScript `MyClass` which adds utility functions (such as `static func` constructors from corresponding Godot classes). 
Currently the only exception to the naming convention is the `BattleMCTSManager` class, because it both implements logic and is exposed to Godot.

When interfacing with Godot, LibSpear extensively uses a "tuple" format of moves, e.g. an array in a format of either \[unit_id, position] or \[unit_id, position, spell_id]. These can be converted using `BattleManagerFastCpp`'s `libspear_tuple_to_move_info` and `move_info_to_libspear_tuple` functions.

`BattleManagerFastCpp` class and its GDScript wrapper `BattleManagerFast` implements battle logic and stores:
- List of armies, each containing a list of units and additional properties, such as cyclone counter and mana,
- List of spells, each having an assigned unit id,
- Unit cache, for more efficient lookups,
- Move/heuristically sensible move cache,
- Other state variables.

Important notes when changing BattleManagerFastCpp:
- Do not relocate units in an array - they require a stable ID,
- When moving/killing a unit, always use `_move_unit` and `_kill_unit` functions
- A `BattleSpellState` represents either a unit's castable spell or an already cast spell. When implementing spells, you can assing multiple `BattleSpellState`s to a single spell to implement more complex behavior,
- Effects are implemented as unit flags (for simple checking) and unit's Effect objects (for duration tracking). There's an exception - martyr - which has its own functions, as it requires a bit of special handling,
- Asserts will be very helpful when debugging, so please extensively use `BM_ASSERT(check, msg)`macro for checking for illegal behavior (or `BM_ASSERT_V(check, msg, return_value)` for non-void methods) - semantics are very similar to GDScript's `assert(...)`. If you REALLY worry that your check will severely impact performance (it likely won't - even optional `unit_cache` self test is not that impactful according to profiling) you can check `_debug_internals` boolean,
- Avoid raw pointers when possible - use either references or when a nullable value is needed use `std::optional` (either with value or with a reference, depending on what you need).

`BattleMCTSManager` implements MCTS logic, running playouts and retrieving moves and their rewards per visit.

Important functions:
- `set_root` - sets BattleMCTSManager as root - currently can only be set once
- `iterate` - may be called over and over again
- `get_optimal_move` - gets the best move in terms of reward/visits
- `get_move_scores` - gets a dictionary of moves 

Parameters are described in [../Scripts/AI/MCTS/battle_mcts_manager.gd]

# How To
## ...implement a new spell?

1. Add a new entry in `BattleSpell::State` enum in `battle_spell.hpp`,
2. Add an extra `if` branch checking for spell's string ID in `BattleSpell(godot::String string, UnitID _unit)`,
3. Add a new case in a switch statement in `BattleManagerFast::_process_spell` in `battle_manager_fast.cpp` file describing what the spell does upon casting on a given tile. You may want to add a new effect via `unit.try_apply_effect(effect_flag)` depending on the spell's behavior,
4. Add a new case in a switch statement in `BattleManagerFast::_spells_append_moves()` describing where the spell can be cast - you can (and even should) use `_append_moves_...` methods for convenience.
## ...implement a new effect?

1. Add a new flag constant in `Unit` class in `battle_structs.hpp` file,
2. Add an extra `if` branch checking for spell's string ID in `BattleSpell(godot::String string, UnitID _unit)`,
3. Implement effect logic, probably triggering on actions e.g. in `_move_unit`, `_kill_unit`, `_update_move_end`, `_update_turn_end` methods - here there's no centralized effect processing. Start by checking for effect's presence with `unit.is_effect_active(effect_flag)`, then implement your logic. If the effect is "consumed", you can remove it with `unit.remove_effect(effect_flag)`. 
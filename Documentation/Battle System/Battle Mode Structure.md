All of battles are managed by: `battle_manager.gd` -> main singleton
To calculate gameplay logic it uses `battle_grid_state.gd`.

# Battle Manager

## Battle Setup
Two main functions:

`start_battle()` - main method which uses `_load_map()` and initiates its `_battle_grid_state`.
Function ends by calling `_on_turn_started()` for the first player.
## Battle End
Only one public function: `close_when_quitting_game()` as it's safe to use, it gets called everywhere.
Second way to end a battle is by having a `battle_grid_state` in a state == STATE_BATTLE_FINISHED during the `end_move()` function call. Which then calls `_on_battle_ended()`.
## Additional mechanics

### Map editor

List of public functions that simply call private functions that:

- Loads a map
- Unloads a map,
- based on the given coord call specific tile function “paint”
- returns a deep copy of the grid.

### Cheats

List of simple wrappers that call `battle_grid_state` functions.

Cheats treat current player making a move as someone calling a cheat. So if during AI turn player were to "surrender" AI would surrender instead of the player.

For cheats which lead to the immediate end of the battle, wrapper concludes the current player move.

### Chess clock

Operates on milliseconds represented by integers.
Chess clock is updated on `_process` and constantly accessed by a `_process` on `BattleUi`



# Battle Grid State
Major file almost 1500 lines of code.
It's split into 14 regions:
## `Init`
Battle can start only through it's public function `create` which requires only a `BattleMap` resource and a list of `Army.gd` objects.
Those are then transformed into battle-mode only specific subclasses: Armies into `ArmyInBattleState` and based on map data an array of `BattleHex` tiles.
Based on number of "mana tiles" as well as number of mana points possessed by armies, a calculation for "Cyclone Timer" is performed using `mana_values_changed()`
First player in the array is assigned as the first player to play.
## `move_info support`
List of functions which execute given player move.

`move_info_execute()` as all `move_info support` functions it starts out by performing records for Replay and Undo systems.
Given overlap in different move types some actions are performed always like retrieving a unit from given starting coordinates. But later function splits through a match method

`move_info_deploy_unit() -> Unit` unique function as it additionally returns generated Unit object based on given unit data and deployment position. Which then is used by Battle Manager to generate `UnitForm.gd` object.

# Units
Are split into gameplay `Unit.gd` and visual `UnitForm.gd` only the visual side has a reference of the gameplay "entity" so to communicate gameplay changes affecting it like movement, rotation or death it uses signals.

All gameplay related to weapons is calculated using static function which operate on global enumerated weapons list.
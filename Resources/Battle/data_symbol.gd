class_name DataSymbol
extends Resource

@export var symbol_name : String
@export_file var texture_path : String
@export var symbol_animation : SymbolAnimation

#region Statistics
## each statistic is independent ex.
## a symbol could parry without having any attack power.
## or a symbol that has parry break with push

## power has to bigger than defense power to kill a unit
@export var attack_power : int = 0

## 0 no shield, 1 weak shield (any symbol), 2 normal shield, 3 strong shield
@export var defense_power : int = 1

## number of tiles unit is pushed away. If tile unit is pushed too is occupied unit dies.
## With the exception of the last tile is pushed to, if push power is >1. (Pits ignore the last tile rule)
@export var push_power : int = 0

## currently only works for attack_power and not yet for push power.
@export var counter_attack : bool = false
## weapon attack occurs before enemy can counter attack
@export var swift_attack : bool = false

## blocks any enemy melee symbol from taking an effect, [br]
## prevents enemy symbol from damaging or pushing regardless of its power
@export var parry : bool = false
## disables parry effect
@export var parry_break : bool = false

## return how many tiles does range weapon attack can reach [br]
## -1 = infinite
@export var reach : int = 0


#Both false is a passive weapon (shield)
# turn only - bow
# move only - javelin
## Determines if symbol activates during rotation
@export var activate_turn : bool = true
## Determines if symbol activates during movement
@export var activate_move : bool = true

#endregion Statistics


#region Effects

## returns true if symbol can push push_power > 0
func can_it_push() -> bool:
	return push_power > 0


## attack_power > defense_symbol.defense_power
func does_pierce_defense(defense_symbol : DataSymbol) -> bool:
	return attack_power > defense_symbol.defense_power


## will_parry_occur (check parry break)
func does_parry(attack_symbol : DataSymbol) -> bool:
	return not attack_symbol.parry_break and parry


## reach > 0
func does_it_shoot() -> bool:
	return reach > 0


## does activate at this action type and does it deal damage or pushes
func is_offensive(action_type : E.MoveType) -> bool:
	if (action_type == E.MoveType.TURN and activate_turn) or \
	   (action_type == E.MoveType.MOVE and activate_move):
		return attack_power > 0 or push_power > 0
	else:
		return false

#endregion Effects

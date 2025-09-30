class_name BattleMagicEffect
extends Resource

@export var name : String = ""
@export_file var icon_path : String = ""

@export var spell_effects : Array[BattleMagicEffect]


## makes the effect last indefinitely
@export var passive_effect : bool = false
## normal magical effects last only for 6 turns
var duration_counter : int = 6


#region Specific spells Variables


var magic_weapon_durability : int = 4


#endregion Specific spells Variables


## used to debug
func _to_string() -> String:
	return "BattleMagicEffect: " + name


func apply_effect(target : Unit, event_type : String) -> void:
	match name:
		"Vengeance":
			if event_type == "post death spell effect":
				target.try_adding_magic_effect(spell_effects[0].duplicate())

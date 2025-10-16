class_name DataMagicEffect
extends Resource

@export var name : String = ""
@export_file var icon_path : String = ""

@export var spell_effects : Array[DataMagicEffect]


## makes the effect last indefinitely
@export var passive_effect : bool = false
## normal magical effects last only for 6 turns
@export var duration_counter : int = 6


@export_category("Specific spells Variables")

@export var magic_weapon_durability : int = 4


## used to debug
func _to_string() -> String:
	return "DataMagicEffect: " + name

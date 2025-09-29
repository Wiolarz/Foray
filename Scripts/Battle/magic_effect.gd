class_name MagicEffect
extends Resource

var name : String = ""
var icon_path : String = ""

var spell_effects : Array[DataMagicEffect]


## makes the effect last indefinitely
var passive_effect : bool = false
## normal magical effects last only for 6 turns
var duration_counter : int = 6


#region Specific spells Variables


var magic_weapon_durability : int = 4


#endregion Specific spells Variables

static func create_effect(data_effect : DataMagicEffect) -> MagicEffect:
	var result := MagicEffect.new()

	result.name = data_effect.name
	result.icon_path = data_effect.icon_path

	result.spell_effects = data_effect.spell_effects.duplicate()
	result.passive_effect = data_effect.passive_effect
	result.duration_counter = data_effect.duration_counter
	result.magic_weapon_durability = data_effect.magic_weapon_durability

	return result


## used to debug
func _to_string() -> String:
	return "MagicEffect: " + name


func apply_effect(target : Unit, event_type : String) -> void:
	match name:
		"Vengeance":
			if event_type == "post death spell effect":
				target.try_adding_magic_effect(spell_effects[0])

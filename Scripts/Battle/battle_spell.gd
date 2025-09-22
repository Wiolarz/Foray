class_name BattleSpell
extends Resource

@export var name : String = ""
@export_file var icon_path : String = ""
@export_multiline var description : String = ""

## optional, used when spell applies an effect to a unit
@export var spell_effects : Array[BattleMagicEffect]

## optional, used only by summon spells
@export var summon_unit_data : DataUnit

##STUB category
@export_category("restrictions for spell targeting")

## -1 infinite | 0 allows to cast on itself
@export var axial_cast_range : int = 0

@export var only_in_front : bool = false

## used to debug
func _to_string() -> String:
	return "BattleSpell: " + name


## STUB for magic refactor
func enchanted_unit_dies() -> void:
	match name:
		"Vengeance":
			#get_unit(target_tile_coord).effects.append(spell)
			#print(get_unit(target_tile_coord).effects)
			print("zemsta")
			pass
		_:
			return


## Based of event type applies effect to the target unit [br]
## each new effects needs to be addded here
func cast_effect(target : Unit, event_type : String) -> void:
	match name:
		"Vengeance", "Blood Ritual", "Martyr", "Anchor":
			if event_type == "casting":
				target.try_adding_magic_effect(spell_effects[0].duplicate())


static func get_network_id(spell : BattleSpell) -> String:
	if not spell:
		return ""
	assert(spell.resource_path.begins_with(CFG.SPELLS_PATH), \
			"spell serialization not supported")
	return spell.resource_path.trim_prefix(CFG.SPELLS_PATH)


static func from_network_id(network_id : String) -> BattleSpell:
	if network_id.is_empty():
		return null
	print("loading BattleSpell - ","%s/%s" % [ CFG.SPELLS_PATH, network_id ])
	return load("%s/%s" % [ CFG.SPELLS_PATH, network_id ]) as BattleSpell

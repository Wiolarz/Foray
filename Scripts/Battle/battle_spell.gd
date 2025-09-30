@tool
class_name BattleSpell
extends Resource

enum DirectionCast {ANY, FRONT, STRAIGHT}

enum TargetType {ANY, UNIT, EMPTY_TILE}

enum TargetUnitType {ANY, ALLY, ENEMY}

@export var name : String = ""
@export_file var icon_path : String = ""
@export_multiline var description : String = ""
## optional, used when spell applies an effect to a unit
@export var spell_effects : Array[BattleMagicEffect]

## optional, used only by summon spells
@export var summon_unit_data : DataUnit


@export_category("restrictions for spell targeting")

## -1 infinite | 0 allows only to cast on itself
@export var cast_range : int = -1 :
	set(value):
		cast_range = value
		notify_property_list_changed()

@export var direction_cast := DirectionCast.ANY

@export var target_type := TargetType.ANY :
	set(value):
		target_type = value
		notify_property_list_changed()


# TILE CATEGORY

var needs_movable_tile : bool = false


# Unit Category

var target_unit_type := TargetUnitType.ANY
var not_self : bool = false


func _get_property_list() -> Array[Dictionary]:
	# By default, `hammer_type` is not visible in the editor.

	var not_self_property = PROPERTY_USAGE_NO_EDITOR
	var tile_properties = PROPERTY_USAGE_NO_EDITOR
	var unit_properties = PROPERTY_USAGE_NO_EDITOR

	if target_type == TargetType.UNIT:
		unit_properties = PROPERTY_USAGE_DEFAULT

	if target_type == TargetType.EMPTY_TILE:
		tile_properties = PROPERTY_USAGE_DEFAULT

	if cast_range != 0 and not needs_movable_tile:
		not_self_property = PROPERTY_USAGE_DEFAULT

	var properties :  Array[Dictionary] = []

	properties.append({
		"name": "needs_movable_tile",
		"type": TYPE_BOOL,
		"usage": tile_properties,
	})

	## UNITS

	var target_unit_types_string = ""
	for value in TargetUnitType.keys():
		target_unit_types_string += value + ","
	target_unit_types_string = target_unit_types_string.trim_suffix(",")
	#print(target_unit_types_string)

	properties.append({
		"name": "target_unit_type",
		"type": TYPE_INT,
		"usage": unit_properties,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": target_unit_types_string,
	})


	properties.append({
		"name": "not_self",
		"type": TYPE_BOOL,
		"usage": not_self_property, # See above assignment.
	})

	return properties


## used to debug
func _to_string() -> String:
	return "BattleSpell: " + name


func generate_description() -> String:
	var result : String = description
	result += "\n" + "Possible spell targets:" + "\n"

	match name: # Unique spells
		"Blood Ritual":
			result += "any enemy unit which is not the last one alive"
			return result

	if cast_range == 0:
		return result + "caster can only target himself"
	elif cast_range != -1:
		result += "Spell has a range of: " + str(cast_range) + "\n"

	match direction_cast:
		BattleSpell.DirectionCast.FRONT:
			result += "Target has to be faced by the caster\n"
		BattleSpell.DirectionCast.STRAIGHT:
			result += "Target has to be in a straight line from the caster\n"


	match target_type:
		BattleSpell.TargetType.EMPTY_TILE:
			result += "Target has to be an empty tile"
		BattleSpell.TargetType.UNIT:
			match target_unit_type:
				BattleSpell.TargetUnitType.ALLY:
					result += "Target has to be an ally unit\n"
					if not_self:
						result += "Caster cannot target himself\n"
				BattleSpell.TargetUnitType.ENEMY:
					result += "Target has to be an enemy unit\n"
				BattleSpell.TargetUnitType.ANY:
					result += "Target has to be a unit\n"
					if not_self:
						result += "Caster cannot target himself\n"

	return result


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

class_name DataUnit
extends Resource


@export_category("General")
@export var unit_name : String
@export var texture_path : String
@export var symbols : Array[DataSymbol] = [null,null,null,null,null,null]
@export var cost : Goods
@export var required_building : DataBuilding = null #TEMP
## determines ability to award expirience to a hero
@export var level : int = 1

@export_category("Mage")
## additional passive mana point provided to the army while this unit is alive
@export var mana : int = 0
## list of spells this unit can cast during a battle [br]
## each spell is single use only - resets every battle

@export var spells : Array[BattleSpell] = []


## godot deep copy doesn't support arrays within objects [br]
## symbols.duplicate(true) wouldn't work
func duplicate_symbols() -> Array[DataSymbol]:
	var result : Array[DataSymbol] = []
	for symbol in symbols:
		result.append(symbol.duplicate())
	return result


static func get_network_id(unit : DataUnit) -> String:
	if not unit:
		return ""
	assert(unit.resource_path.begins_with(CFG.UNITS_PATH), \
			"unit serialization not supported")
	return unit.resource_path.trim_prefix(CFG.UNITS_PATH)


static func from_network_id(network_id : String) -> DataUnit:
	if network_id.is_empty():
		return null
	print("loading DataUnit - ","%s/%s" % [ CFG.UNITS_PATH, network_id ])
	return load("%s/%s" % [ CFG.UNITS_PATH, network_id ]) as DataUnit

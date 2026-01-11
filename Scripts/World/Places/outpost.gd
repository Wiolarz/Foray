class_name Outpost
extends Place


var per_turn : Goods
var outpost_type : String
var neutral_army_preset : PresetArmy


static func create_place(coord_ : Vector2i, args : PackedStringArray) -> Place:
	# if args.size() != 1:
	# 	push_error("outpost needs exactly one argument to create")
	var result := Outpost.new()

	var type : String = args[0] if args.size() >= 1 else "wood"
	if not result._set_type(type):
		return null

	# TODO move this somewhere else -- this should not be here
	result.coord = coord_
	result.movable = true

	return result


## returns false on error
func _set_type(type : String) -> bool:
	match type:
		"wood":
			per_turn = Goods.new(1,0,0)
			neutral_army_preset = load(CFG.OUTPOST_WOOD_PATH)
		"iron":
			per_turn = Goods.new(0,1,0)
			neutral_army_preset = load(CFG.OUTPOST_IRON_PATH)
		"ruby":
			per_turn = Goods.new(0,0,1)
			neutral_army_preset = load(CFG.OUTPOST_RUBY_PATH)
		_:
			push_error("bad type of outpost")
			return false
	outpost_type = type
	return true


func get_army_at_start() -> PresetArmy:
	return neutral_army_preset


func interact(army : Army) -> void:
	capture(army.faction)


func capture(new_faction : Faction) -> void:
	if faction: # if outpost had been occupied we need to remove previous player ownership first
		faction.destroyed_outpost(self)

	faction = new_faction
	new_faction.outposts.append(self)
	controller_changed.emit()  # VISUAL set the flag color to match the new controller


func on_end_of_round():
	if faction:
		faction.goods.add(per_turn)


func get_map_description() -> String:
	return per_turn.to_string_short("empty")


func to_specific_serializable(dict : Dictionary[String, Variant]) -> void:
	dict["outpost_type"] = outpost_type


func paste_specific_serializable_state(dict : Dictionary[String, Variant]) -> void:
	_set_type(dict["outpost_type"])

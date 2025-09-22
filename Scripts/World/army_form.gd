class_name ArmyForm
extends Node2D

var entity : Army

var coord:
	get: return entity.coord

var controller:
	get: return entity.controller

## TODO refactor world manager to utilise hero object more directly
## world coord, where hero wants to travel
var travel_path:
	set(new_path):
		assert(entity and entity.hero, "attempt to set a path to non existing hero")
		entity.hero.travel_path = new_path
	get:
		#assert(entity and entity.hero, "attempt to get a path from not existing hero")
		if entity.hero: # TEMP armyform class will not be used by game manager to handle pathfiding
			return entity.hero.travel_path
		return null


func _init():
	name = "ArmyForm"

func _process(_delta):
	var hero = entity.hero
	if hero:
		$MoveLabel.text = "Move %d / %d" % [hero.movement_points, hero.max_movement_points]
		$DescriptionLabel.text =  "%s\nlv %d (%d)" % [hero.hero_name, hero.level, hero.xp]
		$sprite_unit.modulate = Color.DIM_GRAY if not has_movement_points() \
				else Color.WHITE


static func create_form_of_army(hex : WorldHex, position_ : Vector2) \
		-> ArmyForm:
	if not hex or not hex.army:
		return null
	var result : ArmyForm = CFG.DEFAULT_ARMY_FORM.instantiate()
	var army : Army = hex.army
	result.entity = army
	result.entity.leader_unit_changed.connect(result.change_visual_unit_leader)

	if army.hero:
		result.name = army.hero.hero_name
		var image : Texture2D = load(army.hero.data_unit.texture_path)
		result.get_node("sprite_unit").texture = image
		result.get_node("sprite_color").texture = CFG.TEAM_COLOR_TEXTURES[army.controller.color_idx]
	else:
		if army.controller:
			result.name = "City Garrison " + str(army.coord)
			result.get_node("sprite_color").texture = CFG.TEAM_COLOR_TEXTURES[army.controller.color_idx]
		else:
			result.name = "Neutral army " + str(army.coord)
			result.get_node("sprite_color").texture = CFG.NEUTRAL_COLOR_TEXTURE
		result.change_visual_unit_leader()
		result.get_node("MoveLabel").text = ""
		result.get_node("DescriptionLabel").text = ""
		


	result.position = position_
	return result


func has_movement_points() -> bool:
	return entity.hero.movement_points > 0


##STUB
func place_on(tile):
	position = tile.position


func spend_movement_point() -> void:
	assert(entity.hero.movement_points > 0)
	entity.hero.movement_points -= 1


func set_selected(is_selected : bool) -> void:
	$sprite_color.modulate = Color.RED if is_selected else Color.WHITE


func apply_losses(losses : Array[DataUnit]):
	entity.apply_losses(losses)


func change_visual_unit_leader() -> void:
	if entity.hero:
		return
	var new_sprite : Texture2D = null  # City Garrison doesn't need units
	var highest_unit_level : int = 0
	for unit in entity.units_data:
		if highest_unit_level < unit.level:
			highest_unit_level = unit.level
			new_sprite = load(unit.texture_path)

	get_node("sprite_unit").texture = new_sprite

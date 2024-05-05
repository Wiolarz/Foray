class_name Army
extends Node

var hero : Hero

var units_data : Array[DataUnit]

var units : Array[UnitForm]

var controller : Player

var coord : Vector2i

var alive : bool = true


func destroy_army():
	if hero != null:
		WM.kill_hero(hero)
	else:
		WM.grid[coord.x][coord.y].army = null

	queue_free()


func get_units_list():
	return units_data.duplicate()


static func create_army_from_preset(army_preset : PresetArmy) -> Army:
	var new_army = Army.new()
	new_army.units_data = army_preset.units
	#new_army.hero = army_preset.hero  # TODO ARMY PRESET HERO
	return new_army

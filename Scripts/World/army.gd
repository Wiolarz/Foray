class_name Army
extends RefCounted # RefCounted is default

signal leader_unit_changed()

var units_data : Array[DataUnit] = []

var hero : Hero

#TODO change either this or faction to a getter
var controller_index : int

## after battle starts, control over this army is assigned to a player, [br]
## once battle is over that controll has to be removed
var is_neutral : bool = false

var faction : Faction

var controller : Player:
	get:
		if faction:  # neutral armies don't have player assigned
			return faction.controller
		return null

var coord : Vector2i

var max_army_size : int :
	get:
		if hero:
			return hero.max_army_size
		else:
			return CFG.CITY_MAX_ARMY_SIZE

#TEMP
var timer_reserve_sec : int
var timer_increment_sec : int


func get_units_list():
	return units_data.duplicate()


func apply_losses(losses : Array[DataUnit]):
	if hero and hero.data_unit in losses:
		hero.wounded = true
		for passive in hero.passive_effects:
			if passive.passive_name == "immortality":
				hero.wounded = false

		#print("hero wounded")
	for loss in losses:
		#assert(loss in units_data, "loss not in army")
		units_data.erase(loss)


func heal_in_city():
	if hero:
		hero.is_in_city = true
	if hero and hero.wounded:
		hero.wounded = false
		print("hero healed")


func get_movement_points() -> int:
	if hero:
		return hero.movement_points
	return 0


func add_xp(gained_xp : int) -> void:
	if hero:
		hero.add_xp(gained_xp)


func on_end_of_round():
	if hero:
		hero.movement_points += hero.movements_points_renewal
		if hero.movement_points > hero.max_movement_points:
			hero.movement_points = hero.max_movement_points
		hero.rituals = hero.rituals_book.duplicate()

		for passive in hero.passive_effects:
			if passive.passive_name == "arch mage":
				hero.ritual_cost_reduction += 1


## remember that is some player's army is created, it also needs to be
static func create_from_preset(army_preset : PresetArmy) \
		-> Army:
	var new_army = Army.new()
	new_army.units_data = army_preset.units
	new_army.controller_index = -1
	#new_army.hero = Hero.construct_hero(army_preset.hero, -1) # TODO
	return new_army

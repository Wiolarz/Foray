class_name Hero
extends Node

#debug
var template : DataHero

# code
var controller_index : int
var army : Army
var coord : Vector2i
# visual
var target_tile : TileForm


# gameplay
var hero_name : String

## provides bonus to max_army_size while in the city
var is_in_city : bool = true  # normally hero starts in a city

var max_army_size : int :
	get:
		if is_in_city:
			return max_army_size + CFG.CITY_MAX_ARMY_SIZE
		return max_army_size


var max_movement_points = 3
var movement_points = 3

## world coord, where hero wants to travel
var travel_path : Array[Vector2i]


var wounded : bool = false

var xp = 0
var level = 1

# Battle Gameplay
var data_unit : DataUnit

var passive_effects : Array[HeroPassive] = []


## DESIGN should current level determine how many exp is needed for level up
static func level_threshold_at(_level : int) -> int:
	return 2


# static func create_hero(data_hero : DataHero, player : Player) -> Hero:
# 	for dead_hero in player.dead_heroes:
# 		if dead_hero.template == data_hero:
# 			dead_hero.revive()
# 			dead_hero.controller = player
# 			return dead_hero

# 	return construct_hero(data_hero, player)


## this function only creates structure -- it has to be later added to state
## properly as it is done by WorldState.recruit_hero function
static func construct_hero(data_hero : DataHero,
		player_index : int) -> Hero:
	var new_hero = Hero.new()
	new_hero.template = data_hero
	new_hero.hero_name = data_hero.hero_name
	new_hero.name = "Hero_" + data_hero.hero_name
	new_hero.controller_index = player_index
	new_hero.data_unit = data_hero.data_unit
	new_hero.max_army_size = data_hero.max_army_size
	new_hero.max_movement_points = data_hero.max_movement_points
	new_hero.passive_effects = data_hero.starting_passives
	new_hero.level = data_hero.starting_level
	return new_hero


func _init():
	name = "Hero"


func trade(_another_hero : Hero):
	print("trade menu")


func move(target : TileForm):
	target_tile = target


func add_xp(gained_xp : int) -> void:
	if gained_xp <= 0:
		return
	xp += gained_xp
	while xp >= Hero.level_threshold_at(level):
		_level_up()


func _level_up() -> void:
	if level == CFG.HERO_LEVEL_CAP:
		return
	var threshold = Hero.level_threshold_at(level)
	xp -= threshold
	level += 1
	print("%s leveled up, now has level %d" % [hero_name, level])
	var old_max_move = max_movement_points
	max_army_size = 2 + level
	max_movement_points =  3 + (level / 2)
	movement_points += max_movement_points - old_max_move


func revive():
	movement_points = max_movement_points


func to_network_serializable() -> Dictionary:
	var dict : Dictionary = {}
	dict["data_hero"] = DataHero.get_network_id(template)
	dict["name"] = hero_name
	dict["movement_points"] = movement_points
	dict["xp"] = xp
	dict["level"] = level
	return dict


static func from_network_serializable(dict : Dictionary, controller_index_ : int) -> Hero:
	var data_hero = DataHero.from_network_id(dict["data_hero"])
	var hero : Hero = Hero.construct_hero(data_hero, controller_index_)
	hero.hero_name = dict["name"]
	hero.movement_points = dict["movement_points"]
	hero.xp = dict["xp"]
	hero.level = dict["level"]
	return hero

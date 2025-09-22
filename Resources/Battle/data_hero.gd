class_name DataHero
extends Resource

@export var hero_name : String
@export var cost : Goods
@export var revive_cost : Goods

## COMBAT
@export var data_unit : DataUnit

@export var starting_passives : Array[HeroPassive] = []


## GENERAL
@export var starting_level : int = 1


## CAMPAIGN
@export var max_army_size : int = 3

@export var max_movement_points : int = 3


static func get_network_id(hero : DataHero) -> String:
	var splitted = hero.resource_path.split("/", false)
	splitted = [ splitted[-2], splitted[-1] ]
	return "%s/%s" % splitted if hero else ""


static func from_network_id(network_id : String) -> DataHero:
	if network_id.is_empty():
		return null
	var path = "%s/%s" % [ CFG.HEROES_PATH, network_id ]
	var resource = load(path)
	var data_hero = resource as DataHero
	return data_hero

class_name Faction
extends RefCounted



var controller_index : int
var controller : Player:
	get:
		return IM.get_player_by_index(controller_index)
	set(_wrong_value):
		assert(false, "attempt to modify read only value of Faction controller")

var race : DataRace


var cities : Array[City]
var capital_city : City:
	get:
		if cities.size() == 0:
			return null
		return cities[0]
	set(_wrong_value):
		assert(false, "attempt to modify read only value of Faction capital_city")

var outposts : Array[Outpost]
var outpost_buildings : Array[DataBuilding]

var hero_armies : Array[Army] = []
var dead_heroes: Array[Hero] = []

var goods : Goods = Goods.new()

## Ticks down at end of the round if player doesn't posses any cities
const DEFEAT_TURN_TIMER_RESET : int = 6
var defeat_turn_timer : int = DEFEAT_TURN_TIMER_RESET


static func create_faction(slot : Slot) -> Faction:
	var new_faction := Faction.new()

	new_faction.controller_index = slot.index
	new_faction.race = slot.race

	return new_faction


func has_faction_lost() -> bool:
	assert(defeat_turn_timer >= 0, "negative defeat turn timer value")
	return defeat_turn_timer <= 0 or \
		(cities.size() == 0 and hero_armies.size() == 0)


#region Goods + City Economy

## If there are sufficient goods returns true + goods are subtracted
func try_to_pay(cost : Goods) -> bool:
	if goods.has_enough(cost):
		goods.subtract(cost)
		return true
	print("not enough money")
	return false


func has_this_outpost_type(outpost_type : String) -> bool:
	for outpost in outposts:
		if outpost.outpost_type == outpost_type:
			return true
	return false


## Removes outpost from occupied outpost list,
## it may additionaly remove buildings which require outpost type to be present
func destroyed_outpost(outpost : Outpost) -> void:
	outposts.erase(outpost)
	if not has_this_outpost_type(outpost.outpost_type):
		for building in outpost_buildings:
			if building.outpost_requirement == outpost.outpost_type:
				outpost_buildings.erase(building)


func captured_a_city(city : City) -> void:
	cities.append(city)
	if defeat_turn_timer < DEFEAT_TURN_TIMER_RESET:
		defeat_turn_timer = DEFEAT_TURN_TIMER_RESET


func lost_a_city(city : City) -> void:
	cities.erase(city)
	WS.perform_game_over_checks()


#endregion Goods + City Economy


#region Heroes

func has_hero(data_hero : DataHero) -> bool:
	for hero_army in hero_armies:
		if hero_army.hero.template == data_hero:
			return true
	return false


func has_dead_hero(data_hero : DataHero) -> bool:
	for hero in dead_heroes:
		if hero.template == data_hero:
			return true
	return false


func get_hero_cost(data_hero : DataHero) -> Goods:
	if has_dead_hero(data_hero):
		return data_hero.revive_cost
	return data_hero.cost


## improves goods tiers
func hero_leveled_up() -> void:
	var hero_levels : Array[int] = []
	for army in hero_armies:
		var hero : Hero = army.hero
		hero_levels.append(hero.level)
	hero_levels.sort()
	hero_levels.reverse()

	#TODO awaits design for improved tier thresholds
	# tiers thresholds
	var tier_threshold : int = 0
	# 2
	if hero_levels[0] >= 3:
		tier_threshold += 1

	if hero_levels.size() >= 2:
		if hero_levels[0] >= 4 and hero_levels[1] >= 2:
			tier_threshold += 1
		if hero_levels[0] >= 5 and hero_levels[1] >= 3:
			tier_threshold += 1

	if hero_levels.size() == 3:
		if hero_levels[0] >= 5 and hero_levels[1] >= 4 and hero_levels[2] >= 3:
			pass#tier_threshold += 1

	goods.unlocked_tier_wood = tier_threshold
	goods.unlocked_tier_iron = tier_threshold
	goods.unlocked_tier_ruby = tier_threshold

#endregion Heroes

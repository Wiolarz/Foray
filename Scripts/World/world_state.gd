#Singleton WS - World State
extends Node

const MOVE_IS_INVALID = -1

var grid : GenericHexGrid = null
var turn_counter : int
var current_player_index : int
var player_states : Array[Faction] = []
var defeated_factions : Array[Faction] = []
var move_hold_on_combat : Array[Vector2i] # TODO some better form

var pathfinding : AStar2D
var coord_to_index : Dictionary = {}

## TODO consider not using signals here
## this is signal used by other managers
signal combat_started(armies : Array, coord : Vector2i)


#region init

## main init function
func start_world(map : DataWorldMap,
		slots : Array[Slot],
		saved_state : SerializableWorldState = null) -> void:
	# Core Variables Reset
	turn_counter = 0
	current_player_index = 0
	move_hold_on_combat = []
	defeated_factions = []

	grid = GenericHexGrid.new(map.grid_width, map.grid_height, WorldHex.new())

	# load players and their not related-to-grid state
	player_states = []
	for i in range(slots.size()):
		player_states.append(Faction.create_faction(slots[i]))
		var player = player_states[i]
		if not saved_state:
			player.goods = CFG.get_start_goods()
			continue

		# Loading save from State
		player.goods = Goods.from_array(saved_state.players[i].goods)
		for dead_hero_ser in saved_state.players[i].dead_heroes:
			player.dead_heroes.append(Hero.from_network_serializable(
				dead_hero_ser, i))
		for outpost_building_ser in saved_state.players[i].outpost_buildings:
			player.outpost_buildings.append(DataBuilding.from_network_id(
				outpost_building_ser))
		# living armies are added later


	# init places and armies from map or map and saved game
	for x in map.grid_width:
		for y in map.grid_height:
			var coord := Vector2i(x, y)
			var hex : WorldHex = WorldHex.new()
			hex.data_tile = map.grid_data[x][y]
			var place_ser : Dictionary = {}
			var type : String = hex.data_tile.type
			if saved_state:
				place_ser = saved_state.place_hexes.get(coord, {})
				if place_ser.size() > 0:
					type = place_ser["type"]
			hex.init_place(type, coord, place_ser)
			# TODO somehow get this inside of
			# creation
			grid.set_hex(coord, hex)
			if not saved_state and hex.place:
				var army_preset = hex.place.get_army_at_start()
				if army_preset:
					spawn_army_from_preset(army_preset, coord, \
						hex.place.controller_index)
					if hex.place is City:
						hex.army.controller_index = hex.place.controller_index
						hex.army.faction = hex.place.faction
						hex.place.garrison_reserve = hex.army

			if saved_state and coord in saved_state.army_hexes:
				var loaded : Dictionary = saved_state.army_hexes[coord]
				var army : Army = null
				if loaded:
					army = deserialize_army(loaded)
				if army:
					hex.army = army
					army.coord = coord

	generate_astar()  # PATHFINDING

	# add armies to their players if loading from state
	if saved_state:
		for i in player_states.size():
			var player = player_states[i]
			for army_coord in saved_state.players[i].armies:
				var army : Army = get_army_at(army_coord)
				assert(army)
				player.hero_armies.append(army)
				army.controller_index = i
			player.goods = Goods.from_array(saved_state.players[i].goods)
			for dead_hero_ser in saved_state.players[i].dead_heroes:
				player.dead_heroes.append(Hero.from_network_serializable(
					dead_hero_ser, i))
			for outpost_building_ser in saved_state.players[i].outpost_buildings:
				player.outpost_buildings.append(DataBuilding.from_network_id(
					outpost_building_ser))
			# living armies are added later


	synchronize_players_with_their_places()

	if saved_state:
		current_player_index = saved_state.current_player


func generate_astar() -> void:
	pathfinding = AStar2D.new()
	var hex_index : int = -1

	for row in grid.hexes:
		for hex in row:
			if not hex.place or not hex.place.movable:  # Sentinel / WALL
				continue
			hex_index += 1
			coord_to_index[hex.place.coord] = hex_index
			## graphics coordinates are passed to make astart2d work even though it doesn't make sense
			## TODO write our own custom pathfiding so that portals can work properly
			pathfinding.add_point(hex_index, WM.to_position(hex.place.coord))

	hex_index = -1
	for row in grid.hexes:
		for hex in row:
			if not hex.place or not hex.place.movable:  # Sentinel / WALL
				continue
			hex_index += 1
			for side in range(3): # LEFT, TOP_LEFT, TOP_RIGHT,
				var neighbour_coord : Vector2i = hex.place.coord + GenericHexGrid.DIRECTION_TO_OFFSET[side]
				if neighbour_coord in coord_to_index.keys():
					pathfinding.connect_points(hex_index, coord_to_index[neighbour_coord], true)


## fills up players' fields like `cities` and `outposts` after place grid is
## filled with new map or loaded state
func synchronize_players_with_their_places() -> void:
	for player in player_states:
		player.cities = []
		player.outposts = []
	for x in grid.width:
		for y in grid.height:
			var coord := Vector2i(x, y)
			var city = get_city_at(coord)
			var outpost = get_place_at(coord) as Outpost
			if city:
				var player = get_faction_by_index(city.controller_index)
				if player:
					player.cities.append(city)
			if outpost:
				var player = get_faction_by_index(outpost.controller_index)
				if player:
					player.outposts.append(outpost)

#endregion init


#region Public Helpers

func get_current_player() -> Faction:
	if current_player_index in range(player_states.size()):
		return player_states[current_player_index]
	return null


func get_player_index(player : Faction) -> int:
	for i in range(player_states.size()):
		if player == player_states[i]:
			return i
	return -1


func get_faction_by_index(index : int) -> Faction:
	if index < 0:
		return null
	if index >= player_states.size():
		return null
	return player_states[index]


func check_move_allowed(world_move_info : WorldMoveInfo) -> String:
	if world_move_info.move_type == WorldMoveInfo.TYPE_TRAVEL:
		var source : Vector2i = world_move_info.move_source
		var target : Vector2i = world_move_info.target_tile_coord
		return check_army_travel(source, target)
	if world_move_info.move_type == WorldMoveInfo.TYPE_RECRUIT_HERO:
		var player_index : int = world_move_info.recruit_hero_info.player_index
		var hero_data : DataHero = world_move_info.recruit_hero_info.data_hero
		var coord : Vector2i = world_move_info.target_tile_coord
		return check_recruit_hero(player_index, hero_data, coord)
	elif world_move_info.move_type == WorldMoveInfo.TYPE_RECRUIT_UNIT:
		var army_coord : Vector2i = world_move_info.target_tile_coord
		var city_coord : Vector2i = world_move_info.move_source
		var unit : DataUnit = world_move_info.data
		return check_recruit_unit(unit, city_coord, army_coord)
	elif world_move_info.move_type == WorldMoveInfo.TYPE_START_TRADE:
		var source : Vector2i = world_move_info.move_source
		var target : Vector2i = world_move_info.target_coord
		return check_start_trade(source, target)
	if world_move_info.move_type == WorldMoveInfo.TYPE_BUILD:
		var city_coord : Vector2i = world_move_info.target_tile_coord
		var building : DataBuilding = world_move_info.data
		return check_build_building(city_coord, building)
	elif world_move_info.move_type == WorldMoveInfo.TYPE_END_TURN:
		return ""
	return "unrecognised move"


func check_build_building(city_coord : Vector2i, building : DataBuilding) \
		-> String:
	var city : City = get_city_at(city_coord)
	if not city:
		return "cannot build buildings without city"
	if city.controller_index != current_player_index:
		return "cannot build in other's player city"
	if not city.can_build(building):
		# TODO move this check here probably and divide this error message
		return "this city is not able to build this"
	return ""


func check_start_trade(source : Vector2i, target : Vector2i) -> String:
	var army : Army = get_army_at(source)
	if not army:
		return "please choose army to start trade"
	var second_army : Army = get_army_at(target)
	if not second_army:
		return "please choose valid army to start trade"
	if army.controller_index != current_player_index:
		return "it's not this army turn"
	if second_army.controller_index != current_player_index:
		return ""
	return ""


func check_recruit_unit(data_unit : DataUnit, city_coord : Vector2i,
		army_coord : Vector2i) -> String:
	var army : Army = get_army_at(army_coord)
	var army_controller_state = player_states[army.controller_index]
	var unit_cost = get_city_at(city_coord).get_unit_cost(data_unit)

	if not army:
		return "no army at coord"
	if army.controller_index != current_player_index:
		return "target army has not turn now"
	if army.units_data.size() >= army.max_army_size:
		return "this army has maximum size now"
	var city = get_city_at(city_coord)
	if not city:
		return "no city chosen"
	if army_coord != city_coord and \
			not GenericHexGrid.is_adjacent(army_coord, city_coord):
		return "army has to be in city or next to it"
	if city.controller_index != army.controller_index:
		return "cannot recruit not in own city"
	# TODO optimize this...
	if not data_unit in city.get_units_to_buy():
		return "cannot recruit such unit in this city"
	if not city.unit_has_required_building(data_unit):
		return "not all required buildings are build in this city"
	if not army_controller_state.goods.has_enough(unit_cost):
		return "not enough resources for this unit, need %s" % unit_cost
	return ""


func check_recruit_hero(player_index : int, data_hero : DataHero,
		coord : Vector2i) -> String:
	if get_army_at(coord).hero:
		#TODO based on that information change the UI to show what causes the problem to the player
		return "cannot recruit hero where hero is already present"
	var player_faction : Faction = player_states[player_index]
	var city : City = get_city_at(coord)
	if not city:
		return "GAME ERROR: must recruit hero in a city"
	if player_index != current_player_index:
		return "IM WARNING: it's not this player turn"
	if player_index != city.controller_index:
		# TODO while viewing other player cities,
		# we should look if that player is capable of purchasing this hero in UI
		# Verifying that we cannot press this button is an InputManager job
		return "IM ERROR: player does not own the city where tries to recruit"
	if player_faction.has_hero(data_hero):
		return "hero is already recruited"
	if not data_hero in player_faction.race.heroes:
		return "GAME ERROR: player's race does not contain that hero"
	var cost = player_faction.get_hero_cost(data_hero)
	if not player_faction.goods.has_enough(cost):
		return "not enough cash, needed %s" % cost
	return ""


func get_hero_to_buy_in_city(city : City, hero_index : int) -> DataHero:
	assert(city)
	var hero_array = city.faction.race.heroes
	assert(hero_index >= 0 and hero_index < hero_array.size())
	return hero_array[hero_index]


func check_army_travel(source : Vector2i, target : Vector2i) -> String:
	var army : Army = get_army_at(source)
	if not army:
		return "no army at source hex"
	if source == target:
		return "cannot travel to the same hex"
	if army.controller_index != current_player_index:
		return "now is not this army's turn"
	if not GenericHexGrid.is_adjacent(source, target):
		return "cannot move more than one hex at a time"
	if not is_hex_movable(target):
		return "target hex is not movable"
	if army.get_movement_points() <= 0:
		return "not enough movement points"
	if not is_enemy_at(target, army.controller_index) and get_army_at(target):
		return "cannot move into non-enemy army"
	return ""


func get_interactable_type_at(coord : Vector2i) -> String:

	if get_army_at(coord):
		return "army"

	if get_city_at(coord):
		return "city"

	return "EMPTY"


func get_army_at(coord : Vector2i) -> Army:
	var hex : WorldHex = grid.get_hex(coord)
	if hex:
		return hex.army
	return null


func get_place_at(coord : Vector2i) -> Place:
	var hex : WorldHex = grid.get_hex(coord)
	if hex:
		return hex.place
	return null


## Returns null if there is no city at given coord
func get_city_at(coord : Vector2i) -> City:
	return get_place_at(coord) as City


func is_enemy_at(coord : Vector2i, player_index : int) -> bool:
	var army : Army = get_army_at(coord)
	return army and army.controller_index != player_index


func is_hex_movable(coord : Vector2i) -> bool:
	var hex : WorldHex = grid.get_hex(coord)
	return hex and hex.place and hex.place.movable


func get_battle_map_at(_coord : Vector2i, army_size : int) -> DataBattleMap:
	if army_size > 5:
		return CFG.BIGGER_BATTLE_MAP

	return CFG.DEFAULT_BATTLE_MAP


func get_top_left_hex() -> WorldHex:
	return grid.get_hex(Vector2i(0, 0))


func get_bottom_right_hex() -> WorldHex:
	var coord := Vector2i(grid.width - 1, grid.height - 1)
	return grid.get_hex(coord)


## returns true when points can be spent, false when not
func army_can_spend_movement_points(army : Army, points : int) -> bool:
	if army.get_movement_points() < points:
		return false
	return true


func get_interactable_at(coord : Vector2i) -> Object:
	var army = get_army_at(coord)
	if army:
		return army
	var city = get_city_at(coord)
	if city:
		return city
	return null

#endregion Public Helpers


#region Player Turn

func do_move(world_move_info : WorldMoveInfo) -> bool:
	var problem := check_move_allowed(world_move_info)
	if problem != "":
		push_error(problem)
		return false
	match world_move_info.move_type:
		WorldMoveInfo.TYPE_TRAVEL:
			var source : Vector2i = world_move_info.move_source
			var target : Vector2i = world_move_info.target_tile_coord
			return do_army_travel(source, target)
		WorldMoveInfo.TYPE_RECRUIT_HERO:
			var data_hero : DataHero = world_move_info.recruit_hero_info.data_hero
			var coord : Vector2i = world_move_info.target_tile_coord
			return do_recruit_hero(data_hero, coord)
		WorldMoveInfo.TYPE_RECRUIT_UNIT:
			var army_coord : Vector2i = world_move_info.target_tile_coord
			var city_coord : Vector2i = world_move_info.move_source
			var unit : DataUnit = world_move_info.data
			return do_recruit_unit(unit, city_coord, army_coord)
		WorldMoveInfo.TYPE_START_TRADE:
			var source : Vector2i = world_move_info.move_source
			var target : Vector2i = world_move_info.target_coord
			return do_start_trade(source, target)
		WorldMoveInfo.TYPE_BUILD:
			var city_coord : Vector2i = world_move_info.target_tile_coord
			var building : DataBuilding = world_move_info.data
			return do_build_building(city_coord, building)
		WorldMoveInfo.TYPE_END_TURN:
			do_end_turn()
			return true
		_:
			assert(false, "unsupported WorldMoveInfo Type")
			return false



#region City Economy

## returns true only of move was legal and recruitment took place
func do_recruit_unit(data_unit : DataUnit, city_coord : Vector2i,
		army_coord : Vector2i) -> bool:
	var problem := check_recruit_unit(data_unit, city_coord, army_coord)
	if problem != "":
		push_error(problem)
		return false
	var army : Army = get_army_at(army_coord)
	var city : City = get_city_at(city_coord)
	var cost : Goods = city.get_unit_cost(data_unit)
	var purchased : bool = army.faction.try_to_pay(cost)
	assert(purchased)
	city.on_purchase(data_unit.required_building)
	army.units_data.append(data_unit)
	army.leader_unit_changed.emit()
	WM.world_ui.refresh_army_panel()
	return true


## returns army reference if success/legal, null otherwise
func do_recruit_hero(data_hero : DataHero,
		coord : Vector2i) -> bool:

	var problem := check_recruit_hero(current_player_index, data_hero, coord)
	if problem != "":
		push_error(problem)
		return false
	var city : City = get_city_at(coord)
	var player_state = get_faction_by_index(current_player_index)

	var cost = player_state.get_hero_cost(data_hero)
	var is_purchased : bool = player_state.try_to_pay(cost)
	assert(is_purchased)

	var army : Army = Army.new() # TODO maybe make some function

	# TODO check this hero can be recruited here by game rules

	var hero : Hero
	# now we need to check if this hero was already recruited, but died
	for dead_hero in player_state.dead_heroes:
		if dead_hero.template == data_hero:
			dead_hero.revive()
			dead_hero.controller_index = current_player_index
			hero = dead_hero
	if not hero: # means no hero is revived
		hero = Hero.construct_hero(data_hero, current_player_index)
		army.units_data.append(player_state.race.units_data[0])  # fresh hero starts with a level 1 unit

	army.hero = hero
	army.controller_index = city.controller_index
	army.coord = coord
	army.faction = WS.player_states[city.controller_index]

	# Absorbs city garrison
	army.units_data.append_array(city.garrison_reserve.units_data)
	city.garrison_reserve.units_data = []
	WM.world_ui.load_army_to_panel(army)
	WM.world_ui.refresh_army_panel()

	city.move_to_reserve()

	grid.get_hex(coord).army = army
	player_state.hero_armies.append(army)

	WM.callback_army_created(army)

	return true


func do_build_building(coord : Vector2i, building : DataBuilding) -> bool:
	var problem := check_build_building(coord, building)
	if problem != "":
		push_error(problem)
		return false
	var city := get_city_at(coord)
	return city.build_building(building)


#endregion City Economy


#region Combat

func start_combat_by_attack(armies : Array[Army], source : Vector2i, \
		target : Vector2i) -> void:
	move_hold_on_combat = [source, target]
	WM.start_combat(armies, target)



## Awards exp, applies losses, moves armies that were on hold duo to battle taking place
func end_combat(battle_results : Array[BattleGridState.ArmyInBattleState]) -> void:
	for army_state in battle_results:
		var army = army_state.army_reference
		if army.is_neutral:
			army.faction = null
			army.controller_index = -1

		if army.hero:
			army_state.killed_units.sort()  # from lowest to highest

			var hero_level_threshold_modifier : int = 0
			for passive : HeroPassive in army.hero.passive_effects:
				if passive.passive_name == "sage":
					hero_level_threshold_modifier -= 1

			# we aim to award hero as much as possible
			for killed_unit : int in army_state.killed_units:
				if army.hero.level + hero_level_threshold_modifier <= killed_unit:
					army.hero.add_xp(1)


		if not army_state.can_fight():
			remove_army(army)
		else:
			army.apply_losses(army_state.dead_units)

	# TODO document this variable, and how it works better
	if move_hold_on_combat.size() < 1:
		return  # don't process moves if none were on hold

	var source : Vector2i = move_hold_on_combat[0]
	var target : Vector2i = move_hold_on_combat[1]
	if check_army_travel(source, target) == "":
		do_army_travel(source, target)


## Kills army called once it was defeated
func remove_army(army : Army) -> void:
	assert(army == get_army_at(army.coord))
	var hex : WorldHex = grid.get_hex(army.coord)
	hex.army = null
	var player_index = army.controller_index
	var player = get_faction_by_index(player_index)
	if player:
		var army_array = player.hero_armies
		assert(army in army_array)
		army_array.erase(army)
		player.dead_heroes.append(army.hero)
		WS.perform_game_over_checks()  # Can end the game on the spot
	# think about when is this ref counted object destroyed
	WM.callback_army_destroyed(army)

#endregion Combat


#region Army Movement

func do_start_trade(source : Vector2i, target : Vector2i) -> bool:
	var problem := check_start_trade(source, target)
	if problem != "":
		push_error(problem)
		return false
	return true


## basic hero move
func do_army_travel(source : Vector2i, target : Vector2i) -> bool:
	var problem = check_army_travel(source, target)
	if problem != "":
		push_error(problem)
		return false
	WM.world_ui.try_to_close_context_menu() # TODO awaits server authorative to properly block players from still trading while being away

	var army : Army = get_army_at(source)

	if is_enemy_at(target, army.controller_index):
		var enemy_army : Army = get_army_at(target)
		if not enemy_army.hero and enemy_army.units_data.size() == 0:  # checks if player isn't attacking an empty city
			get_city_at(target).move_to_reserve()
		else:
			var fighting_armies : Array[Army] = [army, enemy_army]
			start_combat_by_attack(fighting_armies, source, target)
			return true

	var spent = army_spend_movement_points(army, 1)
	assert(spent)

	print("moving ", army," to ", target)
	change_army_position(army, target)
	get_place_at(target).interact(army)
	return true


## returns true when points points are spent, false when could not
func army_spend_movement_points(army : Army, points : int) -> bool:
	if not army_can_spend_movement_points(army, points):
		return false
	army.hero.movement_points -= points
	return true


func change_army_position(army : Army, target_coord : Vector2i) -> void:
	assert(get_army_at(army.coord) == army, "army coord desync")
	var source_hex = grid.get_hex(army.coord)
	var target_hex = grid.get_hex(target_coord)
	assert(target_hex, \
		"can't place armies on non existing tile %s" % target_coord)
	assert(not target_hex.army, \
		"can't place armies on occupied tile %s" % target_coord)
	source_hex.army = null
	if source_hex.place is City:
		army.hero.is_in_city = false
		var number_of_units_to_be_left : int = army.units_data.size() - army.max_army_size

		for unit_over_limit_idx in range(number_of_units_to_be_left):
			source_hex.place.garrison_reserve.units_data.append(army.units_data[-unit_over_limit_idx - 1])
			army.units_data.pop_back()

		WM.world_ui.refresh_army_panel()
		source_hex.place.move_out_of_reserve()
	target_hex.army = army
	army.coord = target_coord
	WM.callback_army_updated(army)


func swap_armies(first_army : Army, second_army : Army) -> void:
	var source : Vector2i = first_army.coord
	var target : Vector2i = second_army.coord
	first_army.hero.movement_points -= 1
	if second_army.hero:
		# Not entering city, assumes both armies have sufficient movement points
		assert(first_army.hero.movement_points > 0 and second_army.hero.movement_points > 0,
		"attempt to swap armies that don't have sufficient movement points")

		second_army.hero.movement_points -= 1

		var source_hex = grid.get_hex(first_army.coord)
		var target_hex = grid.get_hex(second_army.coord)
		source_hex.army = second_army
		target_hex.army = first_army
		first_army.coord = target
		second_army.coord = source
		WM.callback_army_updated(first_army)
		WM.callback_army_updated(second_army)

	else: # attempt to enter a city
		var city_coord : Vector2i = target  # during trade city is always treated as second army
		var city : City = WS.get_city_at(city_coord)
		city.move_to_reserve()
		change_army_position(first_army, target)


#endregion Army Movement

#endregion Player Turn


#region End Turn + Start of The Game - Special Events

func do_end_turn() -> void:
	_end_of_turn_callbacks(current_player_index)
	if current_player_index == player_states.size() - 1:
		_end_of_round_callbacks()
	current_player_index = (current_player_index + 1) % player_states.size()
	WM.callback_turn_changed()


## this function spawns an army from preset on given coord [br]
## Used for places at end of turn and start of the game
func spawn_army_from_preset(army_preset : PresetArmy, coord : Vector2i, \
		player_index : int) -> void:
	if get_army_at(coord):
		push_error("tried to spawn army at occupied tile")
		# TODO make option for neutral army to spawn and attack player
	print("spawn army at %s" % coord)
	var army = Army.create_from_preset(army_preset)
	army.coord = coord
	army.controller_index = player_index
	if player_index == -1:
		army.is_neutral = true

	# TODO add this army to player armies array
	grid.get_hex(coord).army = army
	WM.callback_army_created(army)


#STUB
func _end_of_turn_callbacks(player_index : int) -> void:
	pass


func _end_of_round_callbacks() -> void:
	for x in range(grid.width):
		for y in range(grid.height):
			var coord = Vector2i(x,y)
			var army : Army = grid.get_hex(coord).army
			if army:
				army.on_end_of_round()
			var place : Place = grid.get_hex(coord).place
			if place:
				place.on_end_of_round()

	for faction_idx in range(player_states.size() - 1, -1, -1):
		var faction : Faction = player_states[faction_idx]
		if faction.cities.size() == 0:
			faction.defeat_turn_timer -= 1

	perform_game_over_checks()


## can activate end game screen
func perform_game_over_checks() -> bool:
	for faction_idx in range(player_states.size() - 1, -1, -1):
		var faction : Faction = player_states[faction_idx]
		if faction.has_faction_lost():
			player_states.erase(faction)
			defeated_factions.append(faction)
			#print(faction.controller.get_full_player_description(), "has been defeated")
			if player_states.size() == 1:
				WM.player_has_won_a_game()
				return true
	return false

#endregion End Turn + Start of The Game - Special Events


#region Networking

func to_network_serializable() -> SerializableWorldState:
	var result := SerializableWorldState.new()
	for col_index in grid.hexes.size():
		var col = grid.hexes[col_index]
		for hex_index in col.size():
			var coord = Vector2i(col_index, hex_index)
			var hex = col[hex_index]
			assert(hex)
			var place = hex.place
			# TODO later handle modified places (changed to basic)
			# (if ever needed)
			if place and not place.is_basic():
				result.place_hexes[coord] = \
					Place.get_network_serializable(place)
			var army = hex.army
			if army:
				result.army_hexes[coord] = _get_serialized_army(army)
	result.players.resize(player_states.size())
	for player_index in player_states.size():
		var player = player_states[player_index]
		result.players[player_index] = SerializableWorldState.PlayerState.new()
		var result_player = result.players[player_index]
		result_player.goods = player.goods.to_array()
		result_player.armies.resize(player.hero_armies.size())
		for army_index in player.hero_armies.size():
			result_player.armies[army_index] = \
				player.hero_armies[army_index].coord
		result_player.dead_heroes.resize(player.dead_heroes.size())
		for dead_hero_index in player.dead_heroes.size():
			result_player.dead_heroes[dead_hero_index] = \
				player.dead_heroes[dead_hero_index] \
					.to_network_serializable()
		result_player.outpost_buildings.resize(player.outpost_buildings.size())
		for outpost_building_index in player.outpost_buildings.size():
			result_player.outpost_buildings[outpost_building_index] = \
				DataBuilding.get_network_id(
					player.outpost_buildings[outpost_building_index])
	result.current_player = current_player_index
	return result


func _get_serialized_army(army) -> Dictionary:
	var army_dict : Dictionary = {}
	army_dict["player"] = army.controller_index

	if army.hero:
		var hero : Hero = army.hero
		army_dict["hero"] = hero.to_network_serializable()

	army_dict["units"] = []
	var unit_array = army_dict["units"]
	for unit in army.units_data:
		unit_array.append(DataUnit.get_network_id(unit))

	return army_dict


static func deserialize_army(dict : Dictionary) -> Army:
	var army : Army = Army.new()
	army.controller_index = dict["player"]
	if "hero" in dict:
		army.hero = Hero.from_network_serializable(dict["hero"], dict["player"])
	for unit_ser in dict["units"]:
		army.units_data.append(DataUnit.from_network_id(unit_ser))
	return army

#endregion Networking

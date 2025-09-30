# Singleton - WM
extends GridNode2D

signal world_move_done


@onready var world_ui : WorldUI = preload("res://Scenes/UI/World/WorldUi.tscn").instantiate()

## Only army that has a hero can move (army can only have a single hero)
var selected_hero : ArmyForm

var selected_city : City:
	set(city):
		if city and not selected_hero:
			world_ui.load_army_to_panel(city.garrison_reserve)

		selected_city = city
		world_ui.city_ui.city = city

var selected_ritual : Ritual  # TODO move to world ui

# TODO movew to world state chyba
var combat_tile : Vector2i

var _batch_mode : bool = false

var tile_grid : Node2D = null
var armies : Node2D = null

var _is_world_game_active : bool = false


var _painter_node : BattlePainter

#region Start World

func _ready() -> void:
	tile_grid = Node2D.new()
	tile_grid.name = "GRID"
	add_child(tile_grid)
	armies = Node2D.new()
	armies.name = "ARMIES"
	add_child(armies)

	UI.add_custom_screen(world_ui)

	_painter_node = load("res://Scenes/UI/Battle/BattlePlanPainter.tscn").instantiate()
	add_child(_painter_node)

#endregion Start World


#region helpers

## Camera bounds
func get_bounds_global_position() -> Rect2:
	if not world_game_is_active():
		push_warning("asking not initialized grid for camera bounding box")
		return Rect2(0, 0, 0, 0)
	var top_left_hex = WS.get_top_left_hex()
	var bottom_right_hex = WS.get_bottom_right_hex()
	var top_left_tile_form : TileForm = get_tile_of_hex(top_left_hex)
	var bottom_right_tile_form : TileForm = get_tile_of_hex(bottom_right_hex)
	var size : Vector2 = \
		bottom_right_tile_form.global_position - \
		top_left_tile_form.global_position
	return Rect2(top_left_tile_form.global_position, size)


func get_current_player_capital() -> City:
	var player_state = WS.get_faction_by_index(WS.current_player_index)
	assert(player_state)
	return player_state.capital_city


func world_game_is_active() -> bool:
	return _is_world_game_active

#endregion helpers


#region Main functions

func set_selected_hero(army : Army) -> void:
	print("selected ", army)
	if selected_hero:
		selected_hero.set_selected(false)
	var army_form : ArmyForm = get_army_form(army)
	selected_hero = army_form
	selected_hero.set_selected(true)

	world_ui.refresh_heroes()
	world_ui.city_ui._refresh_units_to_buy()
	world_ui.city_ui._refresh_army_display()

	world_ui.load_army_to_panel(army)

	if CFG.WORLD_GOD_MODE:
		WM.hero_speed_cheat()
		WM.hero_level_up(6)
		#TODO move city upgrade logic to selecting cities
		WM.city_upgrade_cheat()
		WM.cheat_money()

	_painter_node.erase()
	_draw_path()


func _deselect_hero() -> void:
	if not selected_hero:
		return
	selected_hero.set_selected(false)
	selected_hero = null
	world_ui.refresh_heroes()
	world_ui.city_ui._refresh_units_to_buy()
	world_ui.city_ui._refresh_army_display()
	world_ui.hide_army_panel()

	_painter_node.erase()


func get_current_player() -> Player:
	var index : int = WS.current_player_index
	return IM.get_player_by_index(index)


func end_turn():
	var world_move_info = WorldMoveInfo.make_end_turn()
	try_do_move(world_move_info)


func callback_turn_changed():
	world_ui.on_end_turn()
	_deselect_hero()
	var current_faction : Faction = WS.get_current_player()
	if current_faction.has_faction_lost():
		end_turn()
		return

	world_ui.refresh_heroes()
	var current_player_capital : City = get_current_player_capital()
	if current_player_capital:  # player may have lost his last city
		world_ui.set_viewed_city(current_player_capital)
	world_ui.refresh_player_buttons()


## this function may be temporary, the sure thing is it needs to be made better
func get_army_form(army : Army) -> ArmyForm:
	for army_form in armies.get_children():
		if army_form.entity == army:
			return army_form
	return null


## this function may be temporary, the sure thing is it needs to be made better
func get_tile_of_hex(hex : WorldHex) -> Node2D:
	for tile_form in tile_grid.get_children():
		if tile_form.hex == hex:
			return tile_form
	return null

#endregion Main functions


#region Player Actions

## generation travel path for the currently selected hero
func _generate_path(destination_coord : Vector2i, hero : ArmyForm = null) -> void:
	if not hero:  # Could be used by AI to generate paths for all their heroes
		hero = selected_hero

	var path : Array[Vector2i] = []

	## In case there is no path between coord, path will be empty
	var path_indexes : PackedInt64Array = WS.pathfinding.get_id_path(WS.coord_to_index[selected_hero.coord], WS.coord_to_index[destination_coord])
	for hex_index in path_indexes:
		var hex_coord : Vector2i = WS.coord_to_index.find_key(hex_index)
		path.append(hex_coord)
	hero.travel_path = path


## if hero isn't passed draws currently selected hero path
func _draw_path(hero : ArmyForm = null):
	if not hero:  # Could be used to draw AI desired paths during debuging
		hero = selected_hero
	if not hero or hero.travel_path.size() == 0:
		return
	var is_it_dangerous : bool = false
	for hex_coord in hero.travel_path:
			if WS.is_enemy_at(hex_coord, WS.current_player_index):
				is_it_dangerous = true
				break

	_painter_node.draw_path(hero.travel_path, is_it_dangerous)


## Called when player interacts (presses) on the map tile
## Selects objects OR orders selected object
## City/Heroes -> orders Heroes
func grid_input(coord : Vector2i):
	print("world input @", coord)

	if BM.should_block_world_interaction():
		print("blocked by BM - Battle Manager")
		return

	if selected_hero == null:  # SELECT HERO
		input_try_select(coord)
		return

	if selected_ritual:
		if is_ritual_target_valid(coord):
			cast_ritual(coord)
		return


	if selected_hero.coord == coord:  # DESELECT HERO
		_deselect_hero()
		return

	if not WS.is_hex_movable(coord):
		return


	if selected_hero.travel_path.size() == 0 or selected_hero.travel_path[-1] != coord:  # Generate Path
		_generate_path(coord)
		_painter_node.erase()
		_draw_path()
		return

	# Player has pressed again on the last tile of the chosen path
	# through which he will now travel

	for tile_idx in range(1, selected_hero.travel_path.size()):  # ignores the tile hero starts at
		if selected_hero.has_movement_points():
			# TODO add passing through allied heroes
			try_interact(selected_hero, selected_hero.travel_path[tile_idx])
		else:
			break

	if selected_hero:  # game might have ended
		selected_hero.travel_path = [] as Array[Vector2i] # TODO make changes to travel path dynamic
		if not selected_hero.has_movement_points():
			_deselect_hero()
	_painter_node.erase()


## Tries to Select owned Hero
func input_try_select(coord) -> void:  #TODO "nothing is selected try to select stuff"
	var selection = WS.get_interactable_at(coord)
	var city = WS.get_city_at(coord)
	var army = WS.get_army_at(coord)
	if army and army.hero:
		if WS.current_player_index == selection.controller_index:
			set_selected_hero(army)

	## also preselects for player city in case hero is standing on top of it
	if city:
		if city.controller_index == WS.current_player_index:
			selected_city = city
			if not army:
				world_ui.city_ui.show_recruit_heroes()
			else:
				world_ui.city_ui.show_recruit_units()


func try_interact(hero : ArmyForm, coord : Vector2i):
	var start_coords = hero.coord
	var second_army = WS.get_army_at(coord)
	if second_army and second_army.controller_index == hero.entity.controller_index: # we start trade instead of travel
		trade_armies(second_army)
		return
	var world_move_info := \
		WorldMoveInfo.make_world_travel(start_coords, coord)
	try_do_move(world_move_info)


## called on input from player
func try_do_move(world_move_info : WorldMoveInfo) -> void:
	var problem = WS.check_move_allowed(world_move_info)
	if problem != "":
		print(problem)
		return
	if not NET.client:
		perform_world_move_info(world_move_info)
	else:
		NET.client.queue_request_world_move(world_move_info)


## opens context menu selected hero army and second owned army present target tile
func trade_armies(second_army : Army):
	print("trading armies")
	world_ui.show_trade_ui(selected_hero.entity, second_army)


## called by `try_do_move` or when move is received from network
func perform_world_move_info(world_move_info : WorldMoveInfo) -> void:
	print(NET.get_role_name(), " performing world move ", world_move_info)
	# TODO replay.record_move
	# TODO replay.save
	if NET.server:
		NET.server.broadcast_world_move(world_move_info)
	var success = WS.do_move(world_move_info)
	if not success:
		NET.desync()
		return
	world_move_done.emit()


func perform_network_move(world_move_info : WorldMoveInfo) -> void:
	perform_world_move_info(world_move_info)


func temp_cast_first_ritual() -> void:
	if selected_ritual:
		selected_ritual = null
		return

	if not selected_hero: #TODO make it an assert
		printerr("No selected hero")
		return

	if selected_hero.entity.hero.rituals.size() == 0: #TODO make it an assert
		printerr("selected_ritual is not present on a hero")
		return


	selected_ritual = selected_hero.entity.hero.rituals[0]


func is_ritual_target_valid(target_coord : Vector2i = Vector2i.ZERO) -> bool:
	assert(selected_hero, "No selected hero")
	assert(selected_ritual, "no selected_ritual")
	assert(selected_ritual in selected_hero.entity.hero.rituals, "selected_ritual is not present on a hero")

	var shaman_present : bool = false
	var hero : Hero = selected_hero.entity.hero
	for passive in hero.passive_effects:
		if passive.passive_name == "shaman":
			shaman_present = true

	if hero.movement_points + hero.ritual_cost_reduction <= 0 or \
		(not shaman_present and \
		hero.movement_points + hero.ritual_cost_reduction < selected_ritual.mp_cost): #TODO make it an assert
		print("hero doesn't have enough movement points left")
		return false


	match selected_ritual.name:
		"Town Portal":
			## TODO add selecting city to teleport to / implement logic to select closest/last visited city
			var target_city : City = WS.get_city_at(target_coord)
			if not target_city:
				print("no destination for town portal spell")
				return false
			return true
		"Steal", "Fear":  # any neutral army # TODO add check if army is adjacent to caster
			var target_neutral_army : Army = WS.get_army_at(target_coord)
			if not target_neutral_army:
				print("no army at destination")
				return false
			if target_neutral_army.faction:
				print("army at destination is not neutral")
				return false
			return true

	assert(false, "ritual is not supported")
	return false



func cast_ritual(target_coord : Vector2i = Vector2i.ZERO) -> void:
	assert(selected_hero, "No selected hero")
	assert(selected_ritual, "no selected_ritual")
	assert(selected_ritual in selected_hero.entity.hero.rituals, "selected_ritual is not present on a hero")


	var hero : Hero = selected_hero.entity.hero

	var cost : int = selected_ritual.mp_cost
	var reduction : int = min(hero.ritual_cost_reduction, cost)

	cost -= reduction
	hero.ritual_cost_reduction -= reduction

	hero.movement_points -= cost

	hero.rituals.erase(selected_ritual)

	print(selected_ritual)
	match selected_ritual.name:
		"Town Portal":
			## TODO implement logic to select closest/last visited city
			var target_city : City = WS.get_city_at(target_coord)
			assert(target_city, "no destination for town portal spell")

			# TODO check if army is present
			WS.change_army_position(selected_hero.entity, target_coord)
			target_city.interact(selected_hero.entity)
		"Steal":
			print("Casted Steal")
			pass
		"Fear":
			print("Casted Fear")
			pass
		_:
			assert(false, "ritual casting not supported: " + selected_ritual.name)
			return


	selected_ritual = null

#endregion Player Action


#region City Management

func try_recruit_unit(city_coord : Vector2i, army_coord : Vector2i,
		unit : DataUnit):
	var world_move_info = \
		WorldMoveInfo.make_recruit_unit(city_coord, army_coord, unit)
	try_do_move(world_move_info)


func try_recruit_hero(city : City, hero_data : DataHero) -> void:
	var world_move_info = WorldMoveInfo.make_recruit_hero( \
		city.controller_index,
		hero_data,
		city.coord)
	try_do_move(world_move_info)


func request_build(city : City, building_data : DataBuilding) -> void:
	var world_move_info = WorldMoveInfo.make_build(city.coord, building_data)
	if not NET.client:
		perform_world_move_info(world_move_info)
	else:
		NET.client.queue_request_world_move(world_move_info)


func do_local_travel(source : Vector2i, target : Vector2i) -> void:
	var success : bool = WS.army_travel(source, target)

	if not success:
		NET.desync()
		return

#endregion City Management


#region Battles

func start_combat( \
		armies_ : Array[Army], \
		combat_coord : Vector2i, \
		battle_state : SerializableBattleState = null):
	"""
	Starts a battle using Battle Manager (BM)
	"""
	print("start_combat")
	#TODO verify with design if biggest army size code is needed
	var biggest_army_size : int = 0
	for army in armies_:
		var army_size : int = army.units_data.size()
		if biggest_army_size < army_size:
			biggest_army_size = army_size


	# Give control over the neutral armies to players not present in battle
	# which don't have any allies partaking in it.
	# We assume that battles involving neutrals cannot contain number of unique
	# teams + neutral armies equal to number of teams in the game
	# TODO create tests for maps to verify number of unique teams for special neutral armies encounters to take into account this system

	# counting unique teams
	var teams_present_in_battle : Array[int] = []
	for army in armies_:
		# neutral armies don't have army controller and they are neutral
		# if more than two neutral armies are present in battle they oppose eachother
		if army.controller and army.controller.team not in teams_present_in_battle:
			teams_present_in_battle.append(army.controller.team)

	# assigning players to control neutrals
	var player_idx_to_control_neutral : int = WS.current_player_index
	for army in armies_:
		if army.controller: # we search only for neutral armies
			continue
		while not army.controller:
			player_idx_to_control_neutral -= 1  # we look for previous player to play as neutrals
			if player_idx_to_control_neutral == -1:  # Search from the end
				player_idx_to_control_neutral = WS.player_states.size() - 1
			# no need to verify if player has been assigned, as each neutral has to be controlled by unique team anyway.
			var player : Player = WS.player_states[player_idx_to_control_neutral].controller
			if player.team not in teams_present_in_battle:
				#TODO refactor armies so that we have clear seperation from checking who can attack who, and who gets to control those units.
				#As the current getter for controller from faction may not be correct
				army.faction = WS.player_states[player_idx_to_control_neutral] # Setting up the player to control the army
				army.controller_index = player_idx_to_control_neutral # TEMP
				teams_present_in_battle.append(player.team)

	combat_tile = combat_coord
	var battle_map : DataBattleMap = WS.get_battle_map_at(combat_tile, biggest_army_size)
	var x_offset = get_bounds_global_position().end.x + CFG.MAPS_OFFSET_X
	BM.start_battle(armies_, battle_map, x_offset, battle_state)
	UI.switch_camera()


func end_of_battle(battle_results : Array[BattleGridState.ArmyInBattleState]):

	WS.end_combat(battle_results)

	UI.go_to_custom_ui(world_ui)
	AUDIO.play_music("world")


#endregion Battles


#region World End


func player_has_won_a_game() -> void:
	_is_world_game_active = false

	var new_summary = _create_summary()

	UI.ui_overlay.show_world_summary(new_summary, IM.go_to_main_menu)


## Major function which fully generates information panel at the end of the world
func _create_summary() -> DataWorldSummary:
	var summary := DataWorldSummary.new()

	var winning_team : int = WS.player_states[0].controller.team
	var winning_team_players : Array[Player] = []

	var all_faction : Array[Faction] = WS.player_states
	all_faction.append_array(WS.defeated_factions)

	# Generate information for every player
	for faction in all_faction:
		var player_stats := DataWorldSummaryPlayer.new()

		# Generate heroes info
		var heroes : Array[Hero] = faction.dead_heroes
		for army in faction.hero_armies:
			heroes.append(army.hero)


		for hero in heroes:
			var hero_description = "%s\n" % hero.hero_name
			player_stats.heroes += hero_description

		var player = faction.controller

		# generates player names for their info column
		player_stats.player_description = player.get_full_player_description()

		if player.team == winning_team:
			player_stats.state = "winner"
			winning_team_players.append(player)

			# TEMP solution - better color system described in TODO notes
			summary.color = player.get_player_color().color
		else:
			player_stats.state = "loser"
		summary.players.append(player_stats)

	# Summary title creation
	assert(winning_team_players.size() > 0, "World ended without any winners")

	var team_name : String = "Team %s" % winning_team_players[0].team
	summary.title = "%s wins" % [team_name]
	var sep : String = " : "
	for player in winning_team_players:
		summary.title += sep + player.get_player_color().name
		sep = ", "

	return summary



func clear_world():
	_is_world_game_active = false
	combat_tile = Vector2i.MAX
	_deselect_hero()

	for army_form in armies.get_children():
		army_form.queue_free()
	for tile in tile_grid.get_children():
		tile.queue_free()

#endregion World End


#region World Setup

func start_new_world(world_map : DataWorldMap) -> void:

	_is_world_game_active = true

	WS.start_world(world_map, IM.game_setup_info.slots)

	recreate_tile_forms()
	recreate_army_forms()

	UI.go_to_custom_ui(world_ui)
	world_ui.on_game_started()

	selected_city = get_current_player_capital()
	world_ui.set_viewed_city(selected_city)
	world_ui.refresh_heroes()
	AUDIO.play_music("world")


#STUB
# this function probably should be divided into parts
func start_world_in_state(world_map : DataWorldMap, \
		serializable_WS : SerializableWorldState) -> void:

	_is_world_game_active = true

	# TODO probably check serializable_WS not null

	_batch_mode = true

	WS.start_world(
		world_map, IM.game_setup_info.slots, serializable_WS)

	recreate_tile_forms()
	recreate_army_forms()

	UI.go_to_custom_ui(world_ui)
	world_ui.on_game_started()

	world_ui.set_viewed_city(get_current_player_capital())
	world_ui.refresh_heroes()

	_batch_mode = false


func spawn_player(coord : Vector2i, player : Player):
	var capital_city = WS.get_city_at(coord)
	player.set_capital(capital_city)


func recreate_tile_forms() -> void:
	Helpers.remove_all_children(tile_grid)
	for x in range(WS.grid.width):
		for y in range(WS.grid.height):
			var coord := Vector2i(x, y)
			var hex : WorldHex = WS.grid.get_hex(coord)
			var tile : TileForm = TileForm.create_world_tile_new(hex, coord, \
				to_position(coord))
			tile_grid.add_child(tile)


func recreate_army_forms() -> void:
	Helpers.remove_all_children(armies)
	for x in range(WS.grid.width):
		for y in range(WS.grid.height):
			var coord := Vector2i(x, y)
			var hex : WorldHex = WS.grid.get_hex(coord)
			if not hex.army:
				continue
			var new_position = to_position(coord)
			var army_form : ArmyForm = ArmyForm.create_form_of_army(hex, \
				new_position)
			armies.add_child(army_form)

#endregion World Setup


#region Callbacks

func _refresh_army_form_position(army_form : ArmyForm) -> void:
	army_form.position = to_position(army_form.entity.coord)


func callback_player_created(_player : Player) -> void:
	return # does nothing yet -- TODO add something or delete in future


func callback_army_created(army : Army) -> void:
	var coord = army.coord
	var hex = WS.grid.get_hex(coord)
	var new_position = to_position(coord)
	var army_form : ArmyForm = ArmyForm.create_form_of_army(hex, \
		new_position)
	armies.add_child(army_form)


## TODO make it full update, along with imgae etc.
## now bo mi się nie chce it is only position :>
func callback_army_updated(army : Army) -> void:
	callback_army_moved(army)


func callback_army_moved(army : Army) -> void:
	var army_form = get_army_form(army)
	_refresh_army_form_position(army_form)


func callback_army_destroyed(army : Army) -> void:
	var army_form = get_army_form(army)
	if selected_hero == army_form:
		_deselect_hero()
	army_form.queue_free()


func callback_place_changed(coord : Vector2i) -> void:
	var _hex = WS.grid.get_hex_at(coord)
	return


func callback_combat_started(armies_ : Array, coord_ : Vector2i) -> void:
	start_combat(armies_, coord_)

#endregion Callbacks


#region Multiplayer

func get_serializable_state() -> SerializableWorldState:
	var state := SerializableWorldState.new()
	if world_game_is_active():
		state = WS.to_network_serializable()
	return state

#endregion Multiplayer


#region UI Information

func show_army_units(tile_coord : Vector2i) -> void:
	var army : Army = WS.get_army_at(tile_coord)
	if army:
		world_ui.load_army_to_panel(army)

#endregion UI Information


#region Cheats

## Add goods to the player
func cheat_money(new_wood : int = 100, new_iron : int = 100, new_ruby : int = 100) -> void:
	WS.get_current_player().goods.add(
		Goods.new(new_wood, new_iron, new_ruby)
	)


## Add movement points to a hero
func hero_speed_cheat(speed : int = 100) -> void:
	if not selected_hero:
		print("no selected hero")
		return
	WM.selected_hero.entity.hero.movement_points += speed


## Level up hero n times
func hero_level_up(levels : int = 1) -> void:
	if not selected_hero:
		print("no selected hero")
		return

	for i in range(levels):
		selected_hero.entity.hero._level_up()
	# After leveling up xp is a negative value
	selected_hero.entity.hero.xp = 0


func city_upgrade_cheat() -> void:
	var current_player : Faction = WS.get_current_player()

	# Iterate over every race building
	for building in current_player.race.buildings:
		# Copied from build_building function
		if not building.is_outpost_building():
			world_ui.city_ui.city.buildings.append(building)
		else:
			current_player.outpost_buildings.append(building)
	# Update UI
	world_ui.city_ui._refresh_buildings_display()


#endregion Cheats

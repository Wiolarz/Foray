class_name AIWorldBotRandom
extends AIWorldInterface


## pairs of heroes (hero_name) and their map coord targets
var hero_targets : Dictionary[String, Army] = {}

const level_up_build = [
	 # 1 tier
	[[false, 0, 0]],
	[[false, 1, 0], [true, 0, 0]],
	# 2 tier
	[[false, 0, 1], [true, 0, 1]],
	[[false, 1, 1]],
	# 3 tier
	[[false, 0, 2], [true, 0, 2]],
	[[false, 1, 2]]
]

func _hero_level_up(hero : Hero) -> void:
	for level in range(hero.level):
		var level_selection = level_up_build[level]
		for choice in level_selection:
			hero.add_passive_from_tree(choice[1], choice[2], choice[0])


func choose_move() -> WorldMoveInfo:

	var goods_spending_moves : Array[WorldMoveInfo] = WS.get_all_goods_spending_moves()
	if goods_spending_moves.size() > 0:
		return goods_spending_moves[randi_range(0, goods_spending_moves.size() - 1)]

	var combat_destinations : Array[Vector2i] = WS.get_all_combat_destinations()
	combat_destinations.shuffle()

	var faction = WS.player_states[WS.current_player_index]

	## MOVING HEROES AROUND THE MAP
	for army : Army in faction.hero_armies:
		_hero_level_up(army.hero) # if after winning a battle bot moves once again, it can level up
		#continue # Disable moving for tests
		## Search for potential targets
		if army.hero.hero_name not in hero_targets.keys():
			for destination : Vector2i in combat_destinations:
				if WS.pathfinding.get_id_path(
						WS.coord_to_index[army.coord], WS.coord_to_index[destination]).size() == 0:
					continue  # there is no viable path to the target

				var target_army : Army = WS.get_army_at(destination)
				var combat_difficulty : int = WS.assess_combat_difficulty(army, target_army)

				if combat_difficulty >= 2:
					hero_targets[army.hero.hero_name] = target_army
					break


		if army.hero.hero_name not in hero_targets.keys():
			continue # didn't found any suitable target

		if army.hero.movement_points == 0:
			continue

		WM.ai_generate_path(army, hero_targets[army.hero.hero_name].coord)

		var neighbor_army : Army = WS.get_army_at(army.hero.travel_path[1])
		if neighbor_army and neighbor_army.controller and neighbor_army.controller.team == me.team:
			continue

		var move := WorldMoveInfo.make_world_travel(army.coord, army.hero.travel_path[1])
		army.hero.travel_path.pop_front()
		if army.hero.travel_path.size() == 1:
			hero_targets.erase(army.hero.hero_name)

		return move

	for army : Army in faction.hero_armies:
		for ritual : Ritual in army.hero.rituals:
			match ritual.name:
				"Town Portal":
					pass
				_:
					continue # ritual is currently unsupported by AI
			if not WS.is_ritual_purchasable(ritual, army.hero):
				continue
			var possible_targets : Array[Vector2i] = WS.get_all_ritual_targets(army.hero, ritual)
			if possible_targets.size() == 0:
				continue
			return WorldMoveInfo.make_ritual(army.coord, possible_targets.pick_random(), ritual)

	# if army no longer has movement points,
	# but it could have leveled up during on last move try leveling up
	for army : Army in faction.hero_armies:
		_hero_level_up(army.hero)

	return WorldMoveInfo.make_end_turn()

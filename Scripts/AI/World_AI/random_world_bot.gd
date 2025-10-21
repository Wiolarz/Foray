class_name AIWorldBotRandom
extends AIWorldInterface


var hero_targets : Dictionary = {} # hero name and object armyform as target


func choose_move() -> WorldMoveInfo:

	var goods_spending_moves : Array[WorldMoveInfo] = WS.get_all_goods_spending_moves()
	if goods_spending_moves.size() > 0:
		return goods_spending_moves[randi_range(0, goods_spending_moves.size() - 1)]

	var combat_destinations : Array[Vector2i] = WS.get_all_combat_destinations()
	combat_destinations.shuffle()

	var faction = WS.player_states[WS.current_player_index]

	## MOVING HEROES AROUND THE MAP
	for army in faction.hero_armies:
		continue

		## Search for potential targets
		if army.hero.hero_name not in hero_targets.keys():
			for destination : Vector2i in combat_destinations:
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
			possible_targets.shuffle()
			return WorldMoveInfo.make_ritual(army.coord, possible_targets[0], ritual)



	return WorldMoveInfo.make_end_turn()

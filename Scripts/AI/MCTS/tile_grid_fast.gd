class_name TileGridFast
extends TileGridFastCpp


static func from(bgstate: BattleGridState):
	var new = TileGridFast.new()
	new.set_map_size(Vector2i(bgstate.width, bgstate.height))

	for x in bgstate.width:
		for y in bgstate.height:
			var pos = Vector2i(x,y)
			var hex = bgstate._get_battle_hex(pos)

			var army_id = hex.spawn_point_army_idx
			if hex.is_mana_tile():
				assert(army_id == -1, "Tile in TileGridFast cannot be spawn and mana tile at the same time");
				if hex.mana_controller:
					army_id = bgstate.armies_in_battle_state.find(hex.mana_controller)

			new.set_tile(pos,
				hex.can_be_moved_to,
				not hex.can_shoot_through,
				hex.swamp,
				hex.is_mana_tile(),
				hex.pit,
				hex.hill,
				army_id,
				hex.spawn_direction
			)
	return new

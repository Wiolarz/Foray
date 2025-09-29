class_name MapBorder
extends Node2D


static func from_map(grid: DataGenericMap) -> MapBorder:
	var border = MapBorder.new()
	border.name = "BORDER"

	for x in range(-CFG.BATTLE_BORDER_WIDTH, grid.grid_width + CFG.BATTLE_BORDER_WIDTH):
		for y in range(-CFG.BATTLE_BORDER_HEIGHT, grid.grid_height + CFG.BATTLE_BORDER_HEIGHT):
			if (x >= 0 and x < grid.grid_width) and (y >= 0 and y < grid.grid_height):
				continue

			var coord = Vector2i(x, y)
			var tile_form
			if grid is DataBattleMap:
				tile_form = TileForm.create_battle_tile(RES.load("res://Resources/Battle/Battle_tiles/sentinel.tres"), coord)
				tile_form.position = BM.to_position(coord)
			else:
				tile_form = TileForm.create_world_tile(RES.load(CFG.SENTINEL_TILE_PATH), coord, null)
				tile_form.position = WM.to_position(coord)

			border.add_child(tile_form)

	return border

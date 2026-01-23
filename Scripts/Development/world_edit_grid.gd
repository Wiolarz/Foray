class_name WorldEditGrid
extends GridNode2D


var grid : GenericHexGrid = \
	GenericHexGrid.new(0, 0, WorldEditGrid.create_empty_tile())


static func create_empty_tile() -> DataTile:
	return load(CFG.SENTINEL_TILE_PATH)


func load_map(map : DataWorldMap) -> void:
	# TODO in future read only type and depending on this, select data_tile
	resize(Vector2i(map.grid_width, map.grid_height))
	for x in range(map.grid_width):
		for y in range(map.grid_height):
			var coord := Vector2i(x, y)
			var data_tile : DataTile = map.grid_data[x][y]
			paint(coord, data_tile)


func size() -> Vector2i:
	return Vector2i(grid.width, grid.height)


func coord_in_bounds(coord : Vector2i) -> bool:
	return coord.x >= 0 and coord.x < grid.width \
		and coord.y >= 0 and coord.y < grid.height


func resize(v : Vector2i) -> void:
	var old_size : Vector2i = Vector2i(grid.width, grid.height)
	grid.resize(v.x, v.y)
	var x_min : int = min(v.x, old_size.x)
	var y_min : int = min(v.y, old_size.y)
	var x_max : int = max(v.x, old_size.x)
	var y_max : int = max(v.y, old_size.y)
	var sentinel = WorldEditGrid.create_empty_tile()
	for x in range(x_max):
		for y in range(y_max):
			if x < x_min and y < y_min:
				continue
			var data_tile : DataTile = null
			var coord = Vector2i(x, y)
			if coord_in_bounds(coord):
				data_tile = sentinel
			_set_or_reset_tile_form(coord, data_tile)



func paint(coord : Vector2i, data_tile : DataTile) -> void:
	if not coord_in_bounds(coord):
		return
	grid.set_hex(coord, data_tile)
	_find_tile_form(coord).paint(data_tile)


func get_current_map(trim : bool) -> DataWorldMap:
	var tiles_present : Array[DataTile] = []
	var top_left = Vector2i(0, 0)
	var bot_right = Vector2i(grid.width, grid.height)
	if trim:
		top_left = _find_real_top_left()
		bot_right = _find_real_bot_right()
	var map : DataWorldMap = DataWorldMap.new()
	map.grid_width = bot_right.x - top_left.x + 1
	map.grid_height = bot_right.y - top_left.y + 1
	print("top left:  %s" % top_left)
	print("bot right: %s" % bot_right)
	print("grid size: %s" % Vector2i(map.grid_width, map.grid_height))
	var grid_data = []
	for x in range(top_left.x, bot_right.x + 1):
		var column = []
		for y in range(top_left.y, bot_right.y + 1):
			var tile_data : DataTile = grid.get_hex(Vector2i(x, y))
			if tile_data:
				tile_data = tile_data.duplicate()
			else:
				tile_data = WorldEditGrid.create_empty_tile()

			var is_it_the_same_tile : bool = false
			for saved_tile in tiles_present:
				if tile_data.is_this_the_same_tile(saved_tile):
					tile_data = saved_tile
					is_it_the_same_tile = true
					break

			if not is_it_the_same_tile:
				tiles_present.append(tile_data)

			column.append(tile_data)
		grid_data.append(column)
	WorldEditGrid._make_nulls_sentinels(grid_data)
	map.grid_data = grid_data
	return map


func get_tile_grid_data() -> Array:
	return grid.hexes


func _set_or_reset_tile_form(coord : Vector2i, data_tile : DataTile) -> void:
	var tile_form = _find_tile_form(coord)
	if tile_form and data_tile:
		data_tile.paint(data_tile)
	elif tile_form and not data_tile:
		tile_form.queue_free()
	elif not tile_form and data_tile:
		var new_tile_form = TileForm.create_world_editor_tile(data_tile, coord,
			to_position(coord))
		add_child(new_tile_form)


func _find_tile_form(coord : Vector2i) -> TileForm:
	return get_node_or_null("Tile_%s_%s" % [ coord.x, coord.y ]) as TileForm


func _find_real_top_left() -> Vector2i:
	var row = 0
	var col = 0
	while _row_empty(row) and row < grid.height:
		row += 1
	while _column_empty(col) and col < grid.width:
		col += 1
	if col >= grid.width or row >= grid.height: # empty map so set 0 everywhere
		col = 0
		row = 0
	return Vector2i(col, row)


func _find_real_bot_right() -> Vector2i:
	var row = grid.height - 1
	var col = grid.width - 1
	while _row_empty(row) and row >= 0:
		row -= 1
	while _column_empty(col) and col >= 0:
		col -= 1
	if col < 0 or row < 0: # empty map so set map to one sentinel
		col = 0
		row = 0
	return Vector2i(col, row)


func get_bounding_box_rect() -> Rect2:
	var top_left_tile_form : TileForm = _find_tile_form(_find_real_top_left())
	var bottom_right_tile_form : TileForm = _find_tile_form(_find_real_bot_right())
	var box_size : Vector2 = \
		bottom_right_tile_form.global_position - \
		top_left_tile_form.global_position
	return Rect2(top_left_tile_form.global_position, box_size)


func _find_max_player_number() -> int:
	var players : Array[int] = []
	for x in grid.width:
		for y in grid.height:
			var coord := Vector2i(x, y)
			var tile = grid.get_hex(coord)
			var args : PackedStringArray = tile.type.split(' ')
			if args.size() < 1 or args[0] != "city":
				continue

			var player_index : int = City.translate_city_args(args.slice(1))["player_index"]
			if player_index < 0:
				continue
			if player_index >= players.size():
				players.resize(player_index + 1)
			players[player_index] += 1
	for number in players:
		if number < 1:
			push_error("Error: some player does not have a city")
			return -1
	return players.size()


func _row_empty(index : int):
	if index < 0 or index >= grid.height:
		return true
	for i in grid.width:
		var tile = grid.hexes[i][index]
		if tile and tile.type != "SENTINEL":
			return false
	return true


func _column_empty(index : int):
	if index < 0 or index >= grid.width:
		return true
	for i in grid.height:
		var tile = grid.hexes[index][i]
		if tile and tile.type != "SENTINEL":
			return false
	return true


static func _make_nulls_sentinels(grid_data : Array) -> void:
	var sentinel = create_empty_tile()
	for column in grid_data:
		for index in column.size():
			if column[index] == null:
				column[index] = sentinel

class_name TileForm

extends Area2D

var coord : Vector2i

var type : String = "SENTINEL"

var hex = null # WorldHex in world

var grid_type : GameSetupInfo.GameMode = GameSetupInfo.GameMode.WORLD


static func create_world_editor_tile(data_tile : DataTile, coord_ : Vector2i,
		new_position : Vector2) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	result._set_coord(coord_)
	result.name = "Tile_%s_%s" % [ coord_.x, coord_.y ]
	result.position = new_position
	if data_tile:
		var image = RES.load(data_tile.texture_path)
		result.type = data_tile.type
		result._set_texture(image)
	return result



## ugly, FIXME TEMP TODO
static func create_world_tile_new(world_hex : WorldHex, coord_ : Vector2i, \
		new_position : Vector2) -> TileForm:
	var result : TileForm = CFG.HEX_TILE_FORM_SCENE.instantiate()
	var image := world_hex.get_image()
	result.type = "SENTINEL"
	if world_hex.place:
		assert(coord_ == world_hex.place.coord)
		result.type = world_hex.place.get_type()
	result._set_coord(coord_)
	result._set_texture(image)
	result.name = "Tile_%s_%s" % [ coord_, result.type ]
	result.position = new_position
	result.hex = world_hex
	var place : Place = result.hex.place
	place.controller_changed.connect(result.controller_changed)
	return result


static func create_world_tile(data: DataTile, new_coord : Vector2i, \
		new_place : Place) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	result._set_coord(new_coord)
	result._set_texture(RES.load(data.texture_path))
	result.type = data.type
	result.place = new_place
	result.name = "Tile_" + str(new_coord) + "_" + data.type
	return result


static func create_battle_tile(data: DataTile, new_coord : Vector2i) -> TileForm:
	var result = CFG.HEX_TILE_FORM_SCENE.instantiate()
	result.grid_type = GameSetupInfo.GameMode.BATTLE
	result.type = data.type
	result._set_coord(new_coord)

	result.name = "Tile_" + str(new_coord) + "_" + data.type
	var sprite : Sprite2D = result.get_node("Sprite2D")
	if data.is_it_deploy_tile():
		sprite.rotation_degrees = data.get_spawn_direction() * 60
		if IM.in_map_editor: # loading the map in editor
			sprite.texture = CFG.DEPLOY_TILES_TEXTURES[data.get_player_ownership()]
		else:
			sprite.texture = CFG.DEPLOY_TILES_TEXTURES[IM.players[data.get_player_ownership()].color_idx]
	else:
		sprite.texture = RES.load(data.texture_path)
		sprite.rotation_degrees = 0
	return result


func _on_input_event(_viewport : Node, event : InputEvent, _shape_idx : int):
	# normal gameplay - on click
	if event.is_action_pressed("KEY_SELECT"):
		UI.grid_input_listener(coord, grid_type, false)

	# normal gameplay - on right click (purely visual "planning tool" for players to draw chess arrows)
	if Input.is_action_pressed("KEY_PLAN"):
		UI.grid_planning_input_listener(coord, grid_type, true)
	elif Input.is_action_just_released("KEY_PLAN"):
		UI.grid_planning_input_listener(coord, grid_type, false)

	# for map editor - on mouse move while button pressed
	if Input.is_action_pressed("KEY_SELECT"):
		UI.grid_input_listener(coord, grid_type, true)


func _process(_delta):
	$PlaceLabel.text = ""
	if hex and hex.place:
		$PlaceLabel.text = hex.place.get_map_description()


func controller_changed():
	var controller : Player = IM.get_player_by_index(hex.place.controller_index)
	var color_name : String = controller.get_player_color().name
	var path =  "%s%s_color.png" % [CFG.PLAYER_COLORS_PATH, color_name]
	var texture = RES.load(path) as Texture2D
	assert(texture, "failed to load background " + path)
	$ControllerColor.texture = texture


## for map editor only
func paint(brush : DataTile) -> void:
	type = brush.type
	$Sprite2D.texture = RES.load(brush.texture_path)
	if brush.is_it_deploy_tile():
		$Sprite2D.texture = CFG.DEPLOY_TILES_TEXTURES[int(type[DataTile.DEPLOY_PLAYER_INDEX]) - 1]
		$Sprite2D.rotation_degrees = brush.get_spawn_direction() * 60
	elif brush.is_it_city_tile():
		var _neutral := false
		if int(type[DataTile.CITY_PLAYER_INDEX]) == DataTile.NEUTRAL_CITY:
			$ControllerColor.texture = CFG.NEUTRAL_STRONG_COLOR_TEXTURE
			_neutral = true
		else: # Player city
			$ControllerColor.texture = CFG.CITY_STRONG_COLOR_TEXTURES[int(type[DataTile.CITY_PLAYER_INDEX])  - 1]

		if int(type[DataTile.CITY_RACE_INDEX]) == DataTile.ANY_RACE_CITY: ## TEMP
			assert(not _neutral, "attempt to paint neutral any city, advanced race cities are not yet implemented")
			return
		$Sprite2D.texture = RES.load(CFG.RACES_LIST[int(type[DataTile.CITY_RACE_INDEX]) - 1].city_texture_path)


func set_hovered(is_hovered : bool):
	assert(material is ShaderMaterial)
	var intensity = 0.1 if is_hovered else 0.0
	material.set_shader_parameter("highlight_intensity", intensity)


func _set_coord(new_coord: Vector2i):
	coord = new_coord
	$CoordLabel.text = str(new_coord)

func _set_texture(texture: Texture2D):
	$Sprite2D.texture = texture



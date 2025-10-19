extends Panel

@onready var button_columns : Array[VBoxContainer] = [ \
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column1,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column2,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column3]


@onready var tile_information_title = $Margin/VBoxContainer/HBoxContainer/TileInformationContainer/VBox/TileName
@onready var tile_information_description = $Margin/VBoxContainer/HBoxContainer/TileInformationContainer/VBox/RichTextLabel
@onready var tile_information_icon = $Margin/VBoxContainer/HBoxContainer/TileInformationContainer/VBox/TextureRect

@onready var button_template : Resource = load("res://Scenes/UI/Wiki/WorldWiki/WikiWorldTileButton.tscn")

func _ready():
	generate_terrain_buttons()

## INIT
func generate_terrain_buttons() -> void:
	# clean mockup ui
	for column in button_columns:
		Helpers.remove_all_children(column)

	var path = CFG.WORLD_MAP_TILES_PATH
	var dir = DirAccess.open(path)
	var tile_idx : int = -1
	for world_tile_file_path in dir.get_files():
		tile_idx += 1

		var world_tile : DataTile = load(path + world_tile_file_path)
		if tile_idx == 0:  # load first tile automatically
			load_tile(world_tile)

		var button : WikiTerrainButton = button_template.instantiate()
		button_columns[tile_idx % button_columns.size()].add_child(button)
		button.load_tile(world_tile)

		button.selected.connect(load_tile)


func load_tile(world_tile : DataTile) -> void:
	tile_information_title.text = world_tile.type.capitalize()
	tile_information_icon.texture = load(world_tile.texture_path)

	match world_tile.type:
		# Basic Tile Types
		"WALL":
			tile_information_description.text = "Unpassable Terrain"

		# Complex Tile Types
		_ when world_tile.type.begins_with("city"):
			tile_information_description.text = \
"Player main base, upon loosing it, player is only few turns away from defeat if he doesn't recapture it"
		_ when world_tile.type.begins_with("hunt"):
			tile_information_description.text = \
"Defended tile with constantly respawing enemy, which provide goods upon defeat
read more on Economy page"
		_ when world_tile.type.begins_with("outpost"):
			tile_information_description.text = \
"Defended but capturable goods producing tile, read more on Economy page"
		_:
			tile_information_description.text = ""

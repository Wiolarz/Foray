extends Panel

@onready var button_columns : Array[VBoxContainer] = [ \
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column1,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column2,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column3]


@onready var tile_information_title = $Margin/VBoxContainer/HBoxContainer/TileInformationContainer/VBox/TileName
@onready var tile_information_description = $Margin/VBoxContainer/HBoxContainer/TileInformationContainer/VBox/RichTextLabel
@onready var tile_information_icon = $Margin/VBoxContainer/HBoxContainer/TileInformationContainer/VBox/TextureRect

@onready var button_template : Resource = load("res://Scenes/UI/Wiki/BattleWiki/WikiBattleTileButton.tscn")

func _ready():
	generate_terrain_buttons()


## INIT
func generate_terrain_buttons() -> void:
	# clean mockup ui
	for column in button_columns:
		Helpers.remove_all_children(column)

	var path = CFG.BATTLE_MAP_TILES_PATH
	var dir = DirAccess.open(path)
	var tile_idx : int = -1
	for world_tile_file_path in dir.get_files():
		tile_idx += 1

		var battle_tile : DataTile = load(path + world_tile_file_path)
		if tile_idx == 0:  # load first tile automatically
			load_tile(battle_tile)

		var button : WikiTerrainButton = button_template.instantiate()
		button_columns[tile_idx % button_columns.size()].add_child(button)
		button.load_tile(battle_tile)

		button.selected.connect(load_tile)


func load_tile(battle_tile : DataTile) -> void:
	tile_information_title.text = battle_tile.type.capitalize() # TODO generate better name based on type
	tile_information_icon.texture = load(battle_tile.texture_path)
	match battle_tile.type:
		"wall": tile_information_description.text = \
"Special Move Tile - you can only move toward it if you faced it before starting the move.

Stops ranged attacks- but not if you stand on top of it.

In case of pushing acts as a wall."

		"hole": tile_information_description.text = \
"Special Move Tile - you can only move toward it if you faced it before starting the move.
Upon moving toward it unit is moved to the opposite tile
which needs to be free and moveable to allow move to occur

In case of pushing immidietly kills, even if it's the last tile someone were to be pushed to."

		"swamp": tile_information_description.text = \
"Units present on this tile have their weapons disabled, and all sides are treated as empty"

		"mana_well": tile_information_description.text = \
"Capturable special mana providing tile, for more information read Mana Cyclone page"

		_: tile_information_description.text = ""

class_name DataTile

extends Resource

@export var type : String

@export var texture_path : String

@export var flip_horizontal : bool = false

static func create_data_tile(hex_tile : TileForm) -> DataTile:
	var new_data_tile = DataTile.new()

	var sprite_node : Sprite2D = hex_tile.get_node("Sprite2D")
	var new_path = sprite_node.texture.resource_path
	new_data_tile.texture_path = new_path

	new_data_tile.type = hex_tile.type

	return new_data_tile


func apply_data(tile : TileForm) -> void:
	tile.get_node("Sprite2D").texture = ResourceLoader.load(texture_path)
	tile.type = type


func is_spawn_tile() -> bool:
	return type == "city" or type == "elf_city" or type == "orc_city"

class_name DataTile
extends Resource

## hardcoded name in SCREAMING_SNAKE_CASE like WALL or EMPTY [br]
## or snake_case Place name (name of script containing derived class from [br]
## Place)
@export var type : String

@export var texture_path : String

## TODO - yet to be implemented
@export var flip_horizontal : bool = false


static func create_data_tile(hex_tile : TileForm) -> DataTile:
	var new_data_tile = DataTile.new()

	var sprite_node : Sprite2D = hex_tile.get_node("Sprite2D")
	var new_path = sprite_node.texture.resource_path
	new_data_tile.texture_path = new_path

	new_data_tile.type = hex_tile.type

	return new_data_tile

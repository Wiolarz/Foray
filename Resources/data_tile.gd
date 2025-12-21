class_name DataTile
extends Resource

## hardcoded name in SCREAMING_SNAKE_CASE like WALL or EMPTY [br]
## or snake_case Place name (name of script containing derived class from [br]
## Place)
@export var type : String

@export_file var texture_path : String

## TODO - yet to be implemented
@export var flip_horizontal : bool = false


func is_it_deploy_tile() -> bool:
	return DataTile.is_type_deploy_tile(type)


static func is_type_deploy_tile(tile_type : String) -> bool:
	return tile_type.ends_with("_player_spawn")


func is_it_city_tile() -> bool:
	return DataTile.is_type_city_tile(type)


static func is_type_city_tile(tile_type : String) -> bool:
	return tile_type.ends_with("_city")


## if no ownership returns -1
func get_player_ownership() -> int:
	return DataTile.get_type_player_ownership(type) - 1


static func get_city_race(city_type : String) -> DataRace:
	var race_idx = int(city_type[CITY_RACE_INDEX])
	if race_idx == 0:
		return null # any race
	race_idx -= 1
	return CFG.RACES_LIST[race_idx]


static func get_type_player_ownership(tile_type : String) -> int:
	if not tile_type[PLAYER_INDEX].is_valid_int():
		return -1
	return tile_type[PLAYER_INDEX].to_int()



func get_spawn_direction() -> int:
	assert(type.ends_with("_player_spawn"), "checked spawn direction for not spawn tile")
	return int(type[SPAWN_DIRECTION_INDEX])


# MAGIC NUMBERS
const PLAYER_INDEX := 0
const SPAWN_DIRECTION_INDEX := 2
const CITY_RACE_INDEX := 2

const NEUTRAL_CITY := 0
const ANY_CITY := 0

static func create_data_tile(hex_tile : TileForm) -> DataTile:
	var new_data_tile = DataTile.new()

	var sprite_node : Sprite2D = hex_tile.get_node("Sprite2D")
	var new_path = sprite_node.texture.resource_path
	new_data_tile.texture_path = new_path

	new_data_tile.type = hex_tile.type

	return new_data_tile


func is_this_the_same_tile(another_tile : DataTile) -> bool:
	if type != another_tile.type:
		return false
	elif texture_path != another_tile.texture_path:
		return false
	elif flip_horizontal != another_tile.flip_horizontal:
		return false
	return true

class_name DataTile
extends Resource

## hardcoded name in SCREAMING_SNAKE_CASE like WALL or EMPTY [br]
## or snake_case Place name (name of script containing derived class from [br]
## Place)
@export var type : String

@export_file var texture_path : String

## TODO - yet to be implemented
@export var flip_horizontal : bool = false

# MAGIC NUMBERS
## TODO change the logic to utilize spaces between parameters or rework the tile types
const DEPLOY_PLAYER_INDEX := 13
const SPAWN_DIRECTION_INDEX := 15

const CITY_RACE_INDEX := 7
const CITY_PLAYER_INDEX := 5
const NEUTRAL_CITY := 0
const ANY_RACE_CITY := 0


#region Generic

## returns player idx -> tile_1 is a 1st player tile, returns 0
## tile_0 is neutral returns as -1
func get_player_ownership() -> int:
	return DataTile.get_type_player_ownership(type) - 1


static func get_type_player_ownership(tile_type : String) -> int:
	var used_type := DEPLOY_PLAYER_INDEX
	if DataTile.is_type_city_tile(tile_type):
		used_type = CITY_PLAYER_INDEX
	if not tile_type[used_type].is_valid_int():
		return -1
	return tile_type[used_type].to_int()


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

#endregion Generic


#region BATTLE

func is_it_deploy_tile() -> bool:
	return DataTile.is_type_deploy_tile(type)


static func is_type_deploy_tile(tile_type : String) -> bool:
	return tile_type.begins_with("player_deploy")


func get_spawn_direction() -> int:
	assert(type.begins_with("player_deploy"), "checked spawn direction for not spawn tile")
	return int(type[SPAWN_DIRECTION_INDEX])

#endregion BATTLE


#region WORLD

func is_it_city_tile() -> bool:
	return DataTile.is_type_city_tile(type)


static func is_type_city_tile(tile_type : String) -> bool:
	return tile_type.begins_with("city")


static func get_city_race(city_type : String) -> DataRace:
	var race_idx = int(city_type[CITY_RACE_INDEX])
	if race_idx == 0:
		return null # any race
	race_idx -= 1
	return CFG.RACES_LIST[race_idx]

#endregion WORLD

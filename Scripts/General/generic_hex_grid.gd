class_name GenericHexGrid
extends RefCounted #default

## used to specify direction on a hex grid
enum GridDirections
{
	LEFT,
	TOP_LEFT,
	TOP_RIGHT,
	RIGHT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT,
}

const INT_MIN = -9223372036854775808 # we really need issue 2411 in godot
const DIRECTION_FRONT = GridDirections.LEFT
const TILES_NOT_ADJACENT = -1
const COORD_NOT_EXIST := Vector2i(INT_MIN, INT_MIN)

## see E.GridDirections
const DIRECTION_TO_OFFSET = [ \
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 1),
]

var width : int
var height : int
var hexes : Array = [] # Array[Array[HexType]]
var sentinel : Variant


func _init(width_ : int, height_ : int, sentinel_ : Variant):
	sentinel = sentinel_
	resize(width_, height_)


func resize(width_ : int, height_ : int):
	var old_width = width

	height = height_
	width = width_

	hexes.resize(width)
	if old_width < width:
		for x in range(old_width, width):
			hexes[x] = []
	for x in range(width):
		hexes[x].resize(height)


func is_on_grid(coord : Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 \
		and coord.x < width and coord.y < height


func get_hex(coord : Vector2i) -> Variant:
	if not is_on_grid(coord):
		return sentinel
	var hex = hexes[coord.x][coord.y]
	if not hex:
		return sentinel
	return hex


func set_hex(coord : Vector2i, value : Variant) -> void:
	assert(is_on_grid(coord), "set_hex not on a grid "+str(coord))
	hexes[coord.x][coord.y] = value


func find(hex) -> Vector2i:
	for x in width:
		for y in height:
			if hexes[x][y] == hex:
				return Vector2i(x, y)
	return COORD_NOT_EXIST


static func direction_to_name(d : GridDirections) -> String:
	return GridDirections.keys()[d]


static func rotate_clockwise(direction : GridDirections, sides : int) -> GridDirections:
	return (direction + sides) % 6 as GridDirections


static func opposite_direction(direction : GridDirections) -> GridDirections:
	return rotate_clockwise(direction, 3)


static func is_adjacent(coord1 : Vector2i, coord2 : Vector2i) -> bool:
	return direction_to_adjacent(coord1, coord2) != TILES_NOT_ADJACENT


## Direction from coord1 to coord2 if adjacent
## Or TILES_NOT_ADJACENT if not adjacent
static func direction_to_adjacent(coord1 : Vector2i, coord2 : Vector2i) -> int:
	return DIRECTION_TO_OFFSET.find(coord2 - coord1)


static func adjacent_coord(coord : Vector2i, side : int) -> Vector2i:
	return coord + DIRECTION_TO_OFFSET[side]


static func distant_coord(coord : Vector2i, side : int, distance:int) -> Vector2i:
	return coord + distance * DIRECTION_TO_OFFSET[side]


static func axial_distance(start_coord : Vector2i, end_coord : Vector2i) -> int:
	return (abs(start_coord.x - end_coord.x) \
		+ abs(start_coord.x + start_coord.y - end_coord.x - end_coord.y) \
		+ abs(start_coord.y - end_coord.y)) / 2


static func is_tile_faced(start_coord : Vector2i, end_coord : Vector2i) -> bool:
	if start_coord.x + start_coord.y == end_coord.x + end_coord.y: # diagonal top right bot left
		return true
	elif start_coord.x == end_coord.x and start_coord.y != end_coord.y: # horizontal
		return true
	elif start_coord.x != end_coord.x and start_coord.y == end_coord.y: # diagonal top left bot right
		return true
	return false


static func is_tile_in_straight_direction(start_coord : Vector2i, end_coord : Vector2i, direction : GridDirections) -> bool:
	if start_coord == end_coord:
		return true

	match direction:
		GridDirections.LEFT, GridDirections.RIGHT:
			if start_coord.y != end_coord.y:
				return false
		GridDirections.TOP_LEFT, GridDirections.BOTTOM_RIGHT:
			if start_coord.x != end_coord.x:
				return false
		GridDirections.TOP_RIGHT, GridDirections.BOTTOM_LEFT:
			if start_coord.x + start_coord.y != end_coord.x + end_coord.y:
				return false

	match direction:
		GridDirections.LEFT:
			return start_coord.x > end_coord.x
		GridDirections.RIGHT:
			return start_coord.x < end_coord.x
		GridDirections.TOP_LEFT:
			return start_coord.y > end_coord.y
		GridDirections.BOTTOM_RIGHT:
			return start_coord.y < end_coord.y
		GridDirections.TOP_RIGHT:
			return start_coord.x < end_coord.x
		GridDirections.BOTTOM_LEFT:
			return start_coord.x > end_coord.x
		_:
			assert(false)
			return false

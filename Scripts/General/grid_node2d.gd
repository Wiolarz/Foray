class_name GridNode2D
extends Node2D

## Base class for putting grids in 2d space in a tree.
## E.g. for visualising grid data, handling click events etc

const VISUAL_EMPTY_BORDER = 20.0 # Hex Sprite draw gaps
#const TILE_OFFSET_HORIZONTAL_PER_X : float = 529.0 + VISUAL_EMPTY_BORDER # current sprite size 529
#const TILE_OFFSET_HORIZONTAL_PER_Y : float = TILE_OFFSET_HORIZONTAL_PER_X / 2
#const TILE_OFFSET_VERTICAL_PER_Y : float = (608 + VISUAL_EMPTY_BORDER) * 0.75

const TILE_OFFSET_HORIZONTAL_PER_X : float = (1730) + VISUAL_EMPTY_BORDER # current sprite size 529
const TILE_OFFSET_HORIZONTAL_PER_Y : float = TILE_OFFSET_HORIZONTAL_PER_X / 2
const TILE_OFFSET_VERTICAL_PER_Y : float = (1993 + VISUAL_EMPTY_BORDER) * 0.75

var horizontal_offset : float = 0.0

func to_position(coord : Vector2i) -> Vector2:
	var horizontal = coord.x * TILE_OFFSET_HORIZONTAL_PER_X
	horizontal += coord.y * TILE_OFFSET_HORIZONTAL_PER_Y
	horizontal += horizontal_offset
	var vertical = coord.y * TILE_OFFSET_VERTICAL_PER_Y
	return Vector2(horizontal, vertical)


func get_bounds_global_position() -> Rect2:
	assert(false, "get_bounds_global_position not implemented")
	return Rect2()

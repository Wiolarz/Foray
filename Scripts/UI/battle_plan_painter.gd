class_name BattlePainter
extends Node2D


var new_arrow : ChessArrow
var arrows_to_draw : Array[ChessArrow] = []  # Array[Array[Vector2]]

func update_drawings() -> void:
	#multi stuff
	print("test")
	queue_redraw()



func _draw():
	var _line_width : float = 80.0

	for arrow : ChessArrow in arrows_to_draw:
		if arrow.draw_path.size() == 1:
			continue  # we don't draw lines for pointers
		var color : Color = BattlePainter.get_color_from_index(arrow.color_idx)
		draw_polyline(arrow.draw_path, color, _line_width)


func erase():
	arrows_to_draw = []
	Helpers.remove_all_children(self)
	update_drawings()


static func get_color_from_index(color_idx : int) -> Color:
	var color : Color = Color.WHITE_SMOKE  # default 0 value
	match color_idx:
		1:
			color = Color.BLUE
		2:
			color = Color.ORANGE
		3:
			color = Color.LIGHT_GREEN
		4:
			color = Color.INDIAN_RED
		5:
			color = Color.BLACK
		6:
			color = Color.PINK
		7:
			color = Color.PURPLE
	return color


#region Planning (Chess arrows)

## Draws a single pointer on a tile, those are cleared by any normal (left click) input
func planning_input( \
		tile_coord : Vector2i, \
		is_it_pressed : bool, \
		position_calculator : GridNode2D \
) -> void:
	if is_it_pressed:
		if not new_arrow:
			var arrow_color_idx = 0
			if Input.is_key_pressed(KEY_CTRL):
				arrow_color_idx += 1
			if Input.is_key_pressed(KEY_ALT):
				arrow_color_idx += 2
			if Input.is_key_pressed(KEY_SHIFT):
				arrow_color_idx += 4

			new_arrow = \
				ChessArrow.creat_chess_arrow(arrow_color_idx, tile_coord, position_calculator)
			arrows_to_draw.append(new_arrow)
			#add_child(new_arrow.end_node)
			return

		if tile_coord not in new_arrow.hex_path:
			new_arrow.add_hex(tile_coord)
			update_drawings()
		return

	# mouse press is released, draw final
	if not new_arrow:
		# edge case when godot input is strange and registers mouse unlicking from object which it didnt click
		return

	add_child(new_arrow.end_node)
	update_drawings()
	new_arrow = null  # reset arrow path

## if there is an danger along the path, line turnes red
func draw_path( \
		path : Array[Vector2i], \
		position_calculator : GridNode2D, \
		danger : bool = false \
) -> void:
	var arrow_color_idx = 0  # default white
	if danger:
		arrow_color_idx += 4  # RED

	new_arrow = \
		ChessArrow.creat_chess_arrow(arrow_color_idx, path[0], position_calculator)
	arrows_to_draw.append(new_arrow)
	for idx in range(1, path.size()):
		new_arrow.add_hex(path[idx])

	add_child(new_arrow.end_node)
	update_drawings()


class ChessArrow:
	var color_idx : int = 0
	var hex_path : Array[Vector2i] = []
	var draw_path : Array[Vector2] = []

	var arrow_end_scene = CFG.PLAN_ARROW_END_SCENE.instantiate()
	var pointer_scene = CFG.PLAN_POINTER_SCENE.instantiate()

	var end_node : Node2D = pointer_scene

	var position_calculator : GridNode2D = null


	static func creat_chess_arrow(
			color_idx_ : int, \
			first_coord : Vector2, \
			position_calculator_ : GridNode2D
	) -> ChessArrow:
		var new_arrow := ChessArrow.new()
		new_arrow.color_idx = color_idx_
		new_arrow.hex_path = [first_coord]
		new_arrow.position_calculator = position_calculator_
		var new_pos = position_calculator_.to_position(first_coord)
		new_arrow.end_node.position = new_pos
		new_arrow.draw_path = [new_pos]
		new_arrow.end_node.modulate = BattlePainter.get_color_from_index(color_idx_)
		new_arrow.arrow_end_scene.modulate = BattlePainter.get_color_from_index(color_idx_)
		return new_arrow


	func add_hex(coord : Vector2i) -> void:
		hex_path.append(coord)
		draw_path.append(to_position(coord))
		_update_end_node()


	func to_position(coord : Vector2i) -> Vector2:
		assert(position_calculator)
		if not position_calculator:
			return Vector2.ZERO
		return position_calculator.to_position(coord)


	func _update_end_node() -> void:
		#end_node.queue_free()
		end_node = arrow_end_scene
		var offset = hex_path[-2] - hex_path[-1]  # angle between last two coords
		var rotation_value = GenericHexGrid.DIRECTION_TO_OFFSET.find(offset) * PI / 3
		end_node.rotation = rotation_value

		end_node.position = draw_path[-1]

#endregion Planning (Chess arrows)

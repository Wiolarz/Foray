class_name PolyCamera
extends Camera2D

const ZOOM_CHANGE_LINEAR_SPEED = 0.3
const ZOOM_CHANGE_EXPONENTIAL_SPEED = 3.6
const MOVE_SPEED = 40.0

# Zoom is exponential, it means that every step (one mouse wheel step) magnifies
# map by certain amount relative to current magnification. Variables with
# 'power' in name are exponents of ZOOM_STEP. Also, we have to parameters of
# zoom change speed -- one is 'linear' -- it changes the power linearly, second
# is exponential -- it means that change speed is proportional to difference
# betwoon target and current power (so we have kind of two powers here).
const MAX_ZOOM_POWER = 1
const MIN_ZOOM_POWER = -16
const ZOOM_STEP = pow(2.0, 0.25)
const START_ZOOM := 1.0 # this start value gives nice zoom out effect at start
const START_ZOOM_TARGET : int = -13

var last_mouse_position : Vector2
var target_zoom_power : int = START_ZOOM_TARGET
var current_zoom_power : float = START_ZOOM
var zoom_pivot : Vector2 # pivot which camera zoom moves around
var bounds : Rect2 = Rect2(0,0,10000,10000)

var direction_actions = ["KEY_LEFT", "KEY_RIGHT", "KEY_UP", "KEY_DOWN"]
var directions_pressed = [false, false, false, false]

func process_input_event(event : InputEvent) -> void:
	if event.is_action_pressed("KEY_ZOOM_OUT"):
		target_zoom_out()
	elif event.is_action_pressed("KEY_ZOOM_IN"):
		target_zoom_in()

	for i in range(direction_actions.size()):
		var action = direction_actions[i]
		if not event.is_action(action):
			continue
		directions_pressed[i] = event.is_pressed()

func get_camera_move() -> Vector2:
	var result = Vector2(0,0)
	if (directions_pressed[0]): result.x -= 1
	if (directions_pressed[1]): result.x += 1
	if (directions_pressed[2]): result.y -= 1
	if (directions_pressed[3]): result.y += 1
	return result.normalized()


func process_camera(delta):
	slide_zoom_power(delta)
	change_zoom()

	if Input.is_action_pressed("KEY_DRAG_CAMERA"):
		process_camera_drag()

	position += MOVE_SPEED * get_camera_move()
	position = position.clamp(bounds.position, bounds.end)


func update_pivot():
	zoom_pivot = get_global_mouse_position()


func target_zoom_in() -> void:
	target_zoom_power = min(target_zoom_power + 1, MAX_ZOOM_POWER)
	update_pivot()


func target_zoom_out() -> void:
	target_zoom_power = max(target_zoom_power - 1, MIN_ZOOM_POWER)
	update_pivot()


## makes smooth zoom change
func slide_zoom_power(delta : float) -> void:
	# exponential
	var diff = float(target_zoom_power) - current_zoom_power
	diff *= 1.0 - exp(-delta * ZOOM_CHANGE_EXPONENTIAL_SPEED)
	current_zoom_power += diff

	# linear
	if float(target_zoom_power) > current_zoom_power:
		current_zoom_power = min(
			current_zoom_power + ZOOM_CHANGE_LINEAR_SPEED,
			float(target_zoom_power)
		)
	elif float(target_zoom_power) < current_zoom_power:
		current_zoom_power = max(
			current_zoom_power - ZOOM_CHANGE_LINEAR_SPEED,
			float(target_zoom_power)
	)


## changes actual current zoom to calculated value and makes proper change
## to camera position around pivot
func change_zoom() -> void:
	var old_zoom := zoom
	var diff = zoom_pivot - position
	position = zoom_pivot
	zoom = get_current_zoom()
	position -= diff * old_zoom / zoom


## calculates exact zoom value from all these powers magic
func get_current_zoom() -> Vector2:
	var val = pow(ZOOM_STEP, current_zoom_power)
	return Vector2(val, val)


func center_camera(node: Node2D):
	position = node.position
	zoom_pivot = node.position


func process_camera_drag():
	var current_mouse_position = get_viewport().get_mouse_position()
	if Input.is_action_just_pressed("KEY_DRAG_CAMERA"):
		last_mouse_position = current_mouse_position
	var diff = current_mouse_position - last_mouse_position
	position -= diff / zoom
	last_mouse_position = current_mouse_position


## set camera bounds
func set_bounds(bounds_global_position : Rect2, reset_position : bool = true) -> void:
	bounds = bounds_global_position
	if reset_position:
		position = bounds_global_position.get_center()
		zoom_pivot = position
		current_zoom_power = START_ZOOM
		target_zoom_power = START_ZOOM_TARGET

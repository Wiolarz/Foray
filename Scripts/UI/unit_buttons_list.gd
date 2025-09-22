class_name UnitsButtonsList
extends BoxContainer

signal unit_was_selected()


var loaded_army : Army

## used only for placement unit tiles, points to currently selected unit/unit-button in placement
## bar
var selected_unit_pointer : DataUnit = null
var _selected_unit_button_pointer : BaseButton = null


## used only for placement unit tiles, points to currently hovered unit button in placement bar
## (same set of buttons as _`selected_unit_button_pointer` points to
var _hovered_unit_button_pointer : BaseButton = null

var unit_button_size : float

func load_unit_buttons(army : Army, units_to_display : Array[DataUnit],
						containers : Array[BoxContainer], unit_button_size_ : float = 100.0,
						fill_empty_slots : bool = false, is_clickable : bool = true) -> void:
	# reset object state
	selected_unit_pointer = null
	_selected_unit_button_pointer = null

	loaded_army = army
	unit_button_size = unit_button_size_

	# clean unit icons from rows
	for container in containers:
		for old_button in container.get_children():
			old_button.queue_free()

	var bg_color : DataPlayerColor

	if army.controller:
		bg_color = army.controller.get_player_color()
	else:
		bg_color = CFG.NEUTRAL_COLOR


	var added_icon_idx : int = -1

	for unit : DataUnit in units_to_display:
		added_icon_idx += 1
		# Generating unit buttons

		var unit_display := UnitForm.create_for_deployment_ui(unit, bg_color)

		if army.hero and army.hero.is_in_city and added_icon_idx >= (army.max_army_size - CFG.CITY_MAX_ARMY_SIZE):
			unit_display.set_marked_for_unit_list()  # mark units that breach max army size

		var button = TextureButton.new()
		button.texture_normal = CFG.DEPLOY_BUTTON_TEXTURE
		button.custom_minimum_size = Vector2.ONE * unit_button_size
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true
		unit_display.position = button.texture_normal.get_size()/2
		if not is_clickable:
			button.disabled = true

		var center_container = CenterContainer.new()

		button.add_child(center_container)

		center_container.add_child(unit_display)
		center_container.set_anchors_preset(Control.LayoutPreset.PRESET_CENTER)
		center_container.name = "Center"
		unit_display.name = "UnitForm"
		unit_display.position = Vector2.ZERO


		# TEMP need to find out good way to calculate scale, the constant number
		# here was find empirically
		var calculated_scale = 0.00058 * unit_button_size
		unit_display.scale = Vector2.ONE * calculated_scale

		containers[added_icon_idx % containers.size()].add_child(button)

		if is_clickable:
			button.pressed.connect(_button_on_click.bind(button, unit))

			button.mouse_entered.connect(_button_on_hover.bind(true, button))
			button.mouse_exited.connect(_button_on_hover.bind(false, button))

	if fill_empty_slots:
		_fill_empty_slots(added_icon_idx, containers)


func _fill_empty_slots(added_icon_idx : int, containers : Array[BoxContainer]) -> void:
	var empty_slot = TextureButton.new()
	empty_slot.texture_normal = CFG.EMPTY_SLOT_TEXTURE
	empty_slot.custom_minimum_size = Vector2.ONE * unit_button_size
	empty_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	empty_slot.ignore_texture_size = true

	empty_slot.disabled = true

	for i in range(loaded_army.max_army_size - loaded_army.units_data.size()):
		added_icon_idx += 1
		empty_slot = empty_slot.duplicate()

		if loaded_army.hero and loaded_army.hero.is_in_city and added_icon_idx >= (loaded_army.max_army_size - CFG.CITY_MAX_ARMY_SIZE):
			empty_slot.modulate = Color("ffc7aa") #ffc7aa for debuging use -> #431900

		containers[added_icon_idx % containers.size()].add_child(empty_slot)


## buttons lambda
func _button_on_click(button : Control, unit : DataUnit) -> void:
	if not loaded_army.controller.is_local():  # block multiplayer input
		return
	if _selected_unit_button_pointer:  # Deselects previously selected unit
		_selected_unit_button_pointer.get_node("Center/UnitForm").set_selected(false)

	if _selected_unit_button_pointer == button: # Selecting the same unit twice deselects it
		selected_unit_pointer = null
		_selected_unit_button_pointer = null
	else:
		selected_unit_pointer = unit
		_selected_unit_button_pointer = button
		_selected_unit_button_pointer.get_node("Center/UnitForm").set_selected(true)
		unit_was_selected.emit()


## buttons lambda
func _button_on_hover(is_hovered : bool, button : Control) -> void:
	if _hovered_unit_button_pointer:
		_hovered_unit_button_pointer.get_node("Center/UnitForm").set_hovered(false)

	if is_hovered:
		_hovered_unit_button_pointer = button
		_hovered_unit_button_pointer.get_node("Center/UnitForm").set_hovered(true)
	else:
		_hovered_unit_button_pointer = null


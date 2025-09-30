extends Control

@onready var first_army_panel : VBoxContainer = $HBoxContainer/FirstTradeArmyPanel
@onready var second_army_panel : VBoxContainer = $HBoxContainer/SecondTradeArmyPanel

## Selected hero from World Manager
var first_army : Army
## Could be a second hero or a city garrison
var second_army : Army


func _ready():
	first_army_panel.unit_was_selected.connect(_attempt_a_unit_transfer)
	second_army_panel.unit_was_selected.connect(_attempt_a_unit_transfer)
	first_army_panel.army_swap.connect(_army_swap)
	second_army_panel.army_swap.connect(_army_swap)


func start_trade(first_army_ : Army, second_army_ : Army) -> void:
	first_army = first_army_
	second_army = second_army_
	first_army_panel.load_army(first_army)
	second_army_panel.load_army(second_army)


func _attempt_a_unit_transfer() -> void:
	## one of the armies is full, and they swap units
	if first_army_panel.selected_unit_pointer and second_army_panel.selected_unit_pointer:
		_succesful_transfer()
		return

	# attempt to move unit from first army to the second:
	if first_army_panel.selected_unit_pointer and second_army.units_data.size() < second_army.max_army_size:
		_succesful_transfer()
		return

	# attempt to move unit from second army to the first:
	if second_army_panel.selected_unit_pointer and first_army.units_data.size() < first_army.max_army_size:
		_succesful_transfer()
		return


func _succesful_transfer() -> void:
	var unit : DataUnit
	if first_army_panel.selected_unit_pointer:
		unit = first_army_panel.selected_unit_pointer
		first_army.units_data.erase(unit)
		second_army.units_data.append(unit)

	if second_army_panel.selected_unit_pointer:
		unit = second_army_panel.selected_unit_pointer
		second_army.units_data.erase(unit)
		first_army.units_data.append(unit)

	# Update Visuals
	first_army_panel.transfered_unit()
	second_army_panel.transfered_unit()


func _army_swap() -> void:
	#print("army swap")
	if first_army.hero.movement_points <= 0:
		return
	## You can always move into a city, so we check only "first" army
	## if there is no hero in second army it's a city
	if second_army.hero and second_army.hero.movement_points <= 0:
		return

	WS.swap_armies(first_army, second_army)
	if not second_army.hero:  # ENTERING CITY
		first_army.hero.is_in_city = true
		if second_army.units_data.size() > 0:  # merging city garrison into hero's army
			first_army.units_data.append_array(second_army.units_data)
			second_army.units_data = []
			WM.world_ui.refresh_army_panel()
		end_trade()  # UX: entering city closes trade screen


func end_trade() -> void:
	WM.world_ui.try_to_close_context_menu()


func _on_close_button_pressed():
	end_trade()

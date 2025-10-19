extends UnitsButtonsList


signal army_swap()


const UNIT_BUTTON_SIZE : float = 130.0

@onready var units_box_first_column : BoxContainer = $Units/FirstColumn
@onready var units_box_second_column : BoxContainer = $Units/SecondColumn


func _ready() -> void:
	$HeroButton.pressed.connect(_attemp_army_swap)


func load_army(army : Army):

	if not army.hero:
		# player can "swap" places with city garrison even though there is no hero there
		var city : City = WS.get_city_at(army.coord)
		assert(city,
		"attempt to trade with an army without a hero, which isn't a city garrison")
		$HeroButton.texture_normal = load(WS.grid.get_hex(city.coord).data_tile.texture_path)
		$ArmyLabel.text = "City Garrison"
	else:
		$ArmyLabel.text = army.hero.hero_name
		$HeroButton.texture_normal = load(army.hero.data_unit.texture_path)

	load_unit_buttons(army, army.units_data, [units_box_first_column, units_box_second_column],
						UNIT_BUTTON_SIZE, true)


func transfered_unit():
	loaded_army.leader_unit_changed.emit()
	load_army(loaded_army)


func _attemp_army_swap() -> void:
	army_swap.emit()

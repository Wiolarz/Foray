extends UnitsButtonsList

signal show_level_up_screen

const UNIT_ICON_SIZE : float = 100.0

@onready var units_box_first_row : BoxContainer = $Units/FirstRow
@onready var units_box_second_row : BoxContainer = $Units/SecondRow



func _ready() -> void:
	var signal_emitter := func():
		show_level_up_screen.emit()
	$HeroIcon.pressed.connect(signal_emitter)


func load_army(army : Army):
	# city garrison allows player to enter it, even though there is no hero in second army
	if not army.hero:
		var city : City = WS.get_city_at(army.coord)
		if city:
			$HeroIcon.texture_normal = load(WS.grid.get_hex(city.coord).data_tile.texture_path)
			$ArmyLabel.text = "City Garrison"
		else:  # Neutral camp/ outpost garrison
			assert(army.units_data.size() > 0, "There shouldn't exist empty neutral army/outpost garrison")
			$HeroIcon.texture_normal = load(army.units_data[0].texture_path)
			$ArmyLabel.text = "Neutral Army"
	else:
		$ArmyLabel.text = army.hero.hero_name
		$HeroIcon.texture_normal = load(army.hero.data_unit.texture_path)


	load_unit_buttons(army, army.units_data, [units_box_first_row, units_box_second_row], UNIT_ICON_SIZE, true, false)


func simplified_display_load_army(army : PresetArmy):
	# city garrison allows player to enter it, even though there is no hero in second army
	if not army.hero:
		if army.units.size() == 0:
			return
		$HeroIcon.texture_normal = load(army.units[0].texture_path)
		$ArmyLabel.text = "Army"
	else:
		$ArmyLabel.text = army.hero.hero_name
		$HeroIcon.texture_normal = load(army.hero.data_unit.texture_path)
	var empty_army := Army.new()
	load_unit_buttons(empty_army, army.units, [units_box_first_row, units_box_second_row], UNIT_ICON_SIZE, false, false)

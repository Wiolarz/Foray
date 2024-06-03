class_name CityUi
extends Control

signal purchased_hero  # Hero list UI Update

var city : City
## currently visiting hero, null if none
var hero_army : ArmyForm

@onready var hero_panels = $HeroRecruitment
@onready var unit_panels = $RecruitUnits
@onready var building_buttons = $Buildings


func _ready():
	WM.world_move_done.connect(_refresh_all)


func _exit_tree():
	WM.world_move_done.disconnect(_refresh_all)


func show_trade_ui(viewed_city : City, visiting_hero : ArmyForm):
	city = viewed_city
	hero_army = visiting_hero
	_refresh_all()
	if not unit_panels.visible and visiting_hero:
		_on_show_recruit_units_ui_pressed()


func _refresh_all():
	_refresh_heroes_to_buy()
	_refresh_units_to_buy()
	_refresh_army_display()
	_refresh_buildings_display()


func _refresh_heroes_to_buy():
	var heroes = city.get_heroes_to_buy()
	assert(heroes.size() == hero_panels.get_child_count(),\
			"panels should equal heroes count, check fraction settings and city ui")
	for i in range(hero_panels.get_child_count()):
		var hero_to_buy = heroes[i];
		var hero_panel = hero_panels.get_child(i)

		hero_panel.get_node("HeroImage").texture = \
			load(heroes[i].data_unit.texture_path)

		var button = hero_panel.get_node("BuyHeroButton")
		var description = city.get_cost_description(hero_to_buy)
		button.text = "Buy %s\n%s" % [hero_to_buy.hero_name, description]
		button.disabled = not city.can_buy_hero(heroes[i])
		for s in button.pressed.get_connections():
			button.pressed.disconnect(s["callable"])
		button.pressed.connect(_on_buy_hero_button_pressed.bind(i))


func _refresh_units_to_buy():
	var units = city.get_units_to_buy()
	var buy_children = $RecruitUnits/UnitsToBuy.get_children()
	for i in range(buy_children.size()-1):
		var b = buy_children[i+1] as Button
		b.text = "-empty-"
		for s in b.get_signal_connection_list("pressed"):
			b.disconnect("pressed", s.callable)
		if i < units.size():
			var unit = units[i]
			b.text = unit.unit_name
			if not city.unit_has_required_building(unit):
				b.text += "\n" + "needs 🏛"
			else:
				b.text += "\n" + unit.cost.to_string_short("free")
			b.pressed.connect(_buy_unit.bind(unit))
			b.disabled = not city.can_buy_unit(unit, hero_army)


func _refresh_army_display():
	#TODO CLEAN
	var army_children : Array = $RecruitUnits/VisitingHeroArmy.get_children()
	if hero_army:
		army_children[0].text = "Max size " + str(hero_army.entity.hero.max_army_size)
	else:
		army_children[0].text = "No hero"
	for i in range(army_children.size()-1):
		var b = army_children[i+1] as Button
		b.text = "-empty-"
		b.disabled = not hero_army
		if hero_army and i < hero_army.entity.units_data.size():
			b.text = hero_army.entity.units_data[i].unit_name


func _buy_unit(unit):
	print("trying to buy ", unit.unit_name)

	WM.request_recruit_unit(hero_army, unit)


func _on_buy_hero_button_pressed(hero_index : int):
	print("trying to buy a hero ")

	var hero_to_buy : DataHero = city.controller.get_faction().heroes[hero_index]

	WM.request_recruit_hero(city.controller, hero_to_buy, city.coord)
	_on_show_recruit_heroes_ui_pressed() # hide

	purchased_hero.emit()


func _refresh_buildings_display():
	var buildings_data = city.controller.get_faction().buildings
	for i in range(buildings_data.size()):
		var building_data = buildings_data[i]
		var b_button = building_buttons.get_child(i+1) as Button
		if not b_button:
			continue
		var description = str(building_data.cost)
		if city.has_built(building_data):
			description = "✔"
		b_button.text = "%s\n%s" % [building_data.name, description]
		b_button.disabled = not city.can_build(building_data)
		for s in b_button.pressed.get_connections():
			b_button.pressed.disconnect(s["callable"])
		b_button.pressed.connect(func build():
			WM.request_build(city, building_data)
		)


func _on_show_recruit_heroes_ui_pressed():
	unit_panels.hide()
	building_buttons.hide()
	_refresh_heroes_to_buy()
	hero_panels.visible = not hero_panels.visible


func _on_show_recruit_units_ui_pressed():
	hero_panels.hide()
	building_buttons.hide()
	_refresh_units_to_buy()
	unit_panels.visible = not unit_panels.visible


func _on_show_build_ui_pressed():
	hero_panels.hide()
	unit_panels.hide()
	_refresh_buildings_display()
	building_buttons.visible = not building_buttons.visible

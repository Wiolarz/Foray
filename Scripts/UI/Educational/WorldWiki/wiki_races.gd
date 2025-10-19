extends Panel

@onready var race_selection_buttons_column : VBoxContainer = $Margin/VBoxContainer/HBoxContainer/VBoxRaceSelection


@onready var race_information_title = $Margin/VBoxContainer/HBoxContainer/RaceInformationContainer/VBox/RaceName
@onready var race_information_description = $Margin/VBoxContainer/HBoxContainer/RaceInformationContainer/VBox/RichTextLabel
@onready var race_information_icon = $Margin/VBoxContainer/HBoxContainer/RaceInformationContainer/VBox/TextureRect


@onready var race_heroes_list_container : HBoxContainer = \
$Margin/VBoxContainer/HBoxContainer/RaceInformationContainer/VBox/HBoxHeroes

@onready var race_units_list_container : HBoxContainer = \
$Margin/VBoxContainer/HBoxContainer/RaceInformationContainer/VBox/HBoxUnits


@onready var race_button_template : Resource = load("res://Scenes/UI/Wiki/WorldWiki/WikiRaceButton.tscn")
@onready var unit_button_template : Resource = load("res://Scenes/UI/Wiki/BattleWiki/WikiUnitButton.tscn")


func _ready():
	generate_race_buttons()


## INIT
func generate_race_buttons() -> void:
	# clean mockup ui
	Helpers.remove_all_children(race_selection_buttons_column)

	var race_idx = -1
	for race_data in CFG.RACES_LIST:
		race_idx += 1

		if race_idx == 0:  # load first race automatically
			load_race(race_data)

		var button : WikiRaceButton = race_button_template.instantiate()
		race_selection_buttons_column.add_child(button)
		button.load_race(race_data)

		button.selected.connect(load_race)


func load_race(race : DataRace) -> void:
	race_information_title.text = race.race_name.capitalize()
	race_information_icon.texture = load(race.units_data[0].texture_path) # TODO add icons to each race

	race_information_description.text = race.description


	# clean previous display
	Helpers.remove_all_children(race_heroes_list_container)
	Helpers.remove_all_children(race_units_list_container)

	## TODO make those buttons useful to show more information about unit, it could be a unit wiki page with listed weapons cost etc.
	for hero in race.heroes:
		var button : WikiUnitButton = unit_button_template.instantiate()
		race_heroes_list_container.add_child(button)
		button.load_unit(hero.data_unit)
	for unit in race.units_data:
		var button : WikiUnitButton = unit_button_template.instantiate()
		race_units_list_container.add_child(button)
		button.load_unit(unit)

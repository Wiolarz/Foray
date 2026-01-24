extends Panel

#region Variables: New run rules

# consts:
var player_factions = {
	CFG.RACE_UNDEAD: "res://Resources/Presets/City_Defense/undead_start_force.tres",
	CFG.RACE_CYCLOPS: "res://Resources/Presets/City_Defense/cyclops_start_force.tres",
	CFG.RACE_ORCS: "res://Resources/Presets/City_Defense/orcs_start_force.tres",
	CFG.RACE_ELVES: "res://Resources/Presets/City_Defense/elves_start_force.tres",
	CFG.RACE_DWARVES: "res://Resources/Presets/City_Defense/dwarves_start_force.tres",
	CFG.RACE_FIENDS: "res://Resources/Presets/City_Defense/fiends_start_force.tres",
}

const attacker_waves_folder_path := "res://Resources/Presets/City_Defense/Attacker_Waves/"
@onready var attacker_waves_presets = FileSystemHelpers.list_files_in_folder(attacker_waves_folder_path)

# UI:
@onready var ai_difficulty_selection : OptionButton = \
$MarginContainer/VBoxContainer/VBoxNewRun/VBoxNewRunRules/HBoxAIDifficulty/AIDifficulty

@onready var attacker_selection : OptionButton = \
$MarginContainer/VBoxContainer/VBoxNewRun/VBoxNewRunRules/HBoxArmiesSettings/AttackerOptionButton

@onready var defender_selection : OptionButton = \
$MarginContainer/VBoxContainer/VBoxNewRun/VBoxNewRunRules/HBoxArmiesSettings/DefenderOptionButton

@onready var new_run_container : VBoxContainer = $MarginContainer/VBoxContainer/VBoxNewRun


# selected settings:
var new_run_attacker_waves_path : String
var new_run_army_path : String
var new_run_selected_race : DataRace

#endregion Variables: New run rules


#region Variables: Current Run

# balance:

@onready var map : DataBattleMap = load("res://Resources/Battle/Battle_Maps/mid_city.tres")

## In case there are more waves than awards, last one is repeated
var goods_awards : Array[Goods] = \
[
	Goods.new(3, 3, 0), # Starting goods
	Goods.new(3, 2, 1), # after 1st
	Goods.new(5, 4, 2), # after 2nd
	Goods.new(7, 6, 3), # after 3rd
	Goods.new(9, 7, 4), # 4
	Goods.new(9, 8, 5), # 5
] # 6th wave is currently last

const MAX_ARMY_SIZE : int = 6

# Settings

var selected_bot_path : String
var player_race : DataRace
var attacker_waves : PresetWaves


# UI:

@onready var current_run_container : VBoxContainer = $MarginContainer/VBoxContainer/VBoxCurrentRun
@onready var units_purchases : HBoxContainer = $MarginContainer/VBoxContainer/VBoxCurrentRun/HBoxPurchases
@onready var current_run_information : Label = $MarginContainer/VBoxContainer/VBoxCurrentRun/CurrentRunLabel
@onready var army_display : UnitsButtonsList = $MarginContainer/VBoxContainer/VBoxCurrentRun/HBoxArmy
@onready var continue_button : Button = $MarginContainer/VBoxContainer/VBoxCurrentRun/ContinueButton

## Next Wave Information
@onready var next_wave_label : Label = $MarginContainer/VBoxContainer/VBoxCurrentRun/VBoxNextWave/HBoxNextWaveInfo/Label
@onready var next_wave_roster : HBoxContainer = $MarginContainer/VBoxContainer/VBoxCurrentRun/VBoxNextWave/HBoxNextWaveArmy
@onready var next_wave_selection : OptionButton = $MarginContainer/VBoxContainer/VBoxCurrentRun/VBoxNextWave/HBoxNextWaveInfo/OptionWaveSelection


# Current run data:
var current_roster : Army

var is_run_ongoing : bool = false
var current_wave : int = -1

var player_goods : Goods

#endregion Variables: Current Run


#region New Run Setup

func _ready():
	new_run_container.visible = true
	current_run_container.visible = false
	highscores_container.visible = true

	## BOTS
	var bot_paths = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_BOTS_PATH, true, true)
	ai_difficulty_selection.clear()
	for bot_name in bot_paths:
		ai_difficulty_selection.add_item(bot_name.trim_prefix(CFG.BATTLE_BOTS_PATH))
	ai_difficulty_selection.item_selected.connect(difficulty_changed)

	## HIGHSCORES
	if not CFG.HIGHSCORES:
		CFG.reset_highscores()
	var reset_highscore_button = \
		$MarginContainer/VBoxContainer/VBoxNewRun/HBoxContainer/ResetHighscoresButton
	reset_highscore_button.pressed.connect(reset_highscores)
	_refresh_highscore_display()

	$MarginContainer/VBoxContainer/VBoxHighScores/HBoxRaces/Button.pressed.connect(
		_refresh_highscore_display)
	var top_bar = highscores_races_top_bar.get_children()
	var idx = 0
	for race in CFG.RACES_LIST:
		idx += 1
		top_bar[idx].pressed.connect(_refresh_highscore_display.bind(race))

	## NEW RUN SETTINGS
	attacker_selection.clear()
	for attacker_waves_preset in attacker_waves_presets:
		attacker_selection.add_item(attacker_waves_preset)
	attacker_selection.item_selected.connect(attacker_changed)

	defender_selection.clear()
	for defender : DataRace in player_factions.keys():
		defender_selection.add_item(defender.race_name)
	defender_selection.item_selected.connect(defender_changed)

	attacker_selection.select(0) # visually changes OptionButton to match the settings
	attacker_changed(0) # 0 currently points to cyclops
	defender_changed(0)

	load_save()

	## CURRENT RUN SETTINGS
	next_wave_selection.item_selected.connect(_displayed_next_wave_changed)

	$MarginContainer/VBoxContainer/VBoxCurrentRun/CurrentRosterTopBar/ResetPurchasesButton.\
		pressed.connect(load_save)


func attacker_changed(attacker_index) -> void:
	new_run_attacker_waves_path = attacker_waves_folder_path + attacker_waves_presets[attacker_index]


func defender_changed(defender_index) -> void:
	new_run_selected_race = player_factions.keys()[defender_index]
	new_run_army_path = player_factions.values()[defender_index]


func difficulty_changed(_difficulty_index) -> void:
	_refresh_highscore_display()


func _start_new_run(is_save_being_loaded : bool = false) -> void:
	new_run_container.visible = false
	current_run_container.visible = true
	highscores_container.visible = false

	is_run_ongoing = true
	current_wave = -1

	attacker_waves = load(new_run_attacker_waves_path)

	selected_bot_path = CFG.BATTLE_BOTS_PATH + ai_difficulty_selection.get_item_text(ai_difficulty_selection.get_selected())

	player_race = new_run_selected_race
	current_roster = Army.new()
	var army_preset : PresetArmy = load(new_run_army_path)
	current_roster.units_data = army_preset.units
	current_roster.hero = Hero.construct_hero(player_race.heroes[0], 0)


	continue_button.disabled = false
	IM.is_city_defense_active = true


	player_goods = goods_awards[0].duplicate()
	refresh_run_info()

	_refresh_unit_purchases()
	_refresh_roster_display()


	next_wave_selection.clear()
	for wave_idx : int in range(attacker_waves.waves.size()):
		next_wave_selection.add_item(str(wave_idx + 1))
	_displayed_next_wave_changed(0)

	if not is_save_being_loaded:
		save_game()

#endregion New Run Setup


#region Run UI

## Saved: race, army, goods, enemy
func save_game() -> void:

	var preset_army := PresetArmy.generate_from_army(current_roster)

	CFG.player_options.city_defense_save = [
		CFG.RACES_LIST.find(player_race),
		preset_army,
		player_goods.duplicate(),
		current_wave,
		CFG.RACES_LIST.find(attacker_waves.race),
	]
	CFG.save_player_options()


## used once starting the game and during purchases reset
func load_save() -> void:
	if CFG.CITY_DEFENSE_SAVE.size() == 0: # No saved game
		return
	if CFG.CITY_DEFENSE_SAVE[1].hero == null:  # TEMP safeguard to prevent loading older version saves
		return
	
	_start_new_run(true)
	player_race = CFG.RACES_LIST[CFG.CITY_DEFENSE_SAVE[0]]

	var preset_army : PresetArmy = CFG.CITY_DEFENSE_SAVE[1]
	current_roster = Army.new()
	current_roster.units_data = preset_army.units.duplicate()
	var hero := Hero.construct_hero(preset_army.hero, 0)
	current_roster.hero = hero

	player_goods = CFG.CITY_DEFENSE_SAVE[2].duplicate()
	current_wave = CFG.CITY_DEFENSE_SAVE[3]
	var enemy_race : DataRace = CFG.RACES_LIST[CFG.CITY_DEFENSE_SAVE[4]]
	var correct_race_found : bool = false

	for attacker_waves_preset_path in \
	FileSystemHelpers.list_files_in_folder(attacker_waves_folder_path, true):
		attacker_waves = load(attacker_waves_preset_path)
		if attacker_waves.race == enemy_race:
			correct_race_found = true
			break

	assert(correct_race_found, "could not find the correct attacker preset")
	_refresh_unit_purchases()
	_refresh_roster_display()

	next_wave_selection.clear()
	for wave_idx : int in range(attacker_waves.waves.size()):
		next_wave_selection.add_item(str(wave_idx + 1))
	_displayed_next_wave_changed(current_wave + 1)
	refresh_run_info()


func _displayed_next_wave_changed(wave_idx : int) -> void:
	next_wave_selection.select(wave_idx)
	var award_idx : int = wave_idx
	if award_idx + 1 >= goods_awards.size():
		award_idx = goods_awards.size() - 2
	# first value is starting goods
	next_wave_label.text = "Next Wave: " + goods_awards[award_idx + 1].to_string_short()

	next_wave_roster.simplified_display_load_army(attacker_waves.waves[wave_idx])


func refresh_run_info():
	var text := "Current Run - Wave: " + str(current_wave + 2) + \
		" Goods: " + player_goods.to_string_short()
	current_run_information.text = text
	if current_wave + 1 == attacker_waves.waves.size():
		current_run_information.text += "\nVICTORY"


func _refresh_unit_purchases() -> void:
	Helpers.remove_all_children(units_purchases)
	for unit in player_race.units_data:
		var unit_buy_button := Button.new()
		unit_buy_button.text = unit.unit_name
		unit_buy_button.text += "\n" + unit.cost.to_string_short("free")

		unit_buy_button.pressed.connect(_buy_unit.bind(unit))
		units_purchases.add_child(unit_buy_button)

		var should_button_be_disabled := false
		if not player_goods.has_enough(unit.cost):
			should_button_be_disabled = true

		if current_roster.units_data.size() >= MAX_ARMY_SIZE:
			should_button_be_disabled = true

		unit_buy_button.disabled = should_button_be_disabled


func _refresh_roster_display() -> void:
	army_display.load_army(current_roster)


func _buy_unit(unit : DataUnit) -> void:
	assert(player_goods.has_enough(unit.cost))
	player_goods.subtract(unit.cost)
	current_roster.units_data.append(unit)
	_refresh_roster_display()
	_refresh_unit_purchases()
	refresh_run_info()


func _launch_battle():
	current_wave += 1
	var enemy_wave : PresetArmy = attacker_waves.waves[current_wave]
	var battle := ScriptedBattle.new()
	battle.armies = [
		PresetArmy.generate_from_army(current_roster),
		enemy_wave
	]
	battle.battle_map = map

	continue_button.disabled = true

	IM.start_scripted_battle(battle, selected_bot_path, 0)


## after BM ends battle with IM.is_city_defense_active being true it calls IM which calls this
func battle_ended(armies : Array[BattleGridState.ArmyInBattleState]) -> void:
	if not armies[0].can_fight():  # player lost
		IM.is_city_defense_active = false
		is_run_ongoing = false
		continue_button.disabled = true
		CFG.player_options.city_defense_save.clear()
		CFG.save_player_options()
		return

	update_highscores()

	for dead_unit : Unit in armies[0].dead_units:
		current_roster.units_data.erase(dead_unit.template)

	# goods awards 0 is starting amount, so we always add + 1
	if current_wave + 1 >= goods_awards.size():
		player_goods.add(goods_awards[-1])
	else:
		player_goods.add(goods_awards[current_wave + 1])

	save_game()
	_refresh_unit_purchases()
	_refresh_roster_display()

	refresh_run_info()
	if current_wave + 1 == attacker_waves.waves.size():  # Victory
		is_run_ongoing = false
		continue_button.disabled = true
		CFG.player_options.city_defense_save.clear()
		CFG.save_player_options()
	else:
		continue_button.disabled = false
		_displayed_next_wave_changed(current_wave + 1)

#endregion Run UI


#region Highscores

@onready var highscores_container : VBoxContainer = $MarginContainer/VBoxContainer/VBoxHighScores

@onready var highscores_races_top_bar : HBoxContainer = \
 $MarginContainer/VBoxContainer/VBoxHighScores/HBoxRaces

@onready var highscores_races_score_bar : HBoxContainer = \
 $MarginContainer/VBoxContainer/VBoxHighScores/HBoxScores


func reset_highscores() -> void:
	CFG.reset_highscores()
	_refresh_highscore_display()


func _refresh_highscore_display(race_focus : DataRace = null) -> void:
	var top_bar = highscores_races_top_bar.get_children()
	var score_bar = highscores_races_score_bar.get_children()

	var difficulty : String =\
		ai_difficulty_selection.get_item_text(ai_difficulty_selection.get_selected())


	var idx = 0
	for race in CFG.RACES_LIST:
		idx += 1
		top_bar[idx].texture_normal = RES.load(race.units_data[0].texture_path)
		if race_focus and race != race_focus:
			top_bar[idx].modulate = Color.GRAY
		else:
			top_bar[idx].modulate = Color.WHITE

		var score : Array
		if not race_focus:
			score = CFG.get_highscore(race, difficulty)
		else:
			score = CFG.get_highscore(race_focus, difficulty, race)
		score_bar[idx].texture = RES.load(score[0].units_data[0].texture_path)
		score_bar[idx].get_node("Label").text = str(score[1])


#updated once we win the battle
func update_highscores() -> void:
	#TEMP TODO always counts as mirror, until new enemy selection system
	var difficulty : String =\
		ai_difficulty_selection.get_item_text(ai_difficulty_selection.get_selected())
	CFG.update_highscore(player_race, attacker_waves.race, difficulty, current_wave + 1)

#endregion Highscores


#region Buttons

func _on_continue_button_pressed() -> void:
	_launch_battle()


func _on_start_new_run_button_pressed() -> void:
	if new_run_container.visible:
		_start_new_run()
	else:
		new_run_container.visible = true
		current_run_container.visible = false
		highscores_container.visible = true
		_refresh_highscore_display()

#endregion Buttons

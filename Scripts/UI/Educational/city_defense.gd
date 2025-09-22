extends Panel

#region Variables: New run rules

# consts:
var player_factions = {
	CFG.RACE_UNDEAD: "res://Resources/Presets/City_Defense/undead_start_force.tres",
	CFG.RACE_CYCLOPS: "res://Resources/Presets/City_Defense/cyclops_start_force.tres",
	CFG.RACE_ORCS: "res://Resources/Presets/City_Defense/orcs_start_force.tres",
	CFG.RACE_ELVES: "res://Resources/Presets/City_Defense/elves_start_force.tres",
}

const attacker_waves_folder_path := "res://Resources/Presets/City_Defense/Attacker_Waves/"
@onready var attacker_folders = FileSystemHelpers.list_folders_in_folder(attacker_waves_folder_path)


# UI:
@onready var ai_difficulty_selection : OptionButton = \
$MarginContainer/VBoxContainer/VBoxNewRun/VBoxNewRunRules/HBoxAIDifficulty/AIDifficulty

@onready var attacker_selection : OptionButton = \
$MarginContainer/VBoxContainer/VBoxNewRun/VBoxNewRunRules/HBoxArmiesSettings/AttackerOptionButton

@onready var defender_selection : OptionButton = \
$MarginContainer/VBoxContainer/VBoxNewRun/VBoxNewRunRules/HBoxArmiesSettings/DefenderOptionButton

@onready var new_run_container : VBoxContainer = $MarginContainer/VBoxContainer/VBoxNewRun


# selected settings:
var new_run_attacker_waves_folder_path : String
var new_run_army_path : String
var new_run_selected_race : DataRace

#endregion Variables: New run rules


#region Variables: Current Run

# balance:

@onready var map : DataBattleMap = load("res://Resources/Battle/Battle_Maps/large_city.tres")

## In case there are more waves than awards, last one is repeated
var goods_awards : Array[Goods] = \
[
	Goods.new(3, 3, 0), # Starting goods
	Goods.new(3, 2, 1), # after 1st
	Goods.new(5, 4, 2), # after 2nd
	Goods.new(7, 6, 3), # after 3rd
] # 4th wave is currently last

# Settings

var selected_bot_path : String
var player_race : DataRace
var attacker_waves : Array[PresetArmy] = []


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
var current_roster : PresetArmy

var is_run_ongoing : bool = false
var current_wave : int = -1

var player_goods : Goods

#endregion Variables: Current Run


#region New Run Setup

func _ready():
	var bot_paths = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_BOTS_PATH, true, true)
	ai_difficulty_selection.clear()
	for bot_name in bot_paths:
		ai_difficulty_selection.add_item(bot_name.trim_prefix(CFG.BATTLE_BOTS_PATH))


	attacker_selection.clear()
	for attacker_folder_path in attacker_folders:
		attacker_selection.add_item(attacker_folder_path)
	attacker_selection.item_selected.connect(attacker_changed)

	defender_selection.clear()
	for defender : DataRace in player_factions.keys():
		defender_selection.add_item(defender.race_name)
	defender_selection.item_selected.connect(defender_changed)

	attacker_selection.select(1) # visually changes OptionButton to match the settings
	attacker_changed(1) # 1 currently points to orcs, which work with AI properly
	defender_changed(0)

	next_wave_selection.item_selected.connect(_displayed_next_wave_changed)


func attacker_changed(attacker_index) -> void:
	new_run_attacker_waves_folder_path = attacker_waves_folder_path + attacker_folders[attacker_index]


func defender_changed(defender_index) -> void:
	new_run_selected_race = player_factions.keys()[defender_index]
	new_run_army_path = player_factions.values()[defender_index]


func _start_new_run() -> void:
	new_run_container.visible = false
	current_run_container.visible = true

	is_run_ongoing = true
	current_wave = -1

	attacker_waves = []
	for wave_path in FileSystemHelpers.list_files_in_folder(new_run_attacker_waves_folder_path):
		var full_wave_path : String = new_run_attacker_waves_folder_path + "/" + wave_path

		var attacker_army : PresetArmy = load(full_wave_path)
		attacker_waves.append(attacker_army)

	selected_bot_path = CFG.BATTLE_BOTS_PATH + ai_difficulty_selection.get_item_text(ai_difficulty_selection.get_selected())

	player_race = new_run_selected_race
	current_roster = load(new_run_army_path)

	continue_button.disabled = false
	IM.is_city_defense_active = true


	player_goods = goods_awards[0].duplicate()
	refresh_run_info()

	_refresh_unit_purchases()
	_refresh_roster_display()


	next_wave_selection.clear()
	for wave_idx : int in range(attacker_waves.size()):
		next_wave_selection.add_item(str(wave_idx + 1))
	_displayed_next_wave_changed(0)

#endregion New Run Setup


#region Run UI

func _displayed_next_wave_changed(wave_idx : int) -> void:
	next_wave_selection.select(wave_idx)
	var award_idx : int = wave_idx
	if award_idx + 1 >= goods_awards.size():
		award_idx = goods_awards.size() - 2
	# first value is starting goods
	next_wave_label.text = "Next Wave: " + goods_awards[award_idx + 1].to_string_short()

	next_wave_roster.simplified_display_load_army(attacker_waves[wave_idx])


func refresh_run_info():
	var text := "Current Run - Wave: " + str(current_wave + 2) + \
		" Goods: " + player_goods.to_string_short()
	current_run_information.text = text
	if current_wave + 1 == attacker_waves.size():
		current_run_information.text += "\nVICTORY"


func _refresh_unit_purchases() -> void:
	Helpers.remove_all_children(units_purchases)
	for unit in player_race.units_data:
		var unit_buy_button := Button.new()
		unit_buy_button.text = unit.unit_name
		unit_buy_button.text += "\n" + unit.cost.to_string_short("free")

		unit_buy_button.pressed.connect(_buy_unit.bind(unit))
		units_purchases.add_child(unit_buy_button)
		unit_buy_button.disabled = not player_goods.has_enough(unit.cost)


func _refresh_roster_display() -> void:
	army_display.simplified_display_load_army(current_roster)


func _buy_unit(unit : DataUnit) -> void:
	assert(player_goods.has_enough(unit.cost))
	player_goods.subtract(unit.cost)
	current_roster.units.append(unit)
	_refresh_roster_display()
	_refresh_unit_purchases()
	refresh_run_info()


func _launch_battle():
	current_wave += 1
	var enemy_wave : PresetArmy = attacker_waves[current_wave]
	var battle := ScriptedBattle.new()
	battle.armies = [
		current_roster,
		enemy_wave
	]
	battle.battle_map = map

	IM.start_scripted_battle(battle, selected_bot_path, 0)


## after BM ends battle with IM.is_city_defense_active being true it calls IM which calls this
func battle_ended(armies : Array[BattleGridState.ArmyInBattleState]) -> void:
	if not armies[0].can_fight():  # player lost
		IM.is_city_defense_active = false
		is_run_ongoing = false
		continue_button.disabled = true
		return

	for dead_unit in armies[0].dead_units:
		current_roster.units.erase(dead_unit)

	# goods awards 0 is starting amount, so we always add + 1
	if current_wave + 1 >= goods_awards.size():
		player_goods.add(goods_awards[-1])
	else:
		player_goods.add(goods_awards[current_wave + 1])

	_refresh_unit_purchases()
	_refresh_roster_display()

	refresh_run_info()
	if current_wave + 1 == attacker_waves.size():  # Victory
		is_run_ongoing = false
		continue_button.disabled = true
	else:
		_displayed_next_wave_changed(current_wave + 1)

#endregion Run UI


#region Buttons

func _on_continue_button_pressed() -> void:
	_launch_battle()


func _on_start_new_run_button_pressed() -> void:
	if new_run_container.visible:
		_start_new_run()
	else:
		new_run_container.visible = true
		current_run_container.visible = false

#endregion Buttons

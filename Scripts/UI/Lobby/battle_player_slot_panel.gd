class_name BattlePlayerSlotPanel
extends PlayerSlotPanel


const EMPTY_UNIT_TEXT = " - empty - "
const ALL_RACES_TEXT = "All Races"


var unit_paths : Array[String]

var hero_paths : Array[String]
var races_paths : Array[String]
var army_paths : Array[String]

@onready var buttons_units : Array[OptionButton] = [
	$GeneralVContainer/OptionButtonUnit1,
	$GeneralVContainer/OptionButtonUnit2,
	$GeneralVContainer/OptionButtonUnit3,
	$GeneralVContainer/OptionButtonUnit4,
	$GeneralVContainer/OptionButtonUnit5,
]

@onready var hero_list : OptionButton = $GeneralVContainer/TopBarHContainer/OptionButtonHero
@onready var level_up_button : Button = $GeneralVContainer/TopBarHContainer/ButtonLevelUp



@onready var races_list : OptionButton = $GeneralVContainer/HBoxRacesAndPresets/OptionButtonRace
@onready var army_preset_list : OptionButton = $GeneralVContainer/HBoxRacesAndPresets/OptionButtonArmy


func _pre_ready_init() -> void:
	hero_paths = FileSystemHelpers.list_files_in_folder(CFG.HEROES_PATH, true, true)
	init_hero_list(hero_list)

	unit_paths = FileSystemHelpers.list_files_in_folder(CFG.UNITS_PATH, true, true)
	for index in buttons_units.size():
		var button : OptionButton = buttons_units[index]
		init_unit_button(button, index)

	button_battle_bot = get_node("GeneralVContainer/TopBarHContainer/OptionButtonBot")

	init_race_list()

	army_paths = FileSystemHelpers.list_files_in_folder(CFG.ARMY_PRESETS_PATH, true, true)
	init_army_list()


#region Top Bar

func init_unit_button(button : OptionButton, index : int):
	button.clear()
	button.add_item(EMPTY_UNIT_TEXT)
	for unit_path in unit_paths:
		button.add_item(unit_path.trim_prefix(CFG.UNITS_PATH))
	button.item_selected.connect(unit_in_army_changed.bind(index))


#region Hero list

func init_hero_list(button : OptionButton) -> void:
	button.clear() #XD
	button.add_item(EMPTY_UNIT_TEXT)
	for hero_path in hero_paths:
		button.add_item(hero_path.trim_prefix(CFG.HEROES_PATH))
	button.item_selected.connect(hero_in_army_changed.bind())


func set_hero_option_button(slot_hero_template : DataHero) -> void:
	if not slot_hero_template:
		level_up_button.disabled = true
		hero_list.select(0)
		return
	for idx in hero_list.item_count:
		if slot_hero_template.resource_path.ends_with(hero_list.get_item_text(idx)):
			hero_list.select(idx)
			level_up_button.disabled = false
			return
	assert(false, "hero assigned to an army is not present in hero list")


func hero_in_army_changed(hero_index) -> void:
	var hero_path = hero_list.get_item_text(hero_index)
	var hero_data : DataHero = null
	if hero_path != EMPTY_UNIT_TEXT:
		hero_data = load(CFG.HEROES_PATH + "/" + hero_path)
		level_up_button.disabled = false
	else:
		level_up_button.disabled = true
	var slot_index = setup_ui.slot_to_index(self)

	IM.game_setup_info.set_hero(slot_index, hero_data)
	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info) #TODO add multi support
	if NET.client:
		pass#NET.client.queue_lobby_set_unit(slot_index, unit_index, unit_data) #TODO STUB


func _on_button_level_up_pressed():
	if not should_react_to_changes():
		return

	var slot_index : int = setup_ui.slot_to_index(self)

	setup_ui.show_hero_level_up(slot_index)

#endregion Hero list

#endregion Top Bar


#region Races And Presets Bar

func init_race_list() -> void:
	races_list.clear()
	races_list.add_item(ALL_RACES_TEXT)
	for race in CFG.RACES_LIST:
		races_list.add_item(race.race_name)
	races_list.item_selected.connect(_on_race_selected .bind())


func _on_race_selected(race_index : int) -> void:
	if race_index == 0:
		load_unit_buttons()
		return

	race_index -= 1

	selected_army_preset(0)  # reset unit selection
	var race : DataRace = CFG.RACES_LIST[race_index]

	unit_paths = FileSystemHelpers.list_files_in_folder(CFG.UNITS_PATH, true, true)
	for index in buttons_units.size():
		var button : OptionButton = buttons_units[index]
		button.clear()
		button.add_item(EMPTY_UNIT_TEXT)
		for data_unit in race.units_data:
			button.add_item(data_unit.resource_path.trim_prefix(CFG.UNITS_PATH))
		if not button.item_selected.is_connected(unit_in_army_changed):
			button.item_selected.connect(unit_in_army_changed.bind(index))


func init_army_list() -> void:
	army_preset_list.clear()
	for army_path in army_paths:
		army_preset_list.add_item(army_path.trim_prefix(CFG.ARMY_PRESETS_PATH))
	army_preset_list.item_selected.connect(selected_army_preset.bind())


func selected_army_preset(army_preset_index : int) -> void:
	var new_army_preset : PresetArmy = load(army_paths[army_preset_index])
	var slot_index : int = setup_ui.slot_to_index(self) # determine on which slot player is

	var slot : Slot = IM.game_setup_info.slots[slot_index]

	var units := slot.units_list
	for unit_idx : int in range(units.size()):
		var unit : DataUnit = null
		if unit_idx < new_army_preset.units.size():
			unit = new_army_preset.units[unit_idx]
		units[unit_idx] = unit
	set_army(units) # VISUALS

	if not new_army_preset.hero:
		hero_in_army_changed(0)
	else:
		var hero_name : String = new_army_preset.hero.resource_path.trim_prefix(CFG.ARMY_PRESETS_PATH)
		for idx in range(hero_paths.size()):
			if hero_paths[idx] == hero_name:
				hero_in_army_changed(idx)
				break
		hero_in_army_changed(0)

	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)
	if NET.client:
		for unit_idx : int in range(units.size()):
			NET.client.queue_lobby_set_unit(slot_index, unit_idx, units[unit_idx])


## VISUALS ONLY
func set_army(units_list : Array[DataUnit]):
	while buttons_units.size() > units_list.size():
		var b = buttons_units.pop_back()
		$GeneralVContainer.remove_child(b)
		b.queue_free()
	while buttons_units.size() < units_list.size():
		var b := OptionButton.new()
		init_unit_button(b, buttons_units.size())
		buttons_units.append(b)
		$GeneralVContainer.add_child(b)
		b.custom_minimum_size = Vector2(200, 0)

	for index in units_list.size():
		set_unit(buttons_units[index], units_list[index])

#endregion Races And Presets Bar


#region Unit List

func load_unit_buttons() -> void:
	unit_paths = FileSystemHelpers.list_files_in_folder(CFG.UNITS_PATH, true, true)
	for index in buttons_units.size():
		var button : OptionButton = buttons_units[index]
		init_unit_button(button, index)


func unit_in_army_changed(selected_index, unit_index) -> void:
	var unit_path = buttons_units[unit_index].get_item_text(selected_index)
	var unit_data : DataUnit = null
	if unit_path != EMPTY_UNIT_TEXT:
		unit_data = load(CFG.UNITS_PATH+"/"+unit_path)
	var slot_index = setup_ui.slot_to_index(self)
	IM.game_setup_info.set_unit(slot_index, unit_index, unit_data)
	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)
	if NET.client:
		NET.client.queue_lobby_set_unit(slot_index, unit_index, unit_data)


## Change text only after sele
func set_unit(unit_button : OptionButton, unit : DataUnit):
	if not unit:
		unit_button.select(0)
		return
	for idx in unit_button.item_count:
		if unit.resource_path.ends_with(unit_button.get_item_text(idx)):
			unit_button.select(idx)

#endregion Unit List

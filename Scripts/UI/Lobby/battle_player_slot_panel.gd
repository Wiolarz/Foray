class_name BattlePlayerSlotPanel
extends PanelContainer

enum TakeLeaveButtonState {
	FREE,
	TAKEN_BY_YOU,
	TAKEN_BY_OTHER,
	GHOST, # state when we display too much slots
}

const EMPTY_UNIT_TEXT = " - empty - "
const ALL_RACES_TEXT = "All Races"

var setup_ui : BattleSetup = null
var button_take_leave_state : TakeLeaveButtonState = TakeLeaveButtonState.FREE

var unit_paths : Array[String]
var bot_paths : Array[String]
var hero_paths : Array[String]
var races_paths : Array[String]
var army_paths : Array[String]

@onready var button_take_leave = $GeneralVContainer/TopBarHContainer/ButtonTakeLeave
@onready var label_name = $GeneralVContainer/TopBarHContainer/PlayerInfoPanel/Label
@onready var buttons_units : Array[OptionButton] = [
	$GeneralVContainer/OptionButtonUnit1,
	$GeneralVContainer/OptionButtonUnit2,
	$GeneralVContainer/OptionButtonUnit3,
	$GeneralVContainer/OptionButtonUnit4,
	$GeneralVContainer/OptionButtonUnit5,
]
@onready var button_bot = $GeneralVContainer/TopBarHContainer/OptionButtonBot
@onready var player_info = $GeneralVContainer/TopBarHContainer/PlayerInfoPanel


@onready var team_list : OptionButton = $GeneralVContainer/TopBarHContainer/OptionButtonTeam
@onready var hero_list : OptionButton = $GeneralVContainer/TopBarHContainer/OptionButtonHero
@onready var level_up_button : Button = $GeneralVContainer/TopBarHContainer/ButtonLevelUp

@onready var timer_reserve_minutes : SpinBox = $GeneralVContainer/TimerContainer/ReserveTime_Min_Edit
@onready var timer_reserve_seconds : SpinBox = $GeneralVContainer/TimerContainer/ReserveTime_Sec_Edit
@onready var timer_increment_seconds : SpinBox = $GeneralVContainer/TimerContainer/IncrementTimeEdit

@onready var races_list : OptionButton = $GeneralVContainer/HBoxRacesAndPresets/OptionButtonRace
@onready var army_preset_list : OptionButton = $GeneralVContainer/HBoxRacesAndPresets/OptionButtonArmy


func _ready():
	hero_paths = FileSystemHelpers.list_files_in_folder(CFG.HEROES_PATH, true, true)
	init_hero_list(hero_list)

	load_unit_buttons()

	bot_paths = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_BOTS_PATH, true, true)
	init_bots_button()

	init_race_list()

	army_paths = FileSystemHelpers.list_files_in_folder(CFG.ARMY_PRESETS_PATH, true, true)
	init_army_list()


## used to know if changes in gui are made by user and should be passed to
## backend (change setup info and send over network) OR made by refreshing
## gui to state in backend
func should_react_to_changes() -> bool:
	var node := get_parent()
	while node:
		if node.has_method("should_react_to_changes"):
			return node.should_react_to_changes()
		node = node.get_parent()
	return false


#region Top Bar


func init_bots_button():
	button_bot.clear()
	for bot_name in bot_paths:
		button_bot.add_item(bot_name.trim_prefix(CFG.BATTLE_BOTS_PATH))
	button_bot.item_selected.connect(bot_changed)


func init_hero_list(button : OptionButton) -> void:
	button.clear() #XD
	button.add_item(EMPTY_UNIT_TEXT)
	for hero_path in hero_paths:
		button.add_item(hero_path.trim_prefix(CFG.HEROES_PATH))
	button.item_selected.connect(hero_in_army_changed.bind())


func init_team_list(max_player_number : int) -> void:
	team_list.clear()
	team_list.add_item("No Team")
	for idx in range(1, max_player_number + 1):
		team_list.add_item("Team " + str(idx))



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




func try_to_take():
	if not setup_ui:
		return
	setup_ui.try_to_take_slot(self)


func try_to_leave():
	if not setup_ui:
		return
	setup_ui.try_to_leave_slot(self)


func cycle_color(backwards : bool = false):
	if not setup_ui:
		return
	setup_ui.cycle_color_slot(self, backwards)


func set_visible_color(c : Color):
	var style_box = get_theme_stylebox("panel")
	if not style_box is StyleBoxFlat:
		return
	var style_box_flat = style_box as StyleBoxFlat
	style_box_flat.bg_color = c


func set_visible_name(player_name : String):
	label_name.text = player_name


func set_visible_team(team : int):
	team_list.selected = team


func set_visible_take_leave_button_state(state : TakeLeaveButtonState):
	# maybe better get this from battle setup, but this is simpler
	button_take_leave_state = state
	button_bot.visible = false
	player_info.visible = true
	match state:
		TakeLeaveButtonState.FREE:
			button_take_leave.text = "Take"
			button_take_leave.disabled = false
			button_bot.visible = true
			player_info.visible = false
		TakeLeaveButtonState.TAKEN_BY_YOU:
			button_take_leave.text = "Leave"
			button_take_leave.disabled = false
		TakeLeaveButtonState.TAKEN_BY_OTHER:
			if IM.is_slot_steal_allowed():
				button_take_leave.text = "Steal"
				button_take_leave.disabled = false
			else:
				# ">> TAKEN <<" -- simple "Taken" would be too similar to "Take"
				button_take_leave.text = ">> TAKEN <<"
				button_take_leave.disabled = true
		TakeLeaveButtonState.GHOST:
			button_take_leave.text = "ghost"
			button_take_leave.disabled = true

#endregion Option Button Support


#region Multiplayer/Preset Related

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

#endregion Multiplayer Related


func bot_changed(bot_index):
	# TODO network code
	IM.game_setup_info.set_battle_bot(setup_ui.slot_to_index(self), bot_paths[bot_index])


func set_bot(new_bot_path: String):
	var bot_path = new_bot_path if new_bot_path != "" else bot_paths[0]
	var idx = bot_paths.find(bot_path)
	assert(idx != -1, "Invalid bot '%s'" % bot_path)
	button_bot.select(idx)
	bot_changed(idx)


func fill_team_list(max_player_number : int) -> void:
	team_list.clear()
	team_list.add_item("No Team")
	for idx in range(1, max_player_number + 1):
		team_list.add_item("Team " + str(idx))


func _on_button_take_leave_pressed():
	if not should_react_to_changes():
		return
	match button_take_leave_state:
		TakeLeaveButtonState.FREE:
			try_to_take()
		TakeLeaveButtonState.TAKEN_BY_YOU:
			try_to_leave()
		TakeLeaveButtonState.TAKEN_BY_OTHER:
			if IM.is_slot_steal_allowed():
				try_to_take()


func _on_button_color_pressed():
	if not should_react_to_changes():
		return
	cycle_color()


func _on_option_button_team_item_selected(index : int):
	if not should_react_to_changes():
		return
	var slot_index = setup_ui.slot_to_index(self) # determine on which slot player is

	IM.game_setup_info.set_team(slot_index, index)
	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)
	if NET.client:
		NET.client.queue_lobby_set_team(slot_index, index)


func _on_button_level_up_pressed():
	if not should_react_to_changes():
		return

	var slot_index : int = setup_ui.slot_to_index(self)

	setup_ui.show_hero_level_up(slot_index)

	UI.show_hero_level_up()

#endregion Top Bar


#region Timer Bar

func set_visible_timers(reserve : int, increment : int):
	var reserve_minutes := int(reserve / 60)
	var reserve_seconds := reserve % 60
	timer_reserve_minutes.value = reserve_minutes
	timer_reserve_seconds.value = reserve_seconds
	timer_increment_seconds.value = increment


func timer_changed(_value) -> void:
	if not should_react_to_changes():
		return

	var slot_index = setup_ui.slot_to_index(self)

	var seconds_reserve = timer_reserve_minutes.value * 60 + timer_reserve_seconds.value


	IM.game_setup_info.set_timer(slot_index, seconds_reserve, int(timer_increment_seconds.value))
	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info) #TODO add multi support
	if NET.client:
		NET.client.queue_lobby_set_timer(slot_index, seconds_reserve, int(timer_increment_seconds.value))

#endregion Timer Bar


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


func init_unit_button(button : OptionButton, index : int):
	button.clear()
	button.add_item(EMPTY_UNIT_TEXT)
	for unit_path in unit_paths:
		button.add_item(unit_path.trim_prefix(CFG.UNITS_PATH))
	if not button.item_selected.is_connected(unit_in_army_changed):
		button.item_selected.connect(unit_in_army_changed.bind(index))


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

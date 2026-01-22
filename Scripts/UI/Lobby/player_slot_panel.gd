class_name PlayerSlotPanel
extends PanelContainer

enum TakeLeaveButtonState {
	FREE,
	TAKEN_BY_YOU,
	TAKEN_BY_OTHER,
	GHOST, # state when we display too much slots
}

var setup_ui # BattleSetup


var button_take_leave_state : TakeLeaveButtonState = TakeLeaveButtonState.FREE

@onready var player_info = $GeneralVContainer/TopBarHContainer/PlayerInfoPanel
@onready var label_name = $GeneralVContainer/TopBarHContainer/PlayerInfoPanel/Label


var button_battle_bot : OptionButton
@onready var team_list : OptionButton = $GeneralVContainer/TopBarHContainer/OptionButtonTeam


@onready var button_take_leave = $GeneralVContainer/TopBarHContainer/ButtonTakeLeave


@onready var battle_timer_reserve_minutes : SpinBox = $GeneralVContainer/TimerContainer/ReserveTime_Min_Edit
@onready var battle_timer_reserve_seconds : SpinBox = $GeneralVContainer/TimerContainer/ReserveTime_Sec_Edit
@onready var battle_timer_increment_seconds : SpinBox = $GeneralVContainer/TimerContainer/IncrementTimeEdit


var battle_bots_paths : Array[String]


#region Init

func _ready() -> void:
	battle_bots_paths = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_BOTS_PATH, true, true)
	init_battle_bots_button()


func init_battle_bots_button():
	button_battle_bot.clear()
	for battle_bot_name in battle_bots_paths:
		button_battle_bot.add_item(battle_bot_name.trim_prefix(CFG.BATTLE_BOTS_PATH))
	button_battle_bot.item_selected.connect(battle_bot_changed)


func fill_team_list(max_player_number : int) -> void:
	team_list.clear()
	team_list.add_item("No Team")
	for idx in range(1, max_player_number + 1):
		team_list.add_item("Team " + str(idx))

#endregion Init


#region Option Button select

func set_battle_bot(new_bot_path : String):
	var bot_path = new_bot_path if new_bot_path != "" else battle_bots_paths[0]
	var idx = battle_bots_paths.find(bot_path)
	assert(idx != -1, "Invalid bot '%s'" % bot_path)
	button_battle_bot.select(idx)
	battle_bot_changed(idx)


func battle_bot_changed(bot_index : int) -> void:
	# TODO network code
	IM.game_setup_info.set_battle_bot(setup_ui.slot_to_index(self), battle_bots_paths[bot_index])


func set_visible_team(team : int):
	team_list.selected = team

#endregion Option Button select


#region Basic Buttons

func try_to_take():
	if not setup_ui:
		return
	setup_ui.try_to_take_slot(self)


func try_to_leave():
	if not setup_ui:
		return
	setup_ui.try_to_leave_slot(self)


func set_visible_name(player_name : String):
	label_name.text = player_name

#endregion Basic Buttons




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





#region Color

func set_visible_color(c : Color):
	var style_box = get_theme_stylebox("panel")
	if not style_box is StyleBoxFlat:
		return
	var style_box_flat = style_box as StyleBoxFlat
	style_box_flat.bg_color = c


func cycle_color(backwards : bool = false):
	if not setup_ui:
		return
	setup_ui.cycle_color_slot(self, backwards)

#endregion Color



#region basic battle chess clock settings

func timer_changed(_value) -> void:
	if not should_react_to_changes():
		return

	var slot_index = setup_ui.slot_to_index(self)

	var seconds_reserve = battle_timer_reserve_minutes.value * 60 + battle_timer_reserve_seconds.value


	IM.game_setup_info.set_timer(slot_index, seconds_reserve, int(battle_timer_increment_seconds.value))
	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info) #TODO add multi support
	if NET.client:
		NET.client.queue_lobby_set_timer(slot_index, seconds_reserve, int(battle_timer_increment_seconds.value))


func set_visible_timers(reserve : int, increment : int):
	var reserve_minutes := int(reserve / 60)
	var reserve_seconds := reserve % 60
	battle_timer_reserve_minutes.value = reserve_minutes
	battle_timer_reserve_seconds.value = reserve_seconds
	battle_timer_increment_seconds.value = increment

#endregion basic battle chess clock settings


#region Button events

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


func _on_option_button_team_item_selected(index : int):
	if not should_react_to_changes():
		return
	var slot_index = setup_ui.slot_to_index(self) # determine on which slot player is

	IM.game_setup_info.set_team(slot_index, index)
	if NET.server:
		NET.server.broadcast_full_game_setup(IM.game_setup_info)
	if NET.client:
		NET.client.queue_lobby_set_team(slot_index, index)


func _on_button_color_pressed():
	if not should_react_to_changes():
		return
	cycle_color()

#endregion Button events


func show_bots_option_buttons() -> void:
	button_battle_bot.visible = true

func hide_bots_option_buttons() -> void:
	button_battle_bot.visible = false



func set_visible_take_leave_button_state(state : TakeLeaveButtonState):
	# maybe better get this from battle setup, but this is simpler
	button_take_leave_state = state
	hide_bots_option_buttons()
	player_info.visible = true
	match state:
		TakeLeaveButtonState.FREE:
			button_take_leave.text = "Take"
			button_take_leave.disabled = false
			show_bots_option_buttons()
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


func apply_bots_from_slot(slot : Slot) -> void:
	set_battle_bot(slot.battle_bot_path)


class_name BattlePlayerSlotPanel
extends PanelContainer


@onready var button_take_leave = $HBoxContainer/ButtonTakeLeave
@onready var label_name = $HBoxContainer/PlayerInfoPanel/Label
@onready var button_faction = $HBoxContainer/ButtonFaction
@onready var button_ai = $HBoxContainer/ButtonAI
@onready var buttons_units = [
	$HBoxContainer/OptionButtonUnit1,
	$HBoxContainer/OptionButtonUnit2,
	$HBoxContainer/OptionButtonUnit3,
	$HBoxContainer/OptionButtonUnit4,
	$HBoxContainer/OptionButtonUnit5,
]

enum TakeLeaveButtonState {
	FREE,
	TAKEN_BY_YOU,
	TAKEN_BY_OTHER,
	GHOST, # state when we display too much slots
}

enum AiButtonState {
	HUMAN,
	AI,
}


var setup_ui = null # TODO some base class for MultiBattleSetup and
					# MultiScenarioSetup
var button_take_leave_state : TakeLeaveButtonState = TakeLeaveButtonState.FREE
var button_ai_state : AiButtonState = AiButtonState.HUMAN

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


func cycle_ai(backwards : bool = false):
	button_ai_state += -1 if backwards else 1
	button_ai_state %= 2
	button_ai.text = AiButtonState.keys()[button_ai_state]
	pass


func set_visible_color(c : Color):
	var style_box = get_theme_stylebox("panel")
	if not style_box is StyleBoxFlat:
		return
	var style_box_flat = style_box as StyleBoxFlat
	style_box_flat.bg_color = c


func set_visible_name(player_name : String):
	label_name.text = player_name


func set_visible_take_leave_button_state(state : TakeLeaveButtonState):
	# maybe better get this from battle setup, but this is simpler
	button_take_leave_state = state
	match state:
		TakeLeaveButtonState.FREE:
			button_take_leave.text = "Take"
			button_take_leave.disabled = false
		TakeLeaveButtonState.TAKEN_BY_YOU:
			button_take_leave.text = "Leave"
			button_take_leave.disabled = false
		TakeLeaveButtonState.TAKEN_BY_OTHER:
			# ">> TAKEN <<" -- simple "Taken" would be too similar to "Take"
			button_take_leave.text = ">> TAKEN <<"
			button_take_leave.disabled = true
		TakeLeaveButtonState.GHOST:
			button_take_leave.text = "ghost"
			button_take_leave.disabled = true


func set_visible_faction(faction : DataFaction):
	pass
	#if faction == null:
		#button_faction.text = "nobody"
		#return
	#button_faction.text = faction.faction_name


func _ready():
	pass


func _on_button_take_leave_pressed():
	match button_take_leave_state:
		TakeLeaveButtonState.FREE:
			try_to_take()
		TakeLeaveButtonState.TAKEN_BY_YOU:
			try_to_leave()
		_:
			pass


func _on_button_color_pressed():
	cycle_color()

func _on_button_ai_pressed():
	cycle_ai()

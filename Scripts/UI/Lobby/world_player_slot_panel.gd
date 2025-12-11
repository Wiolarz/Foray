class_name WorldPlayerSlotPanel
extends PlayerSlotPanel


var world_bots_paths : Array[String]
var races_paths : Array[String]


@onready var button_world_bot = $GeneralVContainer/TopBarHContainer/OptionButtonWorldBot
@onready var button_race = $GeneralVContainer/TopBarHContainer/OptionButtonRace


#region Init

func _ready():
	button_battle_bot = get_node("GeneralVContainer/TopBarHContainer/OptionButtonBattleBot")

	world_bots_paths = FileSystemHelpers.list_files_in_folder(CFG.WORLD_BOTS_PATH, true, true)
	init_world_bots_button()

	init_race_button()

	super()


func init_world_bots_button():
	button_world_bot.clear()
	for world_bot_name in world_bots_paths:
		button_world_bot.add_item(world_bot_name.trim_prefix(CFG.WORLD_BOTS_PATH))
	button_world_bot.item_selected.connect(world_bot_changed)


func init_race_button():
	button_race.clear()
	for race in CFG.RACES_LIST:
		button_race.add_item(race.race_name)
	button_race.item_selected.connect(race_changed)

#endregion Init


#region Option Button select

func world_bot_changed(bot_index : int) -> void:
	# TODO network code
	IM.game_setup_info.set_world_bot(setup_ui.slot_to_index(self), world_bots_paths[bot_index])


func race_changed(race_index : int) -> void:
	# TODO network code
	IM.game_setup_info.set_race(setup_ui.slot_to_index(self), CFG.RACES_LIST[race_index])


func set_visible_race(race : DataRace):
	button_race.text = race.race_name

#endregion Option Button select


## override
func show_bots_option_buttons() -> void:
	button_battle_bot.visible = true
	button_world_bot.visible = true


## override
func hide_bots_option_buttons() -> void:
	button_battle_bot.visible = false
	button_world_bot.visible = false

##override
func apply_bots_from_slot(slot : Slot) -> void:
	set_battle_bot(slot.battle_bot_path)
	set_world_bot(slot.world_bot_path)



func set_world_bot(new_bot_path : String) -> void:
	var bot_path = new_bot_path if new_bot_path != "" else world_bots_paths[0]
	var idx = world_bots_paths.find(bot_path)
	assert(idx != -1, "Invalid bot '%s'" % bot_path)
	button_world_bot.select(idx)
	world_bot_changed(idx)




extends ScriptedBattleBrowser


@onready var ai_difficulty_selection : OptionButton = $MarginContainer/VBoxContainer/Columns/VBoxContainer/AIDifficulty


func _ready():
	super()
	var bot_paths = FileSystemHelpers.list_files_in_folder(CFG.BATTLE_BOTS_PATH, true, true)

	ai_difficulty_selection.clear()
	for bot_name in bot_paths:
		ai_difficulty_selection.add_item(bot_name.trim_prefix(CFG.BATTLE_BOTS_PATH))


func _set_types():
	content_folder_path = CFG.CAMPAIGN_BATTLES_ELVES_PATH


func activate_content() -> void:
	var bot_path : String =  CFG.BATTLE_BOTS_PATH + ai_difficulty_selection.get_item_text(ai_difficulty_selection.get_selected())
	IM.start_scripted_battle(_battle, bot_path)

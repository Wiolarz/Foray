class_name ScriptedBattleBrowser
extends ContentBrowser

var _battle : ScriptedBattle :
	get:
		return _selected_item as ScriptedBattle


@export_file var battle_bot_path : String = "res://Resources/Battle/Bots/Random.tscn"


func get_description() -> String:
	return _battle.scenario_name + "\n\n" + _battle.description


func activate_content() -> void:
	IM.start_scripted_battle(_battle, battle_bot_path)

extends CanvasLayer


func _init():
	BattleReplay.prepare_replay_directory()

func _ready():
	refresh_replays_disabled()

func refresh_replays_disabled():
	$Control/VBoxContainer/Replay.disabled = not BattleReplay.has_replays()

func _on_host_pressed():
	UI.go_to_host_lobby()

func _on_join_pressed():
	UI.go_to_client_lobby()


func _on_replay_pressed():
	$FileDialogReplay.show()


func _on_file_dialog_replay_file_selected(path):
	BM.perform_replay(path)


func _on_editors_menu_id_pressed(id):
	match id:
		0: _on_map_editor_pressed()
		1: _on_unit_editor_pressed()
		_: pass


func _on_unit_editor_pressed():
	UI.go_to_unit_editor()


func _on_map_editor_pressed():
	UI.go_to_map_editor()


func _on_visibility_changed():
	refresh_replays_disabled()

extends CanvasLayer


func _init():
	BattleReplay.prepare_replay_directory()


func _ready():
	refresh_replays_disabled()
	if CFG.AUTO_START_GAME:
		await get_tree().create_timer(0.1).timeout  # Waits for the Main menu UI to properly load, so it can be closed
		IM.start_game()  # auto start setting stored in player data

	$MainContainer/TopMenu/Tabs.current_tab = CFG.LAST_OPENED_TAB
	_on_tabs_tab_changed(CFG.LAST_OPENED_TAB)



func refresh_replays_disabled():
	($MainContainer/TopMenu/Tabs as TabBar).set_tab_disabled(4, not BattleReplay.has_replays())


func open_main_menu() -> void:
	show()
	$InGameMenuCover.visible = false
	$MainContainer/TopMenu/ReturnToGameButton.disabled = true


func open_in_game_menu() -> void:
	show()
	$InGameMenuCover.visible = true
	$MainContainer/TopMenu/ReturnToGameButton.disabled = false


#region Buttons

func _on_return_to_game_button_pressed() -> void:
	hide()


func _on_visibility_changed():
	refresh_replays_disabled()


func _on_host_button_pressed():
	_clear_tabs()
	$MainContainer/HostLobby.show()


func _on_join_button_pressed():
	_clear_tabs()
	$MainContainer/ClientLobby.show()


func _on_settings_button_pressed():
	_clear_tabs()
	$MainContainer/SettingsMenu.show()


func _on_credits_button_pressed():
	_clear_tabs()
	$MainContainer/CreditsMenu.show()


func _on_replays_tab_pressed():
	_clear_tabs()
	$MainContainer/ReplaysMenu.show()


func _on_learn_tab_pressed():
	_clear_tabs()
	$MainContainer/Learn.show()


func _on_defense_tab_pressed():
	_clear_tabs()
	$MainContainer/CityDefense.show()


func _clear_tabs():
	for child in $MainContainer.get_children():
		child.hide()
	$MainContainer/TopMenu.show()

func _on_unit_editor_button_pressed():
	UI.go_to_unit_editor()


func _on_tile_editor_button_pressed():
	UI.go_to_tile_editor()


func _on_map_editor_button_pressed():
	IM.go_to_map_editor()


func _on_exit_button_pressed():
	get_tree().quit()


func _on_tabs_tab_changed(tab_index : int):
	match tab_index:
		CFG.MainMenuTabs.SERVER: _on_host_button_pressed() # 0
		CFG.MainMenuTabs.JOIN: _on_join_button_pressed()  # 1
		CFG.MainMenuTabs.SETTINGS: _on_settings_button_pressed() # 2
		CFG.MainMenuTabs.CREDITS: _on_credits_button_pressed() # 3
		CFG.MainMenuTabs.REPLAYS: _on_replays_tab_pressed() # 4
		CFG.MainMenuTabs.LEARN: _on_learn_tab_pressed() # 5
		CFG.MainMenuTabs.DEFENSE: _on_defense_tab_pressed() # 6
		_: push_error("_on_tabs_tab_changed index not supported: "+str(tab_index))

	CFG.player_options.last_open_menu_tab = tab_index as CFG.MainMenuTabs
	CFG.save_player_options()

#endregion Buttons

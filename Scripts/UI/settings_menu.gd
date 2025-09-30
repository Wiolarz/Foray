extends Control

## Refer to player_controls.gd for information on adding new settings

func _ready():
	# You should put all PlayerOptions-widget connections here
	_declare_toggle("autostart_map", $ToggleAutoStart)
	_declare_toggle("use_default_AI_players", $ToggleDefaultAIPlayers)
	_declare_toggle("streamer_mode", $ToggleStreamerMode)
	_declare_toggle("fullscreen", $ToggleFullscreen)
	_declare_toggle("keep_main_menu_windowed", $ToggleAutoFullscreen)
	_declare_toggle("background_color_follows_players", $ToggleBackgroundColorFollowsPlayers)
	_declare_toggle("auto_win", $ToggleAutoWin)
	_declare_toggle("auto_win_against_neutrals", $ToggleAutoWinAgainstNeutrals)
	_declare_toggle("world_god_mode", $ToggleWorldGodMode)
	_declare_toggle("enable_fuzzing_mode", $EnableFuzzingMode)
	_declare_toggle("discord_rpc", $ToggleDiscordRPC)
	_declare_enum_list("gui_animation_mode", $OptionGuiAnimationMode/Option, {
		CFG.GuiAnimationMode.NONE: "None",
		CFG.GuiAnimationMode.NON_DISTRACTION: "Only non-distracting",
		CFG.GuiAnimationMode.FULL: "All"
	})
	_declare_enum_list("bmfast_integrity_check_mode", $LibSpearIntegrityChecks/Option, {
		CFG.BMFastIntegrityCheckMode.ASSERT: "Assert",
		CFG.BMFastIntegrityCheckMode.NOTIFY_ON_CHAT: "Notify on chat",
		CFG.BMFastIntegrityCheckMode.PUSH_ERROR_ONLY: "Only write error log",
		CFG.BMFastIntegrityCheckMode.DISABLE: "Disable",
	})
	_declare_volume_slider("volume_master", $VolumeContainer/Sliders/Master)
	_declare_volume_slider("volume_music", $VolumeContainer/Sliders/Music)
	_declare_volume_slider("volume_game", $VolumeContainer/Sliders/Game)
	_declare_volume_slider("volume_ui", $VolumeContainer/Sliders/UI)

#region Widgets
#region - Toggle

## Connect a given option with a widget
## Use as a template for other widgets
func _declare_toggle(option : StringName, node : CheckBox):
	# Immediately update option
	node.button_pressed = CFG.player_options.get(option)

	# Refresh button visuals when a setting is changed
	UI.update_settings.connect(func():
		# Lambda instead of bind because one callable can be only bound to signal once
		node.button_pressed = CFG.player_options.get(option)
	)

	# Bind a toggle press
	node.pressed.connect(func():
		# This one could be a dedicated func, but for consistency let's keep it that way
		var old_option = CFG.player_options.get(option)
		CFG.player_options.set(option, not old_option)
		CFG.save_player_options()
		UI.update_settings.emit()
	)

#endregion - Toggle


#region - Enum List

## Connect enum variable to an option button
func _declare_enum_list(enum_var : StringName, node : OptionButton, value_mappings : Dictionary):
	var id_enum_mappings := {}
	var enum_id_mappings := {}

	var c := -1
	for enum_item in value_mappings:
		c += 1
		node.add_item(value_mappings[enum_item])
		id_enum_mappings[c] = enum_item
		enum_id_mappings[enum_item] = c

	node.selected = enum_id_mappings[CFG.player_options.get(enum_var)]

	# Refresh visuals when a setting is changed
	UI.update_settings.connect(func():
		# Lambda instead of bind because one callable can be only bound to signal once
		var enum_value = CFG.player_options.get(enum_var)
		node.selected = enum_id_mappings[enum_value]
	)

	# Bind an item select
	node.item_selected.connect(func(index : int):
		CFG.player_options.set(enum_var, id_enum_mappings[index])
		CFG.save_player_options()
		UI.update_settings.emit()
	)


## Connect volume to a slider and button
func _declare_volume_slider(option : StringName, node : VolumeSlider):
	var update = func():
		var value = CFG.player_options.get(option)
		var mute = CFG.player_options.get(option + "_muted")
		node.actual_slider.value = value
		node.mute_button.button_pressed = mute
		node.actual_slider.modulate = Color.WHITE if not mute else Color.DIM_GRAY
		AUDIO.update_bus_volumes()

	# Refresh now
	update.call()
	# Refresh visuals when a setting is changed
	UI.update_settings.connect(update)

	# Bind a slider value change
	node.actual_slider.value_changed.connect(func(value):
		CFG.player_options.set(option, value)
		CFG.save_player_options()
		UI.update_settings.emit()
	)

	# Bind a mute button press
	# TODO pretty mute/unmute icons
	node.mute_button.pressed.connect(func():
		var value = CFG.player_options.get(option + "_muted")
		CFG.player_options.set(option + "_muted", not value)
		CFG.save_player_options()
		UI.update_settings.emit()
	)

#endregion - Toggle

#endregion - Enum List
#endregion Widgets


extends GutTest

const MAIN_MENU_UI_PATH = "/root/UI/MainMenu"
const WORLD_MODE_BUTTON_PATH = "/root/UI/MainMenu/MainContainer/HostLobby/HostMenu/" + \
		"PanelContainer/GameSetup/MarginContainer/VBoxContainer/ModeChoice/ButtonWorld"
const START_GAME_BUTTON_PATH = "/root/UI/MainMenu/MainContainer/HostLobby/HostMenu/" + \
		"PanelContainer/GameSetup/MarginContainer/VBoxContainer/ButtonConfirm"

const WORLD_UI_PATH = "/root/UI/WorldUI"
const DEFAULT_MAP_TILES_COUNT = 12*8
const OPEN_IN_GAME_MENU_PATH = "/root/UI/WorldUI/Menu"
const IN_GAME_MENU_PATH = "/root/UI/InGameMenu"
const IN_GAME_MENU_BACK_TO_MAIN_MENU_PATH = "/root/UI/InGameMenu/MenuContainer/ReturnToMainMenu"


func before_all():
	gut.p("INIT - go to main menu (as MainScene does)")
	CFG.AUTO_START_GAME = false # disable autostart cheat
	IM.go_to_main_menu()


func after_all():
	gut.p("INIT - hide main menu (restore state)")
	UI._hide_all()


func test_map_start_and_close() -> void:
	gut.p("click 'Full game' in lobby")
	var full_game_button = get_node(WORLD_MODE_BUTTON_PATH)
	assert_true( full_game_button.is_visible_in_tree(), \
		"Full Game button not visible")
	full_game_button.pressed.emit()

	gut.p("click 'Start' button in lobby")
	var lobby_start_button = get_node(START_GAME_BUTTON_PATH)
	assert_true( lobby_start_button.is_visible_in_tree(), \
		"Lobby Start button not visible")
	lobby_start_button.pressed.emit()

	gut.p("simple check if map loaded correctly")
	var world_ui = get_node(WORLD_UI_PATH)
	assert_is(world_ui, CanvasLayer, "World UI not a CanvasLayer")
	assert_true(world_ui.visible, "World UI not visible")
	# TODO: stabilize default map so that this test doesnt need to be updated
	# when new map is added and happens to be picked as first
	assert_eq(WM.get_node("GRID").get_child_count(), DEFAULT_MAP_TILES_COUNT, \
		"Map spawned, but tiles count not 12*8")
	assert_is(WM.get_node("GRID").get_child(0), TileForm, "Map spawned, but tiles are not TileForm")

	gut.p("open in game menu")
	var open_menu_button = get_node(OPEN_IN_GAME_MENU_PATH)
	open_menu_button.pressed.emit()

	var in_game_menu = get_node(IN_GAME_MENU_PATH)
	assert_true(in_game_menu.visible, "In game menu not visible")

	gut.p("press 'back to main menu' button")
	var quit_to_main_button =  get_node(IN_GAME_MENU_BACK_TO_MAIN_MENU_PATH)
	assert_true(quit_to_main_button.is_visible_in_tree(), \
		"back to main menu button not visible")

	quit_to_main_button.pressed.emit()
	await wait_frames(1) # wait for queue_free

	gut.p("check that main menu looks ok")
	assert_false(world_ui.visible, "World UI still visible")
	assert_eq(WM.get_node("GRID").get_child_count(), 0, "Map should be cleared")
	assert_true( get_node(MAIN_MENU_UI_PATH).visible, \
		"main menu is not visible")
	assert_true( get_node(START_GAME_BUTTON_PATH).is_visible_in_tree(), \
		"Start Game button is not visible")

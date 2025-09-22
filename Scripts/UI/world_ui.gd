class_name WorldUI
extends CanvasLayer

@onready var good_label : Label = $HBoxContainer/GoodsLabel
@onready var city_ui : CityUi = $CityUi
@onready var heroes_list : BoxContainer = $HeroesList
@onready var trade_screen : Control = $TradeScreen
@onready var army_panel : BoxContainer = $Army_Panel
@onready var level_screen : Control = $LevelUpWorldScreen


var _hideable_context_menu : Control :
	set(new_menu):
		if _hideable_context_menu:
				_hideable_context_menu.hide()
		_hideable_context_menu = new_menu
		if new_menu:
			$Hide.show()
			$Hide.text = "Hide"
			new_menu.show()
		else:
			$Hide.hide()



func _ready():
	city_ui.purchased_hero.connect(refresh_heroes)

	## UI visibility is independent from design view
	good_label.show()
	city_ui.show()
	heroes_list.show()
	trade_screen.hide()
	army_panel.hide()
	army_panel.show_level_up_screen.connect(show_level_up)
	$Hide.hide()
	# Game chat visibility is set in its own script
	$Players.show()
	$"End Turn".show()
	$Menu.show()


func _process(_delta):
	if WM.world_game_is_active():
		good_label.text = WS.get_current_player().goods.to_string()


func on_game_started():
	refresh_player_buttons()


func on_end_turn():
	try_to_close_context_menu()


func set_viewed_city(city : City) -> void:
	city_ui.set_viewed_city(city)


func refresh_heroes():
	Helpers.remove_all_children(heroes_list)
	var player_index = WS.current_player_index
	var player_state = WS.get_faction_by_index(player_index)
	if not player_state:
		return
	for army in player_state.hero_armies:
		var button := TextureButton.new()
		var hero_texture = army.hero.template.data_unit.texture_path
		button.texture_normal = load(hero_texture)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(200,200)
		if army.hero.movement_points == 0:
			button.modulate = Color.DIM_GRAY
		if WM.selected_hero and WM.selected_hero.entity == army:
			button.modulate = Color.FIREBRICK
		button.pressed.connect(func ():
			if army.controller_index == WM.get_current_player().index:
				WM.set_selected_hero(army)
				UI.camera.center_camera(WM.get_army_form(army))
		)
		heroes_list.add_child(button)


func refresh_player_buttons():
	var player_buttons = $Players.get_children()
	for i in range(player_buttons.size() - 1):
		var player := IM.players[i]
		var selected = player == WM.get_current_player()
		var button = player_buttons[i+1] as Button
		var text = player.get_player_name()
		if selected:
			text = " > " + text
		button.text = text
		button.modulate = player.get_player_color().color


#region Context Menus

func show_trade_ui(first_army : Army, second_army : Army):
	_show_context_menu(trade_screen)
	trade_screen.start_trade(first_army, second_army)


## temp - function is simplified to work only with currently selected hero
func show_level_up() -> void:
	if WM.selected_hero:

		level_screen.load_selected_hero_level_up_screen(WM.selected_hero.entity.hero)
		_show_context_menu(level_screen)


func _show_context_menu(menu : Control) -> void:
	hide_army_panel(false)
	_hideable_context_menu = menu


func try_to_close_context_menu() -> void:
	if _hideable_context_menu:
		_hideable_context_menu.hide()
		_hideable_context_menu = null
		_try_to_show_army_panel()

#endregion Context Menus


#region Army Panel

func load_army_to_panel(army : Army) -> void:
	army_panel.show()
	army_panel.load_army(army)


func hide_army_panel(unload_army : bool = true) -> void:
	if unload_army:
		army_panel.loaded_army = null
	army_panel.hide()


func _try_to_show_army_panel() -> void:
	if army_panel.loaded_army:
		refresh_army_panel()
		army_panel.show()


## Safe function, recreates army panel to account for any possible changes to list of units
func refresh_army_panel() -> void:
	if army_panel.loaded_army:
		army_panel.load_army(army_panel.loaded_army)

#endregion Army Panel


#region Buttons

func _on_menu_pressed():
	UI.main_menu.open_in_game_menu()


func _on_end_turn_pressed():
	WM.end_turn()


## Hides context menu while letting player option to reveal it
func _on_hide_pressed():
	if _hideable_context_menu.visible:
		_hideable_context_menu.hide()
		$Hide.text = "Show"
		_try_to_show_army_panel()
	else:
		_hideable_context_menu.show()
		$Hide.text = "Hide"
		hide_army_panel(false)

	pass # Replace with function body.

#endregion Buttons

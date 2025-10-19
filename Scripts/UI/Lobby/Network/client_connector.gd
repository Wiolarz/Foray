class_name ClientConnector
extends Control


"""
UI - smalll menu where you connect to a server
"""

var client_menu : ClientMenu = null


@onready var username_line = \
	$MainContainer/VBoxContainer/UserName/LineEdit
@onready var randomise_login : Button = \
	$MainContainer/VBoxContainer/UserName/RandomiseCheckBox
@onready var server_address_line = \
	$MainContainer/VBoxContainer/ManualConnection/ConnectionParameters/H/IPAddress/LineEdit
@onready var server_port_line = \
	$MainContainer/VBoxContainer/ManualConnection/ConnectionParameters/H/Port/LineEdit


func _ready():
	_fill_fields_from_last_used()
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	# sometimes called before ready inits @onready
	if username_line:
		_fill_fields_from_last_used()


func _fill_fields_from_last_used():
	username_line.text = CFG.get_username()
	randomise_login.set_pressed(CFG.player_options.randomise_join_login)
	server_address_line.text = CFG.player_options.last_remote_host_address
	server_port_line.text = str(CFG.player_options.last_remote_host_port)


func get_address():
	var server_on_list_selected : bool = false
	if server_on_list_selected:
		return "" # address of selected server
	return server_address_line.text


func get_port() -> int:
	var server_on_list_selected : bool = false
	if server_on_list_selected:
		return 0 # port of selected server
	return int(server_port_line.text)


func get_username()-> String:
	var user_name : String = username_line.text
	if user_name.is_empty():
		user_name = CFG.DEFAULT_PLAYER_NAME
	username_line.text = user_name
	return user_name

func _randomise(username : String) -> String:
	return "%s_%04d" % [username, randi_range(0000, 9999)]


func connect_to_server():
	var username = get_username()
	CFG.save_last_used_for_joining(get_address(), get_port(), get_username(), randomise_login.is_pressed())

	NET.clear_local_chat_log()
	if randomise_login.is_pressed():
		username = _randomise(username)
	NET.client_connect_and_login(get_address(), get_port(), username)


func _on_button_connect_pressed():
	connect_to_server()


func _on_button_back_pressed():
	client_menu.go_back()


func _on_refresh_servers_button_pressed():
	var servers_box = $MainContainer/VBoxContainer/ServerList/ColorRect/VBoxContainer
	for c in servers_box.get_children():
		servers_box.remove_child(c)
		c.queue_free()
	var loading_label := Label.new()
	loading_label.text = "loading..."
	servers_box.add_child(loading_label)
	var servers = await PolyApi.get_servers_list()
	servers_box.remove_child(loading_label)
	loading_label.queue_free()
	for s in servers:
		var b := Button.new()
		b.text = str(s)
		b.pressed.connect(func on_click():
			$MainContainer/VBoxContainer/ManualConnection/ConnectionParameters/H/IPAddress/LineEdit \
					.text = s.address
			$MainContainer/VBoxContainer/ManualConnection/ConnectionParameters/H/Port/LineEdit \
					.text = str(s.port)
			($MainContainer as ScrollContainer).scroll_vertical = 0
		)
		servers_box.add_child(b)

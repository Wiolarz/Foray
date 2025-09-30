class_name ServerCreator
extends Control

"""
UI - smalll menu where you setup a server
"""


var host_menu : HostMenu = null


@onready var server_name_line = \
	$MainContainer/VBoxContainer/ServerName/LineEdit
@onready var server_address_line = \
	$MainContainer/VBoxContainer/BindingOptions/IPAddress/LineEdit
@onready var server_port_line = \
	$MainContainer/VBoxContainer/BindingOptions/Port/LineEdit



func _ready():
	_fill_fields_from_last_used()
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed():
	# sometimes called before ready inits @onready
	if server_name_line:
		_fill_fields_from_last_used()


func _fill_fields_from_last_used():
	server_name_line.text = CFG.get_username()
	server_address_line.text = CFG.player_options.last_hosting_address_used
	server_port_line.text = str(CFG.player_options.last_hosting_port_used)


func start_server():
	CFG.save_last_used_for_host_setup(get_address(), get_port(), get_username_server())
	NET.clear_local_chat_log()
	NET.server_listen(get_address(), get_port(), get_username_server())
	host_menu.refresh_after_connection_change()


func get_address():
	return server_address_line.text


func get_port():
	return int(server_port_line.text)


func get_username_server():
	var server_name : String = server_name_line.text
	if server_name.is_empty():
		server_name = CFG.DEFAULT_PLAYER_NAME
	server_name_line.text = server_name
	return server_name


func _on_button_listen_pressed():
	start_server()


func _on_button_back_pressed():
	host_menu.go_back()

class_name HostMenu
extends Control

"""
Manager scripts that displays specific UI
"""
#TODO verify if current architecture is viable for extension of lobby features
## IF NOT - complete redesign of this part
## IF IT IS - create a parent class for HostMenu and ClientMenu

var server_creator_scene : PackedScene = load("res://Scenes/UI/Lobby/Network/ServerCreator.tscn")

var server_info_and_chat_scene : PackedScene = \
		load("res://Scenes/UI/Lobby/Network/ServerInfoAndChat.tscn")


@onready var server_management = $ServerManagement
@onready var multi_game_setup = $PanelContainer/GameSetup


func go_back():
	UI.go_to_main_menu()


func clear_management():
	for child in server_management.get_children():
		child.queue_free()


func show_server_creator():
	clear_management()
	var server_creator = server_creator_scene.instantiate()
	server_management.add_child(server_creator)
	server_creator.name = "ServerCreator"
	server_creator.host_menu = self


func show_server_info_and_chat():
	clear_management()

	var server_info_and_chat = server_info_and_chat_scene.instantiate()
	server_management.add_child(server_info_and_chat)
	server_info_and_chat.name = "ServerInfoAndChat"
	server_info_and_chat.host_menu = self


func refresh_after_connection_change():
	multi_game_setup.refresh_after_connection_change()


func _ready():
	show_server_creator()


func _process(_delta : float):
	var server_works : bool = NET.server_connection()
	if server_works and \
			not server_management.get_node_or_null("ServerInfoAndChat"):
		show_server_info_and_chat()
	elif not server_works and \
			not server_management.get_node_or_null("ServerCreator"):
		show_server_creator()

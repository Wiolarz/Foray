## Discord Manager
##
## Handles Discord Rich Presence.
## Automatically initializes Discord RPC on startup, continuously processes callbacks
## in the background, and provides methods to update player's Discord information
##
## Installation tutorial: https://github.com/vaporvee/discord-rpc-godot/wiki
## Discord developers account: https://discord.com/developers
extends Node


func _ready() -> void:
	init_discord_rich_presence()


func _process(_delta: float) -> void:
	DiscordRPC.run_callbacks()


func refresh():
	if CFG.player_options.discord_rpc:
		DiscordRPC.refresh()


func init_discord_rich_presence() -> void:
	DiscordRPC.app_id = 1406284593891643483  # Application ID
	DiscordRPC.state = "Sitting in main menu"
	DiscordRPC.large_image = "outpost_wood"  # Images stored at https://discord.com/developers

	DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())

	refresh()  # Always refresh after changing the values!


## Change state in rich presence [br]
## [state] stands for "The user's current party status"
func change_state(state: String) -> void:
	DiscordRPC.state = state

	refresh()


## Change details in rich presence [br]
## [details] stands for "What the player is currently doing"
func change_details(details: String) -> void:
	DiscordRPC.details = details

	refresh()


## Change party size in rich presence [br]
## [current_party_size] stands for "Current size of the player's party, lobby, or group" [br]
## [max_party_size] stand for "Maximum size of the player's party, lobby, or group"
func change_party_size(current_party_size: int, max_party_size: int) -> void:
	DiscordRPC.current_party_size = current_party_size
	DiscordRPC.max_party_size = max_party_size

	refresh()

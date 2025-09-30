# AUDIO - singleton
#class_name SINGLETON_AudioManager # TODO wait for class_name+singleton Godot bugfix, just like with ANIM
extends Node


## How to add new sounds: [br]
## 1. Add the sound file to one of Audio/* folders [br]
## 2. Add an AudioStreamPlayer (or AudioStreamPlayer2D) [br]
##    as a child node to Scenes/AudioManager.tscn [br]
##    Make sure to set appropriate *stream* and *bus*. [br]
##    You also may (or may not) want to adjust volume and max polyphony [br]
## 3. Add an entry in a dictionary below


@onready var sounds : Dictionary = {
	"click": $Click,
	"ingame_click": $IngameClick,
	"parry": $Parry,
	"magic_effect": $MagicEffect,
	"unit_death": $UnitDeath,
	"move": $Move,
	"turn": $Turn
}


## How to add new tracks: [br]
## 1. Put the music in Audio/Music folder [br]
## 2. Make sure to enable loop (double-click on a music file -> Loop) [br]
## 3. Add an entry in a dictionary below``
@onready var tracks : Dictionary = {
	"menu": preload("res://Audio/Music/exp.mp3"),
	"battle": preload("res://Audio/Music/polyspear_battle_demo_update.ogg"),
	"battle_drums": preload("res://Audio/Music/combat_drums.wav"),
	"victory": preload("res://Audio/Music/victory_song.wav"),
	"world": preload("res://Audio/Music/exploring.mp3"),
}

var current_track : String = ""

@onready var bus_idxs : Dictionary = {
	"volume_master": AudioServer.get_bus_index("Master"),
	"volume_music":  AudioServer.get_bus_index("Music"),
	"volume_game":   AudioServer.get_bus_index("Game"),
	"volume_ui":     AudioServer.get_bus_index("UI")
}


func _ready():
	update_bus_volumes() # Apply instantly to prevent a sonic jumpscare upon start
	get_tree().node_added.connect(_node_added)


func update_bus_volumes():
	for bus_name in bus_idxs:
		var muted = CFG.player_options.get(bus_name + "_muted")
		var volume_slider = CFG.player_options.get(bus_name) if not muted else 0
		var volume_linear = volume_slider/100.0
		var volume_db = 10.0 * log(volume_linear) / log(2)
		AudioServer.set_bus_volume_db(bus_idxs[bus_name], volume_db)


func play(sound_name : String):
	assert(sounds.get(sound_name) != null, "Unknown sound '%s'" % [sound_name])
	sounds[sound_name].play()


# For now a very simple immediate restart without even a fade-out
# TODO replace with Godot 4.4's AudioStreamInteractive
func play_music(track_name : String):
	assert(tracks.get(track_name) != null, "Unknown track '%s'" % [track_name])
	if current_track == track_name:
		return

	current_track = track_name
	$Music.stop()
	$Music.stream = tracks[track_name]
	$Music.play()


## Automatically bind sounds to all newly created UI elements
func _node_added(node : Node):
	if node is Button:
		node.pressed.connect(play.bind("click"))
	if node is TabBar:
		node.tab_changed.connect(func(_idx): play("click"))

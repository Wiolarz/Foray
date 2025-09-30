class_name VolumeSlider
extends Control

@export var title : String

@onready var actual_slider : Slider = $Slider
@onready var mute_button : Button = $ButtonMute
@onready var _title_label : Label = $Label

func _ready() -> void:
	_title_label.text = title

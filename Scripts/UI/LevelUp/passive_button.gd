class_name PassiveButton
extends PanelContainer

signal button_pressed

## TODO add passive icon
## TODO add logic related on hover to display description

@onready var label : Label = $Label
@onready var button : Button = $Button

var pressed : bool :
	set(value):
		button.button_pressed = value
	get:
		return button.button_pressed


## Obtained used in world to distinguished passives already locked to a character
func load_passive(passive : HeroPassive) -> void:
	label.hide()
	button.show()
	label.text = passive.passive_name
	button.text = passive.passive_name


func set_locked(locked_state : bool) -> void:
	if locked_state:
		button.hide()
		label.show()
	else:
		button.show()
		label.hide()


func enable() -> void:
	button.disabled = false


func disable() -> void:
	button.disabled = true
	button.button_pressed = false


func selected() -> void:
	button.button_pressed = true

func deselect() -> void:
	button.button_pressed = false


## Only activated through human input
func _on_button_pressed():
	button_pressed.emit()

@tool
class_name TextBubble
extends Resource

## description used in "is_prerequisite_fullfilled()" check
@export var prerequisite := BattleEventDescription.new()

@export var title : String :
	set(value):
		title = value
		resource_name = value
@export_multiline var text : String

## Optional icon that is displayed next to the speech bubble
@export_file var icon_path : String

func is_prerequisite_fullfilled(current_event : BattleEventDescription) -> bool:
	return prerequisite.is_description_satisfied(current_event)

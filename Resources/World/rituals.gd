class_name Ritual
extends Resource

@export var name : String = ""
@export_file var icon_path : String = ""
@export var mp_cost : int = 2

## used to debug
func _to_string() -> String:
	return "Ritual: " + name

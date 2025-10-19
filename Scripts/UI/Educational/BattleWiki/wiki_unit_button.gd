class_name WikiUnitButton
extends TextureButton

var unit : DataUnit

signal selected(unit)

func _on_pressed():
	selected.emit(unit)


func load_unit(unit_ : DataUnit) -> void:
		unit = unit_

		get_node("Label").text = unit.unit_name.capitalize()

		texture_normal = load(unit.texture_path)

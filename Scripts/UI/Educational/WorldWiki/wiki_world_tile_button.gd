class_name WikiTerrainButton
extends TextureButton

var tile : DataTile

signal selected(tile)

func _on_pressed():
	selected.emit(tile)


func load_tile(tile_ : DataTile) -> void:
		tile = tile_

		get_node("Label").text = tile.type.capitalize()

		texture_normal = load(tile.texture_path)

class_name WikiSymbolButton
extends TextureButton

var symbol : DataSymbol

signal selected(symbol)

func _on_pressed():
	selected.emit(symbol)


func load_symbol(symbol_ : DataSymbol) -> void:
		symbol = symbol_
		get_node("Label").text = symbol.symbol_name.capitalize()

		if symbol.symbol_name == "empty":
			texture_normal = null
			return
		texture_normal = load(symbol.texture_path)

extends Panel

@onready var button_columns : Array[VBoxContainer] = [ \
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column1,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column2,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column3]


@onready var symbol_information_title = $Margin/VBoxContainer/HBoxContainer/SymbolInformationContainer/VBox/WeaponName
@onready var symbol_information_description = $Margin/VBoxContainer/HBoxContainer/SymbolInformationContainer/VBox/RichTextLabel
@onready var symbol_information_icon = $Margin/VBoxContainer/HBoxContainer/SymbolInformationContainer/VBox/TextureRect


func _ready():
	generate_data_symbol_buttons()


func load_symbol(symbol : DataSymbol) -> void:
	symbol_information_title.text = symbol.symbol_name.capitalize()
	if symbol.symbol_name == "empty":
		symbol_information_icon.texture = null
	else:
		symbol_information_icon.texture = load(symbol.texture_path)

	var text_description = ""
	if symbol.attack_power > 0:
		match symbol.attack_power:
			1:
				text_description += "Attack - Weak(Orange) 1 - damage will be blocked even by an axe\n\n"
			2:
				text_description += "Attack - Normal(Blue) 2 - damage will be blocked by shields\n\n"
			3:
				text_description += "Attack - Strong(Red)  3 - damage will be blocked only by a Strong Red Shield\n\n"
	if symbol.reach > 0:
		text_description += "Range: " + str(symbol.reach) + "\n\n"

	match symbol.defense_power:
			0:
				text_description += "Lack of Defense 0 - even weak attacks can kill this unit if its not defended by any melee weapon\n\n"
			1:
				pass
			2:
				text_description += "Defense Normal(Blue) 2 - block any damage weaker than strong\n\n"
			3:
				text_description += "Defense Strong(Red)  3 - Blocks any non-magical source of damage\n\n"

	if symbol.push_power > 0:
		if symbol.push_power == 1:
			text_description += "Push Power 1 - Moves enemy 1 tile away, if that tile is occupied enemy will die \n"
		else:
			text_description += \
			"Push Power - moves enemy unit " + str(symbol.push_power) + " tiles away, \n" + \
			"if any of those tiles is occupied enemy will die.\n" + \
			"But if only the last one is occupied enemy will be pushed only " + str(symbol.push_power - 1) + " tiles away\n"



	var tags_description = "\nTags:\n"
	var tags_len = tags_description.length()
	if not (symbol.activate_turn and symbol.activate_move):
		if symbol.activate_turn:
			tags_description += "Activates only once on rotation\n"
		if symbol.activate_move:
			tags_description += "Activates only after unit has rotated and moved\n"

	if symbol.counter_attack:
		tags_description += "- Counter Attack (Spear) - strikes before unit can perform it's attack on that tile\n"
	if symbol.parry:
		tags_description += "- Parry (Sword) - Blocks any melee attack\n"
	if symbol.parry_break:
		tags_description += "- Parry Break - (Scythe -> sword counter, ignores enemy symbol Parry Tag)\n"

	if tags_description.length() > tags_len:
		text_description += tags_description

	symbol_information_description.text = text_description


func generate_data_symbol_buttons() -> void:
	# clean mockup ui
	for column in button_columns:
		for mock_button in column.get_children():
			mock_button.queue_free()

	var path = CFG.SYMBOLS_PATH
	var dir = DirAccess.open(path)
	var symbol_idx : int = -1
	for data_symbol_file_path in dir.get_files():
		symbol_idx += 1

		var data_symbol : DataSymbol = load(path + data_symbol_file_path)
		if symbol_idx == 0:
			load_symbol(data_symbol)

		var button : WikiSymbolButton = load("res://Scenes/UI/Wiki/BattleWiki/wiki_symbol_button.tscn").instantiate()
		button_columns[symbol_idx % button_columns.size()].add_child(button)
		button.load_symbol(data_symbol)

		button.selected.connect(load_symbol)

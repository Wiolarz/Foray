extends Panel

@onready var button_columns : Array[VBoxContainer] = [ \
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column1,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column2,
	$Margin/VBoxContainer/HBoxContainer/Scroll/VBox/HBoxContainer/Column3]


@onready var spell_information_title = $Margin/VBoxContainer/HBoxContainer/SpellInformationContainer/VBox/SpellName
@onready var spell_information_description = $Margin/VBoxContainer/HBoxContainer/SpellInformationContainer/VBox/RichTextLabel
@onready var spell_information_icon = $Margin/VBoxContainer/HBoxContainer/SpellInformationContainer/VBox/TextureRect

@onready var button_template : Resource = load("res://Scenes/UI/Wiki/BattleWiki/wiki_spell_button.tscn")

func _ready():
	generate_battle_spell_buttons()


func load_spell(battle_spell : BattleSpell) -> void:
	spell_information_title.text = battle_spell.name.capitalize()
	spell_information_icon.texture = load(battle_spell.icon_path)

	spell_information_description.text = battle_spell.description


func generate_battle_spell_buttons() -> void:
	# clean mockup ui
	for column in button_columns:
		for mock_button in column.get_children():
			mock_button.queue_free()

	var path = CFG.SPELLS_PATH
	var dir = DirAccess.open(path)
	var spell_idx : int = -1
	for battle_spell_file_path in dir.get_files():
		spell_idx += 1

		var battle_spell : BattleSpell = load(path + battle_spell_file_path)
		if spell_idx == 0:
			load_spell(battle_spell)

		var button : WikiSpellButton = button_template.instantiate()
		button_columns[spell_idx % button_columns.size()].add_child(button)
		button.load_spell(battle_spell)

		button.selected.connect(load_spell)

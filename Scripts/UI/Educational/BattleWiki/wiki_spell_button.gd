class_name WikiSpellButton
extends TextureButton

var spell : BattleSpell

signal selected(spell)

func _on_pressed():
	selected.emit(spell)


func load_spell(spell_ : BattleSpell) -> void:
		spell = spell_

		get_node("Label").text = spell.name.capitalize()

		texture_normal = load(spell.icon_path)

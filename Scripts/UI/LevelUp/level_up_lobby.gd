extends LevelUpScreen

signal confirm_button

@onready var hero_level_value : OptionButton = $VBox/HeroLevelValue


func _assign_tier_panels() -> void:
	description = $VBox/RichTextLabel

	tier_talent_panels = []
	tier_talent_panels.append($VBox/TierPanels/TierTalentPanel)
	tier_talent_panels.append($VBox/TierPanels/TierTalentPanel2)
	tier_talent_panels.append($VBox/TierPanels/TierTalentPanel3)

	tier_skill_panels = []
	tier_skill_panels.append($VBox/TierPanels/TierSkillPanel)
	tier_skill_panels.append($VBox/TierPanels/TierSkillPanel2)
	tier_skill_panels.append($VBox/TierPanels/TierSkillPanel3)

	tier_panels = []
	tier_panels.append_array(tier_talent_panels)
	tier_panels.append_array(tier_skill_panels)



func load_lobby_level_up_screen(hero : Hero) -> void:
	selected_hero = hero
	chosen_abilities = [[], [], []]
	chosen_talents = [-1, -1, -1]


	for tier_panel in tier_panels:
		tier_panel.set_hero(selected_hero, false)
	hero_level_value.selected = hero.level - 1
	hero_level_value.text = "Hero Level: " + str(hero.level)


func _on_hero_level_value_item_selected(_index : int):
	var hero_level : int = hero_level_value.selected + 1
	hero_level_value.text = "Hero Level: " + str(hero_level)
	selected_hero.level = hero_level
	for tier_panel : PanelContainer in tier_panels:
		tier_panel.set_hero(selected_hero, false)


func city_defense_lock_hero_level():
	hero_level_value.disabled = true
	hero_level_value.text = "Hero Level: " + str(selected_hero.level)
	for tier_panel : PanelContainer in tier_panels:
		tier_panel.set_hero(selected_hero, false)


func _on_confirm_button_pressed():
	confirm_button.emit()

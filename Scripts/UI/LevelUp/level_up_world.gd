extends LevelUpScreen


# override
func _assign_tier_panels() -> void:
	tier_talent_panels = []
	tier_talent_panels.append($TierPanels/TierTalentPanel)
	tier_talent_panels.append($TierPanels/TierTalentPanel2)
	tier_talent_panels.append($TierPanels/TierTalentPanel3)

	tier_skill_panels = []
	tier_skill_panels.append($TierPanels/TierSkillPanel)
	tier_skill_panels.append($TierPanels/TierSkillPanel2)
	tier_skill_panels.append($TierPanels/TierSkillPanel3)

	tier_panels = []
	tier_panels.append_array(tier_talent_panels)
	tier_panels.append_array(tier_skill_panels)


func load_selected_hero_level_up_screen(hero : Hero) -> void:
	selected_hero = hero
	chosen_abilities = [[], [], []]
	chosen_talents = [-1, -1, -1]
	for tier_panel in tier_panels:
		tier_panel.set_hero(selected_hero, true)
	$HeroLevelValue.text = "Hero Level: " + str(selected_hero.level)


func _on_button_confirm_pressed():
	apply_talents_and_abilities()
	WM.world_ui.try_to_close_context_menu()

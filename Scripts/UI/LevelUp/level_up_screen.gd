class_name LevelUpScreen
extends Control

var selected_hero : Hero

var tier_panels : Array[PanelContainer]

## Each number represents choice from subsequent tier [br]
##  -1 - No Talent taken [br]
## 0-2 Might, Tactic, Magic
var chosen_talents : Array[int] = [-1, -1, -1]

## 3 sub arrays Each coresponds each tier [br]
## Tier can have at most two numbers [br]
## If number appears this ability has been chosen [br]
## 0-2 Might, Tactic, Magic
var chosen_abilities : Array = [[], [], []]

## Currently there is no difference between level up for various races so level up screen can be generated once
func _ready() -> void:
	var tier_panel_container_children : Array[Node] = _get_tier_panel_children()
	for tier_panel_child : Node in tier_panel_container_children:
		assert(tier_panel_child is PanelContainer)
		tier_panels.append(tier_panel_child as PanelContainer)

	var tier_idx = -1
	for tier_panel in tier_panels:
		tier_idx += 1
		tier_panel.init_tier_panel(tier_idx)
		tier_panel.talent_chosen.connect(_selected_talent)
		tier_panel.ability_chosen.connect(_selected_ability)


# to be overriden
func _get_tier_panel_children() -> Array[Node]:
	assert(false)
	return []


func apply_talents_and_abilities() -> void:
	for tier in range(3):
		var talent_idx = chosen_talents[tier]
		if talent_idx >= 0:
			var new_talent : HeroPassive = CFG.talents[tier][talent_idx]
			if new_talent not in selected_hero.passive_effects:
				selected_hero.passive_effects.append(new_talent)

		for ability_idx : int in chosen_abilities[tier]:
			var new_ability : HeroPassive = CFG.abilities[tier][ability_idx]
			if new_ability not in selected_hero.passive_effects:
				selected_hero.passive_effects.append(new_ability)


func _selected_talent(tier : int, button_idx : int) -> void:
	#log(tier, button_idx)
	chosen_talents[tier] = button_idx


func _selected_ability(tier : int, button_idx : int, selected : bool) -> void:
	#log(tier, button_idx)
	if selected:
		chosen_abilities[tier].append(button_idx)
		assert(chosen_abilities[tier].size() <= 2)
	else:
		chosen_abilities[tier].erase(button_idx)

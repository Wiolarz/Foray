# TierPanel
extends PanelContainer


signal talent_chosen(tier_idx : int, button_idx : int)

signal ability_chosen(tier_idx : int, button_idx : int, deselect : bool)

## helps determine already selected passives
var tier : int
## dynamically limits buttons
var hero_level : int

## hero level 1-6
## tiers += 1 (tiers go from 1-3, not 0-2)
## level corresponds with number of avalaible_abilities directly 1-1 3-3 etc.
## but on a tier
## tier * 2 for tiers: 0, 2, 4
## hero_level 1-6
## Tier 1: lvl 1: 1 - 0 = 1 avalaible skill lvl 2: 2 - 0 = 2
## Tier 2: lvl 3: 3-2 = 1 etc.
var number_of_avalaible_abilities : int

@onready var tier_name = $MainContainer/TierLabel

@onready var talent_buttons : Array[PassiveButton] = [
	$MainContainer/TierUpgrades/PowerPassiveButton,
	$MainContainer/TierUpgrades/TacticPassiveButton,
	$MainContainer/TierUpgrades/MagicPassiveButton
]
@onready var ability_buttons : Array[PassiveButton] = [
	$MainContainer/TierSkills/PowerSkillButton,
	$MainContainer/TierSkills/TacticSkillButton,
	$MainContainer/TierSkills/MagicSkillButton,
]

## called by _ready in level_up_screen
func init_tier_panel(tier_ : int) -> void:
	tier_name.text = "TIER - " + str(tier_ + 1)
	tier = tier_
	var button_idx : int = -1
	for ability_button in ability_buttons:
		button_idx += 1
		var ability : HeroPassive = CFG.abilities[tier][button_idx]
		if ability: # TEMP null check until all pasives in level_up_screen are present
			ability_button.load_passive(ability)

		var lambda = func on_click():
			_ability_pressed(button_idx)
		ability_button.button_pressed.connect(lambda)

	button_idx = -1
	for talent_button in talent_buttons:
		button_idx += 1
		var talent : HeroPassive = CFG.talents[tier][button_idx]
		if talent:  # TEMP null check until all pasives in level_up_screen are present
			talent_button.load_passive(talent)

		var lambda = func on_click():
			_talent_pressed(button_idx)
		talent_button.button_pressed.connect(lambda)


#region Hero level

func set_hero(hero : Hero, is_in_world : bool = false) -> void:
	hero_level = hero.level

	# 1 Reset state to load a new hero
	for talent_button in talent_buttons:
		talent_button.deselect()
	for ability_button in ability_buttons:
		ability_button.deselect()

	var locked_talent : int = -1
	# 2 Load selected hero already chosen passives
	for talent_idx in range(3):
		if CFG.talents[tier][talent_idx] in hero.passive_effects:
			talent_chosen.emit(tier, talent_idx)
			talent_buttons[talent_idx].selected()
			talent_buttons[talent_idx].set_locked(is_in_world)
			if is_in_world:
				locked_talent = true
		else:
			talent_buttons[talent_idx].set_locked(false)

	var locked_abilities : Array[int] = []
	for ability_idx in range(3):
		if CFG.abilities[tier][ability_idx] in hero.passive_effects:
			ability_chosen.emit(tier, ability_idx, false)
			ability_buttons[ability_idx].selected()
			ability_buttons[ability_idx].set_locked(is_in_world)
			if is_in_world:
				locked_abilities.append(ability_idx)
		else:
			ability_buttons[ability_idx].set_locked(false)

	if is_in_world:
		_world_buttons_adjustment(locked_talent, locked_abilities)
	else:
		_talents_adjustments()
		_abilities_adjustments()


func _talents_adjustments() -> void:
	var can_choose_talent : bool = true
	if tier == 0 and hero_level == 1:
		can_choose_talent = false
	elif (hero_level - (tier * 2)) <= 0:  # 3 or 5
		can_choose_talent = false
	#log("talents", tier, can_choose_talent)
	if not can_choose_talent:
		_disable_talents()
	else:
		for talent_button in talent_buttons:   # enable talent buttons
			talent_button.enable()


func _abilities_adjustments() -> void:
	number_of_avalaible_abilities = hero_level - (tier * 2)
	#log("number_of_avalaible_abilities", tier, number_of_avalaible_abilities)


	if number_of_avalaible_abilities == 1:
		_disable_abilities(true)
	elif number_of_avalaible_abilities < 1:
		_disable_abilities(false)
	else:
		var number_of_selected_abilities : int = 0
		for ability_button in ability_buttons:  # check if buttons can be enabled
			if ability_button.pressed:
				number_of_selected_abilities += 1
		if number_of_selected_abilities < 2:
			for ability_button in ability_buttons:  # enable ability buttons
				ability_button.enable()


func _world_buttons_adjustment(locked_talent : int, locked_abilities : Array[int]) -> void:
	# adjust TALENTS buttons
	if locked_talent != -1:
		for talent_idx in range(3):
			if talent_idx != locked_talent:
				talent_buttons[talent_idx].disable()
	else:
		_talents_adjustments()

	if locked_abilities.size() == 0:
		_abilities_adjustments()
	if locked_abilities.size() == 2:
		for ability_idx in range(3):
			if ability_idx not in locked_abilities:
				ability_buttons[ability_idx].disable()
	if locked_abilities.size() == 1:
		number_of_avalaible_abilities = hero_level - (tier * 2)
		for ability_idx in range(3):
			if ability_idx not in locked_abilities:
				if number_of_avalaible_abilities > 1:
					ability_buttons[ability_idx].enable()
				else:
					ability_buttons[ability_idx].disable()






func _disable_talents() -> void:
	talent_chosen.emit(tier, -1)  # deselects
	for talent_button in talent_buttons:
		talent_button.disable()


func _disable_abilities(hero_can_take_one_ability : bool = false) -> void:
	if not hero_can_take_one_ability: # disable all abilities
		for button_idx in range(3):
			if ability_buttons[button_idx].pressed:
				ability_buttons[button_idx].pressed = false
				_ability_pressed(button_idx) # Deselects

		for ability_button in ability_buttons:
			ability_button.disable()
		return

	# hero_can_take_one_ability Region:

	var one_is_chosen : bool = false  # first option selected is not touched
	for button_idx in range(3):
		if ability_buttons[button_idx].pressed and not one_is_chosen:
			one_is_chosen = true  # Ignore this one
		elif ability_buttons[button_idx].pressed:  #
			ability_buttons[button_idx].pressed = false
			_ability_pressed(button_idx) # Deselects

	for ability_button in ability_buttons:  # Disabling / Unlocking based on one_is_chosen
		if one_is_chosen and not ability_button.pressed:  # disable other buttons
			ability_button.disable()
		else:
			ability_button.enable()  # unlock all buttons

#endregion Hero level

#region Buttons

func _ability_pressed(pressed_button_idx : int):
	#log("ability " + str(pressed_button_idx))
	if not ability_buttons[pressed_button_idx].pressed:  # Deselects
		ability_chosen.emit(tier, pressed_button_idx, false)
		for ability_button in ability_buttons:
			ability_button.enable()
		return

	ability_chosen.emit(tier, pressed_button_idx, true)

	assert(number_of_avalaible_abilities > 0, "ability button was not properly disabled")

	if number_of_avalaible_abilities == 1:  ## Hero can have only one Ability
		var button_idx = -1
		for ability_button in ability_buttons:
			button_idx += 1
			if pressed_button_idx != button_idx:
				assert(not ability_button.pressed)
				ability_button.disable()
		return

	## Hero can have two Abilities
	var buttons_indexes : Array[int] = [0, 1, 2]
	for button_idx in range(3):
		if ability_buttons[button_idx].pressed:
			buttons_indexes.erase(button_idx)

	if buttons_indexes.size() == 2:
		return

	if buttons_indexes.size() == 1:  # Two buttons are pressed -> disable 3rd one
		ability_buttons[buttons_indexes[0]].disable()


func _talent_pressed(pressed_button_idx : int):
	#log("talent " + str(pressed_button_idx))
	if talent_buttons[pressed_button_idx].pressed:
		talent_chosen.emit(tier, pressed_button_idx)
	else:
		talent_chosen.emit(tier, -1)  # resets the state
		return

	var button_idx = -1
	for talent_button in talent_buttons:
		button_idx += 1
		if pressed_button_idx != button_idx:
			talent_button.pressed = false

#endregion Buttons

# TierPanel
extends PanelContainer


signal talent_chosen(tier_idx : int, button_idx : int)

## helps determine already selected passives
var tier : int
## dynamically limits buttons
var hero_level : int

@onready var tier_name = $MainContainer/TierLabel

@onready var talent_buttons : Array[PassiveButton] = [
	$MainContainer/TierUpgrades/PowerPassiveButton,
	$MainContainer/TierUpgrades/TacticPassiveButton,
	$MainContainer/TierUpgrades/MagicPassiveButton
]

## called by _ready in level_up_screen
func init_tier_panel(tier_ : int) -> void:
	tier_name.text = "TIER - " + str(tier_ + 1)
	tier = tier_
	var button_idx : int = -1

	for talent_button in talent_buttons:
		button_idx += 1
		var talent : HeroPassive = CFG.talents[tier][button_idx]
		if talent:  # TEMP null check until all passives in level_up_screen are present
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

	if is_in_world:
		_adjust_world_buttons(locked_talent)
	else:
		_adjust_talents()


func _adjust_talents() -> void:
	var can_choose_talent : bool = true
	if tier == 0 and hero_level == 1:
		can_choose_talent = false
	elif (hero_level - (tier * 2)) <= 0:  # 3 or 5
		can_choose_talent = false
	#log("talents", tier, can_choose_talent)
	if not can_choose_talent:
		_disable_talents()
	else:
		for talent_button in talent_buttons:  # enable talent buttons
			talent_button.enable()


func _adjust_world_buttons(locked_talent : int) -> void:
	if locked_talent != -1:
		for talent_idx in range(3):
			if talent_idx != locked_talent:
				talent_buttons[talent_idx].disable()
	else:
		_adjust_talents()


func _disable_talents() -> void:
	talent_chosen.emit(tier, -1)  # deselects
	for talent_button in talent_buttons:
		talent_button.disable()

#endregion Hero level

#region Buttons

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

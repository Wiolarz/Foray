class_name PresetArmy
extends Resource

## DataUnit
@export var units : Array[DataUnit]

## DataHero
@export var hero : DataHero = null

## starting team assigned - 0 - no team(FFA)
@export var team : int = 0


static func generate_from_army(army : Army) -> PresetArmy:
	var result := PresetArmy.new()
	# Saving army state can occur mid game, to account for this duplicate() is required
	result.units = army.units_data.duplicate()
	result.hero = army.hero.template.duplicate()
	result.hero.starting_passives = army.hero.passive_effects.duplicate()
	return result

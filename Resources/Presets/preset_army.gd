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
	result.units = army.units_data.duplicate()
	result.hero = army.hero.template.duplicate()
	#TODO add saving of hero level choices
	return result

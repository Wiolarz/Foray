class_name WikiRaceButton
extends TextureButton

var race : DataRace

signal selected(race)

func _on_pressed():
	selected.emit(race)


func load_race(race_ : DataRace) -> void:
		race = race_

		$Label.text = race.race_name.capitalize()

		texture_normal = load(race.units_data[0].texture_path) # TODO add race icon

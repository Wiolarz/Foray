class_name DataRace
extends Resource


@export var race_name : String

## list of units avalaible in the battle lobby [br]
## should be a copy of the units offered by the buildings list
@export var units_data : Array[DataUnit]

@export var heroes : Array[DataHero]

@export var buildings : Array[DataBuilding]

@export_multiline var description : String

func get_network_id() -> String:
	return resource_path


static func from_network_id(network_id : String) -> DataRace:
	return load(network_id) as DataRace


# no factory needed

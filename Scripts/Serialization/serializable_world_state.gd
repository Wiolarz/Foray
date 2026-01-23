extends Resource
class_name SerializableWorldState

class PlayerState extends Resource:
	@export var goods : Array[int]
	@export var dead_heroes : Array[Dictionary]
	@export var outpost_buildings : Array[String]
	@export var armies : Array[Vector2i]
	# TODO consider saving race here

@export var army_hexes : Dictionary[Vector2i, Dictionary]
@export var place_hexes : Dictionary[Vector2i, Variant]
@export var current_player : int = 0
@export var players : Array[PlayerState]


func valid() -> bool:
	var player_number = players.size()
	return player_number > 0 and current_player in range(player_number)

static func get_network_serialized(world_state : SerializableWorldState) \
		-> PackedByteArray:
	if not world_state:
		return PackedByteArray()
	var player_array = []
	for player in world_state.players:
		player_array.append({
			"goods": player.goods,
			"dead_heroes": player.dead_heroes,
			"outpost_buildings" : player.outpost_buildings,
			"armies": player.armies,
		})
	var dict : Dictionary[String, Variant] = {
		"armies": world_state.army_hexes,
		"places": world_state.place_hexes,
		"current_player": world_state.current_player,
		"players": player_array,
	}
	return var_to_bytes(dict)


static func from_network_serialized(ser : PackedByteArray):
	var dict = bytes_to_var(ser)
	var sws := SerializableWorldState.new()
	sws.army_hexes = dict["armies"]
	sws.place_hexes = dict["places"]
	var players_number = dict["players"].size()
	sws.players.resize(players_number)
	for index in players_number:
		sws.players[index] = PlayerState.new()
		sws.players[index].goods.assign(
			dict["players"][index]["goods"].duplicate())
		for army in dict["players"][index]["armies"]:
			sws.players[index].armies.append(army)
		for dead_hero in dict["players"][index]["dead_heroes"]:
			sws.players[index].dead_heroes.append(dead_hero)
		for outpost_building in dict["players"][index]["outpost_buildings"]:
			sws.players[index].outpost_buildings.append(outpost_building)
	sws.current_player = dict["current_player"]
	return sws

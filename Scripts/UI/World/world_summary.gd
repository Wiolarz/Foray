class_name WorldSummary
extends Summary


const WORLD_SUMMARY_SCENE_PATH := "res://Scenes/UI/World/WorldSummary.tscn"
const WORLD_SUMMARY_PLAYER_SCENE_PATH := "res://Scenes/UI/World/WorldSummaryPlayerStats.tscn"


static func create(parent : Node, info : DataWorldSummary, \
			continue_callback : Callable) -> WorldSummary:
	var result = load(WORLD_SUMMARY_SCENE_PATH).instantiate()
	parent.add_child(result)
	result.set_visible_state_from_info(info)
	if continue_callback:
		result.continued.connect(continue_callback)
	return result


## Generates text info for every player based on content data
func set_visible_state_from_info(content : DataWorldSummary) -> void:
	assert(content, "world summary haven't received data")

	set_visible_title(content.title)
	set_visible_color(content.color)

	clear_players()  # clears mocap
	for player in content.players:
		var player_stats : WorldSummaryPlayerStats = \
			load(WORLD_SUMMARY_PLAYER_SCENE_PATH).instantiate()
		player_list.add_child(player_stats)
		player_stats.player_description.text = player.player_description
		player_stats.state_label.text = player.state
		player_stats.heroes_list.text = player.heroes

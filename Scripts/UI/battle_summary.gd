class_name BattleSummary
extends Summary


const BATTLE_SUMMARY_SCENE_PATH := "res://Scenes/UI/Battle/BattleSummary.tscn"
const BATTLE_SUMMARY_PLAYER_SCENE_PATH := "res://Scenes/UI/Battle/BattleSummaryPlayerStats.tscn"


static func create(parent : Node, info : DataBattleSummary, \
			continue_callback : Callable) -> BattleSummary:
	var result = load(BATTLE_SUMMARY_SCENE_PATH).instantiate()
	parent.add_child(result)
	result.set_visible_state_from_info(info)
	if continue_callback:
		result.continued.connect(continue_callback)
	return result


## Generates text info for every player based on content data
func set_visible_state_from_info(content : DataBattleSummary) -> void:
	assert(content, "battle summary haven't received data")

	set_visible_title(content.title)
	set_visible_color(content.color)

	clear_players()
	for player in content.players:
		var player_stats : BattleSummaryPlayerStats = \
			load(BATTLE_SUMMARY_PLAYER_SCENE_PATH).instantiate()
		player_list.add_child(player_stats)
		player_stats.player_description.text = player.player_description
		player_stats.state_label.text = player.state
		player_stats.losses_list.text = player.losses

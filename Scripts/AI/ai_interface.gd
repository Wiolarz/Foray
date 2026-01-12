@abstract class_name AIInterface
extends Node

var me : Player

# Bugfix - there was a chance that when a new battle is started,
# a bot from the old one will try to perform a move
var battle_id : int

func set_player(controlled_player: Player):
	me = controlled_player


@abstract func choose_move(_battle_state : BattleGridState) -> MoveInfo



## An OPTIONAL interface function
func cleanup_after_move():
	pass

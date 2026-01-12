@abstract class_name AIWorldInterface
extends Resource

var me : Player


func set_player(controlled_player : Player):
	me = controlled_player


@abstract func choose_move() -> WorldMoveInfo


## An OPTIONAL interface function
func cleanup_after_move():
	pass

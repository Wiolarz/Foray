class_name AIWorldInterface
extends Resource

var me : Player


func set_player(controlled_player : Player):
	me = controlled_player


func choose_move() -> WorldMoveInfo:
	assert(false, "ERROR: AI interface has not been implemented (for player %s)" % [me])
	# dead code, just to force godot to not throw warnings on awaiting and mark this method as async
	await Signal()
	return null


## An OPTIONAL interface function
func cleanup_after_move():
	pass

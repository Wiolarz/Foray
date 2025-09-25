class_name AIInterface
extends Node

var me : Player

# Bugfix - there was a chance that when a new battle is started,
# a bot from the old one will try to perform a move
var battle_id : int

func set_player(controlled_player: Player):
	me = controlled_player

func choose_move(_battle_state : BattleGridState) -> MoveInfo:
	assert(false, "ERROR: AI interface has not been implemented (for player %s)" % [me])
	# dead code, just to force godot to not throw warnings on awaiting and mark this method as async
	await Signal()
	return null

func cleanup_after_move():
	# An OPTIONAL interface function
	pass

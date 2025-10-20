class_name AiWorldBotAfk
extends AIWorldInterface


func choose_move() -> WorldMoveInfo:
	return WorldMoveInfo.make_end_turn()

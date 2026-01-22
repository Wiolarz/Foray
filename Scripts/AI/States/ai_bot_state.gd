@abstract class_name AiBotState
extends Node

"""
Parent class of AI States

All childs have to implement:
choose_move(legal_moves)
"""

@export var tags : Array[ExampleBot.TAG] = []

var me : Player


func _init(my_tags : Array[ExampleBot.TAG], my_player:Player):
	tags = my_tags
	name = "AiBotState" + str(my_tags)
	me = my_player


@abstract func choose_move(_battle_state : BattleGridState) -> MoveInfo

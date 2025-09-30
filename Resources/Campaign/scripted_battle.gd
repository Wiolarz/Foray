class_name ScriptedBattle
extends Resource

@export var scenario_name : String

## used for "Practice mode" content menu description [br]
## for campaign battles its a spot for developers notes
@export_multiline var description : String


## index of the army player will control
@export var player_side : int = 0


@export var armies : Array[PresetArmy] = []

@export var battle_map : DataBattleMap

@export var text_bubbles : Array[TextBubble] = []


# TODO add function that takes in player world army to use it during scripted battle

## Goes through all text bubbles and showing the first one that the current battle state fits.[br]
## Their prerequisites should be designed in a way that only one should show on the same turn.
func show_text_bubbles(current_event : BattleEventDescription) -> void:
	for bubble_idx : int in range(text_bubbles.size() - 1, -1, -1):  # Text bubbles are removed after they are shown once
		var text_bubble : TextBubble = text_bubbles[bubble_idx]
		if text_bubble.is_prerequisite_fullfilled(current_event):
			#print(text_bubble.text)
			BM._battle_ui.show_text_bubble(text_bubble)
			text_bubbles.remove_at(bubble_idx)
			return #TODO create a system to detect if more text bubbles fit current battle state, and are shown in some order

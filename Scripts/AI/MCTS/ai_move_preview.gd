class_name AIMovePreview
extends Node2D

const cross_marker_path = "res://Art/old/spear.png" # TODO change

var root : BattleManagerFast
var mcts : BattleMCTSManager = null
var thread := Thread.new()
var mutex := Mutex.new()

# Synchronization
var update_markers := false
var run_mcts := false

## MoveInfo => float
var move_scores_raw : Dictionary
var min_score := 0.0
var max_score := 1.0

## Vector2i => PositionMarker
var pos_markers: Dictionary
var markers : Array[Node2D]

@onready var reference_bot = load("res://Resources/Battle/Bots/MCTS_Hard.tscn")
@onready var arrow_marker = load("res://Scenes/UI/Battle/MoveMarkerArrow.tscn")


func _process(_delta):
	mutex.lock()
	if update_markers:
		update_markers = false
		_update_markers()

	mutex.unlock()


func update(bgs: BattleGridState):
	mutex.lock()
	run_mcts = false

	root = BattleManagerFast.from(bgs)
	if mcts:
		mcts.queue_free()
	mcts = BattleMCTSManager.new()
	add_child(mcts)
	var ref : AIBattleBotMCTS = reference_bot.instantiate()

	mcts.set_root(root)
	mcts.max_sim_iterations = ref.max_sim_turns
	mcts.heuristic_probability = ref.heuristic_probability
	mcts.heuristic_prior_reward_per_iteration = ref.heuristic_prior_reward_per_iteration
	mcts.max_playouts_per_visit = ref.max_playouts_per_visit
	mcts.debug_bmfast_internals = CFG.debug_check_bmfast_internals
	mcts.debug_max_saved_fail_replays = 4

	mutex.unlock()

	if thread.is_started():
		thread.wait_to_finish()
	run_mcts = true
	thread = Thread.new()
	thread.start(_thread_process)


func _update_markers():
	for marker in markers:
		marker.queue_free()
	markers.clear()

	for cppmove in move_scores_raw.keys():
		_update_marker(cppmove)

	for pos in pos_markers:
		var marker_id = 0.0
		var no_markers = float(pos_markers[pos].size())

		# Create a circle of markers on a tile
		for marker_data : PositionMarker in pos_markers[pos]:
			var marker = Sprite2D.new()
			var offset = Vector2(0, -128).rotated(2*PI*marker_id/no_markers)

			marker.position = BM.to_position(pos) + offset
			marker.texture = load(marker_data.icon_path)
			# Make sure sprites are scaled properly regardless of their resolution
			marker.scale *= 196.0 / float(marker.texture.get_width())
			marker.modulate = get_modulate_for_score(marker_data.score)

			add_child(marker)
			markers.push_back(marker)
			marker_id += 1.0

	pos_markers.clear()


func _update_marker(cppmove):
	var move = root.libspear_tuple_to_move_info(cppmove)
	var pos_marker = PositionMarker.new()
	pos_marker.score = move_scores_raw[cppmove]

	match move.move_type:
		MoveInfo.TYPE_MOVE:
			var marker: Node2D = arrow_marker.instantiate()

			var source = BM.to_position(move.move_source)
			var target = BM.to_position(move.target_tile_coord)

			marker.position = (source + target) / 2.0
			marker.look_at(target)
			marker.modulate = get_modulate_for_score(pos_marker.score)

			add_child(marker)
			markers.push_back(marker)

			pos_marker.score = -1.0
		MoveInfo.TYPE_DEPLOY:
			pos_marker.icon_path = move.deployed_unit.texture_path
		MoveInfo.TYPE_SACRIFICE:
			pos_marker.icon_path = cross_marker_path
		MoveInfo.TYPE_MAGIC:
			pos_marker.icon_path = move.spell.icon_path
		_:
			assert(false, "Unknown move type: %s" % [move.move_type])

	if pos_marker.score != -1.0:
		if move.target_tile_coord in pos_markers:
			pos_markers[move.target_tile_coord].push_back(pos_marker)
		else:
			pos_markers[move.target_tile_coord] = [pos_marker]


func get_modulate_for_score(score: float) -> Color:
	var result = Color.WHITE
	result.r = remap(score, min_score, max_score, 0.0, 1.0)
	result.g = remap(score, min_score, max_score, 0.0, 1.0)
	result.a = remap(score, min_score, max_score, 0.1, 1.0)
	return result


func _thread_process():
	while run_mcts:
		if mcts:
			mcts.iterate(1000)

			mutex.lock()

			move_scores_raw = mcts.get_move_scores()
			max_score = -10000.0
			min_score = 10000.0
			for i in move_scores_raw.values():
				max_score = max(max_score, i)
				min_score = min(min_score, i)

			update_markers = true

			mutex.unlock()


func _exit_tree():
	mutex.lock()
	run_mcts = false
	mutex.unlock()
	thread.wait_to_finish()


class PositionMarker:
	var icon_path: String
	var score: float

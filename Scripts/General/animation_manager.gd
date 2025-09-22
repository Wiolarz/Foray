# Singleton - ANIM

# TODO overcome the fear of batshit class name conflicts https://www.reddit.com/r/godot/comments/12brde4/classs_somename_hides_a_global_script_class/jo08luo/
# class_name SINGLETON_AnimationManager # just for F1 documentation
extends Node


enum PlaybackMode {
	NORMAL,
	FAST_FORWARD
}

# An ORDERED set of currently running tweens with their settings
var _running_tweens : Dictionary # Dictionary[Tween, TweenPlaybackSettings]
var _main_tween : Tween
var _playback_mode : PlaybackMode = PlaybackMode.NORMAL
var _speed_scale : float = 1.0


func _process(_delta: float):
	# Set tweens' speed based on game speed (normal = 1.0, instant >> 1.0)
	_speed_scale =  CFG.animation_speed_frames / CFG.AnimationSpeed.NORMAL
	change_speed(_speed_scale)


## Create a tween with default eases/transitions
func create_my_tween(settings := TweenPlaybackSettings.new()) -> Tween:
	var tween := get_tree().create_tween()
	tween.set_ease(CFG.anim_default_ease).set_trans(CFG.anim_default_trans)
	if settings.influenced_by_game_speed:
		tween.set_speed_scale(_speed_scale)

	tween.set_process_mode(settings.process_mode)
	tween.stop()
	return tween


## Get a main gameplay tween for in-game animations to append to
func main_tween() -> Tween:
	if not _main_tween or not _main_tween.is_valid():
		_main_tween = create_my_tween()
	return _main_tween


## Create a subtween, ran when the specified tween
## (by default main tween) finishes all previous animations
func subtween(parent : Tween = main_tween(), settings := TweenPlaybackSettings.new()) -> Tween:
	var tween := create_my_tween(settings)
	tween.finished.connect(_tween_finished.bind(tween))
	parent.tween_callback(play_tween.bind(tween, settings))

	return tween


## Create a tween independent of main tween
func ui_tween():
	# TODO tweaks for ui tweens, if you wish
	var tween = create_my_tween()
	return tween


## Change the speed of a main tween and all its subtweens
func change_speed(scale : float):
	if _main_tween: # TODO is this check useful?
		_main_tween.set_speed_scale(scale)
	for tween in _running_tweens:
		if _running_tweens[tween].influenced_by_game_speed:
			tween.set_speed_scale(scale)


## Instantly execute main tween and all its subtweens
func fast_forward() -> void:
	_playback_mode = PlaybackMode.FAST_FORWARD
	if _main_tween and _main_tween.is_valid():
		_main_tween.custom_step(INF)

	# Run all other tweens, in order they were created
	for tween in _running_tweens:
		if _running_tweens[tween].interrupt_on_fast_forward:
			tween.pause()
			tween.kill()
		else:
			tween.custom_step(INF)

	# From now on use a new main tween, since the old tween is invalid
	_main_tween = null
	_playback_mode = PlaybackMode.NORMAL


## is main tween playing
func is_playing() -> bool:
	return _main_tween != null and _main_tween.is_running()


## Play the specified tween and let it be managed by the animation manager
func play_tween(tween : Tween, settings := TweenPlaybackSettings.new()) -> void:
	match _playback_mode:
		PlaybackMode.NORMAL:
			# Add to list of tweens that are managed by the ANIM
			_running_tweens[tween] = settings

			if settings.influenced_by_game_speed:
				tween.set_speed_scale(_speed_scale)

			# Shouldn't ever happen
			assert(not tween.is_running(), "Subtween is already running")
			tween.play()
		PlaybackMode.FAST_FORWARD when settings.interrupt_on_fast_forward:
			tween.pause()
			tween.kill()
		PlaybackMode.FAST_FORWARD when not settings.interrupt_on_fast_forward:
			# Not functional, just for correct cleanup in _tween_finished
			# TODO it's probably better to bind _tween_finished in play_tween
			_running_tweens[tween] = settings
			tween.play()
			tween.custom_step(INF)


## Add tweens to playback so that they are in sync,
## providing relative timings between them
## (e.g. moment of weapon impact and shield reaction).
## Tween play callbacks and delays are appended to a given
## parent tween (by default [code]ANIM.main_tween[/code]) and the
## chronologically first action is appended immediately [br]
## Example: [br]
## [code]
## ANIM.sync_tweens([
##     ANIM.TweenSync.new(attack_tween, 0.3),
##     ANIM.TweenSync.new(block_tween, 0.1)
## ])
## [/code]
func sync_tweens(
		tween_syncs : Array[TweenSync],
		parent_tween := main_tween(),
		settings := TweenPlaybackSettings.new()):
	assert(not tween_syncs.is_empty(), "'tween_syncs' must have at least one element")

	tween_syncs.sort_custom(_sort_tween_sync_by_timing_desc)
	var time := tween_syncs[0].timing
	var end = 0.0
	var first = true

	for sync in tween_syncs:
		parent_tween.tween_interval(time - sync.timing)

		if not first:
			time += sync.timing
		first = false

		end = max(end, time + sync.total_time)

		sync.tween.finished.connect(_tween_finished.bind(sync.tween))
		parent_tween.tween_callback(play_tween.bind(sync.tween, settings))

	parent_tween.tween_interval(end - time)


func _tween_finished(tween: Tween) -> void:
	var removed := _running_tweens.erase(tween)
	assert(removed, "Given tween was not marked as playing")


func _sort_tween_sync_by_timing_desc(a : TweenSync, b : TweenSync) -> bool:
	return a.timing > b.timing


class TweenSync:
	var tween : Tween
	var timing : float
	var total_time : float

	func _init(_tween : Tween, _sync_time : float, _total_time : float):
		tween = _tween
		timing = _sync_time
		total_time = _total_time


class TweenPlaybackSettings:
	var influenced_by_game_speed := true
	var interrupt_on_fast_forward := false
	var process_mode := Tween.TWEEN_PROCESS_IDLE

	static func speed_independent() -> TweenPlaybackSettings:
		var settings := TweenPlaybackSettings.new()
		settings.influenced_by_game_speed = false
		return settings

	static func always_smooth() -> TweenPlaybackSettings:
		var settings := TweenPlaybackSettings.new()
		settings.influenced_by_game_speed = false
		settings.interrupt_on_fast_forward = true
		settings.process_mode = Tween.TWEEN_PROCESS_PHYSICS
		return settings

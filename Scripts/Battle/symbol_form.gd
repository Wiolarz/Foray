class_name SymbolForm
extends Node2D


@onready var sprite : Sprite2D = $Sprite2D
@onready var anim : AnimatedSprite2D = $ActivationAnim
@onready var frames : SymbolAnimation:
	get:
		return anim.sprite_frames
	set(_new):
		assert(false, "'frames' must be modified via anim.sprite_frames")


#region Initialization

## Apply the sprite, with regard to "local" side
## WARNING: called directly in UNIT EDITOR
func apply_sprite(side_local : int, texture_path : String) -> void:
	if texture_path == null or texture_path.is_empty():
		sprite.texture = null
		sprite.hide()
		return
	sprite.texture = RES.load(texture_path)

	flip_sprite(side_local)

	sprite.show()


## Add the animation to the animated sprite of SymbolForm
func apply_activation_anim(symbol : DataSymbol) -> void:
	if not symbol.symbol_animation:
		return # Animation does not exists for given symbol

	anim.sprite_frames = symbol.symbol_animation
	anim.scale = symbol.symbol_animation.scale
	anim.position = symbol.symbol_animation.offset


## Flips ths sprite so that weapons always point to the top of the screen
func flip_sprite(rotation_local: int):
	if rotation_local in [0, 1, 5]:  # LEFT
		sprite.flip_v = false
	else:
		sprite.flip_v = true

#endregion Initialization


#region Animations

func _fade_symbol_in(anim_tween : Tween):
	# Requires use_parent_material in SymbolForm to be turned off to work properly
	anim_tween.tween_property(sprite, "modulate:a", 1, CFG.anim_symbol_fade_in_out_time)


func _fade_symbol_out(anim_tween : Tween):
	anim_tween.tween_property(sprite, "modulate:a", 0, CFG.anim_symbol_fade_in_out_time)


func make_melee_anim(type : CFG.SymbolAnimationType) -> ANIM.TweenSync:
	var anim_tween = ANIM.create_my_tween()
	anim_tween.set_trans(Tween.TRANS_LINEAR)

	var animation_name : String
	match type:
		CFG.SymbolAnimationType.MELEE_ATTACK:
			animation_name = "default"
			anim.position = frames.offset
		CFG.SymbolAnimationType.FAILED_ATTACK:
			animation_name = "default"
			anim.position = frames.failed_offset
		CFG.SymbolAnimationType.COUNTER_ATTACK:
			animation_name = "counter"
			anim.position = frames.offset

	var time_to_hit = frames.get_time_to_hit(animation_name)

	assert(frames.has_animation(animation_name),
		"Missing %s animation from %s" % [animation_name, frames.resource_path] )

	_fade_symbol_out(anim_tween)
	if type != CFG.SymbolAnimationType.FAILED_ATTACK: # killing attack
		# Play
		anim_tween.tween_callback(anim.play.bind(animation_name))
		# Wait for anim end
		anim_tween.tween_interval(frames.get_animation_duration(animation_name))
	else: # blocked attack
		anim_tween.tween_callback(anim.play.bind(animation_name))
		anim_tween.tween_interval(max(0, time_to_hit))
		anim_tween.tween_callback(anim.pause)
		anim_tween.tween_callback(AUDIO.play.bind("parry"))
		anim_tween.tween_interval(CFG.anim_symbol_fade_in_out_time * 2)
		anim_tween.tween_property(anim, "modulate:a", 0, CFG.anim_symbol_fade_in_out_time * 2)
		# Reset to known state
		anim_tween.tween_callback(anim.stop)
		anim_tween.tween_property(anim, "modulate:a", 1, 0)

	_fade_symbol_in(anim_tween)
	return ANIM.TweenSync.new(
		anim_tween,
		time_to_hit + CFG.anim_symbol_fade_in_out_time,
		frames.get_animation_duration(animation_name)
	)


func make_projectile_anim(target_coord : Vector2i, side : int) -> ANIM.TweenSync:
	var anim_tween = ANIM.create_my_tween()
	anim_tween.set_trans(Tween.TRANS_LINEAR)

	# Create a temporary animated sprite for projectile
	var projectile_animated_sprite : AnimatedSprite2D = AnimatedSprite2D.new()
	add_child(projectile_animated_sprite)

	var projectile_animation_frames = frames.projectile_animation_frames
	projectile_animated_sprite.sprite_frames = projectile_animation_frames

	#idk if that's how to properly make it render on top of units
	projectile_animated_sprite.z_index = 1
	projectile_animated_sprite.scale = projectile_animation_frames.scale
	projectile_animated_sprite.reparent(BM.get_tile_form(target_coord))
	projectile_animated_sprite.global_rotation = deg_to_rad(side * 60)
	var opposite_side : int = GenericHexGrid.opposite_direction(side)
	projectile_animated_sprite.position = projectile_animation_frames.offset.rotated(deg_to_rad(opposite_side * 60))

	var projectile_absolute_frame_duration : float = projectile_animation_frames.get_absolute_frame_duration("default")
	var projectile_time_to_hit : float = projectile_animation_frames.hit_on_frame * projectile_absolute_frame_duration

	# Animate the thing
	# Fade out
	_fade_symbol_out(anim_tween)
	# Start the shooting anim
	anim_tween.tween_callback(anim.play.bind("default"))
	# Set the timer to play the projectile anim
	var time_to_teleport = frames.get_time_to_teleport("default")
	anim_tween.tween_callback(projectile_animated_sprite.play.bind("default")) \
		.set_delay(time_to_teleport - CFG.anim_symbol_fade_in_out_time)

	# Set the timer to kill the projectile
	var proj_lifetime : float = projectile_animation_frames.get_animation_duration("default")
	anim_tween.tween_callback(projectile_animated_sprite.queue_free).set_delay(proj_lifetime)
	# TODO This should ideally happen just after the symbol animation plays entirely
	# Fade in
	_fade_symbol_in(anim_tween)
	# Delay gameplay
	var delay = time_to_teleport + projectile_time_to_hit + CFG.anim_symbol_fade_in_out_time
	return ANIM.TweenSync.new(anim_tween, time_to_teleport + projectile_time_to_hit, delay)


func make_block_anim() -> ANIM.TweenSync:
	var anim_tween = ANIM.create_my_tween()
	anim_tween.set_trans(Tween.TRANS_LINEAR)

	# Set the animated sprite to blocking
	anim_tween.tween_property(anim, "position", frames.blocking_offset, 0)
	anim_tween.tween_property(anim, "scale", frames.blocking_scale, 0)
	# Fade out
	_fade_symbol_out(anim_tween)
	# Play the blocking animation
	anim_tween.tween_callback(anim.play.bind("block"))
	# Wait for it to finish
	var block_anim_duration : float = frames.get_animation_duration("block")
	anim_tween.tween_interval(block_anim_duration)
	# Fade in
	_fade_symbol_in(anim_tween)
	# Return to default position
	anim_tween.tween_property(anim, "position", frames.offset, 0)
	anim_tween.tween_property(anim, "scale", frames.scale, 0)
	# Delay gameplay
	var total_time = block_anim_duration + CFG.anim_symbol_fade_in_out_time
	return ANIM.TweenSync.new(anim_tween, frames.get_time_to_block("block"), total_time)


func get_block_duration():
	return anim.sprite_frames.get_animation_duration("block")

#endregion Animations

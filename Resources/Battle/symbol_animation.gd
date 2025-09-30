class_name SymbolAnimation
extends SpriteFrames

## Holds all animations of a symbol along with offsets and certain frame-timings. [br]
## Animation names matter and will dictate when given animation is played [br]
## Animation types: [br]
## default -> active [br]
## block [br]
## counter [br]

@export_category("Active Behavior")
@export var offset : Vector2 = Vector2(0,0)
@export var scale : Vector2 = Vector2(1,1)
@export var failed_offset : Vector2 = Vector2(0,0)
## The frame of animation on which the "hit" visually connects
@export var hit_on_frame : int = 0

@export_category("Teleporitng Projectile")
## Projectile animation, which will have its position set to the target hex
@export var projectile_animation_frames : SymbolAnimation
## For teleporting projectiles. The frame at witch the projectile animation should play
@export var teleport_at : int

@export_category("Blocking")
@export var blocking_offset : Vector2 = Vector2(0,0)
@export var blocking_scale : Vector2 = Vector2(1,1)
@export var block_on_frame : int = 0


# TODO make animations respect fast-forward and anim speed
func get_absolute_frame_duration(animation : StringName) -> float:
	return get_frame_duration(animation, 0) / get_animation_speed(animation)


func get_animation_duration(animation : StringName) -> float:
	return get_frame_count(animation) * get_absolute_frame_duration(animation)


func get_time_to_hit(animation : StringName) -> float:
	return hit_on_frame * get_absolute_frame_duration(animation)


func get_time_to_block(animation : StringName) -> float:
	return block_on_frame * get_absolute_frame_duration(animation)


func get_time_to_teleport(animation : StringName) -> float:
	return teleport_at * get_absolute_frame_duration(animation)

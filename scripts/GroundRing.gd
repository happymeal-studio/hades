extends FadeEffect


func _ready() -> void:
	top_level = true
	super()


func show_at(point: Vector3) -> void:
	global_position = point + Vector3(0, 0.03, 0)
	reset_physics_interpolation()
	play()

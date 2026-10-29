extends Node3D

@export var target: Node3D
@export var follow_speed := 6.0


func _ready() -> void:
	if target:
		global_position = target.global_position


# 물리 보간을 켰으므로 카메라도 _physics_process에서 움직인다.
func _physics_process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))

extends Enemy
## 근거리 졸개: 플레이어에게 곧장 달려들어 짧은 예비 동작 후 때린다.

## 예비 동작이 끝나는 순간 이보다 멀면 헛친다.
@export var hit_range := 1.6


func _perform_attack() -> void:
	if distance_to_player() <= hit_range:
		player.take_damage(damage, global_position)

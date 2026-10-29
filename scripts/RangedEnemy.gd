extends Enemy
## 원거리 궁수: 플레이어와 min_distance~max_distance 거리를 유지하며 화살을 쏜다.
## min_distance - 1 m보다 가까우면 쏘지 않고 먼저 물러난다.

@export var min_distance := 7.0
@export var max_distance := 9.0
@export var arrow_scene: PackedScene
## 몸 중심에서 앞으로 떨어진 발사 위치와 높이
@export var arrow_forward_offset := 0.5
@export var arrow_height := 0.8


func _chase_direction() -> Vector3:
	var distance := distance_to_player()
	if distance < min_distance:
		return -direction_to_player()
	if distance > max_distance:
		return direction_to_player()
	return Vector3.ZERO


func _can_start_attack() -> bool:
	var distance := distance_to_player()
	return distance >= min_distance - 1.0 and distance <= max_distance


## 화살은 조준이 끝나는 순간의 플레이어 방향으로 직선으로 날아간다.
func _perform_attack() -> void:
	var projectiles := get_tree().get_first_node_in_group("projectiles")
	if projectiles == null or arrow_scene == null:
		return
	var dir := direction_to_player()
	var arrow := arrow_scene.instantiate()
	arrow.damage = damage
	projectiles.add_child(arrow)
	arrow.launch(global_position + dir * arrow_forward_offset + Vector3.UP * arrow_height, dir)

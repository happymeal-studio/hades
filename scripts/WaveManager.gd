extends Node
## 웨이브 구성표대로 스폰 지점에서 적을 하나씩 내보낸다.
## 시작 start_delay초 뒤 첫 웨이브 → 전멸하면 rest_time초 쉬고 다음 웨이브 → 마지막 웨이브를 넘기면 승리.

signal wave_started(wave_number: int, wave_count: int)
## 남은 적 수(아직 스폰되지 않은 적 포함)가 바뀔 때
signal remaining_changed(remaining: int)
signal all_waves_cleared

## 웨이브마다 (근거리, 원거리, 덩치) 마릿수
@export var waves: Array[Vector3i] = [Vector3i(6, 0, 0), Vector3i(6, 3, 0), Vector3i(6, 4, 2)]
@export var start_delay := 1.0
@export var spawn_interval := 0.5
@export var rest_time := 3.0
## 플레이어와 이 거리 이상 떨어진 스폰 지점에서만 나온다.
@export var min_spawn_distance := 10.0
## 같은 지점에서 연달아 나와도 겹치지 않게 흩뿌리는 거리
@export var spawn_jitter := 1.0

@export_group("연결")
@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var brute_scene: PackedScene
@export var enemies_parent: Node3D
@export var spawn_points: Node3D

## 지금 웨이브 번호(1부터). 0이면 아직 시작 전.
var current_wave := 0
var remaining := 0
var kills := 0
## 첫 프레임부터 승리하거나 쓰러질 때까지 걸린 시간(초)
var elapsed := 0.0
var finished := false

var _queue: Array[PackedScene] = []
var _timer := 0.0
var _player: Node3D


func _ready() -> void:
	_timer = start_delay
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if finished or (_player and _player.is_dead):
		return
	elapsed += delta
	_timer -= delta
	if _timer > 0.0:
		return
	if not _queue.is_empty():
		_spawn(_queue.pop_front())
		_timer = spawn_interval
	elif remaining == 0 and current_wave < waves.size():
		_start_next_wave()


func _start_next_wave() -> void:
	current_wave += 1
	var counts := waves[current_wave - 1]
	_queue.clear()
	for i in counts.x:
		_queue.append(melee_scene)
	for i in counts.y:
		_queue.append(ranged_scene)
	for i in counts.z:
		_queue.append(brute_scene)
	_queue.shuffle()
	remaining = _queue.size()
	_timer = 0.0
	wave_started.emit(current_wave, waves.size())
	remaining_changed.emit(remaining)


func _spawn(scene: PackedScene) -> void:
	var enemy: Node3D = scene.instantiate()
	var jitter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * spawn_jitter
	enemy.position = _pick_spawn_point() + jitter
	enemy.died.connect(_on_enemy_died)
	enemies_parent.add_child(enemy)


## 플레이어와 min_spawn_distance 이상 떨어진 지점 중 무작위. 없으면 가장 먼 지점.
func _pick_spawn_point() -> Vector3:
	var far_enough: Array[Vector3] = []
	var farthest := Vector3.ZERO
	var farthest_distance := -1.0
	for marker: Node3D in spawn_points.get_children():
		var distance := marker.global_position.distance_to(_player.global_position)
		if distance >= min_spawn_distance:
			far_enough.append(marker.global_position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest = marker.global_position
	if far_enough.is_empty():
		return farthest
	return far_enough.pick_random()


func _on_enemy_died(_enemy: Node) -> void:
	kills += 1
	remaining -= 1
	remaining_changed.emit(remaining)
	if remaining > 0:
		return
	if current_wave >= waves.size():
		finished = true
		all_waves_cleared.emit()
	else:
		_timer = rest_time

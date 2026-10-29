class_name Enemy
extends CharacterBody3D
## 적 3종 공통: 체력, 상태 머신(추적 → 예비 동작 → 공격 → 대기, 사망), 피격, 넉백, 사망.
## 종류별 차이는 _chase_direction / _can_start_attack / _perform_attack 등을 덮어써서 만든다.

signal died(enemy: Enemy)

enum State { CHASE, WINDUP, RECOVER, DEAD }

@export var max_health := 30.0
@export var move_speed := 3.5
## 몸 반지름. 플레이어 근접 공격 사거리 판정에 더한다.
@export var body_radius := 0.35
## 플레이어가 이 거리 안에 들면 예비 동작을 시작한다.
@export var attack_range := 1.2
@export var windup_time := 0.3
## 공격과 공격 사이 간격(예비 동작 포함).
@export var attack_interval := 1.0
@export var damage := 10.0
@export var takes_knockback := true
@export var knockback_time := 0.15
@export var flash_time := 0.1
@export var death_time := 0.3
@export var head_on_threshold := 0.95
@export var body_color := Color(0.9, 0.2, 0.2)
@export var windup_color := Color(1.0, 0.85, 0.2)

var health: float
var state := State.CHASE
var player: Node3D

var _state_time := 0.0
var _flash_left := 0.0
var _knockback_left := 0.0
var _knockback_velocity := Vector3.ZERO
var _material: StandardMaterial3D

@onready var _body: MeshInstance3D = $Body


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_body.material_override = _material


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	_state_time += delta
	_flash_left = maxf(_flash_left - delta, 0.0)

	if _knockback_left > 0.0:
		_knockback_left -= delta
		velocity = _knockback_velocity
	elif player == null or player.is_dead:
		if state == State.WINDUP:
			_cancel_windup()
		velocity = Vector3.ZERO
	else:
		velocity = _think()

	move_and_slide()
	position.y = 0.0
	_update_color()


func take_damage(amount: float, from_position: Vector3, knockback := 0.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash_left = flash_time
	if health <= 0.0:
		_die()
		return
	if takes_knockback and knockback > 0.0:
		var away := global_position - from_position
		away.y = 0.0
		_knockback_velocity = away.normalized() * (knockback / knockback_time)
		_knockback_left = knockback_time
		if state == State.WINDUP:
			_cancel_windup()


func distance_to_player() -> float:
	var to := player.global_position - global_position
	to.y = 0.0
	return to.length()


func direction_to_player() -> Vector3:
	var to := player.global_position - global_position
	to.y = 0.0
	return to.normalized()


# --- 종류별로 덮어쓰는 부분 ---------------------------------------------

## 추적 중 이동 방향. 기본은 플레이어에게 곧장.
func _chase_direction() -> Vector3:
	return direction_to_player()


func _can_start_attack() -> bool:
	return distance_to_player() <= attack_range


func _on_windup_started() -> void:
	pass


func _on_windup_cancelled() -> void:
	pass


## 예비 동작이 끝나는 순간 호출된다. 범위 밖이면 헛치게 만드는 것도 여기서.
func _perform_attack() -> void:
	pass


# --- 내부 ---------------------------------------------------------------

func _think() -> Vector3:
	match state:
		State.CHASE:
			if _can_start_attack():
				_set_state(State.WINDUP)
				_on_windup_started()
				return Vector3.ZERO
			var dir := _chase_direction()
			if dir == Vector3.ZERO:
				return Vector3.ZERO
			return Steering.around_trees(self, dir, direction_to_player(), head_on_threshold) * move_speed
		State.WINDUP:
			if _state_time >= windup_time:
				_perform_attack()
				_set_state(State.RECOVER)
		State.RECOVER:
			if _state_time >= maxf(attack_interval - windup_time, 0.0):
				_set_state(State.CHASE)
	return Vector3.ZERO


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _cancel_windup() -> void:
	_on_windup_cancelled()
	_set_state(State.CHASE)


func _update_color() -> void:
	if _flash_left > 0.0:
		_material.albedo_color = Color.WHITE
	elif state == State.WINDUP:
		_material.albedo_color = windup_color
	else:
		_material.albedo_color = body_color


func _die() -> void:
	if state == State.WINDUP:
		_on_windup_cancelled()
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	died.emit(self)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, death_time)
	tween.tween_callback(queue_free)

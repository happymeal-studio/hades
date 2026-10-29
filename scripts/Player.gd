extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died

@export_group("이동")
@export var move_speed := 5.0
@export var arrive_distance := 0.2
@export var turn_speed := 20.0
## 맵 한쪽 끝까지의 거리(40 m 맵의 절반에서 몸 반지름을 뺀 값)
@export var map_half_size := 19.5
## 정면 충돌로 판단하는 기준(이동 방향과 충돌면이 이루는 cos 값)
@export var head_on_threshold := 0.95

@export_group("체력")
@export var max_health := 100.0
@export var hurt_invincible_time := 0.5
@export var blink_interval := 0.08

@export_group("근접 공격")
@export var melee_damage := 20.0
@export var melee_range := 1.8
@export var melee_angle := 90.0
@export var melee_knockback := 1.0
@export var melee_cooldown := 0.4
## 공격하는 순간 제자리에 서 있는 시간
@export var attack_pause := 0.15

@export_group("연결")
@export var click_marker: Node3D
@export var melee_fan: Node3D

var health: float
var is_dead := false

var _target := Vector3.ZERO
var _has_target := false
## 공격으로 멈춘 뒤에는 누르고 있던 좌클릭을 무시하고 다음 좌클릭부터 다시 걷는다.
var _click_locked := false
var _attack_pause_left := 0.0
var _melee_cooldown_left := 0.0
var _invincible_left := 0.0
var _blink_left := 0.0

@onready var _model: Node3D = $Model


func _ready() -> void:
	health = max_health
	melee_fan.build(melee_range, melee_angle)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_pause_left = maxf(_attack_pause_left - delta, 0.0)
	_melee_cooldown_left = maxf(_melee_cooldown_left - delta, 0.0)
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	_blink_left = maxf(_blink_left - delta, 0.0)
	_model.visible = _blink_left <= 0.0 or fmod(_blink_left, blink_interval * 2.0) < blink_interval

	if Input.is_action_pressed("attack_melee") and _melee_cooldown_left <= 0.0:
		melee_attack(_aim_direction())

	velocity = Vector3.ZERO
	if _attack_pause_left <= 0.0:
		velocity = _movement(delta)
	move_and_slide()
	position.y = 0.0


func take_damage(amount: float, _from_position: Vector3, _knockback := 0.0) -> void:
	if is_dead or _invincible_left > 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
		return
	_invincible_left = hurt_invincible_time
	_blink_left = hurt_invincible_time


## 커서 방향 부채꼴 안의 적 전부에게 피해 + 넉백. Area3D 없이 거리·각도만으로 판정한다.
func melee_attack(aim: Vector3) -> void:
	_melee_cooldown_left = melee_cooldown
	_start_attack_pause(aim)
	melee_fan.play()
	var min_dot := cos(deg_to_rad(melee_angle * 0.5))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		var distance := to.length()
		if distance - enemy.body_radius > melee_range:
			continue
		if distance > 0.01 and aim.dot(to / distance) < min_dot:
			continue
		enemy.take_damage(melee_damage, global_position, melee_knockback)


## 커서 아래 바닥(y = 0) 지점. 광선이 바닥과 만나지 않으면 null.
func get_cursor_ground_point() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)


func _movement(delta: float) -> Vector3:
	var dir := _wasd_direction()
	if dir != Vector3.ZERO:
		_has_target = false
	else:
		_update_click_target()
		dir = _direction_to_target()
	if dir == Vector3.ZERO:
		return Vector3.ZERO
	var toward := (_target - global_position) if _has_target else dir
	dir = Steering.around_trees(self, dir, toward, head_on_threshold)
	rotation.y = lerp_angle(rotation.y, _yaw_of(dir), 1.0 - exp(-turn_speed * delta))
	return dir * move_speed


## 공격 순간: 이동을 멈추고 커서 쪽으로 몸을 돌린 뒤 잠깐 제자리에 선다.
func _start_attack_pause(aim: Vector3) -> void:
	rotation.y = _yaw_of(aim)
	_attack_pause_left = attack_pause
	_has_target = false
	_click_locked = Input.is_action_pressed("move")


func _aim_direction() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	var point = get_cursor_ground_point()
	if point == null:
		return forward.normalized()
	var to: Vector3 = point - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return forward.normalized()
	return to.normalized()


func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _update_click_target() -> void:
	if Input.is_action_just_pressed("move"):
		_click_locked = false
	if _click_locked or not Input.is_action_pressed("move"):
		return
	var point = get_cursor_ground_point()
	if point == null:
		return
	_target = Vector3(
		clampf(point.x, -map_half_size, map_half_size),
		0.0,
		clampf(point.z, -map_half_size, map_half_size))
	_has_target = true
	if Input.is_action_just_pressed("move") and click_marker:
		click_marker.show_at(_target)


func _direction_to_target() -> Vector3:
	if not _has_target:
		return Vector3.ZERO
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() <= arrive_distance:
		_has_target = false
		return Vector3.ZERO
	return to_target.normalized()


## W = 화면 위쪽, D = 화면 오른쪽. 카메라 방향을 바닥에 눕혀서 계산한다.
func _wasd_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).normalized()


## 회색으로 변하며 옆으로 눕는다.
func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	_model.visible = true
	var gray := StandardMaterial3D.new()
	gray.albedo_color = Color(0.45, 0.45, 0.48)
	for mesh_instance in _model.get_children():
		mesh_instance.material_override = gray
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(_model, "rotation:z", deg_to_rad(90.0), 0.4)
	tween.tween_property(_model, "position:y", 0.4, 0.4)
	died.emit()

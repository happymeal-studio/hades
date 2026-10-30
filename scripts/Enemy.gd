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
## 쓰러질 때 플레이어가 받는 경험치
@export var xp_reward := 20
@export var takes_knockback := true
@export var knockback_time := 0.15
@export var flash_time := 0.1
@export var death_time := 0.3
@export var head_on_threshold := 0.95
## 얼굴이 플레이어 쪽으로 도는 빠르기
@export var turn_speed := 8.0
## 모델 원래 색 위에 덮는 색. 알파가 덮는 세기.
@export var flash_color := Color(1.0, 1.0, 1.0, 0.85)
@export var windup_color := Color(1.0, 0.85, 0.2, 0.55)

@export_group("체력 바")
@export var health_bar_height := 1.7
@export var health_bar_color := Color(0.95, 0.25, 0.2)
@export var health_bar_back_color := Color(0.1, 0.1, 0.1, 0.8)

const BAR_PIXELS := Vector2i(100, 12)
const BAR_PIXEL_SIZE := 0.01

## 모든 적의 체력 바가 함께 쓰는 흰색 텍스처
static var _bar_texture: ImageTexture

var health: float
var state := State.CHASE
var player: Node3D

var _state_time := 0.0
var _flash_left := 0.0
var _knockback_left := 0.0
var _knockback_velocity := Vector3.ZERO
var _material: StandardMaterial3D
var _bar_back: Sprite3D
var _bar_front: Sprite3D

## 앞(얼굴)이 +Z를 보는 모델 (Blender에서 뽑은 glb)
@onready var _model: Node3D = $Model


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	# 모델 색은 그대로 두고, 피격·예비 동작 색은 반투명 덧칠로 보여 준다.
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color.TRANSPARENT
	for mesh_instance in _model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_overlay = _material
	_bar_back = _make_bar_sprite(health_bar_back_color, 0)
	_bar_front = _make_bar_sprite(health_bar_color, 1)


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
	_face_player(delta)
	_update_color()


func take_damage(amount: float, from_position: Vector3, knockback := 0.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash_left = flash_time
	_update_health_bar()
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


func _make_bar_sprite(color: Color, priority: int) -> Sprite3D:
	if _bar_texture == null:
		var image := Image.create(BAR_PIXELS.x, BAR_PIXELS.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(image)
	var sprite := Sprite3D.new()
	sprite.texture = _bar_texture
	sprite.pixel_size = BAR_PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.render_priority = priority
	sprite.modulate = color
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, BAR_PIXELS)
	sprite.position = Vector3(0, health_bar_height, 0)
	sprite.visible = false
	add_child(sprite)
	return sprite


## 처음엔 숨겨 두었다가 첫 피해를 입은 뒤부터 보인다. 바는 왼쪽 끝을 고정하고 줄어든다.
func _update_health_bar() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	var width := BAR_PIXELS.x * ratio
	_bar_back.visible = true
	_bar_front.visible = ratio > 0.0
	_bar_front.region_rect = Rect2(0, 0, width, BAR_PIXELS.y)
	_bar_front.offset.x = -(BAR_PIXELS.x - width) * 0.5


func _update_color() -> void:
	if _flash_left > 0.0:
		_material.albedo_color = flash_color
	elif state == State.WINDUP:
		_material.albedo_color = windup_color
	else:
		_material.albedo_color = Color.TRANSPARENT


## 살아 있는 동안 모델 얼굴(+Z)을 플레이어 쪽으로 천천히 돌린다.
func _face_player(delta: float) -> void:
	if player == null:
		return
	var to := direction_to_player()
	if to == Vector3.ZERO:
		return
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(to.x, to.z), 1.0 - exp(-turn_speed * delta))


func _die() -> void:
	if state == State.WINDUP:
		_on_windup_cancelled()
	_set_state(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	died.emit(self)
	if player:
		player.gain_xp(xp_reward)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, death_time)
	tween.tween_callback(queue_free)

extends Node3D
## 보물상자. 플레이어가 가까이 오면 한 번 열리고 경험치와 마법봉을 준다.
## 마법봉은 상자에서 빙글빙글 돌며 솟아올랐다가 플레이어 손으로 날아간다.

@export var xp_reward := 100
## 몸 중심 사이 거리가 이보다 가까우면 열린다.
@export var open_distance := 1.6
@export var open_animation := &"open"
## 열리면 플레이어 손에 마법봉을 쥐여 준다 (그 뒤로 근접 공격이 주먹질 → 마법봉 휘두르기로 바뀜)
@export var gives_wand := true

@export_group("마법봉 튀어나오기")
## 상자에서 솟아오르는 마법봉 모습 (비워 두면 바로 손에 쥔다)
@export var wand_scene: PackedScene
## 뚜껑이 조금 열린 뒤 나오기까지 기다리는 시간
@export var wand_delay := 0.2
## 솟아오르는 높이(시작 → 끝)와 시간
@export var wand_start_height := 0.4
@export var wand_rise_height := 1.8
@export var wand_rise_time := 0.6
## 상자에서 나올 때 크기 (손에 든 것의 몇 배). 위에서 보는 카메라라 크게 보여 준다
@export var wand_pop_scale := 2.5
## 솟아오르는 동안 도는 바퀴 수
@export var wand_turns := 2.0
## 꼭대기에서 손으로 날아가는 시간
@export var wand_fly_time := 0.3
## 날아가서 닿는 손 높이
@export var hand_height := 0.7

var is_open := false

var _player: Node3D
var _animation: AnimationPlayer


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	var players := find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0]


func _physics_process(_delta: float) -> void:
	if is_open or _player == null or _player.is_dead:
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() <= open_distance:
		_open()


func _open() -> void:
	is_open = true
	if _animation and _animation.has_animation(open_animation):
		_animation.play(open_animation)
	_player.gain_xp(xp_reward)
	if not (gives_wand and "has_wand" in _player):
		return
	if wand_scene == null:
		_player.has_wand = true
		return
	_pop_wand()


func _pop_wand() -> void:
	var wand: Node3D = wand_scene.instantiate()
	add_child(wand)
	wand.top_level = true
	# glb의 마법봉은 별이 앞(+Z)을 본다. X로 -90도 돌려 별이 위를 보게 세운다.
	var upright := Basis(Vector3.RIGHT, -PI / 2)
	var start := global_position + Vector3.UP * wand_start_height
	wand.global_transform = Transform3D(upright.scaled(Vector3.ONE * wand_pop_scale), start)
	wand.reset_physics_interpolation()
	wand.visible = false

	var top := global_position + Vector3.UP * wand_rise_height
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(wand_delay)
	tween.tween_callback(wand.show)
	tween.tween_method(func(t: float) -> void:
		var spin := (Basis(Vector3.UP, TAU * wand_turns * t) * upright).scaled(Vector3.ONE * wand_pop_scale)
		wand.global_transform = Transform3D(spin, start.lerp(top, ease(t, 0.4))),
		0.0, 1.0, wand_rise_time)
	# 손으로 날아가는 동안 플레이어가 움직여도 따라간다
	tween.tween_method(func(t: float) -> void:
		var hand := _player.global_position + Vector3.UP * hand_height
		wand.global_position = top.lerp(hand, t * t)
		wand.scale = Vector3.ONE * lerpf(wand_pop_scale, 0.4, t),
		0.0, 1.0, wand_fly_time)
	tween.tween_callback(func() -> void:
		wand.queue_free()
		if not _player.is_dead:
			_player.has_wand = true)

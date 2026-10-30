extends Node3D
## 보물상자. 플레이어가 가까이 오면 한 번 열리고 경험치와 검을 준다.

@export var xp_reward := 100
## 몸 중심 사이 거리가 이보다 가까우면 열린다.
@export var open_distance := 1.6
@export var open_animation := &"open"
## 열리면 플레이어 손에 검을 쥐여 준다 (그 뒤로 근접 공격이 주먹질 → 칼질로 바뀜)
@export var gives_sword := true

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
	if gives_sword and "has_sword" in _player:
		_player.has_sword = true

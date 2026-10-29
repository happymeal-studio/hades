extends Enemy
## 덩치: 느리게 쫓아오다 바닥에 경고 원을 띄우고 범위 내려찍기를 한다. 넉백을 받지 않는다.
## 경고 원은 반경 전체를 옅게 깔고, 안쪽 원이 예비 동작 동안 차올라 떨어지는 때를 보여준다.

@export var slam_radius := 2.5

@onready var _warning_area: MeshInstance3D = $WarningArea
@onready var _warning_fill: MeshInstance3D = $WarningFill


func _ready() -> void:
	super()
	_warning_area.scale = Vector3(slam_radius, 1.0, slam_radius)
	_hide_warning()


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.WINDUP:
		var t := clampf(_state_time / windup_time, 0.01, 1.0) * slam_radius
		_warning_fill.scale = Vector3(t, 1.0, t)


func _on_windup_started() -> void:
	_warning_area.visible = true
	_warning_fill.visible = true
	_warning_fill.scale = Vector3(0.01, 1.0, 0.01)


func _on_windup_cancelled() -> void:
	_hide_warning()


## 원 밖에 있으면 맞지 않는다.
func _perform_attack() -> void:
	_hide_warning()
	if distance_to_player() <= slam_radius:
		player.take_damage(damage, global_position)


func _hide_warning() -> void:
	_warning_area.visible = false
	_warning_fill.visible = false

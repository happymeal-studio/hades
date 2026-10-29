extends Area3D
## 직선 투사체(매직 미사일, 적 화살 공용): 처음 맞은 대상 하나에 피해를 주고 사라진다.
## 누구를 맞히는지는 충돌 마스크가 정한다. 나무·벽에 닿거나 최대 거리를 날면 그냥 사라진다.

@export var speed := 12.0
@export var max_distance := 12.0
@export var damage := 15.0
## 맞았을 때 작게 퍼지며 사라지는 효과. 끄면 바로 사라진다.
@export var hit_effect := true
@export var hit_effect_time := 0.15
@export var hit_effect_scale := 2.5

var direction := Vector3.FORWARD

var _traveled := 0.0
var _done := false

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, dir: Vector3) -> void:
	global_position = from
	direction = dir
	look_at(from + dir)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	global_position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		_vanish(false)


func _on_body_entered(body: Node3D) -> void:
	if _done:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	_vanish(true)


func _vanish(hit: bool) -> void:
	_done = true
	set_deferred("monitoring", false)
	if not (hit and hit_effect):
		queue_free()
		return
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(_mesh, "scale", Vector3.ONE * hit_effect_scale, hit_effect_time)
	tween.tween_property(_mesh, "transparency", 1.0, hit_effect_time)
	tween.chain().tween_callback(queue_free)

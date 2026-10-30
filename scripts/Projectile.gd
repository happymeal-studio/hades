extends Area3D
## 직선 투사체(햄스터가 던지는 햄버거, 적 화살 공용): 처음 맞은 대상 하나에 피해를 주고 사라진다.
## 누구를 맞히는지는 충돌 마스크가 정한다. 나무·벽에 닿거나 최대 거리를 날면 그냥 사라진다.
## 반짝이 효과는 자식 노드가 있을 때만 쓴다: Trail(날아가는 동안 꼬리), LaunchBurst(쏠 때), HitBurst(맞을 때).

@export var speed := 12.0
@export var max_distance := 12.0
@export var damage := 15.0
## 맞았을 때 작게 퍼지며 사라지는 효과. 끄면 바로 사라진다.
@export var hit_effect := true
@export var hit_effect_time := 0.15
@export var hit_effect_scale := 2.5
## 날아가는 동안 모습이 도는 속도(라디안/초). 0이면 안 돈다.
@export var spin_speed := 0.0
## 도는 축(자기 좌표). 앞(FORWARD)이면 드릴처럼, 옆(RIGHT)이면 앞으로 데굴데굴 구르듯 돈다.
@export var spin_axis := Vector3.FORWARD

var direction := Vector3.FORWARD

var _traveled := 0.0
var _done := false

## 모습: 메시 하나(화살)이거나, 불러온 모델(햄버거 glb)처럼 메시가 안에 든 노드
@onready var _mesh: Node3D = $Mesh
@onready var _trail: CPUParticles3D = get_node_or_null("Trail")
@onready var _launch_burst: CPUParticles3D = get_node_or_null("LaunchBurst")
@onready var _hit_burst: CPUParticles3D = get_node_or_null("HitBurst")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, dir: Vector3) -> void:
	global_position = from
	direction = dir
	look_at(from + dir)
	reset_physics_interpolation()
	if _launch_burst:
		_launch_burst.restart()


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	global_position += direction * step
	_traveled += step
	if spin_speed != 0.0:
		_mesh.rotate_object_local(spin_axis, spin_speed * delta)
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
	# 이미 나온 반짝이는 제자리에서 마저 사라지게 두고, 그동안만 노드를 남겨 둔다.
	var linger := 0.0
	if _trail:
		_trail.emitting = false
		linger = maxf(linger, _trail.lifetime)
	if hit and _hit_burst:
		_hit_burst.restart()
		linger = maxf(linger, _hit_burst.lifetime)
	if not (hit and hit_effect):
		_mesh.visible = false
		if linger <= 0.0:
			queue_free()
		else:
			get_tree().create_timer(linger, false, true).timeout.connect(queue_free)
		return
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(_mesh, "scale", _mesh.scale * hit_effect_scale, hit_effect_time)
	for geometry in [_mesh] + _mesh.find_children("*", "GeometryInstance3D", true, false):
		if geometry is GeometryInstance3D:
			tween.tween_property(geometry, "transparency", 1.0, hit_effect_time)
	tween.chain().tween_interval(maxf(linger - hit_effect_time, 0.0))
	tween.chain().tween_callback(queue_free)

class_name FadeEffect
extends MeshInstance3D
## 잠깐 보였다가 투명해지며 사라지는 이펙트.
## 메시·머티리얼은 그대로 재사용하고 인스턴스 transparency만 바꾼다(새로 만들면 그 프레임이 멈춘다).

@export var duration := 0.3
@export var end_scale := 1.0

var _tween: Tween


func _ready() -> void:
	_prewarm()


## 셰이더 컴파일 멈춤을 미리 없애려고 바닥 아래 안 보이는 곳에 한 번 그려 둔다.
func _prewarm() -> void:
	var saved := position
	position.y -= 3.0
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	position = saved
	reset_physics_interpolation()
	visible = false


func play() -> void:
	visible = true
	transparency = 0.0
	scale = Vector3.ONE
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	_tween.tween_property(self, "transparency", 1.0, duration)
	if end_scale != 1.0:
		_tween.tween_property(self, "scale", Vector3.ONE * end_scale, duration)
	_tween.chain().tween_callback(hide)

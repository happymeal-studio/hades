extends Node3D
## 처음 그릴 때의 셰이더 컴파일 멈춤을 없애려고, 게임 시작 때 바닥 아래 안 보이는 곳에
## 각 씬을 한 번씩 그려 두었다가 지운다. 숨겨진 부분(경고 원, 체력 바)과
## 사라지는 효과(transparency)까지 같이 그린다. 적은 그룹·충돌에서 빼서 게임에 끼어들지 않게 한다.

@export var scenes: Array[PackedScene] = []


func _ready() -> void:
	for scene in scenes:
		var node := scene.instantiate()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		node.position = Vector3(0, -5, 0)
		for group in node.get_groups():
			node.remove_from_group(group)
		if node is CollisionObject3D:
			node.collision_layer = 0
			node.collision_mask = 0
		for geometry in node.find_children("*", "GeometryInstance3D", true, false):
			geometry.visible = true
			geometry.transparency = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	for child in get_children():
		child.queue_free()

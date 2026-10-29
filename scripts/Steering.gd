class_name Steering


## 나무에 정면으로 부딪히면 미끄러질 방향이 없으므로 옆으로 살짝 틀어 준다.
## toward 쪽에 가까운 옆 방향을 고른다. 나무가 아니거나 비스듬히 부딪힌 경우는 dir 그대로.
static func around_trees(body: CharacterBody3D, dir: Vector3, toward: Vector3, head_on_threshold := 0.95) -> Vector3:
	var collision := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, dir * 0.3, collision):
		return dir
	var collider := collision.get_collider()
	if not (collider is Node and collider.is_in_group("trees")):
		return dir
	var normal := collision.get_normal()
	normal.y = 0.0
	normal = normal.normalized()
	if dir.dot(-normal) < head_on_threshold:
		return dir
	var side := normal.cross(Vector3.UP)
	if side.dot(toward) < 0.0:
		side = -side
	return side

extends MultiMeshInstance3D
## 바닥에 진짜 3D 톱밥 조각을 흩뿌린다. 조각마다 방향·기울기·크기·색이 달라서 빛을 받는 면이 제각각이다.
## 수만 개를 MultiMesh 하나로 한 번에 그린다. 같은 seed면 늘 같은 자리에 깔린다.

@export var count := 7000
@export var area := Vector2(40, 40)
## 게임 카메라가 20 m를 내려다봐서, 몇 cm짜리는 1~2픽셀이라 안 보인다
@export var chip_length := Vector2(0.08, 0.25)
@export var max_tilt_deg := 25.0
@export var colors: Array[Color] = [
	Color("f3dcaa"), Color("e6c690"), Color("c99a5c"), Color("f8ead0"), Color("a8783f")]
@export var seed := 11


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _chip_mesh()
	mm.instance_count = count
	for i in count:
		var length := rng.randf_range(chip_length.x, chip_length.y)
		var size := Vector3(length * rng.randf_range(0.25, 0.45), length * rng.randf_range(0.12, 0.2), length)
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(rng.randf_range(-max_tilt_deg, max_tilt_deg)),
			rng.randf_range(0.0, TAU),
			deg_to_rad(rng.randf_range(-max_tilt_deg, max_tilt_deg)))).scaled(size)
		var pos := Vector3(rng.randf_range(-0.5, 0.5) * area.x, 0.0, rng.randf_range(-0.5, 0.5) * area.y)
		pos.y = _ground_height(pos) + size.y * 0.3   # 톱밥 둔덕 위에 얹는다
		mm.set_instance_transform(i, Transform3D(basis, pos))
		mm.set_instance_color(i, colors[rng.randi() % colors.size()] * rng.randf_range(0.9, 1.05))
	multimesh = mm


## 형제 노드 Mesh(SawdustGround.gd)의 둔덕 높이를 그대로 따른다
func _ground_height(p: Vector3) -> float:
	var ground := get_parent().get_node_or_null("Mesh")
	if ground == null or not ground.has_method("height_at"):
		return 0.0
	return ground.height_at(p.x, p.z)


## 크기 1짜리 납작한 쐐기(한쪽이 얇은 나무 조각). 각진 느낌이 나게 면마다 평평하게.
func _chip_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.5
	var p := [
		Vector3(-w, 0, -0.5), Vector3(w, 0, -0.5), Vector3(w, 0, 0.5), Vector3(-w, 0, 0.5),       # 바닥
		Vector3(-w, 0.6, -0.5), Vector3(w, 0.6, -0.5), Vector3(w, 1.0, 0.5), Vector3(-w, 1.0, 0.5)]  # 윗면(한쪽이 더 두꺼움)
	var faces := [[4, 5, 6, 7], [0, 3, 2, 1], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [3, 0, 4, 7]]
	for f in faces:
		for tri in [[f[0], f[1], f[2]], [f[0], f[2], f[3]]]:
			for k in tri:
				st.add_vertex(p[k])
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	st.set_material(mat)
	return st.commit()

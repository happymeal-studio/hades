extends MeshInstance3D
## 톱밥 바닥: 평평한 판 대신, 톱밥이 쌓인 것처럼 낮은 둔덕이 있는 바닥을 만든다.
## 해가 비추면 둔덕 한쪽은 밝고 반대쪽은 어두워서 멀리서도 입체적으로 보인다.
## 바닥 판의 크기·재질은 장면에 있는 PlaneMesh를 그대로 쓴다. 부딪힘 판정은 평평한 그대로(y = 0).

@export var cell := 0.25
@export var bump_height := 0.08
@export var bump_scale := 0.35
@export var seed := 5

var _noise: FastNoiseLite
var _size := Vector2.ZERO


## 바닥 위 (x, z) 지점의 둔덕 높이 (가장자리 쪽으로 줄어드는 것은 빼고)
func height_at(x: float, z: float) -> float:
	if _noise == null:
		return 0.0
	var edge := clampf(minf(_size.x * 0.5 - absf(x), _size.y * 0.5 - absf(z)) / (4.0 * cell), 0.0, 1.0)
	return (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * bump_height * edge


func _ready() -> void:
	var plane := mesh as PlaneMesh
	if plane == null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = seed
	_noise.frequency = bump_scale
	_noise.fractal_octaves = 3
	_size = plane.size
	var size := _size
	var nx := int(size.x / cell)
	var nz := int(size.y / cell)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 가장자리는 0으로 모아서 바닥 끝이 떠 보이지 않게 (height_at 안에서)
	var point := func(i: int, j: int) -> Vector3:
		var x := -size.x * 0.5 + i * cell
		var z := -size.y * 0.5 + j * cell
		return Vector3(x, height_at(x, z), z)
	for j in nz:
		for i in nx:
			var quad := [point.call(i, j), point.call(i + 1, j), point.call(i + 1, j + 1), point.call(i, j + 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = quad[k]
				st.set_uv(Vector2(p.x / size.x + 0.5, p.z / size.y + 0.5))
				st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()   # 노멀 맵을 쓰려면 필요
	st.set_material(plane.material)
	mesh = st.commit()

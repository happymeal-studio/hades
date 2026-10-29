extends FadeEffect
## 근접 공격 범위를 보여주는 부채꼴. 앞쪽(-Z) 기준으로 한 번만 만든다.

@export var color := Color(0.75, 0.9, 1.0, 0.55)
@export var segments := 16


func build(radius: float, angle_degrees: float) -> void:
	var half := deg_to_rad(angle_degrees) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := lerpf(-half, half, float(i) / segments)
		var a1 := lerpf(-half, half, float(i + 1) / segments)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(-sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(-sin(a1), 0, -cos(a1)) * radius)
	mesh = st.commit()

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material_override = material

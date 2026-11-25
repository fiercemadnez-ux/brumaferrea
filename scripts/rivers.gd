extends Node3D
# Rios do mundo aberto: lê o river_paths.json exportado do gerador e monta a água como malha simples
# (cor semitransparente, sem shader). Quem anda dentro do rio fica mais devagar (water_speed_factor).
# Coordenadas do JSON: x = leste, y = norte, z = altura (Blender). No Godot: Vector3(x, z, -y).

const WATER_COLOR := Color(0.16, 0.42, 0.62, 0.62)
const SLOW_FACTOR := 0.5
const SURFACE_TOL := 0.8  # quanto acima da superfície ainda conta como dentro da água
const BED_TOL := 1.0      # quanto abaixo do leito ainda conta como dentro da água

var _segs: Array = []


func build(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Rios: arquivo não encontrado: %s" % path)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("rivers"):
		push_warning("Rios: JSON inválido em %s" % path)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for river in data["rivers"]:
		var samples: Array = river["samples"]
		for k in range(samples.size() - 1):
			var a: Dictionary = samples[k]
			var b: Dictionary = samples[k + 1]
			var la := _bank_point(a["left"], a["water_z"])
			var ra := _bank_point(a["right"], a["water_z"])
			var lb := _bank_point(b["left"], b["water_z"])
			var rb := _bank_point(b["right"], b["water_z"])
			_tri(st, la, ra, lb)
			_tri(st, ra, rb, lb)
			_segs.append({
				"a": Vector2(float(a["p"][0]), -float(a["p"][1])),
				"b": Vector2(float(b["p"][0]), -float(b["p"][1])),
				"wa": float(a["water_z"]),
				"wb": float(b["water_z"]),
				"ba": float(a["bed_z"]),
				"bb": float(b["bed_z"]),
				"ha": float(a["wet_half_width"]),
				"hb": float(b["wet_half_width"]),
			})
	if _segs.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WATER_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.15
	mat.metallic_specular = 0.6
	var mi := MeshInstance3D.new()
	mi.name = "Agua"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func water_speed_factor(pos: Vector3) -> float:
	var p := Vector2(pos.x, pos.z)
	for s in _segs:
		var ab: Vector2 = s["b"] - s["a"]
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 0.0:
			t = clampf((p - s["a"]).dot(ab) / l2, 0.0, 1.0)
		var closest: Vector2 = s["a"] + ab * t
		var hw := lerpf(s["ha"], s["hb"], t)
		if p.distance_to(closest) > hw:
			continue
		var wz := lerpf(s["wa"], s["wb"], t)
		var bz := lerpf(s["ba"], s["bb"], t)
		if pos.y >= bz - BED_TOL and pos.y <= wz + SURFACE_TOL:
			return SLOW_FACTOR
	return 1.0


func _bank_point(q: Array, z: float) -> Vector3:
	return Vector3(float(q[0]), float(z), -float(q[1]))


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

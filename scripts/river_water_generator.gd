extends Node3D
## Água fluvial procedural para Godot 4.6.
## Usa as linhas centrais exportadas pelo Daggerfall Forge, ajusta-as suavemente ao leito
## já esculpido e gera uma superfície opaca sem collider próprio.

const WATER_SHADER: Shader = preload("res://shaders/river_water.gdshader")
const RIVER_PATHS_SOURCE := "res://assets/world/river_paths.json" # centerlines from the Blender drainage solver
const ALLOW_LEGACY_PATH_RIBBON_FALLBACK := true
const AUTHORITATIVE_RIVER_SOURCES = [
	"res://assets/world/river_data.json",
	"res://assets/world/OW_Rivers_rivers.json",
	"res://assets/world/overworld_rivers.json",
]

const DEFAULT_RIVER_WIDTH := 14.0
const DEFAULT_RIVER_DEPTH := 10.0
const DEFAULT_CHANNEL_RADIUS_CELLS := 2.5
const RESAMPLE_SPACING := 1.5
const BANK_SAMPLE_SPACING := 0.60
const BANK_CLEARANCE := 0.4
const WATER_FILL_RATIO := 0.35
const WATER_MAX_DEPTH_RATIO := 1.40
const WATER_SURFACE_EPSILON := 0.06
const MIN_HALF_WIDTH := 0.8
const CENTERLINE_SNAP_PENALTY := 0.003
const CENTERLINE_RELAX_AMOUNT := 0.20
const CROSS_SECTION_SEGMENTS := 12
const MAX_CROSS_SECTION_SEGMENTS := 48
const AUTHORITATIVE_RESAMPLE_SPACING := 3.0
const WATER_LEVEL_SMOOTH_PASSES := 1
const WATER_LEVEL_SMOOTH_AMOUNT := 0.65
const MAX_WATER_DOWNHILL_GRADE := 0.28
const MAX_WATER_UPHILL_GRADE := 0.04
const FLOW_UV_METERS := 1.0

var _grid_side: int = 0
var _height_grid: PackedFloat32Array = PackedFloat32Array()
var _x_grid: PackedFloat32Array = PackedFloat32Array()
var _z_grid: PackedFloat32Array = PackedFloat32Array()
var _x_key_to_index: Dictionary = {}
var _z_key_to_index: Dictionary = {}
var _min_x: float = 0.0
var _max_x: float = 0.0
var _min_z: float = 0.0
var _max_z: float = 0.0
var _grid_spacing: float = 1.0

var _water_vertices: PackedVector3Array = PackedVector3Array()
var _water_uvs: PackedVector2Array = PackedVector2Array()
var _water_indices: PackedInt32Array = PackedInt32Array()


func build_from_terrain(terrain: MeshInstance3D) -> bool:
	if terrain == null or terrain.mesh == null or terrain.mesh.get_surface_count() == 0:
		push_warning("Água procedural: OW_Terrain não tem uma superfície válida.")
		return false

	var path_data := _load_river_paths()
	if path_data.is_empty():
		push_warning("Água procedural indisponível: não encontrei JSON autoritativo dos rios em assets/world/. Gere-o pelo Daggerfall Forge v0.5.0 e copie o arquivo exportado para essa pasta.")
		return false

	var terrain_arrays: Array = terrain.mesh.surface_get_arrays(0)
	var terrain_vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
	if terrain_vertices.is_empty() or not _build_height_grid(terrain_vertices):
		push_error("Água procedural: não foi possível reconstruir a grade de alturas de OW_Terrain.")
		return false

	_water_vertices = PackedVector3Array()
	_water_uvs = PackedVector2Array()
	_water_indices = PackedInt32Array()
	var built_paths := 0
	var rejected_paths := 0
	var source_method := str(path_data.get("source_method", ""))
	var source_reference := str(path_data.get("_loaded_from", RIVER_PATHS_SOURCE))
	var schema := str(path_data.get("schema", ""))

	if schema == "daggerfall.overworld.rivers":
		if int(path_data.get("schema_version", 0)) != 1:
			push_error("Água procedural: versão de schema dos rios não suportada.")
			return false
		if not _validate_authoritative_grid(path_data.get("terrain_grid", {})):
			push_error("Água procedural: terrain_grid de river_data.json não corresponde ao OW_Terrain importado.")
			return false
		var result: Dictionary = _append_authoritative_rivers(path_data.get("rivers", []))
		built_paths = int(result.get("built", 0))
		rejected_paths = int(result.get("rejected", 0))
		source_reference = str(path_data.get("_loaded_from", "res://assets/world/river_data.json"))
	else:
		# Compatibility path: this project's river_paths.json contains centerlines from
		# the Blender drainage solver. Reconstruct the water extent from the actual imported
		# terrain cross-sections instead of treating it as a color mask or drawing a fixed-width strip.
		if not ALLOW_LEGACY_PATH_RIBBON_FALLBACK:
			push_warning("Água procedural: o JSON atual não contém margens autoritativas. Exporte river_data.json no Daggerfall Forge v0.5.0.")
			return false
		if not _validate_path_bounds(path_data.get("terrain_bounds", {})):
			push_error("Água procedural: os limites de river_paths.json não correspondem ao terreno importado.")
			return false
		var river_width := maxf(1.0, float(path_data.get("river_width", DEFAULT_RIVER_WIDTH)))
		var river_depth := maxf(0.5, float(path_data.get("river_depth", DEFAULT_RIVER_DEPTH)))
		var channel_radius := float(path_data.get("channel_radius", 0.0))
		var paths_are_texture_derived := source_method.contains("skeletonized") or source_method.contains("texture-derived")
		if channel_radius <= 0.0:
			channel_radius = maxf(river_width * 1.05, _grid_spacing * DEFAULT_CHANNEL_RADIUS_CELLS)
		elif paths_are_texture_derived:
			channel_radius = maxf(channel_radius, _grid_spacing * DEFAULT_CHANNEL_RADIUS_CELLS)
		var sea_level := float(path_data.get("sea_level", 0.0))
		var paths: Array = path_data.get("paths", [])
		for entry in paths:
			if not (entry is Dictionary):
				continue
			var raw_points: Array = entry.get("points", [])
			var points := PackedVector2Array()
			for raw_point in raw_points:
				if raw_point is Array and raw_point.size() >= 2:
					points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
			if points.size() < 2:
				continue
			points = _resample_polyline(points, RESAMPLE_SPACING)
			if points.size() < 2:
				continue
			points = _orient_downhill(points)
			points = _snap_and_relax_centerline(points, channel_radius * 0.70)
			if points.size() < 2:
				continue
			var vertex_count_before := _water_vertices.size()
			var uv_count_before := _water_uvs.size()
			var index_count_before := _water_indices.size()
			_append_river_strip(points, channel_radius, river_depth, sea_level)
			if _water_indices.size() > index_count_before:
				built_paths += 1
			else:
				_water_vertices.resize(vertex_count_before)
				_water_uvs.resize(uv_count_before)
				_water_indices.resize(index_count_before)
				rejected_paths += 1

	if _water_indices.is_empty():
		push_warning("Água procedural: nenhum canal válido foi preenchido. Confira se o JSON exportado pelo Daggerfall Forge v0.5.0 corresponde ao mesmo GLB do terreno.")
		return false

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _water_vertices
	arrays[Mesh.ARRAY_TEX_UV] = _water_uvs
	var water_normals := PackedVector3Array()
	water_normals.resize(_water_vertices.size())
	for normal_index in range(water_normals.size()):
		water_normals[normal_index] = Vector3.UP
	arrays[Mesh.ARRAY_NORMAL] = water_normals
	arrays[Mesh.ARRAY_INDEX] = _water_indices

	var river_mesh := ArrayMesh.new()
	river_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if river_mesh.get_surface_count() == 0:
		push_error("Água procedural: falha ao criar a malha de água.")
		return false

	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	river_mesh.surface_set_material(0, material)
	var water_instance := MeshInstance3D.new()
	water_instance.name = "RiverWaterSurface"
	water_instance.mesh = river_mesh
	water_instance.material_override = material
	water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_instance.extra_cull_margin = 10.0
	water_instance.set_meta("generated_by", "RiverWaterGenerator")
	water_instance.set_meta("has_collision", false)
	water_instance.set_meta("source", source_reference)
	water_instance.set_meta("surface_style", "opaque_authoritative_channel_fill")
	water_instance.set_meta("cross_section_subdivisions", CROSS_SECTION_SEGMENTS)
	water_instance.set_meta("width_derived_from", "Blender river left/right bank points refined against terrain")
	add_child(water_instance)

	print("Água procedural: ", built_paths, " rios preenchidos de margem a margem; ", rejected_paths,
		" percursos rejeitados; ", _water_indices.size() / 3,
		" triângulos. Fonte: ", source_reference, ". Superfície opaca, correnteza orientada pelo percurso, sem collider próprio.")
	if schema != "daggerfall.overworld.rivers":
		push_warning("Água procedural: usando as linhas centrais do river_paths.json e reconstruindo as bordas pela altura real do OW_Terrain. Para margens/níveis exatos, exporte river_data.json do Daggerfall Forge v0.5.0.")
	return true


func _load_river_paths() -> Dictionary:
	# Prefer the authoritative JSON exported by Blender v0.5.0. It may be named
	# after the .blend file (for example, MyWorld_rivers.json), so scan assets/world
	# instead of requiring users to rename it. The texture-derived legacy file is
	# considered only after every other JSON has been checked.
	var candidates: Array[String] = []
	for source_variant in AUTHORITATIVE_RIVER_SOURCES:
		var source_path := str(source_variant)
		if not candidates.has(source_path):
			candidates.append(source_path)

	var world_dir := DirAccess.open("res://assets/world")
	if world_dir != null:
		world_dir.list_dir_begin()
		var file_name := world_dir.get_next()
		while not file_name.is_empty():
			if not world_dir.current_is_dir() and file_name.to_lower().ends_with(".json"):
				var discovered_path := "res://assets/world/" + file_name
				if not candidates.has(discovered_path) and file_name != "river_paths.json":
					candidates.append(discovered_path)
			file_name = world_dir.get_next()
		world_dir.list_dir_end()

	# The legacy file is deliberately considered last (after authoritative custom-named JSONs),
	# but it must still be loaded. Previously it was excluded from directory discovery and never
	# added to candidates, so the shader surface was never created with the user's actual file.
	if not candidates.has(RIVER_PATHS_SOURCE):
		candidates.append(RIVER_PATHS_SOURCE)

	var legacy_data: Dictionary = {}
	for source_path in candidates:
		if not FileAccess.file_exists(source_path):
			continue
		var file := FileAccess.open(source_path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary):
			continue
		var data: Dictionary = parsed.duplicate(true)
		if str(data.get("schema", "")) == "daggerfall.overworld.rivers":
			if int(data.get("schema_version", 0)) != 1:
				continue
			data["_loaded_from"] = source_path
			return data
		if str(data.get("format", "")) == "ravenhold_river_paths" and int(data.get("schema_version", 0)) == 1:
			data["_loaded_from"] = source_path
			legacy_data = data

	# Retain the old data only as a detectable fallback. The caller controls whether
	# the ribbon approximation may be rendered; it is never mistaken for authoritative data.
	return legacy_data


func _validate_authoritative_grid(grid: Dictionary) -> bool:
	if grid.is_empty() or _grid_side < 2:
		return false
	var expected_size := float(grid.get("world_size", 0.0))
	var origin: Array = grid.get("origin", [])
	if expected_size <= 0.0 or origin.size() < 2:
		return false
	var actual_size_x := _max_x - _min_x
	var actual_size_z := _max_z - _min_z
	var expected_min_x := float(origin[0])
	var expected_min_z := -float(origin[1]) - expected_size
	var tolerance := maxf(2.0, _grid_spacing * 0.5)
	return (
		absf(actual_size_x - expected_size) <= tolerance
		and absf(actual_size_z - expected_size) <= tolerance
		and absf(_min_x - expected_min_x) <= tolerance
		and absf(_min_z - expected_min_z) <= tolerance
	)


func _append_authoritative_rivers(rivers_variant: Variant) -> Dictionary:
	var result := {"built": 0, "rejected": 0}
	if not (rivers_variant is Array):
		return result
	for river_variant in rivers_variant:
		if not (river_variant is Dictionary):
			result["rejected"] += 1
			continue
		var samples: Array = river_variant.get("samples", [])
		if samples.size() < 2:
			result["rejected"] += 1
			continue
		var source_sections: Array[Dictionary] = []
		for sample_variant in samples:
			if not (sample_variant is Dictionary):
				continue
			var sample: Dictionary = sample_variant
			var center_array: Array = sample.get("p", [])
			var left_array: Array = sample.get("left", [])
			var right_array: Array = sample.get("right", [])
			if center_array.size() < 2 or left_array.size() < 2 or right_array.size() < 2:
				continue
			# Blender's river JSON is x/y horizontal with +Z up. The default GLTF conversion
			# used by this project maps it to Godot x/z with z = -Blender y and y = Blender z.
			var center := Vector2(float(center_array[0]), -float(center_array[1]))
			var left := Vector2(float(left_array[0]), -float(left_array[1]))
			var right := Vector2(float(right_array[0]), -float(right_array[1]))
			# Usa a altura real do terreno em vez do water_z do JSON (evita água flutuando)
			var bed_y := _sample_terrain_height(center.x, center.y)
			var water_y := bed_y + 0.12
			var outer_half_width := maxf(float(sample.get("outer_half_width", 0.0)), maxf(center.distance_to(left), center.distance_to(right)))
			if center.distance_to(left) < 0.15 or center.distance_to(right) < 0.15:
				continue
			source_sections.append({
				"center": center, "left": left, "right": right,
				"water_y": water_y, "bed_y": bed_y,
				"arc": float(sample.get("s", 0.0)),
				"outer_half_width": outer_half_width,
			})
		if source_sections.size() < 2:
			result["rejected"] += 1
			continue
		var sections := _resample_water_sections(source_sections, AUTHORITATIVE_RESAMPLE_SPACING)
		if sections.size() < 2:
			result["rejected"] += 1
			continue
		var max_width := 0.0
		for section in sections:
			var section_left: Vector2 = section["left"]
			var section_right: Vector2 = section["right"]
			max_width = maxf(max_width, section_left.distance_to(section_right))
		var across_step := maxf(1.5, minf(_grid_spacing * 0.25, 4.0))
		var cross_segments := clampi(int(ceil(max_width / across_step)), CROSS_SECTION_SEGMENTS, MAX_CROSS_SECTION_SEGMENTS)
		var base_vertex := _water_vertices.size()
		var columns := cross_segments + 1
		var refined_left := PackedVector2Array()
		var refined_right := PackedVector2Array()
		var levels := PackedFloat32Array()
		refined_left.resize(sections.size())
		refined_right.resize(sections.size())
		levels.resize(sections.size())
		for i in range(sections.size()):
			levels[i] = float(sections[i]["water_y"])
		# Smooth the authored waterline before finding banks
		for _pass in range(3):
			var filtered := levels.duplicate()
			for i in range(1, levels.size() - 1):
				var target := (levels[i - 1] + levels[i] * 2.0 + levels[i + 1]) * 0.25
				filtered[i] = maxf(lerpf(levels[i], target, 0.35), float(sections[i]["bed_y"]) + WATER_SURFACE_EPSILON)
			levels = filtered
		# Refine each bank against the actual imported terrain heightfield
		for i in range(sections.size()):
			var section: Dictionary = sections[i]
			var center: Vector2 = section["center"]
			var left: Vector2 = section["left"]
			var right: Vector2 = section["right"]
			var level := levels[i]
			var left_direction := (left - center).normalized()
			var right_direction := (right - center).normalized()
			var outer := maxf(float(section["outer_half_width"]), maxf(center.distance_to(left), center.distance_to(right)))
			refined_left[i] = _find_authoritative_waterline(center, left_direction, center.distance_to(left), outer, level)
			refined_right[i] = _find_authoritative_waterline(center, right_direction, center.distance_to(right), outer, level)
		# Smooth widths (only inward)
		var left_width_profile := PackedFloat32Array()
		var right_width_profile := PackedFloat32Array()
		left_width_profile.resize(sections.size())
		right_width_profile.resize(sections.size())
		for i in range(sections.size()):
			var center: Vector2 = sections[i]["center"]
			left_width_profile[i] = center.distance_to(refined_left[i])
			right_width_profile[i] = center.distance_to(refined_right[i])
		left_width_profile = _smooth_conservative_widths(left_width_profile, 7, 0.52)
		right_width_profile = _smooth_conservative_widths(right_width_profile, 7, 0.52)
		# Limita a largura para a água não vazar pro gramado
		var max_half := 6.5
		for i in range(sections.size()):
			left_width_profile[i] = minf(left_width_profile[i], max_half)
			right_width_profile[i] = minf(right_width_profile[i], max_half)
		for i in range(sections.size()):
			var center: Vector2 = sections[i]["center"]
			var left_point: Vector2 = sections[i]["left"]
			var right_point: Vector2 = sections[i]["right"]
			var left_direction := (left_point - center).normalized()
			var right_direction := (right_point - center).normalized()
			refined_left[i] = center + left_direction * left_width_profile[i]
			refined_right[i] = center + right_direction * right_width_profile[i]
		var distance_along := 0.0
		for i in range(sections.size()):
			if i > 0:
				var current_center: Vector2 = sections[i]["center"]
				var previous_center: Vector2 = sections[i - 1]["center"]
				distance_along += current_center.distance_to(previous_center)
			var level := levels[i]
			var left := refined_left[i]
			var right := refined_right[i]
			for column in range(columns):
				var u := float(column) / float(cross_segments)
				var point := left.lerp(right, u)
				_water_vertices.append(Vector3(point.x, level, point.y))
				_water_uvs.append(Vector2(u, distance_along / FLOW_UV_METERS))
		for row in range(sections.size() - 1):
			for column in range(cross_segments):
				var a := base_vertex + row * columns + column
				var b := base_vertex + (row + 1) * columns + column
				var c := base_vertex + (row + 1) * columns + column + 1
				var d := base_vertex + row * columns + column + 1
				_append_upward_triangle(a, b, c)
				_append_upward_triangle(a, c, d)
		result["built"] += 1
	return result


func _resample_water_sections(source: Array[Dictionary], target_spacing: float) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if source.size() < 2:
		return output
	output.append(source[0].duplicate(true))
	for i in range(source.size() - 1):
		var a: Dictionary = source[i]
		var b: Dictionary = source[i + 1]
		var center_a: Vector2 = a["center"]
		var center_b: Vector2 = b["center"]
		var distance := center_a.distance_to(center_b)
		if distance < 0.001:
			continue
		var steps := maxi(1, int(ceil(distance / target_spacing)))
		for step in range(1, steps + 1):
			var t := float(step) / float(steps)
			var a_left: Vector2 = a["left"]
			var b_left: Vector2 = b["left"]
			var a_right: Vector2 = a["right"]
			var b_right: Vector2 = b["right"]
			output.append({
				"center": center_a.lerp(center_b, t),
				"left": a_left.lerp(b_left, t),
				"right": a_right.lerp(b_right, t),
				"water_y": lerpf(float(a["water_y"]), float(b["water_y"]), t),
				"bed_y": lerpf(float(a["bed_y"]), float(b["bed_y"]), t),
				"arc": lerpf(float(a["arc"]), float(b["arc"]), t),
				"outer_half_width": lerpf(float(a["outer_half_width"]), float(b["outer_half_width"]), t),
			})
	return output


func _find_authoritative_waterline(center: Vector2, direction: Vector2, guessed_width: float,
		outer_half_width: float, water_y: float) -> Vector2:
	if direction.length_squared() < 0.00001:
		return center
	direction = direction.normalized()
	var threshold := water_y - 0.015
	var previous_distance := 0.0
	var previous_height := _sample_terrain_height(center.x, center.y)
	if previous_height >= threshold:
		# If the center sample is slightly above the authored water level, use its bank input
		# unchanged rather than expanding across terrain that should remain dry.
		return center + direction * maxf(0.1, guessed_width)
	var max_distance := maxf(guessed_width + _grid_spacing * 0.8, outer_half_width + _grid_spacing * 0.4)
	max_distance = maxf(max_distance, guessed_width * 1.25)
	var step_size := maxf(0.75, minf(_grid_spacing * 0.12, 1.75))
	var distance := step_size
	while distance <= max_distance:
		var ground := _sample_terrain_height(center.x + direction.x * distance, center.y + direction.y * distance)
		if ground >= threshold:
			var height_delta := ground - previous_height
			var t := 1.0
			if absf(height_delta) > 0.0001:
				t = clampf((threshold - previous_height) / height_delta, 0.0, 1.0)
			var crossing_distance := lerpf(previous_distance, distance, t)
			return center + direction * maxf(0.1, crossing_distance - 0.025)
		previous_distance = distance
		previous_height = ground
		distance += step_size
	return center + direction * maxf(0.1, guessed_width)


func _append_upward_triangle(a: int, b: int, c: int) -> void:
	var normal := (_water_vertices[b] - _water_vertices[a]).cross(_water_vertices[c] - _water_vertices[a])
	if normal.y >= 0.0:
		_water_indices.append(a)
		_water_indices.append(b)
		_water_indices.append(c)
	else:
		_water_indices.append(a)
		_water_indices.append(c)
		_water_indices.append(b)


func _validate_path_bounds(bounds: Dictionary) -> bool:
	if bounds.is_empty() or _grid_side < 2:
		return false
	var expected_min_x := float(bounds.get("min_x", _min_x))
	var expected_max_x := float(bounds.get("max_x", _max_x))
	var expected_min_z := float(bounds.get("min_z", _min_z))
	var expected_max_z := float(bounds.get("max_z", _max_z))
	var tolerance := maxf(2.0, _grid_spacing * 0.25)
	return (
		absf(expected_min_x - _min_x) <= tolerance
		and absf(expected_max_x - _max_x) <= tolerance
		and absf(expected_min_z - _min_z) <= tolerance
		and absf(expected_max_z - _max_z) <= tolerance
	)


func _append_river_strip(source_points: PackedVector2Array, channel_radius: float, river_depth: float, sea_level: float) -> void:
	var points := source_points
	if points.size() < 2:
		return
	var count := points.size()
	var beds := PackedFloat32Array()
	var low_banks := PackedFloat32Array()
	var water_levels := PackedFloat32Array()
	var left_normals := PackedVector2Array()
	var left_widths := PackedFloat32Array()
	var right_widths := PackedFloat32Array()
	beds.resize(count)
	low_banks.resize(count)
	water_levels.resize(count)
	left_normals.resize(count)
	left_widths.resize(count)
	right_widths.resize(count)

	# First estimate the liquid level at each river station. The metadata depth is a design
	# parameter, not the actual carved depth, so the sampled channel relief is authoritative.
	# Filling close to the lower bank keeps water from becoming a thin stripe at the thalweg.
	var maximum_fill := maxf(river_depth * WATER_MAX_DEPTH_RATIO, _grid_spacing * 0.65)
	# The texture-derived centreline is much narrower than the real channel. Probe the terrain
	# near the outer bank of the carved cross-section; sampling only at centreline radius was
	# making the water stop in the middle even when the channel was much wider.
	var bank_probe_radius := maxf(channel_radius * 1.55, _grid_spacing * 3.0)
	for i in range(count):
		var center := points[i]
		var tangent := _path_tangent(points, i)
		var side := Vector2(-tangent.y, tangent.x).normalized()
		left_normals[i] = side
		var bed_y := _sample_terrain_height(center.x, center.y)
		var left_bank_y := _sample_terrain_height(center.x + side.x * bank_probe_radius, center.y + side.y * bank_probe_radius)
		var right_bank_y := _sample_terrain_height(center.x - side.x * bank_probe_radius, center.y - side.y * bank_probe_radius)
		var low_bank_y := minf(left_bank_y, right_bank_y)
		var relief := maxf(0.0, low_bank_y - bed_y)
		beds[i] = bed_y
		low_banks[i] = low_bank_y

		var fill_depth := minf(relief * WATER_FILL_RATIO, maximum_fill)
		var water_y := bed_y + maxf(WATER_SURFACE_EPSILON, fill_depth)
		if relief > BANK_CLEARANCE + WATER_SURFACE_EPSILON:
			water_y = minf(water_y, low_bank_y - BANK_CLEARANCE)
		else:
			water_y = bed_y + WATER_SURFACE_EPSILON
		if bed_y <= sea_level + 0.35:
			var ocean_join_y := sea_level + WATER_SURFACE_EPSILON
			if ocean_join_y > bed_y and ocean_join_y <= low_bank_y - BANK_CLEARANCE:
				water_y = ocean_join_y
		water_levels[i] = water_y

	# Water surface levels are smoothed over several metres, then constrained to the bed
	# and banks. This removes the abrupt drops that previously turned long quads into sloping
	# blue plates. Sharp falls remain only where the terrain physically leaves no room to smooth.
	water_levels = _smooth_constrained_water_levels(water_levels, beds, low_banks, points)

	# Find each shoreline from the real terrain cross-section. A slightly wider search radius
	# helps fill the channel's rounded shoulder, while the first bank crossing prevents flooding.
	var edge_search_radius := maxf(channel_radius * 1.75, _grid_spacing * 3.25)
	for i in range(count):
		var center := points[i]
		var side := left_normals[i]
		left_widths[i] = _find_water_edge(center, side, edge_search_radius, water_levels[i])
		right_widths[i] = _find_water_edge(center, -side, edge_search_radius, water_levels[i])

	# Smooth jagged intersections caused by sampling a coarse terrain grid. The filtered
	# widths are clamped to the originally measured widths, so smoothing can narrow the
	# surface slightly but cannot extend it onto dry land.
	left_widths = _smooth_conservative_widths(left_widths, 7, 0.52)
	right_widths = _smooth_conservative_widths(right_widths, 7, 0.52)

	# Subdivide every cross-section instead of spanning the entire river with a single pair of
	# vertices. This prevents width changes from producing huge twisting triangles and gives the
	# shader a proper across-river UV axis. The water remains one continuous visual surface.
	var base_vertex := _water_vertices.size()
	var across_step := maxf(1.5, minf(_grid_spacing * 0.25, 4.0))
	var cross_segments := clampi(int(ceil(edge_search_radius * 2.0 / across_step)), CROSS_SECTION_SEGMENTS, MAX_CROSS_SECTION_SEGMENTS)
	var columns := cross_segments + 1
	var distance_along := 0.0
	for i in range(count):
		if i > 0:
			distance_along += points[i].distance_to(points[i - 1])
		var center := points[i]
		var side := left_normals[i]
		var left_w := clampf(left_widths[i], 0.0, edge_search_radius)
		var right_w := clampf(right_widths[i], 0.0, edge_search_radius)
		var y := water_levels[i]
		var v := distance_along / FLOW_UV_METERS
		for column in range(columns):
			var across := float(column) / float(cross_segments)
			var lateral := lerpf(left_w, -right_w, across)
			var position := Vector3(center.x + side.x * lateral, y, center.y + side.y * lateral)
			_water_vertices.append(position)
			_water_uvs.append(Vector2(across, v))

	for row in range(count - 1):
		for column in range(cross_segments):
			var a := base_vertex + row * columns + column
			var b := base_vertex + (row + 1) * columns + column
			var c := base_vertex + (row + 1) * columns + column + 1
			var d := base_vertex + row * columns + column + 1
			_append_upward_triangle(a, b, c)
			_append_upward_triangle(a, c, d)


func _smooth_conservative_widths(source: PackedFloat32Array, passes: int = 5, amount: float = 0.45) -> PackedFloat32Array:
	if source.size() < 3 or passes <= 0 or amount <= 0.0:
		return source.duplicate()
	var original := source.duplicate()
	var result := source.duplicate()
	for _pass in range(mini(passes, 12)):
		var filtered := result.duplicate()
		for i in range(1, result.size() - 1):
			var neighbor_average := (result[i - 1] + result[i] * 2.0 + result[i + 1]) * 0.25
			var candidate := lerpf(result[i], neighbor_average, clampf(amount, 0.0, 1.0))
			filtered[i] = clampf(candidate, 0.0, original[i])
		result = filtered
	return result


func _smooth_constrained_water_levels(source: PackedFloat32Array, beds: PackedFloat32Array,
		low_banks: PackedFloat32Array, points: PackedVector2Array) -> PackedFloat32Array:
	var result := source.duplicate()
	if result.size() < 3:
		return result

	# A five-tap low-pass filter repeated across the profile removes the terrain grid's local
	# height changes without turning the entire river into a horizontal plane.
	for _pass in range(WATER_LEVEL_SMOOTH_PASSES):
		var filtered := result.duplicate()
		for i in range(1, result.size() - 1):
			var i0 := maxi(0, i - 2)
			var i1 := maxi(0, i - 1)
			var i3 := mini(result.size() - 1, i + 1)
			var i4 := mini(result.size() - 1, i + 2)
			var weighted := (
				result[i0] + result[i1] * 2.0 + result[i] * 3.0
				+ result[i3] * 2.0 + result[i4]
			)
			var average := weighted / 9.0
			var candidate := lerpf(result[i], average, WATER_LEVEL_SMOOTH_AMOUNT)
			var lower := beds[i] + WATER_SURFACE_EPSILON
			var upper := low_banks[i] - BANK_CLEARANCE
			if upper < lower:
				upper = lower
			filtered[i] = clampf(candidate, lower, upper)
		result = filtered

	# Constrain the surface grade in the flow direction and in reverse. Apply a constraint
	# only when it still fits between the sampled bed and lower bank; otherwise the section is
	# a genuine steep/narrow section and must drop rather than cover dry terrain.
	for _pass in range(3):
		for i in range(1, result.size()):
			var forward_distance := points[i - 1].distance_to(points[i])
			var forward_lower := beds[i] + WATER_SURFACE_EPSILON
			var forward_upper := maxf(forward_lower, low_banks[i] - BANK_CLEARANCE)
			var forward_grade_low := result[i - 1] - MAX_WATER_DOWNHILL_GRADE * forward_distance
			var forward_grade_high := result[i - 1] + MAX_WATER_UPHILL_GRADE * forward_distance
			var forward_candidate := clampf(result[i], forward_grade_low, forward_grade_high)
			if forward_candidate >= forward_lower and forward_candidate <= forward_upper:
				result[i] = forward_candidate
		for i in range(result.size() - 2, -1, -1):
			var backward_distance := points[i].distance_to(points[i + 1])
			var backward_lower := beds[i] + WATER_SURFACE_EPSILON
			var backward_upper := maxf(backward_lower, low_banks[i] - BANK_CLEARANCE)
			var backward_grade_low := result[i + 1] - MAX_WATER_UPHILL_GRADE * backward_distance
			var backward_grade_high := result[i + 1] + MAX_WATER_DOWNHILL_GRADE * backward_distance
			var backward_candidate := clampf(result[i], backward_grade_low, backward_grade_high)
			if backward_candidate >= backward_lower and backward_candidate <= backward_upper:
				result[i] = backward_candidate
	return result


func _find_water_edge(center: Vector2, direction: Vector2, max_distance: float, water_y: float) -> float:
	# Find the waterline by intersecting the sampled terrain profile. If the centerline
	# itself is above the water, or no bank rises above it, collapse this side instead
	# of rendering a sheet over dry ground.
	var threshold_y := water_y + 0.04
	var previous_distance := 0.0
	var previous_height := _sample_terrain_height(center.x, center.y)
	if previous_height >= threshold_y:
		return 0.0
	var d := BANK_SAMPLE_SPACING
	while d <= max_distance:
		var ground_y := _sample_terrain_height(center.x + direction.x * d, center.y + direction.y * d)
		if ground_y >= threshold_y:
			var height_span := ground_y - previous_height
			var fraction := 1.0
			if absf(height_span) > 0.0001:
				fraction = clampf((threshold_y - previous_height) / height_span, 0.0, 1.0)
			var crossing_distance := lerpf(previous_distance, d, fraction)
			return clampf(crossing_distance - 0.02, 0.0, max_distance)
		previous_distance = d
		previous_height = ground_y
		d += BANK_SAMPLE_SPACING
	return 0.0

func _orient_downhill(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var start_y := _sample_terrain_height(points[0].x, points[0].y)
	var end_y := _sample_terrain_height(points[points.size() - 1].x, points[points.size() - 1].y)
	if start_y >= end_y:
		return points
	var reversed := PackedVector2Array()
	for i in range(points.size() - 1, -1, -1):
		reversed.append(points[i])
	return reversed


func _snap_and_relax_centerline(source: PackedVector2Array, radius: float) -> PackedVector2Array:
	if source.size() < 3 or radius <= 0.1:
		return source
	var points := source.duplicate()
	var search_radius := minf(radius, 10.0)
	var steps := maxi(4, int(ceil(search_radius / 1.25)))
	var snapped := PackedVector2Array()
	snapped.resize(points.size())
	for i in range(points.size()):
		var center := points[i]
		var tangent := _path_tangent(points, i)
		var side := Vector2(-tangent.y, tangent.x).normalized()
		var best_point := center
		var best_score := _sample_terrain_height(center.x, center.y)
		for k in range(-steps, steps + 1):
			var offset := search_radius * float(k) / float(steps)
			var candidate := center + side * offset
			var score := _sample_terrain_height(candidate.x, candidate.y) + offset * offset * CENTERLINE_SNAP_PENALTY
			if score < best_score:
				best_score = score
				best_point = candidate
		snapped[i] = best_point

	# Relax small lateral jumps and re-snap within a narrower search range to stay in the bed.
	for _iteration in range(2):
		var relaxed := snapped.duplicate()
		for i in range(1, snapped.size() - 1):
			var average := (snapped[i - 1] + snapped[i] * 2.0 + snapped[i + 1]) * 0.25
			relaxed[i] = snapped[i].lerp(average, CENTERLINE_RELAX_AMOUNT)
		snapped = relaxed

	# Relaxing removes pixel-scale jitter, then a narrow snap puts every sample back
	# into the actual depression instead of allowing the smoothed line to climb a bank.
	var recentered := snapped.duplicate()
	var fine_radius := minf(3.5, search_radius * 0.38)
	var fine_steps := maxi(3, int(ceil(fine_radius / 0.8)))
	for i in range(1, snapped.size() - 1):
		var center := snapped[i]
		var tangent := _path_tangent(snapped, i)
		var side := Vector2(-tangent.y, tangent.x).normalized()
		var best_point := center
		var best_score := _sample_terrain_height(center.x, center.y)
		for k in range(-fine_steps, fine_steps + 1):
			var offset := fine_radius * float(k) / float(fine_steps)
			var candidate := center + side * offset
			var score := _sample_terrain_height(candidate.x, candidate.y) + offset * offset * CENTERLINE_SNAP_PENALTY
			if score < best_score:
				best_score = score
				best_point = candidate
		recentered[i] = best_point
	return recentered


func _path_tangent(points: PackedVector2Array, index: int) -> Vector2:
	var previous := points[maxi(0, index - 1)]
	var next := points[mini(points.size() - 1, index + 1)]
	var tangent := next - previous
	if tangent.length_squared() < 0.000001:
		if index > 0:
			tangent = points[index] - points[index - 1]
			if tangent.length_squared() < 0.000001:
				tangent = Vector2.RIGHT
		else:
			tangent = Vector2.RIGHT
	return tangent.normalized()


func _resample_polyline(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	if points.size() < 2 or spacing <= 0.0:
		return points.duplicate()
	var result := PackedVector2Array()
	result.append(points[0])
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var distance := a.distance_to(b)
		if distance <= 0.0001:
			continue
		var steps := maxi(1, int(ceil(distance / spacing)))
		for step in range(1, steps + 1):
			result.append(a.lerp(b, float(step) / float(steps)))
	return result


func _smooth_profile(source: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	if source.size() < 3 or amount <= 0.0:
		return source.duplicate()
	var result := source.duplicate()
	for i in range(1, source.size() - 1):
		var filtered := (source[i - 1] + source[i] * 2.0 + source[i + 1]) * 0.25
		result[i] = lerpf(source[i], filtered, amount)
	return result


func _build_height_grid(source_vertices: PackedVector3Array) -> bool:
	if source_vertices.is_empty():
		return false
	var x_values_by_key: Dictionary = {}
	var z_values_by_key: Dictionary = {}
	for vertex in source_vertices:
		var x_key := roundi(vertex.x * 1000.0)
		var z_key := roundi(vertex.z * 1000.0)
		if not x_values_by_key.has(x_key):
			x_values_by_key[x_key] = vertex.x
		if not z_values_by_key.has(z_key):
			z_values_by_key[z_key] = vertex.z
	if x_values_by_key.size() < 2 or z_values_by_key.size() != x_values_by_key.size():
		return false

	var x_values: Array = x_values_by_key.values()
	var z_values: Array = z_values_by_key.values()
	x_values.sort()
	z_values.sort_custom(func(a, b): return float(a) > float(b))
	_grid_side = x_values.size()
	_x_grid = PackedFloat32Array()
	_z_grid = PackedFloat32Array()
	_x_key_to_index.clear()
	_z_key_to_index.clear()
	for i in range(_grid_side):
		var xv := float(x_values[i])
		var zv := float(z_values[i])
		_x_grid.append(xv)
		_z_grid.append(zv)
		_x_key_to_index[roundi(xv * 1000.0)] = i
		_z_key_to_index[roundi(zv * 1000.0)] = i
	_min_x = _x_grid[0]
	_max_x = _x_grid[_grid_side - 1]
	_max_z = _z_grid[0]
	_min_z = _z_grid[_grid_side - 1]
	if is_equal_approx(_min_x, _max_x) or is_equal_approx(_min_z, _max_z):
		return false
	_grid_spacing = minf(absf(_x_grid[1] - _x_grid[0]), absf(_z_grid[1] - _z_grid[0]))
	if _grid_spacing <= 0.0001:
		return false

	_height_grid = PackedFloat32Array()
	_height_grid.resize(_grid_side * _grid_side)
	var counts := PackedInt32Array()
	counts.resize(_grid_side * _grid_side)
	for i in range(counts.size()):
		_height_grid[i] = 0.0
		counts[i] = 0
	for vertex in source_vertices:
		var xi := int(_x_key_to_index.get(roundi(vertex.x * 1000.0), -1))
		var zi := int(_z_key_to_index.get(roundi(vertex.z * 1000.0), -1))
		if xi < 0 or zi < 0:
			continue
		var grid_index := xi * _grid_side + zi
		_height_grid[grid_index] += vertex.y
		counts[grid_index] += 1
	var missing_cells := 0
	for i in range(counts.size()):
		if counts[i] > 0:
			_height_grid[i] /= float(counts[i])
		else:
			missing_cells += 1

	# Some GLB exports omit a handful of terrain vertices where degenerate
	# triangles were removed. The terrain can still be a valid grid; fill sparse
	# holes from adjacent known heights instead of failing the entire river system.
	if missing_cells > 0:
		var unresolved := missing_cells
		for pass_index in range(_grid_side):
			var next_heights := _height_grid.duplicate()
			var next_counts := counts.duplicate()
			var filled_this_pass := 0
			for xi in range(_grid_side):
				for zi in range(_grid_side):
					var cell_index := xi * _grid_side + zi
					if counts[cell_index] > 0:
						continue
					var weighted_height := 0.0
					var total_weight := 0.0
					for dx in range(-1, 2):
						for dz in range(-1, 2):
							if dx == 0 and dz == 0:
								continue
							var nx := xi + dx
							var nz := zi + dz
							if nx < 0 or nx >= _grid_side or nz < 0 or nz >= _grid_side:
								continue
							var neighbor_index := nx * _grid_side + nz
							if counts[neighbor_index] <= 0:
								continue
							var weight := 2.0 if abs(dx) + abs(dz) == 1 else 1.0
							weighted_height += _height_grid[neighbor_index] * weight
							total_weight += weight
						if total_weight > 0.0:
							next_heights[cell_index] = weighted_height / total_weight
							next_counts[cell_index] = 1
							filled_this_pass += 1
			_height_grid = next_heights
			counts = next_counts
			unresolved -= filled_this_pass
			if unresolved <= 0 or filled_this_pass == 0:
				break
		if unresolved > 0:
			push_warning("Água procedural: a grade de alturas contém %d células sem vizinhos válidos; rios foram desativados para evitar geometria incorreta." % unresolved)
			return false
		print("Água procedural: grade de alturas reconstruída; %d vértices ausentes foram interpolados a partir dos vizinhos." % missing_cells)
	return true


func _sample_terrain_height(local_x: float, local_z: float) -> float:
	var x_span := _max_x - _min_x
	var z_span := _max_z - _min_z
	var gx := clampf((local_x - _min_x) / x_span * float(_grid_side - 1), 0.0, float(_grid_side - 1) - 0.00001)
	var gz := clampf((_max_z - local_z) / z_span * float(_grid_side - 1), 0.0, float(_grid_side - 1) - 0.00001)
	var i := int(floor(gx))
	var j := int(floor(gz))
	var tx := gx - float(i)
	var tz := gz - float(j)
	var h00 := _height_grid[i * _grid_side + j]
	var h10 := _height_grid[(i + 1) * _grid_side + j]
	var h01 := _height_grid[i * _grid_side + j + 1]
	var h11 := _height_grid[(i + 1) * _grid_side + j + 1]
	# Same alternating triangulation as the terrain generated in Blender.
	if (i + j) % 2 == 0:
		if tx >= tz:
			return h00 + (h10 - h00) * tx + (h11 - h10) * tz
		return h00 + (h11 - h01) * tx + (h01 - h00) * tz
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func _build_smooth_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	for i in range(0, indices.size(), 3):
		var a := int(indices[i])
		var b := int(indices[i + 1])
		var c := int(indices[i + 2])
		var face_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if face_normal.length_squared() <= 0.0000001:
			continue
		if face_normal.y < 0.0:
			face_normal = -face_normal
		normals[a] += face_normal
		normals[b] += face_normal
		normals[c] += face_normal
	for i in range(normals.size()):
		if normals[i].length_squared() > 0.000001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	return normals

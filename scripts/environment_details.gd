extends Node3D
# Vegetação baixa procedural e trilhas acumuladas pelo trânsito dos habitantes.
# A decoração é visual e agrupada em MultiMeshes por setor para hardware modesto.

const CHUNK_SIZE := 48.0
const LOAD_RADIUS := 112.0
const UNLOAD_RADIUS := 176.0
const GRID_RESOLUTION := 14
const TRAIL_CELL_SIZE := 0.9
const TRAIL_VISIBLE_AT := 2.5
const TRAFFIC_SAMPLE_INTERVAL := 0.42
const ACTOR_CELL_COOLDOWN := 2.0
const CHUNK_REFRESH_INTERVAL := 0.65
const TRAIL_REBUILD_INTERVAL := 0.28
const MAX_TRAIL_REBUILDS_PER_TICK := 1
const INVALID_CHUNK := Vector2i(2147483647, 2147483647)
const GRASS_TINTS = [Color(0.68, 0.82, 0.52), Color(0.78, 0.88, 0.58), Color(0.62, 0.78, 0.48), Color(0.83, 0.82, 0.54)]
const GREEN_MASK_FILE_PREFIX := "overworld_OW_TerrainAlbedo_"
# Erode the green mask slightly so foliage/tracks stay off shorelines, rock borders,
# sand, painted roads and settlement symbols in the terrain albedo.
const GREEN_MASK_EDGE_CLEARANCE := 1.5
const GREEN_MASK_CHECK_OFFSETS := [
	Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0),
	Vector3(0.707, 0.0, 0.707), Vector3(-0.707, 0.0, 0.707),
	Vector3(0.707, 0.0, -0.707), Vector3(-0.707, 0.0, -0.707)
]
const CRITTER_DAY_START := 6.0
const CRITTER_NIGHT_START := 19.0
const BUTTERFLY_TINTS = [
	Color(1.0, 0.78, 0.45, 1.0),
	Color(0.92, 0.92, 0.70, 1.0),
	Color(0.70, 0.84, 1.0, 1.0),
	Color(0.93, 0.70, 0.88, 1.0),
	Color(0.90, 0.90, 0.88, 1.0)
]

var _world: Node3D = null
var _game: Node = null
var _player: Node3D = null
var _bounds := AABB()
var _settlements: Array = []
var _sea_level := 0.0
var _rng := RandomNumberGenerator.new()
var _green_mask: Image = null

var _grass_mesh: ArrayMesh
var _flower_mesh: ArrayMesh
var _shrub_mesh: SphereMesh
var _grass_material: StandardMaterial3D
var _flower_material: StandardMaterial3D
var _shrub_material: StandardMaterial3D
var _trail_material: StandardMaterial3D
var _butterfly_mesh: ArrayMesh
var _butterfly_material: ShaderMaterial
var _firefly_mesh: SphereMesh
var _firefly_material: ShaderMaterial
var _critter_mode := "day"

# Loaded decoration chunks; far chunks are discarded and recreated when approached.
var _chunks: Dictionary = {}
var _pending_chunks: Array[Vector2i] = []
var _generation_running := false
var _generating_chunk := INVALID_CHUNK
var _chunk_refresh_timer := 99.0
var _last_player_position := Vector3.ZERO

# Each cell stores cumulative traffic, ground position/normal, and its latest direction.
var _trail_cells: Dictionary = {}
var _trail_chunk_cells: Dictionary = {}
var _last_actor_positions: Dictionary = {}
var _recent_cells_by_actor: Dictionary = {}
var _elapsed := 0.0
var _sample_timer := 0.0
var _trail_rebuild_timer := 0.0
var _state_dirty := false

# Spatially bucketed structure bounds keep decorative plants out of buildings and ruins.
var _structure_bins: Dictionary = {}


func initialize(world_root: Node3D, terrain_bounds: AABB, settlement_records: Array, player_node: Node3D, saved_trails: Dictionary) -> void:
	_world = world_root
	_game = world_root.get("game")
	_player = player_node
	_bounds = terrain_bounds
	_settlements = settlement_records.duplicate()
	_sea_level = float(world_root.get("sea_level"))
	_rng.randomize()
	_critter_mode = _get_critter_mode()
	_load_green_mask()
	_make_materials_and_meshes()
	_build_structure_index()
	if not saved_trails.is_empty():
		_trail_cells = saved_trails.duplicate(true)
	_filter_trails_to_green_areas()
	_rebuild_trail_index()
	_last_player_position = _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	if _game != null:
		_game.set("foot_traffic_session_state", _trail_cells)


func tick(delta: float, player_position: Vector3, record_traffic: bool, active_npcs: Array) -> void:
	if _world == null or not is_instance_valid(_world):
		return
	_elapsed += delta
	_update_critter_mode()
	_update_chunk_streaming(delta, player_position)
	if record_traffic:
		_sample_timer += delta
		if _sample_timer >= TRAFFIC_SAMPLE_INTERVAL:
			_sample_timer = 0.0
			_record_actor_motion("player", player_position)
			for npc_value in active_npcs:
				if not is_instance_valid(npc_value) or not (npc_value is Node3D):
					continue
				if not bool(npc_value.get("visible")) or bool(npc_value.get("is_at_home")) or not bool(npc_value.get("life_enabled")):
					continue
				var actor_id := str(npc_value.get("npc_id"))
				if actor_id.is_empty():
					actor_id = str(npc_value.get_instance_id())
				_record_actor_motion("npc:" + actor_id, npc_value.global_position)
	else:
		# Evita desenhar uma linha reta artificial entre abrir menu/pausa e voltar ao jogo.
		_last_actor_positions.clear()
		_sample_timer = 0.0
	
	_trail_rebuild_timer += delta
	if _trail_rebuild_timer >= TRAIL_REBUILD_INTERVAL:
		_trail_rebuild_timer = 0.0
		_rebuild_one_dirty_trail()
	if _state_dirty and _game != null:
		_game.set("foot_traffic_session_state", _trail_cells)
		_state_dirty = false
	_last_player_position = player_position


func _load_green_mask() -> void:
	# Use the texture actually assigned to OW_Terrain first. The exported texture
	# suffix changes when the Blender world is regenerated, so a fixed numeric
	# filename becomes stale even when the new terrain albedo is present.
	_green_mask = null
	var terrain := _find_terrain_mesh(_world)
	if terrain != null and terrain.mesh != null:
		for surface_index in range(terrain.mesh.get_surface_count()):
			var surface_material := terrain.get_active_material(surface_index)
			if surface_material is BaseMaterial3D:
				var material := surface_material as BaseMaterial3D
				var albedo_texture := material.albedo_texture
				if albedo_texture != null:
					var material_image: Image = albedo_texture.get_image()
					var readable_image := _prepare_green_mask_image(material_image)
					if readable_image != null:
						_green_mask = readable_image
						return

	# Fallback for imported material variants that do not expose their image.
	# Only attempt to open files that exist, avoiding noisy Image.load errors.
	var candidate_paths: Array[String] = []
	var world_dir := DirAccess.open("res://assets/world")
	if world_dir != null:
		for file_name in world_dir.get_files():
			var lower_name := file_name.to_lower()
			if lower_name.begins_with(GREEN_MASK_FILE_PREFIX.to_lower()) and lower_name.ends_with(".png"):
				candidate_paths.append("res://assets/world/" + file_name)
	# Prefer the most recently generated numbered albedo when stale textures
	# from earlier Blender exports remain in the folder.
	candidate_paths.sort()
	candidate_paths.reverse()
	for candidate_path in candidate_paths:
		if not FileAccess.file_exists(candidate_path):
			continue
		var image := Image.new()
		if image.load(candidate_path) == OK and not image.is_empty():
			var readable_image := _prepare_green_mask_image(image)
			if readable_image != null:
				_green_mask = readable_image
				print("Vegetação: usando máscara do terreno ", candidate_path)
				return

	push_warning("Vegetação: nenhuma textura OW_TerrainAlbedo legível disponível; detalhes ambientais dependentes da máscara serão omitidos.")


func _prepare_green_mask_image(source_image: Image) -> Image:
	# Imported textures can expose a GPU-compressed Image. get_pixel() cannot read
	# those directly, and sampling one inside every generated chunk caused thousands
	# of errors and visible stutters. Decompress and normalize it once at startup.
	if source_image == null or source_image.is_empty():
		return null
	var readable_image: Image = source_image.duplicate()
	if readable_image.is_compressed():
		var decompress_error: Error = readable_image.decompress()
		if decompress_error != OK or readable_image.is_compressed():
			return null
	if readable_image.is_empty() or readable_image.is_compressed():
		return null
	if readable_image.get_format() != Image.FORMAT_RGBA8:
		readable_image.convert(Image.FORMAT_RGBA8)
	return readable_image

func _find_terrain_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and str(node.name).to_lower() == "ow_terrain":
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_terrain_mesh(child)
		if found != null:
			return found
	return null


func _sample_green_mask(point: Vector3) -> bool:
	if _green_mask == null or _green_mask.is_empty() or _green_mask.is_compressed():
		return false
	if _bounds.size.x <= 0.0 or _bounds.size.z <= 0.0:
		return false
	var u := (point.x - _bounds.position.x) / _bounds.size.x
	var v := (point.z - _bounds.position.z) / _bounds.size.z
	if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
		return false
	# x maps left-to-right and z maps top-to-bottom in the exported map albedo.
	var px := clampi(floori(u * float(_green_mask.get_width())), 0, _green_mask.get_width() - 1)
	var py := clampi(floori(v * float(_green_mask.get_height())), 0, _green_mask.get_height() - 1)
	var color := _green_mask.get_pixel(px, py)
	# Green terrain colors have a stronger G channel than R and B. This excludes
	# blue water, tan sand, grey rock, and dark brown road/city marks.
	return color.g > color.r * 1.14 and color.g > color.b * 1.10 and color.g > 0.16


func _is_green_ground(point: Vector3, keep_clearance: bool = true) -> bool:
	if not _sample_green_mask(point):
		return false
	if not keep_clearance:
		return true
	var d := GREEN_MASK_EDGE_CLEARANCE
	# Shared offsets avoid allocating a new Array of Vectors for every grass candidate.
	for unit_offset in GREEN_MASK_CHECK_OFFSETS:
		var offset: Vector3 = unit_offset * d
		if not _sample_green_mask(point + offset):
			return false
	return true


func _filter_trails_to_green_areas() -> void:
	# Older session data may contain marks recorded before the mask existed.
	# Drop these marks so trails cannot persist on sand, rock, roads or water.
	for key_value in _trail_cells.keys():
		if not (key_value is Vector2i):
			_trail_cells.erase(key_value)
			continue
		var cell: Vector2i = key_value
		var data_value: Variant = _trail_cells.get(cell, {})
		if not (data_value is Dictionary):
			_trail_cells.erase(cell)
			continue
		var data: Dictionary = data_value
		var p: Vector3 = data.get("position", Vector3((float(cell.x) + 0.5) * TRAIL_CELL_SIZE, 0.0, (float(cell.y) + 0.5) * TRAIL_CELL_SIZE))
		if not _is_green_ground(p, true):
			_trail_cells.erase(cell)


func _make_materials_and_meshes() -> void:
	_grass_mesh = _make_grass_mesh()
	_flower_mesh = _make_flower_mesh()
	_shrub_mesh = SphereMesh.new()
	_shrub_mesh.radius = 0.34
	_shrub_mesh.height = 0.52
	_shrub_mesh.radial_segments = 6
	_shrub_mesh.rings = 3

	_grass_material = StandardMaterial3D.new()
	_grass_material.albedo_color = Color.WHITE
	_grass_material.vertex_color_use_as_albedo = true
	_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grass_material.roughness = 1.0

	_flower_material = StandardMaterial3D.new()
	_flower_material.albedo_color = Color.WHITE
	_flower_material.vertex_color_use_as_albedo = true
	_flower_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flower_material.roughness = 1.0

	_shrub_material = StandardMaterial3D.new()
	_shrub_material.albedo_color = Color(0.24, 0.38, 0.15, 1.0)
	_shrub_material.roughness = 1.0

	_trail_material = StandardMaterial3D.new()
	_trail_material.albedo_color = Color.WHITE
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_material.roughness = 1.0
	_make_critter_resources()


func _make_critter_resources() -> void:
	_butterfly_mesh = _make_butterfly_mesh()
	var butterfly_shader := Shader.new()
	butterfly_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
void vertex() {
    float phase = INSTANCE_CUSTOM.r * 6.2831853;
    float wing_phase = TIME * 17.0 + INSTANCE_CUSTOM.g * 6.2831853;
    VERTEX.y += UV.x * sin(wing_phase) * 0.075;
    VERTEX.y += sin(TIME * 2.1 + phase) * 0.055;
    VERTEX.x += sin(TIME * 0.72 + phase) * 0.28;
    VERTEX.z += cos(TIME * 0.84 + phase * 1.37) * 0.24;
}
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
}
"""
	_butterfly_material = ShaderMaterial.new()
	_butterfly_material.shader = butterfly_shader

	_firefly_mesh = SphereMesh.new()
	_firefly_mesh.radius = 0.075
	_firefly_mesh.height = 0.15
	_firefly_mesh.radial_segments = 5
	_firefly_mesh.rings = 3
	var firefly_shader := Shader.new()
	firefly_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
varying float firefly_phase;
void vertex() {
    firefly_phase = INSTANCE_CUSTOM.r * 6.2831853;
    VERTEX.y += sin(TIME * 1.45 + firefly_phase) * 0.13;
    VERTEX.x += sin(TIME * 0.64 + firefly_phase * 1.91) * 0.26;
    VERTEX.z += cos(TIME * 0.82 + firefly_phase * 1.31) * 0.24;
}
void fragment() {
    float pulse = 0.28 + 0.72 * pow(0.5 + 0.5 * sin(TIME * 3.2 + firefly_phase), 2.0);
    ALBEDO = vec3(0.72, 1.0, 0.28) * pulse;
    EMISSION = vec3(0.36, 1.0, 0.08) * (0.7 + 2.2 * pulse);
    ROUGHNESS = 1.0;
}
"""
	_firefly_material = ShaderMaterial.new()
	_firefly_material.shader = firefly_shader


func _get_critter_mode() -> String:
	var hours: float = 12.0
	if _world != null:
		var hour_value: Variant = _world.get("time_of_day_hours")
		if hour_value != null:
			hours = float(hour_value)
	return "night" if hours >= CRITTER_NIGHT_START or hours < CRITTER_DAY_START else "day"


func _update_critter_mode() -> void:
	var new_mode: String = _get_critter_mode()
	if new_mode == _critter_mode:
		return
	_critter_mode = new_mode
	for record_value in _chunks.values():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var butterflies: Variant = record.get("butterflies")
		if is_instance_valid(butterflies):
			butterflies.visible = _critter_mode == "day"
		var fireflies: Variant = record.get("fireflies")
		if is_instance_valid(fireflies):
			fireflies.visible = _critter_mode == "night"


func _make_butterfly_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Crossed wing planes keep the tiny butterfly readable from different angles.
	for plane in range(2):
		for side_value in [-1.0, 1.0]:
			var side: float = float(side_value)
			var hinge := _butterfly_point(plane, side * 0.008, 0.075)
			var upper := _butterfly_point(plane, side * 0.095, 0.125)
			var tip := _butterfly_point(plane, side * 0.135, 0.035)
			var lower := _butterfly_point(plane, side * 0.024, 0.018)
			_append_butterfly_triangle(vertices, normals, colors, uvs, indices, hinge, upper, lower, side * 0.10, side * 1.0, side * 0.22, Color.WHITE)
			_append_butterfly_triangle(vertices, normals, colors, uvs, indices, upper, tip, lower, side * 1.0, side * 1.0, side * 0.22, Color.WHITE)
	# A dark, narrow body is visible in both crossed planes.
	for plane in range(2):
		var a := _butterfly_point(plane, -0.006, 0.015)
		var b := _butterfly_point(plane, 0.006, 0.015)
		var c := _butterfly_point(plane, 0.004, 0.135)
		var d := _butterfly_point(plane, -0.004, 0.135)
		var body_color := Color(0.19, 0.13, 0.10, 1.0)
		_append_butterfly_triangle(vertices, normals, colors, uvs, indices, a, b, c, 0.0, 0.0, 0.0, body_color)
		_append_butterfly_triangle(vertices, normals, colors, uvs, indices, a, c, d, 0.0, 0.0, 0.0, body_color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _butterfly_point(plane: int, lateral: float, height: float) -> Vector3:
	return Vector3(lateral, height, 0.0) if plane == 0 else Vector3(0.0, height, lateral)


func _append_butterfly_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, ua: float, ub: float, uc: float, vertex_color: Color) -> void:
	var start: int = vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colors.append(vertex_color)
	colors.append(vertex_color)
	colors.append(vertex_color)
	uvs.append(Vector2(ua, 0.5))
	uvs.append(Vector2(ub, 0.5))
	uvs.append(Vector2(uc, 0.5))
	indices.append(start)
	indices.append(start + 1)
	indices.append(start + 2)


func _make_animated_multimesh(mesh: Mesh, material: Material, positions: Array[Vector3], colors: Array[Color], scales: Array[Vector3], rotations: Array[float], custom_data: Array[Color], instance_name: String, parent: Node3D) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = positions.size()
	for i in range(positions.size()):
		var yaw: float = rotations[i] if i < rotations.size() else 0.0
		var scale: Vector3 = scales[i] if i < scales.size() else Vector3.ONE
		var basis := Basis(Vector3.UP, yaw).scaled(scale)
		multi.set_instance_transform(i, Transform3D(basis, positions[i]))
		multi.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
		multi.set_instance_custom_data(i, custom_data[i] if i < custom_data.size() else Color(0.0, 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = instance_name
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _make_grass_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Six overlapping low-poly blades form one compact tuft.
	for blade in range(6):
		var angle := TAU * float(blade) / 6.0
		var right := Vector3(cos(angle), 0.0, sin(angle))
		var center := Vector3(cos(angle) * 0.055, 0.0, sin(angle) * 0.055)
		var width := 0.075 if blade % 2 == 0 else 0.06
		var height := 0.36 + float((blade * 7) % 5) * 0.075
		var a := center - right * width
		var b := center + right * width
		var tip := center + Vector3(sin(angle) * 0.09, height, cos(angle) * 0.09)
		_append_triangle(vertices, normals, colors, indices, a, b, tip, Color.WHITE, Color.WHITE, Color.WHITE)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_flower_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var stem_color := Color(0.27, 0.43, 0.16, 1.0)
	var petal_color := Color(0.96, 0.83, 0.49, 1.0)
	var center_color := Color(0.48, 0.31, 0.10, 1.0)
	# Thin crossed stems so the little flower remains visible from different angles.
	for stem in range(3):
		var angle := PI * float(stem) / 3.0
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.018
		var base := Vector3.ZERO
		var top := Vector3(sin(angle) * 0.02, 0.28 + float(stem % 2) * 0.04, cos(angle) * 0.02)
		_append_triangle(vertices, normals, colors, indices, base - side, base + side, top, stem_color, stem_color, stem_color)
	# Four small petals and one warm center at the top of the stems.
	var flower_center := Vector3(0.0, 0.34, 0.0)
	for petal in range(4):
		var angle2 := TAU * float(petal) / 4.0
		var radial := Vector3(cos(angle2), 0.0, sin(angle2))
		var tangent := Vector3(-radial.z, 0.0, radial.x) * 0.032
		var outer := flower_center + radial * 0.075
		_append_triangle(vertices, normals, colors, indices, flower_center - tangent, flower_center + tangent, outer, petal_color, petal_color, petal_color)
	var c := flower_center + Vector3(0.0, 0.008, 0.0)
	_append_triangle(vertices, normals, colors, indices, c + Vector3(-0.022, 0.0, -0.022), c + Vector3(0.022, 0.0, -0.022), c + Vector3(0.0, 0.0, 0.025), center_color, center_color, center_color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var start := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colors.append(ca)
	colors.append(cb)
	colors.append(cc)
	indices.append(start)
	indices.append(start + 1)
	indices.append(start + 2)


func _build_structure_index() -> void:
	_structure_bins.clear()
	if _world == null:
		return
	var map_root: Node = _world.get("_map")
	if map_root == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(map_root, meshes)
	for mi in meshes:
		var n := str(mi.name).to_lower()
		if not (n.contains("building") or n.contains("landmark") or n.contains("poi")):
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		box.position.x -= 2.8
		box.position.z -= 2.8
		box.size.x += 5.6
		box.size.z += 5.6
		var min_x := floori(box.position.x / CHUNK_SIZE)
		var max_x := floori(box.end.x / CHUNK_SIZE)
		var min_z := floori(box.position.z / CHUNK_SIZE)
		var max_z := floori(box.end.z / CHUNK_SIZE)
		for cx in range(min_x, max_x + 1):
			for cz in range(min_z, max_z + 1):
				var bin_key := Vector2i(cx, cz)
				var bin: Array = _structure_bins.get(bin_key, [])
				bin.append(box)
				_structure_bins[bin_key] = bin


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		_collect_meshes(child, out)


func _update_chunk_streaming(delta: float, player_position: Vector3) -> void:
	_chunk_refresh_timer += delta
	if _chunk_refresh_timer >= CHUNK_REFRESH_INTERVAL:
		_chunk_refresh_timer = 0.0
		_refresh_chunk_set(player_position)
	if not _generation_running and not _pending_chunks.is_empty():
		_start_next_chunk_generation()


func _refresh_chunk_set(player_position: Vector3) -> void:
	var min_x := floori((player_position.x - LOAD_RADIUS) / CHUNK_SIZE)
	var max_x := floori((player_position.x + LOAD_RADIUS) / CHUNK_SIZE)
	var min_z := floori((player_position.z - LOAD_RADIUS) / CHUNK_SIZE)
	var max_z := floori((player_position.z + LOAD_RADIUS) / CHUNK_SIZE)
	for cx in range(min_x, max_x + 1):
		for cz in range(min_z, max_z + 1):
			var key := Vector2i(cx, cz)
			if _chunk_distance(player_position, key) > LOAD_RADIUS:
				continue
			if not _inside_world_chunk(key):
				continue
			_ensure_chunk_record(key)
			var record: Dictionary = _chunks[key]
			if not bool(record.get("generated", false)) and not _pending_chunks.has(key) and not (_generation_running and key == _generating_chunk):
				_pending_chunks.append(key)

	for key_value in _chunks.keys():
		var key: Vector2i = key_value
		if _generation_running and key == _generating_chunk:
			continue
		if _chunk_distance(player_position, key) <= UNLOAD_RADIUS:
			continue
		var record: Dictionary = _chunks[key]
		var node: Node3D = record.get("node")	
		if is_instance_valid(node):
			node.queue_free()
		_chunks.erase(key)
	
	var kept: Array[Vector2i] = []
	for key in _pending_chunks:
		if _chunks.has(key):
			kept.append(key)
	_pending_chunks = kept
	_pending_chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_distance(player_position, a) < _chunk_distance(player_position, b)
	)


func _inside_world_chunk(key: Vector2i) -> bool:
	var x0 := float(key.x) * CHUNK_SIZE
	var z0 := float(key.y) * CHUNK_SIZE
	return x0 < _bounds.end.x and x0 + CHUNK_SIZE > _bounds.position.x and z0 < _bounds.end.z and z0 + CHUNK_SIZE > _bounds.position.z


func _chunk_for_position(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK_SIZE), floori(p.z / CHUNK_SIZE))


func _chunk_distance(p: Vector3, key: Vector2i) -> float:
	var x0 := float(key.x) * CHUNK_SIZE
	var z0 := float(key.y) * CHUNK_SIZE
	var cx := clampf(p.x, x0, x0 + CHUNK_SIZE)
	var cz := clampf(p.z, z0, z0 + CHUNK_SIZE)
	return Vector2(p.x - cx, p.z - cz).length()


func _ensure_chunk_record(key: Vector2i) -> void:
	if _chunks.has(key):
		return
	var node := Node3D.new()
	node.name = "EnvironmentChunk_%d_%d" % [key.x, key.y]
	node.position = Vector3(float(key.x) * CHUNK_SIZE, 0.0, float(key.y) * CHUNK_SIZE)
	add_child(node)
	_chunks[key] = {
		"node": node,
		"generated": false,
		"grass_mm": null,
		"grass_cells": [],
		"grass_transforms": [],
		"hidden_grass": {},
		"trail_mesh": null,
		"trail_dirty": true
	}


func _start_next_chunk_generation() -> void:
	while not _pending_chunks.is_empty():
		var key: Vector2i = _pending_chunks.pop_front()
		if not _chunks.has(key):
			continue
		var record: Dictionary = _chunks[key]
		if bool(record.get("generated", false)):
			continue
		_generation_running = true
		_generating_chunk = key
		_generate_chunk_async(key)
		return


func _generate_chunk_async(key: Vector2i) -> void:
	var record: Dictionary = _chunks.get(key, {})
	if record.is_empty():
		_finish_generation(key)
		return
	var node: Node3D = record.get("node")
	if not is_instance_valid(node):
		_finish_generation(key)
		return
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = abs(key.x * 73856093 + key.y * 19349663 + 83492791) + 1
	var grass_positions: Array[Vector3] = []
	var grass_colors: Array[Color] = []
	var grass_cells: Array[Vector2i] = []
	var grass_scales: Array[Vector3] = []
	var grass_rotations: Array[float] = []
	var grass_transforms: Array[Transform3D] = []
	var flower_positions: Array[Vector3] = []
	var flower_colors: Array[Color] = []
	var flower_scales: Array[Vector3] = []
	var shrub_positions: Array[Vector3] = []
	var shrub_scales: Array[Vector3] = []
	var shrub_rotations: Array[float] = []
	var butterfly_positions: Array[Vector3] = []
	var butterfly_colors: Array[Color] = []
	var butterfly_scales: Array[Vector3] = []
	var butterfly_rotations: Array[float] = []
	var butterfly_custom_data: Array[Color] = []
	# Butterflies and fireflies live in small habitat colonies, not across every
	# green terrain cell. Each chunk gets zero or one preferred patch per species.
	var butterfly_colony_enabled: bool = _rng.randf() < 0.28
	var butterfly_colony_center := Vector2(
		float(key.x) * CHUNK_SIZE + _rng.randf_range(7.0, CHUNK_SIZE - 7.0),
		float(key.y) * CHUNK_SIZE + _rng.randf_range(7.0, CHUNK_SIZE - 7.0)
	)
	var firefly_colony_enabled: bool = _rng.randf() < 0.32
	var firefly_colony_center := Vector2(
		float(key.x) * CHUNK_SIZE + _rng.randf_range(7.0, CHUNK_SIZE - 7.0),
		float(key.y) * CHUNK_SIZE + _rng.randf_range(7.0, CHUNK_SIZE - 7.0)
	)
	var butterfly_patch_radius: float = _rng.randf_range(4.5, 8.0)
	var firefly_patch_radius: float = _rng.randf_range(5.0, 9.0)
	var firefly_positions: Array[Vector3] = []
	var firefly_colors: Array[Color] = []
	var firefly_scales: Array[Vector3] = []
	var firefly_rotations: Array[float] = []
	var firefly_custom_data: Array[Color] = []
	var step := CHUNK_SIZE / float(GRID_RESOLUTION)
	for ix in range(GRID_RESOLUTION):
		for iz in range(GRID_RESOLUTION):
			var candidate_index := ix * GRID_RESOLUTION + iz
			# Consultas físicas para amostrar o terreno podem ser caras em zonas
			# urbanas. Pequenos lotes produzem mais frames de geração, mas evitam
			# engasgos longos quando um novo bloco de vegetação é carregado.
			if candidate_index > 0 and candidate_index % 4 == 0:
				await get_tree().process_frame
				if not is_inside_tree():
					_finish_generation(key)
					return
			if not is_inside_tree() or not _chunks.has(key):
				_finish_generation(key)
				return
			var wx := float(key.x) * CHUNK_SIZE + (float(ix) + local_rng.randf_range(0.18, 0.82)) * step
			var wz := float(key.y) * CHUNK_SIZE + (float(iz) + local_rng.randf_range(0.18, 0.82)) * step
			var point := Vector3(wx, 0.0, wz)
			if wx < _bounds.position.x + 2.0 or wx > _bounds.end.x - 2.0 or wz < _bounds.position.z + 2.0 or wz > _bounds.end.z - 2.0:
				continue
			if _near_settlement(point, 17.0) or _inside_structure(point):
				continue
			var hit_value: Variant = _world.call("_ground_hit", point)
			if not (hit_value is Dictionary):
				continue
			var hit: Dictionary = hit_value
			if hit.is_empty():
				continue
			var ground: Vector3 = hit.get("position", Vector3.ZERO)
			var normal: Vector3 = hit.get("normal", Vector3.UP)
			if ground.y <= _sea_level + 0.8 or normal.y < 0.66:
				continue
			# Vegetation is only allowed on green pixels of the terrain albedo mask.
			# The same test also excludes the brown roads/settlement marks painted on it.
			if not _is_green_ground(ground, true):
				continue
			# Ambient fauna occupies localized habitat patches. Empty chunks are
			# normal; occupied patches are clustered and remain on valid grassy ground.
			var ground_xz := Vector2(ground.x, ground.z)
			if butterfly_colony_enabled and ground_xz.distance_to(butterfly_colony_center) <= butterfly_patch_radius and local_rng.randf() < 0.34:
				butterfly_positions.append(Vector3(ground.x - node.position.x, ground.y - node.position.y + local_rng.randf_range(0.42, 1.45), ground.z - node.position.z))
				var butterfly_tint: Color = BUTTERFLY_TINTS[local_rng.randi_range(0, BUTTERFLY_TINTS.size() - 1)]
				butterfly_colors.append(butterfly_tint)
				butterfly_scales.append(Vector3.ONE * local_rng.randf_range(0.72, 1.18))
				butterfly_rotations.append(local_rng.randf_range(0.0, TAU))
				butterfly_custom_data.append(Color(local_rng.randf(), local_rng.randf(), 0.0, 0.0))
			if firefly_colony_enabled and ground_xz.distance_to(firefly_colony_center) <= firefly_patch_radius and local_rng.randf() < 0.40:
				firefly_positions.append(Vector3(ground.x - node.position.x, ground.y - node.position.y + local_rng.randf_range(0.35, 1.65), ground.z - node.position.z))
				firefly_colors.append(Color.WHITE)
				firefly_scales.append(Vector3.ONE * local_rng.randf_range(0.72, 1.25))
				firefly_rotations.append(0.0)
				firefly_custom_data.append(Color(local_rng.randf(), local_rng.randf(), 0.0, 0.0))
			var trail_cell := _trail_cell_for_position(ground)
			if _trail_density(trail_cell) >= TRAIL_VISIBLE_AT:
				continue
			var roll := local_rng.randf()
			if roll < 0.66:
				var scale := local_rng.randf_range(0.75, 1.28)
				var yaw := local_rng.randf_range(0.0, TAU)
				var local_pos := Vector3(ground.x - node.position.x, ground.y - node.position.y + 0.018, ground.z - node.position.z)
				grass_positions.append(local_pos)
				grass_colors.append(GRASS_TINTS[local_rng.randi_range(0, GRASS_TINTS.size() - 1)])
				grass_cells.append(trail_cell)
				grass_scales.append(Vector3.ONE * scale)
				grass_rotations.append(yaw)
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
				grass_transforms.append(Transform3D(basis, local_pos))
			elif roll < 0.745:
				flower_positions.append(Vector3(ground.x - node.position.x, ground.y - node.position.y + 0.015, ground.z - node.position.z))
				flower_colors.append(Color(1.0, local_rng.randf_range(0.86, 1.0), local_rng.randf_range(0.64, 0.94), 1.0))
				flower_scales.append(Vector3.ONE * local_rng.randf_range(0.75, 1.20))
			elif roll < 0.77 and normal.y > 0.78:
				shrub_positions.append(Vector3(ground.x - node.position.x, ground.y - node.position.y + 0.20, ground.z - node.position.z))
				shrub_scales.append(Vector3(local_rng.randf_range(0.75, 1.35), local_rng.randf_range(0.70, 1.12), local_rng.randf_range(0.75, 1.30)))
				shrub_rotations.append(local_rng.randf_range(0.0, TAU))

	if not _chunks.has(key):
		_finish_generation(key)
		return
	record = _chunks[key]
	record["grass_cells"] = grass_cells
	record["grass_transforms"] = grass_transforms
	record["hidden_grass"] = {}
	if not grass_positions.is_empty():
		await get_tree().process_frame
		if not is_inside_tree() or not _chunks.has(key):
			_finish_generation(key)
			return
		var grass_instance := _make_multimesh_instance(_grass_mesh, _grass_material, grass_positions, grass_colors, grass_scales, grass_rotations, "GrassTufts", node)
		record["grass_mm"] = grass_instance.multimesh
		for i in range(grass_transforms.size()):
			if _trail_density(grass_cells[i]) >= TRAIL_VISIBLE_AT:
				_hide_grass_instance(record, i)
	if not flower_positions.is_empty():
		await get_tree().process_frame
		if not is_inside_tree() or not _chunks.has(key):
			_finish_generation(key)
			return
		_make_multimesh_instance(_flower_mesh, _flower_material, flower_positions, flower_colors, flower_scales, _make_zero_rotations(flower_positions.size()), "Wildflowers", node)
	if not shrub_positions.is_empty():
		await get_tree().process_frame
		if not is_inside_tree() or not _chunks.has(key):
			_finish_generation(key)
			return
		_make_shrub_multimesh(shrub_positions, shrub_scales, shrub_rotations, node)
	var butterfly_instance: MultiMeshInstance3D = null
	if not butterfly_positions.is_empty():
		await get_tree().process_frame
		if not is_inside_tree() or not _chunks.has(key):
			_finish_generation(key)
			return
		butterfly_instance = _make_animated_multimesh(_butterfly_mesh, _butterfly_material, butterfly_positions, butterfly_colors, butterfly_scales, butterfly_rotations, butterfly_custom_data, "DaytimeButterflies", node)
		butterfly_instance.visible = _critter_mode == "day"
	var firefly_instance: MultiMeshInstance3D = null
	if not firefly_positions.is_empty():
		await get_tree().process_frame
		if not is_inside_tree() or not _chunks.has(key):
			_finish_generation(key)
			return
		firefly_instance = _make_animated_multimesh(_firefly_mesh, _firefly_material, firefly_positions, firefly_colors, firefly_scales, firefly_rotations, firefly_custom_data, "NighttimeFireflies", node)
		firefly_instance.visible = _critter_mode == "night"
	record["butterflies"] = butterfly_instance
	record["fireflies"] = firefly_instance
	record["generated"] = true
	record["trail_dirty"] = true
	_chunks[key] = record
	_rebuild_trail_mesh(key)
	_finish_generation(key)


func _make_zero_rotations(count: int) -> Array[float]:
	var values: Array[float] = []
	for _i in count:
		values.append(0.0)
	return values


func _make_uniform_scales(count: int, value: float) -> Array[Vector3]:
	var values: Array[Vector3] = []
	for _i in count:
		values.append(Vector3.ONE * value)
	return values


func _make_multimesh_instance(mesh: Mesh, material: Material, positions: Array[Vector3], colors: Array[Color], scales: Array[Vector3], rotations: Array[float], instance_name: String, parent: Node3D) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = positions.size()
	for i in range(positions.size()):
		var yaw := rotations[i] if i < rotations.size() else 0.0
		var scale := scales[i] if i < scales.size() else Vector3.ONE
		var basis := Basis(Vector3.UP, yaw).scaled(scale)
		multi.set_instance_transform(i, Transform3D(basis, positions[i]))
		multi.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var instance := MultiMeshInstance3D.new()
	instance.name = instance_name
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _make_shrub_multimesh(positions: Array[Vector3], scales: Array[Vector3], rotations: Array[float], parent: Node3D) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _shrub_mesh
	multi.instance_count = positions.size()
	for i in range(positions.size()):
		var basis := Basis(Vector3.UP, rotations[i]).scaled(scales[i])
		multi.set_instance_transform(i, Transform3D(basis, positions[i]))
	var instance := MultiMeshInstance3D.new()
	instance.name = "LowShrubs"
	instance.multimesh = multi
	instance.material_override = _shrub_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _finish_generation(key: Vector2i) -> void:
	_generation_running = false
	_generating_chunk = INVALID_CHUNK
	if _chunks.has(key):
		var record: Dictionary = _chunks[key]
		if not bool(record.get("generated", false)):
			record["generated"] = true
			_chunks[key] = record


func _inside_structure(p: Vector3) -> bool:
	var key := _chunk_for_position(p)
	var boxes: Array = _structure_bins.get(key, [])
	for value in boxes:
		var box: AABB = value
		if p.x >= box.position.x and p.x <= box.end.x and p.z >= box.position.z and p.z <= box.end.z:
			return true
	return false


func _near_settlement(p: Vector3, radius: float) -> bool:
	var radius_squared := radius * radius
	for settlement_value in _settlements:
		if not (settlement_value is Dictionary):
			continue
		var settlement: Dictionary = settlement_value
		var center: Vector3 = settlement.get("pos", Vector3.ZERO)
		var dx := p.x - center.x
		var dz := p.z - center.z
		if dx * dx + dz * dz < radius_squared:
			return true
	return false


func _record_actor_motion(actor_key: String, position: Vector3) -> void:
	if not _last_actor_positions.has(actor_key):
		_last_actor_positions[actor_key] = position
		return
	var previous: Vector3 = _last_actor_positions[actor_key]
	_last_actor_positions[actor_key] = position
	var horizontal_distance := Vector2(position.x - previous.x, position.z - previous.z).length()
	if horizontal_distance < 0.15 or horizontal_distance > 9.0:
		return
	var direction := Vector3(position.x - previous.x, 0.0, position.z - previous.z).normalized()
	var steps := maxi(1, ceili(horizontal_distance / 0.42))
	for step_index in range(steps + 1):
		var ratio := float(step_index) / float(steps)
		var sample := previous.lerp(position, ratio)
		_stamp_traffic_sample(actor_key, sample, direction)


func _stamp_traffic_sample(actor_key: String, position: Vector3, direction: Vector3) -> void:
	var cell := _trail_cell_for_position(position)
	var recent: Dictionary = _recent_cells_by_actor.get(actor_key, {})
	_add_traffic_to_cell(cell, position.y, direction, 1.0, recent)
	var lateral := Vector2(-direction.z, direction.x)
	var side := Vector2i(roundi(lateral.x), roundi(lateral.y))
	if side == Vector2i.ZERO:
		side = Vector2i(0, 1)
	_add_traffic_to_cell(cell + side, position.y, direction, 0.26, recent)
	_add_traffic_to_cell(cell - side, position.y, direction, 0.26, recent)
	_recent_cells_by_actor[actor_key] = recent


func _add_traffic_to_cell(cell: Vector2i, approximate_y: float, direction: Vector3, weight: float, recent: Dictionary) -> void:
	var last_visit := float(recent.get(cell, -10000.0))
	if _elapsed - last_visit < ACTOR_CELL_COOLDOWN:
		return
	recent[cell] = _elapsed
	var data: Dictionary = _trail_cells.get(cell, {})
	var is_new_cell := data.is_empty()
	var old_weight := float(data.get("weight", 0.0))
	var old_band := _trail_band(old_weight)
	var ground_x := (float(cell.x) + 0.5) * TRAIL_CELL_SIZE
	var ground_z := (float(cell.y) + 0.5) * TRAIL_CELL_SIZE
	var mask_point := Vector3(ground_x, approximate_y, ground_z)
	if not _is_green_ground(mask_point, true):
		return
	if data.is_empty():
		var ground_hit_value: Variant = _world.call("_ground_hit", mask_point)
		if not (ground_hit_value is Dictionary):
			return
		var ground_hit: Dictionary = ground_hit_value
		if ground_hit.is_empty():
			return
		var ground: Vector3 = ground_hit.get("position", Vector3.ZERO)
		var normal: Vector3 = ground_hit.get("normal", Vector3.UP)
		if ground.y <= _sea_level + 0.7 or normal.y < 0.50:
			return
		data = {"weight": 0.0, "position": ground, "normal": normal, "direction": direction}
	data["weight"] = old_weight + weight
	if is_new_cell:
		var chunk_key := _chunk_for_cell(cell)
		var chunk_cells: Array = _trail_chunk_cells.get(chunk_key, [])
		if not chunk_cells.has(cell):
			chunk_cells.append(cell)
		_trail_chunk_cells[chunk_key] = chunk_cells
	var previous_direction: Vector3 = data.get("direction", direction)
	if direction.length_squared() > 0.001:
		data["direction"] = direction
	_trail_cells[cell] = data
	_state_dirty = true
	var new_band := _trail_band(float(data["weight"]))
	if old_band != new_band:
		_mark_trail_chunk_dirty(_chunk_for_cell(cell))
		if old_band == 0 and new_band > 0:
			_suppress_grass_near_cell(cell)
	elif new_band > 0 and previous_direction.length_squared() > 0.001 and direction.length_squared() > 0.001 and previous_direction.normalized().dot(direction.normalized()) < 0.62:
		_mark_trail_chunk_dirty(_chunk_for_cell(cell))


func _trail_band(weight: float) -> int:
	if weight < TRAIL_VISIBLE_AT:
		return 0
	if weight < 4.5:
		return 1
	if weight < 7.0:
		return 2
	return 3


func _trail_cell_for_position(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / TRAIL_CELL_SIZE), floori(position.z / TRAIL_CELL_SIZE))


func _chunk_for_cell(cell: Vector2i) -> Vector2i:
	var wx := (float(cell.x) + 0.5) * TRAIL_CELL_SIZE
	var wz := (float(cell.y) + 0.5) * TRAIL_CELL_SIZE
	return Vector2i(floori(wx / CHUNK_SIZE), floori(wz / CHUNK_SIZE))


func _trail_density(cell: Vector2i) -> float:
	var data: Dictionary = _trail_cells.get(cell, {})
	return float(data.get("weight", 0.0))


func _rebuild_trail_index() -> void:
	_trail_chunk_cells.clear()
	for cell_value in _trail_cells.keys():
		if not (cell_value is Vector2i):
			continue
		var cell: Vector2i = cell_value
		var chunk_key := _chunk_for_cell(cell)
		var cells: Array = _trail_chunk_cells.get(chunk_key, [])
		cells.append(cell)
		_trail_chunk_cells[chunk_key] = cells


func _mark_trail_chunk_dirty(chunk_key: Vector2i) -> void:
	if not _chunks.has(chunk_key):
		return
	var record: Dictionary = _chunks[chunk_key]
	record["trail_dirty"] = true
	_chunks[chunk_key] = record


func _suppress_grass_near_cell(cell: Vector2i) -> void:
	# Once a well-used track forms, remove nearby grass instances, rather than only darkening the ground.
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var target_cell := cell + Vector2i(dx, dz)
			var key := _chunk_for_cell(target_cell)
			if not _chunks.has(key):
				continue
			var record: Dictionary = _chunks[key]
			if record.get("grass_mm") == null:
				continue
			var cells: Array = record.get("grass_cells", [])
			for i in range(cells.size()):
				if cells[i] == target_cell:
					_hide_grass_instance(record, i)
			_chunks[key] = record


func _hide_grass_instance(record: Dictionary, index: int) -> void:
	var hidden: Dictionary = record.get("hidden_grass", {})
	if hidden.has(index):
		return
	var grass_mm: MultiMesh = record.get("grass_mm")
	var transforms: Array = record.get("grass_transforms", [])
	if grass_mm == null or index < 0 or index >= transforms.size():
		return
	var original: Transform3D = transforms[index]
	var small_basis := original.basis.scaled(Vector3(0.001, 0.001, 0.001))
	grass_mm.set_instance_transform(index, Transform3D(small_basis, original.origin))
	hidden[index] = true
	record["hidden_grass"] = hidden


func _rebuild_one_dirty_trail() -> void:
	for key_value in _chunks.keys():
		var key: Vector2i = key_value
		var record: Dictionary = _chunks[key]
		if not bool(record.get("generated", false)) or not bool(record.get("trail_dirty", false)):
			continue
		_rebuild_trail_mesh(key)
		return


func _rebuild_trail_mesh(chunk_key: Vector2i) -> void:
	if not _chunks.has(chunk_key):
		return
	var record: Dictionary = _chunks[chunk_key]
	var node: Node3D = record.get("node")
	if not is_instance_valid(node):
		return
	var trail_cells: Array = _trail_chunk_cells.get(chunk_key, [])
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var origin := node.position
	for cell_value in trail_cells:
		var cell: Vector2i = cell_value
		var data: Dictionary = _trail_cells.get(cell, {})
		var weight := float(data.get("weight", 0.0))
		if weight < TRAIL_VISIBLE_AT:
			continue
		var center: Vector3 = data.get("position", Vector3.ZERO)
		var normal: Vector3 = data.get("normal", Vector3.UP).normalized()
		var direction: Vector3 = data.get("direction", Vector3.FORWARD)
		direction.y = 0.0
		if direction.length_squared() < 0.001:
			direction = Vector3.FORWARD
		direction = (direction - normal * direction.dot(normal)).normalized()
		if direction.length_squared() < 0.001:
			direction = Vector3.RIGHT
		var side := normal.cross(direction).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.FORWARD
		var alpha := clampf(0.17 + (weight - TRAIL_VISIBLE_AT) * 0.075, 0.17, 0.58)
		var base_color := Color(0.43, 0.39, 0.26, alpha)
		# Irregular, elongated patches resemble grass pressed flat, gradually exposing soil.
		var angle_offset := float(abs(cell.x * 31 + cell.y * 17) % 100) / 100.0 * 0.55
		var points: Array[Vector3] = []
		for i in range(8):
			var angle := TAU * float(i) / 8.0 + angle_offset
			var jitter := 0.90 + float(abs(cell.x * (i + 7) + cell.y * (i + 3)) % 23) / 100.0
			var p := center + direction * (cos(angle) * 0.58 * jitter) + side * (sin(angle) * 0.43 * jitter)
			p += normal * 0.028
			points.append(p - origin)
		var local_center := center + normal * 0.03 - origin
		for i in range(8):
			var next := (i + 1) % 8
			var start := vertices.size()
			vertices.append(local_center)
			vertices.append(points[i])
			vertices.append(points[next])
			normals.append(normal)
			normals.append(normal)
			normals.append(normal)
			colors.append(base_color)
			colors.append(Color(base_color.r, base_color.g, base_color.b, alpha * 0.68))
			colors.append(Color(base_color.r, base_color.g, base_color.b, alpha * 0.68))
			indices.append(start)
			indices.append(start + 1)
			indices.append(start + 2)
	var existing: MeshInstance3D = record.get("trail_mesh")
	if vertices.is_empty():
		if is_instance_valid(existing):
			existing.mesh = null
		record["trail_dirty"] = false
		_chunks[chunk_key] = record
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not is_instance_valid(existing):
		existing = MeshInstance3D.new()
		existing.name = "WornGrassTrail"
		existing.material_override = _trail_material
		existing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(existing)
	existing.mesh = mesh
	record["trail_mesh"] = existing
	record["trail_dirty"] = false
	_chunks[chunk_key] = record


func _exit_tree() -> void:
	if _game != null and is_instance_valid(_game):
		_game.set("foot_traffic_session_state", _trail_cells.duplicate(true))

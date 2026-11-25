extends Node3D
# Golpe de relâmpago instantâneo: raio ramificado, brilho curto e dano por raycast.
# Os ramos são visuais; somente o eixo principal determina quem recebe dano.

var source_player: Node3D = null
var direction: Vector3 = Vector3.FORWARD
var max_range: float = 18.0
var damage: int = 12
var color: Color = Color(0.55, 0.85, 1.0, 1.0)
var proficiency_rank: int = 0
var _bolt_material: StandardMaterial3D
var _bolt_color := Color(0.75, 0.92, 1.0, 1.0)


func strike(caster: Node3D, origin: Vector3, aim_direction: Vector3, reach: float, damage_value: int, spell_color: Color, rank: int) -> void:
	source_player = caster
	direction = aim_direction.normalized()
	max_range = maxf(1.0, reach)
	damage = maxi(1, damage_value)
	color = spell_color
	proficiency_rank = clampi(rank, 0, 4)
	global_position = origin
	_resolve_hit_and_build()


func _resolve_hit_and_build() -> void:
	if direction.length_squared() < 0.001:
		queue_free()
		return
	var start: Vector3 = global_position
	var end: Vector3 = start + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if is_instance_valid(source_player) and source_player is CollisionObject3D:
		query.exclude = [source_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.get("position", end)
		var collider: Object = hit.get("collider")
		if collider is Node3D and collider.is_in_group("enemies") and collider.has_method("take_hit"):
			var push_dir := Vector3(direction.x, 0.0, direction.z)
			if push_dir.length_squared() > 0.001:
				push_dir = push_dir.normalized()
			collider.call("take_hit", damage, push_dir)

	# Use material próprio para cada golpe, para que o fade não afete outras magias.
	_bolt_color = Color(0.84, 0.96, 1.0, 1.0).lerp(color, 0.18)
	_bolt_material = StandardMaterial3D.new()
	_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_material.albedo_color = _bolt_color
	_bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_material.emission_enabled = true
	_bolt_material.emission = Color(0.48, 0.82, 1.0, 1.0).lerp(color, 0.28)
	_bolt_material.emission_energy_multiplier = 4.5 + float(proficiency_rank) * 0.8
	_bolt_material.roughness = 0.1

	var local_end: Vector3 = to_local(end)
	var bolt_length: float = local_end.length()
	var segments: int = clampi(int(ceil(bolt_length / 0.52)), 6, 30)
	var main_points: Array[Vector3] = _make_jagged_points(Vector3.ZERO, local_end, segments, 0.34)
	_render_polyline(main_points, 0.042 + float(proficiency_rank) * 0.004, true)

	# Ramificações laterais irregulares aumentam com a proficiência da magia.
	var branch_count: int = 3 + proficiency_rank
	if main_points.size() >= 7:
		for branch_i in range(branch_count):
			var start_index: int = randi_range(2, main_points.size() - 3)
			var branch_start: Vector3 = main_points[start_index]
			var tangent: Vector3 = (main_points[start_index + 1] - main_points[start_index - 1]).normalized()
			var side := tangent.cross(Vector3.UP)
			if side.length_squared() < 0.01:
				side = tangent.cross(Vector3.RIGHT)
			side = side.normalized()
			if randf() < 0.5:
				side = -side
			var vertical_sign: float = -1.0 if randf() < 0.55 else 1.0
			var branch_length: float = randf_range(0.55, 1.45) * (1.0 + float(proficiency_rank) * 0.08)
			var branch_dir := (side * randf_range(0.5, 1.0) + Vector3.UP * vertical_sign * randf_range(0.15, 0.7) + tangent * 0.25).normalized()
			var branch_end: Vector3 = branch_start + branch_dir * branch_length
			var branch_segments: int = randi_range(3, 5)
			var branch_points: Array[Vector3] = _make_jagged_points(branch_start, branch_end, branch_segments, 0.16)
			_render_polyline(branch_points, 0.019 + float(proficiency_rank) * 0.002, false)

	_add_impact_flash(local_end)
	var lifetime := 0.14
	var fade := create_tween()
	fade.tween_property(_bolt_material, "emission_energy_multiplier", 0.0, lifetime)
	fade.parallel().tween_property(_bolt_material, "albedo_color", Color(_bolt_color.r, _bolt_color.g, _bolt_color.b, 0.0), lifetime)
	fade.tween_callback(queue_free)


func _make_jagged_points(start_pos: Vector3, end_pos: Vector3, segment_count: int, jitter: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var delta: Vector3 = end_pos - start_pos
	var dir: Vector3 = delta.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	points.append(start_pos)
	for index in range(1, segment_count):
		var t: float = float(index) / float(segment_count)
		# Deslocamento cresce no meio e termina exatamente no ponto de impacto.
		var envelope: float = minf(1.0, minf(t * 3.0, (1.0 - t) * 3.0))
		var offset: Vector3 = side * randf_range(-jitter, jitter) + up * randf_range(-jitter * 0.75, jitter * 0.75)
		points.append(start_pos + delta * t + offset * envelope)
	points.append(end_pos)
	return points


func _render_polyline(points: Array[Vector3], radius: float, add_joints: bool) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var delta: Vector3 = b - a
		var length: float = delta.length()
		if length < 0.005:
			continue
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius * 0.72
		cylinder.bottom_radius = radius
		cylinder.height = length + radius * 0.45
		cylinder.radial_segments = 5
		var segment := MeshInstance3D.new()
		segment.mesh = cylinder
		segment.material_override = _bolt_material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.position = (a + b) * 0.5
		segment.quaternion = Quaternion(Vector3.UP, delta.normalized())
		add_child(segment)
	if add_joints:
		for i in range(1, points.size() - 1):
			if i % 2 != 0:
				continue
			var joint_mesh := SphereMesh.new()
			joint_mesh.radius = radius * 0.95
			joint_mesh.height = radius * 1.9
			joint_mesh.radial_segments = 5
			joint_mesh.rings = 3
			var joint := MeshInstance3D.new()
			joint.mesh = joint_mesh
			joint.material_override = _bolt_material
			joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			joint.position = points[i]
			add_child(joint)


func _add_impact_flash(local_end: Vector3) -> void:
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.12 + float(proficiency_rank) * 0.015
	flash_mesh.height = flash_mesh.radius * 2.0
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	var flash := MeshInstance3D.new()
	flash.mesh = flash_mesh
	flash.material_override = _bolt_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = local_end
	add_child(flash)

	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.82, 1.0)
	light.light_energy = 2.8 + float(proficiency_rank) * 0.35
	light.omni_range = 3.2 + float(proficiency_rank) * 0.35
	light.shadow_enabled = false
	light.position = local_end
	add_child(light)
	var light_fade := create_tween()
	light_fade.tween_property(light, "light_energy", 0.0, 0.11)

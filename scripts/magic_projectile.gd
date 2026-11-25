extends Node3D
# Projétil mágico lançado na direção da câmera. Não precisa selecionar/travar um alvo.

var source_player: Node3D = null
var direction: Vector3 = Vector3.FORWARD
var max_range: float = 16.0
var speed: float = 15.0
var damage: int = 10
var color: Color = Color(1.0, 0.45, 0.1)
var spell_id: String = "fire"
var proficiency_rank: int = 0
var _distance_left: float = 16.0


func _ready() -> void:
	direction = direction.normalized()
	_distance_left = max_range
	_build_visual()


func _physics_process(delta: float) -> void:
	if direction.length_squared() < 0.001:
		queue_free()
		return
	var travel := minf(speed * delta, _distance_left)
	var from := global_position
	var to := from + direction * travel
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if source_player is CollisionObject3D:
		query.exclude = [source_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node3D and collider.is_in_group("enemies") and collider.has_method("take_hit"):
			var push_dir := Vector3(direction.x, 0.0, direction.z)
			if push_dir.length_squared() > 0.001:
				push_dir = push_dir.normalized()
			collider.call("take_hit", damage, push_dir)
		queue_free()
		return
	global_position = to
	_distance_left -= travel
	if _distance_left <= 0.001:
		queue_free()


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var base_radius := 0.105 if spell_id == "fire" else 0.065
	# As versões evoluídas ficam visivelmente maiores e mais intensas.
	var radius := base_radius * (1.0 + float(clampi(proficiency_rank, 0, 4)) * 0.16)
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8 + float(clampi(proficiency_rank, 0, 4)) * 0.45
	material.roughness = 0.25
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

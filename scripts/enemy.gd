extends CharacterBody3D
# Inimigo (cena res://scenes/enemy.tscn): persegue o jogador, ataca de perto e deixa ouro ao morrer.
# Inimigos voadores (cfg "flying") ignoram a gravidade, zigue-zagueiam e planam à altura do jogador.
# No mundo aberto, quem está dentro de uma zona segura (cidades) não é atacado: os monstros ficam parados.
# O jogo configura cada instância com setup() logo após criá-la.

const GRAVITY := 20.0

var game = null
var display_name := "Inimigo"
var kind := ""
var max_hp := 20
var hp := 20
var damage := 6
var speed := 2.5
var gold_drop := 5
var is_boss := false
var flying := false
var fly_height := 1.1
var sight_range := 14.0
var attack_range := 1.8
var _attack_cd := 0.0
var _knock := Vector3.ZERO
var _target = null
var _target_scan_timer := 0.0
var _last_hit_player_credit := true
var _t := 0.0

@onready var sprite: Sprite3D = $Sprite
@onready var collision: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group("enemies")


func setup(cfg: Dictionary, g) -> void:
	game = g
	display_name = cfg["name"]
	kind = cfg.get("kind", "")
	max_hp = cfg["hp"]
	hp = max_hp
	damage = cfg["dmg"]
	speed = cfg["speed"]
	gold_drop = cfg["gold"]
	is_boss = cfg.get("boss", false)
	flying = cfg.get("flying", false)
	fly_height = cfg.get("fly_height", 1.1)
	var r: float = cfg["radius"]
	var h := r * 2.2
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	collision.shape = cap
	collision.position = Vector3(0, h / 2.0, 0)
	sprite.texture = cfg["texture"]
	sprite.scale = Vector3.ONE * (r / 0.6)
	sprite.position = Vector3(0, 0.8 * sprite.scale.y, 0)
	if flying:
		position.y += fly_height
	_t = randf() * TAU


func set_stream_active(active: bool) -> void:
	# Inimigos do overworld pausam IA, renderização e colisão quando ficam
	# longe demais. Ao voltar para perto, retomam do estado atual.
	set_meta("stream_active", active)
	visible = active
	set_physics_process(active)
	collision_layer = 1 if active else 0
	collision_mask = 1 if active else 0


func _physics_process(delta: float) -> void:
	if hp <= 0 or game == null or game.phase != "play":
		return
	_target_scan_timer -= delta
	if _target_scan_timer <= 0.0 or not _is_valid_attack_target(_target):
		_target = _select_combat_target()
		_target_scan_timer = 0.45
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_t += delta
	if not _is_valid_attack_target(_target):
		velocity = Vector3(0.0, -GRAVITY * delta, 0.0) if not flying else Vector3.ZERO
		move_and_slide()
		return
	var player_safe := _target_in_safe_zone()
	if flying:
		_fly(delta, player_safe)
	else:
		_walk(delta, player_safe)


func _is_valid_attack_target(value: Variant) -> bool:
	if not (value is Node3D) or not is_instance_valid(value):
		return false
	if value == game.player:
		return true
	if value.has_method("can_be_targeted_by_monsters"):
		return bool(value.call("can_be_targeted_by_monsters"))
	return false


func _is_safe_position(position: Vector3) -> bool:
	if bool(get_meta("city_occupation_actor", false)):
		return false
	var ow = game.overworld
	return ow != null and is_instance_valid(ow) and ow.in_safe_zone(position)


func _select_combat_target() -> Node3D:
	if game == null or not is_instance_valid(game):
		return null
	var best: Node3D = null
	var best_score := INF
	var player_value: Variant = game.player
	if player_value is Node3D and is_instance_valid(player_value):
		var player_node := player_value as Node3D
		var player_distance := Vector2(player_node.global_position.x - global_position.x, player_node.global_position.z - global_position.z).length()
		if player_distance <= sight_range and not _is_safe_position(player_node.global_position):
			best = player_node
			best_score = player_distance * 0.84
	for npc_value in get_tree().get_nodes_in_group("world_npcs"):
		if not is_instance_valid(npc_value) or not (npc_value is Node3D):
			continue
		var npc := npc_value as Node3D
		if not _is_valid_attack_target(npc):
			continue
		var distance := Vector2(npc.global_position.x - global_position.x, npc.global_position.z - global_position.z).length()
		if distance > sight_range or _is_safe_position(npc.global_position):
			continue
		var score := distance
		# Guardas chamam a atenção dos monstros, enquanto civis só são preferidos
		# quando estiverem realmente mais próximos do que o jogador.
		if str(npc.get("role")) == "guarda":
			score *= 0.92
		if bool(npc.get("is_unique_witch")):
			score *= 1.15
		if score < best_score:
			best = npc
			best_score = score
	return best


func _target_in_safe_zone() -> bool:
	# Uma cidade tomada não é mais uma zona segura; seus invasores enfrentam
	# também guardas e moradores presentes nas ruas.
	if bool(get_meta("city_occupation_actor", false)):
		return false
	if not is_instance_valid(_target):
		return true
	return _is_safe_position(_target.global_position)


func _damage_current_target() -> void:
	if not _is_valid_attack_target(_target):
		return
	if _target == game.player:
		if _target.has_method("take_damage"):
			_target.call("take_damage", damage)
	elif _target.has_method("receive_monster_hit"):
		_target.call("receive_monster_hit", damage, global_position)


func _walk(delta: float, player_safe: bool) -> void:
	var to_player: Vector3 = _target.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player / dist if dist > 0.01 else Vector3.ZERO

	var horizontal := Vector3.ZERO
	if dist <= sight_range and not player_safe:
		if dir != Vector3.ZERO:
			look_at(global_position + dir, Vector3.UP)
		if dist > attack_range:
			horizontal = dir * speed
		elif _attack_cd <= 0.0:
			_attack_cd = 1.2
			_damage_current_target()

	_knock = _knock.move_toward(Vector3.ZERO, 12.0 * delta)
	velocity.x = horizontal.x + _knock.x
	velocity.z = horizontal.z + _knock.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()


func _fly(delta: float, player_safe: bool) -> void:
	var aim: Vector3 = _target.global_position + Vector3(0.0, 1.0, 0.0)
	var from := global_position + Vector3(0.0, 0.4, 0.0)
	var to3 := aim - from
	var dist := to3.length()
	var v := Vector3.ZERO
	if dist <= sight_range and not player_safe:
		var flat := Vector3(to3.x, 0.0, to3.z)
		if flat.length() > 0.01:
			look_at(global_position + flat.normalized(), Vector3.UP)
		if dist > attack_range:
			v = to3.normalized() * speed
			var side := Vector3(-to3.z, 0.0, to3.x).normalized()
			v += side * sin(_t * 6.0) * speed * 0.6
		elif _attack_cd <= 0.0:
			_attack_cd = 1.0
			_damage_current_target()
	else:
		v.y = sin(_t * 2.0) * 0.5
	_knock = _knock.move_toward(Vector3.ZERO, 12.0 * delta)
	velocity = v + _knock
	move_and_slide()


func take_hit(dmg: int, push_dir: Vector3, attacker: Node = null) -> void:
	if hp <= 0:
		return
	_last_hit_player_credit = attacker == null or (game != null and is_instance_valid(game) and attacker == game.player)
	hp -= dmg
	_knock = Vector3(push_dir.x, 0.0, push_dir.z).normalized() * 5.0
	if sprite:
		sprite.modulate = Color(1.0, 0.3, 0.3)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		if game:
			game.on_enemy_killed(self, _last_hit_player_credit)
		queue_free()

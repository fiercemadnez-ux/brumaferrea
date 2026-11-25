extends Node

const WORLD_NAMES := preload("res://scripts/world_names.gd")

# Simulação persistente de pressão regional e queda de cidades.
# A ameaça de cada cidade depende da pressão regional e cresce em tempo real.
# Ao chegar a 100, começa um ataque. Jogador e NPCs podem derrotar invasores; uma
# cidade tomada só deixa de estar ocupada após os combatentes eliminarem os invasores.
const DEFAULT_CITY_INFLUENCE_RADIUS := 140.0
const WILDERNESS_CELL_SIZE := 700.0
const SIMULATION_STEP_SECONDS := 8.0
const PASSIVE_DECAY_PER_SECOND := 0.022
const MAX_HOSTILE_PRESSURE_PER_STEP := 1.8
const CITY_PRESSURE_EXTRA_RADIUS := 420.0
const CITY_BASE_PRESSURE_PER_SECOND := 0.0035
const PLAYER_CITY_PRESSURE_MULTIPLIER := 1.65
const PLAYER_CITY_PRESSURE_BONUS_PER_SECOND := 0.0025
const PLAYER_CITY_MIN_RELATIVE_PRESSURE := 1.12
const LOW_RISK_CITY_PRESSURE_MULTIPLIER := 0.38
const CITY_SITE_PRESSURE_PER_SECOND := 0.0045
const CITY_DUNGEON_PRESSURE_PER_SECOND := 0.009
const CITY_HOSTILE_PRESSURE_PER_SECOND := 0.015
const CITY_ASSAULT_DURATION := 90.0
const CITY_ASSAULT_BASE_SIZE := 7
const CITY_ASSAULT_MAX_SIZE := 12
const CITY_OCCUPATION_MIN_SIZE := 6
const CITY_OCCUPATION_MAX_SIZE := 12
const CITY_EVENT_NOTICE_DISTANCE := 650.0

var regions: Dictionary = {}
var _cities: Array[Dictionary] = []
var _city_influence_radii: Dictionary = {}
var _simulation_timer := 0.0
var _game: Node = null


func initialize(settlements: Array, spawn_records: Array, dungeon_positions: Array, owner_game: Node, session_state: Dictionary = {}, city_radii: Dictionary = {}) -> void:
	_game = owner_game
	regions.clear()
	_cities.clear()
	_city_influence_radii = city_radii.duplicate(true)
	_simulation_timer = 0.0

	for settlement_value in settlements:
		var settlement: Dictionary = settlement_value
		var city_id: String = str(settlement.get("id", ""))
		if city_id.is_empty():
			continue
		var city_center: Vector3 = settlement.get("pos", Vector3.ZERO)
		var city_record: Dictionary = {
			"id": city_id,
			"name": str(settlement.get("name", WORLD_NAMES.settlement_name(city_id))),
			"center": city_center,
			"is_city": true,
			"threat": 4.0,
			"spawn_sites": 0,
			"dungeon_sites": 0,
			"spawn_incidents": 0,
			"enemies_killed": 0,
			"dungeons_discovered": 0,
			"active_hostiles": 0,
			"last_event": "",
			"siege_state": "safe",
			"assault_timer": 0.0,
			"assault_remaining": 0,
			"occupation_remaining": 0,
			"attack_count": 0,
			"city_destroyed": false
		}
		regions[city_id] = city_record
		_cities.append({
			"id": city_id,
			"name": city_record["name"],
			"center": city_center,
			"radius": float(_city_influence_radii.get(city_id, DEFAULT_CITY_INFLUENCE_RADIUS))
		})

	# Covis e criptas próximos contam para a cidade que poderiam ameaçar, mesmo
	# que os marcadores fiquem logo além do perímetro seguro.
	for spawn_value in spawn_records:
		var spawn_record: Dictionary = spawn_value
		var spawn_pos: Vector3 = spawn_record.get("pos", Vector3.ZERO)
		var region_id: String = _pressure_region_id_for_position(spawn_pos)
		var region: Dictionary = _ensure_region(region_id, spawn_pos)
		region["spawn_sites"] = int(region.get("spawn_sites", 0)) + 1
		regions[region_id] = region

	for dungeon_value in dungeon_positions:
		var dungeon_pos: Vector3 = dungeon_value
		var region_id: String = _pressure_region_id_for_position(dungeon_pos)
		var region: Dictionary = _ensure_region(region_id, dungeon_pos)
		region["dungeon_sites"] = int(region.get("dungeon_sites", 0)) + 1
		regions[region_id] = region

	# A quantidade de pontos de monstros e criptas dá uma tensão inicial baixa.
	for region_key in regions.keys():
		var region: Dictionary = regions[region_key]
		var sites: int = mini(int(region.get("spawn_sites", 0)), 16)
		var dungeons: int = mini(int(region.get("dungeon_sites", 0)), 3)
		region["threat"] = clampf(4.0 + float(sites) * 1.15 + float(dungeons) * 5.0, 0.0, 32.0)
		regions[region_key] = region

	# Restaura o estado completo de cidades e células selvagens de saves anteriores.
	for saved_key in session_state.keys():
		var region_id: String = str(saved_key)
		var saved_value: Variant = session_state[region_id]
		if not (saved_value is Dictionary):
			continue
		var saved: Dictionary = saved_value
		if not regions.has(region_id):
			if not region_id.begins_with("wild:"):
				continue
			regions[region_id] = saved.duplicate(true)
			continue
		var current: Dictionary = regions[region_id]
		current["threat"] = clampf(float(saved.get("threat", current.get("threat", 0.0))), 0.0, 100.0)
		for field in [
			"spawn_incidents", "enemies_killed", "dungeons_discovered", "last_event",
			"siege_state", "assault_timer", "assault_remaining", "occupation_remaining",
			"attack_count", "city_destroyed", "active_hostiles"
		]:
			if saved.has(field):
				current[field] = saved[field]
		# Estados introduzidos nesta versão recebem valores seguros em saves antigos.
		current["siege_state"] = str(current.get("siege_state", "safe"))
		current["assault_timer"] = maxf(0.0, float(current.get("assault_timer", 0.0)))
		current["assault_remaining"] = maxi(0, int(current.get("assault_remaining", 0)))
		current["occupation_remaining"] = maxi(0, int(current.get("occupation_remaining", 0)))
		current["attack_count"] = maxi(0, int(current.get("attack_count", 0)))
		current["city_destroyed"] = bool(current.get("city_destroyed", false))
		regions[region_id] = current
	_sync_session_state()


func tick(delta: float, hour: float) -> void:
	_simulation_timer += maxf(delta, 0.0)
	if _simulation_timer < SIMULATION_STEP_SECONDS:
		return
	var elapsed: float = _simulation_timer
	_simulation_timer = 0.0

	var hostile_counts: Dictionary = {}
	for enemy_value in get_tree().get_nodes_in_group("overworld_enemies"):
		if not is_instance_valid(enemy_value) or not enemy_value.is_inside_tree():
			continue
		if not bool(enemy_value.visible):
			continue
		var enemy: Node3D = enemy_value as Node3D
		if enemy == null:
			continue
		var region_id: String = _pressure_region_id_for_position(enemy.global_position)
		hostile_counts[region_id] = int(hostile_counts.get(region_id, 0)) + 1

	var night: bool = hour >= 21.0 or hour < 6.0
	var player_city_id := _current_player_city_id()
	# Calcula a maior pressão normal das cidades fora da região do jogador. A cidade
	# atual recebe ao menos um pouco mais de pressão que as demais, sem igualar seus
	# níveis de alerta nem apagar os efeitos de covis, criptas e ataques anteriores.
	var strongest_other_city_rate := 0.0
	for city_key in regions.keys():
		var city_id := str(city_key)
		var city_record: Dictionary = regions[city_id]
		if not bool(city_record.get("is_city", false)) or city_id == player_city_id:
			continue
		if str(city_record.get("siege_state", "safe")) != "safe":
			continue
		var city_hostiles := int(hostile_counts.get(city_id, 0))
		strongest_other_city_rate = maxf(strongest_other_city_rate, _city_growth_rate(city_record, city_hostiles, night))
	for region_key in regions.keys():
		var region_id: String = str(region_key)
		var region: Dictionary = regions[region_id]
		var hostile_count: int = int(hostile_counts.get(region_id, 0))
		if bool(region.get("is_city", false)):
			# A região atual não apenas recebe um multiplicador: seu ritmo de escalada
			# fica ligeiramente acima do maior ritmo normal de outra cidade. O estado de
			# cada região permanece independente e persistente.
			_tick_city_region(region_id, region, elapsed, hostile_count, night, region_id == player_city_id, strongest_other_city_rate)
			continue
		var recovery: float = PASSIVE_DECAY_PER_SECOND * elapsed
		var pressure: float = minf(MAX_HOSTILE_PRESSURE_PER_STEP, float(hostile_count) * 0.22)
		if night:
			pressure *= 1.2
		region["threat"] = clampf(float(region.get("threat", 0.0)) - recovery + pressure, 0.0, 100.0)
		region["active_hostiles"] = hostile_count
		regions[region_id] = region
	_sync_session_state()


func _current_player_city_id() -> String:
	if _game == null or not is_instance_valid(_game):
		return ""
	var player_value: Variant = _game.get("player")
	if not (player_value is Node3D) or not is_instance_valid(player_value):
		return ""
	var region_id := region_id_for_position((player_value as Node3D).global_position)
	if regions.has(region_id) and bool(regions[region_id].get("is_city", false)):
		return region_id
	return ""


func _count_city_defenders(city_id: String) -> int:
	# Fora da distância de streaming, os cercos são resolvidos em segundo plano.
	# A guarda local ainda influencia o resultado sem exigir que todos os NPCs e
	# inimigos distantes sejam instanciados ao mesmo tempo.
	var parent_node := get_parent()
	if parent_node == null or not is_instance_valid(parent_node):
		return 0
	var npcs_value: Variant = parent_node.get("npcs")
	if not (npcs_value is Array):
		return 0
	var defenders := 0
	for npc_value in npcs_value:
		if not is_instance_valid(npc_value):
			continue
		if str(npc_value.get("city_id")) != city_id or str(npc_value.get("role")) != "guarda":
			continue
		# Mesmo fora da distância de renderização, um guarda ainda contribui para
		# a defesa abstrata daquela região. Só excluímos quem já foi removido da cidade.
		if bool(npc_value.get_meta("city_occupation_hidden", false)) or bool(npc_value.get("_combat_downed")):
			continue
		defenders += 1
	return defenders


func _city_growth_rate(region: Dictionary, hostile_count: int, night: bool) -> float:
	var site_count: int = mini(int(region.get("spawn_sites", 0)), 8)
	var dungeon_count: int = mini(int(region.get("dungeon_sites", 0)), 3)
	var growth_per_second: float = CITY_BASE_PRESSURE_PER_SECOND
	growth_per_second += float(site_count) * CITY_SITE_PRESSURE_PER_SECOND
	growth_per_second += float(dungeon_count) * CITY_DUNGEON_PRESSURE_PER_SECOND
	if site_count == 0 and dungeon_count == 0:
		growth_per_second *= LOW_RISK_CITY_PRESSURE_MULTIPLIER
	growth_per_second += minf(6.0, float(hostile_count)) * CITY_HOSTILE_PRESSURE_PER_SECOND
	if night:
		growth_per_second *= 1.2
	return growth_per_second


func _tick_city_region(city_id: String, region: Dictionary, elapsed: float, hostile_count: int, night: bool, is_player_city: bool = false, strongest_other_city_rate: float = 0.0) -> void:
	var siege_state := str(region.get("siege_state", "safe"))
	region["active_hostiles"] = hostile_count
	if siege_state in ["occupied", "ruins"]:
		regions[city_id] = region
		return
	if siege_state == "under_attack":
		var remaining_time := maxf(0.0, float(region.get("assault_timer", CITY_ASSAULT_DURATION)) - elapsed)
		region["assault_timer"] = remaining_time
		regions[city_id] = region
		if int(region.get("assault_remaining", 0)) <= 0:
			_repel_city_attack(city_id)
		elif remaining_time <= 0.0:
			_resolve_city_attack(city_id)
		return

	# A pressão da cidade nunca desaparece só porque o jogador saiu da região.
	# Monstros derrotados por jogadores ou NPCs e trabalhos regionais reduzem a pressão;
	# enquanto isso, covis próximos e a passagem do tempo aproximam a próxima invasão.
	var growth_per_second := _city_growth_rate(region, hostile_count, night)
	if is_player_city:
		# A cidade atual fica ligeiramente acima do ritmo das demais, garantindo que
		# a pressão do jogo aconteça perto do jogador para ele poder reagir e balancear.
		growth_per_second = maxf(
			growth_per_second * PLAYER_CITY_PRESSURE_MULTIPLIER + PLAYER_CITY_PRESSURE_BONUS_PER_SECOND,
			strongest_other_city_rate * PLAYER_CITY_MIN_RELATIVE_PRESSURE
		)
	var new_threat: float = clampf(float(region.get("threat", 0.0)) + growth_per_second * elapsed, 0.0, 100.0)
	region["threat"] = new_threat
	regions[city_id] = region
	if new_threat >= 100.0:
		_begin_city_attack(city_id)


func _begin_city_attack(city_id: String) -> void:
	if not regions.has(city_id):
		return
	var region: Dictionary = regions[city_id]
	if str(region.get("siege_state", "safe")) in ["under_attack", "occupied", "ruins"]:
		return
	var wave_size := CITY_ASSAULT_BASE_SIZE
	wave_size += mini(3, int(region.get("spawn_sites", 0)) / 3)
	wave_size += mini(2, int(region.get("dungeon_sites", 0)))
	wave_size = clampi(wave_size, CITY_ASSAULT_BASE_SIZE, CITY_ASSAULT_MAX_SIZE)
	region["siege_state"] = "under_attack"
	region["assault_timer"] = CITY_ASSAULT_DURATION
	region["assault_remaining"] = wave_size
	region["occupation_remaining"] = 0
	region["attack_count"] = int(region.get("attack_count", 0)) + 1
	region["threat"] = 100.0
	region["last_event"] = "Monstros atacam %s" % str(region.get("name", WORLD_NAMES.settlement_name(city_id)))
	regions[city_id] = region
	_announce_city_event(city_id, "city_attacked", "Um bando de monstros atacou %s." % str(region.get("name", WORLD_NAMES.settlement_name(city_id))), "Os sinos soaram em %s. Monstros estão atacando a cidade!" % str(region.get("name", WORLD_NAMES.settlement_name(city_id))))


func _resolve_city_attack(city_id: String) -> void:
	if not regions.has(city_id):
		return
	var region: Dictionary = regions[city_id]
	if str(region.get("siege_state", "")) != "under_attack":
		return
	var attackers_left: int = maxi(0, int(region.get("assault_remaining", 0)))
	if attackers_left <= 0:
		_repel_city_attack(city_id)
		return
	var site_count: int = int(region.get("spawn_sites", 0))
	var dungeon_count: int = int(region.get("dungeon_sites", 0))
	var previous_attacks: int = maxi(0, int(region.get("attack_count", 1)) - 1)
	var capture_chance: float = 0.24
	capture_chance += minf(0.18, float(site_count) * 0.015)
	capture_chance += minf(0.15, float(dungeon_count) * 0.05)
	capture_chance += minf(0.20, float(previous_attacks) * 0.04)
	capture_chance += maxf(0.0, float(attackers_left - 4)) * 0.025
	var defenders := _count_city_defenders(city_id)
	capture_chance -= minf(0.24, float(defenders) * 0.055)
	capture_chance = clampf(capture_chance, 0.12, 0.78)
	if randf() < capture_chance:
		region["siege_state"] = "occupied"
		region["city_destroyed"] = true
		region["occupation_remaining"] = clampi(maxi(CITY_OCCUPATION_MIN_SIZE, attackers_left + 2), CITY_OCCUPATION_MIN_SIZE, CITY_OCCUPATION_MAX_SIZE)
		region["assault_remaining"] = 0
		region["assault_timer"] = 0.0
		region["threat"] = 100.0
		region["last_event"] = "%s caiu e foi tomada por orcs e monstros" % str(region.get("name", WORLD_NAMES.settlement_name(city_id)))
		regions[city_id] = region
		_announce_city_event(city_id, "city_fallen", str(region.get("name", WORLD_NAMES.settlement_name(city_id))), "%s caiu. Orcs e outras criaturas tomaram as ruas; quem sobreviveu fugiu." % str(region.get("name", WORLD_NAMES.settlement_name(city_id))))
	else:
		_repel_city_attack(city_id)


func _repel_city_attack(city_id: String) -> void:
	if not regions.has(city_id):
		return
	var region: Dictionary = regions[city_id]
	var city_name := str(region.get("name", WORLD_NAMES.settlement_name(city_id)))
	region["siege_state"] = "safe"
	region["assault_timer"] = 0.0
	region["assault_remaining"] = 0
	region["threat"] = 35.0
	region["last_event"] = "A guarda de %s repeliu os invasores" % city_name
	regions[city_id] = region
	_announce_city_event(city_id, "city_attack_repulsed", city_name, "A guarda de %s conseguiu repelir o ataque." % city_name)


func report_city_invader_killed(city_id: String) -> void:
	if not regions.has(city_id):
		return
	var region: Dictionary = regions[city_id]
	var state := str(region.get("siege_state", "safe"))
	if state == "under_attack":
		region["assault_remaining"] = maxi(0, int(region.get("assault_remaining", 0)) - 1)
		regions[city_id] = region
		if int(region.get("assault_remaining", 0)) <= 0:
			_repel_city_attack(city_id)
	elif state == "occupied":
		region["occupation_remaining"] = maxi(0, int(region.get("occupation_remaining", 0)) - 1)
		regions[city_id] = region
		if int(region.get("occupation_remaining", 0)) <= 0:
			_liberate_ruined_city(city_id)
	_sync_session_state()


func _liberate_ruined_city(city_id: String) -> void:
	if not regions.has(city_id):
		return
	var region: Dictionary = regions[city_id]
	var city_name := str(region.get("name", WORLD_NAMES.settlement_name(city_id)))
	region["siege_state"] = "ruins"
	region["occupation_remaining"] = 0
	region["assault_remaining"] = 0
	region["assault_timer"] = 0.0
	region["threat"] = 18.0
	region["city_destroyed"] = true
	region["last_event"] = "Os invasores de %s foram derrotados; restam as ruínas" % city_name
	regions[city_id] = region
	_announce_city_event(city_id, "city_liberated_ruins", city_name, "Os invasores de %s foram derrotados. A cidade continua em ruínas." % city_name)


func _announce_city_event(city_id: String, event_kind: String, detail: String, local_message: String) -> void:
	if not regions.has(city_id):
		return
	var region: Dictionary = regions[city_id]
	var center: Vector3 = region.get("center", Vector3.ZERO)
	var parent_node := get_parent()
	if parent_node != null and is_instance_valid(parent_node):
		var society_value: Variant = parent_node.get("_npc_society")
		if society_value is Node and society_value.has_method("report_world_event"):
			society_value.call("report_world_event", center, event_kind, detail)
	if _game == null or not is_instance_valid(_game):
		return
	var player_value: Variant = _game.get("player")
	if not (player_value is Node3D) or not is_instance_valid(player_value):
		return
	var player_node: Node3D = player_value as Node3D
	var distance := Vector2(player_node.global_position.x - center.x, player_node.global_position.z - center.z).length()
	if distance <= CITY_EVENT_NOTICE_DISTANCE and _game.has_method("show_msg"):
		_game.call("show_msg", local_message)


func get_city_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in regions.keys():
		var region: Dictionary = regions[str(key)]
		if bool(region.get("is_city", false)):
			result.append(_public_record(region))
	return result


func get_city_record(city_id: String) -> Dictionary:
	if not regions.has(city_id) or not bool(regions[city_id].get("is_city", false)):
		return {}
	return _public_record(regions[city_id])


func get_city_position(city_id: String) -> Vector3:
	if not regions.has(city_id):
		return Vector3.ZERO
	return regions[city_id].get("center", Vector3.ZERO)


func region_id_for_position(position: Vector3) -> String:
	var nearest_city_id := ""
	var nearest_distance := INF
	var nearest_city_radius: float = DEFAULT_CITY_INFLUENCE_RADIUS
	for city in _cities:
		var center: Vector3 = city["center"]
		var distance: float = Vector2(position.x - center.x, position.z - center.z).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_city_id = str(city["id"])
			nearest_city_radius = float(city.get("radius", _city_influence_radii.get(nearest_city_id, DEFAULT_CITY_INFLUENCE_RADIUS)))
	if nearest_city_id != "" and nearest_distance <= nearest_city_radius:
		return nearest_city_id
	var cell_x: int = int(floor(position.x / WILDERNESS_CELL_SIZE))
	var cell_z: int = int(floor(position.z / WILDERNESS_CELL_SIZE))
	return "wild:%d:%d" % [cell_x, cell_z]


func _pressure_region_id_for_position(position: Vector3) -> String:
	var nearest_city_id := ""
	var nearest_distance := INF
	var nearest_radius := DEFAULT_CITY_INFLUENCE_RADIUS
	for city in _cities:
		var center: Vector3 = city["center"]
		var distance: float = Vector2(position.x - center.x, position.z - center.z).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_city_id = str(city["id"])
			nearest_radius = float(city.get("radius", _city_influence_radii.get(nearest_city_id, DEFAULT_CITY_INFLUENCE_RADIUS)))
	if nearest_city_id != "" and nearest_distance <= nearest_radius + CITY_PRESSURE_EXTRA_RADIUS:
		return nearest_city_id
	return region_id_for_position(position)


func get_region_at_position(position: Vector3) -> Dictionary:
	# No mapa e no feedback ao jogador, a faixa ao redor da cidade mostra a ameaça
	# que pode chegar às muralhas. O cálculo local de perigos do ermo continua usando
	# region_id_for_position(), para não transformar todo o campo em zona urbana.
	var region_id: String = _pressure_region_id_for_position(position)
	var region: Dictionary = _ensure_region(region_id, position)
	return _public_record(region)


func get_threat_at(position: Vector3) -> float:
	var region_id: String = region_id_for_position(position)
	var region: Dictionary = _ensure_region(region_id, position)
	return float(region.get("threat", 0.0))


func get_threat_for_city(city_id: String) -> float:
	if not regions.has(city_id):
		return 0.0
	return float(regions[city_id].get("threat", 0.0))


func get_status_for_city(city_id: String) -> String:
	if not regions.has(city_id):
		return "Tranquila"
	return str(_public_record(regions[city_id]).get("status", "Tranquila"))


func status_for_threat(threat: float) -> String:
	if threat < 20.0:
		return "Tranquila"
	if threat < 40.0:
		return "Inquieta"
	if threat < 60.0:
		return "Em alerta"
	if threat < 80.0:
		return "Perigosa"
	return "Crítica"


func is_position_in_city_region(position: Vector3, city_id: String) -> bool:
	return region_id_for_position(position) == city_id


func report_enemy_spawn(position: Vector3, enemy_kind: String) -> Dictionary:
	var amount: float = 0.75
	match enemy_kind:
		"goblin": amount = 0.95
		"skel": amount = 1.15
		"orc": amount = 1.5
		"bat", "rat": amount = 0.55
	var region_id := _pressure_region_id_for_position(position)
	if regions.has(region_id) and bool(regions[region_id].get("is_city", false)):
		amount *= 0.18
	return _change_threat(position, amount, "Atividade de monstros")


func report_enemy_killed(position: Vector3, enemy_kind: String) -> Dictionary:
	var relief: float = 2.7
	match enemy_kind:
		"goblin": relief = 3.4
		"skel": relief = 4.2
		"orc": relief = 5.2
		"bat", "rat": relief = 2.3
	var result: Dictionary = _change_threat(position, -relief, "Monstro derrotado")
	var region_id: String = str(result.get("region_id", ""))
	if regions.has(region_id):
		var region: Dictionary = regions[region_id]
		region["enemies_killed"] = int(region.get("enemies_killed", 0)) + 1
		regions[region_id] = region
		_sync_session_state()
	return result


func report_dungeon_discovered(position: Vector3) -> Dictionary:
	var result: Dictionary = _change_threat(position, 15.0, "Cripta descoberta")
	var region_id: String = str(result.get("region_id", ""))
	if regions.has(region_id):
		var region: Dictionary = regions[region_id]
		region["dungeons_discovered"] = int(region.get("dungeons_discovered", 0)) + 1
		regions[region_id] = region
		_sync_session_state()
	return result


func resolve_regional_quest(city_id: String, targets_defeated: int) -> Dictionary:
	if not regions.has(city_id):
		return {}
	var region: Dictionary = regions[city_id]
	if str(region.get("siege_state", "safe")) in ["under_attack", "occupied", "ruins"]:
		return _public_record(region)
	var old_threat: float = float(region.get("threat", 0.0))
	var reduction: float = 9.0 + minf(8.0, float(targets_defeated) * 0.65)
	region["threat"] = clampf(old_threat - reduction, 0.0, 100.0)
	region["last_event"] = "Trabalho regional concluído"
	regions[city_id] = region
	_sync_session_state()
	return {
		"region_id": city_id,
		"region_name": str(region.get("name", WORLD_NAMES.settlement_name(city_id))),
		"old_threat": old_threat,
		"threat": float(region["threat"]),
		"old_status": status_for_threat(old_threat),
		"status": status_for_threat(float(region["threat"]))
	}


func _change_threat(position: Vector3, amount: float, event_name: String) -> Dictionary:
	var region_id: String = _pressure_region_id_for_position(position)
	var region: Dictionary = _ensure_region(region_id, position)
	var old_threat: float = float(region.get("threat", 0.0))
	var siege_state := str(region.get("siege_state", "safe"))
	if bool(region.get("is_city", false)) and siege_state in ["under_attack", "occupied", "ruins"]:
		return {
			"region_id": region_id,
			"region_name": str(region.get("name", region_id)),
			"old_threat": old_threat,
			"threat": old_threat,
			"old_status": status_for_threat(old_threat),
			"status": status_for_threat(old_threat)
		}
	var new_threat: float = clampf(old_threat + amount, 0.0, 100.0)
	region["threat"] = new_threat
	region["last_event"] = event_name
	if amount > 0.0 and event_name == "Atividade de monstros":
		region["spawn_incidents"] = int(region.get("spawn_incidents", 0)) + 1
	regions[region_id] = region
	_sync_session_state()
	return {
		"region_id": region_id,
		"region_name": str(region.get("name", region_id)),
		"old_threat": old_threat,
		"threat": new_threat,
		"old_status": status_for_threat(old_threat),
		"status": status_for_threat(new_threat)
	}


func _ensure_region(region_id: String, position: Vector3) -> Dictionary:
	if regions.has(region_id):
		return regions[region_id]
	var center := Vector3(
		(float(floor(position.x / WILDERNESS_CELL_SIZE)) + 0.5) * WILDERNESS_CELL_SIZE,
		position.y,
		(float(floor(position.z / WILDERNESS_CELL_SIZE)) + 0.5) * WILDERNESS_CELL_SIZE
	)
	var parts: PackedStringArray = region_id.split(":")
	var region_name := "Ermos desconhecidos"
	if parts.size() >= 3 and parts[0] == "wild":
		region_name = "Ermos %s, %s" % [parts[1], parts[2]]
	var record: Dictionary = {
		"id": region_id,
		"name": region_name,
		"center": center,
		"is_city": false,
		"threat": 0.0,
		"spawn_sites": 0,
		"dungeon_sites": 0,
		"spawn_incidents": 0,
		"enemies_killed": 0,
		"dungeons_discovered": 0,
		"active_hostiles": 0,
		"last_event": "",
		"siege_state": "safe",
		"assault_timer": 0.0,
		"assault_remaining": 0,
		"occupation_remaining": 0,
		"attack_count": 0,
		"city_destroyed": false
	}
	regions[region_id] = record
	return record


func _public_record(region: Dictionary) -> Dictionary:
	var result: Dictionary = region.duplicate(true)
	var threat: float = float(result.get("threat", 0.0))
	var status := status_for_threat(threat)
	if bool(result.get("is_city", false)):
		match str(result.get("siege_state", "safe")):
			"under_attack": status = "Sob ataque"
			"occupied": status = "Tomada por monstros"
			"ruins": status = "Ruínas libertadas"
	result["status"] = status
	result["security"] = 100.0 - threat
	return result


func _sync_session_state() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	_game.set("regional_threat_session_state", regions.duplicate(true))

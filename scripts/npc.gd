extends CharacterBody3D
# NPC com identidade, residência, rotina e movimento autônomo.
# A aparência e o sistema de diálogo existentes são mantidos.

const SHOP_ROLES := ["ferreiro", "curandeira", "mercador"]

const CREATURE_NAMES := {
	"rat": "ratos gigantes",
	"bat": "morcegos",
	"goblin": "goblins",
	"skel": "esqueletos",
	"orc": "orcs"
}

const WALK_SPEED := 1.65
const GRAVITY := 22.0
const ARRIVE_DISTANCE := 1.15
const NPC_SEPARATION_RADIUS := 1.45
# A rotina atualiza a lista de vizinhos a cada segundo. Margem maior que a
# velocidade combinada de dois NPCs evita que pares recém-chegados fiquem sem
# separação, sem fazer cada personagem examinar todos os habitantes da cidade.
const NPC_SEPARATION_CACHE_RADIUS := 5.5
const NPC_SEPARATION_CACHE_RADIUS_SQUARED := NPC_SEPARATION_CACHE_RADIUS * NPC_SEPARATION_CACHE_RADIUS
const NPC_SEPARATION_WEIGHT := 1.35
const HOME_INTERIOR_RECESS := 0.72
const HOME_TRANSITION_SECONDS := 0.72
const MAX_KNOWN_WORLD_EVENTS := 12
const AMBIENT_CHAT_STOP_SECONDS := 11.0
const NPC_MONSTER_SCAN_SECONDS := 0.45
const NPC_MONSTER_FIGHT_RADIUS := 16.0
const NPC_MONSTER_FLEE_RADIUS := 9.5
const NPC_MONSTER_MELEE_RANGE := 1.7
const NPC_MONSTER_FLEE_SPEED := 2.75

var display_name := "Aldeão"
var person_name := ""
var gender := "male"
var age_stage := "adult"
var age_years: float = 18.0
var mother_id := ""
var father_id := ""
var generation := 0
var family_surname := ""
var family_generated := false
var is_deceased := false
var partner_id := ""
var sprite_key := "npcmale"
var role := "aldeao"
var occupation_label := "" # profissão/título, separado do nome pessoal
# Mercadores locais trabalham numa loja; ambulantes hospedam-se em estalagens e viajam.
var merchant_type := "none" # none, resident, itinerant
var merchant_trip_active := false
var merchant_target_city_id := ""
var merchant_target_inn_id := ""
var merchant_last_city_id := ""
var merchant_trips_completed := 0
var messenger_trip_active := false
var messenger_trip_stage := ""
var messenger_target_city_id := ""
var messenger_target_office_id := ""
var messenger_origin_office_id := ""
var messenger_arrival_clock := 0.0
var messenger_trips_completed := 0
var messenger_carried_news: Array[Dictionary] = []
var is_unique_witch := false
var witch_location := ""
var witch_state := "alive"
var witch_hp := 80
# Ajustado pelo jogo apenas para a bruxa aliada; NPCs comuns mantêm WALK_SPEED.
var companion_move_speed: float = 0.0
var society: Node = null
var game: Node = null
var personality := "pratico"
var speech_style := "direto"
var personal_interest := "os costumes locais"
var personal_goal := "aprender algo que ainda não sei"
var sociability := 0.55
var curiosity := 0.5
var ambient_conversation_locked := false
var recent_ambient_lines: Array[String] = []
var ambient_speech_count := 0
var npc_id := ""
var city_id := ""
var origin_city_id := ""
var city_name := ""
var home_id := ""
var home_name := ""
var home_position := Vector3.ZERO # ponto exterior da porta
var home_door_position := Vector3.ZERO # plano da porta na fachada
var home_front_direction := Vector3.FORWARD # aponta da casa para a rua
var is_interior_present := false # visível no interior gerado enquanto o jogador visita
var interior_building_id := ""
var is_at_tavern := false
var tavern_building_id := ""
var tavern_entry_position := Vector3.ZERO
var tavern_door_position := Vector3.ZERO
var tavern_front_direction := Vector3.FORWARD
var work_position := Vector3.ZERO
var work_building_id := ""
var work_door_position := Vector3.ZERO
var work_front_direction := Vector3.FORWARD
var work_building_name := ""
var is_at_work := false
var has_work_position := false
var household_member_ids: Array = []
var household_member_names: Array[String] = []
var household_data_ready := false
var known_world_events: Array[Dictionary] = []
var conversations_with_player := 0
# Relação individual com o jogador: familiaridade, confiança e gratidão ficam salvas
# com a identidade do habitante, em vez de serem zeradas quando a cena é recriada.
var player_relationship: Dictionary = {}
var ambient_line_label: Label3D = null
var ambient_line_timer := 0.0
var ambient_conversation_partner_id := ""
var known_city_ids: Array[String] = []
var known_house_ids: Array[String] = []
var known_place_ids: Array[String] = []
var known_places: Array[Dictionary] = []
var regional_facts: Array[String] = []
var life_bucket := ""
var life_enabled := false
var is_at_home := false
var has_target := false
var target_kind := "idle"
var target_position := Vector3.ZERO
var _activity_timer := 0.0
var _blocked_timer := 0.0
var _detour_timer := 0.0
var _detour_point := Vector3.ZERO
var _detour_side := 1.0
var _last_distance := INF
var _stuck_cycles := 0
var _route_points: Array[Vector3] = []
var _route_index := 0
var _separation_peers: Array = []
var _home_transition_kind := "" # "enter" / "exit"
var _home_transition_elapsed := 0.0
var _home_transition_start := Vector3.ZERO
var _home_transition_end := Vector3.ZERO
var _pending_home_destination := Vector3.ZERO
var _pending_home_destination_kind := "town"
var _pending_home_route: Array[Vector3] = []
var _tavern_visit_state: Dictionary = {}
# Combate social leve: guardas e alguns moradores corajosos defendem-se; os demais
# fogem quando uma criatura chega perto. Isto usa os inimigos existentes do mundo.
var combat_hp := 42
var combat_max_hp := 42
var _combat_target: Node3D = null
var _combat_scan_timer := 0.0
var _combat_attack_timer := 0.0
var _combat_flee_timer := 0.0
var _combat_downed := false
var _combat_recovery_timer := 0.0

@onready var sprite: Sprite3D = $Sprite
@onready var label: Label3D = $Name
@onready var collision_shape: CollisionShape3D = $Collision
var quest_return_marker: Label3D = null
var _quest_return_active := false


func _ready() -> void:
	add_to_group("world_npcs")
	# Os nomes continuam sendo dados internos para diálogo/quests, mas não são
	# renderizados flutuando sobre os sprites durante a exploração.
	label.visible = false
	# Exclamação dourada acima do contratante, visível só quando há uma entrega.
	quest_return_marker = Label3D.new()
	quest_return_marker.name = "QuestReturnMarker"
	quest_return_marker.text = "!"
	quest_return_marker.position = Vector3(0.0, 3.0, 0.0)
	quest_return_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	quest_return_marker.font_size = 72
	quest_return_marker.pixel_size = 0.012
	quest_return_marker.modulate = Color(1.0, 0.78, 0.18, 1.0)
	quest_return_marker.outline_modulate = Color(0.035, 0.025, 0.012, 1.0)
	quest_return_marker.outline_size = 12
	quest_return_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_return_marker.visible = false
	add_child(quest_return_marker)
	ambient_line_label = Label3D.new()
	ambient_line_label.name = "AmbientDialogue"
	ambient_line_label.position = Vector3(0.0, 2.05, 0.0)
	ambient_line_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ambient_line_label.font_size = 38
	ambient_line_label.pixel_size = 0.0042
	ambient_line_label.modulate = Color(1.0, 0.96, 0.82, 1.0)
	ambient_line_label.outline_modulate = Color(0.035, 0.03, 0.022, 1.0)
	ambient_line_label.outline_size = 8
	ambient_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ambient_line_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ambient_line_label.visible = false
	add_child(ambient_line_label)
	# A maioria dos NPCs não tem legenda ativa. Não executa _process em centenas
	# de personagens ociosos; show_ambient_line o reativa apenas durante uma fala.
	set_process(false)


func _process(delta: float) -> void:
	if ambient_line_timer <= 0.0:
		set_process(false)
		return
	ambient_line_timer = maxf(0.0, ambient_line_timer - delta)
	if ambient_line_timer <= 0.0:
		if is_instance_valid(ambient_line_label):
			ambient_line_label.visible = false
			ambient_line_label.text = ""
		set_process(false)


func has_pending_quest_return() -> bool:
	return _quest_return_active


func set_separation_peers(peers: Array) -> void:
	# A sociedade chama este método por intervalo, não por frame. Pré-filtra os
	# vizinhos espaciais aqui: em vez de cada NPC comparar-se com todos os outros
	# habitantes ativos (custo quadrático numa cidade cheia), sua física examina
	# apenas os poucos personagens que podem se aproximar o bastante para colidir.
	var nearby: Array = []
	for peer in peers:
		if peer == self or not is_instance_valid(peer):
			continue
		if not bool(peer.visible) or bool(peer.is_at_home) or not bool(peer.life_enabled):
			continue
		var dx: float = global_position.x - peer.global_position.x
		var dz: float = global_position.z - peer.global_position.z
		if dx * dx + dz * dz <= NPC_SEPARATION_CACHE_RADIUS_SQUARED:
			nearby.append(peer)
	_separation_peers = nearby


func _separation_steering() -> Vector3:
	var result := Vector3.ZERO
	for peer in _separation_peers:
		if peer == self or not is_instance_valid(peer):
			continue
		if not bool(peer.visible) or bool(peer.is_at_home) or not bool(peer.life_enabled):
			continue
		var offset := Vector3(global_position.x - peer.global_position.x, 0.0, global_position.z - peer.global_position.z)
		var distance := offset.length()
		if distance >= NPC_SEPARATION_RADIUS:
			continue
		var away: Vector3
		if distance < 0.001:
			# Se dois habitantes já ocupam exatamente a mesma posição, separam-se
			# em direções determinísticas distintas em vez de ficarem sobrepostos.
			var angle := float(abs(npc_id.hash()) % 6283) / 1000.0
			away = Vector3(cos(angle), 0.0, sin(angle))
		else:
			away = offset / distance
		result += away * ((NPC_SEPARATION_RADIUS - distance) / NPC_SEPARATION_RADIUS)
	return result


func set_quest_return_marker(active: bool) -> void:
	if _quest_return_active == active:
		return
	_quest_return_active = active
	if not is_instance_valid(quest_return_marker):
		return
	quest_return_marker.visible = active
	if not active or is_interior_present:
		# Se o jogador está dentro da casa, não removemos o NPC da sala no meio
		# da conversa. Ao sair, a rotina o deixa acessível à porta se houver entrega.
		return
	# A rotina pode ter escondido o NPC dentro da residência durante a noite.
	# Recolocamos o contratante na posição externa de entrada da casa para que
	# o jogador consiga encontrá-lo e entregar o trabalho.
	if is_at_work:
		_home_transition_kind = ""
		is_interior_present = false
		global_position = work_position
		is_at_work = false
		is_at_home = false
		visible = true
		collision_layer = 2
		collision_mask = 1
		life_enabled = true
		has_target = false
		_route_points.clear()
		_route_index = 0
		velocity = Vector3.ZERO
		set_physics_process(true)
	elif is_at_home:
		_home_transition_kind = ""
		is_interior_present = false
		global_position = home_position
		is_at_home = false
		visible = true
		collision_layer = 2
		collision_mask = 1
		life_enabled = true
		has_target = false
		_route_points.clear()
		_route_index = 0
		velocity = Vector3.ZERO
		set_physics_process(true)
	elif _home_transition_kind in ["enter", "work_enter"] or (target_kind in ["home", "work"] and has_target):
		# Um contratante com missão pronta não desaparece na porta. Interrompe
		# tanto o caminho de volta quanto a curta transição de entrada.
		var was_entering_work: bool = _home_transition_kind == "work_enter" or target_kind == "work"
		_home_transition_kind = ""
		_home_transition_elapsed = 0.0
		global_position = work_position if was_entering_work else home_position
		is_at_home = false
		is_at_work = false
		is_interior_present = false
		visible = true
		collision_layer = 2
		collision_mask = 1
		life_enabled = true
		set_physics_process(true)
		has_target = false
		_route_points.clear()
		_route_index = 0
		velocity = Vector3.ZERO


func setup(npc_name: String, npc_role: String, tex: Texture2D, tint: Color) -> void:
	# O NPC só ativa a física quando entra na região simulada do jogador.
	set_physics_process(false)
	display_name = npc_name
	role = npc_role
	merchant_type = "resident" if role == "mercador" else "none"
	sprite.texture = tex
	sprite.modulate = tint
	sprite.pixel_size = 0.003
	label.text = npc_name
	label.visible = false
	# NPCs colidem com o cenário, mas não empurram uns aos outros nem bloqueiam o jogador.
	collision_layer = 2
	collision_mask = 1


func configure_life(profile: Dictionary) -> void:
	npc_id = str(profile.get("id", ""))
	merchant_type = str(profile.get("merchant_type", "resident" if role == "mercador" else "none"))
	if role == "mercador" and merchant_type not in ["resident", "itinerant"]:
		merchant_type = "resident"
	merchant_trip_active = bool(profile.get("merchant_trip_active", false))
	merchant_target_city_id = str(profile.get("merchant_target_city_id", ""))
	merchant_target_inn_id = str(profile.get("merchant_target_inn_id", ""))
	merchant_last_city_id = str(profile.get("merchant_last_city_id", ""))
	merchant_trips_completed = int(profile.get("merchant_trips_completed", 0))
	messenger_trip_active = bool(profile.get("messenger_trip_active", false))
	messenger_trip_stage = str(profile.get("messenger_trip_stage", ""))
	messenger_target_city_id = str(profile.get("messenger_target_city_id", ""))
	messenger_target_office_id = str(profile.get("messenger_target_office_id", ""))
	messenger_origin_office_id = str(profile.get("messenger_origin_office_id", ""))
	messenger_arrival_clock = float(profile.get("messenger_arrival_clock", 0.0))
	messenger_trips_completed = int(profile.get("messenger_trips_completed", 0))
	messenger_carried_news.clear()
	var carried_news_value: Variant = profile.get("messenger_carried_news", [])
	if carried_news_value is Array:
		for news_value in carried_news_value:
			if news_value is Dictionary:
				messenger_carried_news.append(news_value.duplicate(true))
	is_unique_witch = bool(profile.get("is_unique_witch", role == "bruxa"))
	witch_location = str(profile.get("witch_location", ""))
	witch_state = str(profile.get("witch_state", "alive"))
	witch_hp = clampi(int(profile.get("witch_hp", 80)), 0, 80)
	city_id = str(profile.get("city_id", ""))
	origin_city_id = str(profile.get("origin_city_id", city_id))
	city_name = str(profile.get("city_name", ""))
	home_id = str(profile.get("home_id", ""))
	home_name = str(profile.get("home_name", ""))
	home_position = profile.get("home_position", global_position)
	home_front_direction = profile.get("home_front_direction", Vector3.FORWARD)
	home_front_direction.y = 0.0
	if home_front_direction.length_squared() < 0.001:
		home_front_direction = Vector3.FORWARD
	home_front_direction = home_front_direction.normalized()
	home_door_position = profile.get("home_door_position", home_position - home_front_direction * 1.15)
	is_interior_present = false
	interior_building_id = ""
	is_at_tavern = false
	tavern_building_id = ""
	tavern_entry_position = Vector3.ZERO
	tavern_door_position = Vector3.ZERO
	tavern_front_direction = Vector3.FORWARD
	_home_transition_kind = ""
	work_position = profile.get("work_position", Vector3.ZERO)
	work_building_id = str(profile.get("work_building_id", ""))
	work_door_position = profile.get("work_door_position", work_position)
	work_front_direction = profile.get("work_front_direction", Vector3.FORWARD)
	work_front_direction.y = 0.0
	if work_front_direction.length_squared() < 0.001:
		work_front_direction = Vector3.FORWARD
	work_front_direction = work_front_direction.normalized()
	work_building_name = str(profile.get("work_building_name", ""))
	is_at_work = false
	has_work_position = work_position != Vector3.ZERO
	person_name = str(profile.get("person_name", str(profile.get("display_name", display_name)).split(" · ")[0]))
	gender = str(profile.get("gender", "male"))
	age_stage = str(profile.get("age_stage", "adult"))
	age_years = float(profile.get("age_years", 18.0))
	mother_id = str(profile.get("mother_id", ""))
	father_id = str(profile.get("father_id", ""))
	generation = int(profile.get("generation", 0))
	family_surname = str(profile.get("family_surname", ""))
	family_generated = bool(profile.get("family_generated", false))
	is_deceased = bool(profile.get("is_deceased", false))
	partner_id = str(profile.get("partner_id", ""))
	sprite_key = str(profile.get("sprite_key", "npcfemale" if gender == "female" else "npcmale"))
	personality = str(profile.get("personality", "pratico"))
	speech_style = str(profile.get("speech_style", "direto"))
	personal_interest = str(profile.get("personal_interest", "os costumes locais"))
	personal_goal = str(profile.get("personal_goal", "aprender algo que ainda não sei"))
	sociability = float(profile.get("sociability", 0.55))
	curiosity = float(profile.get("curiosity", 0.5))
	var saved_player_relation: Variant = profile.get("player_relationship", {})
	player_relationship = saved_player_relation.duplicate(true) if saved_player_relation is Dictionary else {}
	conversations_with_player = int(player_relationship.get("conversations", profile.get("conversations_with_player", 0)))
	display_name = str(profile.get("display_name", display_name))
	occupation_label = str(profile.get("occupation_label", ""))
	combat_max_hp = _combat_hp_for_role()
	combat_hp = clampi(int(profile.get("combat_hp", combat_max_hp)), 1, combat_max_hp)
	_combat_target = null
	_combat_scan_timer = randf_range(0.05, NPC_MONSTER_SCAN_SECONDS)
	_combat_attack_timer = 0.0
	_combat_flee_timer = 0.0
	_combat_downed = false
	_combat_recovery_timer = 0.0
	label.text = display_name
	label.visible = false
	known_world_events.clear()
	var saved_memories: Variant = profile.get("known_world_events", [])
	if saved_memories is Array:
		for memory_value in saved_memories:
			if memory_value is Dictionary:
				known_world_events.append(memory_value.duplicate(true))
	known_city_ids = [city_id, origin_city_id]
	known_city_ids = _unique_strings(known_city_ids)
	known_house_ids.clear()
	if home_id != "":
		known_house_ids.append(home_id)
	known_place_ids.clear()
	known_places.clear()
	regional_facts.clear()
	# Estado externo salvo: se o arquivo do mundo foi recarregado, o morador retoma
	# uma posição/atividade plausível em vez de reaparecer automaticamente em casa.
	# Coordenadas antigas só são usadas quando ainda pertencem à cidade registrada.
	global_position = home_position
	is_at_home = true
	is_at_work = false
	target_kind = "home"
	life_bucket = ""
	has_target = false
	var life_state_value: Variant = profile.get("life_state", {})
	if life_state_value is Dictionary and not life_state_value.is_empty():
		var saved_state: Dictionary = life_state_value
		var saved_mode := str(saved_state.get("mode", "public"))
		life_bucket = str(saved_state.get("life_bucket", ""))
		target_kind = str(saved_state.get("target_kind", "town"))
		if saved_mode == "work" and has_work_position:
			global_position = work_position
			is_at_home = false
			is_at_work = true
		elif saved_mode == "home":
			global_position = home_position
			is_at_home = true
			is_at_work = false
		else:
			var position_value: Variant = saved_state.get("position", [])
			if position_value is Array and position_value.size() >= 3:
				var candidate := Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
				var center_value: Variant = profile.get("city_center", home_position)
				var center: Vector3 = center_value if center_value is Vector3 else home_position
				var maximum_restore_distance := 100000.0 if saved_mode == "travel" else 1600.0
				if Vector2(candidate.x - center.x, candidate.z - center.z).length() <= maximum_restore_distance:
					global_position = candidate
					is_at_home = false
				is_at_work = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	life_enabled = false
	set_physics_process(false)


func update_age_profile(new_age_years: float, new_age_stage: String, new_sprite_key: String) -> void:
	age_years = maxf(0.0, new_age_years)
	age_stage = new_age_stage
	sprite_key = new_sprite_key
	if game == null or not is_instance_valid(sprite):
		return
	var sprite_bank: Variant = game.get("sprites")
	if sprite_bank is Dictionary and sprite_bank.has(sprite_key):
		sprite.texture = sprite_bank[sprite_key]


func set_work_building_details(record: Dictionary) -> void:
	if record.is_empty():
		return
	work_building_id = str(record.get("id", work_building_id))
	work_door_position = record.get("door_position", record.get("entry", work_door_position))
	work_front_direction = record.get("front_direction", work_front_direction)
	work_front_direction.y = 0.0
	if work_front_direction.length_squared() < 0.001:
		work_front_direction = Vector3.FORWARD
	work_front_direction = work_front_direction.normalized()
	work_building_name = str(record.get("name", work_building_name))


func set_household_members(member_ids: Array, member_names: Array) -> void:
	# O registro da casa inclui todos os residentes, inclusive este NPC. Para a
	# perspectiva individual, guardar apenas as outras pessoas que moram aqui.
	household_member_ids.clear()
	household_member_names.clear()
	var count := mini(member_ids.size(), member_names.size())
	for i in range(count):
		var member_id := str(member_ids[i])
		var member_name := str(member_names[i])
		if member_id == str(npc_id):
			continue
		# Proteção para registros antigos/incompletos sem ID correspondente.
		if member_id.is_empty() and member_name == person_name:
			continue
		household_member_ids.append(member_id)
		household_member_names.append(member_name)
	# Caso os arrays tenham tamanhos diferentes, não perder os nomes restantes,
	# mas ainda evitar que o personagem fale de si mesmo na terceira pessoa.
	if member_names.size() > count:
		for i in range(count, member_names.size()):
			var member_name := str(member_names[i])
			if member_name != person_name:
				household_member_names.append(member_name)
	household_data_ready = true


func go_home() -> void:
	if is_at_home:
		has_target = false
		velocity = Vector3.ZERO
		return
	go_to(home_position, "home")


func go_to(destination: Vector3, destination_kind: String = "town") -> void:
	go_to_route(destination, destination_kind, [])


func set_tavern_destination(record: Dictionary) -> void:
	# Guarda a porta da estalagem escolhida pela rotina, para que chegar ao destino
	# signifique atravessar a porta e não ficar parado na calçada.
	tavern_building_id = str(record.get("id", ""))
	tavern_entry_position = record.get("entry", record.get("center", global_position))
	tavern_door_position = record.get("door_position", tavern_entry_position)
	tavern_front_direction = record.get("front_direction", Vector3.FORWARD)
	tavern_front_direction.y = 0.0
	if tavern_front_direction.length_squared() < 0.001:
		tavern_front_direction = Vector3.FORWARD
	tavern_front_direction = tavern_front_direction.normalized()


func _tavern_interior_world_position() -> Vector3:
	var direction := tavern_front_direction
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var inside := tavern_door_position - direction * HOME_INTERIOR_RECESS
	inside.y = tavern_entry_position.y
	return inside


func refresh_tavern_stay() -> void:
	if is_at_tavern:
		_activity_timer = randf_range(40.0, 80.0)


func go_to_route(destination: Vector3, destination_kind: String, route: Array) -> void:
	if destination_kind in ["home", "work"] and _quest_return_active:
		# Quem aguarda a entrega de uma missão permanece acessível ao jogador,
		# mesmo se sua rotina normal mandaria voltar para casa ou para a oficina.
		has_target = false
		_route_points.clear()
		_route_index = 0
		velocity = Vector3.ZERO
		_activity_timer = 12.0
		return
	if is_at_tavern and destination_kind != "tavern" and _home_transition_kind == "":
		# O frequentador sai pela mesma porta pela qual entrou antes de retomar a rota.
		_pending_home_destination = destination
		_pending_home_destination_kind = destination_kind
		_pending_home_route.clear()
		for route_value in route:
			if route_value is Vector3:
				_pending_home_route.append(route_value)
		_home_transition_start = _tavern_interior_world_position()
		_home_transition_end = tavern_entry_position
		_home_transition_kind = "tavern_exit"
		_home_transition_elapsed = 0.0
		has_target = false
		_route_points.clear()
		_route_index = 0
		is_interior_present = false
		visible = true
		life_enabled = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		set_physics_process(true)
		return
	if is_at_tavern and destination_kind == "tavern":
		refresh_tavern_stay()
		return
	if _home_transition_kind == "work_enter" and destination_kind != "work":
		# Se o turno terminar exatamente quando o NPC está entrando, ele conclui
		# a rotina do lado de fora em vez de ficar preso no estado de trabalho.
		_home_transition_kind = ""
		_home_transition_elapsed = 0.0
		global_position = work_position
		is_at_work = false
		is_at_home = false
		is_interior_present = false
		visible = true
		life_enabled = true
		collision_layer = 2
		collision_mask = 1
		set_physics_process(true)
		_apply_route(destination, destination_kind, route)
		return
	if _home_transition_kind != "":
		# Uma mudança de rotina durante uma transição atualiza o destino que será
		# seguido depois de terminar de atravessar a porta, sem reiniciar a animação.
		var leaving_home := _home_transition_kind == "exit" and destination_kind != "home"
		var leaving_work := _home_transition_kind == "work_exit" and destination_kind != "work"
		if leaving_home or leaving_work:
			_pending_home_destination = destination
			_pending_home_destination_kind = destination_kind
			_pending_home_route.clear()
			for route_value in route:
				if route_value is Vector3:
					_pending_home_route.append(route_value)
		return
	if is_at_work and destination_kind == "work":
		has_target = false
		velocity = Vector3.ZERO
		return
	if is_at_work and destination_kind != "work":
		_pending_home_destination = destination
		_pending_home_destination_kind = destination_kind
		_pending_home_route.clear()
		for route_value in route:
			if route_value is Vector3:
				_pending_home_route.append(route_value)
		global_position = _work_interior_world_position()
		_home_transition_start = global_position
		_home_transition_end = work_position
		_home_transition_kind = "work_exit"
		_home_transition_elapsed = 0.0
		is_at_work = false
		is_at_home = false
		is_interior_present = false
		has_target = false
		_route_points.clear()
		_route_index = 0
		visible = true
		life_enabled = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		set_physics_process(true)
		return
	if is_at_home and destination_kind == "home":
		has_target = false
		velocity = Vector3.ZERO
		return
	if is_at_home and destination_kind != "home":
		# A rotina não faz o NPC aparecer do nada na rua: primeiro ele atravessa
		# o vão da porta, com colisão temporariamente desligada, e só então começa
		# o trajeto público até o trabalho ou ponto de passeio.
		_pending_home_destination = destination
		_pending_home_destination_kind = destination_kind
		_pending_home_route.clear()
		for route_value in route:
			if route_value is Vector3:
				_pending_home_route.append(route_value)
		global_position = _home_interior_world_position()
		_home_transition_start = global_position
		_home_transition_end = home_position
		_home_transition_kind = "exit"
		_home_transition_elapsed = 0.0
		is_at_home = false
		is_interior_present = false
		has_target = false
		_route_points.clear()
		_route_index = 0
		visible = true # a parede oculta o sprite até que ele alcance a porta
		life_enabled = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		set_physics_process(true)
		return
	_apply_route(destination, destination_kind, route)


func _apply_route(destination: Vector3, destination_kind: String, route: Array) -> void:
	life_enabled = true
	set_physics_process(true)
	target_position = destination
	target_kind = destination_kind
	_route_points.clear()
	for route_value in route:
		if route_value is Vector3:
			var route_point: Vector3 = route_value
			if _route_points.is_empty() or Vector2(route_point.x - _route_points.back().x, route_point.z - _route_points.back().z).length() > 0.65:
				_route_points.append(route_point)
	if _route_points.is_empty() or Vector2(_route_points.back().x - destination.x, _route_points.back().z - destination.z).length() > 0.65:
		_route_points.append(destination)
	else:
		_route_points[_route_points.size() - 1] = destination
	_route_index = 0
	has_target = true
	_activity_timer = 0.0
	_blocked_timer = 0.0
	_detour_timer = 0.0
	_last_distance = INF
	_stuck_cycles = 0
	if _distance_to_active_waypoint() <= _active_arrive_distance():
		_advance_route_or_arrive()


func _home_interior_world_position() -> Vector3:
	var outward := home_front_direction
	outward.y = 0.0
	if outward.length_squared() < 0.001:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	# Usa o plano real da fachada, não a posição exterior de espera; entradas
	# deslocadas para evitar casas vizinhas continuam transitando pela porta certa.
	var inside := home_door_position - outward * HOME_INTERIOR_RECESS
	inside.y = home_position.y
	return inside


func _work_interior_world_position() -> Vector3:
	var outward := work_front_direction
	outward.y = 0.0
	if outward.length_squared() < 0.001:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	var inside := work_door_position - outward * HOME_INTERIOR_RECESS
	inside.y = work_position.y
	return inside


func _process_home_transition(delta: float) -> void:
	_home_transition_elapsed += delta
	var transition_duration: float = HOME_TRANSITION_SECONDS
	if _home_transition_kind in ["work_enter", "work_exit", "tavern_enter", "tavern_exit"]:
		var transition_distance := Vector2(
			_home_transition_end.x - _home_transition_start.x,
			_home_transition_end.z - _home_transition_start.z
		).length()
		transition_duration = clampf(transition_distance / WALK_SPEED, 0.72, 2.4)
	var progress := clampf(_home_transition_elapsed / transition_duration, 0.0, 1.0)
	# Ease in/out para que entrar e sair não pareça um teleporte brusco.
	var eased := progress * progress * (3.0 - 2.0 * progress)
	global_position = _home_transition_start.lerp(_home_transition_end, eased)
	velocity = Vector3.ZERO
	if progress < 1.0:
		return
	var finished_kind := _home_transition_kind
	_home_transition_kind = ""
	_home_transition_elapsed = 0.0
	if finished_kind == "enter":
		global_position = _home_interior_world_position()
		is_at_home = true
		is_at_work = false
		is_interior_present = false
		visible = false
		life_enabled = false
		collision_layer = 0
		collision_mask = 0
		has_target = false
		_route_points.clear()
		_route_index = 0
		set_physics_process(false)
		_activity_timer = 0.0
		return
	if finished_kind == "work_enter":
		global_position = _work_interior_world_position()
		is_at_home = false
		is_at_work = true
		is_interior_present = false
		visible = false
		life_enabled = false
		collision_layer = 0
		collision_mask = 0
		has_target = false
		_route_points.clear()
		_route_index = 0
		set_physics_process(false)
		_activity_timer = 0.0
		return
	if finished_kind == "tavern_enter":
		global_position = _tavern_interior_world_position()
		is_at_tavern = true
		is_at_home = false
		is_at_work = false
		is_interior_present = false
		interior_building_id = ""
		visible = false
		life_enabled = false
		collision_layer = 0
		collision_mask = 0
		has_target = false
		_route_points.clear()
		_route_index = 0
		set_physics_process(false)
		_activity_timer = 0.0
		return
	if finished_kind == "tavern_exit":
		global_position = tavern_entry_position
		is_at_tavern = false
		is_at_home = false
		is_at_work = false
		is_interior_present = false
		interior_building_id = ""
		visible = true
		life_enabled = true
		collision_layer = 2
		collision_mask = 1
		set_physics_process(true)
		var tavern_destination := _pending_home_destination
		var tavern_destination_kind := _pending_home_destination_kind
		var tavern_route: Array[Vector3] = []
		for route_value in _pending_home_route:
			if route_value is Vector3:
				tavern_route.append(route_value)
		_pending_home_route.clear()
		tavern_building_id = ""
		_apply_route(tavern_destination, tavern_destination_kind, tavern_route)
		return
	if finished_kind == "work_exit":
		global_position = work_position
		is_at_home = false
		is_at_work = false
		is_interior_present = false
		visible = true
		life_enabled = true
		collision_layer = 2
		collision_mask = 1
		set_physics_process(true)
		var work_destination := _pending_home_destination
		var work_destination_kind := _pending_home_destination_kind
		var work_route: Array[Vector3] = []
		for route_value in _pending_home_route:
			if route_value is Vector3:
				work_route.append(route_value)
		_pending_home_route.clear()
		_apply_route(work_destination, work_destination_kind, work_route)
		return
	# Fim da saída de uma casa: já alcançou a área exterior da porta e pode mover-se com física.
	global_position = home_position
	is_at_home = false
	is_at_work = false
	is_interior_present = false
	visible = true
	life_enabled = true
	collision_layer = 2
	collision_mask = 1
	set_physics_process(true)
	var destination := _pending_home_destination
	var destination_kind := _pending_home_destination_kind
	var route: Array[Vector3] = []
	for route_point in _pending_home_route:
		if route_point is Vector3:
			route.append(route_point)
	_pending_home_route.clear()
	_apply_route(destination, destination_kind, route)


func place_for_home_visit(interior_position: Vector3, building_id: String = "") -> void:
	# Materializa somente moradores que já estão logicamente em casa. É o mesmo
	# NPC do overworld, não um clone, portanto diálogos e missões continuam ligados.
	if not is_at_home or _quest_return_active:
		return
	_home_transition_kind = ""
	is_interior_present = true
	interior_building_id = building_id
	has_target = false
	_route_points.clear()
	_route_index = 0
	global_position = interior_position
	visible = true
	life_enabled = false
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	set_physics_process(false)


func place_for_tavern_visit(interior_position: Vector3, building_id: String = "") -> bool:
	# Usa a identidade persistente do NPC. Frequentadores já dentro da estalagem
	# podem estar invisíveis no mundo exterior; quem já chegou à porta termina a entrada
	# ao materializar no interior, em vez de voltar à calçada quando o jogador sai.
	var is_regular_here := is_at_tavern and tavern_building_id == building_id and building_id != ""
	var is_heading_here := target_kind == "tavern" and tavern_building_id == building_id and building_id != ""
	if is_interior_present or is_at_home or is_at_work:
		return false
	if not visible and not is_regular_here:
		return false
	var will_remain_inside := is_regular_here or is_heading_here
	_tavern_visit_state = {
		"position": _tavern_interior_world_position() if will_remain_inside else global_position,
		"visible": false if will_remain_inside else visible,
		"life_enabled": false if will_remain_inside else life_enabled,
		"collision_layer": 0 if will_remain_inside else collision_layer,
		"collision_mask": 0 if will_remain_inside else collision_mask,
		"physics_processing": false if will_remain_inside else is_physics_processing(),
		"is_at_tavern": will_remain_inside,
		"tavern_building_id": building_id if will_remain_inside else tavern_building_id,
		"interior_building_id": interior_building_id,
		"target_kind": "tavern" if will_remain_inside else target_kind
	}
	_home_transition_kind = ""
	_home_transition_elapsed = 0.0
	is_interior_present = true
	interior_building_id = building_id
	has_target = false
	_route_points.clear()
	_route_index = 0
	global_position = interior_position
	visible = true
	life_enabled = false
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	set_physics_process(false)
	return true


func restore_tavern_visit() -> void:
	if _tavern_visit_state.is_empty():
		return
	global_position = _tavern_visit_state.get("position", global_position)
	is_interior_present = false
	_home_transition_kind = ""
	_home_transition_elapsed = 0.0
	is_at_tavern = bool(_tavern_visit_state.get("is_at_tavern", false))
	tavern_building_id = str(_tavern_visit_state.get("tavern_building_id", ""))
	interior_building_id = str(_tavern_visit_state.get("interior_building_id", ""))
	target_kind = str(_tavern_visit_state.get("target_kind", target_kind))
	has_target = false
	_route_points.clear()
	_route_index = 0
	velocity = Vector3.ZERO
	visible = bool(_tavern_visit_state.get("visible", true))
	life_enabled = bool(_tavern_visit_state.get("life_enabled", true))
	collision_layer = int(_tavern_visit_state.get("collision_layer", 2))
	collision_mask = int(_tavern_visit_state.get("collision_mask", 1))
	set_physics_process(bool(_tavern_visit_state.get("physics_processing", true)))
	_tavern_visit_state.clear()


func place_for_work_visit(interior_position: Vector3, building_id: String = "") -> void:
	if not is_at_work or is_interior_present:
		return
	_home_transition_kind = ""
	is_interior_present = true
	interior_building_id = building_id
	has_target = false
	_route_points.clear()
	_route_index = 0
	global_position = interior_position
	visible = true
	life_enabled = false
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	set_physics_process(false)


func restore_work_after_visit() -> void:
	if not is_interior_present or not is_at_work:
		return
	is_interior_present = false
	interior_building_id = ""
	has_target = false
	_route_points.clear()
	_route_index = 0
	velocity = Vector3.ZERO
	_home_transition_kind = ""
	if _quest_return_active:
		global_position = work_position
		is_at_work = false
		is_at_home = false
		visible = true
		life_enabled = true
		collision_layer = 2
		collision_mask = 1
		set_physics_process(true)
		return
	global_position = _work_interior_world_position()
	visible = false
	life_enabled = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)


func restore_home_after_visit() -> void:
	if not is_interior_present:
		return
	is_interior_present = false
	interior_building_id = ""
	has_target = false
	_route_points.clear()
	_route_index = 0
	velocity = Vector3.ZERO
	_home_transition_kind = ""
	if _quest_return_active:
		# Uma missão pronta tem prioridade sobre o recolhimento doméstico: o NPC
		# aguarda na porta para que o jogador consiga encontrá-lo após sair.
		global_position = home_position
		is_at_home = false
		visible = true
		life_enabled = true
		collision_layer = 2
		collision_mask = 1
		set_physics_process(true)
		return
	global_position = _home_interior_world_position()
	is_at_home = true
	visible = false
	life_enabled = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)


func _active_waypoint() -> Vector3:
	if _route_index >= 0 and _route_index < _route_points.size():
		return _route_points[_route_index]
	return target_position


func _distance_to_active_waypoint() -> float:
	var waypoint: Vector3 = _active_waypoint()
	return Vector2(waypoint.x - global_position.x, waypoint.z - global_position.z).length()


func _is_on_home_approach() -> bool:
	# Verifica o corredor exterior da própria porta. Serve apenas como recuperação
	# quando uma colisão da fachada impede a cápsula de alcançar o ponto virtual.
	var outward := home_front_direction
	outward.y = 0.0
	if outward.length_squared() < 0.001:
		return false
	outward = outward.normalized()
	var offset := Vector3(global_position.x - home_door_position.x, 0.0, global_position.z - home_door_position.z)
	var along_front := offset.dot(outward)
	var lateral_offset := offset - outward * along_front
	return along_front >= -0.25 and along_front <= 10.5 and lateral_offset.length() <= 1.5


func _active_arrive_distance() -> float:
	# A cápsula física não consegue encostar na parede da construção. O antigo
	# limite de 0.72 m era menor que a distância residual até o ponto de entrada,
	# então o NPC colidia com a fachada e ficava parado do lado de fora.
	var is_final_waypoint: bool = _route_index >= _route_points.size() - 1
	if is_final_waypoint and target_kind == "home":
		return 1.10
	if is_final_waypoint and target_kind in ["work", "guard_gate"]:
		return 1.6
	return ARRIVE_DISTANCE


func _advance_route_or_arrive() -> void:
	if _route_index < _route_points.size() - 1:
		_route_index += 1
		_blocked_timer = 0.0
		_detour_timer = 0.0
		_last_distance = INF
		return
	_arrive()


func needs_new_activity() -> bool:
	return not ambient_conversation_locked and _home_transition_kind == "" and not is_at_home and not is_at_work and not is_at_tavern and not has_target and _activity_timer <= 0.0


func set_stream_active(active: bool) -> void:
	# Fora do raio do jogador, NPCs não precisam desenhar sprite, nem participar
	# da física. A identidade e a residência continuam presentes no registro.
	# Contratantes com entrega pendente reaparecem na entrada externa da casa
	# quando o jogador se aproxima, mesmo se a rotina noturna os simulou em casa.
	if is_at_home and _quest_return_active and active:
		global_position = home_position
		is_at_home = false
		has_target = false
		_route_points.clear()
		_route_index = 0
		velocity = Vector3.ZERO
	if is_at_work and _quest_return_active and active:
		global_position = work_position
		is_at_work = false
		has_target = false
		_route_points.clear()
		_route_index = 0
		velocity = Vector3.ZERO
	if is_at_work:
		life_enabled = false
		visible = false
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		return
	if is_at_home:
		life_enabled = false
		visible = false
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		return
	if is_at_tavern and not _quest_return_active:
		# Frequentadores que já atravessaram a porta continuam dentro do prédio;
		# a cena do interior materializa esse mesmo NPC quando o jogador entra.
		life_enabled = false
		visible = false
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		return
	life_enabled = active
	visible = active
	collision_layer = 2 if active else 0
	collision_mask = 1 if active else 0
	set_physics_process(active)


func simulate_offscreen(destination: Vector3, destination_kind: String) -> void:
	# Simulação de alto nível para habitantes distantes: a rotina avança sem
	# precisar executar movimento físico a cada frame fora da área do jogador.
	_home_transition_kind = ""
	_home_transition_elapsed = 0.0
	is_interior_present = false
	interior_building_id = ""
	if destination_kind == "home":
		global_position = _home_interior_world_position()
	elif destination_kind == "work":
		global_position = _work_interior_world_position()
	elif destination_kind == "tavern":
		global_position = _tavern_interior_world_position()
	else:
		global_position = destination
	target_position = destination
	target_kind = destination_kind
	has_target = false
	velocity = Vector3.ZERO
	is_at_home = destination_kind == "home"
	is_at_work = destination_kind == "work"
	is_at_tavern = destination_kind == "tavern"
	if not is_at_tavern:
		tavern_building_id = ""
	life_enabled = false
	visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	_activity_timer = 12.0 if destination_kind == "work" else randf_range(5.0, 12.0)
	_blocked_timer = 0.0
	_detour_timer = 0.0
	_stuck_cycles = 0


func configure_world_knowledge(knowledge: Dictionary) -> void:
	known_places.clear()
	known_place_ids.clear()
	regional_facts.clear()
	var place_values: Variant = knowledge.get("known_places", [])
	if place_values is Array:
		for place_value in place_values:
			if not (place_value is Dictionary):
				continue
			var place: Dictionary = place_value.duplicate(true)
			known_places.append(place)
			var place_id := str(place.get("id", ""))
			if place_id != "" and not known_place_ids.has(place_id):
				known_place_ids.append(place_id)
			if str(place.get("kind", "")) == "city":
				var known_city_id := str(place.get("city_id", ""))
				if known_city_id != "" and not known_city_ids.has(known_city_id):
					known_city_ids.append(known_city_id)
	var fact_values: Variant = knowledge.get("regional_facts", [])
	if fact_values is Array:
		for fact_value in fact_values:
			regional_facts.append(str(fact_value))


func knows_place(query_place_id: String) -> bool:
	return known_place_ids.has(query_place_id)


func known_place_by_kind(kinds: Array) -> Dictionary:
	for place in known_places:
		if kinds.has(str(place.get("kind", ""))):
			return place.duplicate(true)
	return {}


func knows_city(query_city_id: String) -> bool:
	return known_city_ids.has(query_city_id)


func knows_house(query_house_id: String) -> bool:
	return known_house_ids.has(query_house_id)


func knows_household_member(query_npc_id: String) -> bool:
	return household_member_ids.has(query_npc_id)


func home_information() -> Dictionary:
	return {
		"npc_id": npc_id,
		"person_name": display_name,
		"city_id": city_id,
		"origin_city_id": origin_city_id,
		"city_name": city_name,
		"home_id": home_id,
		"home_name": home_name,
		"household_member_ids": household_member_ids.duplicate(),
		"household_member_names": household_member_names.duplicate()
	}


func _physics_process(delta: float) -> void:
	if _combat_downed:
		_combat_recovery_timer = maxf(0.0, _combat_recovery_timer - delta)
		velocity = Vector3.ZERO
		if _combat_recovery_timer <= 0.0:
			_recover_from_combat_knockout()
		return
	if is_unique_witch and witch_state != "allied" and witch_location == "lake":
		velocity = Vector3.ZERO
		has_target = false
		return
	if _home_transition_kind != "":
		_process_home_transition(delta)
		return
	if not life_enabled or is_at_home:
		velocity = Vector3.ZERO
		return
	if ambient_conversation_locked:
		if _find_nearest_monster(NPC_MONSTER_FLEE_RADIUS) == null:
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
				move_and_slide()
			else:
				velocity.y = 0.0
			return
		# Uma ameaça próxima interrompe a conversa e devolve controle ao comportamento
		# de combate/fuga, em vez de deixar os moradores parados falando sob ataque.
		ambient_conversation_locked = false
		ambient_conversation_partner_id = ""
	if _tick_monster_reaction(delta):
		return
	_activity_timer = maxf(0.0, _activity_timer - delta)
	if not has_target:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
			move_and_slide()
		else:
			velocity.y = 0.0
		return
	var active_waypoint: Vector3 = _active_waypoint()
	var distance_before := Vector2(active_waypoint.x - global_position.x, active_waypoint.z - global_position.z).length()
	if distance_before <= _active_arrive_distance():
		_advance_route_or_arrive()
		return
	var steering_target := active_waypoint
	if _detour_timer > 0.0:
		_detour_timer = maxf(0.0, _detour_timer - delta)
		steering_target = _detour_point
	var direction := Vector3(steering_target.x - global_position.x, 0.0, steering_target.z - global_position.z).normalized()
	# Evita que habitantes atravessem uns aos outros quando cruzam ou chegam
	# simultaneamente a destinos próximos. A separação é suave, não uma colisão dura.
	var separation := _separation_steering()
	if separation.length_squared() > 0.001:
		var separation_weight := NPC_SEPARATION_WEIGHT
		if target_kind == "home":
			# Mantém espaço na rua, mas permite aproximar-se da entrada da casa.
			separation_weight *= clampf(_distance_to_active_waypoint() / 3.0, 0.0, 1.0)
		direction = (direction + separation * separation_weight).normalized()
	var travel_speed: float = WALK_SPEED
	if target_kind == "witch_companion":
		travel_speed = maxf(WALK_SPEED, companion_move_speed)
	velocity.x = direction.x * travel_speed
	velocity.z = direction.z * travel_speed
	var was_on_floor: bool = is_on_floor()
	if was_on_floor:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	# CharacterBody3D não sobe degraus automaticamente. Sem esta pequena assistência,
	# as escadas trianguladas das construções bloqueiam a cápsula, fazendo o NPC
	# tentar desvios laterais em loop apesar de o destino estar logo atrás dos degraus.
	if was_on_floor:
		_try_step_up(delta)
	move_and_slide()
	var active_after_move: Vector3 = _active_waypoint()
	var distance_after := Vector2(active_after_move.x - global_position.x, active_after_move.z - global_position.z).length()
	if distance_after <= _active_arrive_distance():
		_advance_route_or_arrive()
		return
	if get_slide_collision_count() > 0 and distance_after >= distance_before - 0.025:
		_blocked_timer += delta
	else:
		_blocked_timer = maxf(0.0, _blocked_timer - delta * 1.5)
	if _blocked_timer >= 0.85:
		# Se o obstáculo é a própria fachada e o NPC já está no corredor frontal da
		# porta, iniciar a entrada é melhor que repetir desvios eternamente do lado de fora.
		var is_final_home_waypoint: bool = target_kind == "home" and _route_index >= _route_points.size() - 1
		if is_final_home_waypoint and distance_after <= 2.25 and _is_on_home_approach():
			_arrive()
			return
		_detour_side *= -1.0
		var side := Vector3(-direction.z, 0.0, direction.x) * _detour_side
		_detour_point = global_position + side * 2.2
		_detour_point.y = global_position.y
		_detour_timer = 1.0
		_blocked_timer = 0.0
		_stuck_cycles += 1
		if _stuck_cycles >= 7:
			# Não considera chegada se uma colisão impedir o caminho até a porta.
			# A rotina tenta novamente após uma pausa curta.
			has_target = false
			_route_points.clear()
			_route_index = 0
			_activity_timer = randf_range(1.0, 2.5)
			velocity = Vector3.ZERO


func _combat_hp_for_role() -> int:
	match role:
		"guarda": return 72
		"bruxa": return 80
		"ferreiro": return 58
		"estalajadeiro": return 48
		_: return 42


func can_be_targeted_by_monsters() -> bool:
	if not is_inside_tree() or not visible or not life_enabled or _combat_downed:
		return false
	if is_at_home or is_at_work or is_interior_present or _home_transition_kind != "":
		return false
	if bool(get_meta("city_occupation_hidden", false)):
		return false
	if is_unique_witch and witch_state == "dead":
		return false
	return true


func _can_fight_monsters() -> bool:
	if is_unique_witch:
		return witch_state == "allied"
	if role == "guarda":
		return true
	if age_stage != "adult":
		return false
	if role in ["ferreiro", "estalajadeiro"]:
		return true
	if personality in ["corajoso", "protetor", "impulsivo", "temperamental"]:
		return true
	# Uma pequena parte dos adultos comuns enfrenta criaturas, de forma estável por
	# identidade; isso evita transformar cada aldeão num combatente idêntico.
	return posmod(npc_id.hash(), 100) < 16


func _is_valid_monster_target(value: Variant) -> bool:
	if not (value is Node3D) or not is_instance_valid(value):
		return false
	var monster := value as Node3D
	if not monster.is_inside_tree() or not monster.is_in_group("overworld_enemies") or not monster.visible:
		return false
	if int(monster.get("hp")) <= 0:
		return false
	return true


func _find_nearest_monster(max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_distance_sq := max_distance * max_distance
	for value in get_tree().get_nodes_in_group("overworld_enemies"):
		if not _is_valid_monster_target(value):
			continue
		var monster := value as Node3D
		var dx: float = monster.global_position.x - global_position.x
		var dz: float = monster.global_position.z - global_position.z
		var distance_sq: float = dx * dx + dz * dz
		if distance_sq >= best_distance_sq or not _has_combat_line_of_sight(monster):
			continue
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = monster
	return best


func _has_combat_line_of_sight(monster: Node3D) -> bool:
	if not is_instance_valid(monster) or get_world_3d() == null:
		return false
	var ray_from := global_position + Vector3.UP * 1.1
	var ray_to := monster.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == monster


func _tick_monster_reaction(delta: float) -> bool:
	_combat_attack_timer = maxf(0.0, _combat_attack_timer - delta)
	_combat_scan_timer -= delta
	if _combat_scan_timer <= 0.0 or not _is_valid_monster_target(_combat_target):
		var scan_radius: float = NPC_MONSTER_FIGHT_RADIUS if _can_fight_monsters() else NPC_MONSTER_FLEE_RADIUS
		_combat_target = _find_nearest_monster(scan_radius)
		_combat_scan_timer = NPC_MONSTER_SCAN_SECONDS
	if _is_valid_monster_target(_combat_target):
		var enemy := _combat_target as Node3D
		var offset := Vector3(enemy.global_position.x - global_position.x, 0.0, enemy.global_position.z - global_position.z)
		var distance := offset.length()
		if _can_fight_monsters():
			_combat_flee_timer = 0.0
			_engage_monster(enemy, offset, distance, delta)
			return true
		if distance <= NPC_MONSTER_FLEE_RADIUS:
			_combat_flee_timer = 1.4
			_flee_from_monster(enemy, offset, delta)
			return true
	if _combat_flee_timer > 0.0:
		_combat_flee_timer = maxf(0.0, _combat_flee_timer - delta)
		var nearest := _find_nearest_monster(NPC_MONSTER_FLEE_RADIUS + 4.0)
		if is_instance_valid(nearest):
			_flee_from_monster(nearest, Vector3.ZERO, delta)
			return true
	return false


func _engage_monster(enemy: Node3D, offset: Vector3, distance: float, delta: float) -> void:
	var direction := offset.normalized() if distance > 0.001 else Vector3.ZERO
	var move_speed := 2.35 if role == "guarda" else 2.0
	if distance > NPC_MONSTER_MELEE_RANGE:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _combat_attack_timer <= 0.0 and enemy.has_method("take_hit"):
			_combat_attack_timer = 1.05 if role == "guarda" else 1.25
			var damage_amount := 3
			if role == "guarda":
				damage_amount = 7
			elif role in ["ferreiro", "estalajadeiro"]:
				damage_amount = 4
			enemy.call("take_hit", damage_amount, direction, self)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	if is_on_floor():
		_try_step_up(delta)
	move_and_slide()


func _flee_from_monster(enemy: Node3D, _offset: Vector3, delta: float) -> void:
	var away := Vector3(global_position.x - enemy.global_position.x, 0.0, global_position.z - enemy.global_position.z)
	if away.length_squared() < 0.001:
		var angle := float(abs(npc_id.hash()) % 6283) / 1000.0
		away = Vector3(cos(angle), 0.0, sin(angle))
	away = away.normalized()
	velocity.x = away.x * NPC_MONSTER_FLEE_SPEED
	velocity.z = away.z * NPC_MONSTER_FLEE_SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	if is_on_floor():
		_try_step_up(delta)
	move_and_slide()


func receive_monster_hit(dmg: int, attacker_position: Vector3) -> void:
	if not can_be_targeted_by_monsters():
		return
	var amount := maxi(1, dmg)
	if is_unique_witch:
		if witch_state != "allied":
			take_hit(amount, global_position - attacker_position)
			return
		witch_hp = maxi(0, witch_hp - amount)
		if is_instance_valid(society) and society.has_method("set_witch_hp"):
			society.call("set_witch_hp", witch_hp)
		if is_instance_valid(sprite):
			sprite.modulate = Color(1.0, 0.3, 0.3)
			create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
		if witch_hp <= 0:
			witch_state = "dead"
			if is_instance_valid(society) and society.has_method("set_witch_state"):
				society.call("set_witch_state", "dead")
			remove_from_group("enemies")
			queue_free()
		return
	combat_hp = maxi(0, combat_hp - amount)
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 0.3, 0.3)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if combat_hp <= 0:
		_combat_downed = true
		_combat_recovery_timer = 45.0
		_combat_target = null
		velocity = Vector3.ZERO
		visible = false
		collision_layer = 0
		collision_mask = 0


func _recover_from_combat_knockout() -> void:
	_combat_downed = false
	combat_hp = maxi(12, int(combat_max_hp * 0.55))
	var hidden_by_city: bool = bool(get_meta("city_occupation_hidden", false))
	visible = not hidden_by_city and not is_at_home and not is_at_work and not is_interior_present
	collision_layer = 0 if hidden_by_city or is_at_home or is_at_work or is_interior_present else 2
	collision_mask = 0 if hidden_by_city or is_at_home or is_at_work or is_interior_present else 1
	set_physics_process(life_enabled)


func _try_step_up(delta: float) -> void:
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if horizontal_motion.length_squared() < 0.000001:
		return
	# Só tenta subir quando o deslocamento normal realmente está bloqueado.
	if not test_move(global_transform, horizontal_motion):
		return
	var step_heights: Array[float] = [0.16, 0.24, 0.32, 0.42, 0.50]
	for step_height_value in step_heights:
		var step_height: float = float(step_height_value)
		var rise := Vector3.UP * step_height
		# Não tenta subir se há uma parede/teto imediatamente acima da cápsula.
		if test_move(global_transform, rise):
			continue
		var raised_transform := global_transform
		raised_transform.origin += rise
		if test_move(raised_transform, horizontal_motion):
			continue
		# Confirma que há uma superfície caminhável na posição de chegada; isto
		# evita usar o step-up para saltar muros ou sair de uma borda.
		var probe_distance: float = maxf(horizontal_motion.length(), 0.40)
		var landing_origin: Vector3 = raised_transform.origin + horizontal_motion.normalized() * probe_distance
		var ray_from: Vector3 = landing_origin + Vector3.UP * 0.15
		var ray_to: Vector3 = landing_origin - Vector3.UP * (step_height + 0.30)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		var excluded: Array[RID] = [get_rid()]
		query.exclude = excluded
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
		if hit_normal.dot(Vector3.UP) < 0.70:
			continue
		var hit_position: Vector3 = hit.get("position", landing_origin)
		var rise_amount := hit_position.y - global_position.y
		if rise_amount < 0.06 or rise_amount > step_height + 0.10:
			continue
		# Eleva a base até a superfície do degrau. O move_and_slide que vem a seguir
		# executa o avanço horizontal normal desta mesma frame.
		global_position.y = hit_position.y + 0.025
		return


func _arrive() -> void:
	# Não teleporta o NPC para o centro exato do destino: isso fazia vários
	# habitantes terminarem empilhados no mesmo ponto apesar de terem caminhado.
	# O limiar de chegada já garante proximidade suficiente para portas e balcões.
	velocity = Vector3.ZERO
	has_target = false
	_detour_timer = 0.0
	_blocked_timer = 0.0
	_route_points.clear()
	_route_index = 0
	if target_kind == "home":
		# Ao alcançar a entrada começa uma curta transição pela porta. O sprite
		# atravessa a fachada, fica oculto pelo edifício e só então é marcado em casa.
		_home_transition_kind = "enter"
		_home_transition_elapsed = 0.0
		_home_transition_start = global_position
		_home_transition_end = _home_interior_world_position()
		collision_layer = 0
		collision_mask = 0
		life_enabled = true
		set_physics_process(true)
		_activity_timer = 0.0
	elif target_kind == "work":
		# Chegou à entrada da oficina/loja: atravessa o vão e fica no interior
		# lógico do estabelecimento durante o expediente, em vez de esperar na calçada.
		_home_transition_kind = "work_enter"
		_home_transition_elapsed = 0.0
		_home_transition_start = global_position
		_home_transition_end = _work_interior_world_position()
		collision_layer = 0
		collision_mask = 0
		life_enabled = true
		set_physics_process(true)
		_activity_timer = 0.0
	elif target_kind == "guard_gate":
		# O guarda permanece no posto durante a sua vez de vigia antes de rodar
		# para outra entrada ou sair para patrulhar.
		_activity_timer = randf_range(24.0, 42.0)
	elif target_kind == "tavern":
		# A chegada ocorre na frente do prédio; em seguida o NPC atravessa a porta
		# e fica oculto no interior lógico, não circulando ao redor da fachada.
		if tavern_building_id != "":
			_home_transition_kind = "tavern_enter"
			_home_transition_elapsed = 0.0
			_home_transition_start = global_position
			_home_transition_end = _tavern_interior_world_position()
			collision_layer = 0
			collision_mask = 0
			life_enabled = true
			set_physics_process(true)
			_activity_timer = 0.0
		else:
			_activity_timer = randf_range(40.0, 80.0)
	else:
		_activity_timer = 14.0 if target_kind == "work" else randf_range(4.0, 11.0)


func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value != "" and not result.has(value):
			result.append(value)
	return result


func can_chat_ambiently() -> bool:
	if not is_instance_valid(ambient_line_label) or not visible or (is_at_home and not is_interior_present):
		return false
	if ambient_conversation_locked or _home_transition_kind != "" or _quest_return_active:
		return false
	if is_at_work and not is_interior_present:
		return false
	# Caminhadas públicas podem ser interrompidas. Viagens para casa/serviço e
	# transições de porta não podem, para não quebrar a rotina nem prender alguém.
	if not is_interior_present and has_target and target_kind in ["home", "work"]:
		return false
	if not is_interior_present and target_kind in ["home", "work"]:
		return false
	return life_enabled or is_interior_present


func begin_ambient_conversation(partner_id: String) -> void:
	ambient_conversation_locked = true
	ambient_conversation_partner_id = partner_id
	# Cancela apenas o passeio público atual. Depois da conversa a rotina atribui
	# um destino novo; não é necessário tentar retomar uma rota que ficou velha.
	has_target = false
	target_kind = "conversation"
	_route_points.clear()
	_route_index = 0
	_detour_timer = 0.0
	_blocked_timer = 0.0
	velocity = Vector3.ZERO
	_activity_timer = AMBIENT_CHAT_STOP_SECONDS
	clear_ambient_line()
	set_physics_process(true)


func end_ambient_conversation() -> void:
	clear_ambient_line()
	ambient_conversation_locked = false
	ambient_conversation_partner_id = ""
	if target_kind == "conversation":
		target_kind = "idle"
	has_target = false
	_route_points.clear()
	_route_index = 0
	velocity = Vector3.ZERO
	_activity_timer = randf_range(2.0, 3.8)


func personalize_ambient_line(base_line: String, topic: String, beat: int) -> String:
	# A fala já foi escrita com base na personalidade, profissão e contexto do NPC.
	# Não acrescentamos bordões genéricos nem comentários sobre a própria conversa.
	var clean_line := base_line.strip_edges()
	remember_spoken_dialogue(clean_line, topic)
	return clean_line


func remember_spoken_dialogue(base_line: String, topic: String = "") -> void:
	# Registra apenas texto realmente mostrado ao jogador, sem contar duas vezes a
	# mesma fala quando ele usa “Voltar” no diálogo.
	var clean_line := base_line.strip_edges()
	if clean_line == "" or recent_ambient_lines.has(clean_line):
		return
	recent_ambient_lines.push_front(clean_line)
	while recent_ambient_lines.size() > 14:
		recent_ambient_lines.pop_back()
	ambient_speech_count += 1


func personalize_player_dialogue(base_line: String, topic: String) -> String:
	# Decide uma alternativa para saudações repetidas, mas deixa o registro da fala
	# para o momento em que a caixa de diálogo realmente a exibe.
	var line := base_line.strip_edges()
	if topic == "saudação" and recent_ambient_lines.has(line):
		line = _alternate_repeated_greeting(line)
	return line


func _alternate_repeated_greeting(previous_line: String) -> String:
	var choices: Array[String] = []
	if previous_line.contains("agradeço") or previous_line.contains("cumprir o combinado"):
		choices = [
			"O combinado está cumprido. O que traz você aqui desta vez?",
			"Se veio tratar de outra coisa, pode falar.",
			"Já não tenho mais nada a cobrar daquele trabalho. O que precisa agora?"
		]
	else:
		match speech_style:
			"formal": choices = ["É bom rever você. Em que posso ajudar?", "Pois não? Do que precisa hoje?"]
			"ironico": choices = ["Ora, você de novo. O que aconteceu agora?", "Já voltou? Tomara que não seja outra encrenca."]
			"observador": choices = ["Você voltou. Aconteceu alguma coisa no caminho?", "Notou algo diferente desde a última vez?"]
			"poetico": choices = ["A estrada trouxe você de volta. O que precisa?", "O caminho foi longo? Diga, em que posso ajudar?"]
			"coloquial": choices = ["Oi de novo. O que foi?", "E aí, aconteceu alguma coisa?"]
			"reservado": choices = ["Ah, você voltou. Diga.", "Pode falar. Estou ouvindo."]
			"supersticioso": choices = ["Você voltou. Espero que seja por um bom motivo.", "Foi tudo bem no caminho? As coisas andam estranhas."]
			"pratico": choices = ["Vamos direto ao ponto. O que precisa?", "Tenho trabalho esperando. Diga o que veio buscar."]
			"curioso": choices = ["E então, descobriu alguma coisa desde a última vez?", "Trouxe alguma novidade do caminho?"]
			_: choices = ["Olá outra vez. O que deseja?", "Oi. Veio falar sobre o quê?"]
	for choice in choices:
		if not recent_ambient_lines.has(choice):
			return choice
	return choices[posmod(ambient_speech_count, choices.size())]


func clear_ambient_line() -> void:
	ambient_line_timer = 0.0
	set_process(false)
	if is_instance_valid(ambient_line_label):
		ambient_line_label.visible = false
		ambient_line_label.text = ""


func show_ambient_line(line: String, duration: float = 2.8) -> void:
	if not is_instance_valid(ambient_line_label) or line.strip_edges() == "":
		return
	ambient_line_label.text = _caption_with_line_breaks(line.strip_edges(), 34)
	ambient_line_label.visible = true
	ambient_line_timer = duration
	set_process(true)


func set_ambient_conversation_partner(partner_id: String) -> void:
	# Compatibilidade com chamadas antigas: esta função agora inicia a pausa real.
	if partner_id == "":
		end_ambient_conversation()
	else:
		begin_ambient_conversation(partner_id)


func remember_world_event(event: Dictionary) -> void:
	var event_id := str(event.get("id", ""))
	if event_id == "":
		return
	for existing in known_world_events:
		if str(existing.get("id", "")) == event_id:
			return
	known_world_events.push_front(event.duplicate(true))
	while known_world_events.size() > MAX_KNOWN_WORLD_EVENTS:
		var remove_index := -1
		# Avistamentos comuns envelhecem antes de feitos importantes como concluir
		# um trabalho ou derrotar uma criatura na frente de testemunhas.
		for i in range(known_world_events.size() - 1, -1, -1):
			var kind := str(known_world_events[i].get("kind", ""))
			if kind not in ["quest_completed", "monster_defeated"]:
				remove_index = i
				break
		if remove_index < 0:
			for i in range(known_world_events.size() - 1, -1, -1):
				if str(known_world_events[i].get("kind", "")) != "quest_completed":
					remove_index = i
					break
		if remove_index < 0:
			remove_index = known_world_events.size() - 1
		known_world_events.remove_at(remove_index)


func _caption_with_line_breaks(line: String, max_chars: int) -> String:
	if line.length() <= max_chars:
		return line
	var split_at: int = line.rfind(" ", max_chars)
	if split_at < int(max_chars * 0.55):
		split_at = max_chars
	var first_line := line.substr(0, split_at).strip_edges()
	var remaining := line.substr(split_at).strip_edges()
	if remaining.length() > max_chars:
		var second_split: int = remaining.rfind(" ", max_chars)
		if second_split < int(max_chars * 0.55):
			second_split = max_chars
		return first_line + "\n" + remaining.substr(0, second_split).strip_edges() + "\n" + remaining.substr(second_split).strip_edges()
	return first_line + "\n" + remaining


func can_trade(context: Dictionary = {}) -> bool:
	# Ferreiros e curandeiras mantêm o comportamento comercial já existente.
	if role != "mercador":
		return SHOP_ROLES.has(role)
	# Ambulantes podem negociar quando encontrados na estrada, na cidade ou
	# hospedados numa estalagem. Não precisam possuir uma loja permanente.
	if merchant_type == "itinerant":
		return not is_at_home or is_interior_present
	# Um comerciante residente só atende no próprio estabelecimento, durante
	# o expediente. Estar de folga ou dentro da própria casa não abre o comércio.
	var inside_id := str(context.get("inside_building_id", ""))
	var inside_kind := str(context.get("inside_building_kind", ""))
	return is_at_work and is_interior_present and inside_id != "" and inside_id == work_building_id and inside_kind == "shop"


func take_hit(dmg: int, push_dir: Vector3) -> void:
	# Apenas a bruxa única é um alvo de combate entre os NPCs sociais.
	if not is_unique_witch or witch_state in ["dead", "allied"]:
		return
	witch_hp = maxi(0, witch_hp - maxi(1, dmg))
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 0.3, 0.3)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if is_instance_valid(society) and society.has_method("set_witch_hp"):
		society.call("set_witch_hp", witch_hp)
	if witch_hp <= 0:
		witch_state = "dead"
		if is_instance_valid(society) and society.has_method("set_witch_state"):
			society.call("set_witch_state", "dead")
		if is_instance_valid(game) and game.has_method("show_msg"):
			game.call("show_msg", "A bruxa caiu. A lenda de Brumaférrea terminou aqui.")
		remove_from_group("enemies")
		queue_free()


func _witch_society_quest_status() -> String:
	if is_instance_valid(society) and society.has_method("get_witch_quest_status"):
		return str(society.call("get_witch_quest_status"))
	return "not_started"


func _witch_material_counts() -> Dictionary:
	var copper := 0
	var herbs := 0
	if is_instance_valid(game) and game.player != null and is_instance_valid(game.player):
		copper = int(game.player.call("resource_count", "copper_ore"))
		for herb_id in ["healing_herb", "bitterleaf", "silverleaf"]:
			herbs += int(game.player.call("resource_count", str(herb_id)))
	return {"copper": copper, "herbs": herbs}


func _unique_witch_dialogue_tree(context: Dictionary = {}) -> Dictionary:
	var allied: bool = witch_state == "allied"
	var quest_status: String = _witch_society_quest_status()
	var materials: Dictionary = _witch_material_counts()
	var tactic: String = str(context.get("witch_companion_tactic", "adaptive"))
	var tactic_labels: Dictionary = {
		"adaptive": "Autônoma e adaptável",
		"aggressive": "Ofensiva",
		"defensive": "Defensiva e protetora",
		"hold": "Manter posição",
		"follow": "Acompanhar à distância"
	}
	var start_options: Array = []
	if allied:
		# Depois da aliança, ela deixa de ser tratada como uma lenda a ser investigada.
		# A conversa passa a refletir a amizade e a parceria que se desenvolveram.
		start_options = [
			{"label": "Conversar como companheiros", "next": "witch_friendship"},
			{"label": "Comentar o que acontece ao redor", "next": "witch_observation"},
			{"label": "Perguntar como ela está", "next": "witch_wellbeing"},
			{"label": "Pedir conselho", "next": "witch_advice"},
			{"label": "Definir estratégia de combate · %s" % str(tactic_labels.get(tactic, "Autônoma e adaptável")), "next": "witch_tactics"}
		]
	else:
		start_options = [
			{"label": "Perguntar sobre a lenda", "next": "witch_lore"},
			{"label": "Perguntar por que vive aqui", "next": "witch_hideout"}
		]
		if quest_status == "active":
			start_options.append({"label": "Entregar cobre e ervas (%d/2 · %d/3)" % [int(materials.get("copper", 0)), int(materials.get("herbs", 0))], "next": "witch_materials"})
		else:
			start_options.append({"label": "Perguntar como conquistar sua confiança", "next": "witch_offer"})
		start_options.append({"label": _local_observation_option_label(context), "next": "witch_observation"})

	if allied and age_stage == "adult" and partner_id == "":
		start_options.append({"label": "Flertar", "next": "witch_flirt"})
	start_options.append({"label": "Encerrar conversa", "action": ""})

	var observation_text: String = _local_observation_dialogue(context)
	var wellbeing_text := "Estou bem. E você? Não precisa inventar um assunto só para falar comigo."
	if int(context.get("player_hp", 1)) < int(context.get("player_max_hp", 1)) * 0.55:
		wellbeing_text = "Eu estou bem, mas você está longe disso. Sente-se um pouco, se puder. Não precisa bancar o invulnerável comigo."
	elif int(context.get("nearby_enemy_count", 0)) > 0:
		wellbeing_text = "Estou alerta. Tem movimento por perto; vou observar os lados antes de gastar magia. A gente conversa depois, não vou ignorar o perigo."
	elif int(context.get("weather", 0)) in [3, 5]:
		wellbeing_text = "Estou bem, apesar desse tempo. A chuva e a neve podem esconder rastros; é melhor prestar atenção ao terreno e aos sons."

	var familiarity: float = float(player_relationship.get("familiarity", 0.0))
	var affection: float = float(player_relationship.get("affection", 0.0))
	var friendship_text := "Não sou muito boa em conversa leve, mas podemos tentar. É melhor do que passar cada estrada ouvindo apenas os próprios passos."
	if familiarity >= 40.0:
		friendship_text = "Você já não é só alguém que provou que sabe cumprir a palavra. Gosto de ter você por perto, embora às vezes ainda precise de silêncio."
	elif familiarity >= 15.0:
		friendship_text = "Ainda estou me acostumando a dividir o caminho com alguém, mas a estrada fica menos tediosa com você. Não espalhe isso por aí."
	if affection >= 35.0:
		friendship_text += " E, para ser sincera, sinto falta da sua companhia quando você se afasta por muito tempo."
	if bool(context.get("player_wounded", false)):
		friendship_text += " Agora, deixe eu olhar esse ferimento antes que piore."
	elif bool(context.get("player_is_mounted", false)):
		friendship_text += " Só não desapareça a galope sem avisar; acompanhar alguém montado exige mais atenção do que parece."
	elif int(context.get("nearby_enemy_count", 0)) > 0:
		friendship_text += " A gente continua depois. Tem algo se movendo por perto, e não vou dar as costas para isso."
	elif int(context.get("weather", 0)) in [3, 4, 5]:
		friendship_text += " Com esse tempo, é melhor procurar abrigo antes de seguir viagem."

	var flirt_text := "Você quer me dizer alguma coisa? Estou ouvindo."
	if affection >= 55.0:
		flirt_text = "Vai continuar me olhando assim ou finalmente vai dizer o que está pensando?"
	elif familiarity >= 30.0:
		flirt_text = "Essa sua expressão costuma vir antes de alguma pergunta difícil. Desta vez é diferente?"
	elif familiarity >= 12.0:
		flirt_text = "Você parece querer dizer alguma coisa. Pode falar; não prometo facilitar."

	var advice_text := "Escolha o próximo destino por uma razão, não só porque o caminho está aberto. E lembre: recuar quando algo parece errado também é uma decisão."
	if bool(context.get("player_wounded", false)):
		advice_text = "Primeiro, cuide dos ferimentos e recupere o fôlego. Coragem não adianta muito se você estiver fraco demais para reagir à próxima ameaça."
	elif int(context.get("nearby_enemy_count", 0)) > 0:
		var threat_name := str(context.get("nearest_enemy_name", "uma criatura"))
		advice_text = "Tem perigo por perto — %s, pelo que consigo ver. Não avance às cegas. Observe o terreno, mantenha uma rota de recuo e não deixe que encurralem você." % threat_name
	elif float(context.get("regional_threat", 0.0)) >= 32.0:
		advice_text = "As estradas daqui não estão seguras. Planeje o caminho e evite parar onde não tenha espaço para recuar."
	elif int(context.get("weather", 0)) in [3, 4, 5]:
		advice_text = "Com esse tempo, a visibilidade engana. Prefira caminhos conhecidos e procure abrigo se a tempestade apertar."
	elif float(context.get("hour", 12.0)) < 5.0 or float(context.get("hour", 12.0)) >= 21.0:
		advice_text = "Viajar à noite evita parte do movimento, mas também dificulta perceber uma ameaça a tempo. Silêncio não quer dizer segurança."

	var opening_line := "Não costumo receber visitas. O que você quer saber?"
	if allied:
		opening_line = _witch_companion_greeting(context, familiarity, affection)
	var tree: Dictionary = {
		"start": {"text": opening_line, "options": start_options},
		"witch_lore": {"text": "É mais fácil me chamar de lenda do que admitir que há lugares onde as regras da cidade não valem. Quase todo rumor sobre mim vem de alguém que nunca chegou perto.", "options": [{"label": "Voltar", "next": "start"}]},
		"witch_hideout": {"text": "Escolhi este lugar porque quase ninguém passa por aqui por acaso. A floresta me deixa em paz; no lago, ao menos, ninguém aparece de surpresa pela porta.", "options": [{"label": "Voltar", "next": "start"}]},
		"witch_offer": {"text": "Promessas não provam nada. Traga dois minérios de cobre e três ervas úteis: erva restauradora, folha amarga ou folha-prateada. Volte com isso, e conversamos.", "options": [{"label": "Aceitar a tarefa", "action": "witch_quest_accept"}, {"label": "Deixar para outra hora", "next": "start"}]},
		"witch_materials": {"text": "Preciso de dois minérios de cobre e três ervas úteis. Você tem %d/2 minérios e %d/3 ervas. Traga os materiais quando estiver pronto." % [int(materials.get("copper", 0)), int(materials.get("herbs", 0))], "options": [{"label": "Entregar os materiais", "action": "witch_quest_turnin"}, {"label": "Voltar", "next": "start"}]},
		"witch_friendship": {"text": friendship_text, "options": [{"label": "Continuar", "next": "start"}, {"label": "Encerrar conversa", "action": ""}]},
		"witch_advice": {"text": advice_text, "options": [{"label": "Obrigado pelo conselho", "next": "start"}, {"label": "Encerrar conversa", "action": ""}]},
		"witch_allied": {"text": "Já fizemos um acordo. Agora sigo ao seu lado. Minhas magias estão com você; talvez, com o tempo, eu confie em você para algo além disso.", "options": [{"label": "Voltar", "next": "start"}]},
		"witch_tactics": {"text": "Escolha como prefere que eu lute. Mesmo assim, vou observar os inimigos e o terreno; não vou correr atrás de você enquanto houver uma ameaça ao alcance.", "options": [
			{"label": "Adaptar-me à situação", "action": "witch_tactic:adaptive"},
			{"label": "Postura ofensiva · pressionar inimigos", "action": "witch_tactic:aggressive"},
			{"label": "Postura defensiva · proteger e curar", "action": "witch_tactic:defensive"},
			{"label": "Manter posição e lançar magias", "action": "witch_tactic:hold"},
			{"label": "Acompanhar à distância segura", "action": "witch_tactic:follow"},
			{"label": "Voltar", "next": "start"}
		]},
		"witch_observation": {"text": observation_text, "options": [{"label": "Voltar", "next": "start"}]},
		"witch_wellbeing": {"text": wellbeing_text, "options": [{"label": "Voltar", "next": "start"}]},
		"witch_flirt": {"text": flirt_text, "options": [
			{"label": "Fazer um elogio sincero", "action": "npc_flirt:gentle"},
			{"label": "Fazer uma brincadeira carinhosa", "action": "npc_flirt:playful"},
			{"label": "Deixar para outra hora", "next": "start"}
		]}
	}
	if allied:
		# Os tópicos de lenda, esconderijo e missão antiga não existem mais depois da aliança.
		tree.erase("witch_lore")
		tree.erase("witch_hideout")
		tree.erase("witch_offer")
		tree.erase("witch_materials")
		tree.erase("witch_allied")
	else:
		tree.erase("witch_friendship")
		tree.erase("witch_advice")
		tree.erase("witch_flirt")
		tree.erase("witch_tactics")
		tree.erase("witch_wellbeing")
	return tree


func _witch_companion_greeting(context: Dictionary, familiarity: float, affection: float) -> String:
	# A primeira fala é curta e responde ao momento; não repete uma apresentação a cada conversa.
	if int(context.get("nearby_enemy_count", 0)) > 0:
		return "Espera um pouco. Tem movimento por perto. Vamos terminar isso primeiro."
	if bool(context.get("player_wounded", false)):
		return "Você está machucado. Depois me conta o que houve; primeiro, cuide disso."
	if bool(context.get("player_is_mounted", false)):
		return "Vai seguir a cavalo? Só não suma na primeira curva; não tenho pernas de cavalo."
	if int(context.get("weather", 0)) == 5:
		return "Não gosto dessa nevasca. Se a trilha desaparecer, vamos procurar abrigo."
	if int(context.get("weather", 0)) in [2, 3, 4]:
		return "Esse tempo não ajuda em nada. Vamos ver se abre antes de seguir muito longe."
	var hour := float(context.get("hour", 12.0))
	if hour >= 22.0 or hour < 5.0:
		return "Ainda acordado? Bom... eu também não estava com sono."
	if affection >= 40.0:
		return "Oi. Estava pensando se você ia parar para conversar hoje."
	if familiarity >= 40.0:
		return "Ah, você. A viagem fica menos silenciosa quando resolve falar comigo."
	if familiarity >= 15.0:
		return "Tem alguma coisa em mente ou só quer companhia por um minuto?"
	return "Tudo certo? Se não tiver, pode falar."


func dialogue(context: Dictionary = {}) -> Dictionary:
	if is_unique_witch:
		conversations_with_player += 1
		return _unique_witch_dialogue_tree(context)
	# A árvore é montada a cada interação. As opções dependem do trabalho, hora,
	# clima, perigo regional e do que este habitante realmente sabe.
	conversations_with_player += 1
	var tree: Dictionary = {}
	var start_options: Array = []
	var hour := float(context.get("hour", 12.0))
	var weather := int(context.get("weather", 0))
	var threat := float(context.get("regional_threat", 0.0))
	var inside_kind := str(context.get("inside_building_kind", ""))
	var in_tavern := inside_kind in ["inn", "tavern"]

	if role == "mercador":
		if can_trade(context):
			start_options.append({"label": _shop_option_label(context), "action": "shop"})
	elif SHOP_ROLES.has(role):
		start_options.append({"label": _shop_option_label(context), "action": "shop"})

	_add_dialogue_topic(tree, start_options, "occupation", _occupation_option_label(context), _occupation_dialogue(context))
	var town_question_label := "Como vão as coisas em %s?" % city_name if city_name != "" else "Como vão as coisas por aqui?"
	_add_dialogue_topic(tree, start_options, "town", town_question_label, _town_dialogue(context))
	_add_dialogue_topic(tree, start_options, "places", "Pedir uma indicação", _places_dialogue(context))
	_add_dialogue_topic(tree, start_options, "situation", _local_observation_option_label(context), _local_observation_dialogue(context))
	if in_tavern:
		_add_dialogue_topic(tree, start_options, "tavern_food", "Comentar a comida e a bebida", _tavern_food_dialogue(context))
		_add_dialogue_topic(tree, start_options, "tavern_regulars", "Perguntar sobre os frequentadores", _tavern_regulars_dialogue(context))

	var event := _latest_relevant_event(context)
	if not event.is_empty():
		_add_dialogue_topic(tree, start_options, "news", _event_option_label(event), _event_dialogue(event))

	if threat >= 32.0:
		_add_dialogue_topic(tree, start_options, "safety", "As estradas estão seguras?", _safety_dialogue(context))

	if weather >= 2:
		_add_dialogue_topic(tree, start_options, "weather", "Falar do tempo", _weather_dialogue(context))

	if hour >= 20.0 or hour < 6.0:
		_add_dialogue_topic(tree, start_options, "night", "Como fica a cidade à noite?", _night_dialogue(context))

	if household_data_ready:
		_add_dialogue_topic(tree, start_options, "household", "Falar da família", _household_dialogue())

	# Cada pessoa tem um assunto próprio, derivado de seus interesses e objetivos.
	# Isso muda tanto a opção apresentada quanto a resposta, inclusive entre NPCs
	# que exercem a mesma profissão.
	var personal_topic_label := "Falar sobre " + personal_interest
	_add_dialogue_topic(tree, start_options, "personal", personal_topic_label, _personal_topic_dialogue(context))
	var relationship_familiarity := float(player_relationship.get("familiarity", 0.0))
	if conversations_with_player >= 2 or relationship_familiarity >= 15.0:
		_add_dialogue_topic(tree, start_options, "future", "Perguntar sobre seus planos", _personal_goal_dialogue(context))

	# O flerte é uma pequena conversa com escolha e reação, não uma mensagem flutuante.
	if age_stage == "adult" and partner_id == "":
		start_options.append({"label": "Flertar", "next": "flirt_opening"})
		tree["flirt_opening"] = {"text": _flirt_opening_dialogue(), "options": [
			{"label": "Dizer um elogio sincero", "action": "npc_flirt:gentle"},
			{"label": "Fazer uma brincadeira carinhosa", "action": "npc_flirt:playful"},
			{"label": "Deixar para outra hora", "next": "start"}
		]}
	# Saudação e respostas passam pela voz individual e pelo histórico recente do NPC.
	tree["start"] = {"text": _dialogue_greeting(context), "options": start_options}
	# Só a saudação será dita quando a conversa abrir. Não registre como falas
	# pronunciadas as respostas das opções que o jogador ainda nem escolheu.
	if has_method("personalize_player_dialogue"):
		var start_record: Dictionary = tree["start"]
		start_record["text"] = personalize_player_dialogue(str(start_record.get("text", "")), "saudação")
		tree["start"] = start_record
	return tree


func _flirt_opening_dialogue() -> String:
	var familiarity := float(player_relationship.get("familiarity", 0.0))
	var affection := float(player_relationship.get("affection", 0.0))
	if affection >= 50.0:
		return "Você está me olhando desse jeito há um tempo. O que foi?"
	if familiarity >= 25.0:
		match speech_style:
			"ironico":
				return "Essa conversa está ficando pessoal. Vai me dizer o que tem em mente?"
			"formal":
				return "Você parece querer me dizer algo. Estou ouvindo."
			"reservado":
				return "Quer me dizer alguma coisa? Pode falar, sem pressa."
			"coloquial":
				return "Essa cara é de elogio ou de encrenca?"
			"curioso":
				return "Você parece ter uma coisa em mente. O que é?"
			_:
				return "Você parece querer dizer alguma coisa. Pode falar."
	return "Vai dizer alguma coisa ou está só testando minha paciência?"


func _places_dialogue(context: Dictionary) -> String:
	var knowledge_value: Variant = context.get("world_knowledge", {})
	var knowledge: Dictionary = knowledge_value if knowledge_value is Dictionary else {}
	var places_value: Variant = knowledge.get("known_places", known_places)
	var places: Array = places_value if places_value is Array else []
	var city := str(knowledge.get("city_name", city_name if city_name != "" else "esta região"))
	var role_name := str(knowledge.get("role", role))
	var sentences: Array[String] = []
	var seen_kinds: Dictionary = {}
	# Resposta curta e concreta: um serviço local, um marco/região e, se
	# apropriado, um assentamento vizinho. O NPC não finge conhecer o mapa inteiro.
	var priority_groups := [
		["workshop", "shop", "inn", "town_hall"],
		["cave", "ruins", "camp", "shrine", "watchtower", "dungeon", "mine", "grove", "meadow", "forest", "resource_ore", "resource_herbs", "resource_mixed"],
		["city"]
	]
	for group in priority_groups:
		for place_value in places:
			if not (place_value is Dictionary):
				continue
			var place: Dictionary = place_value
			var kind := str(place.get("kind", ""))
			if not group.has(kind) or seen_kinds.has(kind):
				continue
			var place_name := str(place.get("name", "um lugar daqui"))
			var description := str(place.get("description", "é um ponto conhecido da região"))
			if kind == "city":
				sentences.append("%s fica %s daqui; %s." % [place_name, _distance_phrase(float(place.get("distance", 0.0))), description])
			elif bool(place.get("same_city", false)):
				sentences.append("Em %s, %s %s." % [city, place_name, description])
			else:
				sentences.append("%s fica %s, %s; %s." % [place_name, str(place.get("direction", "nos arredores")), _distance_phrase(float(place.get("distance", 0.0))), description])
			seen_kinds[kind] = true
			break
		if sentences.size() >= 2:
			break
	var facts_value: Variant = knowledge.get("regional_facts", regional_facts)
	if facts_value is Array and not facts_value.is_empty() and sentences.size() < 3:
		var fact := str(facts_value[0])
		if role_name == "mensageiro":
			var city_names: Array = knowledge.get("known_city_names", [])
			if city_names.size() > 1:
				fact = "Preciso conhecer os caminhos entre %s e %s; meu trabalho é levar mensagens e distinguir o que vi do que apenas me contaram." % [str(city_names[0]), str(city_names[1])]
		sentences.append(fact)
	if sentences.is_empty():
		match role_name:
			"guarda": return "Conheço os caminhos que costumo patrulhar e os acessos da cidade. Para além disso, é melhor perguntar a quem veio de viagem."
			"ferreiro": return "Na oficina eu consigo orientar você. Para lugares mais distantes, tente falar com um mercador ou mensageiro."
			"curandeira": return "Conheço alguns lugares onde costumo colher ervas, mas não quero mandar você a um ponto que não confirmei."
			"mercador": return "Conheço as rotas que uso para negociar. O resto depende do que os viajantes trouxeram de notícia."
			"mensageiro": return "Posso indicar os caminhos por onde já passei. Não vou adivinhar uma rota que não conheço."
			_: return "Não conheço cada canto daqui. Na estalagem ou perto do portão costuma haver alguém que sabe mais do que eu."
	# Diz o que sabe e para por aí; o NPC não precisa transformar a resposta num guia turístico.
	return " ".join(sentences)


func _distance_phrase(distance: float) -> String:
	if distance < 120.0: return "a poucos passos"
	if distance < 300.0: return "a pouca distância"
	if distance < 650.0: return "mais adiante"
	return "bem longe"


func _context_place_by_kind(context: Dictionary, kinds: Array) -> Dictionary:
	var knowledge_value: Variant = context.get("world_knowledge", context)
	var knowledge: Dictionary = knowledge_value if knowledge_value is Dictionary else {}
	var places_value: Variant = knowledge.get("known_places", known_places)
	if not (places_value is Array): return {}
	for place_value in places_value:
		if not (place_value is Dictionary): continue
		var place: Dictionary = place_value
		if kinds.has(str(place.get("kind", ""))): return place.duplicate(true)
	return {}


func _tavern_food_dialogue(context: Dictionary) -> String:
	var place_name := str(context.get("inside_building_name", "esta estalagem"))
	var hour := float(context.get("hour", 18.0))
	if role == "estalajadeiro":
		if hour >= 20.0 or hour < 5.0:
			return "A cozinha já está no ritmo da noite. Em %s, uma refeição quente e uma bebida costumam trazer gente de volta, mesmo depois de um dia ruim." % place_name
		return "Em %s, tento manter comida quente e bebida em condições. Quem viaja não precisa de luxo; precisa saber que encontrará algo decente." % place_name
	var variants: Array[String] = []
	if personality == "bem-humorado":
		variants = ["A comida está melhor do que parece. É o cheiro que engana; depois da primeira colher, fica difícil parar.", "Uma boa bebida não resolve todos os problemas, mas ajuda a ouvir uma história até o fim.", "Se o ensopado continuar assim, vou ter de inventar uma desculpa para voltar amanhã."]
	elif personality == "desconfiado":
		variants = ["A comida é aceitável e o preço está à vista. Para mim, isso já é mais confiável que muita promessa.", "Bebo devagar. Em lugar cheio, gosto de manter a cabeça clara e saber quem entrou.", "Não é um banquete, mas pelo menos sei o que estou pagando."]
	elif personality == "reservado":
		variants = ["Gosto da comida simples daqui. Dá para descansar sem precisar conversar com todo mundo.", "Uma bebida quente e um canto tranquilo já bastam para mim.", "A cozinha faz o que promete. É bom ter um lugar assim no fim do dia."]
	else:
		variants = ["O ensopado daqui é bom para espantar o frio. Depois de uma caminhada, vale cada moeda.", "A bebida local é forte, mas combina com as histórias que se ouvem por aqui.", "Prefiro uma refeição simples e quente a gastar o dobro num prato cheio de enfeites."]
	var choice := posmod(abs((npc_id + "|tavern-food|" + str(conversations_with_player)).hash()), variants.size())
	return "%s %s" % ["Aqui em %s," % place_name, variants[choice]]


func _tavern_regulars_dialogue(context: Dictionary) -> String:
	var place_name := str(context.get("inside_building_name", "esta estalagem"))
	var guest_count := maxi(0, int(context.get("tavern_occupant_count", 0)))
	if role == "estalajadeiro":
		if guest_count >= 4:
			return "Hoje há bastante gente em %s. Alguns vêm pela comida, outros pelas notícias; com o tempo, aprendi a reconhecer quem só quer descansar e quem veio atrás de rumores." % place_name
		return "O movimento muda conforme a hora. Em %s, os viajantes trazem histórias diferentes dos moradores daqui, e costumo prestar atenção nos dois." % place_name
	if guest_count >= 4:
		match personality:
			"fofoqueiro": return "Hoje tem bastante gente por aqui. Se escutar com atenção, sempre aparece uma história nova — embora nem todas mereçam crédito."
			"desconfiado": return "A casa está cheia. Isso traz notícias, mas também gente que fala mais do que sabe."
			"bem-humorado": return "Com tanta gente, é difícil terminar uma bebida sem ouvir três histórias e uma discussão sobre quem paga a próxima rodada."
			_: return "Tem bastante gente por aqui. É uma boa ocasião para ouvir o que os viajantes estão contando."
	if guest_count >= 2:
		return "Não está lotado, mas há companhia suficiente. Às vezes é mais fácil conversar quando o salão não está barulhento."
	return "Está mais quieto agora. Talvez o pessoal ainda esteja trabalhando ou só venha mais tarde, quando a estrada começa a esvaziar."


func _personal_goal_dialogue(context: Dictionary) -> String:
	var goal_text := str(personal_goal)
	var answers: Dictionary = {
		"juntar moedas suficientes para dias difíceis": "Estou tentando guardar umas moedas para quando as coisas apertarem. Basta uma doença ou uma carga perdida para levar o que a gente juntou.",
		"melhorar a vida da minha família": "Quero dar uma vida melhor à minha família. Não é um plano grandioso, mas é o que me faz levantar cedo.",
		"ser reconhecido pelo meu ofício": "Quero que reconheçam meu trabalho pela qualidade, não só pelo preço. Ainda falta convencer algumas pessoas disso.",
		"conhecer o que existe além destas estradas": "Quero ver o que há para lá destas estradas. Às vezes penso em partir; depois lembro de tudo que me prende aqui.",
		"conseguir um pouco de paz e sossego": "Quero alguns dias sem dívida, briga nem gente batendo à porta. Parece pedir demais.",
		"pagar uma dívida antiga": "Preciso quitar uma dívida antiga. Não gosto de dever favores, muito menos moedas.",
		"aprender algo que ainda não sei": "Quero aprender algo novo, mas o trabalho sempre toma o tempo que eu ia reservar para começar.",
		"proteger as pessoas em quem confio": "Quero manter a salvo quem confia em mim. Não posso estar em todo lugar, então faço o que consigo.",
		"abrir meu próprio negócio": "Quero abrir meu próprio negócio um dia. Por enquanto, toda moeda já tem destino antes de chegar à bolsa.",
		"deixar alguma coisa de valor para o futuro": "Quero deixar alguma coisa de valor para quem vier depois. Não precisa ser riqueza; um trabalho bem-feito também fica."
	}
	var answer := str(answers.get(goal_text, "Tenho tentado %s. Ainda estou descobrindo como chegar lá." % goal_text))
	if speech_style == "ironico" and personality == "bem-humorado":
		answer += " Vamos ver se o mundo resolve colaborar."
	elif personality == "reservado" and float(player_relationship.get("familiarity", 0.0)) < 30.0:
		answer = "Não costumo falar disso com qualquer pessoa. " + answer
	elif speech_style == "curioso":
		answer += " Ainda estou tentando descobrir qual é o primeiro passo."
	return answer


func _personal_topic_dialogue(context: Dictionary) -> String:
	var interest := personal_interest.to_lower()
	var latest_event := _latest_relevant_event(context)
	var variants: Array[String] = []
	if interest.contains("história") or interest.contains("armas antigas") or interest.contains("artesãos"):
		variants = [
			"As ruínas daqui já eram velhas antes de muita gente nascer. O que me intriga é saber quem ainda se lembrava delas quando a cidade cresceu.",
			"Sempre aparece alguém dizendo que conhece a história verdadeira das ruínas. Curioso como nunca concordam entre si.",
			"Gosto de ouvir histórias antigas, mas presto mais atenção quando duas pessoas contam a mesma coisa de formas diferentes."
		]
	elif interest.contains("taverna") or interest.contains("comidas") or interest.contains("comida"):
		variants = [
			"Uma tigela de ensopado quente vale mais que um banquete frio depois de andar o dia inteiro.",
			"Na estalagem, a comida é melhor quando a cozinha está cheia. Quando sobra pouco movimento, às vezes sobra pouco tempero também.",
			"Não sou difícil para comer. Só não gosto de pagar caro por um prato que mal sustenta alguém."
		]
	elif interest.contains("costumes") or interest.contains("leis"):
		variants = [
			"Tem costume daqui que ninguém sabe explicar; só dizem que sempre foi assim. Às vezes isso basta, às vezes não.",
			"Os mais velhos guardam certas tradições com unhas e dentes. Queria saber quais ainda fazem sentido e quais ficaram só por hábito.",
			"É curioso como uma regra muda de uma rua para outra, mesmo quando todo mundo jura que segue o mesmo costume."
		]
	elif interest.contains("canções") or interest.contains("festas"):
		variants = [
			"Faz tempo que a praça não tem uma festa de verdade. A cidade parece menor quando todo mundo só vai do trabalho para casa.",
			"Cada família canta aquela velha canção de um jeito. Acho que ninguém lembra mais qual era a primeira versão.",
			"Faz falta uma noite de música por aqui. A praça anda quieta demais."
		]
	elif interest.contains("animais") or interest.contains("rastros"):
		variants = [
			"Depois da chuva, os rastros ficam mais fáceis de ler. Pena que também desaparecem depressa quando o chão seca.",
			"Os bichos percebem a mudança do tempo antes de nós. Quando somem dos campos, costumo prestar atenção.",
			"Gosto de observar os animais daqui. Eles conhecem atalhos que muita gente só descobre depois de se perder."
		]
	elif interest.contains("estradas") or interest.contains("viajantes") or interest.contains("segurança"):
		variants = [
			"Quem viaja bastante aprende a reconhecer uma estrada ruim pelo silêncio. Às vezes falta até o barulho dos animais.",
			"Cada viajante conta uma versão diferente do caminho. Quase sempre dá para descobrir quem realmente esteve lá fazendo perguntas simples.",
			"Uma estrada segura vale mais do que uma rota curta. Poupa carga, tempo e gente."
		]
	elif interest.contains("deuses") or interest.contains("presságios"):
		variants = [
			"Respeito os Sete, mas não acho que toda coincidência seja um sinal. Às vezes a chuva é só chuva.",
			"Minha avó dizia que cada deus deixa marcas diferentes no mundo. Nunca consegui decidir se ela falava sério ou só queria que eu prestasse atenção.",
			"As pessoas lembram dos deuses quando precisam de alguma coisa. Eu me pergunto o que fazemos nos dias em que tudo vai bem."
		]
	elif interest.contains("ferramentas") or interest.contains("ofícios") or interest.contains("metalurgia") or interest.contains("trabalhos manuais"):
		variants = [
			"Gosto de ver uma ferramenta bem-feita. Dá para notar quando alguém teve paciência em vez de só querer terminar logo.",
			"Uma peça ruim costuma quebrar na pior hora. Por isso prefiro pagar uma vez por algo decente.",
			"Quase todo ofício tem um truque que os mais velhos não ensinam de primeira. É preciso trabalhar ao lado deles para aprender."
		]
	elif interest.contains("preços") or interest.contains("mercado") or interest.contains("mercadorias") or interest.contains("comerciais"):
		variants = [
			"Quando a estrada fica perigosa, o preço sobe mesmo antes de faltar mercadoria. O medo também entra na conta.",
			"No mercado, todo mundo quer um bom negócio; só muda o que cada um considera um bom preço.",
			"Antes de comprar, gosto de perguntar de onde veio a mercadoria. Às vezes a resposta explica mais que a etiqueta."
		]
	elif interest.contains("família") or interest.contains("famílias"):
		variants = [
			"A gente passa o dia resolvendo problemas dos outros e, quando chega em casa, ainda há uma porção de coisas esperando.",
			"Queria ter mais tempo para os meus. Trabalho nunca falta, mas o tempo passa do mesmo jeito.",
			"Uma cidade pode ter muralhas fortes e ainda assim depender de quem põe comida na mesa de cada casa."
		]
	elif interest.contains("plantas") or interest.contains("ervas") or interest.contains("cura") or interest.contains("remédios"):
		variants = [
			"Uma planta pode ajudar ou fazer mal. O que importa não é só reconhecer a folha, mas saber quando colher e como preparar.",
			"As ervas ficam mais difíceis de encontrar quando o tempo vira. Tento guardar um pouco antes que alguém precise delas.",
			"Nem toda dor precisa de magia. Às vezes, água limpa, repouso e a planta certa já resolvem bastante coisa."
		]
	elif interest.contains("rumores") or interest.contains("notícias") or interest.contains("outras cidades"):
		variants = [
			"Notícia de fora chega atrasada e, quando chega, já passou por tanta boca que é difícil saber o que sobrou de verdade.",
			"Prefiro uma notícia curta de quem esteve lá a uma história grandiosa de quem ouviu de outra pessoa.",
			"Os mensageiros sabem mais do que dizem, mas também carregam recados que não lhes pertencem."
		]
	else:
		variants = [
			"Gosto de reparar nas pequenas coisas. É nelas que a vida daqui muda primeiro.",
			"Nem todo dia traz novidade, mas quase sempre há alguma coisa que vale lembrar.",
			"Tenho minhas manias. Esta, pelo menos, não custa nada."
		]

	var seed := (npc_id + "|personal|" + str(conversations_with_player) + "|" + interest).hash()
	var variant_index := posmod(abs(seed), variants.size())
	var line := variants[variant_index]
	if not latest_event.is_empty() and personality == "fofoqueiro":
		var detail := str(latest_event.get("detail", "alguma coisa nas redondezas"))
		var gossip_leads: Array[String] = [
			"Ah, quase me esqueci: ouvi falar de %s." % detail,
			"E tem outra coisa circulando por aí: %s." % detail,
			"Mudando de assunto, parece que %s virou conversa na cidade." % detail
		]
		line += " " + gossip_leads[posmod(abs(seed + 17), gossip_leads.size())]
		if str(latest_event.get("knowledge", "witness")) == "heard":
			line += " Ainda não sei quem viu isso de perto."
	elif personality == "desconfiado":
		if interest.contains("notícias") or interest.contains("rumores") or interest.contains("viajantes"):
			line += " Mas vou esperar alguém confirmar antes de repetir isso."
		elif interest.contains("erva") or interest.contains("planta") or interest.contains("cura"):
			line += " Já vi conselho bem-intencionado dar errado. Prefiro conferir antes."
		elif interest.contains("deus") or interest.contains("presságio") or interest.contains("costume"):
			line += " Não digo que seja mentira; só não gosto de acreditar sem pensar."
	elif personality == "bem-humorado" and conversations_with_player % 3 == 0:
		var asides: Array[String] = [" Pronto, já falei mais do que pretendia.", " Se continuar perguntando, vou acabar cobrando pela conversa.", " Agora me deixe voltar ao que estava fazendo antes que eu esqueça."]
		line += asides[posmod(abs(seed + 31), asides.size())]
	return line

func _add_dialogue_topic(tree: Dictionary, options: Array, key: String, label_text: String, body: String) -> void:
	tree[key] = {
		"text": body,
		"options": [
			{"label": "Voltar", "next": "start"},
			{"label": "Encerrar conversa", "action": ""}
		]
	}
	options.append({"label": label_text, "next": key})


func _dialogue_greeting(context: Dictionary) -> String:
	var hour := float(context.get("hour", 12.0))
	var weather := int(context.get("weather", 0))
	var threat := float(context.get("regional_threat", 0.0))
	var gratitude := float(player_relationship.get("gratitude", 0.0))
	var familiarity := float(player_relationship.get("familiarity", 0.0))
	var latest_event := _latest_relevant_event(context)
	if gratitude >= 8.0 and str(latest_event.get("kind", "")) == "quest_completed" and str(latest_event.get("informed_npc_id", "")) == npc_id:
		return "Você voltou. Ainda agradeço por cumprir o combinado; não é todo dia que alguém mantém a palavra."
	if familiarity >= 60.0 and conversations_with_player > 2:
		var familiar_turn := posmod(abs((npc_id + "|familiar-greeting|" + str(conversations_with_player)).hash()), 3)
		match speech_style:
			"formal": return ["Bom ver você de novo. Em que posso ajudar hoje?", "É bom saber que voltou em segurança. O que precisa?", "Ora, uma visita conhecida. Diga, como posso ajudar?"][familiar_turn]
			"ironico": return ["Você de novo. Espero que tenha trazido uma história melhor que a última.", "Olha só quem resolveu aparecer. Devo me preocupar?", "Já estava achando que tinha encontrado uma estrada sem volta."][familiar_turn]
			"observador": return ["Vi você passar por aqui outro dia. Como foi o caminho depois disso?", "Parece que anda bastante por esta região. Alguma coisa mudou na estrada?", "Você conhece este lugar melhor agora. Notou algo diferente?"][familiar_turn]
			"poetico": return ["O caminho trouxe você de volta. Como tem sido a viagem?", "Até os rostos conhecidos parecem diferentes quando a estação muda.", "Há algo reconfortante em rever alguém depois de dias de estrada."][familiar_turn]
		match personality:
			"bem-humorado": return ["Ora, um rosto conhecido! Já estava achando que tinha sumido da região.", "Olha quem voltou. A praça andava quieta demais.", "De volta? Então o dia ainda pode melhorar."][familiar_turn]
			"reservado": return ["Bom ver você novamente. O que precisa?", "Ah, você voltou. Podemos conversar um pouco.", "Já nos conhecemos. Diga logo o que procura."][familiar_turn]
			"desconfiado": return ["Já sei quem você é. Ainda prefiro ver as coisas com meus próprios olhos.", "Você de novo. Espero que não traga problemas para %s." % _place_name(), "Já conversamos antes. Vamos ver o que tem a dizer desta vez."][familiar_turn]
			_: return ["Que bom ver você outra vez. O que o traz por aqui?", "Como têm sido as coisas desde a última visita?", "Você voltou. Precisa de alguma coisa ou veio conversar?"][familiar_turn]
	if str(context.get("inside_building_kind", "")) in ["inn", "tavern"]:
		match personality:
			"bem-humorado": return "Chegou na hora certa; uma conversa fica melhor com o salão cheio e a caneca perto."
			"reservado": return "Pode ficar à vontade. Aqui dentro dá para conversar sem enfrentar o vento lá fora."
			"desconfiado": return "Na estalagem, prefiro ouvir primeiro e tirar conclusões depois. O que deseja saber?"
			"fofoqueiro": return "Você veio pela comida ou pelos rumores? Hoje ouvi umas coisas interessantes."
			_: return "Boa noite. Aqui sempre aparece alguém com uma história para contar."
	if conversations_with_player > 1:
		match personality:
			"desconfiado":
				return "Você de novo. Espero que não traga problemas para %s." % _place_name()
			"bem-humorado":
				return ["Ora, olha quem voltou!", "Já está sentindo falta da minha companhia?", "De volta? Pelo menos você movimenta as coisas por aqui."][abs(npc_id.hash() + conversations_with_player) % 3]
			"reservado":
				return "Ah, você voltou. O que precisa?"
			"fofoqueiro":
				return "Você chegou numa boa hora. Tenho ouvido umas coisas por aí." if not known_world_events.is_empty() else "Ora, você voltou. Alguma novidade?"
			"curioso":
				return "De volta! E então, o que descobriu desde a última vez?"
			_:
				return "Olá outra vez. O que deseja?"

	if not _latest_relevant_event(context).is_empty() and threat >= 45.0:
		return "Bom que apareceu. As coisas estão estranhas por aqui ultimamente."
	if weather == 5:
		return "Entre logo. Uma nevasca dessas apaga as trilhas e torna perigoso ficar na estrada."
	if weather == 4:
		return "A neve já está cobrindo o caminho. Se veio de longe, espero que tenha roupas quentes."
	if weather == 3:
		return "Entre logo, se puder. Não é tempo para ficar parado nessa tempestade elétrica."
	if weather == 2:
		return "Dia molhado, não é? O caminho vai ficar ruim se essa chuva continuar."
	if conversations_with_player == 1:
		var first_greeting := "Bom dia" if hour >= 6.0 and hour < 12.0 else "Boa tarde" if hour < 18.0 else "Boa noite"
		match speech_style:
			"formal": return "%s. Diga, como posso ajudar?" % first_greeting
			"ironico": return "Se veio trazer uma notícia, espero que seja melhor que as últimas."
			"observador": return "Você não é daqui, é? A gente acaba reconhecendo quem cruza a praça todo dia."
			"poetico": return "A luz está bonita hoje. Pena que quase ninguém para para notar."
			"coloquial": return "Oi. Está procurando alguém ou só dando uma volta?"
			"supersticioso": return "Que os Sete mantenham seu caminho livre. O que precisa?"
	if hour < 6.0 or hour >= 21.0:
		return "Boa noite. Não é comum ver viajantes circulando a esta hora."
	if hour < 11.0:
		return "Bom dia. Espero que a estrada tenha sido gentil com você."
	if hour < 18.0:
		match personality:
			"desconfiado": return "Pois não? Estou ocupado, então vamos direto ao assunto."
			"bem-humorado": return "Saudações! Um rosto novo sempre quebra a monotonia."
			"reservado": return "Olá. Precisa de alguma coisa?"
			"fofoqueiro": return "Ah, um viajante! Está procurando alguma coisa ou alguma história?"
			"curioso": return "Olá! Veio de longe? Como estão as estradas?"
			_: return "Boa tarde, viajante. O que o traz por aqui?"
	return "Boa tarde. Se precisa de algo, é melhor resolver antes de escurecer."


func _place_name() -> String:
	return city_name if city_name != "" else "esta região"


func _shop_option_label(context: Dictionary) -> String:
	var gold := int(context.get("player_gold", 0))
	if role == "ferreiro":
		return "Ver equipamentos (tenho %d ouro)" % gold if gold < 40 else "Ver ferramentas e equipamentos"
	if role == "curandeira":
		return "Ver remédios (tenho %d ouro)" % gold if gold < 10 else "Ver remédios e pergaminhos"
	return "Ver mercadorias (ouro contado)" if gold < 15 else "Ver mercadorias"


func _occupation_option_label(context: Dictionary) -> String:
	var hour := float(context.get("hour", 12.0))
	var threat := float(context.get("regional_threat", 0.0))
	match role:
		"ferreiro": return "Perguntar sobre a oficina" if hour >= 20.0 or hour < 6.0 else "Perguntar sobre a ferraria"
		"mercador": return "Perguntar sobre preços e negócios"
		"curandeira":
			if int(context.get("player_hp", 1)) < int(context.get("player_max_hp", 1)) * 0.55:
				return "Pedir conselho sobre meus ferimentos"
			return "Perguntar sobre ervas e cura"
		"guarda": return "Perguntar sobre os perigos da região" if threat >= 32.0 else "Perguntar sobre a ronda"
		_: return "Perguntar sobre a vida por aqui"


func _occupation_dialogue(context: Dictionary) -> String:
	var hour := float(context.get("hour", 12.0))
	var threat := float(context.get("regional_threat", 0.0))
	match role:
		"ferreiro":
			var place := work_building_name if work_building_name != "" else "minha oficina"
			var ore_place := _context_place_by_kind(context, ["resource_ore", "resource_mixed", "mine"])
			var ore_note := " Conheço também %s, um ponto útil para quem trabalha metal." % str(ore_place.get("name", "os pontos de minério da região")) if not ore_place.is_empty() else ""
			if hour >= 20.0 or hour < 6.0:
				return "%s é meu ganha-pão, mas a forja não fica acesa a noite inteira. Se precisa de equipamento, volte no horário de trabalho.%s" % [place, ore_note]
			return "Trabalho em %s. Ferramenta bem cuidada dura anos; equipamento barato pode custar caro quando você mais precisa.%s" % [place, ore_note]
		"mercador":
			var route_place := _context_place_by_kind(context, ["city", "inn"])
			var route_note := " Também presto atenção em %s, porque viajantes e mercadorias passam por ali." % str(route_place.get("name", "outras estalagens e assentamentos")) if not route_place.is_empty() else ""
			return ("O comércio depende de estradas seguras e de gente com algumas moedas no bolso. Quando a região fica perigosa, todo mundo compra menos — ou compra o que consegue carregar." if threat >= 32.0 else "Comércio é saber o que as pessoas precisam antes que elas mesmas percebam. Tenho mercadorias úteis para quem vive na estrada.") + route_note
		"curandeira":
			var herb_place := _context_place_by_kind(context, ["resource_herbs", "resource_mixed", "meadow", "grove"])
			var herb_note := " Há plantas úteis em %s, embora seja preciso colher com cuidado." % str(herb_place.get("name", "alguns prados próximos")) if not herb_place.is_empty() else ""
			if int(context.get("player_hp", 1)) < int(context.get("player_max_hp", 1)) * 0.55:
				return "Você parece precisar de descanso. Cuide de seus ferimentos antes de sair de novo; tenho suprimentos se estiver precisando.%s" % herb_note
			return "Ervas boas exigem tempo e atenção. Nem todo mal se resolve com magia, e nem toda cura precisa de magia.%s" % herb_note
		"guarda":
			var patrol_place := _context_place_by_kind(context, ["watchtower", "camp", "ruins", "cave", "dungeon"])
			var patrol_note := " Mantenho atenção especial em %s." % str(patrol_place.get("name", "pontos de passagem nos arredores")) if not patrol_place.is_empty() else ""
			if threat >= 65.0:
				return "A ronda anda pesada. Estamos atentos aos arredores, mas não conseguimos estar em toda estrada ao mesmo tempo. Evite viajar sozinho.%s" % patrol_note
			if threat >= 32.0:
				return "Temos recebido sinais de perigo nas redondezas. Fique perto das estradas e avise a guarda se notar algo estranho.%s" % patrol_note
			return "A ronda é repetitiva quando tudo vai bem. Ainda assim, é melhor patrulhar uma estrada vazia do que chegar tarde quando alguém precisa de ajuda.%s" % patrol_note
		"mensageiro":
			var knowledge_value: Variant = context.get("world_knowledge", {})
			var knowledge: Dictionary = knowledge_value if knowledge_value is Dictionary else {}
			if messenger_trip_active:
				var destination_name := "outro assentamento"
				for place_value in known_places:
					if not (place_value is Dictionary):
						continue
					if str(place_value.get("kind", "")) == "city" and str(place_value.get("city_id", "")) == messenger_target_city_id:
						destination_name = str(place_value.get("name", destination_name))
						break
				if messenger_trip_stage == "returning":
					return "Estou voltando ao posto depois de recolher notícias em %s. Uma informação só vale quando chega a quem precisa dela." % destination_name
				return "Estou levando mensagens para %s. Quando chegar, vou recolher o que souberem por lá e trazer de volta." % destination_name
			var known_city_names_value: Variant = knowledge.get("known_city_names", [])
			var known_city_names: Array = known_city_names_value if known_city_names_value is Array else []
			if known_city_names.size() > 1:
				return "Minha base é o posto de correios daqui. Levo mensagens entre %s e %s, e separo o que vi daquilo que apenas me contaram." % [str(known_city_names[0]), str(known_city_names[1])]
			return "Minha base é o posto de correios daqui. Levo mensagens pela região e confiro de onde veio cada notícia antes de repeti-la."
		_:
			if hour >= 20.0 or hour < 6.0:
				return "A essa hora, eu já penso em fechar a porta e descansar. De dia sempre aparece algo para fazer."
			return "A vida em %s segue no ritmo de sempre: trabalho, mercado, vizinhos e notícias que chegam pela estrada." % _place_name()


func _local_observation_option_label(context: Dictionary) -> String:
	if int(context.get("nearby_enemy_count", 0)) > 0:
		return "Perguntar sobre a ameaça próxima"
	if bool(context.get("player_wounded", false)):
		return "Comentar meus ferimentos"
	var weather: int = int(context.get("weather", 0))
	if weather == 5:
		return "Falar da nevasca e da visibilidade"
	if weather == 4:
		return "Comentar a neve no caminho"
	if weather == 3:
		return "Falar da tempestade"
	if weather == 2:
		return "Comentar a chuva e as estradas"
	if str(context.get("inside_building_kind", "")) in ["inn", "tavern"]:
		return "Comentar o movimento no salão"
	if bool(context.get("player_is_mounted", false)):
		return "Comentar a montaria e a viagem"
	var latest_event: Dictionary = _latest_relevant_event(context)
	if not latest_event.is_empty():
		return "Retomar o último acontecimento"
	var hour: float = float(context.get("hour", 12.0))
	if hour < 6.0 or hour >= 20.0:
		return "Comentar a hora e os arredores"
	return "Comentar o que está acontecendo ao redor"


func _local_observation_dialogue(context: Dictionary) -> String:
	# Resposta situada: interpreta o que este NPC consegue notar agora, sem
	# fingir que sabe de coisas ocorridas longe ou que não presenciou.
	var lines: Array[String] = []
	var hour: float = float(context.get("hour", 12.0))
	var weather: int = int(context.get("weather", 0))
	var enemy_count: int = int(context.get("nearby_enemy_count", 0))
	var enemy_name: String = str(context.get("nearest_enemy_name", "criatura"))
	var enemy_distance: float = float(context.get("nearest_enemy_distance", -1.0))
	var location: String = str(context.get("local_place_name", city_name if city_name != "" else "esta região"))
	var inside_kind: String = str(context.get("inside_building_kind", ""))
	if inside_kind in ["inn", "tavern"]:
		var occupants: int = int(context.get("tavern_occupant_count", 0))
		if occupants >= 4:
			lines.append("O salão está cheio; com tanta conversa, sempre há uma história que merece ser conferida antes de acreditar nela.")
		elif occupants > 0:
			lines.append("Tem pouca gente por aqui agora. Dá para conversar sem gritar por cima do salão.")
		else:
			lines.append("O salão está quieto. Talvez os viajantes ainda estejam na estrada, ou talvez esta hora não convide ninguém a sair.")
	elif enemy_count > 0:
		var distance_text := "bem perto" if enemy_distance >= 0.0 and enemy_distance < 7.0 else "a alguns passos" if enemy_distance < 15.0 else "mais adiante"
		if role == "guarda":
			lines.append("Tem movimento por aqui. A criatura mais próxima parece estar %s; vou ficar de olho nos acessos." % distance_text)
		elif role == "curandeira":
			lines.append("Vejo %s %s. Não vou recomendar que enfrente isso sem preparo; ferimentos são mais fáceis de evitar do que de tratar." % [enemy_name, distance_text])
		elif role == "mercador":
			lines.append("Com %s à vista, prefiro não abrir a carga nem ficar no meio do caminho." % enemy_name)
		else:
			lines.append("Vejo %s %s. Não sei se vai atacar, mas não vou fingir que os arredores estão tranquilos." % [enemy_name, distance_text])
	elif weather == 5:
		lines.append("A nevasca está cobrindo rastros e reduzindo a visibilidade. É difícil distinguir movimento real de sombra neste tempo.")
	elif weather == 4:
		lines.append("A neve muda o caminho e esconde marcas antigas. Se eu sair daqui, vou procurar pontos de referência conhecidos.")
	elif weather == 3:
		lines.append("Os trovões estão altos. O terreno aberto e as árvores isoladas não são bons lugares para esperar a tempestade passar.")
	elif weather == 2:
		lines.append("A chuva está deixando o caminho mais escorregadio. Quem viaja agora precisa escolher melhor onde pisa.")
	elif hour < 5.0:
		lines.append("Ainda é madrugada. Há pouco movimento e consigo ouvir coisas que o barulho do dia costuma esconder.")
	elif hour < 8.0:
		lines.append("A manhã está começando; em pouco tempo as ruas e as estradas vão ficar mais movimentadas.")
	elif hour >= 20.0:
		lines.append("Já está tarde. As pessoas estão se recolhendo e qualquer movimento fora de hora chama mais atenção.")
	else:
		lines.append("Por enquanto, %s parece tranquila. Vou aproveitar enquanto dura." % location)

	if bool(context.get("player_wounded", false)):
		if role == "curandeira":
			lines.append("E você está ferido. Um descanso ou um tratamento antes de voltar à estrada seria prudente.")
		else:
			lines.append("Você parece ferido. Não vou presumir o que aconteceu, mas eu pensaria duas vezes antes de entrar em outra briga assim.")
	if bool(context.get("player_is_mounted", false)):
		lines.append("Vejo que está a cavalo. Isso ajuda na estrada, mas não torna estreitos, encostas ou emboscadas menos perigosos.")
	var latest_event: Dictionary = _latest_relevant_event(context)
	if not latest_event.is_empty() and lines.size() < 2:
		var event_kind: String = str(latest_event.get("kind", ""))
		var event_detail: String = str(latest_event.get("detail", "um acontecimento"))
		if event_kind == "monster_defeated":
			lines.append("Ainda se fala do confronto com %s." % str(CREATURE_NAMES.get(event_detail, event_detail)))
		elif event_kind == "monster_sighting":
			lines.append("Os relatos de %s ainda não me saíram da cabeça." % str(CREATURE_NAMES.get(event_detail, event_detail)))
		elif event_kind == "quest_completed":
			lines.append("Ouvi dizer que '%s' foi resolvido." % event_detail)
	if lines.is_empty():
		return "Nada me chamou a atenção até agora."
	return " ".join(PackedStringArray(lines.slice(0, 2)))


func _town_dialogue(context: Dictionary) -> String:
	var threat := float(context.get("regional_threat", 0.0))
	var status := str(context.get("regional_threat_status", ""))
	var place := _place_name()
	if threat >= 70.0:
		return "%s está passando por tempos difíceis. %s As pessoas evitam sair sem necessidade; qualquer notícia da estrada corre de casa em casa." % [place, status if status != "" else "A região está em perigo."]
	if threat >= 40.0:
		return "À primeira vista, a vida em %s segue normal. Mas pergunte a quem vive perto dos portões: a estrada anda preocupando todo mundo. %s" % [place, status if status != "" else "Convém ficar alerta."]
	var variants: Array[String] = []
	match role:
		"guarda": variants = [
			"Quando a ronda está tranquila, o povo reclama do tédio. Quando fica perigoso, perguntam por que não chegamos antes. É assim em %s." % place,
			"Cobrimos os portões e as ruas principais. Estrada distante é outra história; não dá para pôr um guarda em cada curva de %s." % place,
			"O pior da ronda nem sempre é encontrar perigo. Às vezes é convencer alguém de que os sinais estavam lá desde o começo, em %s." % place
		]
		"ferreiro": variants = [
			"Em %s, quase todo mundo só traz uma peça para consertar quando ela já quebrou de vez. Aí querem tudo pronto antes do almoço." % place,
			"O trabalho não falta em %s. O que falta é gente que aceite esperar por um serviço bem-feito em vez de levar o mais barato." % place,
			"Consigo dizer como anda a cidade pela fila da oficina. Quando as carroças atrasam, logo aparecem ferramentas e rodas para consertar em %s." % place
		]
		"curandeira": variants = [
			"Em %s, muita gente só procura ajuda quando já não aguenta a dor. Tento convencer o pessoal a vir antes disso." % place,
			"Os dias calmos são os melhores para cuidar de quem precisa. Quando a estrada fica perigosa, chegam todos de uma vez em %s." % place,
			"Sempre peço que limpem bem os cortes e descansem. Metade das pessoas promete; a outra metade volta pior no dia seguinte, em %s." % place
		]
		"mercador": variants = [
			"Em %s, basta uma estrada fechar para faltar coisa nas bancas. O povo só percebe quando o preço muda." % place,
			"Posso adivinhar o estado das estradas pelo que falta no mercado. Hoje, por sorte, ainda há quase tudo em %s." % place,
			"Todo mundo gosta de pechinchar até descobrir que a mercadoria veio de longe. Aí o preço já não parece tão absurdo, em %s." % place
		]
		"mensageiro": variants = [
			"Em %s, uma notícia chega antes da pessoa que a trouxe. Só queria que as boas corressem tão depressa quanto as ruins." % place,
			"Passo mais tempo indo e voltando do que em casa. Pelo menos, em %s, já conheço quem costuma esperar por cada recado." % place,
			"Tem recado que pesa mais que uma bolsa cheia. Aprendi a não ler o que não me pertence e a não prometer entrega impossível, em %s." % place
		]
	if variants.is_empty():
		match personality:
			"fofoqueiro": variants = [
				"Em %s, uma notícia dá a volta na praça antes do almoço. A versão que chega à noite já costuma ser outra." % place,
				"Se quiser saber o que aconteceu em %s, pergunte a duas pessoas diferentes. A terceira versão costuma ser a mais interessante, não necessariamente a verdadeira.",
				"Aqui todo mundo conhece alguém que conhece alguém. É assim que as histórias atravessam %s." % place
			]
			"desconfiado": variants = [
				"Em %s, cuide dos seus e aprenda quem cumpre a palavra. O resto você descobre com o tempo." % place,
				"Não tenho problema com vizinhos; tenho problema com quem aparece dizendo que sabe tudo sobre %s depois de passar uma noite aqui." % place,
				"Conheço bastante gente em %s, mas não confundo conhecer um rosto com confiar numa pessoa." % place
			]
			_: variants = [
				"Em %s, quase todo mundo se conhece de vista. Ajuda quando há problema e atrapalha quando se quer guardar segredo." % place,
				"A cidade tem seus defeitos, mas sei onde encontrar quem me deve um favor e quem me ajudaria sem perguntar por quê. Isso já conta muito em %s." % place,
				"Os dias parecem iguais até alguma coisa sair do lugar. Aí a gente descobre quantas pessoas dependem umas das outras em %s." % place
			]
	var variant_seed := (npc_id + "|town|" + str(conversations_with_player)).hash()
	return variants[posmod(abs(variant_seed), variants.size())]


func _latest_relevant_event(_context: Dictionary) -> Dictionary:
	# A memória já tem limite e política de retenção de eventos importantes. Não
	# expira usando o relógio da conversa: isso apagava feitos após poucos minutos.
	var best: Dictionary = {}
	var best_time := -INF
	for event_value in known_world_events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var event_time := maxf(float(event.get("timestamp", 0.0)), float(event.get("last_heard_timestamp", 0.0)))
		if event_time >= best_time:
			best = event
			best_time = event_time
	return best


func _event_option_label(event: Dictionary) -> String:
	var detail := str(CREATURE_NAMES.get(str(event.get("detail", "")), str(event.get("detail", ""))))
	if str(event.get("kind", "")) == "monster_sighting":
		return "Perguntar sobre %s" % detail
	if str(event.get("kind", "")) == "monster_defeated":
		return "Comentar o confronto recente"
	if str(event.get("kind", "")) == "player_tavern_round":
		return "Comentar a rodada na taverna"
	if str(event.get("kind", "")) == "quest_completed":
		return "Comentar o trabalho concluído"
	return "Perguntar sobre as últimas notícias"


func _event_dialogue(event: Dictionary) -> String:
	var detail := str(CREATURE_NAMES.get(str(event.get("detail", "")), str(event.get("detail", "criaturas"))))
	var place_name := str(event.get("place_name", ""))
	var place_note := " perto de %s" % place_name if place_name != "" else " nas redondezas"
	if str(event.get("kind", "")) == "monster_sighting":
		if str(event.get("knowledge", "witness")) == "heard":
			var sighting_reporter := str(event.get("heard_from_name", "alguém da região"))
			return "Não vi pessoalmente. %s me contou que havia sinais de %s%s, mas histórias mudam quando passam de boca em boca." % [sighting_reporter, detail, place_note]
		if str(event.get("knowledge", "witness")) == "recipient":
			return "Recebi um aviso sobre sinais de %s%s. Ainda não confirmei pessoalmente, então mantenha os olhos abertos." % [detail, place_note]
		if personality == "desconfiado":
			return "Vi sinais de %s%s. Não vou dizer que sei exatamente para onde foram, mas eu não me afastaria da estrada sem motivo." % [detail, place_note]
		if personality == "fofoqueiro":
			return "Vi sinais de %s%s e já tem gente aumentando a história. Melhor conferir antes de acreditar em tudo." % [detail, place_note]
		return "Notei %s%s há pouco tempo. Não sei se ainda estão por perto, mas vale manter os olhos abertos." % [detail, place_note]
	if str(event.get("kind", "")) == "player_tavern_round":
		return "Lembro que você pagou uma rodada na %s. Foi um gesto generoso; essas coisas não passam despercebidas." % str(event.get("place_name", "taverna"))
	if str(event.get("kind", "")) == "monster_defeated":
		if str(event.get("knowledge", "")) == "heard":
			var confrontation_reporter := str(event.get("heard_from_name", "alguém da região"))
			return "Não presenciei o confronto. %s me contou que houve uma luta contra %s%s; não sei todos os detalhes." % [confrontation_reporter, detail, place_note]
		if str(event.get("knowledge", "")) == "witness" and str(event.get("actor_id", "")) == "player":
			return "Eu vi você enfrentar %s%s. Foi perigoso, mas agora sei que posso contar com você quando a estrada ficar ruim." % [detail, place_note]
		if personality == "bem-humorado":
			return "Parece que alguém deu uma boa surra em %s por aqui. Tomara que tenham aprendido a ficar longe da cidade." % detail
		return "Houve um confronto com %s nas redondezas. Pode ser que a estrada fique mais tranquila por um tempo, mas não baixaria a guarda." % detail
	if str(event.get("kind", "")) == "quest_completed":
		var quest_title := str(event.get("detail", "um trabalho"))
		if str(event.get("informed_npc_id", "")) == npc_id:
			return "Você cumpriu o combinado em '%s'. Obrigado por cuidar disso. Vou me lembrar de quem manteve a palavra." % quest_title
		if str(event.get("knowledge", "witness")) == "witness":
			return "Vi que terminou '%s'. Pelo menos hoje temos uma notícia melhor para contar." % quest_title
		if personality == "fofoqueiro" or str(event.get("knowledge", "")) == "heard":
			return "Ouvi dizer que o trabalho '%s' foi concluído. Ainda não sei todos os detalhes, então prefiro perguntar antes de aumentar a história." % quest_title
		return "Ouvi que '%s' foi resolvido. Vamos ver se a estrada melhora nos próximos dias." % quest_title
	return "Aconteceu algo nas redondezas, mas não sei de todos os detalhes. Prefiro contar o que sei do que inventar o resto."


func _safety_dialogue(context: Dictionary) -> String:
	var threat := float(context.get("regional_threat", 0.0))
	if threat >= 75.0:
		return "A situação está crítica. Evite sair sozinho, fique atento aos arredores e procure a guarda antes de pegar uma estrada perigosa."
	if threat >= 60.0:
		return "O perigo está crescendo. Há razões para a guarda reforçar as rondas e para viajantes evitarem atalhos."
	if threat >= 42.0:
		return "Há mais sinais de perigo do que gostaríamos. Não quer dizer que algo vá acontecer na próxima esquina, mas é melhor ter cuidado."
	return "As coisas estão um pouco tensas, embora ainda não seja motivo para pânico. Preste atenção ao caminho."


func _weather_dialogue(context: Dictionary) -> String:
	var weather := int(context.get("weather", 0))
	match weather:
		5:
			if role == "guarda":
				return "Com essa nevasca, vamos manter a ronda perto dos abrigos e vigiar quem ainda estiver na estrada."
			if role == "mercador":
				return "Não vou arriscar a carga num vento desses. A caravana espera até a passagem ficar visível."
			return "O vento está apagando as trilhas e a visibilidade mal passa de alguns passos. Procure abrigo até a nevasca diminuir."
		4:
			if role == "guarda":
				return "A neve esconde pegadas e deixa as trilhas traiçoeiras. Vou reforçar a atenção nas entradas da cidade."
			if role == "mercador":
				return "A neve pode atrasar minhas entregas. Vou conferir o estoque antes de prometer qualquer mercadoria."
			return "A neve está cobrindo a estrada. Vista algo quente e evite os caminhos mais altos se não precisar viajar."
		3:
			return "Com essa tempestade elétrica, evite árvores isoladas e campos abertos. É melhor procurar abrigo até o trovão passar."
		2:
			return "A chuva vai deixar algumas partes do caminho escorregadias. Se não tiver urgência, espere diminuir; se tiver, vá com calma."
	return "O céu está carregado, mas ainda não parece tempo para preocupação. Vale ficar atento às mudanças."


func _night_dialogue(context: Dictionary) -> String:
	var threat := float(context.get("regional_threat", 0.0))
	if role == "guarda":
		return "À noite, a ronda presta atenção principalmente aos acessos e às estradas. Mesmo assim, não podemos cobrir todo o campo."
	if threat >= 45.0:
		return "À noite, os arredores ficam mais arriscados. Muita gente prefere se recolher e deixar as viagens para o amanhecer."
	if personality == "fofoqueiro":
		return "É quando a taverna enche e as histórias começam a crescer. Algumas valem a pena ouvir; outras é melhor deixar morrer ali mesmo."
	return "Depois de escurecer, a cidade fica mais quieta. Quem conhece bem o lugar sabe a quais portas bater e quais ruas evitar."


func _household_dialogue() -> String:
	# A resposta é escrita da perspectiva deste NPC. O nome próprio nunca deve
	# aparecer como se fosse outra pessoa da casa.
	var names := household_member_names.duplicate()
	if names.is_empty():
		match personality:
			"reservado":
				return "Moro por conta própria. Prefiro cuidar das minhas coisas sem depender de ninguém."
			"bem-humorado":
				return "Moro por conta própria. Pelo menos ninguém disputa comigo o último pedaço de pão."
			"desconfiado":
				return "Moro por conta própria. Gosto de saber que minhas coisas ficam onde deixei."
			_:
				return "Moro por conta própria. Tenho minhas tarefas e cuido da casa como posso."
	if names.size() == 1:
		return "Moro com %s. A gente divide as tarefas da casa e se ajuda quando precisa." % names[0]
	var last_name: String = str(names[names.size() - 1])
	var first_names: Array = names.slice(0, names.size() - 1)
	var household_names: String = ", ".join(PackedStringArray(first_names)) + " e " + last_name
	if personality == "reservado":
		return "Moro com %s. Prefiro não expor muito nossa vida, mas a gente se ajuda." % household_names
	if personality == "bem-humorado":
		return "Moro com %s. Tem sempre alguma coisa para fazer em casa — e quase sempre alguém discutindo por bobagem." % household_names
	return "Moro com %s. Cada um cuida das suas obrigações e a gente tenta se ajudar quando pode." % household_names

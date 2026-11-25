extends Node3D
# Mundo aberto (criado pelo jogo ao começar uma partida): carrega o overworld.glb e põe monstros, NPCs e a entrada da cripta.
# Nomes dos objetos do mapa (no Blender ou no glb) mandam no que nasce onde:
#   spawn_rato, spawn_esqueleto, spawn_orc (com ou sem número no fim) -> ponto de spawn de monstro
#   npc_ferreiro, npc_guarda, npc_mercador, npc_curandeira, npc_aldeao -> NPC
#   entrada_cripta -> entrada da cripta (aperte F perto dela para descer)
#   inicio_jogador -> onde o jogador nasce
# Zonas seguras: em volta de cada cidade (settlement_) não nascem monstros e quem está lá não é atacado.
# Fora dela, o que nasce depende do lugar: cada POI tem seu conjunto (POI_POOLS), spawns com nome fixo
# (spawn_rato, spawn_goblin, spawn_morcego...) respeitam o nome, e o campo aberto muda com a distância da cidade (FIELD_POOLS).
# Sem entrada_cripta, coloca uma longe do início.

const MAP_PATH := "res://assets/world/overworld.glb"
const NPC_SCENE := "res://scenes/npc.tscn"
const NPC_SOCIETY_SCRIPT := preload("res://scripts/npc_society.gd")
const REGIONAL_THREATS_SCRIPT := preload("res://scripts/regional_threats.gd")
const ENVIRONMENT_DETAILS_SCRIPT := preload("res://scripts/environment_details.gd")
const PROCEDURAL_INTERIOR_SCRIPT := preload("res://scripts/procedural_interior.gd")
const WORLD_RESOURCE_SCRIPT := preload("res://scripts/world_resource.gd")
const RESOURCE_CATALOG := preload("res://scripts/resource_catalog.gd")
const WORLD_NAMES := preload("res://scripts/world_names.gd")
# Cavalos originais do Daggerfall (TEXTURE.201), extraídos com a paleta ART_PAL.COL.
# O castanho é usado nas montarias para combinar com o sprite de primeira pessoa MRED00I0.
const HORSE_WORLD_FRAMES_BROWN := [
	preload("res://assets/world/animals/horses/TEXTURE201_record00_frame00.png"),
	preload("res://assets/world/animals/horses/TEXTURE201_record00_frame01.png"),
	preload("res://assets/world/animals/horses/TEXTURE201_record00_frame02.png"),
	preload("res://assets/world/animals/horses/TEXTURE201_record00_frame03.png")
]
# Segunda pelagem preservada para futura variação de cavalos e NPCs montados.
const HORSE_WORLD_FRAMES_GRAY := [
	preload("res://assets/world/animals/horses/TEXTURE201_record01_frame00.png"),
	preload("res://assets/world/animals/horses/TEXTURE201_record01_frame01.png"),
	preload("res://assets/world/animals/horses/TEXTURE201_record01_frame02.png"),
	preload("res://assets/world/animals/horses/TEXTURE201_record01_frame03.png")
]
const MAX_ALIVE_PER_SPAWN := 2
const MAX_NEARBY_ENEMIES := 8
const CITY_ASSAULT_WAKE_RADIUS := 300.0
const CITY_OCCUPATION_WAKE_RADIUS := 260.0
const RESPAWN_MIN := 8.0
const RESPAWN_MAX := 15.0
const FIRST_SPAWN_MIN := 0.0
const FIRST_SPAWN_MAX := 1.6
const SPAWN_RETRY_MIN := 0.65
const SPAWN_RETRY_MAX := 1.8
const SPAWN_GLOBAL_COOLDOWN := 0.42
const NIGHT_SPAWN_DELAY_MULTIPLIER := 0.62
const NIGHT_SPAWN_RETRY_MULTIPLIER := 0.58
const NIGHT_SPAWN_COOLDOWN_MULTIPLIER := 0.72
const ACTIVE_DIST := 80.0
const MIN_SPAWN_DIST := 20.0
const INTERACT_REACH := 4.0
const AIM_TARGET_RAY_EPSILON := 0.05
const MAP_RES := 2048  # resolução da imagem do mapa (px)
# Streaming de cena: meshes individuais são desenhadas só perto da câmera e suas
# colisões são criadas sob demanda, em pequenos lotes por frame.
const STREAM_COLLISION_BUDGET := 1
const STREAM_INITIAL_COLLISION_BUDGET := 2
const STREAM_REFRESH_SECONDS := 0.25
const BUILDING_RENDER_DISTANCE := 420.0
const LANDMARK_RENDER_DISTANCE := 480.0
const DETAIL_RENDER_DISTANCE := 135.0
const NPC_ACTIVE_RADIUS := 135.0
const ENEMY_ACTIVE_RADIUS := 115.0
const ENEMY_DEACTIVATE_RADIUS := 165.0
const ENTRANCE_LABEL_DISTANCE := 48.0
const ENTRANCE_VISIBILITY_DISTANCE := 190.0
const ENTRANCE_DISCOVERY_DISTANCE := 36.0
# Evita que contratos diferentes coloquem alvos no mesmo acampamento/aglomerado.
const QUEST_SITE_MIN_SEPARATION := 125.0
@export_range(60.0, 3600.0, 10.0) var day_length_seconds: float = 600.0 # 20 minutos reais por dia completo
var moon_phase_index: int = 4 # 0 nova, 4 cheia; persistido em game.gd
@export_range(1, 10, 1) var days_per_moon_phase: int = 2
@export_range(0.0, 1.0, 0.01) var cloud_coverage: float = 0.48
@export var clouds_enabled: bool = true
@export var automatic_weather: bool = true
@export_enum("Limpo", "Nublado", "Chuva", "Tempestade", "Neve", "Tempestade de neve") var starting_weather: int = 0
@export_range(60.0, 900.0, 10.0) var weather_change_min_seconds: float = 180.0
@export_range(90.0, 1800.0, 10.0) var weather_change_max_seconds: float = 420.0
@export_range(240.0, 1200.0, 40.0) var weather_region_size: float = 520.0
const DEFAULT_START_HOUR := 0.0 # o relógio começa à meia-noite; o amanhecer ocorre às 06h
const SAFE_RADIUS := 100.0      # zona segura em volta das cidades (as maiores têm uns 64 de raio)
const FIELD_SPAWNS := 36        # pontos de monstros espalhados pelo campo aberto
const FIELD_MIN_SPACING := 70.0
const FIELD_SPAWN_RADIUS := 42.0
const MARKER_SPAWN_RADIUS := 18.0
const POI_SPAWN_RADIUS := 30.0
const SPAWN_POSITION_ATTEMPTS := 12
const SEA_MARGIN := 1.0         # não nasce nada abaixo do nível do mar + isso
const NO_COLLISION_WORDS := ["ocean", "water", "river", "canopies", "roof"]
# Quem nasce em cada tipo de POI (peso de cada monstro; rat, goblin, bat, skel, orc)
const POI_POOLS := {
	"cave": {"rat": 6, "bat": 4},
	"ruins": {"skel": 8, "rat": 2},
	"shrine": {"skel": 6, "bat": 4},
	"camp": {"goblin": 7, "orc": 3},
	"watchtower": {"goblin": 5, "orc": 5},
}
# Spawns com nome fixo no mapa (a ordem importa: "morcego" contém "orc")
const MARKER_POOLS := {
	"morcego": {"bat": 1}, "bat": {"bat": 1},
	"goblin": {"goblin": 1},
	"esqueleto": {"skel": 1}, "skel": {"skel": 1},
	"orc": {"orc": 1},
	"rato": {"rat": 1}, "rat": {"rat": 1},
}
# Campo aberto: [distância máxima até a cidade mais próxima, quem nasce]
const FIELD_POOLS := [
	[250.0, {"rat": 6, "goblin": 3, "bat": 1}],
	[500.0, {"goblin": 5, "rat": 2, "bat": 2, "skel": 1}],
	[99999.0, {"orc": 4, "goblin": 3, "skel": 3, "bat": 2}],
]
const NPC_ROLE_CYCLE := ["guarda", "ferreiro", "mercador", "curandeira", "aldeao", "aldeao"]
const ROLE_NAMES := {"ferreiro": "Ferreiro", "guarda": "Guarda", "mercador": "Mercador", "curandeira": "Curandeira", "mensageiro": "Mensageiro", "estalajadeiro": "Estalajadeiro", "aldeao": "Aldeão", "bruxa": "Bruxa"}

var ROLE_TINTS := {"ferreiro": Color(1.0, 0.7, 0.5), "guarda": Color(0.6, 0.75, 1.0), "mercador": Color(1.0, 0.9, 0.5), "curandeira": Color(0.7, 1.0, 0.8), "estalajadeiro": Color(1.0, 0.82, 0.52), "aldeao": Color(1.0, 1.0, 1.0)}
var TEST_MARKERS := {
	"inicio_jogador": Vector3(0, 0, 0),
	"npc_aldeao": Vector3(-5, 0, -6),
	"npc_aldeao_2": Vector3(7, 0, 5),
	"npc_ferreiro": Vector3(6, 0, -4),
	"npc_guarda": Vector3(-6, 0, 5),
	"npc_mercador": Vector3(3, 0, 9),
	"spawn_rato_1": Vector3(50, 0, 30),
	"spawn_rato_2": Vector3(-60, 0, 50),
	"spawn_rato_3": Vector3(20, 0, -60),
	"spawn_esqueleto_1": Vector3(90, 0, -70),
	"spawn_orc_1": Vector3(-120, 0, -90),
	"entrada_cripta": Vector3(-70, 0, -20),
}

var game = null
var map_note := ""
var spawns: Array = []
var npcs: Array = []
var _horses: Array[Dictionary] = []
var _mounted_horse: Node3D = null
var _resource_nodes: Array = []
var resource_sites: Array[Dictionary] = []
var _npc_society = null
var _interactable_building_records: Array = []
var _regional_threats = null
var _active_interior: Node3D = null
var _inside_building := false
var _active_building_record: Dictionary = {}
var _interior_home_residents: Array = []
var _interior_work_npcs: Array = []
var _tavern_visit_npcs: Array = []
var _interior_return_position := Vector3.ZERO
var _interior_return_rotation := Vector3.ZERO
var _interior_return_pitch := 0.0
var _rain_was_emitting := false
var _rain_was_visible := true
var _map_was_visible := true
var _environment_details = null
var _last_player_region_id := ""
var _last_player_region_status := ""
var _region_feedback_timer := 0.0
var _city_presence_timer := 0.0
var entrances: Array = []
var start_pos := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var environment: Environment = null
var sky_material: ProceduralSkyMaterial = null
var sun: DirectionalLight3D = null
var moon: DirectionalLight3D = null
var time_of_day_hours := DEFAULT_START_HOUR
var ready_to_run := false
var _map: Node3D = null
var _prompt: Label = null
var _aim_reticle: Label = null
var _npc_scene: PackedScene = null
var world_bounds := AABB()
var map_bounds := AABB()      # só o terreno (sem o oceano gigante em volta)
var map_texture: Texture2D = null
var map_extent := 0.0
var map_center := Vector3.ZERO
var _map_viewport: SubViewport = null
var settlement_points: Array = []
var safe_radius := SAFE_RADIUS
var sea_level := -1000.0
var _safe_name := ""
var _stream_meshes: Array[MeshInstance3D] = []
var _stream_timer := 0.0
var _spawn_global_timer := 0.0
var _spawn_check_timer := 0.0
var _streamed_body_ids: Dictionary = {}
# Materiais compartilhados em duas faces para evitar que faces dos edifícios
# sejam descartadas pelo culling em ângulos rasantes. Cache por material original.
var _city_two_sided_material_cache: Dictionary = {}
var discovered_entrances: Array[String] = []

# Elementos visuais adaptados do DayNightCycle.gd original.
const SKY_RADIUS: float = 4800.0
var star_dome: MeshInstance3D = null
var cloud_dome: MeshInstance3D = null
var celestial_dome: MeshInstance3D = null
var star_material: ShaderMaterial = null
var cloud_material: ShaderMaterial = null
var celestial_material: ShaderMaterial = null
var cloud_time: float = 0.0
var moon_phase_angle: float = PI # fase cheia inicial
var noon_count: int = 0
var _camera_far_original: float = -1.0

# Clima regional: chuva em regiões temperadas e neve nas regiões frias.
enum Weather { CLEAR, CLOUDY, RAIN, STORM, SNOW, SNOWSTORM }
var current_weather: int = Weather.CLEAR
var overcast_amount: float = 0.0
var rain_amount: float = 0.0
var storm_amount: float = 0.0
var rain_level: float = 0.0
var storm_level: float = 0.0
var rain_particles: CPUParticles3D = null
var snow_particles: CPUParticles3D = null
var snow_amount: float = 0.0
var snow_level: float = 0.0
var snowstorm_level: float = 0.0
var local_coldness: float = 0.0
var wet_material: ShaderMaterial = null
var wet_meshes: Array[MeshInstance3D] = []
var wetness: float = 0.0
var puddle_level: float = 0.0
var wet_overlay_enabled: bool = false
var lightning_light: DirectionalLight3D = null
var lightning_flash: float = 0.0
var lightning_timer: float = 7.0
var second_flash_timer: float = -1.0
var lightning_bolt: MeshInstance3D = null
var lightning_bolt_mesh: ImmediateMesh = null
var lightning_bolt_material: StandardMaterial3D = null
var thunder_stream: AudioStreamWAV = null
# O clima é simulado por células espaciais persistentes, não por um estado global.
const WEATHER_FIELD_RESOLUTION := 32
const WEATHER_FIELD_REFRESH_SECONDS := 3.0
# Lanterns use the emissive geometry already present in the current overworld GLB.
# Only nearby point lights are enabled, keeping the Compatibility renderer affordable.
const LANTERN_ACTIVE_RADIUS := 145.0
const LANTERN_MAX_ACTIVE_LIGHTS := 12
const LANTERN_LIGHT_RANGE := 9.5
const LANTERN_BASE_LIGHT_ENERGY := 1.75
const LANTERN_EMISSION_ENERGY := 5.0
const LANTERN_REFRESH_SECONDS := 0.60
const SHELTER_CHECK_INTERVAL := 0.24
var _weather_regions: Dictionary = {}
var _weather_noise: FastNoiseLite = null
var _weather_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weather_clock: float = 0.0
var _weather_field_image: Image = null
var _weather_field_texture: ImageTexture = null
var _weather_field_refresh_timer: float = 0.0
var _weather_world_grid_initialized: bool = false
var _initial_weather_applied: bool = false
var _lantern_lights: Array[OmniLight3D] = []
var _lantern_sources: Array[Dictionary] = []
var _lantern_material_records: Array[Dictionary] = []
var _lantern_refresh_timer: float = 0.0
var _last_lantern_emission_energy: float = -100.0
var _last_lantern_night_factor: float = -1.0
var _last_lantern_weather_boost: float = -1.0
var _lanterns_initialized: bool = false
var _shelter_check_timer: float = 0.0
var _player_is_sheltered := false


func open(g) -> void:
	game = g
	rng.randomize()
	_npc_scene = load(NPC_SCENE)
	_make_sky_and_sun()
	_make_prompt()
	if ResourceLoader.exists(MAP_PATH):
		_map = load(MAP_PATH).instantiate()
		add_child(_map)
	else:
		_build_test_map()
		map_note = "Sem assets/world/overworld.glb: usando um mapa de teste."
	_add_collision(_map)
	_setup_lantern_lighting()
	_setup_weather_system()
	await get_tree().physics_frame
	await get_tree().physics_frame

	var markers: Array = []
	_collect_markers(_map, markers)
	var start_raw = null
	var spawn_raw: Array = []
	var npc_raw: Array = []
	var settlements: Array = []
	var poi_raw: Array = []
	var entrance_raw: Array = []
	for m in markers:
		var n: String = m["name"]
		if n.begins_with("inicio_jogador"):
			start_raw = m["pos"]
		elif n.begins_with("spawn_"):
			spawn_raw.append(m)
		elif n.begins_with("npc_"):
			npc_raw.append(m)
		elif n.begins_with("settlement_"):
			settlements.append(m)
		elif n.begins_with("poi_"):
			poi_raw.append(m)
		elif n.begins_with("entrada_cripta"):
			entrance_raw.append(m["pos"])

	var bounds := _bounds(_map)
	world_bounds = bounds
	_build_map_texture()
	_find_sea_level()
	if start_raw == null:
		start_raw = _default_start(settlements, bounds)
	start_pos = _ground(start_raw)

	# Registra primeiro todas as cidades, para que as casas possam ser vinculadas
	# ao município correto antes de qualquer NPC ser criado.
	for i in settlements.size():
		var marker_name := str(settlements[i]["name"])
		var sname: String = _settlement_title(marker_name)
		var city_id: String = _city_id_from_marker(marker_name)
		settlement_points.append({
			"id": city_id,
			"marker_name": marker_name,
			"name": sname,
			"pos": _ground(settlements[i]["pos"])
		})

	# A cidade escolhida na criação também determina onde a jornada começa.
	# Usamos o ID estável do marcador, nunca o nome exibido ao jogador.
	if game != null:
		var chosen_home_id := str(game.get("character_home_id"))
		if not chosen_home_id.is_empty():
			for settlement_value in settlement_points:
				var settlement_record: Dictionary = settlement_value
				if str(settlement_record.get("id", "")) == chosen_home_id:
					start_pos = settlement_record.get("pos", start_pos)
					break

	_npc_society = NPC_SOCIETY_SCRIPT.new()
	_npc_society.name = "NPCSociety"
	add_child(_npc_society)
	_npc_society.initialize(self, _map, settlement_points, start_pos)
	if _npc_society.has_signal("npc_born") and not _npc_society.npc_born.is_connected(_on_npc_born):
		_npc_society.npc_born.connect(_on_npc_born)
	# A casa é definida e reservada antes de criar os moradores. Isso garante que
	# ela fique realmente vazia para o jogador e que o mesmo edifício seja usado
	# em carregamentos futuros, mantendo o baú no lugar certo.
	if game != null:
		var home_city_id := str(game.get("character_home_id"))
		var preferred_home_id := str(game.get("player_home_building_id"))
		if preferred_home_id.is_empty() and game.has_method("get_saved_player_home_building_id"):
			preferred_home_id = str(game.call("get_saved_player_home_building_id", home_city_id))
		var fallback_home: Dictionary = {}
		var selected_home: Dictionary = {}
		var physical_buildings: Array = _npc_society.call("get_all_buildings")
		for building_value in physical_buildings:
			if not (building_value is Dictionary):
				continue
			var candidate_home: Dictionary = building_value
			if str(candidate_home.get("kind", "")) != "house" or str(candidate_home.get("city_id", "")) != home_city_id:
				continue
			# A lista de edifícios é ordenada por ID; guardar o último como reserva
			# evita depender de quais casas foram ocupadas pela população no passado.
			fallback_home = candidate_home
			if str(candidate_home.get("id", "")) == preferred_home_id:
				selected_home = candidate_home
				break
		if selected_home.is_empty():
			selected_home = fallback_home
		if not selected_home.is_empty():
			if game.has_method("assign_player_home"):
				game.call("assign_player_home", selected_home)
			if _npc_society.has_method("reserve_player_home"):
				_npc_society.call("reserve_player_home", str(selected_home.get("id", "")))
	# Registra os pontos de interesse reais do mapa antes de gerar os habitantes.
	_npc_society.call("register_poi_markers", poi_raw)
	# Cada assentamento recebe um posto de correios fixo, antes de distribuir as residências.
	for settlement_value in settlement_points:
		var postal_city_id := str(settlement_value.get("id", ""))
		if postal_city_id != "":
			_npc_society.call("get_post_office_for_city", postal_city_id)
	for i in settlements.size():
		var city_id := _city_id_from_marker(str(settlements[i]["name"]))
		_add_settlement(settlements[i]["pos"], i, city_id)
	for m in npc_raw:
		_add_npc(m["name"], m["pos"])
	# Um mensageiro único por posto parte da casa de correios e viaja entre assentamentos.
	for settlement_value in settlement_points:
		var courier_city_id := str(settlement_value.get("id", ""))
		if courier_city_id == "":
			continue
		var office_value: Variant = _npc_society.call("get_post_office_for_city", courier_city_id)
		if not (office_value is Dictionary):
			continue
		var courier_office: Dictionary = office_value
		if courier_office.is_empty():
			continue
		var courier_position: Vector3 = courier_office.get("entry", settlement_value.get("pos", start_pos))
		var courier_ordinal: int = _npc_society.get_residents_of_city(courier_city_id).size()
		_spawn_npc("mensageiro", "Mensageiro", courier_position, courier_city_id, "npc:%s:post-messenger" % courier_city_id, courier_ordinal)
	# A bruxa é uma personagem lendária singular, sem marcador nem ícone de mapa.
	# A localização é escolhida uma vez por save: junto à Casa da Bruxa do modelo,
	# ou na margem do lago nas coordenadas indicadas para o mapa novo.
	var witch_location := str(_npc_society.call("get_unique_witch_location"))
	if bool(_npc_society.call("should_spawn_unique_witch")):
		var witch_position: Vector3
		if witch_location == "lake_edge":
			witch_position = _ground(Vector3(-954.0, 0.0, 465.0))
			witch_position.y += 0.08
		else:
			var witch_hut_node: Node = _map.find_child("OW_WitchHut", true, false) if is_instance_valid(_map) else null
			if witch_hut_node is MeshInstance3D:
				var witch_hut_mesh := witch_hut_node as MeshInstance3D
				var witch_hut_center: Vector3 = witch_hut_mesh.to_global(witch_hut_mesh.get_aabb().get_center())
				# Posiciona a personagem do lado de fora da construção, sem prendê-la
				# dentro da malha ou sobre a colisão da casa.
				witch_position = _ground(Vector3(witch_hut_center.x + 7.0, 0.0, witch_hut_center.z))
			else:
				# Fallback para a localização da casa no mapa novo de seed 16983215.
				witch_position = _ground(Vector3(-1699.5, 0.0, -469.4))
			witch_position.y += 0.08
		var witch_city_id: String = _npc_society.find_nearest_city(witch_position)
		var witch_ordinal: int = _npc_society.get_residents_of_city(witch_city_id).size()
		_spawn_npc("bruxa", "Bruxa", witch_position, witch_city_id, "npc:unique:witch", witch_ordinal)
		var witch = npcs.back()
		witch.is_unique_witch = true
		witch.witch_location = witch_location
		witch.witch_state = str(_npc_society.call("get_witch_state"))
		witch.witch_hp = int(_npc_society.call("get_witch_hp"))
		witch.society = _npc_society
		witch.game = game
		witch.home_id = ""
		witch.home_name = "Casa da Bruxa" if witch_location == "witch_house" else "Margem do lago"
		witch.home_position = witch_position
		witch.home_door_position = witch_position
		witch.work_building_id = ""
		witch.work_position = Vector3.ZERO
		witch.is_at_home = false
		witch.is_at_work = false
		witch.is_interior_present = false
		witch.is_at_tavern = false
		witch.life_bucket = "witch_lair"
		witch.target_kind = "witch_lair"
		witch.has_target = false
		witch.velocity = Vector3.ZERO
		# _spawn_npc já aplica a posição persistida quando há um registro salvo.
		# Não a sobrescrevemos com o ponto inicial da lenda ao reconstruir o mundo.
		# A lenda não aparece a quilômetros de distância por um frame enquanto o
		# streaming da população ainda não calculou o raio do jogador.
		witch.visible = false
		witch.life_enabled = false
		witch.collision_layer = 0
		witch.collision_mask = 0
		witch.set_physics_process(false)
		if witch.witch_state == "allied":
			witch.remove_from_group("enemies")
		else:
			witch.add_to_group("enemies")
	_npc_society.call("save_world_state")
	# As estalagens existentes também são as tavernas da cidade: não se gera
	# uma construção adicional. Cada estalagem física recebe seu responsável
	# persistente, que trabalha no próprio edifício.
	var keeper_cities_seen: Dictionary = {}
	for inn_value in _npc_society.call("get_all_buildings"):
		if not (inn_value is Dictionary):
			continue
		var inn: Dictionary = inn_value
		if str(inn.get("kind", "")) != "inn":
			continue
		var inn_city_id := str(inn.get("city_id", ""))
		var inn_id := str(inn.get("id", ""))
		if inn_city_id == "" or inn_id == "":
			continue
		var ordinal: int = _npc_society.get_residents_of_city(inn_city_id).size() if _npc_society.has_method("get_residents_of_city") else 80
		# Mantém o ID histórico na primeira estalagem da cidade para preservar
		# nome, aparência e memórias de estalajadeiros já salvos.
		var keeper_id := "npc:%s:tavernkeeper" % inn_city_id
		if keeper_cities_seen.has(inn_city_id):
			keeper_id = "npc:%s:innkeeper:%s" % [inn_city_id, inn_id.replace("/", "_")]
		keeper_cities_seen[inn_city_id] = true
		_spawn_npc("estalajadeiro", "Estalajadeiro", inn.get("entry", inn.get("center", Vector3.ZERO)), inn_city_id, keeper_id, ordinal)
	_npc_society.finalize_npcs(npcs)
	_npc_society.call("save_world_state")
	_interactable_building_records.clear()
	var world_buildings: Array = _npc_society.call("get_all_buildings")
	# A casa já foi reservada antes de criar a população para que os NPCs nunca
	# ocupem o domicílio pessoal do jogador.
	var player_home_id := str(game.get("player_home_building_id")) if game != null else ""
	for building_value in world_buildings:
		if not (building_value is Dictionary):
			continue
		var building_record: Dictionary = building_value.duplicate()
		if str(building_record.get("id", "")) == player_home_id and player_home_id != "":
			building_record["is_player_home"] = true
			building_record["name"] = str(game.get("player_home_building_name"))
		# Só construções funcionais/habitáveis geram interiores. Templos e ruínas
		# são marcos exteriores; poços também não são edifícios visitáveis.
		if _building_supports_interior(building_record):
			_interactable_building_records.append(building_record)
	_spawn_stable_horses(world_buildings)

	# Pontos de interesse: dungeon vira entrada da cripta; o resto vira spawn de monstros
	for m in poi_raw:
		var pn: String = m["name"]
		if pn.contains("dungeon"):
			entrance_raw.append(m["pos"])
		else:
			_add_spawn(_poi_pool(pn), m["pos"], POI_SPAWN_RADIUS)
	for m in spawn_raw:
		_add_spawn(_pool_for_marker(m["name"], m["pos"]), m["pos"], MARKER_SPAWN_RADIUS)
	# Campo aberto: pontos espalhados fora das cidades e longe da água
	for i in FIELD_SPAWNS:
		var fp = _random_land_point()
		if fp != null:
			_add_spawn(_field_pool(fp), fp, FIELD_SPAWN_RADIUS)

	# Recursos naturais são gerados depois de conhecer as cidades e os POIs,
	# permitindo criar locais nomeados e contratos de coleta ligados a eles.
	_setup_natural_resources(poi_raw)
	# Os recursos naturais são gerados após os NPCs; atualizamos seu conhecimento
	# para que profissões, coleta e geografia façam parte da mesma simulação.
	if _npc_society != null:
		_npc_society.call("register_resource_sites", resource_sites)
		_npc_society.call("refresh_npc_world_knowledge", npcs)

	if entrance_raw.is_empty():
		var ep = _random_ground_point(bounds, 40.0, 120.0)
		entrance_raw.append(ep if ep != null else start_pos + Vector3(40, 0, 0))
	for p in entrance_raw:
		var entrance_node := _build_entrance(_ground(p))
		var entrance_id: String = "crypt_%02d" % entrances.size()
		var was_discovered: bool = game != null and game.discovered_dungeons_session.has(entrance_id)
		entrance_node.set_meta("entrance_id", entrance_id)
		entrance_node.set_meta("discovered", was_discovered)
		if was_discovered and not discovered_entrances.has(entrance_id):
			discovered_entrances.append(entrance_id)
		entrances.append(entrance_node)

	# Inicializa as ameaças por região depois de conhecer as cidades, os spawns e
	# as criptas. O estado fica em memória no game.gd ao reiniciar uma tentativa.
	_regional_threats = REGIONAL_THREATS_SCRIPT.new()
	_regional_threats.name = "RegionalThreats"
	add_child(_regional_threats)
	var dungeon_positions: Array[Vector3] = []
	for entrance in entrances:
		if is_instance_valid(entrance):
			dungeon_positions.append(entrance.global_position)
	var previous_regional_state: Dictionary = game.get("regional_threat_session_state") if game != null else {}
	var city_radii: Dictionary = _npc_society.get_city_influence_radii() if _npc_society != null else {}
	_regional_threats.initialize(settlement_points, spawns, dungeon_positions, game, previous_regional_state, city_radii)

	# Prepara só a colisão das estruturas mais próximas do ponto inicial. O resto
	# será ativado em lotes quando o jogador se aproximar.
	_prime_stream_collisions(start_pos, STREAM_INITIAL_COLLISION_BUDGET)
	game.player.global_position = start_pos + Vector3(0, 0.2, 0)
	game.player.velocity = Vector3.ZERO
	_environment_details = ENVIRONMENT_DETAILS_SCRIPT.new()
	_environment_details.name = "EnvironmentDetails"
	add_child(_environment_details)
	var saved_foot_traffic: Dictionary = game.get("foot_traffic_session_state") if game != null else {}
	_environment_details.initialize(self, map_bounds, settlement_points, game.player, saved_foot_traffic)
	if map_note == "":
		map_note = "Você chega às estradas de Os Cânticos dos Sete: Brumaférrea. Fale com os moradores (F)."
	ready_to_run = true


# ---------- Imagem do mapa ----------

func _land_bounds(fallback: AABB) -> AABB:
	# Usa só a malha do terreno para enquadrar o mapa (o oceano costuma ser bem maior)
	var meshes: Array = []
	_collect_meshes(_map, meshes)
	var total := AABB()
	var first := true
	for mi in meshes:
		if not str(mi.name).to_lower().contains("terrain"):
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if first:
			total = box
			first = false
		else:
			total = total.merge(box)
	return fallback if first else total


func _build_map_texture() -> void:
	# Câmera ortográfica olhando de cima, renderizada uma única vez num SubViewport.
	# Norte (-Z) fica em cima e leste (+X) à direita, igual ao desenho do world_map.gd.
	map_bounds = _land_bounds(world_bounds)
	map_extent = maxf(map_bounds.size.x, map_bounds.size.z) * 1.03
	map_center = map_bounds.get_center()
	_map_viewport = SubViewport.new()
	_map_viewport.size = Vector2i(MAP_RES, MAP_RES)
	_map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_map_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_map_viewport.handle_input_locally = false
	_map_viewport.audio_listener_enable_3d = false
	add_child(_map_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var cam := Camera3D.new()
	cam.environment = env
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = map_extent
	cam.near = 1.0
	cam.far = map_bounds.size.y + 2000.0
	_map_viewport.add_child(cam)
	cam.global_position = Vector3(map_center.x, map_bounds.end.y + 500.0, map_center.z)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	map_texture = _map_viewport.get_texture()


# ---------- Atualização ----------

func _process(delta: float) -> void:
	if not ready_to_run or game == null:
		return
	if _inside_building:
		# A porta continua tendo prioridade para sair; fora dela, moradores em casa
		# podem ser selecionados pela mira como qualquer NPC do mundo exterior.
		var looking_at_exit: bool = (game.phase == "play") and is_aiming_at_exit()
		var interior_aimed: Dictionary = {}
		if game.phase == "play" and not looking_at_exit and game.player != null:
			interior_aimed = aimed_interactable(game.player.global_position, INTERACT_REACH)
			if str(interior_aimed.get("kind", "")) not in ["npc", "home_bed", "home_storage"]:
				interior_aimed.clear()
		var looking_at_resident: bool = str(interior_aimed.get("kind", "")) == "npc"
		var looking_at_home_target: bool = str(interior_aimed.get("kind", "")) in ["home_bed", "home_storage"]
		if is_instance_valid(_prompt):
			_prompt.visible = looking_at_exit or looking_at_resident or looking_at_home_target
			if looking_at_exit:
				_prompt.text = "[F] Abrir a porta e sair"
			elif looking_at_resident:
				_prompt.text = "[F] Falar com %s" % str(interior_aimed["node"].display_name)
			elif str(interior_aimed.get("kind", "")) == "home_bed":
				_prompt.text = "[F] Dormir até o amanhecer"
			elif str(interior_aimed.get("kind", "")) == "home_storage":
				_prompt.text = "[F] Abrir baú pessoal"
			else:
				_prompt.text = ""
		if is_instance_valid(_aim_reticle):
			_aim_reticle.visible = game.phase == "play"
			_aim_reticle.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35) if looking_at_exit or looking_at_resident or looking_at_home_target else Color(0.9, 0.9, 0.85))
		# A rotina exterior retorna cedo enquanto o jogador está num interior; a
		# simulação social, porém, deve continuar para frequentadores conversarem.
		if _npc_society != null and game.player != null:
			_npc_society.tick(delta, time_of_day_hours, game.phase == "play", npcs, game.player.global_position, NPC_ACTIVE_RADIUS)
		return
	if game.phase != "pause":
		_update_day_night(delta)
		_update_weather(delta)
	_update_sky_domes()
	if game.player == null:
		return
	var pp: Vector3 = game.player.global_position
	_update_lantern_lighting(delta, pp)
	if game.phase == "play" and _regional_threats != null:
		_regional_threats.tick(delta, time_of_day_hours)
		_region_feedback_timer += delta
		if _region_feedback_timer >= 0.8:
			_region_feedback_timer = 0.0
			_update_region_feedback(pp)
	if _npc_society != null:
		_npc_society.tick(delta, time_of_day_hours, game.phase == "play", npcs, pp, NPC_ACTIVE_RADIUS)
	if game.phase == "play":
		_city_presence_timer += delta
		if _city_presence_timer >= 0.75:
			_city_presence_timer = 0.0
			_sync_city_occupation_presence(pp)
	_update_world_streaming(delta, pp)
	if _environment_details != null and is_instance_valid(_environment_details):
		_environment_details.tick(delta, pp, game.phase == "play", npcs)
	_update_entrance_discovery(pp)
	var aimed: Dictionary = {}
	if game.phase == "play":
		# Interação por mira: nenhuma interação acontece apenas por estar perto.
		aimed = aimed_interactable(pp, INTERACT_REACH)
	if bool(game.player.get("is_mounted")):
		_prompt.visible = game.phase == "play"
		_prompt.text = "[F] Desmontar do cavalo" if game.phase == "play" else ""
	else:
		_prompt.visible = game.phase == "play" and not aimed.is_empty()
	if not bool(game.player.get("is_mounted")) and not aimed.is_empty():
		if aimed["kind"] == "entrance":
			_prompt.text = "[F] Descer à cripta"
		elif aimed["kind"] == "building":
			_prompt.text = "[F] Entrar em %s" % str(aimed["record"].get("name", "construção"))
		elif aimed["kind"] == "resource":
			_prompt.text = "[F] Coletar %s" % str(aimed["node"].resource_name)
		elif aimed["kind"] == "horse":
			_prompt.text = "[F] Montar no cavalo"
		else:
			_prompt.text = "[F] Falar com %s" % aimed["node"].display_name
	if is_instance_valid(_aim_reticle):
		_aim_reticle.visible = game.phase == "play"
		_aim_reticle.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35) if not aimed.is_empty() else Color(0.9, 0.9, 0.85))
	if game.phase == "play":
		# Os pontos de spawn mudam em escala de segundos; não precisam varrer
		# todos os pontos e inimigos em todos os frames.
		_spawn_check_timer += delta
		if _spawn_check_timer >= 0.25:
			var spawn_elapsed: float = _spawn_check_timer
			_spawn_check_timer = 0.0
			_tick_spawns(spawn_elapsed, pp)
		var zone := safe_zone_at(pp)
		if zone != _safe_name:
			if zone != "":
				game.show_zone_title(zone, "Zona segura")
			elif _safe_name != "":
				game.show_msg("Você saiu da zona segura.")
			_safe_name = zone


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if game == null or game.phase != "play":
		return
	match key_event.keycode:
		KEY_KP_0:
			automatic_weather = true
			# Cancela todos os overrides de teste; caso contrário, células vizinhas
			# poderiam continuar forçando um clima após reativar o modo automático.
			for region_key in _weather_regions.keys():
				var region_state: Dictionary = _weather_regions[region_key]
				if bool(region_state.get("weather_override", false)):
					region_state["weather_override"] = false
					region_state["timer"] = 0.0
					_weather_regions[region_key] = region_state
			game.show_msg("Clima automático ativado. Teclado numérico: 0 automático, 1 limpo, 2 nublado, 3 chuva, 4 tempestade, 5 neve, 6 nevasca.")
		KEY_KP_1:
			_force_weather_for_player(Weather.CLEAR)
			game.show_msg("Clima local: céu limpo.")
		KEY_KP_2:
			_force_weather_for_player(Weather.CLOUDY)
			game.show_msg("Clima local: nublado.")
		KEY_KP_3:
			_force_weather_for_player(Weather.RAIN)
			game.show_msg("Clima local: chuva ou neve, conforme a região.")
		KEY_KP_4:
			_force_weather_for_player(Weather.STORM)
			game.show_msg("Clima local: tempestade ou nevasca, conforme a região.")
		KEY_KP_5:
			_force_weather_for_player(Weather.SNOW)
			game.show_msg("Teste de neve ativado.")
		KEY_KP_6:
			_force_weather_for_player(Weather.SNOWSTORM)
			game.show_msg("Teste de tempestade de neve ativado.")
		_:
			return
	get_viewport().set_input_as_handled()


func aimed_interactable(_player_position: Vector3, reach: float) -> Dictionary:
	# Escolhe apenas alvos próximos ao raio central da câmera e com linha de
	# visão desobstruída. A distância por si só nunca inicia uma interação.
	if game == null or game.player == null or game.player.cam == null:
		return {}
	var camera: Camera3D = game.player.cam
	var ray_origin: Vector3 = camera.global_position
	var ray_direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var best: Dictionary = {}
	var best_score := INF

	var nearby_limit_squared := (reach + 1.0) * (reach + 1.0)
	for n in npcs:
		if not is_instance_valid(n) or not n.visible:
			continue
		if bool(n.is_at_home) and not bool(n.is_interior_present):
			continue
		var target_pos: Vector3 = n.global_position + Vector3(0.0, 1.18, 0.0)
		if target_pos.distance_squared_to(ray_origin) > nearby_limit_squared:
			continue
		var candidate := {"kind": "npc", "node": n, "target_pos": target_pos, "radius": 0.58}
		var score := _aim_candidate_score(ray_origin, ray_direction, reach, candidate)
		if score < best_score:
			best_score = score
			best = candidate

	# Cavalos ficam disponíveis perto de estábulos; somente podem ser montados
	# quando não estão sendo usados pelo jogador.
	if not bool(game.player.get("is_mounted")):
		for horse_record_value in _horses:
			if not (horse_record_value is Dictionary):
				continue
			var horse_record: Dictionary = horse_record_value
			if bool(horse_record.get("mounted", false)):
				continue
			var horse_node: Node3D = horse_record.get("node")
			if not is_instance_valid(horse_node) or not horse_node.visible:
				continue
			var horse_target: Vector3 = horse_node.global_position + Vector3(0.0, 1.18, 0.0)
			if horse_target.distance_squared_to(ray_origin) > nearby_limit_squared:
				continue
			var horse_candidate := {"kind": "horse", "node": horse_node, "target_pos": horse_target, "radius": 0.78}
			var horse_score := _aim_candidate_score(ray_origin, ray_direction, reach, horse_candidate)
			if horse_score < best_score:
				best_score = horse_score
				best = horse_candidate

	for resource_node in _resource_nodes:
		if not is_instance_valid(resource_node) or not resource_node.visible:
			continue
		if resource_node.has_method("can_gather") and not bool(resource_node.call("can_gather")):
			continue
		var target_pos: Vector3 = resource_node.global_position + Vector3(0.0, 0.42, 0.0)
		if target_pos.distance_squared_to(ray_origin) > nearby_limit_squared:
			continue
		var candidate := {"kind": "resource", "node": resource_node, "target_pos": target_pos, "radius": 0.58}
		var score := _aim_candidate_score(ray_origin, ray_direction, reach, candidate)
		if score < best_score:
			best_score = score
			best = candidate

	for e in entrances:
		if not is_instance_valid(e) or not e.visible:
			continue
		var target_pos: Vector3 = e.global_position + Vector3(0.0, 1.45, 0.0)
		if target_pos.distance_squared_to(ray_origin) > (reach + 1.5) * (reach + 1.5):
			continue
		var candidate := {"kind": "entrance", "node": e, "target_pos": target_pos, "radius": 1.05}
		var score := _aim_candidate_score(ray_origin, ray_direction, reach, candidate)
		if score < best_score:
			best_score = score
			best = candidate

	for record_value in _interactable_building_records:
		var record: Dictionary = record_value
		var entry: Vector3 = record.get("entry", Vector3.ZERO)
		# Há centenas de edifícios no GLB. Descartar entradas distantes primeiro evita
		# testar dados internos de estabelecimentos que não podem ser alcançados pela mira.
		if entry.distance_squared_to(ray_origin) > nearby_limit_squared:
			continue
		if not _building_supports_interior(record):
			continue
		var front: Vector3 = record.get("front_direction", Vector3.FORWARD)
		front.y = 0.0
		if front.length_squared() < 0.001:
			front = Vector3.FORWARD
		front = front.normalized()
		var target_pos: Vector3 = record.get("center", entry)
		var front_depth := float(record.get("front_depth", 0.0))
		# Mira no plano da fachada, não no ponto de chegada do NPC/jogador,
		# que fica cerca de um metro fora da porta.
		target_pos.x += front.x * (front_depth + 0.06)
		target_pos.z += front.z * (front_depth + 0.06)
		target_pos.y = entry.y + 1.2
		var candidate := {"kind": "building", "record": record, "target_pos": target_pos, "radius": 0.82}
		var score := _aim_candidate_score(ray_origin, ray_direction, reach, candidate)
		if score < best_score:
			best_score = score
			best = candidate

	# Balcão e quadro de notícias só são interativos dentro de estalagens e tavernas.
	if _inside_building and is_instance_valid(_active_interior) and str(_active_building_record.get("kind", "")) in ["inn", "tavern"]:
		var tavern_targets: Array[Dictionary] = [
			{"node_name": "InnBarTop", "kind": "tavern_counter", "radius": 1.2},
			{"node_name": "TavernCounterTop", "kind": "tavern_counter", "radius": 1.2},
			{"node_name": "TavernNoticeBoard", "kind": "tavern_board", "radius": 1.0}
		]
		for target_info in tavern_targets:
			var target_node := _active_interior.get_node_or_null(str(target_info.get("node_name", ""))) as StaticBody3D
			if target_node == null or not target_node.has_meta("interaction_target"):
				continue
			if str(target_node.get_meta("interaction_target")) != str(target_info.get("kind", "")):
				continue
			var target_pos: Vector3 = target_node.global_position + Vector3(0.0, 0.1, 0.0)
			var candidate := {"kind": str(target_info.get("kind", "")), "node": target_node, "target_pos": target_pos, "radius": float(target_info.get("radius", 0.8))}
			var score := _aim_candidate_score(ray_origin, ray_direction, reach, candidate)
			if score < best_score:
				best_score = score
				best = candidate

	# Cama e baú só são interativos na casa do jogador; móveis equivalentes nas
	# casas alheias permanecem decoração, não um armazenamento compartilhado.
	if _inside_building and is_instance_valid(_active_interior) and bool(_active_building_record.get("is_player_home", false)):
		for target_info in [{"node_name": "BedMattress", "kind": "home_bed", "radius": 0.95}, {"node_name": "StorageChest", "kind": "home_storage", "radius": 0.85}]:
			var target_node := _active_interior.get_node_or_null(str(target_info["node_name"])) as StaticBody3D
			if target_node == null or not target_node.has_meta("interaction_target"):
				continue
			var target_pos: Vector3 = target_node.global_position + Vector3(0.0, 0.12, 0.0)
			var candidate := {"kind": str(target_info["kind"]), "node": target_node, "target_pos": target_pos, "radius": float(target_info["radius"])}
			var score := _aim_candidate_score(ray_origin, ray_direction, reach, candidate)
			if score < best_score:
				best_score = score
				best = candidate

	if best.is_empty():
		return {}
	best.erase("target_pos")
	best.erase("radius")
	return best


func _aim_candidate_score(ray_origin: Vector3, ray_direction: Vector3, reach: float, candidate: Dictionary) -> float:
	var target_pos: Vector3 = candidate["target_pos"]
	var delta: Vector3 = target_pos - ray_origin
	var along := delta.dot(ray_direction)
	if along < 0.0 or along > reach:
		return INF
	var closest_point := ray_origin + ray_direction * along
	var miss_distance := target_pos.distance_to(closest_point)
	var radius := float(candidate.get("radius", 0.6))
	if miss_distance > radius:
		return INF
	if not _aim_line_of_sight_clear(ray_origin, target_pos, candidate):
		return INF
	# Prioriza o alvo mais centrado na mira; desempata pelo mais próximo.
	return miss_distance / maxf(radius, 0.01) + along * 0.0005


func _aim_line_of_sight_clear(ray_origin: Vector3, target_pos: Vector3, candidate: Dictionary) -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsRayQueryParameters3D.create(ray_origin, target_pos + (target_pos - ray_origin).normalized() * AIM_TARGET_RAY_EPSILON)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if game != null and game.player != null:
		query.exclude = [game.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	match str(candidate.get("kind", "")):
		"npc":
			return collider == candidate.get("node")
		"entrance":
			var entrance_node: Node = candidate.get("node")
			return collider == entrance_node or (collider is Node and entrance_node.is_ancestor_of(collider))
		"resource":
			var resource_node: Node = candidate.get("node")
			return collider == resource_node or (collider is Node and resource_node.is_ancestor_of(collider))
		"horse":
			var horse_node: Node = candidate.get("node")
			return collider == horse_node or (collider is Node and horse_node.is_ancestor_of(collider))
		"home_bed", "home_storage", "tavern_counter", "tavern_board":
			var home_target: Node = candidate.get("node")
			if collider == home_target or (collider is Node and home_target.is_ancestor_of(collider)):
				return true
			# O estrado e o colchão ocupam volumes adjacentes; ambos contam como
			# a cama, evitando que a colisão de um impeça interagir com o outro.
			return collider is Node and str((collider as Node).get_meta("interaction_target", "")) == str(candidate.get("kind", ""))
		"building":
			var record: Dictionary = candidate.get("record", {})
			var building_node: Node = record.get("node")
			if building_node != null and collider is Node and (collider == building_node or building_node.is_ancestor_of(collider)):
				var hit_pos: Vector3 = hit.get("position", target_pos)
				return hit_pos.distance_to(target_pos) <= 0.75
	return false


func is_aiming_at_exit() -> bool:
	if not _inside_building or not is_instance_valid(_active_interior) or game == null or game.player == null:
		return false
	var door := _active_interior.get_node_or_null("ExitDoor") as StaticBody3D
	if door == null:
		return false
	var camera: Camera3D = game.player.cam
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 5.0)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [game.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	return collider == door or (collider is Node and door.is_ancestor_of(collider))


func _spawn_stable_horses(world_buildings: Array) -> void:
	_horses.clear()
	var stable_by_city: Dictionary = {}
	for building_value in world_buildings:
		if not (building_value is Dictionary):
			continue
		var building_record: Dictionary = building_value
		if str(building_record.get("kind", "")) != "stable":
			continue
		var stable_city_id := str(building_record.get("city_id", ""))
		if stable_city_id != "" and not stable_by_city.has(stable_city_id):
			stable_by_city[stable_city_id] = building_record

	for settlement_value in settlement_points:
		if not (settlement_value is Dictionary):
			continue
		var settlement: Dictionary = settlement_value
		var city_id := str(settlement.get("id", ""))
		if city_id == "":
			continue
		var spawn_position := Vector3.ZERO
		var facing := Vector3(0.0, 0.0, -1.0)
		var stable_id := ""
		var found_position := false

		if stable_by_city.has(city_id):
			var stable: Dictionary = stable_by_city[city_id]
			stable_id = str(stable.get("id", ""))
			var center: Vector3 = stable.get("center", stable.get("entry", settlement.get("pos", start_pos)))
			facing = stable.get("front_direction", Vector3(0.0, 0.0, 1.0))
			facing.y = 0.0
			if facing.length_squared() < 0.001:
				facing = Vector3(0.0, 0.0, 1.0)
			facing = facing.normalized()
			var side := Vector3(facing.z, 0.0, -facing.x).normalized()
			var front_depth := float(stable.get("front_depth", 0.0))
			var stable_candidates: Array[Vector3] = [
				center + facing * (front_depth + 2.0) + side * 2.0,
				center + facing * (front_depth + 3.4) - side * 2.0,
				center + facing * (front_depth + 4.5) + side * 3.0,
				center + facing * (front_depth + 5.0) - side * 3.0
			]
			for candidate in stable_candidates:
				if not _horse_position_clear(city_id, candidate, world_buildings, 0.65):
					continue
				spawn_position = _ground(candidate)
				found_position = true
				break

		# Nem toda cidade necessariamente contém um estábulo gerado. Nesse caso,
		# coloca a montaria num ponto livre na periferia, sem enterrá-la em edifícios.
		if not found_position:
			var settlement_pos: Vector3 = settlement.get("pos", start_pos)
			for radius_value in [18.0, 24.0, 30.0, 36.0]:
				var radius := float(radius_value)
				for angle_index in range(8):
					var angle := TAU * float(angle_index) / 8.0
					var candidate := settlement_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
					if not _horse_position_clear(city_id, candidate, world_buildings, 0.8):
						continue
					spawn_position = _ground(candidate)
					facing = Vector3(-cos(angle), 0.0, -sin(angle)).normalized()
					found_position = true
					break
				if found_position:
					break

		if found_position:
			_add_horse_mount(city_id, stable_id, spawn_position, facing)

	# Fallback de segurança para mapas de teste sem marcadores settlement_.
	if _horses.is_empty():
		var fallback_position := _ground(start_pos + Vector3(7.0, 0.0, 5.0))
		_add_horse_mount("test_stable", "", fallback_position, Vector3(0.0, 0.0, -1.0))


func _horse_position_clear(city_id: String, point: Vector3, world_buildings: Array, margin: float = 0.65) -> bool:
	for building_value in world_buildings:
		if not (building_value is Dictionary):
			continue
		var building_record: Dictionary = building_value
		if city_id != "" and str(building_record.get("city_id", "")) != city_id:
			continue
		var bounds_value: Variant = building_record.get("bounds")
		if not (bounds_value is AABB):
			continue
		var bounds: AABB = bounds_value
		if point.x >= bounds.position.x - margin and point.x <= bounds.end.x + margin and point.z >= bounds.position.z - margin and point.z <= bounds.end.z + margin:
			return false
	return true


func _add_horse_mount(city_id: String, stable_id: String, position: Vector3, facing: Vector3) -> void:
	var horse := Node3D.new()
	horse.name = "HorseMount_%s" % city_id.replace("/", "_")
	horse.set_meta("interaction_target", "horse")

	# Billboard 3D com a animação original de Daggerfall. O sprite permanece no
	# mundo quando desmontado; montado, some daqui e MRED00I0 aparece na câmera.
	var horse_sprite := AnimatedSprite3D.new()
	horse_sprite.name = "DaggerfallHorseSprite"
	horse_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	horse_sprite.pixel_size = 0.021
	horse_sprite.position = Vector3(0.0, 0.94, 0.0)
	horse_sprite.shaded = false
	horse_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	horse_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	horse_sprite.transparent = true
	var horse_frames := SpriteFrames.new()
	horse_frames.add_animation("idle")
	horse_frames.set_animation_speed("idle", 4.0)
	horse_frames.set_animation_loop("idle", true)
	for frame_texture_value in HORSE_WORLD_FRAMES_BROWN:
		var frame_texture := frame_texture_value as Texture2D
		if frame_texture != null:
			horse_frames.add_frame("idle", frame_texture)
	horse_sprite.sprite_frames = horse_frames
	horse_sprite.play("idle")
	horse.add_child(horse_sprite)
	horse.set_meta("world_sprite", horse_sprite)

	# A hitbox permite mirar no cavalo e apertar F; não bloqueia a locomoção.
	var interaction_body := StaticBody3D.new()
	interaction_body.name = "InteractionBody"
	interaction_body.collision_layer = 2
	interaction_body.collision_mask = 0
	interaction_body.position = Vector3(0.0, 1.05, -0.05)
	var interaction_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.66
	interaction_shape.shape = sphere_shape
	interaction_body.add_child(interaction_shape)
	horse.add_child(interaction_body)
	add_child(horse)
	horse.global_position = _ground(position) + Vector3(0.0, 0.02, 0.0)
	var horizontal_facing := facing
	horizontal_facing.y = 0.0
	if horizontal_facing.length_squared() < 0.001:
		horizontal_facing = Vector3(0.0, 0.0, -1.0)
	horizontal_facing = horizontal_facing.normalized()
	horse.rotation.y = atan2(-horizontal_facing.x, -horizontal_facing.z)
	_horses.append({"id": "horse:%s" % city_id, "city_id": city_id, "stable_id": stable_id, "node": horse, "mounted": false})

func _horse_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _add_horse_mesh_part(parent: Node3D, mesh: PrimitiveMesh, local_position: Vector3, local_scale: Vector3, material: Material, local_rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.scale = local_scale
	mesh_instance.rotation = local_rotation
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func get_horse_save_state() -> Array:
	var saved_horses: Array = []
	for horse_record_value in _horses:
		if not (horse_record_value is Dictionary):
			continue
		var horse_record: Dictionary = horse_record_value
		var horse_node: Node3D = horse_record.get("node") as Node3D
		if not is_instance_valid(horse_node):
			continue
		var is_mounted_horse: bool = bool(horse_record.get("mounted", false)) or horse_node == _mounted_horse
		var horse_position: Vector3 = horse_node.global_position
		var horse_rotation_y: float = horse_node.global_rotation.y
		if is_mounted_horse and game != null and game.player != null and is_instance_valid(game.player):
			horse_position = game.player.global_position
			horse_rotation_y = game.player.global_rotation.y
		saved_horses.append({
			"id": str(horse_record.get("id", horse_node.name)),
			"city_id": str(horse_record.get("city_id", "")),
			"stable_id": str(horse_record.get("stable_id", "")),
			"position": [horse_position.x, horse_position.y, horse_position.z],
			"rotation_y": horse_rotation_y,
			"mounted": is_mounted_horse
		})
	return saved_horses


func restore_horse_save_state(saved_horses: Array) -> void:
	if game == null or game.player == null or not is_instance_valid(game.player):
		return
	var mounted_horse_to_restore: Node3D = null
	var mounted_record_index := -1
	for saved_value in saved_horses:
		if not (saved_value is Dictionary):
			continue
		var saved_record: Dictionary = saved_value
		var saved_id := str(saved_record.get("id", ""))
		var saved_city := str(saved_record.get("city_id", ""))
		var matched_index := -1
		for i in range(_horses.size()):
			var candidate_record: Dictionary = _horses[i]
			if saved_id != "" and str(candidate_record.get("id", "")) == saved_id:
				matched_index = i
				break
		if matched_index < 0 and saved_city != "":
			for i in range(_horses.size()):
				var candidate_record: Dictionary = _horses[i]
				if str(candidate_record.get("city_id", "")) == saved_city:
					matched_index = i
					break
		if matched_index < 0:
			continue
		var horse_record: Dictionary = _horses[matched_index]
		var horse_node: Node3D = horse_record.get("node") as Node3D
		if not is_instance_valid(horse_node):
			continue
		var is_mounted: bool = bool(saved_record.get("mounted", false))
		var position_value: Variant = saved_record.get("position", [])
		var saved_position := horse_node.global_position
		var has_saved_position := false
		if position_value is Array and position_value.size() >= 3:
			saved_position = Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
			has_saved_position = is_finite(saved_position.x) and is_finite(saved_position.y) and is_finite(saved_position.z)
		var saved_rotation_y := float(saved_record.get("rotation_y", horse_node.global_rotation.y))
		if is_mounted:
			mounted_horse_to_restore = horse_node
			mounted_record_index = matched_index
			horse_record["mounted"] = true
		else:
			if horse_node.get_parent() != self:
				horse_node.reparent(self, true)
			if has_saved_position:
				horse_node.global_position = _ground(saved_position) + Vector3(0.0, 0.02, 0.0)
			horse_node.global_rotation = Vector3(0.0, saved_rotation_y, 0.0)
			horse_record["mounted"] = false
			if has_saved_position:
				horse_record["last_position"] = horse_node.global_position
			var sprite: AnimatedSprite3D = horse_node.get_meta("world_sprite", null) as AnimatedSprite3D
			if sprite != null:
				sprite.visible = true
		_horses[matched_index] = horse_record
	if is_instance_valid(mounted_horse_to_restore):
		if mounted_horse_to_restore.get_parent() != game.player:
			mounted_horse_to_restore.reparent(game.player, true)
		mounted_horse_to_restore.position = Vector3.ZERO
		mounted_horse_to_restore.rotation = Vector3.ZERO
		_mounted_horse = mounted_horse_to_restore
		var mounted_sprite: AnimatedSprite3D = mounted_horse_to_restore.get_meta("world_sprite", null) as AnimatedSprite3D
		if mounted_sprite != null:
			mounted_sprite.visible = false
		if mounted_record_index >= 0:
			var mounted_record: Dictionary = _horses[mounted_record_index]
			mounted_record["mounted"] = true
			_horses[mounted_record_index] = mounted_record
		game.player.call("set_mounted_state", true)
	else:
		_mounted_horse = null
		game.player.call("set_mounted_state", false)


func mount_horse(horse_node: Node3D) -> bool:
	if game == null or game.player == null or game.phase != "play" or _inside_building or horse_node == null or not is_instance_valid(horse_node):
		return false
	if bool(game.player.get("is_mounted")):
		return false
	var record_index := -1
	for i in range(_horses.size()):
		var horse_record: Dictionary = _horses[i]
		if horse_record.get("node") == horse_node and not bool(horse_record.get("mounted", false)):
			record_index = i
			break
	if record_index < 0:
		return false
	horse_node.reparent(game.player)
	horse_node.position = Vector3.ZERO
	horse_node.rotation = Vector3.ZERO
	var record: Dictionary = _horses[record_index]
	record["mounted"] = true
	_horses[record_index] = record
	_mounted_horse = horse_node
	var mounted_sprite := horse_node.get_meta("world_sprite", null) as AnimatedSprite3D
	if mounted_sprite != null:
		mounted_sprite.visible = false
	game.player.call("set_mounted_state", true)
	game.show_msg("Você montou no cavalo. Segure Shift para galopar; pressione F para desmontar.")
	return true


func dismount_horse(silent: bool = false) -> void:
	if game == null or game.player == null:
		return
	var horse_node := _mounted_horse
	if horse_node == null or not is_instance_valid(horse_node):
		game.player.call("set_mounted_state", false)
		_mounted_horse = null
		return
	var player_node: Node3D = game.player
	var right := player_node.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var forward := -player_node.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var possible_positions: Array[Vector3] = [
		player_node.global_position + right * 1.65,
		player_node.global_position - right * 1.65,
		player_node.global_position - forward * 2.0,
		player_node.global_position + forward * 2.0
	]
	var all_buildings: Array = _npc_society.call("get_all_buildings") if _npc_society != null else []
	var dismount_position: Vector3 = possible_positions[0]
	for candidate in possible_positions:
		if _horse_position_clear("", candidate, all_buildings, 0.7):
			dismount_position = candidate
			break
	horse_node.reparent(self)
	horse_node.global_position = _ground(dismount_position) + Vector3(0.0, 0.02, 0.0)
	horse_node.global_rotation = Vector3(0.0, player_node.rotation.y, 0.0)
	var dismounted_sprite := horse_node.get_meta("world_sprite", null) as AnimatedSprite3D
	if dismounted_sprite != null:
		dismounted_sprite.visible = true
	for i in range(_horses.size()):
		var horse_record: Dictionary = _horses[i]
		if horse_record.get("node") == horse_node:
			horse_record["mounted"] = false
			horse_record["last_position"] = horse_node.global_position
			_horses[i] = horse_record
			break
	_mounted_horse = null
	player_node.call("set_mounted_state", false)
	if not silent:
		game.show_msg("Você desmontou do cavalo.")


func _building_supports_interior(record: Dictionary) -> bool:
	if record.is_empty():
		return false
	var building_node: Variant = record.get("node", null)
	if building_node is MeshInstance3D and bool(building_node.get_meta("city_ruins_hidden", false)):
		return false
	if bool(record.get("is_landmark", false)):
		return false
	if record.has("supports_interior"):
		return bool(record.get("supports_interior", false))
	var kind := str(record.get("kind", "")).to_lower()
	# Lista positiva de compatibilidade: novos tipos não recebem interior por acidente.
	return kind in ["house", "shop", "workshop", "inn", "tavern", "town_hall", "library", "infirmary", "guard_post", "lookout", "depot", "shelter", "stable", "mill", "barn"]


func enter_building(record: Dictionary) -> bool:
	if _inside_building or game == null or game.player == null or record.is_empty():
		return false
	if not _building_supports_interior(record):
		game.show_msg("Este lugar é um marco exterior; não possui interior explorável.")
		return false
	_active_building_record = record.duplicate()
	_interior_return_position = game.player.global_position
	_interior_return_rotation = game.player.rotation
	_interior_return_pitch = float(game.player.get("_pitch"))
	_rain_was_emitting = is_instance_valid(rain_particles) and rain_particles.emitting
	_rain_was_visible = is_instance_valid(rain_particles) and rain_particles.visible
	_map_was_visible = is_instance_valid(_map) and _map.visible
	if is_instance_valid(rain_particles):
		rain_particles.emitting = false
		rain_particles.visible = false
	# A sala gerada fica isolada do cenário externo; a textura do mapa já foi
	# capturada em seu próprio SubViewport, então ocultar o GLB não afeta o mapa.
	if is_instance_valid(_map):
		_map.visible = false
	_inside_building = true
	_active_interior = Node3D.new()
	var safe_interior_name := str(record.get("id", "Building")).replace("/", "_").replace(" ", "_")
	_active_interior.name = "GeneratedInterior_%s" % safe_interior_name
	_active_interior.set_script(PROCEDURAL_INTERIOR_SCRIPT)
	add_child(_active_interior)
	var interior_origin := Vector3(map_center.x, map_bounds.end.y + 180.0, map_center.z)
	var spawn: Vector3 = _active_interior.call("build", record, interior_origin)
	_place_home_residents_inside(record)
	_place_inn_guests_inside(record)
	_place_workplace_npcs_inside(record)
	_place_tavern_patrons_inside(record)
	if _npc_society != null and _npc_society.has_method("set_active_conversation_interior"):
		_npc_society.call("set_active_conversation_interior", str(record.get("id", "")), str(record.get("kind", "")))
	game.player.global_position = _active_interior.to_global(spawn)
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player.set("_pitch", 0.0)
	game.player.cam.rotation.x = 0.0
	_prompt.visible = true
	_prompt.text = "[F] Sair de %s" % str(record.get("name", "este local"))
	game.show_zone_title(str(record.get("name", "Edifício")), str(record.get("kind", "local")).replace("_", " ").to_upper())
	if bool(record.get("is_player_home", false)):
		game.show_msg("Você chegou à sua casa. Aponte para a cama para descansar ou para o baú para guardar pertences.")
	else:
		game.show_msg("Interior gerado. Para sair, aponte a mira para a porta fechada e pressione F.")
	return true


func exit_building() -> void:
	if not _inside_building or game == null or game.player == null:
		return
	if _npc_society != null and _npc_society.has_method("set_active_conversation_interior"):
		_npc_society.call("set_active_conversation_interior", "", "")
	_restore_home_residents_after_visit()
	_restore_workplace_npcs_after_visit()
	_restore_tavern_patrons_after_visit()
	_inside_building = false
	if is_instance_valid(_active_interior):
		_active_interior.queue_free()
	_active_interior = null
	game.player.global_position = _interior_return_position + Vector3(0.0, 0.04, 0.0)
	game.player.velocity = Vector3.ZERO
	game.player.rotation = _interior_return_rotation
	game.player.set("_pitch", _interior_return_pitch)
	game.player.cam.rotation.x = _interior_return_pitch
	if is_instance_valid(_map):
		_map.visible = _map_was_visible
	if is_instance_valid(rain_particles):
		rain_particles.visible = _rain_was_visible
		rain_particles.emitting = _rain_was_emitting
	_prompt.visible = false
	game.show_zone_title(str(_active_building_record.get("name", "")), "")
	game.show_msg("Você saiu para a rua.")
	_active_building_record.clear()


func _place_home_residents_inside(record: Dictionary) -> void:
	# Só moradores cuja rotina os colocou em casa aparecem no interior. Usamos os
	# próprios NPCs do overworld para que fala, reputação e missões não se dupliquem.
	_interior_home_residents.clear()
	if str(record.get("kind", "")) != "house" or _active_interior == null or _npc_society == null:
		return
	var house_id := str(record.get("id", ""))
	if house_id == "":
		return
	var resident_ids: Array = _npc_society.get_residents_of_house(house_id)
	if resident_ids.is_empty():
		return
	# Pontos laterais do interior: ficam longe da mesa, cama e passagem da porta.
	# Em uma casa normal cabem dois residentes por domicílio.
	var stand_positions: Array[Vector3] = [
		Vector3(-3.45, 0.05, 0.15),
		Vector3(3.45, 0.05, 0.15),
		Vector3(-3.45, 0.05, -2.0),
		Vector3(3.45, 0.05, -2.0)
	]
	var slot := 0
	for npc in npcs:
		if not is_instance_valid(npc) or not resident_ids.has(str(npc.npc_id)):
			continue
		if not bool(npc.is_at_home) or bool(npc.is_interior_present):
			continue
		if slot >= stand_positions.size():
			break
		var interior_position: Vector3 = _active_interior.to_global(stand_positions[slot])
		if npc.has_method("place_for_home_visit"):
			npc.place_for_home_visit(interior_position, house_id)
			_interior_home_residents.append(npc)
			slot += 1


func _place_inn_guests_inside(record: Dictionary) -> void:
	# Mercadores ambulantes usam a estalagem como hospedagem, não como casa de
	# proprietário. Materializa o NPC persistente quando o jogador entra no local.
	if str(record.get("kind", "")) != "inn" or _active_interior == null:
		return
	var inn_id := str(record.get("id", ""))
	if inn_id == "":
		return
	var stand_positions: Array[Vector3] = [
		Vector3(-3.25, 0.05, -2.5), Vector3(3.0, 0.05, -2.5),
		Vector3(-3.0, 0.05, 0.4), Vector3(3.0, 0.05, 0.4)
	]
	var slot := 0
	for npc in npcs:
		if not is_instance_valid(npc) or str(npc.get("merchant_type")) != "itinerant":
			continue
		if str(npc.get("home_id")) != inn_id or not bool(npc.get("is_at_home")) or bool(npc.get("is_interior_present")):
			continue
		if slot >= stand_positions.size():
			break
		var interior_position: Vector3 = _active_interior.to_global(stand_positions[slot])
		if npc.has_method("place_for_home_visit"):
			npc.place_for_home_visit(interior_position, inn_id)
			_interior_home_residents.append(npc)
			slot += 1


func _place_workplace_npcs_inside(record: Dictionary) -> void:
	# Trabalhadores que cumpriram a rotina de expediente reaparecem no interior
	# procedural correto quando o jogador entra na oficina/loja/estalagem.
	_interior_work_npcs.clear()
	if str(record.get("kind", "")) == "house" or _active_interior == null:
		return
	var building_id := str(record.get("id", ""))
	if building_id == "":
		return
	var stand_positions: Array[Vector3]
	match str(record.get("kind", "")):
		"workshop":
			stand_positions = [Vector3(3.45, 0.05, 0.05), Vector3(1.3, 0.05, 0.25)]
		"shop":
			stand_positions = [Vector3(0.0, 0.05, -0.15), Vector3(2.3, 0.05, -0.1)]
		"inn":
			stand_positions = [Vector3(0.0, 0.05, -2.6), Vector3(3.2, 0.05, -2.6)]
		"tavern":
			stand_positions = [Vector3(0.0, 0.05, -3.0), Vector3(-3.0, 0.05, -1.0), Vector3(3.0, 0.05, -1.0)]
		"town_hall":
			stand_positions = [Vector3(0.0, 0.05, -2.8)]
		"guard_post", "lookout":
			stand_positions = [Vector3(0.0, 0.05, -1.6), Vector3(2.0, 0.05, 0.2)]
		"infirmary":
			stand_positions = [Vector3(-2.4, 0.05, 0.2), Vector3(2.4, 0.05, 0.2)]
		"library":
			stand_positions = [Vector3(0.0, 0.05, -0.7)]
		"mill", "barn", "stable", "depot", "shelter":
			stand_positions = [Vector3(0.0, 0.05, 0.1), Vector3(2.1, 0.05, 0.6)]
		_:
			stand_positions = [Vector3(0.0, 0.05, 0.0)]
	var slot := 0
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if str(npc.work_building_id) != building_id:
			continue
		if not bool(npc.is_at_work) or bool(npc.is_interior_present):
			continue
		if slot >= stand_positions.size():
			break
		var interior_position: Vector3 = _active_interior.to_global(stand_positions[slot])
		if npc.has_method("place_for_work_visit"):
			npc.place_for_work_visit(interior_position, building_id)
			_interior_work_npcs.append(npc)
			slot += 1


func _place_tavern_patrons_inside(record: Dictionary) -> void:
	_tavern_visit_npcs.clear()
	if str(record.get("kind", "")) not in ["inn", "tavern"] or _active_interior == null:
		return
	var city_id := str(record.get("city_id", ""))
	var inn_id := str(record.get("id", ""))
	var hour := fposmod(float(time_of_day_hours), 24.0)
	if hour < 10.0 or inn_id == "":
		return
	var candidates: Array = []
	var origin: Vector3 = record.get("entry", record.get("center", Vector3.ZERO))
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if str(npc.get("city_id")) != city_id or str(npc.get("role")) == "estalajadeiro":
			continue
		if bool(npc.get("is_at_home")) or bool(npc.get("is_at_work")) or bool(npc.get("is_interior_present")):
			continue
		if bool(npc.get("merchant_trip_active")):
			continue
		var is_regular_here := bool(npc.get("is_at_tavern")) and str(npc.get("tavern_building_id")) == inn_id
		var is_heading_here := str(npc.get("target_kind")) == "tavern" and str(npc.get("tavern_building_id")) == inn_id
		# Não teleporta moradores aleatórios da rua para dentro. Só aparecem os que
		# já entraram logicamente ou estão realmente a caminho desta estalagem.
		if not is_regular_here and not is_heading_here:
			continue
		if not is_regular_here:
			if not bool(npc.visible):
				continue
			if Vector2(npc.global_position.x - origin.x, npc.global_position.z - origin.z).length() > 105.0:
				continue
		candidates.append(npc)
	# Frequentadores que já atravessaram a porta têm prioridade sobre quem ainda
	# estava caminhando até ela.
	candidates.sort_custom(func(a, b):
		var a_is_inside := bool(a.get("is_at_tavern")) and str(a.get("tavern_building_id")) == inn_id
		var b_is_inside := bool(b.get("is_at_tavern")) and str(b.get("tavern_building_id")) == inn_id
		if a_is_inside != b_is_inside:
			return a_is_inside
		return abs((str(a.get("npc_id")) + inn_id).hash()) < abs((str(b.get("npc_id")) + inn_id).hash())
	)
	var patron_limit := 1 if hour < 16.0 else 4
	# Distância entre frequentadores fica abaixo do limite de conversa ambiente,
	# inclusive quando só há duas pessoas no salão.
	var stand_positions: Array[Vector3] = [Vector3(-2.0, 0.05, -1.8), Vector3(2.0, 0.05, -1.8), Vector3(-2.0, 0.05, 1.0), Vector3(2.0, 0.05, 1.0)]
	var slot := 0
	for npc in candidates:
		if slot >= patron_limit or slot >= stand_positions.size():
			break
		var interior_position: Vector3 = _active_interior.to_global(stand_positions[slot])
		if npc.has_method("place_for_tavern_visit") and bool(npc.call("place_for_tavern_visit", interior_position, inn_id)):
			_tavern_visit_npcs.append(npc)
			slot += 1


func _restore_tavern_patrons_after_visit() -> void:
	for npc in _tavern_visit_npcs:
		if is_instance_valid(npc) and npc.has_method("restore_tavern_visit"):
			npc.call("restore_tavern_visit")
	_tavern_visit_npcs.clear()


func _restore_workplace_npcs_after_visit() -> void:
	for npc in _interior_work_npcs:
		if is_instance_valid(npc) and npc.has_method("restore_work_after_visit"):
			npc.restore_work_after_visit()
	_interior_work_npcs.clear()


func _restore_home_residents_after_visit() -> void:
	# Devolve os moradores à simulação exterior ainda no estado "em casa". A rotina
	# normal é retomada no próximo ciclo após o jogador sair do interior.
	for npc in _interior_home_residents:
		if is_instance_valid(npc) and npc.has_method("restore_home_after_visit"):
			npc.restore_home_after_visit()
	_interior_home_residents.clear()


func is_inside_generated_interior() -> bool:
	return _inside_building


func sync_quest_giver_markers(giver_ids: Array) -> void:
	# O quest manager fornece os IDs estáveis dos contratantes que aguardam
	# entrega. O marcador é aplicado ao NPC certo, não a qualquer morador.
	var wanted: Dictionary = {}
	for giver_id_value in giver_ids:
		wanted[str(giver_id_value)] = true
	for npc in npcs:
		if not is_instance_valid(npc) or not npc.has_method("set_quest_return_marker"):
			continue
		npc.call("set_quest_return_marker", wanted.has(str(npc.get("npc_id"))))


func _tick_spawns(delta: float, pp: Vector3) -> void:
	# Os temporizadores continuam correndo fora de vista; ao entrar numa região,
	# os pontos elegíveis já podem gerar inimigos sem uma espera artificial longa.
	_spawn_global_timer = maxf(0.0, _spawn_global_timer - delta)
	var eligible: Array[Dictionary] = []
	for s in spawns:
		var alive: Array = s["alive"]
		for alive_index in range(alive.size() - 1, -1, -1):
			if not is_instance_valid(alive[alive_index]):
				alive.remove_at(alive_index)
		s["alive"] = alive
		s["timer"] = maxf(0.0, float(s["timer"]) - delta)
		if float(s["timer"]) > 0.0 or alive.size() >= MAX_ALIVE_PER_SPAWN:
			continue
		var sp: Vector3 = s["pos"]
		var d := Vector2(sp.x - pp.x, sp.z - pp.z).length()
		if d > ACTIVE_DIST or d < MIN_SPAWN_DIST:
			continue
		eligible.append(s)
	# Conta todos os inimigos ativos em torno do jogador, incluindo grupos de quest.
	# Assim, alvos de missão não passam por fora do limite normal de população.
	var nearby_enemies: int = 0
	for enemy_value in get_tree().get_nodes_in_group("overworld_enemies"):
		if not is_instance_valid(enemy_value) or not enemy_value.is_inside_tree():
			continue
		var enemy_node: Node3D = enemy_value as Node3D
		if enemy_node == null:
			continue
		var enemy_distance: float = Vector2(enemy_node.global_position.x - pp.x, enemy_node.global_position.z - pp.z).length()
		if enemy_distance <= ENEMY_ACTIVE_RADIUS:
			nearby_enemies += 1
	var nearby_limit: int = MAX_NEARBY_ENEMIES
	var is_night: bool = _is_night_spawn_period()
	if is_night:
		nearby_limit += 2
	if _regional_threats != null:
		var local_threat: float = _regional_threats.get_threat_at(pp)
		if local_threat >= 70.0:
			nearby_limit += 2
		elif local_threat >= 48.0:
			nearby_limit += 1
	if eligible.is_empty() or _spawn_global_timer > 0.0 or nearby_enemies >= nearby_limit:
		return
	# A ordem varia entre tentativas, para evitar que os mesmos pontos sempre
	# ganhem prioridade. O limite global evita que todos apareçam no mesmo frame.
	eligible.shuffle()
	for s in eligible:
		if _spawn_monster(s):
			s["timer"] = _next_spawn_delay(s["pos"])
			_spawn_global_timer = SPAWN_GLOBAL_COOLDOWN * (NIGHT_SPAWN_COOLDOWN_MULTIPLIER if is_night else 1.0)
			return
		# Um ponto inválido é tentado novamente logo, em vez de impor um cooldown
		# completo de respawn por uma tentativa que nem chegou a criar um inimigo.
		var retry_delay: float = rng.randf_range(SPAWN_RETRY_MIN, SPAWN_RETRY_MAX)
		if is_night:
			retry_delay *= NIGHT_SPAWN_RETRY_MULTIPLIER
		s["timer"] = retry_delay


func _is_night_spawn_period() -> bool:
	return time_of_day_hours >= 20.0 or time_of_day_hours < 6.0


func _spawn_monster(s: Dictionary) -> bool:
	if game == null or game.enemy_scene == null:
		return false
	var sp: Vector3 = s["pos"]
	var at := Vector3.ZERO
	var found_position := false
	# O registro define uma área ecológica, não uma coordenada fixa. Cada criatura
	# surge num ponto de terreno diferente dentro desse território.
	var radius: float = float(s.get("radius", FIELD_SPAWN_RADIUS))
	for _attempt in SPAWN_POSITION_ATTEMPTS:
		var angle := rng.randf_range(0.0, TAU)
		var distance := sqrt(rng.randf()) * radius
		var candidate := sp + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var ground_hit := _ground_hit(candidate)
		if ground_hit.is_empty():
			continue
		var grounded: Vector3 = ground_hit["position"]
		if safe_zone_at(grounded) != "" or grounded.y < sea_level + SEA_MARGIN:
			continue
		at = grounded
		found_position = true
		break
	if not found_position:
		return false
	var pool: Dictionary = _pool_adjusted_for_threat(s["pool"], at)
	var enemy_kind: String = _pick_kind(pool)
	var cfg := _enemy_cfg(enemy_kind)
	if cfg.is_empty():
		return false
	var e = game.enemy_scene.instantiate()
	if e == null:
		return false
	e.add_to_group("overworld_enemies")
	add_child(e)
	e.global_position = at + Vector3(0, 0.2, 0)
	e.setup(cfg, game)
	if e.has_method("set_stream_active"):
		e.call("set_stream_active", true)
	s["alive"].append(e)
	if _regional_threats != null:
		_regional_threats.report_enemy_spawn(at, enemy_kind)
	if _npc_society != null and _npc_society.has_method("report_world_event"):
		_npc_society.report_world_event(at, "monster_sighting", enemy_kind)
	return true


func _pool_adjusted_for_threat(source_pool: Dictionary, position: Vector3) -> Dictionary:
	var adjusted: Dictionary = source_pool.duplicate(true)
	if _regional_threats == null:
		return adjusted
	var threat: float = _regional_threats.get_threat_at(position)
	var multiplier: float = 1.0
	if threat >= 70.0:
		multiplier = 1.75
	elif threat >= 45.0:
		multiplier = 1.35
	for kind in ["goblin", "skel", "orc"]:
		if adjusted.has(kind):
			adjusted[kind] = float(adjusted[kind]) * multiplier
	return adjusted


func _next_spawn_delay(position: Vector3) -> float:
	var multiplier: float = 1.0
	if _regional_threats != null:
		var threat: float = _regional_threats.get_threat_at(position)
		multiplier = lerpf(1.0, 0.45, clampf(threat / 100.0, 0.0, 1.0))
	if _is_night_spawn_period():
		multiplier *= NIGHT_SPAWN_DELAY_MULTIPLIER
	return rng.randf_range(RESPAWN_MIN, RESPAWN_MAX) * multiplier


func _enemy_cfg(kind: String) -> Dictionary:
	for t in game.enemy_types:
		if t["kind"] == kind:
			var cfg: Dictionary = t.duplicate()
			cfg["texture"] = game.sprites[kind]
			return cfg
	return {}


# ---------- Marcadores e objetos ----------

func _collect_markers(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Node3D:
			out.append({"name": str(c.name).to_lower(), "pos": c.global_position})
		_collect_markers(c, out)


func _collect_meshes(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect_meshes(c, out)


func _bounds(node: Node) -> AABB:
	var meshes: Array = []
	_collect_meshes(node, meshes)
	var total := AABB()
	var first := true
	for mi in meshes:
		var box: AABB = mi.global_transform * mi.get_aabb()
		if first:
			total = box
			first = false
		else:
			total = total.merge(box)
	if first:
		return AABB(Vector3(-200, 0, -200), Vector3(400, 10, 400))
	return total


func _pool_for_marker(marker_name: String, pos: Vector3) -> Dictionary:
	for key in MARKER_POOLS:
		if marker_name.contains(key):
			return MARKER_POOLS[key]
	return _field_pool(pos)


func _poi_pool(marker_name: String) -> Dictionary:
	var parts := marker_name.split("_")
	var tipo := parts[parts.size() - 1]
	return POI_POOLS.get(tipo, POI_POOLS["ruins"])


func _field_pool(pos: Vector3) -> Dictionary:
	var d := _dist_to_nearest_settlement(pos)
	for tier in FIELD_POOLS:
		if d <= float(tier[0]):
			return tier[1]
	return FIELD_POOLS[FIELD_POOLS.size() - 1][1]


func _dist_to_nearest_settlement(pos: Vector3) -> float:
	var best := INF
	for st in settlement_points:
		var sp: Vector3 = st["pos"]
		best = minf(best, Vector2(sp.x - pos.x, sp.z - pos.z).length())
	if best == INF:
		best = Vector2(pos.x - start_pos.x, pos.z - start_pos.z).length()
	return best


func _pick_kind(pool: Dictionary) -> String:
	var total := 0.0
	for k in pool:
		total += float(pool[k])
	var r := rng.randf() * total
	for k in pool:
		r -= float(pool[k])
		if r <= 0.0:
			return str(k)
	return str(pool.keys()[0])


func _dominant_kind(pool: Dictionary) -> String:
	var best := ""
	var best_w := -1.0
	for k in pool:
		if float(pool[k]) > best_w:
			best_w = float(pool[k])
			best = str(k)
	return best


func _add_spawn(pool: Dictionary, pos: Vector3, area_radius: float = FIELD_SPAWN_RADIUS) -> void:
	var ground := _ground(pos)
	if safe_zone_at(ground) != "":
		return  # nada de monstro em cidade nem nos arredores
	var first_spawn_max: float = FIRST_SPAWN_MAX
	if _is_night_spawn_period():
		first_spawn_max *= NIGHT_SPAWN_DELAY_MULTIPLIER
	spawns.append({
		"pos": ground,
		"radius": maxf(4.0, area_radius),
		"pool": pool,
		"kind": _dominant_kind(pool),
		"alive": [],
		"timer": rng.randf_range(FIRST_SPAWN_MIN, first_spawn_max)
	})


# ---------- Zonas seguras ----------

func safe_zone_at(p: Vector3) -> String:
	for st in settlement_points:
		var sp: Vector3 = st["pos"]
		if Vector2(sp.x - p.x, sp.z - p.z).length() < safe_radius:
			return str(st["name"])
	return ""


func settlement_zone_for_player(position: Vector3) -> String:
	# Interiores procedurais ficam fora do espaço do mapa, mas pertencem à cidade
	# do edifício onde o jogador entrou. Usa a posição externa guardada como referência.
	var reference_position: Vector3 = _interior_return_position if _inside_building else position
	return safe_zone_at(reference_position)


func in_safe_zone(p: Vector3) -> bool:
	return safe_zone_at(p) != ""


func _find_sea_level() -> void:
	var meshes: Array = []
	_collect_meshes(_map, meshes)
	for mi in meshes:
		if str(mi.name).to_lower().contains("ocean"):
			var box: AABB = mi.global_transform * mi.get_aabb()
			sea_level = box.get_center().y
			return


func _random_land_point() -> Variant:
	# Ponto no terreno, fora das zonas seguras, acima da água e longe de outros spawns
	var b := map_bounds if map_bounds.size.x > 0.0 else world_bounds
	for _t in 60:
		var p := Vector3(rng.randf_range(b.position.x, b.end.x), 0.0, rng.randf_range(b.position.z, b.end.z))
		if safe_zone_at(p) != "":
			continue
		var hit := _ground_hit(p)
		if hit.is_empty():
			continue
		var g: Vector3 = hit["position"]
		if g.y < sea_level + SEA_MARGIN:
			continue
		var close := false
		for s in spawns:
			if Vector2(s["pos"].x - g.x, s["pos"].z - g.z).length() < FIELD_MIN_SPACING:
				close = true
				break
		if close:
			continue
		return g
	return null


func _settlement_title(raw: String) -> String:
	# O marcador mantém o nome técnico; o jogador e os NPCs recebem o topônimo oficial.
	return WORLD_NAMES.settlement_name(raw)


func _city_id_from_marker(marker_name: String) -> String:
	var lower := marker_name.to_lower()
	var regex := RegEx.new()
	regex.compile("settlement_(\\d+)")
	var found := regex.search(lower)
	if found == null:
		return ""
	return "settlement_%s" % found.get_string(1)


func _add_npc(marker_name: String, pos: Vector3) -> void:
	var role := "aldeao"
	var display := ""
	var rest := marker_name.trim_prefix("npc_")
	for key in ROLE_NAMES.keys():
		if rest.begins_with(key):
			role = key
			display = ROLE_NAMES[key]
	if display == "":
		display = rest.replace("_", " ").capitalize()
	# Mensageiros são gerados um por posto; a bruxa única nunca vem de um marcador comum.
	if role in ["mensageiro", "bruxa"]:
		return
	var city_id: String = _npc_society.find_nearest_city(pos) if _npc_society != null else ""
	var ordinal: int = _npc_society.get_residents_of_city(city_id).size() if _npc_society != null else 0
	var npc_id := "npc:marker:%s" % marker_name.to_lower().replace(" ", "_")
	_spawn_npc(role, display, pos, city_id, npc_id, ordinal)


func _spawn_npc(role: String, display: String, pos: Vector3, city_id: String = "", npc_id: String = "", ordinal: int = -1) -> void:
	var ground := _ground(pos)
	if city_id == "" and _npc_society != null:
		city_id = _npc_society.find_nearest_city(ground)
	if npc_id == "":
		npc_id = "npc:ambient:%s:%03d" % [city_id, npcs.size() + 1]

	# Ruínas e cidades ocupadas não geram população civil. Consultamos o save antes
	# de criar o perfil para impedir que a população seja registrada outra vez.
	# A bruxa é única e não é residente; viajantes ativos continuam em trânsito.
	var previous_profile: Dictionary = {}
	if _npc_society != null and _npc_society.has_method("get_saved_npc_record"):
		var previous_profile_value: Variant = _npc_society.call("get_saved_npc_record", npc_id)
		if previous_profile_value is Dictionary:
			previous_profile = previous_profile_value
	var effective_city_id := city_id
	var previous_life_value: Variant = previous_profile.get("life_state", {})
	var previous_life: Dictionary = previous_life_value if previous_life_value is Dictionary else {}
	if role == "mercador" and str(previous_profile.get("merchant_type", "")) == "itinerant":
		var saved_merchant_city := str(previous_profile.get("city_id", ""))
		if saved_merchant_city != "":
			effective_city_id = saved_merchant_city
	elif role == "mensageiro" and bool(previous_life.get("messenger_trip_active", false)):
		var saved_messenger_city := str(previous_profile.get("city_id", ""))
		if saved_messenger_city != "":
			effective_city_id = saved_messenger_city
	var is_active_traveler := (
		(role == "mercador" and str(previous_profile.get("merchant_type", "")) == "itinerant" and bool(previous_life.get("merchant_trip_active", false)))
		or (role == "mensageiro" and bool(previous_life.get("messenger_trip_active", false)))
	)
	if role != "bruxa" and not is_active_traveler and _city_blocks_resident_spawn(effective_city_id):
		return

	var profile: Dictionary = {}
	if _npc_society != null:
		profile = _npc_society.create_profile(npc_id, role, city_id, ordinal, display)
	var npc = _npc_scene.instantiate()
	add_child(npc)
	npc.global_position = ground
	# A identidade define a aparência. Não sorteamos mais um sprite à parte,
	# pois isso podia mostrar um nome feminino num personagem masculino (ou vice-versa).
	var tex_key := str(profile.get("sprite_key", "npcmale" if str(profile.get("gender", "male")) == "male" else "npcfemale"))
	if not game.sprites.has(tex_key):
		tex_key = "npcfemale" if str(profile.get("gender", "male")) == "female" else "npcmale"
	if not game.sprites.has(tex_key):
		tex_key = "npc"
	var tex: Texture2D = game.sprites[tex_key]
	var npc_display := str(profile.get("display_name", display))
	# Os sprites desenhados já têm paleta própria: não os tingimos pela profissão.
	# A cor antiga continua disponível apenas para o sprite genérico de fallback.
	var npc_tint: Color = ROLE_TINTS.get(role, Color.WHITE)
	if tex_key != "npc":
		npc_tint = Color.WHITE
	npc.setup(npc_display, role, tex, npc_tint)
	if not profile.is_empty():
		npc.configure_life(profile)
		# Restaura a última posição física registrada para este NPC. A rotina diária
		# pode recalcular o destino depois, mas não deve teletransportá-lo para casa
		# no instante em que o mundo é carregado.
		var life_state_value: Variant = profile.get("life_state", {})
		if life_state_value is Dictionary:
			var saved_position_value: Variant = life_state_value.get("position", [])
			if saved_position_value is Array and saved_position_value.size() >= 3:
				var saved_position: Vector3 = Vector3(
					float(saved_position_value[0]),
					float(saved_position_value[1]),
					float(saved_position_value[2])
				)
				# Evita aplicar posições inválidas de saves antigos/corrompidos.
				if is_finite(saved_position.x) and is_finite(saved_position.y) and is_finite(saved_position.z):
					npc.global_position = saved_position
	npc.game = game
	if role == "bruxa":
		npc.society = _npc_society
	npcs.append(npc)


func _has_spawned_npc(npc_id: String) -> bool:
	for npc in npcs:
		if is_instance_valid(npc) and str(npc.get("npc_id")) == npc_id:
			return true
	return false


func _on_npc_born(profile: Dictionary, spawn_position: Vector3) -> void:
	if profile.is_empty():
		return
	var child_id := str(profile.get("id", ""))
	if child_id == "" or _has_spawned_npc(child_id):
		return
	var city_id := str(profile.get("city_id", ""))
	var role := str(profile.get("role", "aldeao"))
	var display_name := str(profile.get("person_name", "Aldeão"))
	var ordinal: int = _npc_society.get_residents_of_city(city_id).size() if _npc_society != null else npcs.size()
	_spawn_npc(role, display_name, spawn_position, city_id, child_id, ordinal)


func _city_blocks_resident_spawn(city_id: String) -> bool:
	if city_id.is_empty() or game == null or not is_instance_valid(game):
		return false
	# RegionalThreats é inicializado depois da população; durante a carga, o estado
	# autoritativo já está em game.regional_threat_session_state.
	var states_value: Variant = game.get("regional_threat_session_state")
	if not (states_value is Dictionary):
		return false
	var state_value: Variant = states_value.get(city_id, {})
	if not (state_value is Dictionary):
		return false
	var state_record: Dictionary = state_value
	var siege_state := str(state_record.get("siege_state", "safe"))
	return siege_state in ["occupied", "ruins"] or bool(state_record.get("city_destroyed", false))


func _add_settlement(pos: Vector3, index: int, city_id: String) -> void:
	var center := _ground(pos)
	var population: int = 6
	if _npc_society != null:
		population = int(_npc_society.get_population_target(city_id))
	for k in range(population):
		var role := _settlement_resident_role(city_id, k)
		var person_number := k + 1
		var npc_id := "npc:%s:resident_%02d" % [city_id, person_number]
		_spawn_npc(role, str(ROLE_NAMES.get(role, "Aldeão")), center, city_id, npc_id, k)
	# Filhos nascidos em campanhas anteriores não fazem parte do elenco inicial
	# fixo: são restaurados pelo registro genealógico da própria cidade.
	if _npc_society != null and _npc_society.has_method("get_family_members_to_spawn"):
		var family_members: Array = _npc_society.call("get_family_members_to_spawn", city_id)
		for family_member_value in family_members:
			if not (family_member_value is Dictionary):
				continue
			var family_member: Dictionary = family_member_value
			var family_npc_id := str(family_member.get("id", ""))
			if family_npc_id == "" or _has_spawned_npc(family_npc_id):
				continue
			var family_role := str(family_member.get("role", "aldeao"))
			var family_name := str(family_member.get("person_name", "Aldeão"))
			var family_position: Vector3 = family_member.get("home_position", center)
			_spawn_npc(family_role, family_name, family_position, city_id, family_npc_id, _npc_society.get_residents_of_city(city_id).size())


func _setup_natural_resources(poi_markers: Array) -> void:
	_resource_nodes.clear()
	resource_sites.clear()
	var already_created: Dictionary = {}
	for settlement_value in settlement_points:
		var settlement: Dictionary = settlement_value
		var city_id: String = str(settlement.get("id", ""))
		var city_name: String = str(settlement.get("name", "a região"))
		var city_pos: Vector3 = settlement.get("pos", start_pos)
		var ore_pos: Variant = _find_resource_site_near_city(city_pos, "ore", 0)
		if ore_pos != null:
			_add_resource_site("resource_ore_%s" % city_id, "Veio Ferruginoso de %s" % city_name, "ore", city_id, ore_pos, already_created)
		var herb_pos: Variant = _find_resource_site_near_city(city_pos, "herbs", 1)
		if herb_pos != null:
			_add_resource_site("resource_herbs_%s" % city_id, "Prado das Ervas de %s" % city_name, "herbs", city_id, herb_pos, already_created)

	# POIs já colocados no Blender também ganham recursos coerentes com o lugar.
	for marker_value in poi_markers:
		var marker: Dictionary = marker_value
		var marker_name: String = str(marker.get("name", "")).to_lower()
		if marker_name.contains("dungeon"):
			continue
		var site_type: String = ""
		var site_name: String = ""
		if marker_name.contains("mine") or marker_name.contains("quarry") or marker_name.contains("ore") or marker_name.contains("cave"):
			site_type = "ore"
			if marker_name.contains("quarry"):
				site_name = "Pedreira Antiga"
			elif marker_name.contains("mine"):
				site_name = "Mina Esquecida"
			else:
				site_name = "Veio Mineral da Caverna"
		elif marker_name.contains("grove") or marker_name.contains("forest") or marker_name.contains("herb") or marker_name.contains("meadow") or marker_name.contains("shrine"):
			site_type = "herbs"
			site_name = "Clareira das Ervas"
		elif marker_name.contains("ruins") or marker_name.contains("ruin") or marker_name.contains("camp") or marker_name.contains("watchtower"):
			site_type = "mixed"
			site_name = "Ermos da Estrada Velha"
		if site_type == "":
			continue
		var marker_pos: Vector3 = _ground(marker.get("pos", start_pos))
		if safe_zone_at(marker_pos) != "":
			var nearest_city: Dictionary = _nearest_settlement_record(marker_pos)
			var shifted: Variant = _find_resource_site_near_city(nearest_city.get("pos", start_pos), site_type, 2)
			if shifted == null:
				continue
			marker_pos = shifted
		var normalized_id: String = marker_name.replace(" ", "_").replace("/", "_")
		var site_city_id: String = _npc_society.find_nearest_city(marker_pos) if _npc_society != null else ""
		_add_resource_site("resource_poi_%s" % normalized_id, site_name, site_type, site_city_id, marker_pos, already_created)

	# Mapas de teste ou mapas sem marcadores de cidade ainda terão pelo menos
	# alguns pontos de coleta, sem colocá-los dentro das zonas seguras.
	if resource_sites.is_empty():
		for fallback_index in range(4):
			var fallback_type: String = "ore" if fallback_index % 2 == 0 else "herbs"
			var fallback_pos: Variant = _random_land_point()
			if fallback_pos != null:
				var fallback_name: String = "Afloramento Rochoso" if fallback_type == "ore" else "Bosque de Plantas Medicinais"
				_add_resource_site("resource_fallback_%02d" % fallback_index, fallback_name, fallback_type, "", fallback_pos, already_created)


func _find_resource_site_near_city(city_pos: Vector3, site_type: String, variation: int) -> Variant:
	# Busca fora da zona segura, mas perto o bastante para ser uma tarefa regional.
	for attempt in range(20):
		var angle: float = rng.randf_range(0.0, TAU) + float(variation) * 0.71
		var radius: float = rng.randf_range(135.0, 285.0)
		var probe := Vector3(city_pos.x + cos(angle) * radius, city_pos.y, city_pos.z + sin(angle) * radius)
		if probe.x < map_bounds.position.x + 8.0 or probe.x > map_bounds.end.x - 8.0 or probe.z < map_bounds.position.z + 8.0 or probe.z > map_bounds.end.z - 8.0:
			continue
		if safe_zone_at(probe) != "":
			continue
		var hit: Dictionary = _ground_hit(probe)
		if hit.is_empty():
			continue
		var ground_pos: Vector3 = hit.get("position", probe)
		if ground_pos.y <= sea_level + SEA_MARGIN or safe_zone_at(ground_pos) != "":
			continue
		var separated: bool = true
		for site_value in resource_sites:
			var site: Dictionary = site_value
			var existing_position: Vector3 = site.get("position", Vector3.ZERO)
			var separation: float = Vector2(ground_pos.x - existing_position.x, ground_pos.z - existing_position.z).length()
			if separation < 45.0:
				separated = false
				break
		if separated:
			return ground_pos
	return null


func _nearest_settlement_record(position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for settlement_value in settlement_points:
		var settlement: Dictionary = settlement_value
		var candidate: Vector3 = settlement.get("pos", Vector3.ZERO)
		var distance: float = Vector2(position.x - candidate.x, position.z - candidate.z).length()
		if distance < best_distance:
			best_distance = distance
			best = settlement
	return best


func _add_resource_site(site_id: String, site_name: String, site_type: String, city_id: String, site_position: Vector3, already_created: Dictionary) -> void:
	if site_id == "" or already_created.has(site_id):
		return
	var ground_site: Vector3 = _ground(site_position)
	if safe_zone_at(ground_site) != "" or ground_site.y <= sea_level + SEA_MARGIN:
		return
	var contents: Array[String] = []
	match site_type:
		"ore":
			contents = ["iron_ore", "iron_ore", "copper_ore", "copper_ore", "silver_ore", "silver_ore"]
		"herbs":
			contents = ["healing_herb", "healing_herb", "bitterleaf", "bitterleaf", "silverleaf", "silverleaf"]
		_:
			contents = ["iron_ore", "iron_ore", "copper_ore", "copper_ore", "healing_herb", "healing_herb", "bitterleaf", "bitterleaf"]
	var available_types: Array[String] = []
	var created_count: int = 0
	for resource_index in range(contents.size()):
		var resource_id: String = contents[resource_index]
		var chosen_position: Variant = null
		for attempt in range(3):
			var angle: float = rng.randf_range(0.0, TAU)
			var radius: float = rng.randf_range(2.2, 7.2)
			var probe := ground_site + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			var hit: Dictionary = _ground_hit(probe)
			if hit.is_empty():
				continue
			var found_ground: Vector3 = hit.get("position", probe)
			if found_ground.y <= sea_level + SEA_MARGIN or safe_zone_at(found_ground) != "":
				continue
			chosen_position = found_ground
			break
		if chosen_position == null:
			# Mantém a vegetação/minério junto ao terreno quando uma pequena rocha
			# próxima não oferece um segundo ponto de colisão para a consulta.
			chosen_position = ground_site + Vector3(0.0, 0.025, 0.0)
		var node := StaticBody3D.new()
		node.set_script(WORLD_RESOURCE_SCRIPT)
		add_child(node)
		node.global_position = chosen_position
		node.call("configure", {
			"resource_id": resource_id,
			"site_id": site_id,
			"site_name": site_name,
			"yield": rng.randi_range(2, 3),
			"ordinal": resource_index + 1,
			"respawn_seconds": rng.randf_range(65.0, 100.0)
		})
		_resource_nodes.append(node)
		created_count += 1
		if not available_types.has(resource_id):
			available_types.append(resource_id)
	if created_count <= 0:
		return
	already_created[site_id] = true
	resource_sites.append({
		"id": site_id,
		"name": site_name,
		"type": site_type,
		"city_id": city_id,
		"position": ground_site,
		"resource_ids": available_types,
		"node_count": created_count
	})


func get_resource_sites_for_resource(resource_id: String, city_id: String = "") -> Array[Dictionary]:
	var local_sites: Array[Dictionary] = []
	var all_sites: Array[Dictionary] = []
	for site_value in resource_sites:
		var site: Dictionary = site_value
		var types: Array = site.get("resource_ids", [])
		if not types.has(resource_id):
			continue
		all_sites.append(site.duplicate(true))
		if city_id == "" or str(site.get("city_id", "")) == city_id:
			local_sites.append(site.duplicate(true))
	if not local_sites.is_empty():
		return local_sites
	return all_sites


func get_resource_site(site_id: String) -> Dictionary:
	for site_value in resource_sites:
		var site: Dictionary = site_value
		if str(site.get("id", "")) == site_id:
			return site.duplicate(true)
	return {}


func harvest_resource(resource_node: Node) -> Dictionary:
	if not is_instance_valid(resource_node) or not resource_node.has_method("gather"):
		return {}
	return resource_node.call("gather")


func _settlement_resident_role(city_id: String, resident_index: int) -> String:
	# Os primeiros habitantes cobrem segurança e serviços essenciais. Todo núcleo
	# habitado tem uma pequena guarnição; cidades maiores recebem reforços conforme
	# crescem, sem depender de marcadores NPC colocados manualmente no Blender.
	var counts: Dictionary = {}
	if _npc_society != null:
		counts = _npc_society.get_city_building_counts(city_id)
	if resident_index == 0:
		return "guarda"
	if resident_index == 1:
		return "ferreiro" if int(counts.get("workshop", 0)) > 0 else "aldeao"
	if resident_index == 2:
		return "mercador" if int(counts.get("shop", 0)) > 0 else "aldeao"
	if resident_index == 3:
		return "curandeira" if int(counts.get("infirmary", 0)) > 0 or int(counts.get("shop", 0)) > 0 or int(counts.get("inn", 0)) > 0 else "aldeao"
	# Segundo guarda no grupo inicial; novos reforços entram gradualmente em cidades
	# maiores. IDs de residentes continuam determinísticos, então suas identidades
	# continuam estáveis entre carregamentos.
	if resident_index == 5 or (resident_index >= 11 and posmod(resident_index - 11, 6) == 0):
		return "guarda"
	var extra_roles: Array[String] = ["aldeao", "aldeao", "aldeao", "mercador", "aldeao", "aldeao", "ferreiro", "aldeao", "curandeira", "aldeao", "aldeao"]
	return extra_roles[(resident_index - 4) % extra_roles.size()]


func _default_start(settlements: Array, bounds: AABB) -> Vector3:
	var c := bounds.get_center()
	var best := Vector3(c.x, 0.0, c.z)
	var best_d := INF
	for m in settlements:
		var sp: Vector3 = m["pos"]
		var d := Vector2(sp.x - c.x, sp.z - c.z).length()
		if d < best_d:
			best_d = d
			best = sp
	return best


func _build_entrance(at: Vector3) -> Node3D:
	var entrance := Node3D.new()
	entrance.name = "EntradaCripta"
	entrance.visible = false
	add_child(entrance)
	entrance.global_position = at
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.36, 0.34, 0.32)
	stone.roughness = 1.0
	var hole := StandardMaterial3D.new()
	hole.albedo_color = Color(0.02, 0.02, 0.02)
	_box(entrance, Vector3(-1.2, 1.5, 0), Vector3(0.6, 3.0, 0.9), stone)
	_box(entrance, Vector3(1.2, 1.5, 0), Vector3(0.6, 3.0, 0.9), stone)
	_box(entrance, Vector3(0, 3.1, 0), Vector3(3.0, 0.6, 0.9), stone)
	_box(entrance, Vector3(0, 1.2, 0.05), Vector3(1.8, 2.4, 0.5), hole)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.0, 1.0)
	lamp.light_color = Color(1.0, 0.5, 0.2)
	lamp.light_energy = 2.0
	lamp.omni_range = 7.0
	entrance.add_child(lamp)
	var label := Label3D.new()
	label.text = "Entrada da Cripta"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = 40
	label.outline_size = 10
	label.position = Vector3(0, 3.9, 0)
	label.visible = false
	entrance.add_child(label)
	return entrance


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# ---------- Chão e colisão ----------

func _ground_hit(p: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var excl: Array = []
	var best: Dictionary = {}
	for _i in 12:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 500.0, p + Vector3.DOWN * 500.0)
		q.exclude = excl
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		excl.append(hit["rid"])
		if hit["collider"] is CharacterBody3D:
			continue
		if best.is_empty() or hit["position"].y < best["position"].y:
			best = hit
	return best


func _ground(p: Vector3) -> Vector3:
	var hit := _ground_hit(p)
	if hit.is_empty():
		return p
	return hit["position"]


func _random_ground_point(bounds: AABB, min_d: float, max_d: float) -> Variant:
	for _t in 40:
		var p := Vector3(rng.randf_range(bounds.position.x, bounds.end.x), 0.0, rng.randf_range(bounds.position.z, bounds.end.z))
		var d := Vector2(p.x - start_pos.x, p.z - start_pos.z).length()
		if d < min_d or d > max_d:
			continue
		var hit := _ground_hit(p)
		if not hit.is_empty():
			return hit["position"]
	return null


func _has_body(mi: Node) -> bool:
	for c in mi.get_children():
		if c is StaticBody3D:
			return true
	return false


func _skip_collision(node_name: StringName) -> bool:
	var lower := str(node_name).to_lower()
	for w in NO_COLLISION_WORDS:
		if lower.contains(w):
			return true
	return false


func _stabilize_city_building_rendering(mi: MeshInstance3D) -> void:
	# Cada edifício do GLB é uma malha completa (não há nós separados para cada
	# parede). Margem extra evita culling incorreto da malha em vistas rasantes.
	if not is_instance_valid(mi) or mi.mesh == null:
		return
	mi.extra_cull_margin = maxf(mi.extra_cull_margin, 4.0)
	# O fade por dithering pode deixar superfícies estreitas visualmente furadas
	# perto do limite de distância. Mantemos o limite de renderização, sem fade.
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for surface_idx in range(mi.mesh.get_surface_count()):
		var source_material: Material = mi.get_surface_override_material(surface_idx)
		if source_material == null:
			source_material = mi.mesh.surface_get_material(surface_idx)
		if not (source_material is BaseMaterial3D):
			continue
		var base_material := source_material as BaseMaterial3D
		var cache_key: int = base_material.get_instance_id()
		var two_sided_material: BaseMaterial3D = null
		if _city_two_sided_material_cache.has(cache_key):
			two_sided_material = _city_two_sided_material_cache[cache_key] as BaseMaterial3D
		if two_sided_material == null:
			two_sided_material = base_material.duplicate() as BaseMaterial3D
			if two_sided_material == null:
				continue
			two_sided_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_city_two_sided_material_cache[cache_key] = two_sided_material
		mi.set_surface_override_material(surface_idx, two_sided_material)


func _add_collision(node: Node) -> void:
	# O terreno tem uma malha de colisão própria no GLB. Se estiver presente,
	# usamos essa malha e não duplicamos a colisão do terreno visual.
	var meshes: Array = []
	_collect_meshes(node, meshes)
	var has_collision_terrain := false
	for mesh_node in meshes:
		if mesh_node is MeshInstance3D and str(mesh_node.name).to_lower().contains("terrain-colonly"):
			has_collision_terrain = true
			break
	for value in meshes:
		if not (value is MeshInstance3D):
			continue
		var mi := value as MeshInstance3D
		var lower := str(mi.name).to_lower()
		if lower.contains("terrain-colonly"):
			mi.visible = false
			_ensure_stream_collision(mi)
			continue
		if _skip_collision(mi.name):
			continue
		if lower.contains("treetrunks"):
			_ensure_stream_collision(mi)
			continue
		if lower.contains("terrain"):
			# Fallback para modelos sem OW_Terrain-colonly.
			if not has_collision_terrain:
				_ensure_stream_collision(mi)
			continue
		if lower.contains("building"):
			mi.visibility_range_end = BUILDING_RENDER_DISTANCE
			mi.visibility_range_end_margin = 22.0
		elif lower.contains("landmark") or lower.contains("poi"):
			mi.visibility_range_end = LANDMARK_RENDER_DISTANCE
			mi.visibility_range_end_margin = 28.0
		elif not (lower.contains("treetrunks") or lower.contains("treecanopies")):
			mi.visibility_range_end = DETAIL_RENDER_DISTANCE
			mi.visibility_range_end_margin = 16.0
		# Fade por dithering evita que detalhes simplesmente apareçam/desapareçam.
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if lower.contains("building"):
			# As superfícies de parede dos prédios devem continuar visíveis quando
			# a câmera olha de lado; o limite de distância continua ativo.
			_stabilize_city_building_rendering(mi)
		# Árvores e grandes meshes de ambiente são combinados num único objeto;
		# aplicar distância por origem esconderia a floresta inteira de uma vez.
		if not _has_body(mi):
			_stream_meshes.append(mi)


func _ensure_stream_collision(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or _has_body(mi) or _skip_collision(mi.name):
		return
	if bool(mi.get_meta("city_ruins_hidden", false)):
		return
	mi.create_trimesh_collision()
	for body in mi.get_children():
		if body is StaticBody3D:
			body.name = "StreamedCollisionBody"
			_streamed_body_ids[mi.get_instance_id()] = body.get_instance_id()
			for child in body.get_children():
				if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
					child.shape.backface_collision = true


func _remove_stream_collision(mi: MeshInstance3D) -> void:
	var body_id: int = int(_streamed_body_ids.get(mi.get_instance_id(), 0))
	if body_id == 0:
		return
	for child in mi.get_children():
		if child is StaticBody3D and child.get_instance_id() == body_id:
			mi.remove_child(child)
			child.queue_free()
	_streamed_body_ids.erase(mi.get_instance_id())


func _mesh_distance_to_point(mi: MeshInstance3D, point: Vector3) -> float:
	var box: AABB = mi.global_transform * mi.get_aabb()
	var nearest := Vector3(
		clampf(point.x, box.position.x, box.end.x),
		clampf(point.y, box.position.y, box.end.y),
		clampf(point.z, box.position.z, box.end.z)
	)
	return point.distance_to(nearest)


func _mesh_render_distance(mi: MeshInstance3D) -> float:
	var lower := str(mi.name).to_lower()
	if lower.contains("building"):
		return BUILDING_RENDER_DISTANCE
	if lower.contains("landmark") or lower.contains("poi"):
		return LANDMARK_RENDER_DISTANCE
	return DETAIL_RENDER_DISTANCE


func _mesh_collision_load_distance(mi: MeshInstance3D) -> float:
	# Colisão física não precisa cobrir toda a distância visual. Criar colisões
	# para edifícios a 500 m fazia o mundo preparar centenas de malhas trimesh
	# sem utilidade imediata, gerando picos de CPU ao se aproximar de assentamentos.
	# Os NPCs só se movem ativamente num raio de ~135 m, então mantemos uma margem.
	var lower := str(mi.name).to_lower()
	if lower.contains("building"):
		return 165.0
	if lower.contains("landmark") or lower.contains("poi"):
		return 180.0
	return 140.0


func _mesh_collision_release_distance(mi: MeshInstance3D) -> float:
	# Histerese evita criar/remover colisão repetidamente perto da borda do raio.
	return _mesh_collision_load_distance(mi) + 42.0


func _prime_stream_collisions(point: Vector3, budget: int) -> void:
	var candidates: Array[Dictionary] = []
	for mi in _stream_meshes:
		if not is_instance_valid(mi) or _has_body(mi) or bool(mi.get_meta("city_ruins_hidden", false)):
			continue
		var d := _mesh_distance_to_point(mi, point)
		if d <= _mesh_collision_load_distance(mi):
			candidates.append({"mesh": mi, "distance": d})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	for i in range(mini(budget, candidates.size())):
		var mi: MeshInstance3D = candidates[i]["mesh"]
		_ensure_stream_collision(mi)


func _update_world_streaming(delta: float, player_position: Vector3) -> void:
	_stream_timer += delta
	if _stream_timer < STREAM_REFRESH_SECONDS:
		return
	_stream_timer = 0.0
	_update_enemy_streaming(player_position)
	var candidates: Array[Dictionary] = []
	for i in range(_stream_meshes.size() - 1, -1, -1):
		var mi: MeshInstance3D = _stream_meshes[i]
		if not is_instance_valid(mi):
			_stream_meshes.remove_at(i)
			continue
		if bool(mi.get_meta("city_ruins_hidden", false)):
			if _streamed_body_ids.has(mi.get_instance_id()):
				_remove_stream_collision(mi)
			continue
		var distance := _mesh_distance_to_point(mi, player_position)
		var has_stream_body := _streamed_body_ids.has(mi.get_instance_id())
		if has_stream_body and distance > _mesh_collision_release_distance(mi):
			_remove_stream_collision(mi)
		elif not has_stream_body and distance <= _mesh_collision_load_distance(mi):
			candidates.append({"mesh": mi, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	# O orçamento evita um pico de CPU quando uma cidade inteira entra no raio.
	for i in range(mini(STREAM_COLLISION_BUDGET, candidates.size())):
		var mi: MeshInstance3D = candidates[i]["mesh"]
		_ensure_stream_collision(mi)


func advance_regional_threats_for_sleep(hours_to_advance: float, start_hour: float) -> void:
	# O descanso avança o relógio do mundo em poucas linhas; a ameaça regional
	# precisa percorrer o mesmo intervalo para uma cidade não ficar imune à noite.
	if _regional_threats == null or not is_instance_valid(_regional_threats):
		return
	if not _regional_threats.has_method("tick"):
		return
	var safe_day_length := maxf(60.0, day_length_seconds)
	var seconds_to_advance := maxf(0.0, hours_to_advance) * safe_day_length / 24.0
	if seconds_to_advance <= 0.0:
		return
	var elapsed := 0.0
	while elapsed < seconds_to_advance:
		var step_seconds := minf(8.0, seconds_to_advance - elapsed)
		elapsed += step_seconds
		var simulated_hour := fposmod(start_hour + elapsed * 24.0 / safe_day_length, 24.0)
		_regional_threats.call("tick", step_seconds, simulated_hour)


func _sync_city_occupation_presence(player_position: Vector3) -> void:
	if _regional_threats == null or not is_instance_valid(_regional_threats) or not _regional_threats.has_method("get_city_records"):
		return
	var records_value: Variant = _regional_threats.call("get_city_records")
	if not (records_value is Array):
		return
	var known_city_ids: Dictionary = {}
	for record_value in records_value:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var city_id := str(record.get("id", ""))
		if city_id.is_empty():
			continue
		known_city_ids[city_id] = true
		var state := str(record.get("siege_state", "safe"))
		var is_destroyed_city: bool = state in ["occupied", "ruins"] or bool(record.get("city_destroyed", false))
		_set_city_residents_hidden(city_id, is_destroyed_city)
		_set_city_building_ruins(city_id, is_destroyed_city)

		if state == "occupied":
			_convert_assault_actors_to_occupiers(city_id)
			var occupied_center: Vector3 = record.get("center", Vector3.ZERO)
			var occupied_distance := Vector2(player_position.x - occupied_center.x, player_position.z - occupied_center.z).length()
			if occupied_distance <= CITY_OCCUPATION_WAKE_RADIUS:
				_ensure_city_hostiles(record, true, player_position)
		elif state == "under_attack":
			var assault_center: Vector3 = record.get("center", Vector3.ZERO)
			var assault_distance := Vector2(player_position.x - assault_center.x, player_position.z - assault_center.z).length()
			if assault_distance <= CITY_ASSAULT_WAKE_RADIUS:
				_ensure_city_hostiles(record, false, player_position)
		else:
			_remove_city_hostiles(city_id, true)

	# Cidades removidas do mapa ou de saves incompatíveis não devem deixar cidadãos
	# presos no estado invisível para sempre.
	for npc_value in npcs:
		if not is_instance_valid(npc_value):
			continue
		if bool(npc_value.get_meta("city_occupation_hidden", false)) and not known_city_ids.has(str(npc_value.get("city_id"))):
			_set_npc_occupation_hidden(npc_value, false)


func _set_city_building_ruins(city_id: String, ruined: bool) -> void:
	if _npc_society == null or not is_instance_valid(_npc_society) or not _npc_society.has_method("get_city_buildings"):
		return
	var building_values: Variant = _npc_society.call("get_city_buildings", city_id)
	if not (building_values is Array):
		return
	var easily_destroyed_kinds: Array[String] = ["house", "shop", "workshop", "barn", "depot", "shelter", "mill", "stable"]
	for building_value in building_values:
		if not (building_value is Dictionary):
			continue
		var building: Dictionary = building_value
		var mesh: MeshInstance3D = building.get("node") as MeshInstance3D
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue
		if ruined:
			if bool(mesh.get_meta("city_ruins_applied", false)):
				continue
			mesh.set_meta("city_ruins_applied", true)
			mesh.set_meta("city_ruins_previous_visible", mesh.visible)
			var original_overrides: Array = []
			for surface_index in range(mesh.mesh.get_surface_count()):
				original_overrides.append(mesh.get_surface_override_material(surface_index))
				var active_material: StandardMaterial3D = mesh.get_active_material(surface_index) as StandardMaterial3D
				if active_material == null:
					continue
				var damaged_material := active_material.duplicate() as StandardMaterial3D
				if damaged_material == null:
					continue
				damaged_material.albedo_color = Color(
					active_material.albedo_color.r * 0.62,
					active_material.albedo_color.g * 0.54,
					active_material.albedo_color.b * 0.46,
					active_material.albedo_color.a
				)
				damaged_material.roughness = maxf(damaged_material.roughness, 0.92)
				if damaged_material.emission_enabled:
					damaged_material.emission = Color(
						damaged_material.emission.r * 0.3,
						damaged_material.emission.g * 0.24,
						damaged_material.emission.b * 0.18,
						damaged_material.emission.a
					)
					damaged_material.emission_energy_multiplier *= 0.3
				mesh.set_surface_override_material(surface_index, damaged_material)
			mesh.set_meta("city_ruins_previous_overrides", original_overrides)
			var kind := str(building.get("kind", ""))
			var building_id := str(building.get("id", mesh.name))
			# Parte das construções comuns desaparece, deixando lacunas na malha urbana.
			# Mantemos marcos e serviços centrais para a cidade continuar reconhecível.
			if kind in easily_destroyed_kinds and posmod(building_id.hash(), 3) == 0:
				mesh.set_meta("city_ruins_hidden", true)
				mesh.visible = false
				_remove_stream_collision(mesh)
		else:
			if not bool(mesh.get_meta("city_ruins_applied", false)):
				continue
			mesh.visible = bool(mesh.get_meta("city_ruins_previous_visible", true))
			var saved_overrides: Variant = mesh.get_meta("city_ruins_previous_overrides", [])
			if saved_overrides is Array:
				for surface_index in range(mini(saved_overrides.size(), mesh.mesh.get_surface_count())):
					mesh.set_surface_override_material(surface_index, saved_overrides[surface_index] as Material)
			for meta_key in ["city_ruins_applied", "city_ruins_previous_visible", "city_ruins_previous_overrides", "city_ruins_hidden"]:
				mesh.remove_meta(meta_key)


func _set_city_residents_hidden(city_id: String, hide_residents: bool) -> void:
	for npc_value in npcs:
		if not is_instance_valid(npc_value) or str(npc_value.get("city_id")) != city_id:
			continue
		# A bruxa aliada e os viajantes não pertencem à população que ficou presa
		# na cidade. Eles não desaparecem quando uma cidade cai.
		if str(npc_value.get("role")) == "bruxa" or bool(npc_value.get("is_unique_witch")):
			continue
		if (str(npc_value.get("merchant_type")) == "itinerant" and bool(npc_value.get("merchant_trip_active"))) or bool(npc_value.get("messenger_trip_active")):
			continue
		_set_npc_occupation_hidden(npc_value, hide_residents)


func _set_npc_occupation_hidden(npc: Node, hide_resident: bool) -> void:
	if hide_resident:
		if not bool(npc.get_meta("city_occupation_hidden", false)):
			npc.set_meta("city_occupation_hidden", true)
			npc.set_meta("city_occ_prev_visible", bool(npc.visible))
			npc.set_meta("city_occ_prev_collision_layer", int(npc.get("collision_layer")))
			npc.set_meta("city_occ_prev_collision_mask", int(npc.get("collision_mask")))
			npc.set_meta("city_occ_prev_physics", npc.is_physics_processing())
			npc.set_meta("city_occ_prev_process", npc.is_processing())
		npc.visible = false
		npc.set("collision_layer", 0)
		npc.set("collision_mask", 0)
		npc.set_physics_process(false)
		npc.set_process(false)
		return
	if not bool(npc.get_meta("city_occupation_hidden", false)):
		return
	npc.visible = bool(npc.get_meta("city_occ_prev_visible", true))
	npc.set("collision_layer", int(npc.get_meta("city_occ_prev_collision_layer", 2)))
	npc.set("collision_mask", int(npc.get_meta("city_occ_prev_collision_mask", 1)))
	npc.set_physics_process(bool(npc.get_meta("city_occ_prev_physics", false)))
	npc.set_process(bool(npc.get_meta("city_occ_prev_process", false)))
	for meta_key in ["city_occupation_hidden", "city_occ_prev_visible", "city_occ_prev_collision_layer", "city_occ_prev_collision_mask", "city_occ_prev_physics", "city_occ_prev_process"]:
		npc.remove_meta(meta_key)


func _convert_assault_actors_to_occupiers(city_id: String) -> void:
	for enemy_value in get_tree().get_nodes_in_group("city_occupation_actors"):
		if not is_instance_valid(enemy_value) or str(enemy_value.get_meta("city_id", "")) != city_id:
			continue
		if bool(enemy_value.get_meta("city_assault_invader", false)):
			enemy_value.set_meta("city_assault_invader", false)
			enemy_value.set_meta("city_invader", true)


func _ensure_city_hostiles(city_record: Dictionary, permanent_occupation: bool, player_position: Vector3) -> void:
	var city_id := str(city_record.get("id", ""))
	if city_id.is_empty() or game == null or game.enemy_scene == null:
		return
	var meta_to_count := "city_invader" if permanent_occupation else "city_assault_invader"
	var desired_count := int(city_record.get("occupation_remaining", 0)) if permanent_occupation else int(city_record.get("assault_remaining", 0))
	var existing_count := 0
	for enemy_value in get_tree().get_nodes_in_group("city_occupation_actors"):
		if not is_instance_valid(enemy_value) or str(enemy_value.get_meta("city_id", "")) != city_id:
			continue
		if int(enemy_value.get("hp")) <= 0:
			continue
		if permanent_occupation and bool(enemy_value.get_meta("city_assault_invader", false)):
			enemy_value.set_meta("city_assault_invader", false)
			enemy_value.set_meta("city_invader", true)
		if bool(enemy_value.get_meta(meta_to_count, false)):
			existing_count += 1
	if existing_count >= desired_count:
		return
	var city_name := str(city_record.get("name", WORLD_NAMES.settlement_name(city_id)))
	for local_index in range(existing_count, desired_count):
		if not _spawn_city_hostile(city_id, city_name, city_record.get("center", Vector3.ZERO), permanent_occupation, local_index, player_position):
			# Não força um número fictício de sobreviventes quando o terreno não
			# oferece espaço; o cerco ainda será resolvido pela simulação persistente.
			break


func _spawn_city_hostile(city_id: String, city_name: String, center: Vector3, permanent_occupation: bool, index: int, player_position: Vector3) -> bool:
	var pattern: Array[String] = ["orc", "goblin", "orc", "skel", "goblin", "orc", "skel", "orc"]
	var kind := pattern[posmod(index, pattern.size())]
	var config: Dictionary = _enemy_cfg(kind)
	if config.is_empty():
		return false
	match kind:
		"orc": config["name"] = "Orc invasor"
		"goblin": config["name"] = "Saqueador goblin"
		"skel": config["name"] = "Esqueleto invasor"
	var spawn_position := _city_hostile_ground_position(city_id, center, index)
	if not is_finite(spawn_position.x) or not is_finite(spawn_position.y) or not is_finite(spawn_position.z):
		return false
	var enemy: Node = game.enemy_scene.instantiate()
	if enemy == null:
		return false
	enemy.add_to_group("overworld_enemies")
	enemy.add_to_group("city_occupation_actors")
	add_child(enemy)
	enemy.global_position = spawn_position + Vector3(0.0, 0.2, 0.0)
	enemy.call("setup", config, game)
	enemy.set_meta("city_occupation_actor", true)
	enemy.set_meta("city_id", city_id)
	enemy.set_meta("city_name", city_name)
	enemy.set_meta("city_invader_index", index)
	enemy.set_meta("city_invader", permanent_occupation)
	enemy.set_meta("city_assault_invader", not permanent_occupation)
	var distance_to_player := Vector2(spawn_position.x - player_position.x, spawn_position.z - player_position.z).length()
	enemy.call("set_stream_active", distance_to_player <= ENEMY_ACTIVE_RADIUS)
	return true


func _city_hostile_ground_position(city_id: String, center: Vector3, index: int) -> Vector3:
	for attempt in range(36):
		var angle := float(index + attempt) * 2.399963 + float(city_id.length()) * 0.29
		var radius := 20.0 + float(posmod(index + attempt, 6)) * 5.0
		var candidate := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var hit: Dictionary = _ground_hit(candidate)
		if hit.is_empty():
			continue
		var grounded: Vector3 = hit.get("position", candidate)
		if grounded.y <= sea_level + SEA_MARGIN:
			continue
		var overlaps := false
		for other_value in get_tree().get_nodes_in_group("city_occupation_actors"):
			if not is_instance_valid(other_value) or str(other_value.get_meta("city_id", "")) != city_id:
				continue
			var other := other_value as Node3D
			if other == null:
				continue
			if Vector2(other.global_position.x - grounded.x, other.global_position.z - grounded.z).length() < 2.2:
				overlaps = true
				break
		if not overlaps:
			return grounded
	return _ground(center + Vector3(25.0 + float(index % 5) * 4.0, 0.0, -18.0))


func _remove_city_hostiles(city_id: String, include_occupiers: bool) -> void:
	for enemy_value in get_tree().get_nodes_in_group("city_occupation_actors"):
		if not is_instance_valid(enemy_value) or str(enemy_value.get_meta("city_id", "")) != city_id:
			continue
		var should_remove := bool(enemy_value.get_meta("city_assault_invader", false))
		if include_occupiers and bool(enemy_value.get_meta("city_invader", false)):
			should_remove = true
		if should_remove:
			enemy_value.queue_free()


func report_city_invader_killed(city_id: String) -> void:
	if _regional_threats != null and is_instance_valid(_regional_threats) and _regional_threats.has_method("report_city_invader_killed"):
		_regional_threats.call("report_city_invader_killed", city_id)


func _update_enemy_streaming(player_position: Vector3) -> void:
	for value in get_tree().get_nodes_in_group("overworld_enemies"):
		if not is_instance_valid(value) or not value.is_inside_tree():
			continue
		var enemy := value as Node3D
		var distance := Vector2(enemy.global_position.x - player_position.x, enemy.global_position.z - player_position.z).length()
		var active := bool(enemy.get_meta("stream_active", true))
		if active and distance > ENEMY_DEACTIVATE_RADIUS:
			enemy.call("set_stream_active", false)
		elif not active and distance <= ENEMY_ACTIVE_RADIUS:
			enemy.call("set_stream_active", true)


func _update_entrance_discovery(player_position: Vector3) -> void:
	for entrance in entrances:
		if not is_instance_valid(entrance):
			continue
		var distance := Vector2(entrance.global_position.x - player_position.x, entrance.global_position.z - player_position.z).length()
		entrance.visible = distance <= ENTRANCE_VISIBILITY_DISTANCE
		var label := entrance.get_node_or_null("Label3D") as Label3D
		if label != null:
			label.visible = distance <= ENTRANCE_LABEL_DISTANCE
		if distance <= ENTRANCE_DISCOVERY_DISTANCE and not bool(entrance.get_meta("discovered", false)):
			entrance.set_meta("discovered", true)
			var entrance_id: String = str(entrance.get_meta("entrance_id", ""))
			if entrance_id != "" and not discovered_entrances.has(entrance_id):
				discovered_entrances.append(entrance_id)
				var globally_new: bool = true
				if game != null:
					var session_discoveries: Array[String] = game.get("discovered_dungeons_session")
					if session_discoveries.has(entrance_id):
						globally_new = false
					else:
						session_discoveries.append(entrance_id)
						game.set("discovered_dungeons_session", session_discoveries)
				if globally_new and _regional_threats != null:
					_regional_threats.report_dungeon_discovered(entrance.global_position)
			if game != null and game.has_method("show_msg"):
				game.show_msg("Local descoberto: Entrada da Cripta. Marcada no mapa.")


func get_npc_debug_snapshot() -> Dictionary:
	var player_position := Vector3.ZERO
	if game != null and is_instance_valid(game) and game.player != null and is_instance_valid(game.player):
		player_position = game.player.global_position
	if _npc_society != null and is_instance_valid(_npc_society) and _npc_society.has_method("get_debug_snapshot"):
		return _npc_society.get_debug_snapshot(player_position)
	return {"recent_log": ["Sistema de sociedade dos NPCs ainda não foi inicializado."], "npc_count": 0, "sessions": [], "nearby_npcs": []}


func get_regional_threat(city_id: String) -> float:
	if _regional_threats == null:
		return 0.0
	return _regional_threats.get_threat_for_city(city_id)


func get_regional_threat_status(city_id: String) -> String:
	if _regional_threats == null:
		return "Tranquila"
	return _regional_threats.get_status_for_city(city_id)


func get_regional_threat_at_position(position: Vector3) -> float:
	if _regional_threats == null:
		return 0.0
	return _regional_threats.get_threat_at(position)


func get_regional_threat_info_at_position(position: Vector3) -> Dictionary:
	if _regional_threats == null:
		return {}
	return _regional_threats.get_region_at_position(position)


func is_position_in_city_region(position: Vector3, city_id: String) -> bool:
	if _regional_threats == null:
		return false
	return _regional_threats.is_position_in_city_region(position, city_id)


func get_regional_enemy_weights(city_id: String) -> Dictionary:
	var weights: Dictionary = {}
	var city_position: Vector3 = quest_city_position(city_id)
	for spawn_value in spawns:
		var spawn_record: Dictionary = spawn_value
		var position: Vector3 = spawn_record.get("pos", city_position)
		if not is_position_in_city_region(position, city_id):
			continue
		var pool: Dictionary = spawn_record.get("pool", {})
		for kind_value in pool.keys():
			var kind: String = str(kind_value)
			weights[kind] = float(weights.get(kind, 0.0)) + float(pool[kind_value])
	return weights


func quest_target_position_in_region(city_id: String, target_kind: String, avoid_positions: Array = []) -> Vector3:
	var city_position: Vector3 = quest_city_position(city_id)
	var best_position: Vector3 = Vector3.ZERO
	var best_score: float = INF
	for spawn_value in spawns:
		var spawn_record: Dictionary = spawn_value
		var pool: Dictionary = spawn_record.get("pool", {})
		if not pool.has(target_kind):
			continue
		var position: Vector3 = _ground(spawn_record.get("pos", city_position))
		if safe_zone_at(position) != "" or not is_position_in_city_region(position, city_id):
			continue
		var city_distance: float = Vector2(position.x - city_position.x, position.z - city_position.z).length()
		# Mantém o grupo dentro da região mesmo depois de espalhar os alvos.
		if city_distance > 840.0:
			continue
		var score: float = _quest_site_score(position, city_position, avoid_positions)
		if score < best_score:
			best_score = score
			best_position = position
	if best_score < INF and _is_quest_site_separated(best_position, avoid_positions):
		return best_position
	var fallback: Dictionary = _find_separated_quest_site(city_position, city_id, avoid_positions, true)
	if bool(fallback.get("success", false)):
		return fallback.get("position", best_position)
	if best_score < INF:
		return best_position
	return quest_target_position(city_id, target_kind, avoid_positions)


func resolve_regional_quest(city_id: String, targets_defeated: int) -> void:
	if _regional_threats == null:
		return
	_regional_threats.resolve_regional_quest(city_id, targets_defeated)
	if game != null and is_instance_valid(game.player):
		_update_region_feedback(game.player.global_position)


func report_enemy_killed(position: Vector3, enemy_kind: String) -> void:
	if _regional_threats != null:
		_regional_threats.report_enemy_killed(position, enemy_kind)
	if _npc_society != null and _npc_society.has_method("report_world_event"):
		_npc_society.report_world_event(position, "monster_defeated", enemy_kind)


func report_quest_completed(quest: Dictionary) -> void:
	if _npc_society == null or not is_instance_valid(_npc_society) or not _npc_society.has_method("report_world_event"):
		return
	var giver_id := str(quest.get("giver_id", ""))
	var event_position: Vector3 = quest.get("city_position", Vector3.ZERO)
	for npc in npcs:
		if is_instance_valid(npc) and str(npc.get("npc_id")) == giver_id:
			event_position = npc.global_position
			break
	var title := str(quest.get("title", "trabalho concluído"))
	_npc_society.report_world_event(event_position, "quest_completed", title, giver_id)


func _update_region_feedback(player_position: Vector3) -> void:
	if _regional_threats == null or game == null or game.phase != "play":
		return
	var record: Dictionary = _regional_threats.get_region_at_position(player_position)
	var region_id: String = str(record.get("id", ""))
	var region_name: String = str(record.get("name", "Região desconhecida"))
	var status: String = str(record.get("status", "Tranquila"))
	if region_id != _last_player_region_id:
		_last_player_region_id = region_id
		_last_player_region_status = status
		game.show_msg("%s — situação: %s." % [region_name, status])
	elif status != _last_player_region_status:
		_last_player_region_status = status
		game.show_msg("A situação de %s mudou: %s." % [region_name, status])


func quest_city_position(city_id: String) -> Vector3:
	for city in settlement_points:
		if str(city.get("id", "")) == city_id:
			return city.get("pos", start_pos)
	return start_pos


func quest_target_position(city_id: String, target_kind: String, avoid_positions: Array = []) -> Vector3:
	var city_position: Vector3 = quest_city_position(city_id)
	var best_position: Vector3 = Vector3.ZERO
	var best_score: float = INF
	for spawn_value in spawns:
		var spawn_record: Dictionary = spawn_value
		var position: Vector3 = _ground(spawn_record.get("pos", city_position))
		if safe_zone_at(position) != "" or position.y <= sea_level + SEA_MARGIN:
			continue
		var pool: Dictionary = spawn_record.get("pool", {})
		var score: float = _quest_site_score(position, city_position, avoid_positions)
		if not pool.has(target_kind):
			score += 180.0
		if not is_position_in_city_region(position, city_id):
			score += 500.0
		if score < best_score:
			best_score = score
			best_position = position
	if best_score < INF and _is_quest_site_separated(best_position, avoid_positions):
		return best_position
	# Se os spawns normais estiverem concentrados perto de outra missão, procura
	# terreno livre em outros setores da cidade, sem reaproveitar a mesma área.
	var fallback: Dictionary = _find_separated_quest_site(city_position, city_id, avoid_positions, false)
	if bool(fallback.get("success", false)):
		return fallback.get("position", best_position)
	if best_score < INF:
		return best_position
	return city_position + Vector3(safe_radius + 40.0, 0.0, 0.0)


func _quest_site_min_separation(position: Vector3, avoid_positions: Array) -> float:
	if avoid_positions.is_empty():
		return INF
	var minimum_distance: float = INF
	for value in avoid_positions:
		if not (value is Vector3):
			continue
		var other: Vector3 = value
		var distance: float = Vector2(position.x - other.x, position.z - other.z).length()
		minimum_distance = minf(minimum_distance, distance)
	return minimum_distance


func _is_quest_site_separated(position: Vector3, avoid_positions: Array) -> bool:
	return avoid_positions.is_empty() or _quest_site_min_separation(position, avoid_positions) >= QUEST_SITE_MIN_SEPARATION


func _quest_site_score(position: Vector3, city_position: Vector3, avoid_positions: Array) -> float:
	var city_distance: float = Vector2(position.x - city_position.x, position.z - city_position.z).length()
	var score: float = city_distance
	if not avoid_positions.is_empty():
		var separation: float = _quest_site_min_separation(position, avoid_positions)
		if separation < QUEST_SITE_MIN_SEPARATION:
			# Grande penalidade: um ponto separado é sempre preferível a outro perto.
			score += 10000.0 + (QUEST_SITE_MIN_SEPARATION - separation) * 30.0
		else:
			# Entre locais separados, favorece ligeiramente os que ficam mais distantes.
			score -= minf(separation, 420.0) * 0.12
	return score


func _find_separated_quest_site(city_position: Vector3, city_id: String, avoid_positions: Array, region_only: bool) -> Dictionary:
	var best_separated_position: Vector3 = Vector3.ZERO
	var best_separated_score: float = INF
	var best_any_position: Vector3 = Vector3.ZERO
	var best_any_separation: float = -1.0
	var best_any_score: float = INF
	var radii: Array[float] = [float(safe_radius + 45.0), 170.0, 230.0, 300.0, 380.0, 480.0, 600.0, 720.0]
	for radius in radii:
		for i in range(48):
			var angle: float = TAU * float(i) / 48.0
			var candidate: Vector3 = _ground(city_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
			if safe_zone_at(candidate) != "" or candidate.y <= sea_level + SEA_MARGIN:
				continue
			if region_only and not is_position_in_city_region(candidate, city_id):
				continue
			var separation: float = _quest_site_min_separation(candidate, avoid_positions)
			var score: float = Vector2(candidate.x - city_position.x, candidate.z - city_position.z).length()
			if separation >= QUEST_SITE_MIN_SEPARATION and score < best_separated_score:
				best_separated_score = score
				best_separated_position = candidate
			if separation > best_any_separation or (is_equal_approx(separation, best_any_separation) and score < best_any_score):
				best_any_separation = separation
				best_any_score = score
				best_any_position = candidate
	if best_separated_score < INF:
		return {"success": true, "position": best_separated_position}
	if best_any_separation >= 0.0:
		return {"success": true, "position": best_any_position}
	return {"success": false, "position": city_position}


func spawn_quest_targets(quest_id: String, target_kind: String, desired_count: int, preferred_position: Vector3, city_id: String, region_only: bool) -> Dictionary:
	if game == null or game.enemy_scene == null or desired_count <= 0:
		return {"success": false, "message": "O sistema de encontros não está pronto."}
	var enemy_config: Dictionary = _enemy_cfg(target_kind)
	if enemy_config.is_empty():
		return {"success": false, "message": "Não existe uma configuração válida para esse tipo de alvo."}

	# Se a função for chamada mais de uma vez na mesma cena, não duplica um grupo
	# que ainda esteja vivo. A contagem considera somente os filhos deste overworld.
	var existing_count: int = 0
	var existing_anchor: Vector3 = Vector3.ZERO
	for enemy_value in get_tree().get_nodes_in_group("overworld_enemies"):
		if not is_instance_valid(enemy_value) or enemy_value.get_parent() != self:
			continue
		if str(enemy_value.get_meta("quest_id", "")) != quest_id:
			continue
		if int(enemy_value.get("hp")) <= 0:
			continue
		if existing_count == 0:
			existing_anchor = (enemy_value as Node3D).global_position
		existing_count += 1
	if existing_count >= desired_count:
		return {"success": true, "position": existing_anchor, "spawned": 0}
	var to_spawn: int = desired_count - existing_count

	var anchor_result: Dictionary = _find_quest_target_anchor(city_id, target_kind, preferred_position, region_only)
	if not bool(anchor_result.get("success", false)):
		return {"success": false, "message": "Não encontrei um ponto seguro para preparar os alvos. Tente aceitar o trabalho novamente."}
	var anchor: Vector3 = anchor_result["position"]
	if existing_count > 0:
		anchor = existing_anchor

	# Primeiro reserva posições válidas; só depois cria os inimigos para nunca
	# aceitar um contrato deixando um grupo incompleto.
	var target_positions: Array[Vector3] = []
	var max_attempts: int = maxi(40, to_spawn * 16)
	for attempt in range(max_attempts):
		var angle: float = float(attempt) * 2.399963 + rng.randf_range(-0.18, 0.18)
		var radius: float = 2.8 + 1.35 * sqrt(float(attempt % 18)) + rng.randf_range(0.0, 1.1)
		var candidate: Vector3 = _ground(anchor + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		if safe_zone_at(candidate) != "" or candidate.y <= sea_level + SEA_MARGIN:
			continue
		if region_only and not is_position_in_city_region(candidate, city_id):
			continue
		var overlaps := false
		for chosen in target_positions:
			if Vector2(chosen.x - candidate.x, chosen.z - candidate.z).length() < 1.65:
				overlaps = true
				break
		if overlaps:
			continue
		target_positions.append(candidate)
		if target_positions.size() >= to_spawn:
			break
	if target_positions.size() < to_spawn:
		return {"success": false, "message": "Não há espaço seguro suficiente para preparar todos os alvos deste trabalho."}

	var created: Array[Node] = []
	for target_position in target_positions:
		var enemy: Node = game.enemy_scene.instantiate()
		if enemy == null:
			for created_enemy in created:
				if is_instance_valid(created_enemy):
					created_enemy.queue_free()
			return {"success": false, "message": "Não foi possível criar todos os alvos do trabalho."}
		enemy.add_to_group("overworld_enemies")
		add_child(enemy)
		enemy.global_position = target_position + Vector3(0.0, 0.2, 0.0)
		enemy.call("setup", enemy_config, game)
		enemy.set_meta("quest_id", quest_id)
		enemy.set_meta("quest_target", true)
		var player_position: Vector3 = game.player.global_position if game.player != null else Vector3.ZERO
		var distance_to_player: float = Vector2(target_position.x - player_position.x, target_position.z - player_position.z).length()
		enemy.call("set_stream_active", distance_to_player <= ENEMY_ACTIVE_RADIUS)
		created.append(enemy)
		if _regional_threats != null:
			_regional_threats.report_enemy_spawn(target_position, target_kind)
	return {"success": true, "position": anchor, "spawned": created.size()}


func _find_quest_target_anchor(city_id: String, target_kind: String, preferred_position: Vector3, region_only: bool) -> Dictionary:
	var preferred: Vector3 = _ground(preferred_position)
	if _quest_anchor_is_valid(preferred, city_id, region_only):
		return {"success": true, "position": preferred}
	var best_position: Vector3 = Vector3.ZERO
	var best_score: float = INF
	for spawn_value in spawns:
		var spawn_record: Dictionary = spawn_value
		var position: Vector3 = _ground(spawn_record.get("pos", preferred))
		if not _quest_anchor_is_valid(position, city_id, region_only):
			continue
		var pool: Dictionary = spawn_record.get("pool", {})
		var score: float = Vector2(position.x - preferred.x, position.z - preferred.z).length()
		if not pool.has(target_kind):
			score += 180.0
		if not region_only and not is_position_in_city_region(position, city_id):
			score += 350.0
		if score < best_score:
			best_score = score
			best_position = position
	if best_score < INF:
		return {"success": true, "position": best_position}

	var city_position: Vector3 = quest_city_position(city_id)
	for radius in [float(safe_radius + 45.0), 170.0, 230.0, 300.0, 380.0]:
		for i in range(32):
			var angle: float = TAU * float(i) / 32.0
			var candidate: Vector3 = _ground(city_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
			if _quest_anchor_is_valid(candidate, city_id, region_only):
				return {"success": true, "position": candidate}
	return {"success": false, "position": city_position}


func _quest_anchor_is_valid(position: Vector3, city_id: String, region_only: bool) -> bool:
	if safe_zone_at(position) != "" or position.y <= sea_level + SEA_MARGIN:
		return false
	if region_only and not is_position_in_city_region(position, city_id):
		return false
	return true


# ---------- Mapa de teste (só enquanto não houver overworld.glb) ----------

func _build_test_map() -> void:
	_map = Node3D.new()
	_map.name = "MapaDeTeste"
	add_child(_map)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	var half := 240.0
	var step := 8.0
	var n := int(half * 2.0 / step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x0 := -half + i * step
			var z0 := -half + j * step
			var a := _test_point(noise, x0, z0)
			var b := _test_point(noise, x0, z0 + step)
			var c := _test_point(noise, x0 + step, z0 + step)
			var d := _test_point(noise, x0 + step, z0)
			_test_tri(st, a, b, c)
			_test_tri(st, a, c, d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Terreno"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	_map.add_child(mi)
	for key in TEST_MARKERS:
		var m := Node3D.new()
		m.name = key
		m.position = TEST_MARKERS[key]
		_map.add_child(m)


func _test_point(noise: FastNoiseLite, x: float, z: float) -> Vector3:
	var flat := clampf(Vector2(x, z).length() / 30.0, 0.0, 1.0)
	return Vector3(x, noise.get_noise_2d(x, z) * 9.0 * flat, z)


func _test_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		var t := clampf(p.y / 9.0, 0.0, 1.0)
		st.set_color(Color(0.24, 0.44, 0.2).lerp(Color(0.45, 0.38, 0.27), t))
		st.add_vertex(p)


# ---------- Visual ----------

func _make_sky_and_sun() -> void:
	# O mundo exterior usa seu próprio Environment. Ao entrar na cripta, game.gd
	# troca para o ambiente da masmorra e libera este mundo.
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 0.1 # discos são desenhados pelas cúpulas abaixo
	sky_material.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.0
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 80.0
	environment.fog_depth_end = 720.0
	environment.fog_density = 0.28
	environment.fog_sky_affect = 0.15

	if game != null and game.world_environment_node != null:
		game.world_environment_node.environment = environment
		game.player.cam.environment = null # usa o WorldEnvironment global
	elif game != null and game.player != null:
		game.player.cam.environment = environment

	sun = DirectionalLight3D.new()
	sun.name = "SolDinamico"
	# A direção ilumina a geometria; o disco visível é desenhado por shader.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_enabled = false # mantém o custo baixo para GPUs antigas
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "LuaDinamica"
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.shadow_enabled = false
	moon.light_color = Color(0.68, 0.76, 1.0)
	moon.light_energy = 0.0
	add_child(moon)

	_setup_star_dome()
	_setup_celestial_dome()
	_setup_cloud_dome()

	time_of_day_hours = DEFAULT_START_HOUR
	if game != null:
		time_of_day_hours = float(game.day_time_hours)
		moon_phase_index = int(game.moon_phase_index)
		noon_count = int(game.moon_phase_noon_count)
	moon_phase_angle = float(moon_phase_index) * TAU / 8.0
	_update_day_night(0.0)


func _create_sky_sphere(radius: float, dome_name: String) -> MeshInstance3D:
	var dome := MeshInstance3D.new()
	dome.name = dome_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	dome.mesh = sphere
	dome.layers = 1
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	return dome


func _setup_star_dome() -> void:
	star_dome = _create_sky_sphere(SKY_RADIUS, "StarDome")
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, fog_disabled;

uniform float star_strength = 0.0;
varying vec3 sky_dir;

vec3 hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

void vertex() {
    sky_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

void fragment() {
    vec3 d = normalize(sky_dir);
    vec3 p = d * 72.0;
    vec3 cell = floor(p);
    vec3 rnd = hash33(cell);
    vec3 rnd2 = hash33(cell + 17.0);
    float star_cell = step(0.62, rnd.x);
    vec3 star_pos = cell + 0.5 + (rnd2 - 0.5) * 0.54;
    float dist_to_star = distance(p, star_pos);
    float star = 1.0 - smoothstep(0.035, 0.145, dist_to_star);
    float twinkle = 0.88 + 0.12 * sin(TIME * (1.2 + rnd.z * 2.4) + rnd.y * 31.0);
    float above_horizon = smoothstep(-0.055, 0.10, d.y);
    star *= star_cell * twinkle * above_horizon * star_strength;
    ALBEDO = vec3(0.72, 0.82, 1.0);
    EMISSION = ALBEDO * star;
    ALPHA = star;
}
"""
	star_material = ShaderMaterial.new()
	star_material.shader = shader
	star_material.render_priority = -4
	star_dome.material_override = star_material
	star_material.set_shader_parameter("star_strength", 0.0)


func _setup_celestial_dome() -> void:
	celestial_dome = _create_sky_sphere(SKY_RADIUS - 2.0, "CelestialDome")
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);
uniform vec3 moon_dir = vec3(-1.0, 0.0, 0.0);
uniform vec3 sun_color = vec3(1.0, 0.78, 0.48);
uniform float sun_size = 0.034;
uniform float moon_size = 0.023;
uniform float moon_phase = 3.14159;
uniform float visibility = 1.0;
varying vec3 sky_dir;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float e = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

void vertex() {
    sky_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

void fragment() {
    vec3 d = normalize(sky_dir);

    // Disco e halo solar, localizados pela direção astronômica calculada no script.
    float sun_angle = acos(clamp(dot(d, normalize(sun_dir)), -1.0, 1.0));
    float sun_disc = 1.0 - smoothstep(sun_size * 0.88, sun_size, sun_angle);
    float sun_halo = exp(-sun_angle * 7.0) * 0.36 + exp(-sun_angle * 25.0) * 0.22;
    float sun_alpha = clamp(sun_disc + sun_halo * (1.0 - sun_disc), 0.0, 1.0);
    vec3 sun_rgb = mix(sun_color, vec3(1.0, 0.98, 0.88), sun_disc);

    // Disco lunar com crateras estilizadas e fase realçada pelo terminador.
    vec3 md = normalize(moon_dir);
    float moon_dot = dot(d, md);
    vec3 reference_up = abs(md.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(md, reference_up));
    vec3 upv = normalize(cross(right, md));
    vec2 moon_pos = vec2(dot(d, right), dot(d, upv)) / moon_size;
    float radius = length(moon_pos);
    float moon_disc = moon_dot > 0.0 ? 1.0 - smoothstep(0.94, 1.0, radius) : 0.0;
    vec3 normal = vec3(moon_pos, sqrt(max(1.0 - radius * radius, 0.0)));
    vec3 light_dir = normalize(vec3(sin(moon_phase), 0.0, -cos(moon_phase)));
    float illumination = smoothstep(-0.04, 0.12, dot(normal, light_dir));
    float maria = smoothstep(0.43, 0.67, noise2(moon_pos * 3.2 + vec2(4.0, 9.0)));
    vec2 crater_grid = moon_pos * 8.0;
    vec2 crater_cell = floor(crater_grid);
    vec2 crater_off = (vec2(hash21(crater_cell), hash21(crater_cell + 7.7)) - 0.5) * 0.48;
    float crater_radius = 0.12 + 0.16 * hash21(crater_cell + 3.3);
    float crater = 1.0 - smoothstep(crater_radius * 0.72, crater_radius, length(fract(crater_grid) - 0.5 - crater_off));
    crater *= step(0.48, hash21(crater_cell + 9.1));
    float lunar_albedo = mix(1.0, 0.68, maria) * (1.0 - crater * 0.22);
    vec3 moon_bright = vec3(0.82, 0.86, 0.91) * lunar_albedo * (0.06 + 0.94 * illumination);
    vec3 moon_dark = vec3(0.13, 0.17, 0.24);
    vec3 moon_rgb = mix(moon_dark, moon_bright, illumination);
    float moon_alpha = moon_disc * (0.82 + 0.18 * illumination);
    float moon_halo = moon_dot > 0.0 ? exp(-max(acos(clamp(moon_dot, -1.0, 1.0)) - moon_size, 0.0) * 16.0) * 0.13 : 0.0;
    moon_alpha = max(moon_alpha, moon_halo * (1.0 - moon_disc));

    // O horizonte esconde os astros quando estão abaixo do terreno.
    float horizon = smoothstep(-0.045, 0.035, d.y);
    sun_alpha *= horizon;
    moon_alpha *= horizon;
    float total_alpha = sun_alpha + moon_alpha;
    vec3 result_color = (sun_rgb * sun_alpha + moon_rgb * moon_alpha) / max(total_alpha, 0.0001);
    ALBEDO = result_color;
    ALPHA = clamp(total_alpha, 0.0, 1.0) * visibility;
}
"""
	celestial_material = ShaderMaterial.new()
	celestial_material.shader = shader
	celestial_material.render_priority = -3
	celestial_dome.material_override = celestial_material


func _setup_cloud_dome() -> void:
	cloud_dome = _create_sky_sphere(SKY_RADIUS - 4.0, "CloudLayer")
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;

uniform float cloud_time = 0.0;
uniform float cloud_strength = 0.0;
uniform float coverage : hint_range(0.0, 1.0) = 0.48;
uniform vec3 cloud_tint = vec3(1.0);
varying vec3 sky_dir;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float e = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; i++) {
        value += noise2(p) * amplitude;
        p = p * 2.03 + vec2(17.3, 9.1);
        amplitude *= 0.5;
    }
    return value;
}
void vertex() {
    sky_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}
void fragment() {
    vec3 d = normalize(sky_dir);
    vec2 p = d.xz / (max(d.y, 0.0) + 0.15);
    p *= 1.4;
    p += vec2(cloud_time * 0.012, cloud_time * 0.005);
    float n = fbm(p);
    float body = smoothstep(coverage, coverage + 0.14, n);
    float core = smoothstep(coverage + 0.10, coverage + 0.45, n);
    vec3 col = cloud_tint * mix(0.68, 1.0, core);
    float fade = smoothstep(0.02, 0.22, d.y);
    ALBEDO = col;
    ALPHA = body * cloud_strength * fade;
}
"""
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = shader
	cloud_material.render_priority = -2 # desenha o céu antes das legendas 3D de NPCs
	cloud_dome.material_override = cloud_material
	cloud_material.set_shader_parameter("cloud_strength", 0.0)


func _update_day_night(delta: float) -> void:
	if sky_material == null or sun == null or moon == null or environment == null:
		return

	var previous_time := time_of_day_hours
	if delta > 0.0:
		time_of_day_hours = fposmod(time_of_day_hours + (24.0 / day_length_seconds) * delta, 24.0)
		cloud_time += delta
		if game != null:
			game.day_time_hours = time_of_day_hours
		if previous_time < 12.0 and time_of_day_hours >= 12.0:
			noon_count += 1
			if noon_count >= days_per_moon_phase:
				noon_count = 0
				moon_phase_index = (moon_phase_index + 1) % 8
			if game != null:
				game.moon_phase_index = moon_phase_index
				game.moon_phase_noon_count = noon_count

	var target_moon_phase := float(moon_phase_index) * TAU / 8.0
	moon_phase_angle = lerp_angle(moon_phase_angle, target_moon_phase, 1.0 - exp(-maxf(delta, 0.0) * 0.8))

	# Órbita determinística: +X é leste, -X oeste, +Z sul.
	# 06h: leste/horizonte; 12h: arco alto ao sul; 18h: oeste/horizonte;
	# meia-noite: abaixo do horizonte no lado norte. A lua percorre o arco oposto.
	var orbit_angle := (time_of_day_hours - 6.0) * TAU / 24.0
	var max_altitude := sin(deg_to_rad(70.0))
	var altitude := sin(orbit_angle) * max_altitude
	var horizontal := sqrt(maxf(0.0, 1.0 - altitude * altitude))
	var sun_direction := Vector3(cos(orbit_angle) * horizontal, altitude, sin(orbit_angle) * horizontal).normalized()
	var moon_direction := -sun_direction

	# DirectionalLight3D emite para -Z. O disco visível usa diretamente sun_direction,
	# de modo que a trajetória celeste não dependa de pequenas diferenças de rotação.
	sun.look_at(sun.global_position - sun_direction, Vector3.UP)
	moon.look_at(moon.global_position - moon_direction, Vector3.UP)

	var sun_altitude := sun_direction.y
	var daylight := _smooth_range(-0.08, 0.35, sun_altitude)
	var twilight := 1.0 - clampf(absf(sun_altitude) / 0.42, 0.0, 1.0)
	var moon_altitude := moon_direction.y
	var moon_visibility := _smooth_range(-0.10, 0.22, moon_altitude)
	var night_progress := clampf(inverse_lerp(0.12, -0.32, sun_altitude), 0.0, 1.0)

	# Iluminação direta mais quente no horizonte e azul fria durante a noite.
	var night_light := Color(0.16, 0.21, 0.36)
	var sunlight_color := night_light.lerp(Color(1.0, 0.92, 0.78), daylight)
	sun.light_color = sunlight_color.lerp(Color(1.0, 0.48, 0.31), twilight * 0.60)
	sun.light_energy = (lerpf(0.0, 1.20, daylight) + twilight * 0.10)
	moon.light_color = Color(0.68, 0.76, 1.0)
	moon.light_energy = 0.10 * moon_visibility

	# Céu: azul diurno, crepúsculo âmbar e azul-noite. Os astros não dependem
	# do disco automático do ProceduralSkyMaterial; são renderizados na cúpula.
	var night_top := Color(0.012, 0.022, 0.065)
	var day_top := Color(0.30, 0.50, 0.80)
	var night_horizon := Color(0.025, 0.035, 0.085)
	var day_horizon := Color(0.70, 0.78, 0.85)
	var night_ground := Color(0.025, 0.032, 0.040)
	var day_ground := Color(0.55, 0.60, 0.50)
	sky_material.sky_top_color = night_top.lerp(day_top, daylight).lerp(Color(0.48, 0.20, 0.20), twilight * 0.52)
	sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(Color(0.90, 0.43, 0.27), twilight * 0.68)
	sky_material.ground_horizon_color = night_ground.lerp(day_ground, daylight).lerp(Color(0.38, 0.23, 0.19), twilight * 0.55)
	sky_material.ground_bottom_color = Color(0.004, 0.006, 0.012).lerp(Color(0.20, 0.20, 0.18), daylight)

	# A noite continua legível, mas fica claramente mais escura que o dia.
	environment.ambient_light_color = Color(0.17, 0.22, 0.38).lerp(Color(0.68, 0.73, 0.80), daylight).lerp(Color(0.78, 0.48, 0.38), twilight * 0.35)
	environment.ambient_light_energy = lerpf(0.24, 0.80, daylight)
	environment.fog_light_color = sky_material.sky_horizon_color

	if celestial_material != null:
		celestial_material.set_shader_parameter("sun_dir", sun_direction)
		celestial_material.set_shader_parameter("moon_dir", moon_direction)
		celestial_material.set_shader_parameter("sun_color", Vector3(sun.light_color.r, sun.light_color.g, sun.light_color.b))
		celestial_material.set_shader_parameter("moon_phase", moon_phase_angle)
		celestial_material.set_shader_parameter("visibility", 1.0)
	if star_material != null:
		star_material.set_shader_parameter("star_strength", night_progress * 0.98)
	if cloud_material != null:
		var sunset_t := _smooth_range(-0.40, 0.0, sun_altitude)
		var day_t := _smooth_range(-0.05, 0.55, sun_altitude)
		var tint := Color(0.16, 0.20, 0.34).lerp(Color(1.0, 0.62, 0.42), sunset_t).lerp(Color.WHITE, day_t)
		var cloud_strength := (0.82 if clouds_enabled else 0.0) * lerpf(0.72, 1.0, daylight)
		cloud_material.set_shader_parameter("coverage", cloud_coverage)
		cloud_material.set_shader_parameter("cloud_strength", cloud_strength)
		cloud_material.set_shader_parameter("cloud_tint", Vector3(tint.r, tint.g, tint.b))
		cloud_material.set_shader_parameter("cloud_time", cloud_time)


func _update_sky_domes() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	camera.set_cull_mask_value(1, true)
	camera.set_cull_mask_value(20, true)
	# As cúpulas acompanham a câmera para parecerem infinitamente distantes.
	# Aumenta o plano de corte quando necessário para evitar que o céu seja cortado.
	if camera.far < SKY_RADIUS * 1.2:
		if _camera_far_original < 0.0:
			_camera_far_original = camera.far
		camera.far = SKY_RADIUS * 1.2
	if star_dome != null:
		star_dome.global_position = camera.global_position
	if celestial_dome != null:
		celestial_dome.global_position = camera.global_position
	if cloud_dome != null:
		cloud_dome.global_position = camera.global_position


func _exit_tree() -> void:
	# Persiste o estado regional inteiro (incluindo a camada de neve) ao sair
	# do overworld, sem depender do próximo ciclo de atualização da textura.
	if game != null and is_instance_valid(game):
		game.weather_region_session_state = _weather_regions.duplicate(true)
	# Restaura a distância de renderização da câmera ao sair do overworld,
	# para não prejudicar a precisão de profundidade dentro da cripta.
	if _camera_far_original > 0.0 and game != null and game.player != null and is_instance_valid(game.player):
		game.player.cam.far = _camera_far_original


func _smooth_range(edge_a: float, edge_b: float, value: float) -> float:
	var t := clampf((value - edge_a) / (edge_b - edge_a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ---------- Clima regional: células, transições, chuva, tempestade e solo úmido ----------

func _normalize_weather_region_keys(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_key in source.keys():
		var cell: Variant = raw_key
		if not (cell is Vector2i):
			cell = _parse_weather_region_key(str(raw_key))
		if not (cell is Vector2i):
			continue
		var raw_state: Variant = source[raw_key]
		if raw_state is Dictionary:
			normalized[cell] = raw_state.duplicate(true)
	return normalized


func _parse_weather_region_key(raw_key: String) -> Variant:
	var cleaned := raw_key.strip_edges()
	cleaned = cleaned.replace("Vector2i", "").replace("(", "").replace(")", "").replace("[", "").replace("]", "")
	var parts := cleaned.split(",")
	if parts.size() < 2:
		parts = cleaned.split(":")
	if parts.size() < 2:
		return null
	var x_text := str(parts[0]).strip_edges()
	var y_text := str(parts[1]).strip_edges()
	if not x_text.is_valid_int() or not y_text.is_valid_int():
		return null
	return Vector2i(x_text.to_int(), y_text.to_int())


func _setup_weather_system() -> void:
	if game != null:
		if int(game.weather_world_seed) == 0:
			game.weather_world_seed = rng.randi_range(1, 2147483647)
		_weather_regions = _normalize_weather_region_keys(game.weather_region_session_state)
	var climate_seed: int = int(game.weather_world_seed) if game != null else rng.randi()
	_weather_rng.seed = climate_seed
	_weather_noise = FastNoiseLite.new()
	_weather_noise.seed = climate_seed
	_weather_noise.frequency = 0.00105
	_initial_weather_applied = not _weather_regions.is_empty()
	current_weather = clampi(starting_weather, Weather.CLEAR, Weather.SNOWSTORM)
	_setup_rain_particles()
	_setup_snow_particles()
	_setup_wet_surfaces()
	_setup_lightning()


func _setup_lantern_lighting() -> void:
	if _lanterns_initialized or _map == null:
		return
	_lanterns_initialized = true
	var meshes: Array = []
	_collect_meshes(_map, meshes)
	var scanned_buildings := 0
	for mesh_value in meshes:
		if not (mesh_value is MeshInstance3D):
			continue
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var surface_count := mesh_instance.mesh.get_surface_count()
		var building_has_lantern := false
		for surface_index in range(surface_count):
			var original_material := mesh_instance.get_active_material(surface_index)
			if original_material == null or not _is_lantern_glow_material(original_material):
				continue
			building_has_lantern = true
			var runtime_material := original_material.duplicate(true) as StandardMaterial3D
			if runtime_material != null:
				runtime_material.resource_name = "LanternGlow_Runtime_%s_%d" % [str(mesh_instance.name), surface_index]
				runtime_material.emission_enabled = true
				runtime_material.emission = Color(1.0, 0.57, 0.24, 1.0)
				runtime_material.emission_energy_multiplier = 0.0
				runtime_material.albedo_color = Color(0.34, 0.25, 0.16, 1.0)
				mesh_instance.set_surface_override_material(surface_index, runtime_material)
				_lantern_material_records.append({"material": runtime_material, "node_name": str(mesh_instance.name)})

			var surface_arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var vertex_value: Variant = surface_arrays[Mesh.ARRAY_VERTEX]
			if not (vertex_value is PackedVector3Array):
				continue
			var positions := _cluster_lantern_vertices(vertex_value as PackedVector3Array)
			var light_strength := _lantern_strength_for_building(str(mesh_instance.name))
			for cluster_value in positions:
				var cluster: Dictionary = cluster_value
				var local_position: Vector3 = cluster.get("position", Vector3.ZERO)
				var world_position: Vector3 = mesh_instance.global_transform * local_position
				_lantern_sources.append({
					"position": world_position + Vector3(0.0, 0.10, 0.0),
					"strength": light_strength,
					"building": str(mesh_instance.name)
				})
		if building_has_lantern:
			scanned_buildings += 1

	# Use a small pool of real lights instead of creating hundreds of inactive
	# OmniLight3D nodes across the world. Only the nearest lanterns get a light.
	var pool_size := mini(LANTERN_MAX_ACTIVE_LIGHTS, _lantern_sources.size())
	for index in range(pool_size):
		var lamp := OmniLight3D.new()
		lamp.name = "LuzLanterna_%02d" % index
		lamp.light_color = Color(1.0, 0.58, 0.30, 1.0)
		lamp.light_energy = 0.0
		lamp.omni_range = LANTERN_LIGHT_RANGE
		lamp.omni_attenuation = 1.35
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		_lantern_lights.append(lamp)

	if scanned_buildings == 0 or _lantern_sources.is_empty():
		push_warning("Iluminação: não foi encontrada a superfície OW_LanternGlow no modelo atual; a iluminação padrão permanece ativa.")


func _is_lantern_glow_material(material: Material) -> bool:
	var material_name := str(material.resource_name).to_lower()
	if material_name.contains("lanternglow"):
		return true
	# Fallback for GLTF importers that don't retain the material resource name.
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return standard.emission_enabled and standard.emission.r > 0.80 and standard.emission.g > 0.25 and standard.emission.b < 0.55 and standard.emission_energy_multiplier >= 2.0
	return false


func _cluster_lantern_vertices(vertices: PackedVector3Array) -> Array[Dictionary]:
	# Each building mesh packs its lanterns into an emissive surface. Group its
	# vertices by horizontal position to recover a handful of light positions.
	var clusters: Array[Dictionary] = []
	for vertex in vertices:
		var best_index := -1
		var best_distance := 1.15
		for i in range(clusters.size()):
			var cluster_center_sum: Vector3 = clusters[i].get("sum", Vector3.ZERO)
			var cluster_count: int = int(clusters[i].get("count", 0))
			if cluster_count <= 0:
				continue
			var cluster_center := cluster_center_sum / float(cluster_count)
			var horizontal_distance := Vector2(vertex.x - cluster_center.x, vertex.z - cluster_center.z).length()
			if horizontal_distance < best_distance:
				best_distance = horizontal_distance
				best_index = i
		if best_index >= 0:
			var updated_sum: Vector3 = clusters[best_index].get("sum", Vector3.ZERO)
			clusters[best_index]["sum"] = updated_sum + vertex
			clusters[best_index]["count"] = int(clusters[best_index].get("count", 0)) + 1
		else:
			clusters.append({"sum": vertex, "count": 1})

	var result: Array[Dictionary] = []
	for cluster in clusters:
		var count := int(cluster.get("count", 0))
		if count < 4:
			continue
		var total: Vector3 = cluster.get("sum", Vector3.ZERO)
		result.append({"position": total / float(count), "count": count})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	# Buildings in this GLB use two or four lanterns; this cap also protects
	# against accidental over-clustering if the asset topology changes later.
	if result.size() > 4:
		result.resize(4)
	return result


func _lantern_strength_for_building(node_name: String) -> float:
	var lower := node_name.to_lower()
	if lower.contains("town_hall") or lower.contains("inn") or lower.contains("shop") or lower.contains("temple"):
		return 1.0
	if lower.contains("guard_post") or lower.contains("lookout") or lower.contains("shelter"):
		return 0.92
	if lower.contains("library") or lower.contains("infirmary") or lower.contains("workshop"):
		return 0.84
	if lower.contains("stable") or lower.contains("barn") or lower.contains("depot") or lower.contains("mill"):
		return 0.72
	return 0.78


func _lantern_night_factor() -> float:
	# O relógio é cíclico: a noite deve continuar iluminada depois da meia-noite,
	# não apenas entre o pôr do sol e 24h.
	var hour := fposmod(time_of_day_hours, 24.0)
	if hour < 4.4:
		return 1.0
	if hour < 7.2:
		return 1.0 - _smooth_range(4.4, 7.2, hour)
	if hour < 16.5:
		return 0.0
	return _smooth_range(16.5, 19.3, hour)


func _update_lantern_lighting(delta: float, player_position: Vector3) -> void:
	if not _lanterns_initialized:
		return
	_lantern_refresh_timer -= maxf(delta, 0.0)
	if _lantern_refresh_timer > 0.0:
		return
	_lantern_refresh_timer = LANTERN_REFRESH_SECONDS
	var night_factor := _lantern_night_factor()
	var weather_boost := 1.0 + clampf(overcast_amount, 0.0, 1.0) * 0.22
	var emission_energy := LANTERN_EMISSION_ENERGY * night_factor * weather_boost
	var lighting_changed := (
		absf(emission_energy - _last_lantern_emission_energy) >= 0.10
		or absf(night_factor - _last_lantern_night_factor) >= 0.025
		or absf(weather_boost - _last_lantern_weather_boost) >= 0.025
	)
	if lighting_changed:
		var daylight_glass := Color(0.34, 0.25, 0.16, 1.0)
		var lit_glass := Color(1.0, 0.62, 0.28, 1.0)
		for record in _lantern_material_records:
			var material_value: Variant = record.get("material")
			if material_value is StandardMaterial3D and is_instance_valid(material_value):
				var material := material_value as StandardMaterial3D
				material.emission_energy_multiplier = emission_energy
				material.albedo_color = daylight_glass.lerp(lit_glass, night_factor)
		_last_lantern_emission_energy = emission_energy
		_last_lantern_night_factor = night_factor
		_last_lantern_weather_boost = weather_boost

	var candidates: Array[Dictionary] = []
	if night_factor > 0.025 and game != null and game.player != null:
		var radius_squared := LANTERN_ACTIVE_RADIUS * LANTERN_ACTIVE_RADIUS
		for source in _lantern_sources:
			var light_position: Vector3 = source.get("position", Vector3.ZERO)
			var offset := Vector2(light_position.x - player_position.x, light_position.z - player_position.z)
			var distance_squared := offset.length_squared()
			if distance_squared <= radius_squared:
				candidates.append({
					"position": light_position,
					"strength": float(source.get("strength", 0.8)),
					"distance_squared": distance_squared
				})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_squared", INF)) < float(b.get("distance_squared", INF))
	)
	var active_count := mini(_lantern_lights.size(), candidates.size())
	for i in range(_lantern_lights.size()):
		var light := _lantern_lights[i]
		if not is_instance_valid(light):
			continue
		if i < active_count:
			var source: Dictionary = candidates[i]
			light.global_position = source.get("position", player_position)
			var strength := float(source.get("strength", 0.8))
			light.light_energy = LANTERN_BASE_LIGHT_ENERGY * night_factor * weather_boost * strength
			light.visible = light.light_energy > 0.025
		else:
			light.visible = false
			light.light_energy = 0.0


func _player_is_under_structure(position: Vector3) -> bool:
	if game == null or game.player == null or _inside_building:
		return _inside_building
	var ray_from := position + Vector3(0.0, 0.65, 0.0)
	var ray_to := position + Vector3(0.0, 9.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [game.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider_value: Variant = hit.get("collider")
	if not (collider_value is Node):
		return false
	var current_node: Node = collider_value as Node
	var structural_tokens: Array[String] = ["_building_", "_shelter", "_stable", "_guard_post", "_lookout", "_barn", "_depot", "_inn", "_shop", "_temple", "_house", "_library", "_infirmary", "_workshop", "_mill", "_town_hall"]
	while current_node != null:
		var lower_name := str(current_node.name).to_lower()
		for token in structural_tokens:
			if lower_name.contains(token):
				return true
		current_node = current_node.get_parent()
	return false


func _setup_rain_particles() -> void:
	# CPU particles mantêm compatibilidade com o renderer Compatibility e GPUs antigas.
	rain_particles = CPUParticles3D.new()
	rain_particles.name = "Chuva"
	rain_particles.amount = 280
	rain_particles.lifetime = 0.9
	rain_particles.emitting = false
	rain_particles.local_coords = false
	rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_particles.layers = 1
	rain_particles.visibility_aabb = AABB(Vector3(-28.0, -28.0, -28.0), Vector3(56.0, 50.0, 56.0))

	# CPUParticles3D expõe os parâmetros diretamente; ParticleProcessMaterial
	# é exclusivo do sistema GPUParticles3D.
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(22.0, 0.5, 22.0)
	rain_particles.direction = Vector3(0.08, -1.0, 0.04)
	rain_particles.spread = 3.0
	rain_particles.initial_velocity_min = 17.0
	rain_particles.initial_velocity_max = 22.0
	rain_particles.gravity = Vector3(0.0, -11.0, 0.0)
	rain_particles.scale_amount_min = 0.7
	rain_particles.scale_amount_max = 1.1

	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.48)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.70, 0.81, 0.94, 0.48)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = mat
	rain_particles.mesh = streak
	add_child(rain_particles)


func _setup_snow_particles() -> void:
	# Flocos simples, sem textura externa, compatíveis com o renderer Compatibility.
	# A contagem é moderada para não penalizar GPUs antigas nem a CPU do jogo.
	snow_particles = CPUParticles3D.new()
	snow_particles.name = "Neve"
	snow_particles.amount = 260
	snow_particles.lifetime = 5.0
	snow_particles.emitting = false
	snow_particles.local_coords = false
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.layers = 1
	snow_particles.visibility_aabb = AABB(Vector3(-29.0, -30.0, -29.0), Vector3(58.0, 48.0, 58.0))
	snow_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow_particles.emission_box_extents = Vector3(23.0, 0.5, 23.0)
	snow_particles.direction = Vector3(0.10, -1.0, 0.04)
	snow_particles.spread = 22.0
	snow_particles.initial_velocity_min = 1.0
	snow_particles.initial_velocity_max = 2.8
	snow_particles.gravity = Vector3(0.0, -0.48, 0.0)
	snow_particles.scale_amount_min = 0.55
	snow_particles.scale_amount_max = 1.25
	snow_particles.angular_velocity_min = -0.45
	snow_particles.angular_velocity_max = 0.45

	var flake := QuadMesh.new()
	flake.size = Vector2(0.10, 0.10)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.88, 0.94, 1.0, 0.88)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flake.material = material
	snow_particles.mesh = flake
	add_child(snow_particles)


func _setup_wet_surfaces() -> void:
	if _map == null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D weather_field : filter_linear, repeat_disable;
uniform vec2 weather_origin = vec2(0.0, 0.0);
uniform vec2 weather_size = vec2(1.0, 1.0);
varying vec3 world_pos;
varying vec3 world_normal;
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i); float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0)); float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    vec2 safe_size = max(weather_size, vec2(1.0));
    vec2 uv = clamp((world_pos.xz - weather_origin) / safe_size, vec2(0.001), vec2(0.999));
    vec3 weather = texture(weather_field, uv).rgb;
    float wetness = weather.r;
    float puddles = weather.g;
    float snow_cover = weather.b;
    float flat_surface = smoothstep(0.58, 0.92, clamp(world_normal.y, 0.0, 1.0));
    float snow_surface = smoothstep(0.24, 0.78, clamp(world_normal.y, 0.0, 1.0));
    float patch = smoothstep(0.42, 0.78, noise2(world_pos.xz * 0.16));
    float snow_noise = noise2(world_pos.xz * 0.052 + vec2(17.2, 4.1));
    float snow_patches = smoothstep(snow_noise - 0.24, snow_noise + 0.20, snow_cover);
    float snow_growth = smoothstep(0.015, 0.13, snow_cover);
    float snow_alpha = clamp(snow_patches * snow_growth * snow_surface * (0.74 + snow_cover * 0.20), 0.0, 0.94);
    float puddle = patch * flat_surface * puddles;
    float darkening = wetness * mix(0.10, 0.23, flat_surface) + puddle * 0.18;
    vec3 wet_albedo = mix(vec3(0.035, 0.045, 0.06), vec3(0.11, 0.13, 0.16), puddle);
    vec3 snow_albedo = vec3(0.78, 0.85, 0.93) * (0.94 + 0.06 * snow_surface);
    ALBEDO = mix(wet_albedo, snow_albedo, snow_alpha);
    ALPHA = clamp(max(darkening * (1.0 - snow_alpha), snow_alpha), 0.0, 0.94);
    ROUGHNESS = mix(mix(0.82, 0.28, clamp(wetness + puddle, 0.0, 1.0)), 0.96, snow_alpha);
    SPECULAR = (0.12 + puddle * 0.18) * (1.0 - snow_alpha);
    METALLIC = 0.0;
}
"""
	wet_material = ShaderMaterial.new()
	wet_material.shader = shader
	_weather_field_image = Image.create(WEATHER_FIELD_RESOLUTION, WEATHER_FIELD_RESOLUTION, false, Image.FORMAT_RGBA8)
	_weather_field_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_weather_field_texture = ImageTexture.create_from_image(_weather_field_image)
	wet_material.set_shader_parameter("weather_field", _weather_field_texture)
	_collect_wet_meshes(_map)


func _collect_wet_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and not node.is_in_group("no_wet"):
		var lower_name := str(node.name).to_lower()
		var excluded := ["tree", "pine", "leaf", "leaves", "foliage", "grass", "bush", "shrub", "plant", "ocean", "water", "river", "cloud", "sky", "glass", "window", "lantern", "torch", "light"]
		var skip := false
		for word in excluded:
			if lower_name.contains(word):
				skip = true
				break
		if not skip and not wet_meshes.has(node):
			wet_meshes.append(node)
	for child in node.get_children():
		_collect_wet_meshes(child)


func _setup_lightning() -> void:
	lightning_light = DirectionalLight3D.new()
	lightning_light.name = "ClarãoDeTempestade"
	lightning_light.light_color = Color(0.72, 0.82, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.shadow_enabled = false
	lightning_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	lightning_light.rotation_degrees = Vector3(-35.0, 28.0, 0.0)
	add_child(lightning_light)

	lightning_bolt_mesh = ImmediateMesh.new()
	lightning_bolt_material = StandardMaterial3D.new()
	lightning_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lightning_bolt_material.albedo_color = Color(0.78, 0.88, 1.0, 1.0)
	lightning_bolt_material.emission_enabled = true
	lightning_bolt_material.emission = Color(0.48, 0.68, 1.0)
	lightning_bolt_material.emission_energy_multiplier = 2.5
	lightning_bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	lightning_bolt = MeshInstance3D.new()
	lightning_bolt.name = "RaioVisivel"
	lightning_bolt.top_level = true
	lightning_bolt.mesh = lightning_bolt_mesh
	lightning_bolt.material_override = lightning_bolt_material
	lightning_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lightning_bolt.visible = false
	add_child(lightning_bolt)
	thunder_stream = _create_thunder_stream()


func _create_thunder_stream() -> AudioStreamWAV:
	# Som sintético curto: não depende de um arquivo de áudio externo no ZIP.
	var sample_rate := 22050
	var sample_count := int(sample_rate * 2.2)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var envelope := (1.0 - exp(-t * 55.0)) * exp(-t * 2.0)
		var rumble := sin(TAU * (38.0 * t + 1.8 * t * t)) * 0.42 + sin(TAU * 61.0 * t) * 0.18 + sin(TAU * 23.0 * t) * 0.17
		var noise := randf_range(-1.0, 1.0)
		var crack := noise * exp(-t * 23.0) * 0.45
		var sample := clampf((rumble * envelope) + (noise * 0.22 * envelope) + crack, -1.0, 1.0)
		var value := int(sample * 32767.0)
		pcm[i * 2] = value & 0xff
		pcm[i * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream


func _update_weather(delta: float) -> void:
	if rain_particles == null:
		return
	_weather_clock += maxf(delta, 0.0)
	var player_position := Vector3.ZERO
	if game != null and game.player != null and is_instance_valid(game.player):
		player_position = game.player.global_position

	# Inicializa um mapa de clima para todo o terreno, com uma borda extra para a interpolação.
	# As células continuam independentes, mesmo quando o jogador está longe delas.
	_ensure_weather_world_grid()
	_ensure_weather_neighborhood(player_position)
	if not _initial_weather_applied:
		# A opção inicial vale somente para a região de partida, nunca para o mapa inteiro.
		var start_cell := _weather_cell_for_position(player_position)
		var start_state: Dictionary = _ensure_weather_region(start_cell)
		_upgrade_weather_region_state(start_cell, start_state)
		var initial_weather := clampi(starting_weather, Weather.CLEAR, Weather.SNOWSTORM)
		initial_weather = _adapt_weather_to_climate(initial_weather, bool(start_state.get("cold", false)))
		start_state["weather"] = initial_weather
		start_state["weather_override"] = starting_weather >= Weather.SNOW
		var initial_targets := _weather_target_levels(initial_weather)
		var initial_snow_targets := _weather_target_snow_levels(initial_weather)
		start_state["overcast"] = initial_targets.x
		start_state["rain"] = initial_targets.y
		start_state["storm"] = initial_targets.z
		start_state["snow"] = initial_snow_targets.x
		start_state["snowstorm"] = initial_snow_targets.y
		start_state["timer"] = _weather_rng.randf_range(weather_change_min_seconds, maxf(weather_change_min_seconds, weather_change_max_seconds))
		_weather_regions[start_cell] = start_state
		_initial_weather_applied = true

	# Estados distantes continuam evoluindo enquanto a região já foi descoberta;
	# ao voltar, chuva e umidade não reiniciam do zero. A normalização das chaves é
	# feita uma vez ao carregar a campanha, não a cada frame.
	for key in _weather_regions.keys():
		var region_key: Vector2i = key
		var region_state: Dictionary = _weather_regions[region_key]
		_advance_weather_region(region_key, region_state, delta)
		_weather_regions[region_key] = region_state

	var local_weather := _sample_weather_at_position(player_position, true)
	overcast_amount = float(local_weather.get("overcast", 0.0))
	rain_amount = float(local_weather.get("rain", 0.0))
	storm_amount = float(local_weather.get("storm", 0.0))
	snow_amount = float(local_weather.get("snow", 0.0))
	var sampled_snowstorm := float(local_weather.get("snowstorm", 0.0))
	local_coldness = float(local_weather.get("cold", 0.0))
	# A transição de temperatura entre células não deve desenhar chuva e neve juntas.
	# No lado frio, qualquer precipitação residual da interpolação vira neve; no lado
	# temperado, o inverso ocorre para impedir flocos fora das zonas frias.
	var local_weather_override := float(local_weather.get("weather_override", 0.0)) >= 0.5
	if not local_weather_override:
		if local_coldness >= 0.5:
			snow_amount = maxf(snow_amount, rain_amount)
			sampled_snowstorm = maxf(sampled_snowstorm, storm_amount)
			rain_amount = 0.0
			storm_amount = 0.0
		else:
			# No lado temperado, a neve das células frias vizinhas não vira chuva;
			# cada tipo de precipitação deixa de aparecer ao cruzar a fronteira térmica.
			snow_amount = 0.0
			sampled_snowstorm = 0.0
	wetness = float(local_weather.get("wetness", 0.0))
	puddle_level = float(local_weather.get("puddles", 0.0))
	current_weather = _weather_id_from_sample(local_weather)
	rain_level = rain_amount * _smooth_range(0.14, 0.62, overcast_amount)
	storm_level = storm_amount * _smooth_range(0.30, 0.80, overcast_amount)
	snow_level = snow_amount * _smooth_range(0.12, 0.58, overcast_amount)
	snowstorm_level = sampled_snowstorm * _smooth_range(0.24, 0.72, overcast_amount)
	# Intensidades residuais podem demorar alguns segundos para convergir depois
	# de uma mudança de estado. Elas não devem deixar cair precipitação quando o
	# clima amostrado já é limpo ou apenas nublado. A cobertura acumulada no solo
	# é independente e permanece visível durante o derretimento gradual.
	if current_weather not in [Weather.RAIN, Weather.STORM]:
		rain_level = 0.0
	if current_weather != Weather.STORM:
		storm_level = 0.0
	if current_weather not in [Weather.SNOW, Weather.SNOWSTORM]:
		snow_level = 0.0
	if current_weather != Weather.SNOWSTORM:
		snowstorm_level = 0.0

	# Atmosfera e luz são recalculadas sobre a base do ciclo diurno, nunca acumuladas.
	if cloud_material != null:
		var threshold := clampf(cloud_coverage - overcast_amount * 0.24, 0.16, 0.85)
		cloud_material.set_shader_parameter("coverage", threshold)
		cloud_material.set_shader_parameter("cloud_strength", (0.42 + overcast_amount * 0.42) if clouds_enabled else 0.0)
		var sun_altitude_for_tint := sin((time_of_day_hours - 6.0) * TAU / 24.0) * sin(deg_to_rad(70.0))
		var night_tint := Color(0.13, 0.17, 0.27)
		var clear_tint := Color(0.82, 0.84, 0.87)
		var gray_tint := Color(0.34, 0.37, 0.42)
		var tint := night_tint.lerp(clear_tint, _smooth_range(-0.12, 0.35, sun_altitude_for_tint))
		tint = tint.lerp(gray_tint, overcast_amount * 0.82)
		var cold_cloud_tint := Color(0.60, 0.69, 0.80)
		tint = tint.lerp(cold_cloud_tint, clampf(local_coldness * 0.30 + snow_level * 0.34, 0.0, 0.62))
		cloud_material.set_shader_parameter("cloud_tint", Vector3(tint.r, tint.g, tint.b))
		cloud_material.set_shader_parameter("cloud_time", cloud_time)

	if environment != null:
		var precipitation_haze := maxf(rain_level * 0.32, snow_level * 0.40 + snowstorm_level * 0.42)
		var weather_haze := clampf(overcast_amount * 0.62 + precipitation_haze, 0.0, 1.0)
		environment.ambient_light_energy *= lerpf(1.0, 0.78, overcast_amount)
		var haze_begin := lerpf(80.0, 24.0, maxf(rain_level * 0.72, snow_level * 0.64))
		var blizzard_begin := lerpf(haze_begin, 12.0, snowstorm_level)
		environment.fog_depth_begin = blizzard_begin
		var ordinary_fog_end := lerpf(720.0, 380.0, weather_haze)
		environment.fog_depth_end = lerpf(ordinary_fog_end, 145.0, snowstorm_level)
		environment.fog_density = lerpf(0.28, 0.38, weather_haze) + snowstorm_level * 0.10
		var fog_base: Color = sky_material.sky_horizon_color if sky_material != null else Color(0.34, 0.38, 0.45)
		var snowy_fog := Color(0.66, 0.73, 0.82)
		environment.fog_light_color = fog_base.lerp(snowy_fog, clampf(local_coldness * 0.28 + snow_level * 0.32, 0.0, 0.60))
	if sky_material != null and overcast_amount > 0.001:
		var gray_top := Color(0.28, 0.31, 0.36)
		var gray_horizon := Color(0.43, 0.46, 0.49)
		sky_material.sky_top_color = sky_material.sky_top_color.lerp(gray_top, overcast_amount * 0.66)
		sky_material.sky_horizon_color = sky_material.sky_horizon_color.lerp(gray_horizon, overcast_amount * 0.68)
		sky_material.ground_horizon_color = sky_material.ground_horizon_color.lerp(gray_horizon, overcast_amount * 0.60)
	if sun != null:
		sun.light_energy *= lerpf(1.0, 0.50, overcast_amount)
	if moon != null:
		moon.light_energy *= lerpf(1.0, 0.42, overcast_amount)

	# Partículas de chuva acompanham a câmera e respeitam telhados/abrigos reais.
	# A consulta de teto é limitada a ~4 por segundo para não pesar no PC do jogador.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var particle_origin := camera.global_position + Vector3(0.0, 9.0, 0.0)
		rain_particles.global_position = particle_origin
		if snow_particles != null:
			snow_particles.global_position = particle_origin
	_shelter_check_timer -= maxf(delta, 0.0)
	if _shelter_check_timer <= 0.0:
		_shelter_check_timer = SHELTER_CHECK_INTERVAL
		_player_is_sheltered = _player_is_under_structure(player_position)
	rain_particles.emitting = rain_level > 0.025 and not _player_is_sheltered
	rain_particles.direction = Vector3(0.08 + storm_level * 0.42, -1.0, 0.04 + storm_level * 0.18)
	rain_particles.initial_velocity_min = 17.0 + storm_level * 4.0
	rain_particles.initial_velocity_max = 22.0 + storm_level * 6.0
	if snow_particles != null:
		snow_particles.emitting = snow_level > 0.025 and not _player_is_sheltered
		# A nevasca aumenta o vento lateral e a velocidade, sem trocar flocos por gotas.
		snow_particles.direction = Vector3(0.12 + snowstorm_level * 0.82, -1.0, 0.05 + snowstorm_level * 0.28).normalized()
		snow_particles.spread = lerpf(20.0, 42.0, snowstorm_level)
		snow_particles.initial_velocity_min = 0.8 + snowstorm_level * 2.2
		snow_particles.initial_velocity_max = 2.6 + snowstorm_level * 5.0
		snow_particles.gravity = Vector3(0.0, -0.38 - snowstorm_level * 0.42, 0.0)

	_update_wet_overlay_visibility()
	_weather_field_refresh_timer -= maxf(delta, 0.0)
	if _weather_field_texture == null or _weather_field_refresh_timer <= 0.0:
		_refresh_weather_field_texture()
		_weather_field_refresh_timer = WEATHER_FIELD_REFRESH_SECONDS
	_update_lightning(delta, camera)


func _weather_cell_for_position(pos: Vector3) -> Vector2i:
	var size := maxf(weather_region_size, 240.0)
	return Vector2i(floori(pos.x / size), floori(pos.z / size))


func _ensure_weather_world_grid() -> void:
	if _weather_world_grid_initialized or map_bounds.size.x <= 0.0 or map_bounds.size.z <= 0.0:
		return
	var size := maxf(weather_region_size, 240.0)
	var min_x := floori(map_bounds.position.x / size) - 1
	var max_x := floori(map_bounds.end.x / size) + 1
	var min_z := floori(map_bounds.position.z / size) - 1
	var max_z := floori(map_bounds.end.z / size) + 1
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			_ensure_weather_region(Vector2i(x, z))
	_weather_world_grid_initialized = true


func _ensure_weather_neighborhood(pos: Vector3) -> void:
	var center := _weather_cell_for_position(pos)
	for z in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			_ensure_weather_region(Vector2i(x, z))


func _region_center(cell: Vector2i) -> Vector3:
	var size := maxf(weather_region_size, 240.0)
	return Vector3((float(cell.x) + 0.5) * size, 0.0, (float(cell.y) + 0.5) * size)


func _estimate_region_elevation(cell: Vector2i) -> float:
	# Sample a point inside the current terrain even for edge cells whose centers
	# fall just outside the model bounds. The submitted overworld keeps OW_Terrain-colonly
	# as the authoritative collision surface.
	if map_bounds.size.x <= 2.0 or map_bounds.size.z <= 2.0:
		return 0.0
	var center := _region_center(cell)
	center.x = clampf(center.x, map_bounds.position.x + 1.0, map_bounds.end.x - 1.0)
	center.z = clampf(center.z, map_bounds.position.z + 1.0, map_bounds.end.z - 1.0)
	var ray_from := Vector3(center.x, map_bounds.end.y + 200.0, center.z)
	var ray_to := Vector3(center.x, map_bounds.position.y - 100.0, center.z)
	var space_state := get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	for _attempt in range(24):
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.exclude = excluded
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider_value: Variant = hit.get("collider")
		var current_node: Node = null
		if collider_value is Node:
			current_node = collider_value
		var is_terrain := false
		while current_node != null:
			var node_name := str(current_node.name).to_lower()
			if node_name.contains("terrain-colonly") or node_name == "ow_terrain":
				is_terrain = true
				break
			current_node = current_node.get_parent()
		if is_terrain:
			var hit_position: Vector3 = hit.get("position", center)
			return hit_position.y
		if hit.has("rid"):
			var hit_rid: RID = hit["rid"]
			if hit_rid.is_valid():
				excluded.append(hit_rid)
			else:
				break
		else:
			break
	# Neutral fallback: the AABB midpoint is below the mountain thresholds, so a
	# missing collision sample does not make an entire region permanently stormy.
	return clampf(map_bounds.get_center().y, map_bounds.position.y, map_bounds.end.y)


func _weather_target_levels(weather_id: int) -> Vector3:
	# Componentes: cobertura de nuvens, chuva, tempestade elétrica.
	match weather_id:
		Weather.CLEAR:
			return Vector3(0.0, 0.0, 0.0)
		Weather.CLOUDY:
			return Vector3(0.78, 0.0, 0.0)
		Weather.RAIN:
			return Vector3(0.90, 0.68, 0.0)
		Weather.STORM:
			return Vector3(1.0, 1.0, 1.0)
		Weather.SNOW:
			return Vector3(0.90, 0.0, 0.0)
		Weather.SNOWSTORM:
			return Vector3(1.0, 0.0, 0.0)
	return Vector3.ZERO


func _weather_target_snow_levels(weather_id: int) -> Vector2:
	# Componentes: precipitação sólida, intensidade de vento/nevasca.
	match weather_id:
		Weather.SNOW:
			return Vector2(0.62, 0.0)
		Weather.SNOWSTORM:
			return Vector2(0.96, 0.92)
	return Vector2.ZERO


func _is_cold_climate_region(cell: Vector2i, elevation: float, temperature_noise: float) -> bool:
	var center := _region_center(cell)
	# A povoação de Lobofrio ancora uma zona tradicionalmente fria.
	# O ID estável evita que a regra dependa do nome localizado exibido no mapa.
	var cold_radius := maxf(weather_region_size * 1.65, 700.0)
	var cold_radius_squared := cold_radius * cold_radius
	for settlement_value in settlement_points:
		if not (settlement_value is Dictionary):
			continue
		var settlement: Dictionary = settlement_value
		if str(settlement.get("id", "")) != "settlement_06":
			continue
		var settlement_pos_value: Variant = settlement.get("pos", Vector3.ZERO)
		if settlement_pos_value is Vector3:
			var settlement_pos: Vector3 = settlement_pos_value
			var d := Vector2(center.x - settlement_pos.x, center.z - settlement_pos.z).length_squared()
			if d <= cold_radius_squared:
				return true
	# Altitude is the primary cause of cold zones; the independent temperature
	# noise also creates colder pockets on foothills and higher valleys.
	if elevation >= 68.0:
		return true
	if elevation >= 43.0 and temperature_noise < 0.28:
		return true
	if elevation >= 32.0 and temperature_noise < -0.78:
		return true
	return false


func _adapt_weather_to_climate(weather_id: int, is_cold: bool) -> int:
	if is_cold:
		if weather_id == Weather.RAIN:
			return Weather.SNOW
		if weather_id == Weather.STORM:
			return Weather.SNOWSTORM
	return weather_id


func _ensure_weather_region(cell: Vector2i) -> Dictionary:
	if _weather_regions.has(cell):
		return _weather_regions[cell]

	var elevation := _estimate_region_elevation(cell)
	var center := _region_center(cell)
	var climate_value: float = _weather_noise.get_noise_2d(center.x, center.z) if _weather_noise != null else _weather_rng.randf_range(-1.0, 1.0)
	var temperature_noise: float = _weather_noise.get_noise_2d(center.x + 9137.0, center.z - 4271.0) if _weather_noise != null else _weather_rng.randf_range(-1.0, 1.0)
	var cold_region := _is_cold_climate_region(cell, elevation, temperature_noise)
	# Montanhas favorecem a precipitação, mas a temperatura decide sua forma.
	if elevation > 90.0:
		climate_value += 0.12
	elif elevation > 55.0:
		climate_value += 0.05
	var initial_weather := Weather.CLEAR
	if climate_value < -0.36:
		initial_weather = Weather.CLEAR
	elif climate_value < 0.18:
		initial_weather = Weather.CLOUDY
	elif climate_value < 0.74:
		initial_weather = Weather.SNOW if cold_region else Weather.RAIN
	else:
		initial_weather = Weather.SNOWSTORM if cold_region else Weather.STORM
	var levels := _weather_target_levels(initial_weather)
	var snow_levels := _weather_target_snow_levels(initial_weather)
	var state: Dictionary = {
		"weather": initial_weather,
		"timer": _weather_rng.randf_range(weather_change_min_seconds, maxf(weather_change_min_seconds, weather_change_max_seconds)),
		"overcast": levels.x,
		"rain": levels.y,
		"storm": levels.z,
		"snow": snow_levels.x,
		"snowstorm": snow_levels.y,
		"cold": cold_region,
		"weather_override": false,
		"temperature_noise": temperature_noise,
		"wetness": 0.0,
		"puddles": 0.0,
		"snow_cover": 0.0,
		"elevation": elevation
	}
	_weather_regions[cell] = state
	return state


func _upgrade_weather_region_state(cell: Vector2i, state: Dictionary) -> void:
	# Adiciona o acúmulo de neve aos estados de versões anteriores sem apagar o
	# nível que já foi acumulado nesta sessão.
	state["snow_cover"] = clampf(float(state.get("snow_cover", 0.0)), 0.0, 1.0)
	# Converte estados salvos por versões antigas, que só conheciam chuva e tempestade.
	if state.has("cold") and state.has("snow") and state.has("snowstorm") and state.has("weather_override"):
		return
	var elevation := float(state.get("elevation", _estimate_region_elevation(cell)))
	var center := _region_center(cell)
	var temperature_noise := float(state.get("temperature_noise", _weather_noise.get_noise_2d(center.x + 9137.0, center.z - 4271.0) if _weather_noise != null else 0.0))
	var cold_region := _is_cold_climate_region(cell, elevation, temperature_noise)
	var old_weather := int(state.get("weather", Weather.CLEAR))
	old_weather = _adapt_weather_to_climate(old_weather, cold_region)
	state["cold"] = cold_region
	state["temperature_noise"] = temperature_noise
	state["weather_override"] = bool(state.get("weather_override", false))
	state["weather"] = old_weather
	var targets := _weather_target_levels(old_weather)
	var snow_targets := _weather_target_snow_levels(old_weather)
	state["overcast"] = float(state.get("overcast", targets.x))
	# Não deixe chuva nem relâmpagos ativos quando uma região salva passa a ser fria.
	state["rain"] = targets.y
	state["storm"] = targets.z
	state["snow"] = snow_targets.x
	state["snowstorm"] = snow_targets.y
	state["elevation"] = elevation


func _advance_weather_region(cell: Vector2i, state: Dictionary, delta: float) -> void:
	_upgrade_weather_region_state(cell, state)
	if automatic_weather:
		var timer := float(state.get("timer", 0.0)) - delta
		if timer <= 0.0:
			var old_weather := int(state.get("weather", Weather.CLEAR))
			state["weather"] = _choose_weather_for_region(cell, old_weather, bool(state.get("cold", false)))
			timer = _weather_rng.randf_range(weather_change_min_seconds, maxf(weather_change_min_seconds, weather_change_max_seconds))
		state["timer"] = timer

	var weather_id := int(state.get("weather", Weather.CLEAR))
	var targets := _weather_target_levels(weather_id)
	var snow_targets := _weather_target_snow_levels(weather_id)
	var transition := maxf(delta, 0.0) / 28.0
	state["overcast"] = move_toward(float(state.get("overcast", targets.x)), targets.x, transition)
	state["rain"] = move_toward(float(state.get("rain", targets.y)), targets.y, transition)
	state["storm"] = move_toward(float(state.get("storm", targets.z)), targets.z, transition)
	state["snow"] = move_toward(float(state.get("snow", snow_targets.x)), snow_targets.x, transition)
	state["snowstorm"] = move_toward(float(state.get("snowstorm", snow_targets.y)), snow_targets.y, transition)
	var regional_rain := float(state.get("rain", 0.0))
	var regional_snow := float(state.get("snow", 0.0))
	var regional_snowstorm := float(state.get("snowstorm", 0.0))
	var regional_overcast := float(state.get("overcast", 0.0))
	var snow_cover := clampf(float(state.get("snow_cover", 0.0)), 0.0, 1.0)
	var snow_precipitation := maxf(regional_snow, regional_snowstorm * 0.92)
	var daylight_sun := maxf(0.0, sin((time_of_day_hours - 6.0) * PI / 12.0))
	if snow_precipitation > 0.035:
		# A neve se acumula lentamente; a nevasca deposita uma camada mais depressa.
		var accumulation_rate := 0.0042 + regional_snowstorm * 0.0040
		snow_cover = clampf(snow_cover + maxf(delta, 0.0) * accumulation_rate * snow_precipitation, 0.0, 1.0)
	else:
		# Depois que a precipitação para, a camada permanece por um tempo. Sol e
		# temperaturas mais amenas aceleram o derretimento; zonas frias a conservam.
		var cold_region := bool(state.get("cold", false))
		var melt_rate: float
		if cold_region:
			melt_rate = 0.0008 + daylight_sun * (1.0 - regional_overcast * 0.70) * 0.0017
		else:
			melt_rate = 0.0022 + daylight_sun * (1.0 - regional_overcast * 0.55) * 0.0040
		if not cold_region and regional_rain > 0.04:
			melt_rate += regional_rain * 0.0025
		snow_cover = maxf(0.0, snow_cover - maxf(delta, 0.0) * melt_rate)
	state["snow_cover"] = snow_cover
	if regional_rain > 0.035:
		state["wetness"] = move_toward(float(state.get("wetness", 0.0)), clampf(0.48 + regional_rain * 0.52, 0.0, 1.0), maxf(delta, 0.0) / 22.0)
		state["puddles"] = move_toward(float(state.get("puddles", 0.0)), regional_rain * 0.8, maxf(delta, 0.0) / 34.0)
	else:
		# Neve não gera poças nem ativa o revestimento de solo molhado.
		var snow_melt_factor := 0.22 if bool(state.get("cold", false)) else 1.0
		var target_wetness := 0.0
		var sun_height := maxf(0.0, sin((time_of_day_hours - 6.0) * PI / 12.0))
		var drying_speed := (1.0 + sun_height * (1.0 - regional_overcast) * 1.5) * snow_melt_factor
		state["wetness"] = move_toward(float(state.get("wetness", 0.0)), target_wetness, maxf(delta, 0.0) / 105.0 * drying_speed)
		state["puddles"] = move_toward(float(state.get("puddles", 0.0)), 0.0, maxf(delta, 0.0) / 155.0 * drying_speed)


func _choose_weather_for_region(cell: Vector2i, previous: int, cold_region: bool = false) -> int:
	# As frentes evoluem em etapas: céu limpo -> nublado -> precipitação -> abrandamento.
	var weather_ids: Array[int]
	var weights: Array[float]
	if cold_region:
		weather_ids = [Weather.CLEAR, Weather.CLOUDY, Weather.SNOW, Weather.SNOWSTORM]
		match previous:
			Weather.CLEAR:
				weights = [0.55, 0.33, 0.11, 0.01]
			Weather.CLOUDY:
				weights = [0.25, 0.44, 0.26, 0.05]
			Weather.SNOW, Weather.RAIN:
				weights = [0.14, 0.31, 0.46, 0.09]
			Weather.SNOWSTORM, Weather.STORM:
				weights = [0.10, 0.30, 0.40, 0.20]
			_:
				weights = [0.48, 0.34, 0.16, 0.02]
	else:
		weather_ids = [Weather.CLEAR, Weather.CLOUDY, Weather.RAIN, Weather.STORM]
		match previous:
			Weather.CLEAR:
				weights = [0.55, 0.32, 0.12, 0.01]
			Weather.CLOUDY:
				weights = [0.28, 0.42, 0.26, 0.04]
			Weather.RAIN, Weather.SNOW:
				weights = [0.18, 0.32, 0.40, 0.10]
			Weather.STORM, Weather.SNOWSTORM:
				weights = [0.12, 0.30, 0.43, 0.15]
			_:
				weights = [0.48, 0.34, 0.15, 0.03]

	var known_neighbors := 0
	var wet_neighbors := 0
	var clear_neighbors := 0
	var neighbor_offsets: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for offset in neighbor_offsets:
		var neighbor_key: Vector2i = cell + offset
		if not _weather_regions.has(neighbor_key):
			continue
		known_neighbors += 1
		var neighbor_state: Dictionary = _weather_regions[neighbor_key]
		var neighbor_weather := int(neighbor_state.get("weather", Weather.CLEAR))
		if neighbor_weather in [Weather.RAIN, Weather.STORM, Weather.SNOW, Weather.SNOWSTORM]:
			wet_neighbors += 1
		elif neighbor_weather == Weather.CLEAR:
			clear_neighbors += 1
	if known_neighbors > 0:
		if float(wet_neighbors) / float(known_neighbors) >= 0.5:
			weights[0] *= 0.72
			weights[1] *= 1.10
			weights[2] *= 1.32
			weights[3] *= 1.18
		elif float(clear_neighbors) / float(known_neighbors) >= 0.5:
			weights[0] *= 1.20
			weights[1] *= 1.08
			weights[3] *= 0.78
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := _weather_rng.randf() * total
	for i in range(weights.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return weather_ids[i]
	return Weather.CLEAR


func _sample_weather_at_position(pos: Vector3, create_missing: bool = true) -> Dictionary:
	var size := maxf(weather_region_size, 240.0)
	# Bilinear interpolation between four regional cell centres removes hard weather borders.
	var gx := pos.x / size - 0.5
	var gz := pos.z / size - 0.5
	var x0 := floori(gx)
	var z0 := floori(gz)
	var fx := clampf(gx - float(x0), 0.0, 1.0)
	var fz := clampf(gz - float(z0), 0.0, 1.0)
	var cells: Array[Vector2i] = [Vector2i(x0, z0), Vector2i(x0 + 1, z0), Vector2i(x0, z0 + 1), Vector2i(x0 + 1, z0 + 1)]
	var weights: Array[float] = [(1.0 - fx) * (1.0 - fz), fx * (1.0 - fz), (1.0 - fx) * fz, fx * fz]
	var result := {"overcast": 0.0, "rain": 0.0, "storm": 0.0, "snow": 0.0, "snowstorm": 0.0, "cold": 0.0, "weather_override": 0.0, "wetness": 0.0, "puddles": 0.0, "snow_cover": 0.0}
	for i in range(cells.size()):
		var key: Vector2i = cells[i]
		var state: Dictionary = {}
		if _weather_regions.has(key):
			state = _weather_regions[key]
		elif create_missing:
			state = _ensure_weather_region(key)
		if state.is_empty():
			continue
		var weight := weights[i]
		for property in ["overcast", "rain", "storm", "snow", "snowstorm", "wetness", "puddles", "snow_cover"]:
			result[property] = float(result[property]) + float(state.get(property, 0.0)) * weight
		result["cold"] = float(result["cold"]) + (1.0 if bool(state.get("cold", false)) else 0.0) * weight
		result["weather_override"] = float(result["weather_override"]) + (1.0 if bool(state.get("weather_override", false)) else 0.0) * weight
	return result


func _weather_id_from_sample(sample: Dictionary) -> int:
	var weather_override := float(sample.get("weather_override", 0.0)) >= 0.5
	var cold_sample := float(sample.get("cold", 0.0)) >= 0.5
	if weather_override:
		if float(sample.get("snowstorm", 0.0)) >= 0.48:
			return Weather.SNOWSTORM
		if float(sample.get("snow", 0.0)) >= 0.28:
			return Weather.SNOW
		if float(sample.get("storm", 0.0)) >= 0.48:
			return Weather.STORM
		if float(sample.get("rain", 0.0)) >= 0.28:
			return Weather.RAIN
	if cold_sample:
		if float(sample.get("snowstorm", 0.0)) >= 0.48 or float(sample.get("storm", 0.0)) >= 0.48:
			return Weather.SNOWSTORM
		if float(sample.get("snow", 0.0)) >= 0.28 or float(sample.get("rain", 0.0)) >= 0.28:
			return Weather.SNOW
	else:
		if float(sample.get("storm", 0.0)) >= 0.48:
			return Weather.STORM
		if float(sample.get("rain", 0.0)) >= 0.28:
			return Weather.RAIN
	if float(sample.get("overcast", 0.0)) >= 0.48:
		return Weather.CLOUDY
	return Weather.CLEAR


func get_weather_at_position(pos: Vector3) -> int:
	return _weather_id_from_sample(_sample_weather_at_position(pos, true))


func get_weather_intensity_at_position(pos: Vector3) -> float:
	var sample := _sample_weather_at_position(pos, true)
	var cold_sample := float(sample.get("cold", 0.0)) >= 0.5
	var override_sample := float(sample.get("weather_override", 0.0)) >= 0.5
	if cold_sample or (override_sample and float(sample.get("snow", 0.0)) > float(sample.get("rain", 0.0))):
		return clampf(float(sample.get("snow", 0.0)) + float(sample.get("snowstorm", 0.0)) * 0.25, 0.0, 1.0)
	return clampf(float(sample.get("rain", 0.0)) + float(sample.get("storm", 0.0)) * 0.25, 0.0, 1.0)


func _force_weather_for_player(weather_id: int) -> void:
	if game == null or game.player == null:
		return
	automatic_weather = false
	var player_position: Vector3 = game.player.global_position
	var center_cell := _weather_cell_for_position(player_position)
	var requested_weather := clampi(weather_id, Weather.CLEAR, Weather.SNOWSTORM)
	# A amostragem climática interpola entre os centros de quatro células. Forçar
	# só a célula ocupada deixa as vizinhas vazarem neve sob o céu limpo. Aplicamos
	# o override numa pequena vizinhança de 3x3 para o teste continuar coerente
	# enquanto o jogador se move dentro da região.
	for z in range(center_cell.y - 1, center_cell.y + 2):
		for x in range(center_cell.x - 1, center_cell.x + 2):
			var cell := Vector2i(x, z)
			var state: Dictionary = _ensure_weather_region(cell)
			_upgrade_weather_region_state(cell, state)
			var cell_weather := requested_weather
			# Testes de chuva/tempestade respeitam a temperatura local; KP_5/KP_6 ainda
			# podem forçar neve explicitamente em regiões quentes.
			if bool(state.get("cold", false)):
				cell_weather = _adapt_weather_to_climate(cell_weather, true)
			var targets := _weather_target_levels(cell_weather)
			var snow_targets := _weather_target_snow_levels(cell_weather)
			state["weather"] = cell_weather
			state["weather_override"] = true
			state["timer"] = 999999.0
			# Comandos de depuração aplicam o estado imediatamente. Snow_cover não é
			# zerado: a camada acumulada no chão continua derretendo normalmente.
			state["overcast"] = targets.x
			state["rain"] = targets.y
			state["storm"] = targets.z
			state["snow"] = snow_targets.x
			state["snowstorm"] = snow_targets.y
			_weather_regions[cell] = state


func _update_wet_overlay_visibility() -> void:
	var should_show := false
	for state_value in _weather_regions.values():
		var state: Dictionary = state_value
		if float(state.get("wetness", 0.0)) > 0.008 or float(state.get("puddles", 0.0)) > 0.008 or float(state.get("snow_cover", 0.0)) > 0.008:
			should_show = true
			break
	if should_show == wet_overlay_enabled:
		return
	wet_overlay_enabled = should_show
	for mesh in wet_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = wet_material if should_show else null


func _refresh_weather_field_texture() -> void:
	if wet_material == null or map_bounds.size.x <= 0.0 or map_bounds.size.z <= 0.0:
		return
	if _weather_field_image == null:
		_weather_field_image = Image.create(WEATHER_FIELD_RESOLUTION, WEATHER_FIELD_RESOLUTION, false, Image.FORMAT_RGBA8)
		_weather_field_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	if _weather_field_texture == null:
		_weather_field_texture = ImageTexture.create_from_image(_weather_field_image)
		wet_material.set_shader_parameter("weather_field", _weather_field_texture)
	wet_material.set_shader_parameter("weather_origin", Vector2(map_bounds.position.x, map_bounds.position.z))
	wet_material.set_shader_parameter("weather_size", Vector2(map_bounds.size.x, map_bounds.size.z))
	for y in range(WEATHER_FIELD_RESOLUTION):
		for x in range(WEATHER_FIELD_RESOLUTION):
			var world_x := map_bounds.position.x + (float(x) + 0.5) / float(WEATHER_FIELD_RESOLUTION) * map_bounds.size.x
			var world_z := map_bounds.position.z + (float(y) + 0.5) / float(WEATHER_FIELD_RESOLUTION) * map_bounds.size.z
			var sample := _sample_weather_at_position(Vector3(world_x, 0.0, world_z), false)
			_weather_field_image.set_pixel(x, y, Color(float(sample.get("wetness", 0.0)), float(sample.get("puddles", 0.0)), float(sample.get("snow_cover", 0.0)), 1.0))
	_weather_field_texture.update(_weather_field_image)
	if game != null:
		game.weather_region_session_state = _weather_regions.duplicate(true)


func _update_lightning(delta: float, camera: Camera3D) -> void:
	lightning_flash = move_toward(lightning_flash, 0.0, delta * 5.0)
	if second_flash_timer >= 0.0:
		second_flash_timer -= delta
		if second_flash_timer < 0.0:
			lightning_flash = maxf(lightning_flash, 0.72)
	if lightning_timer > 0.0:
		lightning_timer -= delta
	if storm_level > 0.45 and lightning_timer <= 0.0:
		_trigger_lightning(camera)
	if lightning_light != null:
		lightning_light.light_energy = lightning_flash * 2.4
	if environment != null and lightning_flash > 0.0:
		environment.ambient_light_energy += lightning_flash * 0.65
	if sky_material != null and lightning_flash > 0.02:
		sky_material.sky_top_color = sky_material.sky_top_color.lerp(Color(0.72, 0.80, 0.96), lightning_flash * 0.45)
	if lightning_bolt != null and lightning_bolt.visible and lightning_flash < 0.035 and second_flash_timer < 0.0:
		lightning_bolt.visible = false


func _trigger_lightning(camera: Camera3D) -> void:
	lightning_flash = 1.0
	lightning_timer = rng.randf_range(5.0, 12.0) / maxf(storm_level, 0.35)
	second_flash_timer = rng.randf_range(0.09, 0.18) if rng.randf() < 0.28 else -1.0
	if camera != null:
		_draw_lightning_bolt(camera)
	_play_delayed_thunder(rng.randf_range(0.25, 1.15))


func _draw_lightning_bolt(camera: Camera3D) -> void:
	if lightning_bolt_mesh == null or lightning_bolt == null:
		return
	lightning_bolt_mesh.clear_surfaces()
	lightning_bolt_mesh.surface_begin(Mesh.PRIMITIVE_LINES, lightning_bolt_material)
	var points: Array[Vector3] = [Vector3.ZERO]
	var point := Vector3.ZERO
	for i in range(1, 8):
		point += Vector3(rng.randf_range(-2.2, 2.2), -4.0, rng.randf_range(-1.4, 1.4))
		points.append(point)
	for i in range(points.size() - 1):
		lightning_bolt_mesh.surface_add_vertex(points[i])
		lightning_bolt_mesh.surface_add_vertex(points[i + 1])
	# Um pequeno ramo lateral torna o raio menos geométrico.
	lightning_bolt_mesh.surface_add_vertex(points[3])
	lightning_bolt_mesh.surface_add_vertex(points[3] + Vector3(-4.0, -3.0, 1.2))
	lightning_bolt_mesh.surface_end()
	lightning_bolt.global_position = camera.global_position + Vector3(rng.randf_range(-27.0, 27.0), 28.0, rng.randf_range(-24.0, 24.0))
	lightning_bolt.visible = true


func _play_delayed_thunder(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or thunder_stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "Trovão"
	player.stream = thunder_stream
	player.volume_db = rng.randf_range(-8.0, -3.0)
	player.pitch_scale = rng.randf_range(0.88, 1.04)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _make_prompt() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_prompt = Label.new()
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -220.0
	_prompt.offset_right = 220.0
	_prompt.offset_top = -170.0
	_prompt.offset_bottom = -130.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	layer.add_child(_prompt)
	_aim_reticle = Label.new()
	_aim_reticle.name = "InteractionReticle"
	_aim_reticle.text = "+"
	_aim_reticle.anchor_left = 0.5
	_aim_reticle.anchor_right = 0.5
	_aim_reticle.anchor_top = 0.5
	_aim_reticle.anchor_bottom = 0.5
	_aim_reticle.offset_left = -8.0
	_aim_reticle.offset_right = 8.0
	_aim_reticle.offset_top = -12.0
	_aim_reticle.offset_bottom = 12.0
	_aim_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aim_reticle.add_theme_font_size_override("font_size", 14)
	_aim_reticle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	_aim_reticle.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))
	_aim_reticle.add_theme_constant_override("outline_size", 3)
	layer.add_child(_aim_reticle)

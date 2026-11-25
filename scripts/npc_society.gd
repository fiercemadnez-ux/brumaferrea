extends Node

const WORLD_NAMES := preload("res://scripts/world_names.gd")

signal npc_born(profile: Dictionary, spawn_position: Vector3)

# Registro de identidad, ciudades, residencias y lugares de trabajo de los habitantes.
# Los identificadores se derivan de los nombres del mundo Blender, por lo que no
# dependen de la posición que ocupa un nodo dentro de la escena.

const STATE_PATH := "user://npc_society_state.json"
const HOME_ENTRY_MARGIN := 1.15
const ROUTE_CORNER_OFFSET := 2.1
const ROUTE_BLOCK_MARGIN := 0.65
const ROUTE_CORRIDOR_RADIUS := 48.0
const ROUTINE_UPDATE_SECONDS := 1.0
const NPC_SEPARATION_GRID_CELL_SIZE := 5.5
const PERSISTENT_SAVE_INTERVAL := 30.0
const NPC_STREAM_STATE_REFRESH_SECONDS := 0.50
const GUARD_ROSTER_REFRESH_SECONDS := 4.0
const GUARD_SHIFT_LENGTH_HOURS := 8.0
const GUARD_POST_ROTATION_HOURS := 2.0
const GUARD_GATE_OFFSET := 10.0
const CITY_THREAT_MARGIN := 20.0
const CHAT_START_INTERVAL := 2.5
const CHAT_DISTANCE := 5.0
const CHAT_PLAYER_DISTANCE := 34.0
const CHAT_TURN_SECONDS := 2.8
const CHAT_COOLDOWN_SECONDS := 19.0
const CHAT_EVENT_MEMORY_SECONDS := 150.0
const CHAT_EVENT_WITNESS_RADIUS := 28.0
const PERSONALITIES := ["curioso", "desconfiado", "bem-humorado", "reservado", "fofoqueiro", "pratico"]
const SPEECH_STYLES := ["direto", "formal", "ironico", "supersticioso", "observador", "coloquial", "reservado", "pratico", "poetico", "curioso"]
const GENERAL_INTERESTS := ["as histórias antigas da região", "as comidas da taverna", "os costumes locais", "as canções e festas", "os animais dos arredores", "as estradas e os viajantes", "as histórias dos deuses", "as ferramentas e os ofícios", "os preços do mercado", "as famílias da cidade", "as plantas e ervas", "os rumores que chegam de fora"]
const PERSONAL_GOALS := ["juntar moedas suficientes para dias difíceis", "melhorar a vida da minha família", "ser reconhecido pelo meu ofício", "conhecer o que existe além destas estradas", "conseguir um pouco de paz e sossego", "pagar uma dívida antiga", "aprender algo que ainda não sei", "proteger as pessoas em quem confio", "abrir meu próprio negócio", "deixar alguma coisa de valor para o futuro"]

# Nomes gerados a partir de repertório lusófono, com grafia portuguesa e acentos.
# A combinação é determinística por identidade: o nome não muda a cada carregamento.
const MALE_FIRST_NAMES := [
	"Afonso", "Álvaro", "Amaro", "Anselmo", "António", "Baltasar", "Bartolomeu", "Belchior",
	"Bento", "Bernardo", "Brás", "Caetano", "Camilo", "Cândido", "Damião", "Dinis", "Domingos",
	"Duarte", "Edmundo", "Estêvão", "Evaristo", "Fausto", "Feliciano", "Fernão", "Gaspar",
	"Geraldo", "Gil", "Gonçalo", "Heitor", "Henrique", "Honório", "Inácio", "Isidro", "Jaime",
	"Jerónimo", "Joaquim", "Jorge", "Lourenço", "Leandro", "Lázaro", "Martim", "Mateus", "Nuno",
	"Octávio", "Orlando", "Pascoal", "Ramiro", "Raul", "Roque", "Salvador", "Sebastião", "Simão",
	"Teodoro", "Tomé", "Tomás", "Valentim", "Vasco", "Vicente", "Xavier", "Agostinho", "Albano",
	"André", "Aníbal", "Cícero", "Crispim", "Elói", "Ezequiel", "Hilário", "Ivo", "Januário",
	"Leôncio", "Nicolau", "Norberto", "Óscar", "Quirino", "Rui", "Silvestre", "Tadeu", "Artur"
]
const FEMALE_FIRST_NAMES := [
	"Adelaide", "Amália", "Ana", "Antónia", "Beatriz", "Benedita", "Brígida", "Cândida",
	"Carlota", "Catarina", "Cecília", "Clara", "Constança", "Dalila", "Delfina", "Ema", "Emília",
	"Eulália", "Filipa", "Francisca", "Genoveva", "Guiomar", "Helena", "Inês", "Isabel", "Joana",
	"Leonor", "Luzia", "Madalena", "Mafalda", "Margarida", "Maria", "Marília", "Marta", "Matilde",
	"Micaela", "Natália", "Noémia", "Olívia", "Perpétua", "Quitéria", "Rosa", "Rosalina", "Salomé",
	"Teresa", "Úrsula", "Violante", "Vitória", "Alzira", "Amélia", "Branca", "Carmelita", "Conceição",
	"Deolinda", "Ermelinda", "Estela", "Felícia", "Florinda", "Graça", "Jesuína", "Juliana", "Laurinda",
	"Lídia", "Lucinda", "Luísa", "Mariana", "Mónica", "Odete", "Palmira", "Paula", "Serafina", "Sofia",
	"Susana", "Teodora", "Violeta", "Elvira", "Isolda", "Lurdes", "Raquel", "Terenciana"
]
const SURNAMES := [
	"Abreu", "Aguiar", "Albergaria", "Almeida", "Alvarenga", "Alves", "Amaral", "Andrade", "Antunes",
	"Araújo", "Azevedo", "Barata", "Barros", "Bastos", "Batista", "Belmonte", "Belo", "Borges", "Braga",
	"Brandão", "Brito", "Cabral", "Caldeira", "Campos", "Cardoso", "Carmo", "Carvalho", "Castelo", "Castro",
	"Coelho", "Correia", "Coutinho", "Cruz", "Cunha", "Dias", "Domingues", "Esteves", "Faria", "Farias",
	"Fernandes", "Ferreira", "Figueira", "Figueiredo", "Fonseca", "Fontes", "Freire", "Gama", "Garcia", "Gomes",
	"Gonçalves", "Guerreiro", "Henriques", "Leal", "Lemos", "Lima", "Lobo", "Lopes", "Loureiro", "Machado",
	"Madeira", "Magalhães", "Marinho", "Marques", "Martins", "Matos", "Medeiros", "Melo", "Mendes", "Mesquita",
	"Miranda", "Monteiro", "Moraes", "Moreira", "Moura", "Nascimento", "Neves", "Nogueira", "Nunes", "Oliveira",
	"Paiva", "Paredes", "Pacheco", "Passos", "Peixoto", "Pereira", "Pimentel", "Pinto", "Pires", "Queirós",
	"Ramalho", "Ramos", "Reis", "Resende", "Ribeiro", "Rocha", "Rodrigues", "Romão", "Sampaio", "Santana",
	"Saraiva", "Sequeira", "Serpa", "Soares", "Sousa", "Tavares", "Teixeira", "Teles", "Torres", "Valente",
	"Varela", "Vasconcelos", "Ventura", "Vidal", "Vieira", "da Abadia", "da Barreira", "da Costa", "da Fonte",
	"da Lomba", "da Mata", "da Pedra", "da Ponte", "da Rocha", "da Serra", "da Veiga", "das Neves", "de Alencar",
	"de Alvarães", "de Bragança", "de Carvalho", "de Faria", "de Lacerda", "de Lemos", "de Magalhães", "de Matos",
	"de Moura", "de Noronha", "de Paiva", "de Penafiel", "de Queirós", "de Sá", "de Sequeira", "do Carmo",
	"do Mar", "do Monte", "do Prado", "do Vale", "dos Anjos", "dos Reis", "Ferral", "Ferro", "Penedo", "Pedrosa",
	"Vilar", "Brumário", "da Bruma", "da Ferraria", "da Montanha", "das Fontes", "do Penedo", "do Ribeiro"
]

var cities: Dictionary = {}
var houses: Dictionary = {}
var buildings: Dictionary = {}
var _world: Node3D
var reserved_player_home_id := ""
var _previous_records: Dictionary = {}
var _active_records: Dictionary = {}
var _building_regex := RegEx.new()
var _city_regex := RegEx.new()
var _think_timer := 0.0
var _npc_stream_state_timer := 0.0
var _guard_roster_refresh_timer := 0.0
var _cached_guard_rosters: Dictionary = {}
var _guard_rosters_initialized := false
var _regional_threat_refresh_timer := 0.0
var _cached_regional_threats: Dictionary = {}
var _current_npc_nodes: Array = []
var _conversation_think_timer := 0.0
var _conversation_clock := 0.0
var _conversation_event_serial := 0
var _conversation_sessions: Array[Dictionary] = []
var _conversation_cooldowns: Dictionary = {}
var _conversation_event_pairs: Dictionary = {}
var _active_social_interior_id := ""
var _active_social_interior_kind := ""
var _relationships: Dictionary = {}
# Grafo genealógico persistente. As relações sociais continuam em _relationships;
# este registro guarda parentesco biológico, uniões e eventos de vida.
var _genealogy: Dictionary = {}
var _last_lifecycle_day := -1
var _debug_log: Array[String] = []
var _debug_hour := 10.0
var _debug_last_activity: Dictionary = {}
# Relógio monotónico da simulação (em horas de jogo) para viagens entre cidades.
var _world_clock_hours := 0.0
var _last_clock_hour := -1.0
var _persistent_save_timer := 0.0
var _merchant_next_departure_clock: Dictionary = {}
var _messenger_next_departure_clock: Dictionary = {}
# Estado global persistente de entidades únicas e dos postos de correios.
var _world_flags: Dictionary = {}
# Conhecimento derivado diretamente dos marcadores e objetos do mapa.
var _poi_features: Array[Dictionary] = []
var _resource_features: Array[Dictionary] = []
var _has_road_network := false
var _has_river_network := false
var _has_named_terrain := false
const LOCAL_POI_RADIUS := 680.0
const LOCAL_RESOURCE_RADIUS := 460.0
const LOCAL_NEIGHBOR_CITY_RADIUS := 520.0

# Calendário social comprimido: 30 dias do mundo equivalem a um ano de vida.
# O relógio visual continua no seu ciclo normal de 10 minutos por dia.
const FAMILY_HOURS_PER_YEAR := 24.0 * 30.0
const FAMILY_GESTATION_HOURS := FAMILY_HOURS_PER_YEAR * 0.75
const FAMILY_MIN_UNION_HOURS := 24.0 * 6.0
const FAMILY_CONCEPTION_INTERVAL_DAYS := 3
const FAMILY_CONCEPTION_CHANCE := 0.14
const FAMILY_MAX_CHILDREN_PER_MOTHER := 3
const FAMILY_MAX_HOUSEHOLD_SIZE := 6
const FAMILY_MIN_PARENT_AGE := 18.0
const FAMILY_MAX_MOTHER_AGE := 40.0


func initialize(world_root: Node3D, map_root: Node, settlement_records: Array, fallback_center: Vector3) -> void:
	_world = world_root
	_building_regex.compile("settlement_(\\d+)_building_(\\d+)_([a-z_]+)$")
	_city_regex.compile("settlement_(\\d+)")
	_load_persistent_records()
	_last_lifecycle_day = floori(_world_clock_hours / 24.0)
	for settlement in settlement_records:
		var id := str(settlement.get("id", ""))
		if id == "":
			id = city_id_from_marker(str(settlement.get("marker_name", settlement.get("name", ""))))
		if id == "":
			continue
		cities[id] = {
			"id": id,
			"name": str(settlement.get("name", WORLD_NAMES.settlement_name(id))),
			"center": settlement.get("pos", fallback_center),
			"house_ids": [],
			"building_ids": [],
			"public_positions": [],
			"gate_positions": [],
			"resident_ids": []
		}
	if cities.is_empty():
		var safe_center: Vector3 = _ground(fallback_center)
		cities["settlement_fallback"] = {
			"id": "settlement_fallback", "name": "Os Cânticos dos Sete: Brumaférrea", "center": safe_center,
			"house_ids": [], "building_ids": [], "public_positions": [], "gate_positions": [], "resident_ids": []
		}
	_collect_buildings(map_root)
	_finalize_building_entries()
	_scan_world_networks(map_root)
	for city_id in cities.keys():
		_ensure_virtual_homes(str(city_id))
		_sort_city_records(str(city_id))
		_build_public_points(str(city_id))
		_build_guard_posts(str(city_id))


func reserve_player_home(building_id: String) -> void:
	# O ID só é aceito se apontar para uma casa física válida no mundo atual.
	if houses.has(building_id) and not bool(houses[building_id].get("virtual", false)):
		reserved_player_home_id = building_id


func advance_clock_for_sleep(hours: float, target_hour: float) -> void:
	# Dormir é um salto de tempo legítimo; não deve ser confundido com um erro
	# de relógio nem descartado pelo limite anti-teleporte da simulação.
	if hours <= 0.0:
		return
	_world_clock_hours += hours
	_last_clock_hour = fposmod(target_hour, 24.0)
	_debug_hour = fposmod(target_hour, 24.0)
	_think_timer = 0.0


func _scan_world_networks(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		var node_name := str(child.name).to_lower()
		if node_name.contains("road") or node_name.contains("estrada"):
			_has_road_network = true
		if node_name.contains("river") or node_name.contains("waterway") or node_name.contains("rio"):
			_has_river_network = true
		if node_name.contains("terrain") or node_name.contains("relief") or node_name.contains("biome") or node_name.contains("forest") or node_name.contains("mountain") or node_name.contains("swamp"):
			_has_named_terrain = true
		_scan_world_networks(child)


func register_poi_markers(poi_records: Array) -> void:
	_poi_features.clear()
	for record_value in poi_records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var marker_name := str(record.get("name", "")).to_lower()
		if not marker_name.begins_with("poi_"):
			continue
		var position: Vector3 = record.get("pos", Vector3.ZERO)
		var kind := _poi_kind_from_name(marker_name)
		var display_name := _poi_display_name(marker_name, kind)
		_poi_features.append({
			"id": "poi:" + marker_name, "name": display_name, "kind": kind,
			"city_id": find_nearest_city(position), "position": position,
			"description": _place_description(kind), "source": "map_marker"
		})


func get_map_features() -> Array:
	var features: Array = []
	for feature in _poi_features:
		features.append(feature.duplicate(true))
	for resource in _resource_features:
		features.append(resource.duplicate(true))
	# Estalagens e postos de correios são pontos de interesse no mapa regional.
	for building_id_value in buildings.keys():
		var building_id := str(building_id_value)
		var building: Dictionary = buildings[building_id]
		if bool(building.get("virtual", false)):
			continue
		if str(building.get("kind", "")) == "inn":
			var inn_feature := _building_feature(building, 0)
			inn_feature["id"] = "map_inn:" + building_id
			inn_feature["name"] = str(building.get("name", "Estalagem"))
			inn_feature["description"] = "Estabelecimento para descanso, refeições e hospedagem."
			features.append(inn_feature)
		elif bool(building.get("is_post_office", false)):
			var office_feature := _building_feature(building, 0)
			office_feature["id"] = "map_post_office:" + building_id
			office_feature["name"] = str(building.get("name", "Posto de Correios"))
			office_feature["description"] = _place_description("post_office")
			features.append(office_feature)
	return features


func register_resource_sites(resource_records: Array) -> void:
	_resource_features.clear()
	for record_value in resource_records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var site_id := str(record.get("id", ""))
		if site_id == "":
			continue
		var site_type := str(record.get("type", "mixed"))
		var kind := "resource_ore" if site_type == "ore" else "resource_herbs" if site_type == "herbs" else "resource_mixed"
		var site_name := str(record.get("name", "local de coleta"))
		_resource_features.append({
			"id": "resource:" + site_id, "name": site_name, "kind": kind,
			"city_id": str(record.get("city_id", "")), "position": record.get("position", Vector3.ZERO),
			"description": _place_description(kind), "source": "resource_site"
		})


func refresh_npc_world_knowledge(npc_nodes: Array) -> void:
	for npc in npc_nodes:
		if is_instance_valid(npc) and npc.has_method("configure_world_knowledge"):
			npc.call("configure_world_knowledge", get_world_knowledge_for_npc(npc))


func get_world_knowledge_for_npc(npc: Node) -> Dictionary:
	if npc == null or not is_instance_valid(npc):
		return {"known_places": [], "known_city_names": [], "regional_facts": []}
	var city_id := str(npc.get("city_id"))
	var role := str(npc.get("role"))
	var origin: Vector3 = npc.get("home_position") if npc.get("home_position") is Vector3 else npc.global_position
	var own_city_name := str(cities.get(city_id, {}).get("name", WORLD_NAMES.settlement_name(city_id)))
	var places: Array[Dictionary] = []
	var seen: Dictionary = {}
	var home_id := str(npc.get("home_id"))
	var work_id := str(npc.get("work_building_id"))
	if houses.has(home_id):
		var home: Dictionary = houses[home_id]
		var home_kind := "post_office" if bool(home.get("is_post_office", false)) else "house"
		var home_description := _place_description("post_office") if home_kind == "post_office" else "é a casa de quem vive aqui"
		_add_known_place(places, seen, {"id": home_id, "name": str(home.get("name", npc.get("home_name"))), "kind": home_kind, "city_id": city_id, "position": home.get("entry", origin), "description": home_description, "source": "home", "relevance": 0}, origin, own_city_name)
	elif buildings.has(home_id) and str(buildings[home_id].get("kind", "")) == "inn":
		var inn_home: Dictionary = buildings[home_id]
		_add_known_place(places, seen, _building_feature(inn_home, 0), origin, own_city_name)
	if buildings.has(work_id):
		_add_known_place(places, seen, _building_feature(buildings[work_id], 0), origin, own_city_name)
	# Os moradores conhecem os estabelecimentos públicos de sua cidade, não só o lugar de trabalho.
	for building_id_value in cities.get(city_id, {}).get("building_ids", []):
		var building_id := str(building_id_value)
		var building: Dictionary = buildings.get(building_id, {})
		if building.is_empty() or (str(building.get("kind", "")) == "house" and not bool(building.get("is_post_office", false))) or building_id == work_id:
			continue
		_add_known_place(places, seen, _building_feature(building, 1), origin, own_city_name)
	var poi_radius := LOCAL_POI_RADIUS
	if role == "aldeao": poi_radius = 540.0
	if role in ["guarda", "mercador", "mensageiro"]: poi_radius = 920.0
	for poi in _poi_features:
		if _horizontal_distance(origin, poi.get("position", Vector3.ZERO)) <= poi_radius:
			var feature := poi.duplicate(true)
			feature["relevance"] = 2
			_add_known_place(places, seen, feature, origin, own_city_name)
	for resource in _resource_features:
		if _horizontal_distance(origin, resource.get("position", Vector3.ZERO)) > LOCAL_RESOURCE_RADIUS:
			continue
		var feature := resource.duplicate(true)
		feature["relevance"] = 2 if (role == "ferreiro" and str(feature.get("kind", "")) in ["resource_ore", "resource_mixed"]) or (role == "curandeira" and str(feature.get("kind", "")) in ["resource_herbs", "resource_mixed"]) else 4
		_add_known_place(places, seen, feature, origin, own_city_name)
	# Profissionais que viajam conhecem mais assentamentos; um morador comum não é onisciente.
	var other_cities: Array[Dictionary] = []
	for other_id_value in cities.keys():
		var other_id := str(other_id_value)
		if other_id == city_id: continue
		var city: Dictionary = cities[other_id]
		var distance := _horizontal_distance(origin, city.get("center", origin))
		var allowed := distance <= LOCAL_NEIGHBOR_CITY_RADIUS
		if role == "guarda": allowed = distance <= 900.0
		elif role == "mercador": allowed = distance <= 2200.0
		elif role == "mensageiro": allowed = true
		if not allowed: continue
		other_cities.append({"id": other_id, "name": str(city.get("name", WORLD_NAMES.settlement_name(other_id))), "kind": "city", "city_id": other_id, "position": city.get("center", Vector3.ZERO), "description": _place_description("city"), "relevance": 5})
	other_cities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _horizontal_distance(origin, a.get("position", origin)) < _horizontal_distance(origin, b.get("position", origin))
	)
	var city_limit := 1
	if role == "guarda": city_limit = 2
	elif role == "mercador": city_limit = 4
	elif role == "mensageiro": city_limit = mini(8, other_cities.size())
	for i in range(mini(city_limit, other_cities.size())):
		_add_known_place(places, seen, other_cities[i], origin, own_city_name)
	places.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("relevance", 9)) != int(b.get("relevance", 9)):
			return int(a.get("relevance", 9)) < int(b.get("relevance", 9))
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)
	var city_names: Array[String] = [own_city_name]
	for place in places:
		if str(place.get("kind", "")) == "city" and not city_names.has(str(place.get("name", ""))):
			city_names.append(str(place.get("name", "")))
	var facts: Array[String] = []
	if _has_road_network: facts.append("As estradas ligam assentamentos e são referências importantes para viagens.")
	if _has_river_network: facts.append("Os cursos d'água fazem parte da geografia local e podem influenciar os caminhos.")
	if _has_named_terrain: facts.append("O terreno varia em altura e condiciona os caminhos e a visibilidade na região.")
	return {"city_id": city_id, "city_name": own_city_name, "role": role, "known_places": places, "known_city_names": city_names, "regional_facts": facts, "roads_known": _has_road_network, "rivers_known": _has_river_network}


func _add_known_place(target: Array[Dictionary], seen: Dictionary, source: Dictionary, origin: Vector3, own_city_name: String) -> void:
	var place_id := str(source.get("id", ""))
	if place_id == "" or seen.has(place_id): return
	var place: Dictionary = source.duplicate(true)
	var position: Vector3 = place.get("position", origin)
	place["distance"] = _horizontal_distance(origin, position)
	place["direction"] = _direction_from_to(origin, position)
	var place_city_id := str(place.get("city_id", ""))
	place["same_city"] = str(place.get("source", "")) in ["building", "home"] and place_city_id != "" and place_city_id == _city_id_for_name(own_city_name)
	place["locality"] = "na cidade" if bool(place["same_city"]) else "nos arredores"
	place["city_name"] = str(cities.get(place_city_id, {}).get("name", WORLD_NAMES.settlement_name(place_city_id) if place_city_id != "" else own_city_name))
	seen[place_id] = true
	target.append(place)


func _city_id_for_name(city_name: String) -> String:
	for key in cities.keys():
		if str(cities[key].get("name", "")) == city_name: return str(key)
	return ""


func _building_feature(record: Dictionary, relevance: int) -> Dictionary:
	var kind := "post_office" if bool(record.get("is_post_office", false)) else str(record.get("kind", "building"))
	return {"id": str(record.get("id", "")), "name": str(record.get("name", "edifício local")), "kind": kind, "city_id": str(record.get("city_id", "")), "position": record.get("entry", record.get("center", Vector3.ZERO)), "description": _place_description(kind), "source": "building", "relevance": relevance}


func _poi_kind_from_name(marker_name: String) -> String:
	if marker_name.contains("dungeon") or marker_name.contains("crypt"): return "dungeon"
	if marker_name.contains("watchtower") or marker_name.contains("watch_tower") or marker_name.contains("tower"): return "watchtower"
	if marker_name.contains("shrine") or marker_name.contains("sanctuary"): return "shrine"
	if marker_name.contains("ruin"): return "ruins"
	if marker_name.contains("camp"): return "camp"
	if marker_name.contains("mine") or marker_name.contains("quarry") or marker_name.contains("ore"): return "mine"
	if marker_name.contains("grove"): return "grove"
	if marker_name.contains("meadow") or marker_name.contains("herb"): return "meadow"
	if marker_name.contains("forest"): return "forest"
	if marker_name.contains("cave"): return "cave"
	return "landmark"


func _poi_display_name(marker_name: String, kind: String) -> String:
	# O índice do marcador nunca é tratado como nome. O catálogo fornece um
	# topônimo próprio e, para pontos futuros, um rótulo natural sem números.
	return WORLD_NAMES.poi_name(marker_name, kind)

func _place_description(kind: String) -> String:
	match kind:
		"house": return "é uma moradia dos habitantes locais"
		"shop": return "é um estabelecimento de comércio e suprimentos"
		"workshop": return "é uma oficina onde se fazem e consertam coisas"
		"inn": return "é a estalagem local, que também funciona como taverna para refeições, bebidas, hospedagem e notícias"
		"post_office": return "é a casa que serve de posto de correios; mensageiros partem daqui e trazem notícias de outras cidades"
		"tavern": return "é uma taverna onde moradores e viajantes se encontram para comer, beber e trocar notícias"
		"town_hall": return "é o salão comunal onde se discutem assuntos da comunidade"
		"temple": return "é um templo dedicado às práticas religiosas da região"
		"library": return "é uma biblioteca que guarda livros, mapas e registros"
		"infirmary": return "é uma enfermaria onde os doentes e feridos recebem cuidados"
		"guard_post": return "é um posto da guarda usado para vigiar e proteger o assentamento"
		"lookout": return "é um mirante de onde se observam as estradas e os arredores"
		"depot": return "é um depósito para guardar ferramentas, mantimentos e mercadorias"
		"shelter": return "é um abrigo para viajantes e moradores que precisam de proteção"
		"stable": return "é um estábulo onde se abrigam e tratam animais de montaria e carga"
		"mill": return "é um moinho usado para processar grãos e outros produtos"
		"barn": return "é um celeiro para guardar colheitas, feno e ferramentas agrícolas"
		"well": return "é um poço público usado para obter água"
		"ruin": return "é uma construção arruinada que conserva sinais de ocupação antiga"
		"cave": return "é uma caverna natural; convém ter cuidado antes de explorar"
		"ruins": return "são ruínas antigas, sinais de ocupação de outros tempos"
		"camp": return "é um acampamento nos ermos, onde pode haver sinais de atividade recente"
		"shrine": return "é um santuário, um lugar de devoção e costumes locais"
		"watchtower": return "é uma torre de vigia com vista sobre parte dos arredores"
		"dungeon": return "é uma entrada subterrânea; não é um lugar para descer sem preparo"
		"mine": return "é uma área associada à extração de pedra ou minério"
		"grove": return "é um bosque que serve de referência para quem conhece a região"
		"meadow": return "é um prado onde podem crescer plantas úteis"
		"forest": return "é uma área de floresta, com caminhos menos óbvios que as estradas"
		"resource_ore": return "é um ponto de coleta de minério e pedras úteis para os artesãos"
		"resource_herbs": return "é um ponto de coleta de ervas e plantas medicinais"
		"resource_mixed": return "é um ponto de coleta com materiais naturais diferentes"
		"city": return "é outro assentamento ligado às viagens e ao comércio regional"
		_: return "é um marco da região que os moradores usam para se orientar"


func _direction_from_to(origin: Vector3, destination: Vector3) -> String:
	var delta := Vector2(destination.x - origin.x, destination.z - origin.z)
	if delta.length_squared() < 1.0: return "bem aqui"
	if absf(delta.x) > absf(delta.y) * 1.65: return "a leste" if delta.x >= 0.0 else "a oeste"
	if absf(delta.y) > absf(delta.x) * 1.65: return "ao sul" if delta.y >= 0.0 else "ao norte"
	if delta.x >= 0.0 and delta.y < 0.0: return "a nordeste"
	if delta.x >= 0.0: return "a sudeste"
	if delta.y < 0.0: return "a noroeste"
	return "a sudoeste"


func city_id_from_marker(marker_name: String) -> String:
	var found := _city_regex.search(marker_name.to_lower())
	if found == null:
		return ""
	return "settlement_%s" % found.get_string(1)


func find_nearest_city(pos: Vector3) -> String:
	var best_id := ""
	var best_distance := INF
	for key in cities.keys():
		var city: Dictionary = cities[key]
		var center: Vector3 = city["center"]
		var distance := Vector2(pos.x - center.x, pos.z - center.z).length()
		if distance < best_distance:
			best_distance = distance
			best_id = str(key)
	return best_id


func get_unique_witch_location() -> String:
	var location := str(_world_flags.get("witch_location", ""))
	# Migra saves antigos: o lago continua sendo uma opção, e a mata foi
	# substituída pela nova Casa da Bruxa adicionada ao overworld.
	if location == "lake":
		location = "lake_edge"
	elif location == "forest":
		location = "witch_house"
	if location not in ["lake_edge", "witch_house"]:
		location = "lake_edge" if randi() % 2 == 0 else "witch_house"
	_world_flags["witch_location"] = location
	return location


func get_witch_state() -> String:
	var state := str(_world_flags.get("witch_status", "alive"))
	return state if state in ["alive", "allied", "dead"] else "alive"


func get_witch_quest_status() -> String:
	var status := str(_world_flags.get("witch_quest_status", "not_started"))
	return status if status in ["not_started", "active", "completed"] else "not_started"


func set_witch_quest_status(status: String) -> void:
	if status not in ["not_started", "active", "completed"]:
		return
	_world_flags["witch_quest_status"] = status
	_save_persistent_records()


func should_spawn_unique_witch() -> bool:
	return get_witch_state() != "dead"


func get_witch_hp() -> int:
	if get_witch_state() == "dead":
		return 0
	return clampi(int(_world_flags.get("witch_hp", 80)), 1, 80)


func set_witch_hp(value: int) -> void:
	if get_witch_state() == "dead":
		return
	_world_flags["witch_hp"] = clampi(value, 0, 80)
	if int(_world_flags["witch_hp"]) <= 0:
		_world_flags["witch_status"] = "dead"
	_save_persistent_records()


func set_witch_state(state: String) -> void:
	if state not in ["alive", "allied", "dead"]:
		return
	if get_witch_state() == "dead" and state != "dead":
		return
	_world_flags["witch_status"] = state
	if state == "dead":
		_world_flags["witch_hp"] = 0
	elif int(_world_flags.get("witch_hp", 80)) <= 0:
		_world_flags["witch_hp"] = 80
	_save_persistent_records()


func save_world_state() -> void:
	_save_persistent_records()


func get_saved_npc_record(npc_id: String) -> Dictionary:
	# A criação do overworld precisa consultar a identidade anterior antes de decidir
	# se um NPC pode aparecer numa cidade tomada ou reduzida a ruínas.
	var saved_value: Variant = _previous_records.get(npc_id, {})
	return saved_value.duplicate(true) if saved_value is Dictionary else {}


func get_post_office_for_city(city_id: String) -> Dictionary:
	var office_id := _ensure_post_office_id(city_id)
	if office_id == "":
		return {}
	var office: Dictionary = buildings.get(office_id, {})
	return office.duplicate(true)


func _ensure_post_office_id(city_id: String) -> String:
	if not cities.has(city_id):
		return ""
	var offices_value: Variant = _world_flags.get("post_offices", {})
	var offices: Dictionary = offices_value if offices_value is Dictionary else {}
	var saved_id := str(offices.get(city_id, ""))
	if saved_id != "" and houses.has(saved_id) and buildings.has(saved_id) and saved_id != reserved_player_home_id and str(houses[saved_id].get("city_id", "")) == city_id:
		_mark_post_office(saved_id, city_id)
		return saved_id

	var candidates: Array[String] = []
	var city: Dictionary = cities[city_id]
	for home_value in city.get("house_ids", []):
		var home_id := str(home_value)
		var home: Dictionary = houses.get(home_id, {})
		if home.is_empty() or home_id == reserved_player_home_id or not buildings.has(home_id):
			continue
		if str(home.get("city_id", "")) != city_id or str(home.get("kind", "")) != "house":
			continue
		if bool(home.get("is_post_office", false)) and str(home.get("post_office_for", "")) != city_id:
			continue
		if not bool(home.get("virtual", false)):
			candidates.append(home_id)
	# Um posto deve corresponder a uma casa física que realmente exista no mundo.
	# Não atribuímos um endereço virtual como se fosse um prédio visitável.
	if candidates.is_empty():
		return ""
	candidates.sort()
	var selected_id := candidates[posmod(absi((city_id + "|post-office").hash()), candidates.size())]
	var updated_offices := offices.duplicate(true)
	updated_offices[city_id] = selected_id
	_world_flags["post_offices"] = updated_offices
	_mark_post_office(selected_id, city_id)
	return selected_id


func _mark_post_office(building_id: String, city_id: String) -> void:
	if not buildings.has(building_id) or not houses.has(building_id):
		return
	var city_name := str(cities.get(city_id, {}).get("name", WORLD_NAMES.settlement_name(city_id)))
	var office: Dictionary = buildings[building_id].duplicate(true)
	office["is_post_office"] = true
	office["post_office_for"] = city_id
	office["name"] = "Posto de Correios de %s" % city_name
	office["supports_interior"] = true
	buildings[building_id] = office
	houses[building_id] = office.duplicate(true)


func create_profile(npc_id: String, role: String, requested_city_id: String, ordinal: int = -1, occupation_label: String = "") -> Dictionary:
	var city_id := requested_city_id
	var previous: Dictionary = _previous_records.get(npc_id, {})
	if not cities.has(city_id):
		city_id = find_nearest_city(Vector3.ZERO) if cities.size() > 0 else "settlement_fallback"
	if not cities.has(city_id):
		var center := _ground(Vector3.ZERO)
		cities["settlement_fallback"] = {
			"id": "settlement_fallback", "name": "Os Cânticos dos Sete: Brumaférrea", "center": center,
			"house_ids": [], "building_ids": [], "public_positions": [], "gate_positions": [], "resident_ids": []
		}
		_ensure_virtual_homes("settlement_fallback")
		_sort_city_records("settlement_fallback")
		_build_public_points("settlement_fallback")
		city_id = "settlement_fallback"
	# Um mercador ambulante mantém sua identidade, mas reaparece na cidade onde
	# terminou a última viagem, não volta magicamente ao assentamento de origem.
	if role == "mercador" and str(previous.get("merchant_type", "")) == "itinerant":
		var saved_city_id := str(previous.get("city_id", ""))
		if cities.has(saved_city_id):
			city_id = saved_city_id
	elif role == "mensageiro":
		var saved_life_value: Variant = previous.get("life_state", {})
		var saved_life: Dictionary = saved_life_value if saved_life_value is Dictionary else {}
		if bool(saved_life.get("messenger_trip_active", false)):
			var saved_messenger_city := str(previous.get("city_id", ""))
			if cities.has(saved_messenger_city):
				city_id = saved_messenger_city
	var city: Dictionary = cities[city_id]
	if ordinal < 0:
		var current_residents: Array = city["resident_ids"]
		ordinal = current_residents.size()
	var person_name := str(previous.get("person_name", ""))
	var gender := str(previous.get("gender", ""))
	# Aproveita o gênero salvo quando existe; no caso de registros antigos sem gênero,
	# tenta reconhecê-lo pelo nome próprio antes de usar o ID como decisão estável.
	if gender not in ["male", "female"]:
		gender = _gender_from_name(person_name)
	if gender not in ["male", "female"]:
		gender = _gender_for_id(npc_id)
	# A bruxa é um personagem/arquétipo específico do asset atual, não uma profissão
	# distribuída aleatoriamente entre os habitantes.
	if role == "bruxa":
		gender = "female"
	var age_years := float(previous.get("age_years", -1.0))
	if age_years < 0.0:
		# A população inicial começa em idades adultas variadas e estáveis.
		age_years = 18.0 + float(posmod(absi((npc_id + "|starting-age").hash()), 23))
	var birth_world_hours := float(previous.get("birth_world_hours", _world_clock_hours - age_years * FAMILY_HOURS_PER_YEAR))
	var age_stage := "child" if age_years < 16.0 else "adult"
	# Migra nomes antigos para o repertório português na primeira carga. Depois disso,
	# um nome português válido permanece estável entre sessões e alterações de rotina.
	if not _is_portuguese_name(person_name, gender):
		person_name = _generate_name(city_id, ordinal, gender, npc_id)
	var merchant_type := "none"
	if role == "mercador":
		merchant_type = str(previous.get("merchant_type", ""))
		if merchant_type not in ["resident", "itinerant"]:
			# O primeiro comerciante da população é o lojista residente. Mercadores
			# adicionais podem ser viajantes, selecionados de maneira estável por ID.
			merchant_type = "itinerant" if ordinal >= 5 and posmod(absi((npc_id + "|itinerant-merchant").hash()), 3) == 0 else "resident"
	var home_id := str(previous.get("home_id", ""))
	var is_unique_witch := role == "bruxa"
	if is_unique_witch:
		# A bruxa não é residente de nenhuma cidade e não pertence a uma família local.
		home_id = ""
	elif role == "mensageiro":
		# Mesmo durante uma viagem, a residência e a base postal continuam na cidade de origem.
		var postal_home_city := str(previous.get("origin_city_id", city_id))
		if not cities.has(postal_home_city):
			postal_home_city = city_id
		home_id = _ensure_post_office_id(postal_home_city)
	elif merchant_type == "itinerant":
		if not _is_inn_in_city(home_id, city_id):
			home_id = _select_inn_home(city_id, npc_id)
	else:
		if (not houses.has(home_id)
			or str(houses[home_id].get("city_id", "")) != city_id
			or bool(houses[home_id].get("is_post_office", false))):
			home_id = _select_home(city_id, ordinal)
	# Uma casa reservada ao jogador não pode continuar atribuída a um morador salvo.
	if home_id == reserved_player_home_id and not is_unique_witch:
		home_id = _select_home(city_id, ordinal)
	# Se o assentamento não tiver estalagem, usa uma residência como contingência.
	if not is_unique_witch and not houses.has(home_id) and not buildings.has(home_id):
		home_id = _select_home(city_id, ordinal)
	var home: Dictionary = houses.get(home_id, buildings.get(home_id, {}))
	if home.is_empty() and not is_unique_witch:
		home_id = _select_home(city_id, ordinal)
		home = houses.get(home_id, {})
	if is_unique_witch:
		home = {"id": "", "name": "Esconderijo desconhecido", "entry": city.get("center", Vector3.ZERO), "door_position": city.get("center", Vector3.ZERO), "front_direction": Vector3.FORWARD}
	var label_role := _occupation_label(role, gender, occupation_label)
	var sprite_key := _sprite_key_for(role, gender, age_stage)
	# Nome pessoal e profissão são dados separados; a função é exibida pela interface,
	# não incorporada ao nome nem repetida no cabeçalho do diálogo.
	var display_name := person_name
	var public_positions: Array = city["public_positions"]
	var home_front_direction: Vector3 = home.get("front_direction", Vector3.FORWARD)
	home_front_direction.y = 0.0
	if home_front_direction.length_squared() < 0.001:
		home_front_direction = Vector3.FORWARD
	home_front_direction = home_front_direction.normalized()
	var messenger_base_city := str(previous.get("origin_city_id", city_id)) if role == "mensageiro" else city_id
	if not cities.has(messenger_base_city):
		messenger_base_city = city_id
	var work_building_id := "" if merchant_type == "itinerant" or is_unique_witch else _work_building_id_for(messenger_base_city, role)
	var work_building: Dictionary = buildings.get(work_building_id, {})
	var work_position: Vector3 = Vector3.ZERO if merchant_type == "itinerant" or is_unique_witch else _work_position_for(messenger_base_city, role, work_building_id)
	var brain := _brain_profile_for(npc_id, role, previous)
	var saved_life_value: Variant = previous.get("life_state", {})
	var saved_life_state: Dictionary = saved_life_value.duplicate(true) if saved_life_value is Dictionary else {}
	if not saved_life_state.is_empty() and str(saved_life_state.get("city_id", city_id)) != city_id:
		saved_life_state.clear()
	var saved_player_relation_value: Variant = previous.get("player_relationship", {})
	var saved_player_relation: Dictionary = saved_player_relation_value.duplicate(true) if saved_player_relation_value is Dictionary else {}
	var saved_world_events: Array = _normalize_world_event_memories(previous.get("known_world_events", []))
	var profile := {
		"id": npc_id,
		"person_name": person_name,
		"gender": gender,
		"age_stage": age_stage,
		"age_years": age_years,
		"birth_world_hours": birth_world_hours,
		"mother_id": str(previous.get("mother_id", "")),
		"father_id": str(previous.get("father_id", "")),
		"generation": int(previous.get("generation", _generation_from_parents(str(previous.get("mother_id", "")), str(previous.get("father_id", ""))))),
		"family_surname": str(previous.get("family_surname", _surname_from_person_name(person_name))),
		"family_generated": bool(previous.get("family_generated", false)),
		"is_deceased": bool(previous.get("is_deceased", false)),
		"sprite_key": sprite_key,
		"partner_id": str(previous.get("partner_id", get_partner_id(npc_id))),
		"display_name": display_name,
		"occupation_label": label_role,
		"personality": str(previous.get("personality", _personality_for(npc_id))),
		"speech_style": str(brain.get("speech_style", "direto")),
		"personal_interest": str(brain.get("personal_interest", "os costumes locais")),
		"personal_goal": str(brain.get("personal_goal", "aprender algo que ainda não sei")),
		"sociability": float(brain.get("sociability", 0.55)),
		"curiosity": float(brain.get("curiosity", 0.5)),
		"role": role,
		"merchant_type": merchant_type,
		"merchant_last_city_id": str(previous.get("merchant_last_city_id", "")),
		"merchant_trips_completed": int(previous.get("merchant_trips_completed", 0)),
		"merchant_trip_active": bool(saved_life_state.get("merchant_trip_active", false)),
		"merchant_target_city_id": str(saved_life_state.get("merchant_target_city_id", "")),
		"merchant_target_inn_id": str(saved_life_state.get("merchant_target_inn_id", "")),
		"messenger_trip_active": bool(saved_life_state.get("messenger_trip_active", false)),
		"messenger_trip_stage": str(saved_life_state.get("messenger_trip_stage", "")),
		"messenger_target_city_id": str(saved_life_state.get("messenger_target_city_id", "")),
		"messenger_target_office_id": str(saved_life_state.get("messenger_target_office_id", "")),
		"messenger_origin_office_id": str(saved_life_state.get("messenger_origin_office_id", "")),
		"messenger_arrival_clock": float(saved_life_state.get("messenger_arrival_clock", 0.0)),
		"messenger_trips_completed": int(previous.get("messenger_trips_completed", 0)),
		"messenger_carried_news": previous.get("messenger_carried_news", []),
		"is_unique_witch": is_unique_witch,
		"witch_location": str(_world_flags.get("witch_location", "")),
		"witch_state": get_witch_state(),
		"witch_hp": get_witch_hp(),
		"life_state": saved_life_state,
		"player_relationship": saved_player_relation,
		"city_id": city_id,
		"origin_city_id": str(previous.get("origin_city_id", city_id)),
		"city_name": str(city["name"]),
		"city_center": city.get("center", Vector3.ZERO),
		"home_id": home_id,
		"home_name": str(home["name"]),
		"home_position": home.get("entry", city.get("center", Vector3.ZERO)),
		"home_door_position": home.get("door_position", home.get("entry", city.get("center", Vector3.ZERO)) - home_front_direction * HOME_ENTRY_MARGIN),
		"home_front_direction": home_front_direction,
		"work_position": work_position,
		"work_building_id": work_building_id,
		"work_door_position": work_building.get("door_position", work_building.get("entry", work_position)),
		"work_front_direction": work_building.get("front_direction", Vector3.FORWARD),
		"work_building_name": str(work_building.get("name", "")),
		"public_positions": public_positions.duplicate(),
		"household_ids": [],
		"household_names": [],
		"known_world_events": saved_world_events
	}
	_register_profile(profile)
	return profile


func finalize_npcs(npc_nodes: Array) -> void:
	_current_npc_nodes = npc_nodes
	# Migra casais já existentes em saves anteriores para o grafo genealógico.
	for relation_value in _relationships.values():
		if not (relation_value is Dictionary):
			continue
		var relation: Dictionary = relation_value
		if str(relation.get("stage", "")) == "partner":
			if not relation.has("union_started_clock"):
				relation["union_started_clock"] = _world_clock_hours - FAMILY_MIN_UNION_HOURS
				var relation_key := _relationship_key(str(relation.get("a", "")), str(relation.get("b", "")))
				_relationships[relation_key] = relation
			_record_family_union(str(relation.get("a", "")), str(relation.get("b", "")), float(relation.get("union_started_clock", _world_clock_hours)))
	# Fecha a lista de moradores depois que todos foram criados, permitindo que a
	# casa e cada residente consultem a mesma composição do núcleo doméstico.
	for home_key in houses.keys():
		var home_record: Dictionary = houses[home_key]
		var resident_ids: Array = home_record.get("resident_ids", [])
		var resident_names: Array[String] = []
		for resident_id in resident_ids:
			var resident_record: Dictionary = _active_records.get(str(resident_id), _previous_records.get(str(resident_id), {}))
			if not resident_record.is_empty():
				resident_names.append(str(resident_record.get("person_name", resident_id)))
		var city_record: Dictionary = cities.get(str(home_record.get("city_id", "")), {})
		var city_label := str(city_record.get("name", "Os Cânticos dos Sete: Brumaférrea"))
		var house_label := "Posto de Correios de %s" % city_label if bool(home_record.get("is_post_office", false)) else _house_display_name(resident_names, city_label)
		home_record["resident_names"] = resident_names
		home_record["name"] = house_label
		houses[home_key] = home_record
		if buildings.has(str(home_key)):
			var building_record: Dictionary = buildings[str(home_key)]
			building_record["resident_names"] = resident_names.duplicate()
			building_record["name"] = house_label
			buildings[str(home_key)] = building_record
	# Nomes comerciais dependem dos proprietários que foram associados aos locais
	# de trabalho. Casas, lojas e oficinas passam a ter nomes legíveis no mapa/UI.
	_refresh_owned_building_names()
	# Cada NPC recebe uma cópia da mesma lista de moradores da sua casa.
	for npc in npc_nodes:
		if not is_instance_valid(npc) or not npc.has_method("set_household_members"):
			continue
		var home_id := str(npc.home_id)
		var home: Dictionary = houses.get(home_id, {})
		var resident_ids: Array = home.get("resident_ids", []).duplicate()
		var resident_names: Array = home.get("resident_names", []).duplicate()
		npc.set_household_members(resident_ids, resident_names)
		npc.home_name = str(home.get("name", npc.home_name))
		if npc.has_method("set_work_building_details"):
			npc.set_work_building_details(buildings.get(str(npc.work_building_id), {}))
	# Evita serializar todos os perfis no frame em que o mundo termina de carregar.
	# O primeiro checkpoint periódico ou a saída do mundo persiste esse estado.
	_log_debug("SOCIEDADE", "%d habitantes registrados em %d cidades." % [npc_nodes.size(), cities.size()])


func set_active_conversation_interior(building_id: String, building_kind: String) -> void:
	# Conversas iniciadas na rua não continuam sendo mostradas dentro de um
	# interior, e moradores de salas distintas nunca são pareados por proximidade X/Z.
	if building_id == _active_social_interior_id and building_kind == _active_social_interior_kind:
		return
	for session in _conversation_sessions:
		for participant in session.get("participants", []):
			if is_instance_valid(participant) and participant.has_method("end_ambient_conversation"):
				participant.end_ambient_conversation()
	_conversation_sessions.clear()
	_conversation_think_timer = 0.0
	_active_social_interior_id = building_id
	_active_social_interior_kind = building_kind


func tick(delta: float, hour: float, active: bool, npc_nodes: Array, player_position: Vector3 = Vector3.ZERO, active_radius: float = 135.0) -> void:
	_current_npc_nodes = npc_nodes
	if active:
		if _last_clock_hour < 0.0:
			_last_clock_hour = hour
		else:
			var clock_advance := fposmod(hour - _last_clock_hour, 24.0)
			# Ignora saltos incompatíveis com o relógio correndo normalmente.
			if clock_advance < 12.0:
				_world_clock_hours += clock_advance
			_last_clock_hour = hour
	else:
		# O relógio de viagem não acumula enquanto o mundo está pausado/em diálogo.
		_last_clock_hour = hour
	_debug_hour = hour
	if active:
		_process_genealogy_time(npc_nodes)
	_conversation_clock += delta
	_tick_conversation_cooldowns(delta)
	if active:
		_persistent_save_timer += delta
		if _persistent_save_timer >= PERSISTENT_SAVE_INTERVAL:
			_persistent_save_timer = fposmod(_persistent_save_timer, PERSISTENT_SAVE_INTERVAL)
			_save_persistent_records()
	if active:
		_advance_conversation_sessions(delta)
	else:
		# Ao sair do mundo/pausar a simulação, libera os dois participantes antes
		# de descartar as sessões, para ninguém ficar travado ao voltar.
		for session in _conversation_sessions:
			for participant in session.get("participants", []):
				if is_instance_valid(participant) and participant.has_method("end_ambient_conversation"):
					participant.end_ambient_conversation()
		_conversation_sessions.clear()
		_conversation_think_timer = 0.0
	if active:
		_regional_threat_refresh_timer += delta
		if _regional_threat_refresh_timer >= 1.0:
			_regional_threat_refresh_timer = 0.0
			_refresh_regional_threat_cache()
	# O plantel de guardas só muda ocasionalmente. Recalcular a lista em todo
	# frame criava varreduras e arrays temporários sem necessidade.
	_guard_roster_refresh_timer += delta
	if not _guard_rosters_initialized or _guard_roster_refresh_timer >= GUARD_ROSTER_REFRESH_SECONDS:
		_cached_guard_rosters = _build_guard_rosters(npc_nodes)
		_guard_rosters_initialized = true
		_guard_roster_refresh_timer = 0.0
	var guard_rosters: Dictionary = _cached_guard_rosters

	# Ativação física, destinos off-screen e rotinas de habitantes têm escala de
	# décimos de segundo; não precisam percorrer todos os NPCs a cada frame.
	_npc_stream_state_timer += delta
	if _npc_stream_state_timer >= NPC_STREAM_STATE_REFRESH_SECONDS:
		_npc_stream_state_timer = fposmod(_npc_stream_state_timer, NPC_STREAM_STATE_REFRESH_SECONDS)
		for npc in npc_nodes:
			if not is_instance_valid(npc):
				continue
			if bool(npc.get("is_unique_witch")) and str(npc.get("witch_state")) == "allied":
				# A bruxa aliada não é um habitante comum: a simulação de distância
				# não pode mandá-la de volta ao esconderijo nem ocultá-la.
				if active:
					npc.visible = true
					npc.life_enabled = true
					npc.collision_layer = 2
					npc.collision_mask = 1
					npc.set_physics_process(true)
				else:
					npc.life_enabled = false
					npc.set_physics_process(false)
				continue
			if not active:
				if bool(npc.get("life_enabled")):
					npc.life_enabled = false
					npc.set_physics_process(false)
				continue
			# NPCs materializados num interior são mantidos nesse espaço. A conversa
			# ambiente continua funcionando, mas a rotina exterior não os teleporta.
			if bool(npc.get("is_interior_present")):
				continue
			if bool(npc.get("is_at_tavern")):
				# Já atravessou a porta: não reativa o sprite na calçada. Só sai da
				# estalagem quando a agenda muda para outra atividade.
				var tavern_distance := _horizontal_distance(npc.global_position, player_position)
				var tavern_next_bucket := _routine_bucket_for_npc(npc, hour, guard_rosters)
				if tavern_next_bucket != "tavern" and str(npc.get("life_bucket")) != tavern_next_bucket:
					npc.life_bucket = tavern_next_bucket
					if tavern_distance <= active_radius:
						_give_activity(npc, tavern_next_bucket)
					else:
						_give_distant_activity(npc, tavern_next_bucket)
				continue
			var distance := Vector2(npc.global_position.x - player_position.x, npc.global_position.z - player_position.z).length()
			if str(npc.get("role")) == "mensageiro" and bool(npc.get("messenger_trip_active")) and distance > active_radius and _world_clock_hours >= float(npc.get("messenger_arrival_clock")):
				_arrive_messenger_leg(npc, true)
			if distance <= active_radius:
				if bool(npc.get("is_at_home")) or bool(npc.get("is_at_work")):
					if npc.has_method("has_pending_quest_return") and bool(npc.call("has_pending_quest_return")):
						npc.set_stream_active(true)
				elif not bool(npc.get("life_enabled")) or not bool(npc.visible) or not npc.is_physics_processing():
					npc.set_stream_active(true)
			else:
				var remote_bucket := _routine_bucket_for_npc(npc, hour, guard_rosters)
				if str(npc.life_bucket) != remote_bucket or npc.visible:
					npc.life_bucket = remote_bucket
					_give_distant_activity(npc, remote_bucket)
				if bool(npc.get("life_enabled")) or bool(npc.visible) or npc.is_physics_processing():
					npc.set_stream_active(false)
	if not active:
		return
	_conversation_think_timer += delta
	if _conversation_think_timer >= CHAT_START_INTERVAL:
		_conversation_think_timer = 0.0
		_try_start_conversation(npc_nodes, player_position, hour)
	_think_timer += delta
	if _think_timer < ROUTINE_UPDATE_SECONDS:
		return
	_think_timer = 0.0
	var active_npcs: Array = []
	for npc in npc_nodes:
		if not is_instance_valid(npc) or bool(npc.get("is_interior_present")):
			continue
		if bool(npc.get("is_unique_witch")) and str(npc.get("witch_state")) == "allied":
			continue
		var distance := Vector2(npc.global_position.x - player_position.x, npc.global_position.z - player_position.z).length()
		if distance <= active_radius and not bool(npc.is_at_home) and bool(npc.visible):
			active_npcs.append(npc)
	# Índice espacial para a separação entre habitantes. Passar a lista completa
	# a cada NPC custava O(N²) a cada atualização de rotina, sobretudo nas cidades.
	# Com células de 5,5 m, cada personagem consulta apenas a própria célula e as 8 vizinhas.
	var separation_grid: Dictionary = {}
	for npc in active_npcs:
		var cell := Vector2i(
			floori(npc.global_position.x / NPC_SEPARATION_GRID_CELL_SIZE),
			floori(npc.global_position.z / NPC_SEPARATION_GRID_CELL_SIZE)
		)
		var bucket: Array = separation_grid.get(cell, [])
		bucket.append(npc)
		separation_grid[cell] = bucket
	for npc in active_npcs:
		if not npc.has_method("set_separation_peers"):
			continue
		var cell := Vector2i(
			floori(npc.global_position.x / NPC_SEPARATION_GRID_CELL_SIZE),
			floori(npc.global_position.z / NPC_SEPARATION_GRID_CELL_SIZE)
		)
		var nearby: Array = []
		for cell_x in range(cell.x - 1, cell.x + 2):
			for cell_z in range(cell.y - 1, cell.y + 2):
				var bucket: Array = separation_grid.get(Vector2i(cell_x, cell_z), [])
				for peer in bucket:
					if peer != npc:
						nearby.append(peer)
		npc.set_separation_peers(nearby)
	for npc in npc_nodes:
		if not is_instance_valid(npc) or bool(npc.get("is_interior_present")):
			continue
		if bool(npc.get("is_unique_witch")) and str(npc.get("witch_state")) == "allied":
			continue
		var distance := Vector2(npc.global_position.x - player_position.x, npc.global_position.z - player_position.z).length()
		if distance > active_radius:
			continue
		if str(npc.get("merchant_type")) == "itinerant" and bool(npc.get("merchant_trip_active")) and not bool(npc.get("has_target")) and str(npc.get("target_kind")) == "merchant_travel":
			_complete_merchant_trip(npc, false)
		if str(npc.get("role")) == "mensageiro" and bool(npc.get("messenger_trip_active")):
			if not bool(npc.get("has_target")) and str(npc.get("target_kind")) == "messenger_travel":
				if _world_clock_hours >= float(npc.get("messenger_arrival_clock")):
					_arrive_messenger_leg(npc, false)
				else:
					var target_office_id := str(npc.messenger_target_office_id)
					var target_office: Dictionary = buildings.get(target_office_id, {})
					var target_pos: Vector3 = _work_position_for(str(target_office.get("city_id", "")), "mensageiro", target_office_id) if not target_office.is_empty() else npc.global_position
					# Se já chegou cedo, espera no posto até o relógio de viagem marcar a entrega.
					if _horizontal_distance(npc.global_position, target_pos) > 3.0:
						_send_messenger_on_trip(npc)
				continue
		var bucket := _routine_bucket_for_npc(npc, hour, guard_rosters)
		if bool(npc.get("ambient_conversation_locked")):
			continue
		if str(npc.life_bucket) != bucket:
			npc.life_bucket = bucket
			_give_activity(npc, bucket)
		elif npc.needs_new_activity():
			_give_activity(npc, bucket)


func _personality_for(npc_id: String) -> String:
	var index: int = posmod(abs((npc_id + "|personality").hash()), PERSONALITIES.size())
	return str(PERSONALITIES[index])


func _brain_profile_for(npc_id: String, role: String, previous: Dictionary = {}) -> Dictionary:
	# Cada pessoa recebe traços estáveis próprios. São derivados do ID persistente,
	# não de sorteios por fala, para que o habitante continue reconhecível depois.
	var styles: Array[String] = []
	for style_value in SPEECH_STYLES:
		styles.append(str(style_value))
	var style_index: int = posmod(abs((npc_id + "|voice").hash()), styles.size())
	var interest_pool: Array[String] = []
	match role:
		"ferreiro": interest_pool = ["metalurgia e ferramentas", "preços do minério", "armas antigas", "a qualidade dos trabalhos manuais", "histórias de artesãos"]
		"mercador": interest_pool = ["mercadorias raras", "preços e rotas comerciais", "histórias de viajantes", "contas e dívidas", "as notícias que chegam de outras cidades"]
		"curandeira": interest_pool = ["ervas medicinais", "plantas dos arredores", "doenças e remédios", "crenças populares sobre cura", "o bem-estar das famílias"]
		"estalajadeiro": interest_pool = ["histórias de viajantes", "comida e bebida", "as notícias que chegam de outras cidades", "os costumes dos frequentadores", "as estradas e suas caravanas"]
		"guarda": interest_pool = ["segurança das estradas", "leis e costumes locais", "rastros e animais", "histórias de viajantes", "o que acontece depois do pôr do sol"]
		_: interest_pool = []
	if interest_pool.is_empty():
		for interest_value in GENERAL_INTERESTS:
			interest_pool.append(str(interest_value))
	var interest_index: int = posmod(abs((npc_id + "|interest").hash()), interest_pool.size())
	var goal_index: int = posmod(abs((npc_id + "|goal").hash()), PERSONAL_GOALS.size())
	var social_raw: int = posmod(abs((npc_id + "|social").hash()), 76)
	var curiosity_raw: int = posmod(abs((npc_id + "|curiosity").hash()), 76)
	return {
		"speech_style": str(previous.get("speech_style", styles[style_index])),
		"personal_interest": str(previous.get("personal_interest", interest_pool[interest_index])),
		"personal_goal": str(previous.get("personal_goal", PERSONAL_GOALS[goal_index])),
		"sociability": float(previous.get("sociability", 0.25 + float(social_raw) / 100.0)),
		"curiosity": float(previous.get("curiosity", 0.25 + float(curiosity_raw) / 100.0))
	}


func get_conversation_clock() -> float:
	return _conversation_clock


func report_world_event(position: Vector3, event_kind: String, detail: String, informed_npc_id: String = "") -> void:
	# Os fatos são eventos do mundo, não apenas uma mensagem temporária. A lista
	# usa somente valores serializáveis e acompanha cada NPC entre carregamentos.
	_conversation_event_serial += 1
	var city_id := find_nearest_city(position)
	var event_place := _nearest_named_place(position, 150.0)
	var event := {
		"id": "%s_%d_%d" % [event_kind, int(Time.get_unix_time_from_system()), _conversation_event_serial],
		"kind": event_kind,
		"detail": detail,
		"city_id": city_id,
		"place_id": str(event_place.get("id", "")),
		"place_name": str(event_place.get("name", "")),
		"position": [position.x, position.y, position.z],
		"world_hour": _debug_hour,
		"informed_npc_id": informed_npc_id,
		"actor_id": "player" if event_kind == "monster_defeated" else "",
		"timestamp": int(Time.get_unix_time_from_system())
	}
	var witness_radius := CHAT_EVENT_WITNESS_RADIUS
	if event_kind == "monster_sighting":
		witness_radius = 42.0
	elif event_kind == "monster_defeated":
		witness_radius = 38.0
	elif event_kind == "quest_completed":
		witness_radius = 22.0
	var witnesses := 0
	for npc in _current_npc_nodes:
		if not is_instance_valid(npc) or not npc.has_method("remember_world_event"):
			continue
		var npc_id := str(npc.get("npc_id"))
		# O contratante sabe da entrega porque a recebeu, mesmo que esteja em casa
		# ou fora do raio visual. Outros habitantes só sabem se estavam por perto.
		if informed_npc_id != "" and npc_id == informed_npc_id:
			var received_event := event.duplicate(true)
			received_event["knowledge"] = "recipient"
			_remember_and_persist(npc, received_event, false)
			if event_kind == "quest_completed":
				_adjust_player_relationship(npc, 8.0, 6.0, "quest_completed")
			witnesses += 1
			continue
		if not bool(npc.visible):
			continue
		if _horizontal_distance(npc.global_position, position) > witness_radius:
			continue
		var witnessed_event := event.duplicate(true)
		witnessed_event["knowledge"] = "witness"
		_remember_and_persist(npc, witnessed_event, false)
		# Testemunhar o jogador protegendo a região muda a percepção pessoal desse
		# morador; não transforma, porém, isso em conhecimento compartilhado por toda cidade.
		if event_kind == "monster_defeated" and str(event.get("actor_id", "")) == "player":
			_adjust_player_relationship(npc, 1.5, 2.0, "monster_defeated")
		witnesses += 1
	# Os registros já foram atualizados em memória. Não reserializa a sociedade
	# inteira a cada morte/avistamento; o checkpoint periódico e a saída do mundo
	# garantem a persistência sem pausas durante o combate.
	var event_label := "criatura avistada" if event_kind == "monster_sighting" else "criatura derrotada" if event_kind == "monster_defeated" else "trabalho concluído" if event_kind == "quest_completed" else event_kind.replace("_", " ")
	var detail_text := detail if event_kind == "quest_completed" else _creature_phrase(detail)
	_log_debug("MUNDO", "%s: %s; %d testemunha(s)/informado(s) perto de %s." % [event_label, detail_text, witnesses, str(cities.get(city_id, {}).get("name", WORLD_NAMES.settlement_name(city_id)))], city_id)


func _adjust_player_relationship(npc: Node, familiarity_delta: float, trust_delta: float, action: String) -> void:
	if not is_instance_valid(npc):
		return
	var npc_id := str(npc.get("npc_id"))
	if npc_id == "":
		return
	var relation_value: Variant = npc.get("player_relationship")
	var relation: Dictionary = relation_value.duplicate(true) if relation_value is Dictionary else {}
	relation["familiarity"] = clampf(float(relation.get("familiarity", 0.0)) + familiarity_delta, 0.0, 100.0)
	relation["trust"] = clampf(float(relation.get("trust", 0.0)) + trust_delta, -100.0, 100.0)
	# Afeição é individual e persistente. Atos positivos vistos pelo NPC aumentam
	# a ligação pessoal sem transformar confiança em romance automaticamente.
	var affection_gain := maxf(0.0, familiarity_delta) * 0.12 + maxf(0.0, trust_delta) * 0.18
	relation["affection"] = clampf(float(relation.get("affection", 0.0)) + affection_gain, 0.0, 100.0)
	if action == "quest_completed":
		relation["gratitude"] = clampf(float(relation.get("gratitude", 0.0)) + 12.0, 0.0, 100.0)
		relation["completed_quests"] = int(relation.get("completed_quests", 0)) + 1
	elif action == "monster_defeated":
		relation["heroic_deeds_witnessed"] = int(relation.get("heroic_deeds_witnessed", 0)) + 1
	elif action == "player_tavern_round":
		relation["rounds_witnessed"] = int(relation.get("rounds_witnessed", 0)) + 1
	relation["last_player_action"] = action
	relation["last_action_timestamp"] = int(Time.get_unix_time_from_system())
	relation["stage"] = _player_relationship_stage(relation)
	npc.set("player_relationship", relation)
	if _active_records.has(npc_id):
		var record: Dictionary = _active_records[npc_id]
		record["player_relationship"] = relation.duplicate(true)
		_active_records[npc_id] = record
	if _previous_records.has(npc_id):
		var previous: Dictionary = _previous_records[npc_id]
		previous["player_relationship"] = relation.duplicate(true)
		_previous_records[npc_id] = previous


func record_player_flirt(npc: Node) -> String:
	if not is_instance_valid(npc):
		return "A conversa já terminou."
	if str(npc.get("age_stage")) != "adult":
		return "Prefiro manter nossa conversa amistosa."
	if bool(npc.get("is_unique_witch")) and str(npc.get("witch_state")) != "allied":
		return "Ainda não confio em você o bastante para esse tipo de aproximação."
	if str(npc.get("partner_id")) != "":
		return "Tenho um compromisso com outra pessoa e não quero dar a entender algo que não sinto."
	var npc_id := str(npc.get("npc_id"))
	if npc_id == "":
		return "Não foi possível registrar essa conversa."
	var relation_value: Variant = npc.get("player_relationship")
	var relation: Dictionary = relation_value.duplicate(true) if relation_value is Dictionary else {}
	var familiarity := float(relation.get("familiarity", 0.0))
	var affection := clampf(float(relation.get("affection", 0.0)) + 7.0, 0.0, 100.0)
	var romance := clampf(float(relation.get("romance", 0.0)) + (6.0 if familiarity >= 24.0 else 1.0), 0.0, 100.0)
	relation["affection"] = affection
	relation["romance"] = romance
	relation["flirt_attempts"] = int(relation.get("flirt_attempts", 0)) + 1
	relation["last_flirt_timestamp"] = int(Time.get_unix_time_from_system())
	relation["stage"] = _player_relationship_stage(relation)
	npc.set("player_relationship", relation)
	if _active_records.has(npc_id):
		var record: Dictionary = _active_records[npc_id]
		record["player_relationship"] = relation.duplicate(true)
		_active_records[npc_id] = record
	if _previous_records.has(npc_id):
		var previous: Dictionary = _previous_records[npc_id]
		previous["player_relationship"] = relation.duplicate(true)
		_previous_records[npc_id] = previous
	var allied_witch := bool(npc.get("is_unique_witch")) and str(npc.get("witch_state")) == "allied"
	if allied_witch:
		if familiarity >= 50.0 and affection >= 40.0 and romance >= 30.0:
			return "Achei que você nunca fosse tocar nesse assunto. Ainda bem que tocou."
		if affection >= 20.0:
			return "Então era por isso que você andava me olhando assim? Não digo que desgoste... mas não se acostume a me deixar sem resposta."
		return "Não esperava por isso. Me dê um tempo para pensar, está bem?"
	if familiarity < 24.0:
		return "Você parece gostar da minha companhia, mas ainda mal nos conhecemos. Prefiro ir com calma."
	if familiarity >= 50.0 and affection >= 40.0 and romance >= 30.0:
		return "Também tenho interesse em você. Vamos ver no que isso dá."
	if affection >= 20.0:
		return "Foi bom ouvir isso. Quero conhecer você melhor antes de decidir qualquer coisa."
	return "Você me pegou de surpresa. Ainda não sei como me sinto, então prefiro ir com calma."


func _normalize_world_event_memories(value: Variant) -> Array:
	var normalized: Array = []
	if not (value is Array):
		return normalized
	for event_value in value:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value.duplicate(true)
		var place_id := str(event.get("place_id", ""))
		var resolved_name := ""
		if buildings.has(place_id):
			resolved_name = str(buildings[place_id].get("name", ""))
		elif houses.has(place_id):
			resolved_name = str(houses[place_id].get("name", ""))
		else:
			for feature_value in _poi_features + _resource_features:
				if str(feature_value.get("id", "")) == place_id:
					resolved_name = str(feature_value.get("name", ""))
					break
		if resolved_name != "":
			event["place_name"] = resolved_name
		else:
			var legacy_name := str(event.get("place_name", ""))
			var legacy_regex := RegEx.new()
			legacy_regex.compile("(?i)^(ru[ií]nas?|acampamento|caverna|gruta|torre|santu[aá]rio|cripta)\\s*0*(\\d+)$")
			var legacy_match := legacy_regex.search(legacy_name.strip_edges())
			if legacy_match != null:
				var category := legacy_match.get_string(1).to_lower()
				var kind := "ruins"
				if category == "acampamento": kind = "camp"
				elif category in ["caverna", "gruta"]: kind = "cave"
				elif category == "torre": kind = "watchtower"
				elif category.begins_with("santu"): kind = "shrine"
				elif category == "cripta": kind = "dungeon"
				var poi_marker := "poi_%03d_%s" % [int(legacy_match.get_string(2)), kind]
				event["place_name"] = WORLD_NAMES.poi_name(poi_marker, kind)
		normalized.append(event)
	return normalized


func _nearest_named_place(position: Vector3, max_distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := max_distance
	for building_id_value in buildings.keys():
		var building: Dictionary = buildings[str(building_id_value)]
		if str(building.get("kind", "")) == "house": continue
		var distance := _horizontal_distance(position, building.get("entry", Vector3.ZERO))
		if distance < best_distance:
			best_distance = distance
			best = {"id": str(building.get("id", "")), "name": str(building.get("name", "")), "kind": str(building.get("kind", ""))}
	for feature in _poi_features + _resource_features:
		var distance := _horizontal_distance(position, feature.get("position", Vector3.ZERO))
		if distance < best_distance:
			best_distance = distance
			best = {"id": str(feature.get("id", "")), "name": str(feature.get("name", "")), "kind": str(feature.get("kind", ""))}
	return best


func _shared_known_place(first: Node, second: Node) -> Dictionary:
	var first_knowledge := get_world_knowledge_for_npc(first)
	var second_knowledge := get_world_knowledge_for_npc(second)
	var second_ids: Dictionary = {}
	for place_value in second_knowledge.get("known_places", []):
		if place_value is Dictionary: second_ids[str(place_value.get("id", ""))] = true
	var candidates: Array[Dictionary] = []
	for place_value in first_knowledge.get("known_places", []):
		if not (place_value is Dictionary): continue
		var place: Dictionary = place_value
		if not second_ids.has(str(place.get("id", ""))): continue
		if str(place.get("kind", "")) == "house": continue
		candidates.append(place)
	if candidates.is_empty(): return {}
	return candidates[randi_range(0, candidates.size() - 1)].duplicate(true)


func _shared_place_reply(npc: Node, place: Dictionary, other_name: String) -> String:
	var place_name := str(place.get("name", "esse lugar"))
	var description := str(place.get("description", "é um ponto conhecido da região"))
	if str(npc.get("personality")) == "desconfiado":
		return "Conheço o nome de %s. Ainda assim, prefiro não me aproximar sem um bom motivo." % place_name
	if str(place.get("kind", "")) in ["cave", "ruins", "camp", "watchtower", "dungeon", "mine"]:
		return "É melhor lembrar onde fica %s antes de precisar passar por lá, %s." % [place_name, other_name]
	return "Sim. %s %s." % [place_name, description]


func _shared_place_closing(npc: Node, place: Dictionary, other_name: String) -> String:
	if str(npc.get("personality")) == "curioso":
		return "Qualquer dia desses podemos passar por lá e ver se há algo que ainda não conhecemos, %s." % other_name
	if str(place.get("kind", "")) in ["shop", "inn", "workshop", "town_hall"]:
		return "É um dos lugares que fazem a cidade funcionar. Sempre há uma razão para saber onde fica, %s." % other_name
	return "Ao menos agora estamos falando do mesmo lugar, não de um rumor sem endereço, %s." % other_name


func record_player_interaction(npc: Node, context: Dictionary = {}) -> void:
	# A familiaridade é específica para cada pessoa e só cresce de verdade entre
	# encontros espaçados; abrir repetidamente a mesma conversa não cria amizade.
	if not is_instance_valid(npc):
		return
	var npc_id := str(npc.get("npc_id"))
	if npc_id == "":
		return
	var relation_value: Variant = npc.get("player_relationship")
	var relation: Dictionary = relation_value.duplicate(true) if relation_value is Dictionary else {}
	var visits := maxi(int(relation.get("conversations", 0)), int(npc.get("conversations_with_player")))
	var now_timestamp := int(Time.get_unix_time_from_system())
	var previous_timestamp := int(relation.get("last_interaction_timestamp", 0))
	var elapsed_real_seconds := now_timestamp - previous_timestamp if previous_timestamp > 0 else 0
	var familiarity_gain := 0.25
	if visits <= 1:
		familiarity_gain = 12.0
	elif elapsed_real_seconds >= 90:
		# O tempo real funciona entre sessões também; o relógio monotónico da cena
		# volta a zero quando o mundo é reconstruído.
		familiarity_gain = 4.0
	relation["conversations"] = visits
	relation["familiarity"] = minf(100.0, float(relation.get("familiarity", 0.0)) + familiarity_gain)
	var affection_gain := 0.35
	if visits <= 1:
		affection_gain = 1.0
	elif elapsed_real_seconds >= 90:
		affection_gain = 1.25
	relation["affection"] = clampf(float(relation.get("affection", 0.0)) + affection_gain, 0.0, 100.0)
	relation["last_interaction_clock"] = _conversation_clock
	relation["last_interaction_timestamp"] = now_timestamp
	relation["last_city_id"] = str(context.get("city_id", npc.get("city_id")))
	relation["last_city_name"] = str(context.get("city_name", npc.get("city_name")))
	relation["last_hour"] = float(context.get("hour", _debug_hour))
	relation["stage"] = _player_relationship_stage(relation)
	npc.set("player_relationship", relation)
	if _active_records.has(npc_id):
		var record: Dictionary = _active_records[npc_id]
		record["player_relationship"] = relation.duplicate(true)
		_active_records[npc_id] = record
	if _previous_records.has(npc_id):
		var previous: Dictionary = _previous_records[npc_id]
		previous["player_relationship"] = relation.duplicate(true)
		_previous_records[npc_id] = previous
	# A relação fica atualizada imediatamente na memória; gravação no checkpoint.


func _player_relationship_stage(relation: Dictionary) -> String:
	if (float(relation.get("familiarity", 0.0)) >= 50.0
		and float(relation.get("affection", 0.0)) >= 40.0
		and float(relation.get("romance", 0.0)) >= 30.0):
		return "romantic_interest"
	if float(relation.get("gratitude", 0.0)) >= 12.0:
		return "grateful"
	if float(relation.get("familiarity", 0.0)) >= 62.0:
		return "friend"
	if float(relation.get("familiarity", 0.0)) >= 24.0:
		return "known"
	if float(relation.get("familiarity", 0.0)) > 0.0:
		return "acquaintance"
	return "stranger"


func record_player_tavern_round(city_id: String, tavern_name: String, player_name: String) -> int:
	# Só quem está fisicamente na taverna se lembra da rodada paga pelo jogador.
	var count := 0
	var stamp := int(Time.get_unix_time_from_system())
	for npc in _current_npc_nodes:
		if not is_instance_valid(npc) or not bool(npc.get("is_interior_present")):
			continue
		if str(npc.get("city_id")) != city_id:
			continue
		var event := {
			"id": "player_tavern_round_%s_%s_%d" % [city_id, str(npc.get("npc_id")), stamp],
			"kind": "player_tavern_round",
			"detail": player_name,
			"city_id": city_id,
			"place_name": tavern_name,
			"actor_id": "player",
			"knowledge": "witness",
			"timestamp": stamp
		}
		_remember_and_persist(npc, event, false)
		_adjust_player_relationship(npc, 1.5, 0.5, "player_tavern_round")
		count += 1
	# A rodada e as reações dos presentes são persistidas no checkpoint seguinte.
	return count


func _remember_and_persist(npc, event: Dictionary, save_now: bool = true) -> void:
	if not is_instance_valid(npc) or not npc.has_method("remember_world_event"):
		return
	npc.remember_world_event(event)
	var npc_id := str(npc.get("npc_id"))
	if npc_id == "":
		return
	var memories: Array = npc.get("known_world_events")
	if _active_records.has(npc_id):
		var record: Dictionary = _active_records[npc_id]
		record["known_world_events"] = memories.duplicate(true)
		_active_records[npc_id] = record
	if _previous_records.has(npc_id):
		var previous: Dictionary = _previous_records[npc_id]
		previous["known_world_events"] = memories.duplicate(true)
		_previous_records[npc_id] = previous
	if save_now:
		_save_persistent_records()


func _tick_conversation_cooldowns(delta: float) -> void:
	for npc_id_value in _conversation_cooldowns.keys():
		var npc_id := str(npc_id_value)
		var remaining: float = float(_conversation_cooldowns[npc_id]) - delta
		if remaining <= 0.0:
			_conversation_cooldowns.erase(npc_id)
		else:
			_conversation_cooldowns[npc_id] = remaining


func _advance_conversation_sessions(delta: float) -> void:
	for index in range(_conversation_sessions.size() - 1, -1, -1):
		var session: Dictionary = _conversation_sessions[index]
		var timer: float = float(session.get("timer", 0.0)) + delta
		if timer < CHAT_TURN_SECONDS:
			session["timer"] = timer
			_conversation_sessions[index] = session
			continue
		var next_turn: int = int(session.get("turn", 0)) + 1
		var lines: Array = session.get("lines", [])
		var speakers: Array = session.get("speakers", [])
		if next_turn >= lines.size() or next_turn >= speakers.size():
			for participant in session.get("participants", []):
				if is_instance_valid(participant) and participant.has_method("end_ambient_conversation"):
					participant.end_ambient_conversation()
			_conversation_sessions.remove_at(index)
			continue
		for participant in session.get("participants", []):
			if is_instance_valid(participant) and participant.has_method("clear_ambient_line"):
				participant.clear_ambient_line()
		var speaker = speakers[next_turn]
		if is_instance_valid(speaker) and speaker.has_method("show_ambient_line") and bool(speaker.visible):
			speaker.show_ambient_line(str(lines[next_turn]), CHAT_TURN_SECONDS)
			_log_debug("FALA", "%s: %s" % [_person_first_name(speaker), str(lines[next_turn])], str(speaker.city_id))
		session["turn"] = next_turn
		session["timer"] = 0.0
		_conversation_sessions[index] = session


func _try_start_conversation(npc_nodes: Array, player_position: Vector3, hour: float) -> void:
	var candidates: Array = []
	var tavern_interior_active := _active_social_interior_id != "" and _active_social_interior_kind in ["inn", "tavern"]
	# Interiores são instanciados num plano de coordenadas separado. Sem este
	# filtro, um morador do exterior perto do centro do mapa poderia parecer vizinho.
	if _active_social_interior_id != "" and not tavern_interior_active:
		return
	for npc in npc_nodes:
		if not is_instance_valid(npc) or not npc.has_method("can_chat_ambiently"):
			continue
		if tavern_interior_active:
			if not bool(npc.get("is_interior_present")) or str(npc.get("interior_building_id")) != _active_social_interior_id:
				continue
		elif bool(npc.get("is_interior_present")):
			continue
		if not bool(npc.can_chat_ambiently()):
			continue
		if _conversation_cooldowns.has(str(npc.npc_id)):
			continue
		if _horizontal_distance(npc.global_position, player_position) > CHAT_PLAYER_DISTANCE:
			continue
		candidates.append(npc)
	if candidates.size() < 2:
		return
	# Avalia os pares próximos em vez de sortear pares aleatórios que quase nunca
	# se encontram. Isso permite que pessoas em movimento sejam paradas ao se cruzar.
	var possible_pairs: Array[Dictionary] = []
	for i in range(candidates.size()):
		var first = candidates[i]
		for j in range(i + 1, candidates.size()):
			var second = candidates[j]
			if str(first.city_id) != str(second.city_id):
				continue
			if _conversation_cooldowns.has(str(first.npc_id)) or _conversation_cooldowns.has(str(second.npc_id)):
				continue
			var distance: float = _horizontal_distance(first.global_position, second.global_position)
			if distance > CHAT_DISTANCE or distance < 1.25:
				continue
			var social_bonus := 0.0
			if _are_household_members(first, second):
				social_bonus += 1.7
			if _are_coworkers(first, second):
				social_bonus += 1.1
			var relation := _relationship_between(str(first.npc_id), str(second.npc_id))
			var familiarity := float(relation.get("familiarity", 0.0))
			social_bonus += minf(familiarity / 30.0, 2.6)
			if str(relation.get("stage", "")) == "partner":
				social_bonus += 2.2
			social_bonus += (float(first.get("sociability")) + float(second.get("sociability"))) * 0.7
			var score := distance - social_bonus + randf_range(0.0, 1.3)
			possible_pairs.append({"first": first, "second": second, "score": score})
	if possible_pairs.is_empty():
		return
	possible_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 99.0)) < float(b.get("score", 99.0))
	)
	var chosen: Dictionary = possible_pairs[0]
	_start_conversation(chosen["first"], chosen["second"], hour)


func _start_conversation(first, second, hour: float) -> void:
	var pair_ids: Array[String] = [str(first.npc_id), str(second.npc_id)]
	pair_ids.sort()
	var pair_key := "%s|%s" % [pair_ids[0], pair_ids[1]]
	var event := _best_shared_topic_event(first, second, pair_key)
	# O NPC que sabe do acontecimento é sempre o primeiro a falar. Isso impede que
	# a conversa atribua falsamente uma testemunha ou experiência ao outro morador.
	var source_id := str(event.get("_source_npc_id", ""))
	if source_id == str(second.npc_id):
		var swap = first
		first = second
		second = swap
	var event_id := str(event.get("id", ""))
	var recipient_already_knows := _npc_knows_event(second, event_id) if event_id != "" else true
	event.erase("_source_npc_id")
	event.erase("_score")
	var context: Dictionary = _build_conversation(first, second, hour, event)
	var lines: Array = context.get("lines", []).duplicate()
	if lines.size() < 2:
		return
	var conversation_topic := str(context.get("topic", "cotidiano"))
	# Conversas comuns nem sempre precisam de uma terceira fala que resuma tudo.
	# Acontecimentos importantes mantêm a troca completa para não perder informação.
	if lines.size() >= 3 and conversation_topic not in ["boato", "trabalho concluído", "generosidade", "segurança", "clima"] and randf() < 0.55:
		lines.remove_at(2)
	_record_social_interaction(first, second, conversation_topic)
	var speakers: Array = [first, second, first]
	for line_index in range(lines.size()):
		var speaker = speakers[line_index % speakers.size()]
		if is_instance_valid(speaker) and speaker.has_method("personalize_ambient_line"):
			lines[line_index] = speaker.personalize_ambient_line(str(lines[line_index]), str(context.get("topic", "cotidiano")), line_index)
	first.begin_ambient_conversation(str(second.npc_id))
	second.begin_ambient_conversation(str(first.npc_id))
	first.show_ambient_line(str(lines[0]), 3.0)
	_log_debug("CONVERSA", "%s e %s começaram a conversar sobre %s." % [_person_first_name(first), _person_first_name(second), str(context.get("topic", "cotidiano"))], str(first.city_id))
	_log_debug("FALA", "%s: %s" % [_person_first_name(first), str(lines[0])], str(first.city_id))
	_conversation_cooldowns[str(first.npc_id)] = CHAT_COOLDOWN_SECONDS
	_conversation_cooldowns[str(second.npc_id)] = CHAT_COOLDOWN_SECONDS
	var is_event_conversation := conversation_topic in ["boato", "trabalho concluído", "generosidade"]
	if not event.is_empty() and is_event_conversation:
		event_id = str(event.get("id", ""))
		_conversation_event_pairs["%s|%s" % [pair_key, event_id]] = true
		# Informação passa apenas do falante para quem ainda não a conhece. Boatos
		# preservam a origem e perdem confiança a cada nova transmissão.
		if not recipient_already_knows:
			var source_knowledge := str(event.get("knowledge", "witness"))
			var source_hops := int(event.get("rumor_hops", 0))
			var source_confidence := float(event.get("confidence", 1.0 if source_knowledge != "heard" else 0.72))
			var next_hops := source_hops + 1
			var next_confidence := source_confidence * (0.78 if source_knowledge == "heard" else 0.88)
			if next_hops <= 3 and next_confidence >= 0.30:
				var heard_event := event.duplicate(true)
				heard_event["knowledge"] = "heard"
				heard_event["heard_from"] = str(first.npc_id)
				heard_event["heard_from_name"] = _person_first_name(first)
				heard_event["rumor_hops"] = next_hops
				heard_event["confidence"] = next_confidence
				heard_event["last_heard_timestamp"] = int(Time.get_unix_time_from_system())
				_remember_and_persist(second, heard_event, false)
				_log_debug("RUMOR", "%s ouviu de %s: %s (confiança %.0f%%)." % [_person_first_name(second), _person_first_name(first), str(event.get("detail", event.get("kind", "notícia"))), next_confidence * 100.0], str(second.city_id))
	var session := {"pair": pair_key, "participants": [first, second], "speakers": speakers, "lines": lines, "turn": 0, "timer": 0.0, "topic": str(context.get("topic", "cotidiano"))}
	_conversation_sessions.append(session)
	if _conversation_sessions.size() > 24:
		var oldest: Dictionary = _conversation_sessions.pop_front()
		for participant in oldest.get("participants", []):
			if is_instance_valid(participant) and participant.has_method("end_ambient_conversation"):
				participant.end_ambient_conversation()


func _npc_knows_event(npc: Node, event_id: String) -> bool:
	if event_id == "" or not is_instance_valid(npc):
		return false
	var memory_value: Variant = npc.get("known_world_events")
	if not (memory_value is Array):
		return false
	for memory in memory_value:
		if memory is Dictionary and str(memory.get("id", "")) == event_id:
			return true
	return false


func _best_shared_topic_event(first, second, pair_key: String) -> Dictionary:
	var first_events: Dictionary = {}
	var second_events: Dictionary = {}
	var first_memories: Variant = first.get("known_world_events")
	var second_memories: Variant = second.get("known_world_events")
	if first_memories is Array:
		for event_value in first_memories:
			if event_value is Dictionary:
				first_events[str(event_value.get("id", ""))] = event_value
	if second_memories is Array:
		for event_value in second_memories:
			if event_value is Dictionary:
				second_events[str(event_value.get("id", ""))] = event_value
	var candidates: Array[Dictionary] = []
	for source in [first, second]:
		var memories: Variant = source.get("known_world_events")
		if not (memories is Array):
			continue
		var other_id := str(second.npc_id) if str(source.npc_id) == str(first.npc_id) else str(first.npc_id)
		var other_events: Dictionary = second_events if other_id == str(second.npc_id) else first_events
		for event_value in memories:
			if not (event_value is Dictionary):
				continue
			var event: Dictionary = event_value
			var event_id := str(event.get("id", ""))
			if event_id == "" or _conversation_event_pairs.has("%s|%s" % [pair_key, event_id]):
				continue
			var hops := int(event.get("rumor_hops", 0))
			var confidence := float(event.get("confidence", 1.0 if str(event.get("knowledge", "witness")) != "heard" else 0.72))
			if hops >= 3 or confidence < 0.30:
				continue
			var other_knows := other_events.has(event_id)
			var knowledge := str(event.get("knowledge", "witness"))
			var quality := 3.0 if knowledge in ["witness", "recipient"] else 1.0
			var event_recency := maxf(float(event.get("timestamp", 0.0)), float(event.get("last_heard_timestamp", 0.0)))
			var age_hours := maxf(0.0, (float(Time.get_unix_time_from_system()) - event_recency) / 3600.0)
			var recency_bonus := maxf(0.0, 3.0 - age_hours * 0.25)
			var score := recency_bonus + confidence * 2.0 + quality
			if not other_knows:
				score += 100.0
			var candidate: Dictionary = event.duplicate(true)
			candidate["_source_npc_id"] = str(source.npc_id)
			candidate["_score"] = score
			candidates.append(candidate)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("_score", 0.0)) > float(b.get("_score", 0.0))
	)
	if randf() < 0.72:
		return candidates[0]
	return {}


func _build_conversation(first, second, hour: float, event: Dictionary) -> Dictionary:
	# Cada conversa é construída como um pequeno diálogo com assunto definido:
	# a segunda fala responde à pergunta/afirmação da primeira e a terceira fecha
	# o mesmo assunto, em vez de sortear três frases sem relação entre si.
	var a_name := _person_first_name(first)
	var b_name := _person_first_name(second)
	var a_personality := str(first.personality)
	var b_personality := str(second.personality)
	var lines: Array[String] = []
	var relation := _relationship_between(str(first.npc_id), str(second.npc_id))
	var relation_stage := str(relation.get("stage", "stranger"))

	if not event.is_empty():
		var creature := _creature_phrase(str(event.get("detail", "criaturas")))
		var event_kind := str(event.get("kind", ""))
		if event_kind == "player_tavern_round":
			var tavern_name := str(event.get("place_name", "a estalagem"))
			lines.append("%s, parece que %s pagou uma rodada em %s." % [b_name, str(event.get("detail", "um viajante")), tavern_name])
			if b_personality == "desconfiado":
				lines.append("Pode ter sido generosidade ou vontade de chamar atenção. De qualquer forma, quem estava lá vai se lembrar.")
			else:
				lines.append("Aposto que amanhã alguém vai perguntar quem pagou. Essas coisas não passam despercebidas por aqui.")
			lines.append("Quem estava lá vai falar disso amanhã, pode apostar, %s." % b_name)
			return {"lines": lines, "topic": "generosidade"}
		if event_kind == "quest_completed":
			var quest_title := str(event.get("detail", "trabalho"))
			var quest_knowledge := str(event.get("knowledge", "witness"))
			if quest_knowledge == "witness":
				lines.append("%s, vi que o trabalho '%s' foi concluído." % [b_name, quest_title])
			elif quest_knowledge == "heard":
				lines.append("%s, ouvi dizer que o trabalho '%s' foi concluído, mas ainda não sei todos os detalhes." % [b_name, quest_title])
			else:
				lines.append("%s, fiquei sabendo que o trabalho '%s' foi concluído." % [b_name, quest_title])
			if b_personality == "desconfiado":
				lines.append("Bom, espero que tenham cumprido tudo direito. Pelo menos agora sabemos que alguém cuidou disso.")
			elif b_personality == "bem-humorado":
				lines.append("Uma tarefa a menos para preocupar a cidade. Isso já merece uma caneca depois do expediente.")
			else:
				lines.append("Tomara que a estrada fique livre agora. A última carroça que veio de lá chegou atrasada.")
			lines.append("Vou ficar de olho nos próximos dias. Não quero descobrir tarde demais que voltou, %s." % b_name)
			return {"lines": lines, "topic": "trabalho concluído"}
		var event_place_name := str(event.get("place_name", ""))
		if event_kind == "monster_sighting":
			var sighting_knowledge := str(event.get("knowledge", "witness"))
			var sighting_line := "%s, vi movimento estranho na estrada. Pareciam %s." % [b_name, creature]
			if event_place_name != "": sighting_line = "%s, vi movimento estranho perto de %s. Pareciam %s." % [b_name, event_place_name, creature]
			if sighting_knowledge == "heard":
				sighting_line = "%s, ouvi dizer que havia movimento estranho na estrada. Falavam de %s, mas não sei se a história está inteira." % [b_name, creature]
				if event_place_name != "": sighting_line = "%s, ouvi dizer que havia movimento estranho perto de %s. Falavam de %s, mas não sei se a história está inteira." % [b_name, event_place_name, creature]
			elif sighting_knowledge == "recipient":
				sighting_line = "%s, recebi um aviso sobre movimento estranho na estrada. Ainda não vi por mim mesmo." % b_name
				if event_place_name != "": sighting_line = "%s, recebi um aviso sobre movimento estranho perto de %s. Ainda não vi por mim mesmo." % [b_name, event_place_name]
			lines.append(sighting_line)
			lines.append(_event_reply_context(second, a_name, creature, event_kind, b_personality, sighting_knowledge))
			lines.append(_event_closing_context(first, b_name, creature, event_kind, a_personality, sighting_knowledge))
		else:
			var event_line := "%s, parece que alguém enfrentou %s por aqui." % [b_name, creature]
			if event_place_name != "": event_line = "%s, parece que alguém enfrentou %s perto de %s." % [b_name, creature, event_place_name]
			lines.append(event_line)
			var confrontation_knowledge := str(event.get("knowledge", "witness"))
			lines.append(_event_reply_context(second, a_name, creature, event_kind, b_personality, confrontation_knowledge))
			lines.append(_event_closing_context(first, b_name, creature, event_kind, a_personality, confrontation_knowledge))
		return {"lines": lines, "topic": "boato"}

	if relation_stage == "partner":
		lines = _partner_conversation(first, second, hour, relation)
		return {"lines": lines, "topic": "relacionamento"}

	if _active_social_interior_id != "" and _active_social_interior_kind in ["inn", "tavern"] and bool(first.get("is_interior_present")) and str(first.get("interior_building_id")) == _active_social_interior_id:
		return _build_tavern_ambient_conversation(first, second, hour, relation)

	var threat := _regional_threat_for_city(str(first.city_id))
	var weather := int(_world.get("current_weather")) if _world != null and is_instance_valid(_world) else 0
	# Conversas entre moradores usam o clima do lugar em que eles estão, não
	# obrigatoriamente o clima da região onde o jogador está explorando.
	if _world != null and is_instance_valid(_world) and _world.has_method("get_weather_at_position") and is_instance_valid(first):
		weather = int(_world.call("get_weather_at_position", first.global_position))
	if threat >= 62.0 and randf() < 0.62:
		lines.append("%s, as estradas estão perigosas demais ultimamente." % b_name)
		lines.append(_threat_reply(second, a_name, b_personality))
		lines.append(_threat_closing(first, b_name, a_personality))
		return {"lines": lines, "topic": "segurança"}

	if weather >= 2 and randf() < 0.65:
		if weather == 3:
			lines.append("%s, não gosto nem um pouco dessas trovoadas." % b_name)
			lines.append(_storm_reply(second, b_personality))
			lines.append(_storm_closing(first, b_name, a_personality))
		elif weather == 5:
			lines.append("%s, essa nevasca vai apagar as trilhas e fechar as passagens." % b_name)
			lines.append(_snowstorm_reply(second, b_personality))
			lines.append(_snowstorm_closing(first, b_name, a_personality))
		elif weather == 4:
			lines.append("%s, a neve está cobrindo a estrada. A viagem vai ser mais lenta." % b_name)
			lines.append(_snow_reply(second, b_name, b_personality))
			lines.append(_snow_closing(first, a_personality))
		else:
			lines.append("%s, essa chuva vai transformar a estrada num lamaçal." % b_name)
			lines.append(_weather_reply(second, b_name, b_personality))
			lines.append(_weather_closing(first, a_personality))
		return {"lines": lines, "topic": "clima"}

	if _are_household_members(first, second):
		lines.append("%s, você volta para casa depois daqui?" % b_name)
		lines.append(_home_reply(second, a_name, b_personality))
		lines.append(_home_followup(first, b_name, a_personality))
		return {"lines": lines, "topic": "casa"}

	if _are_coworkers(first, second):
		lines.append(_work_opening(first, second, b_name, a_personality))
		lines.append(_work_reply_for_context(second, a_name, str(first.role), b_personality))
		lines.append(_work_closing(first, b_name, a_personality))
		return {"lines": lines, "topic": "trabalho"}

	if str(first.role) == "guarda" or str(second.role) == "guarda":
		if str(second.role) == "guarda":
			lines.append("%s, a ronda correu tranquila hoje?" % b_name)
			lines.append(_guard_reply(second, a_name, b_personality))
			lines.append(_guard_followup(first, b_name, a_personality))
		else:
			lines.append("%s, evite a estrada depois do portão; a região anda perigosa." % b_name)
			lines.append(_road_warning_reply(second, a_name, b_personality))
			lines.append(_road_warning_followup(first, b_name, a_personality))
		return {"lines": lines, "topic": "guarda"}

	# Às vezes, a conversa parte de um lugar concreto que ambos conhecem. Isso
	# conecta rotinas e geografia sem dar a nenhum NPC conhecimento universal.
	if randf() < 0.24:
		var shared_place := _shared_known_place(first, second)
		if not shared_place.is_empty():
			lines.append("%s, você conhece %s?" % [b_name, str(shared_place.get("name", "esse lugar"))])
			lines.append(_shared_place_reply(second, shared_place, a_name))
			lines.append(_shared_place_closing(first, shared_place, b_name))
			return {"lines": lines, "topic": "lugares locais"}

	var personal_topic := _personal_topic_for_npc(first, hour)
	# Evita que o mesmo par volte sempre ao mesmo assunto. O vínculo aparece pelo
	# que compartilham, não por uma frase carinhosa adicionada mecanicamente.
	if str(relation.get("last_topic", "")) == personal_topic:
		var second_topic := _personal_topic_for_npc(second, hour)
		if second_topic != personal_topic:
			personal_topic = second_topic
		else:
			personal_topic = "cotidiano"
	lines.append(_personal_opening_for_topic(first, b_name, hour, personal_topic))
	lines.append(_personal_context_reply(second, a_name, personal_topic, b_personality))
	lines.append(_personal_context_followup(first, b_name, personal_topic, a_personality))
	return {"lines": lines, "topic": personal_topic}


func _build_tavern_ambient_conversation(first, second, hour: float, relation: Dictionary) -> Dictionary:
	var a_name := _person_first_name(first)
	var b_name := _person_first_name(second)
	var b_personality := str(second.get("personality"))
	var a_personality := str(first.get("personality"))
	var turn_seed := str(first.get("npc_id")) + "|" + str(second.get("npc_id")) + "|tavern|" + str(int(first.get("ambient_speech_count")))
	var topic_index := posmod(abs(turn_seed.hash()), 5)
	var lines: Array[String] = []
	match topic_index:
		0:
			lines.append("%s, já provou o ensopado de hoje? O cheiro está melhor do que ontem." % b_name)
			if b_personality == "desconfiado":
				lines.append("Provei. É bom, mas eu ainda confirmo o preço antes de pedir a segunda tigela.")
			elif b_personality == "bem-humorado":
				lines.append("Provei, sim. Se continuar assim, vou começar a vir aqui pelo cozinheiro e não pela conversa.")
			else:
				lines.append("Ainda não, mas estava pensando nisso. Uma refeição quente cai bem depois de um dia inteiro na rua.")
			lines.append("Então peça antes que esfrie. Pelo menos nisso, a estalagem raramente decepciona, %s." % b_name)
			return {"lines": lines, "topic": "comida da estalagem"}
		1:
			lines.append("%s, ouviu alguma notícia das estradas hoje?" % b_name)
			if b_personality == "fofoqueiro":
				lines.append("Ouvi duas versões da mesma história. Estou tentando descobrir qual delas mudou mais a cada mesa.")
			elif b_personality == "desconfiado":
				lines.append("Só ouvi comentários. Até alguém confirmar, prefiro tratar tudo como rumor.")
			else:
				lines.append("Nada que eu possa garantir. Mas viajantes costumam trazer notícias quando o salão começa a encher.")
			lines.append("É por isso que gosto de parar aqui. Uma conversa de mesa às vezes vale mais que um aviso pregado no portão, %s." % b_name)
			return {"lines": lines, "topic": "rumores da estrada"}
		2:
			lines.append("%s, você vem sempre a esta estalagem ou só quando o trabalho deixa?" % b_name)
			if str(second.get("role")) == "ferreiro":
				lines.append("Quando termino o serviço. Não dá para martelar ferro a noite inteira e esperar continuar de bom humor.")
			elif str(second.get("role")) == "mensageiro":
				lines.append("Quando estou na cidade. Se venho de viagem, uma cadeira e um teto já são um luxo.")
			elif str(second.get("role")) == "curandeira":
				lines.append("Depois de atender quem precisa. Também tenho de descansar, por mais que as ervas esperem por mim.")
			else:
				lines.append("Sempre que posso. É bom encontrar rostos conhecidos sem precisar marcar hora para isso.")
			lines.append("É esse o costume daqui: cada um chega quando pode, e alguém acaba puxando conversa, %s." % b_name)
			return {"lines": lines, "topic": "frequentadores"}
		3:
			lines.append("%s, o salão está mais cheio do que costuma ficar nesta hora." % b_name)
			if hour >= 20.0 or hour < 5.0:
				lines.append("A noite traz quem terminou o turno e quem não quer enfrentar a estrada no escuro.")
			else:
				lines.append("Talvez os viajantes tenham chegado juntos. Pelo menos o estalajadeiro deve estar satisfeito.")
			lines.append("Enquanto ninguém começa uma briga, movimento costuma ser bom para todos, %s." % b_name)
			return {"lines": lines, "topic": "movimento da estalagem"}
		_:
			lines.append("%s, parece que sempre encontramos alguém diferente por aqui." % b_name)
			if a_personality == "reservado" or b_personality == "reservado":
				lines.append("Gosto disso. Posso ouvir as histórias sem precisar contar a minha inteira.")
			elif b_personality == "bem-humorado":
				lines.append("E quase sempre alguém sabe quem deixou a última rodada sem pagar. A cidade tem seus mistérios.")
			else:
				lines.append("Uma estalagem acaba juntando gente que talvez nunca se encontrasse na rua.")
			lines.append("É uma das poucas coisas boas de parar no mesmo lugar de vez em quando, %s." % b_name)
			return {"lines": lines, "topic": "vida na cidade"}


func _partner_conversation(first, second, hour: float, relation: Dictionary) -> Array[String]:
	var a_name := _person_first_name(first)
	var b_name := _person_first_name(second)
	var lines: Array[String] = []
	if hour >= 20.0 or hour < 6.0:
		lines.append("%s, vamos voltar juntos? Já está ficando tarde." % b_name)
		if str(second.personality) == "bem-humorado":
			lines.append("Vamos. Desde que você não me faça correr até a porta.")
		else:
			lines.append("Vamos, sim. Gosto mais de caminhar quando você está comigo.")
		lines.append("Então fico ao seu lado. Não quero que a gente se perca no escuro, %s." % b_name)
	else:
		lines.append("%s, como foi seu dia? Espero que não tenha sido tão cansativo quanto o meu." % b_name)
		if str(second.personality) == "reservado":
			lines.append("Foi puxado, mas conversar um pouco com você já ajuda.")
		elif str(second.personality) == "bem-humorado":
			lines.append("Sobrevivi. Acho que mereço uma refeição e uma cadeira confortável.")
		else:
			lines.append("Foi cheio, mas tenho uma coisa boa para contar quando tivermos tempo.")
		lines.append("Quero ouvir tudo depois. Vamos arranjar um momento só nosso, %s." % b_name)
	return lines


func _personal_topic_for_npc(npc, hour: float) -> String:
	if hour >= 20.0 or hour < 6.0:
		if str(npc.personality) == "desconfiado":
			return "noite"
	var interest := str(npc.get("personal_interest")).to_lower()
	if interest.contains("taverna") or interest.contains("comida"):
		return "comida"
	if interest.contains("história") or interest.contains("armas antigas") or interest.contains("artesãos"):
		return "história"
	if interest.contains("costumes") or interest.contains("leis"):
		return "costumes"
	if interest.contains("canções") or interest.contains("festas"):
		return "festas"
	if interest.contains("animais") or interest.contains("rastros"):
		return "animais"
	if interest.contains("estradas") or interest.contains("viajantes") or interest.contains("segurança"):
		return "viagens"
	if interest.contains("deuses") or interest.contains("presságios"):
		return "deuses"
	if interest.contains("ferramentas") or interest.contains("ofícios") or interest.contains("metalurgia") or interest.contains("trabalhos manuais"):
		return "ofício"
	if interest.contains("preços") or interest.contains("minério") or interest.contains("mercado") or interest.contains("comerciais"):
		return "preços"
	if interest.contains("famílias") or interest.contains("família") or interest.contains("bem-estar"):
		return "família"
	if interest.contains("ervas") or interest.contains("plantas"):
		return "ervas"
	if interest.contains("notícias") or interest.contains("rumores") or interest.contains("outras cidades"):
		return "notícias"
	if interest.contains("doenças") or interest.contains("remédios") or interest.contains("cura"):
		return "cura"
	if interest.contains("contas") or interest.contains("dívidas"):
		return "dívidas"
	if interest.contains("mercadorias") or interest.contains("raras"):
		return "mercadorias"
	if interest.contains("pôr do sol") or interest.contains("noite"):
		return "noite"
	if str(npc.role) == "ferreiro":
		return "ofício"
	if str(npc.role) == "curandeira":
		return "ervas"
	if str(npc.role) == "mercador":
		return "preços"
	if str(npc.role) == "guarda":
		return "viagens"
	return "cotidiano"


func _known_history_place_for_npc(npc) -> Dictionary:
	# O morador só cita lugares presentes no próprio conhecimento geográfico.
	var places_value: Variant = npc.get("known_places")
	if not (places_value is Array):
		return {}
	var candidates: Array[Dictionary] = []
	for place_value in places_value:
		if not (place_value is Dictionary):
			continue
		var place: Dictionary = place_value
		if str(place.get("kind", "")) in ["ruins", "dungeon", "shrine", "landmark"]:
			candidates.append(place)
	if candidates.is_empty():
		return {}
	var seed := str(npc.get("npc_id")) + "|history-place|" + str(npc.get("ambient_speech_count"))
	var index := posmod(absi(seed.hash()), candidates.size())
	return candidates[index]


func _personal_opening_for_topic(npc, other_name: String, hour: float, topic: String) -> String:
	var choices: Array[String] = []
	match topic:
		"comida": choices = [
			"%s, já provou o ensopado de hoje?" % other_name,
			"%s, dizem que a cozinha mudou a receita. Você percebeu?" % other_name,
			"%s, você acha que a comida daqui vale o preço?" % other_name
		]
		"história":
			var historic_place := _known_history_place_for_npc(npc)
			if not historic_place.is_empty():
				var place_name := str(historic_place.get("name", "este lugar"))
				var place_kind := str(historic_place.get("kind", ""))
				if place_kind == "ruins":
					choices = [
						"%s, já ouviu alguma história sobre %s?" % [other_name, place_name],
					"%s, sabe o que havia em %s antes de aquilo virar ruína?" % [other_name, place_name],
					"%s, cada pessoa conta uma versão diferente sobre %s. Qual você ouviu?" % [other_name, place_name]
					]
				else:
					choices = [
						"%s, já ouviu alguma história antiga sobre %s?" % [other_name, place_name],
					"%s, sabe quem costumava frequentar %s?" % [other_name, place_name],
					"%s, dizem coisas diferentes sobre %s. O que você ouviu?" % [other_name, place_name]
					]
			else:
				choices = [
					"%s, ouviu alguma história antiga sobre estas terras?" % other_name,
					"%s, há algum lugar antigo por aqui cuja história você gostaria de conhecer?" % other_name,
					"%s, os mais velhos ainda contam histórias sobre a região?" % other_name
				]
		"costumes": choices = [
			"%s, acha que os costumes daqui mudaram muito nos últimos anos?" % other_name,
			"%s, tem alguma tradição daqui que você acha estranha?" % other_name,
			"%s, os mais velhos ainda insistem em fazer tudo como antigamente?" % other_name
		]
		"festas": choices = [
			"%s, faz tempo que não temos uma festa de verdade por aqui, não acha?" % other_name,
			"%s, você se lembra da última vez que a praça ficou cheia para uma festa?" % other_name,
			"%s, será que alguém ainda vai organizar a festa da colheita este ano?" % other_name
		]
		"animais": choices = [
			"%s, viu algum animal estranho nos arredores ultimamente?" % other_name,
			"%s, os bichos têm aparecido perto dos campos depois da chuva?" % other_name,
			"%s, você entende de rastros? Encontrei uns que não reconheci." % other_name
		]
		"viagens": choices = [
			"%s, tem encontrado muita gente viajando por estas estradas?" % other_name,
			"%s, sabe se as carroças têm conseguido passar pela rota do norte?" % other_name,
			"%s, viu algum viajante chegar de fora hoje?" % other_name
		]
		"deuses": choices = [
			"%s, você costuma prestar atenção aos presságios ou acha que é conversa fiada?" % other_name,
			"%s, em qual dos Sete sua família costuma confiar quando as coisas apertam?" % other_name,
			"%s, você acha que os deuses deixam sinais ou somos nós que procuramos por eles?" % other_name
		]
		"ofício": choices = [
			"%s, para você, o que faz um trabalho valer o preço cobrado?" % other_name,
			"%s, já teve de consertar algo que outra pessoa fez às pressas?" % other_name,
			"%s, prefere uma ferramenta simples que dura ou uma bonita que dá trabalho?" % other_name
		]
		"preços": choices = [
			"%s, reparou como os preços andam mudando ultimamente?" % other_name,
			"%s, o que ficou mais caro desde a última estação?" % other_name,
			"%s, você costuma negociar ou paga logo para se livrar disso?" % other_name
		]
		"família": choices = [
			"%s, sua família está bem? Esses dias tenho pensado bastante nisso." % other_name,
			"%s, consegue reservar um tempo para os seus depois do trabalho?" % other_name,
			"%s, tem alguém da sua família morando em outra cidade?" % other_name
		]
		"ervas": choices = [
			"%s, conhece alguma planta que cresça melhor nesta época do ano?" % other_name,
			"%s, depois da chuva, você sabe onde encontrar folha-prateada?" % other_name,
			"%s, já viu alguém usar uma erva de um jeito que realmente funcionasse?" % other_name
		]
		"notícias": choices = [
			"%s, chegou alguma notícia de fora? Faz tempo que não ouço nada novo." % other_name,
			"%s, algum mensageiro passou por aqui hoje?" % other_name,
			"%s, ouviu algo de alguém que realmente veio de outra cidade?" % other_name
		]
		"cura": choices = [
			"%s, ouviu algum conselho de cura que parecesse absurdo, mas funcionasse?" % other_name,
			"%s, você confia em remédios caseiros ou prefere procurar a curandeira?" % other_name,
			"%s, já viu um remédio popular fazer mais mal do que bem?" % other_name
		]
		"dívidas": choices = [
			"%s, parece que todo mundo deve alguma coisa a alguém ultimamente." % other_name,
			"%s, você consegue guardar moedas ou sempre aparece uma despesa nova?" % other_name,
			"%s, já teve de adiar uma compra porque alguém precisava receber primeiro?" % other_name
		]
		"mercadorias": choices = [
			"%s, qual foi a coisa mais incomum que já viu à venda?" % other_name,
			"%s, já comprou algo que parecia inútil e acabou salvando seu dia?" % other_name,
			"%s, que tipo de mercadoria anda difícil de encontrar por aqui?" % other_name
		]
		"noite": choices = [
			"%s, ouviu barulho na rua durante a noite passada?" % other_name,
			"%s, você dorme bem com esse silêncio todo ou ele incomoda?" % other_name,
			"%s, tem alguma coisa que evita fazer depois de escurecer?" % other_name
		]
		"cotidiano": return _coherent_daily_opening(npc, other_name, hour)
		_: return "Como anda o dia, %s?" % other_name
	return _ambient_variant(npc, topic, choices, hour)


func _ambient_variant(npc, topic: String, choices: Array[String], hour: float) -> String:
	if choices.is_empty():
		return "Como anda o dia?"
	var count := int(npc.get("ambient_speech_count"))
	var seed := (str(npc.get("npc_id")) + "|" + topic + "|" + str(int(hour)) + "|" + str(count)).hash()
	var recent_value: Variant = npc.get("recent_ambient_lines")
	var recent: Array = recent_value if recent_value is Array else []
	var initial_index := posmod(abs(seed), choices.size())
	for offset in range(choices.size()):
		var candidate := choices[posmod(initial_index + offset, choices.size())]
		if not recent.has(candidate):
			return candidate
	return choices[initial_index]


func _coherent_daily_opening(npc, other_name: String, hour: float) -> String:
	if hour >= 20.0 or hour < 6.0:
		return "%s, já está voltando para casa? As ruas ficam quietas a esta hora." % other_name
	match str(npc.personality):
		"curioso": return "%s, aconteceu alguma coisa interessante hoje?" % other_name
		"fofoqueiro": return "%s, ouviu alguma novidade pela cidade?" % other_name
		"desconfiado": return "As coisas estão quietas demais por aqui, %s." % other_name
		"bem-humorado": return "%s, já teve um dia pior que este. Acho." % other_name
		_: return "Como anda o dia, %s?" % other_name


func _personal_context_reply(npc, other_name: String, topic: String, personality: String) -> String:
	# O jeito de falar muda a resposta sem obrigar todo mundo a repetir o mesmo bordão.
	var style := str(npc.get("speech_style"))
	if style == "formal" and topic in ["notícias", "viagens", "preços"]:
		return "Ainda não tenho informação bastante para afirmar isso. Prefiro esperar uma confirmação a passar adiante uma história errada."
	if style == "ironico" and topic == "preços":
		return "Subiu, claro. Parece que até as moedas ficam mais leves quando chega a hora de pagar."
	if style == "ironico" and topic == "trabalho":
		return "O trabalho terminou; agora só falta o resto do dia parar de inventar mais trabalho."
	if style == "supersticioso" and topic in ["clima", "deuses"]:
		return "Minha família sempre levou esses sinais a sério. Não sei se explicam tudo, mas também não gosto de ignorá-los."
	if style == "observador" and topic == "animais":
		return "Repare nas pegadas depois da próxima chuva. A direção costuma dizer mais do que o tamanho."
	if style == "observador" and topic == "viagens":
		return "Hoje vi menos carroças do que de costume. Talvez não signifique nada, mas vou prestar atenção amanhã."
	if style == "coloquial" and topic == "comida":
		return "Se está quente e enche a barriga, já ganhou metade da minha aprovação."
	if style == "poetico" and topic == "noite":
		return "De noite, até as ruas conhecidas parecem esconder outra vida."
	if style == "pratico" and topic == "ervas":
		return "Colha só o que souber identificar. Erva errada não vira remédio só porque alguém está com pressa."
	match topic:
		"comida":
			if personality == "bem-humorado": return "Já provei. É bom, embora eu suspeite que o cozinheiro esconda o sal para economizar."
			if personality == "reservado": return "Ainda não. Talvez eu experimente depois do trabalho."
			return "Provei ontem. É simples, mas sustenta bem depois de um dia cansativo."
		"história":
			if personality == "curioso": return "Ouvi uma sobre as ruínas ao norte, mas ninguém concorda sobre o que aconteceu lá."
			if personality == "desconfiado": return "Ouvi algumas, mas cada pessoa muda os detalhes. Prefiro não acreditar em tudo."
			return "Meu avô contava que as estradas daqui já eram antigas antes de a cidade crescer."
		"costumes":
			if personality == "bem-humorado": return "Mudaram. Agora reclamamos dos mesmos problemas, mas com palavras diferentes."
			return "Um pouco. Os mais velhos ainda seguem as tradições, mas os jovens fazem as coisas à própria maneira."
		"festas":
			if personality == "bem-humorado": return "Concordo. Uma festa dessas ajudaria a esquecer as contas por uma noite."
			return "Também sinto falta. A praça fica mais viva quando as pessoas têm um motivo para se reunir."
		"animais":
			if personality == "curioso": return "Vi rastros perto dos campos. Não sei de que animal eram, mas quero descobrir."
			if personality == "desconfiado": return "Vi alguns rastros, mas mantive distância. Não vale a pena se arriscar sem saber o que é."
			return "Só os animais de sempre perto dos campos. Nada que parecesse ameaçador."
		"viagens":
			if personality == "fofoqueiro": return "Mais do que o normal, e cada viajante traz uma versão diferente das notícias."
			if personality == "desconfiado": return "Poucos param por aqui. Com as estradas assim, não os culpo por seguir depressa."
			return "Vi alguns mercadores e dois viajantes esta manhã. O movimento parece normal."
		"deuses":
			if str(npc.get("speech_style")) == "supersticioso": return "Presto atenção, sim. Minha avó dizia que certos sinais aparecem antes das desgraças."
			if personality == "pratico": return "Respeito as crenças, mas prefiro julgar pelas coisas que posso observar."
			return "Não sei dizer. Às vezes uma coincidência parece um sinal, até entendermos melhor."
		"ofício":
			if str(npc.role) == "ferreiro": return "Materiais bons e trabalho cuidadoso. Uma peça barata que quebra cedo acaba custando mais."
			if personality == "pratico": return "Tem que durar e cumprir sua função. Enfeite nenhum compensa uma ferramenta ruim."
			return "O cuidado de quem fez. Dá para notar quando alguém não tentou terminar o serviço às pressas."
		"preços":
			if str(npc.role) == "mercador": return "O preço muda com a oferta e com o risco da rota. Quando uma estrada fica perigosa, tudo encarece."
			if personality == "desconfiado": return "Subiram em alguns produtos. Estou esperando para ver se é falta de mercadoria ou ganância."
			return "Algumas coisas subiram, outras não. Vou comparar os preços antes de comprar mais."
		"família":
			if personality == "reservado": return "Estão bem, obrigado por perguntar. Prefiro não falar demais sobre eles em público."
			if personality == "fofoqueiro": return "Estão bem, sim. Na verdade, ouvi uma boa notícia sobre uma família daqui..."
			return "Estão bem, felizmente. Tento reservar um pouco do dia para ficar com eles."
		"ervas":
			if str(npc.role) == "curandeira": return "A folha-prateada costuma ser útil, mas é preciso saber identificar a planta antes de colher."
			return "Conheço algumas que crescem perto dos riachos, mas não arriscaria usar uma planta sem confirmar o que é."
		"notícias":
			if personality == "fofoqueiro": return "Ouvi falar de problemas na estrada, mas ainda não consegui confirmar os detalhes."
			if personality == "desconfiado": return "Nada confirmado. Prefiro esperar uma fonte confiável antes de espalhar rumores."
			return "Ainda não chegou nada importante. Talvez algum viajante traga novidades nos próximos dias."
		"cura":
			if str(npc.role) == "curandeira": return "Alguns remédios populares funcionam, mas a dose e a planta certa fazem toda a diferença."
			return "Já ouvi alguns. Uns tinham fundamento; outros poderiam ter feito mais mal do que bem."
		"dívidas":
			if personality == "bem-humorado": return "Tenho uma pequena lista. O problema é que ela parece crescer mais rápido que minha bolsa."
			return "É difícil guardar dinheiro quando sempre aparece alguma despesa inesperada."
		"mercadorias":
			if str(npc.role) == "mercador": return "Uma bússola antiga que apontava para o norte mesmo perto de um campo magnético. O dono queria uma fortuna por ela."
			return "Vi uma caixa de ferramentas feita por um artesão distante. Era bonita, mas custava mais do que eu podia pagar."
		"noite":
			if personality == "desconfiado": return "Ouvi passos depois da meia-noite, mas não abri a porta para descobrir quem era."
			return "Ouvi o vento batendo nas venezianas. Fora isso, a rua pareceu tranquila."
		_:
			if personality == "curioso": return "Aconteceu uma coisa pequena, mas interessante: um viajante contou que a estrada muda bastante depois das colinas."
			if personality == "bem-humorado": return "Nada extraordinário. O que já é uma boa notícia para variar."
			if personality == "fofoqueiro": return "Ouvi uma conversa na praça, mas ainda estou tentando descobrir o que é verdade."
			var goal := str(npc.get("personal_goal"))
			if goal != "": return "Ando tentando %s. Não é coisa para resolver de uma vez." % goal
			return "Foi um dia comum até agora. Espero que continue assim."


func _personal_context_followup(npc, other_name: String, topic: String, personality: String) -> String:
	match topic:
		"comida": return "Se provar, me diga se vale o preço, %s." % other_name
		"história": return "Se encontrar alguém que saiba mais sobre isso, quero ouvir, %s." % other_name
		"costumes": return "Talvez eu pergunte aos mais velhos quando tiver oportunidade, %s." % other_name
		"festas": return "Tomara que alguém tome a iniciativa este ano, %s." % other_name
		"animais": return "Se encontrar outro rastro desses, tente lembrar a direção, %s." % other_name
		"viagens": return "Vou perguntar ao próximo carroceiro que passar, %s." % other_name
		"deuses": return "Minha família teria muito a dizer sobre isso, %s." % other_name
		"ofício": return "Vou lembrar disso quando precisar comprar outra ferramenta, %s." % other_name
		"preços": return "Vou esperar uns dias antes de gastar minhas moedas, %s." % other_name
		"família": return "Espero que os seus estejam bem. Pergunto de novo quando nos encontrarmos, %s." % other_name
		"ervas": return "Se encontrar uma planta diferente, mostre à curandeira antes de usar, %s." % other_name
		"notícias": return "Se ouvir de alguém que esteve lá, me conte, %s." % other_name
		"cura": return "Melhor ouvir quem já tratou disso do que seguir palpite, %s." % other_name
		"dívidas": return "Se descobrir como fazer as moedas renderem, me avise, %s." % other_name
		"mercadorias": return "Essas coisas sempre aparecem quando a bolsa está vazia, %s." % other_name
		"noite": return "Vou fechar a janela cedo hoje. Até mais, %s." % other_name
		_:
			if personality == "reservado": return "Obrigado pela conversa. Até mais, %s." % other_name
			return "Bem, tenho de voltar ao trabalho. Até mais, %s." % other_name


func _event_reply_context(npc, other_name: String, creature: String, event_kind: String, personality: String, knowledge: String = "witness") -> String:
	if knowledge in ["heard", "recipient"]:
		if str(npc.role) == "guarda":
			return "Vou tratar isso como um relato, não como confirmação. Se soubermos a origem, podemos verificar antes de fechar a estrada."
		if personality == "curioso":
			return "Quem contou isso? Seria bom descobrir de onde veio a notícia antes de tirar conclusões, %s." % other_name
		return "É melhor ter cuidado, mas também descobrir de onde veio essa história antes de espalhá-la, %s." % other_name
	if event_kind == "monster_sighting":
		if personality == "curioso": return "Você viu em que direção foram, %s? Quero saber se estão se aproximando da cidade." % other_name
		if personality == "desconfiado": return "Então não devemos nos afastar dos portões. Melhor não correr esse risco, %s."
		if str(npc.role) == "guarda": return "Vou avisar a guarda e pedir que verifiquem a estrada. Obrigado por contar, %s." % other_name
		return "Vou evitar aquela estrada até sabermos se %s ainda está por perto." % creature
	if personality == "fofoqueiro": return "Quem enfrentou %s? Alguém já contou como terminou?" % creature
	if str(npc.role) == "guarda": return "Se alguém enfrentou %s, vou tentar confirmar o que aconteceu antes de liberar a estrada." % creature
	if personality == "bem-humorado": return "Tomara que tenham resolvido o problema. Não quero encontrar %s no caminho de casa." % creature
	return "Pelo menos alguém está enfrentando %s. Ainda assim, vou ter cuidado na estrada." % creature


func _event_closing_context(npc, other_name: String, creature: String, event_kind: String, personality: String, knowledge: String = "witness") -> String:
	if knowledge in ["heard", "recipient"]:
		return "Vamos confirmar a notícia antes de tratá-la como verdade, %s." % other_name
	if event_kind == "monster_sighting":
		if str(npc.role) == "guarda": return "Vou passar o aviso ao próximo turno. Melhor prevenir do que remediar, %s." % other_name
		return "Vou ficar longe daquela estrada até termos notícias mais seguras, %s." % other_name
	if personality == "fofoqueiro": return "Se eu souber quem enfrentou %s, conto a você depois, %s." % [creature, other_name]
	return "Vamos esperar por uma confirmação antes de considerar a estrada segura, %s." % other_name


func _storm_reply(npc, personality: String) -> String:
	if str(npc.role) == "guarda": return "Com esse tempo, vou manter a ronda longe das árvores e dos campos abertos."
	if personality == "bem-humorado": return "Eu também. Hoje até o trovão parece querer discutir com alguém."
	if personality == "pratico": return "Melhor procurar abrigo e ficar longe das árvores altas até passar."
	return "Tomara que ninguém precise viajar enquanto a tempestade durar."


func _storm_closing(npc, other_name: String, personality: String) -> String:
	if personality == "pratico": return "Vou guardar minhas ferramentas e esperar a tempestade passar, %s." % other_name
	if personality == "curioso": return "Quero ver se o tempo abre pela manhã. Até mais, %s." % other_name
	return "Vamos procurar abrigo antes que a chuva aperte, %s." % other_name


func _snow_reply(npc, other_name: String, personality: String) -> String:
	if str(npc.role) == "guarda": return "Vou pedir que a ronda fique atenta a viajantes perdidos. A neve esconde pegadas depressa, %s." % other_name
	if str(npc.role) == "mercador": return "Vou conferir minhas provisões. Com neve na estrada, a próxima entrega pode atrasar."
	if personality == "bem-humorado": return "Pelo menos a lama congelou. É uma pequena vitória, %s." % other_name
	return "Melhor ficar pelas ruas próximas e evitar as trilhas mais altas, %s." % other_name


func _snow_closing(npc, personality: String) -> String:
	if personality == "pratico": return "Vou cobrir os mantimentos antes que a neve se acumule."
	if personality == "curioso": return "Será que a neve vai chegar aos vales também?"
	return "Espero que a estrada volte a ficar visível logo."


func _snowstorm_reply(npc, personality: String) -> String:
	if str(npc.role) == "guarda": return "Vou suspender a ronda nas passagens abertas e manter alguém perto do abrigo."
	if str(npc.role) == "mercador": return "Caravana nenhuma devia sair agora. Vento assim apaga marcos e cobre a estrada."
	if personality == "bem-humorado": return "O frio está tentando nos transformar em estátuas. Prefiro ficar perto do fogo."
	if personality == "desconfiado": return "Com essa visibilidade, qualquer som pode ser alguém pedindo socorro."
	return "Quem estiver na estrada devia encontrar abrigo. Uma nevasca dessas não perdoa distração."


func _snowstorm_closing(npc, other_name: String, personality: String) -> String:
	if personality == "pratico": return "Vou reforçar a porta e esperar o vento diminuir, %s." % other_name
	if personality == "curioso": return "Quando abrir, quero ver quanta neve ficou nos telhados. Até mais, %s." % other_name
	return "Fique por perto de um abrigo, %s. Não vale a pena enfrentar isso lá fora." % other_name


func _home_reply(npc, other_name: String, personality: String) -> String:
	if personality == "bem-humorado": return "Pretendo, sim. Se eu me atrasar, alguém vai ficar com o melhor lugar perto da lareira."
	if personality == "desconfiado": return "Sim. Prefiro não andar pela rua tarde da noite."
	return "Depois que terminar minhas tarefas, vou direto para casa."


func _home_followup(npc, other_name: String, personality: String) -> String:
	if personality == "pratico": return "Certo. Nos vemos por lá quando terminarmos o que falta, %s." % other_name
	return "Então até mais tarde. Bom caminho de volta, %s." % other_name


func _work_reply_for_context(npc, other_name: String, first_role: String, personality: String) -> String:
	if first_role == "ferreiro":
		if personality == "bem-humorado": return "Imagino. Pelo menos o som do martelo cobre as reclamações dos clientes."
		return "A oficina ficou cheia, sim. Ainda temos encomendas para terminar amanhã."
	if first_role == "mercador":
		if personality == "fofoqueiro": return "E ouvi todo tipo de história enquanto os clientes olhavam as mercadorias."
		return "O movimento foi bom. Se as estradas continuarem abertas, amanhã deve ser parecido."
	if first_role == "curandeira":
		return "Espero que os remédios tenham ajudado. Algumas pessoas vão precisar voltar para acompanhamento."
	if personality == "reservado": return "Foi um dia cheio, mas conseguimos terminar o que era urgente."
	return "Foi puxado, mas o trabalho andou. Amanhã podemos cuidar do que ficou pendente."


func _guard_followup(npc, other_name: String, personality: String) -> String:
	if personality == "pratico": return "Continue atento, mas tente descansar quando terminar o turno, %s." % other_name
	return "Tomara que a próxima ronda seja tranquila também. Até mais, %s." % other_name


func _road_warning_reply(npc, other_name: String, personality: String) -> String:
	if personality == "curioso": return "Houve algum avistamento ou é uma precaução geral? Quero saber qual caminho evitar."
	if personality == "desconfiado": return "Vou seguir seu conselho e ficar dentro dos portões até a situação melhorar."
	if personality == "bem-humorado": return "Entendido. Hoje minha vontade de passear acabou de diminuir bastante."
	return "Obrigado pelo aviso. Vou usar a estrada principal e evitar os ermos."


func _road_warning_followup(npc, other_name: String, personality: String) -> String:
	if personality == "fofoqueiro": return "Se souber de algum perigo específico, me avise para eu espalhar o alerta certo, %s." % other_name
	return "Vou pedir que avisem os viajantes que passarem pelo portão, %s." % other_name


func _personal_opening(npc, other_name: String, hour: float) -> String:
	var interest := str(npc.get("personal_interest"))
	var name := other_name
	if hour >= 20.0 or hour < 6.0:
		return "%s, voltando para casa? Eu também não gosto de ficar na rua até tarde." % name if str(npc.personality) == "desconfiado" else "%s, a cidade fica bem diferente depois que escurece." % name
	match interest:
		"comida da taverna", "as comidas da taverna": return "%s, já provou o ensopado que estão servindo na taverna?" % name
		"histórias antigas da região", "histórias de armas antigas", "armas antigas", "histórias de artesãos": return "%s, ouviu alguma história antiga sobre estas terras?" % name
		"os costumes locais", "leis e costumes locais": return "%s, acha que os costumes daqui mudaram muito nos últimos anos?" % name
		"as canções e festas": return "%s, faz tempo que não temos uma festa de verdade por aqui, não acha?" % name
		"os animais dos arredores", "rastros e animais": return "%s, viu algum animal estranho nos arredores ultimamente?" % name
		"as estradas e os viajantes", "segurança das estradas", "histórias de viajantes": return "%s, tem encontrado muita gente viajando por estas estradas?" % name
		"as histórias dos deuses": return "%s, você costuma prestar atenção aos presságios ou acha que é conversa fiada?" % name
		"as ferramentas e os ofícios", "a qualidade dos trabalhos manuais": return "%s, para você o que faz um trabalho valer o preço cobrado?" % name
		"os preços do mercado", "preços e rotas comerciais", "preços do minério": return "%s, reparou como os preços andam mudando ultimamente?" % name
		"as famílias da cidade", "o bem-estar das famílias": return "%s, sua família está bem? Esses dias tenho pensado bastante nisso." % name
		"as plantas e ervas", "ervas medicinais", "plantas dos arredores": return "%s, conhece alguma planta que cresça melhor nesta época do ano?" % name
		"os rumores que chegam de fora", "as notícias que chegam de outras cidades": return "%s, chegou alguma notícia de fora? Faz tempo que não ouço nada novo." % name
		"metalurgia e ferramentas": return "%s, uma ferramenta bem-feita pode durar mais que seu dono. Você concorda?" % name
		"mercadorias raras": return "%s, qual foi a coisa mais incomum que já viu à venda?" % name
		"contas e dívidas": return "%s, parece que todo mundo deve alguma coisa a alguém ultimamente." % name
		"doenças e remédios", "crenças populares sobre cura": return "%s, ouviu algum conselho de cura que parecesse absurdo, mas funcionasse?" % name
		"o que acontece depois do pôr do sol": return "%s, ouviu barulho na rua durante a noite passada?" % name
		_: return _generic_opening(npc, null, name, hour, str(npc.personality))


func _personal_reply(npc, other_name: String, hour: float) -> String:
	var interest := str(npc.get("personal_interest"))
	var goal := str(npc.get("personal_goal"))
	var curiosity := float(npc.get("curiosity"))
	if curiosity >= 0.72:
		return "Ainda tento entender %s. Sempre há algum detalhe que passa despercebido." % interest
	if str(npc.personality) == "fofoqueiro":
		return "Não sei tudo, claro, mas posso perguntar por aí. Uma hora alguém fala demais." 
	if str(npc.personality) == "bem-humorado":
		return "Eu teria uma resposta melhor depois de comer alguma coisa. Ou de dormir uma semana."
	if str(npc.personality) == "desconfiado":
		return "Pode ser. Só prefiro não tirar conclusões antes de ter certeza."
	return "Ultimamente tenho tentado %s. Não é tão simples quanto parece." % goal


func _conversation_topic(first, second, event: Dictionary, threat: float, weather: int) -> String:
	if not event.is_empty():
		return "boato"
	if threat >= 62.0:
		return "segurança"
	if weather >= 2:
		return "clima"
	if _are_household_members(first, second):
		return "família"
	if _are_coworkers(first, second):
		return "trabalho"
	if str(first.role) == "guarda" or str(second.role) == "guarda":
		return "guarda"
	return "cotidiano"


func _are_household_members(first, second) -> bool:
	return first.household_member_ids.has(str(second.npc_id)) or second.household_member_ids.has(str(first.npc_id))


func _are_coworkers(first, second) -> bool:
	var first_building := str(first.work_building_id)
	return first_building != "" and first_building == str(second.work_building_id)


func _person_first_name(npc) -> String:
	var full_name := str(npc.get("person_name"))
	if full_name == "":
		full_name = str(npc.display_name).split(" · ")[0]
	return full_name.split(" ")[0]


func _creature_phrase(kind: String) -> String:
	match kind.to_lower():
		"rat", "rato": return "ratos enormes"
		"goblin": return "goblins"
		"bat", "morcego": return "morcegos enormes"
		"skel", "skeleton", "esqueleto": return "esqueletos"
		"orc": return "orcs"
		_: return "criaturas estranhas"


func _event_reply(npc, other_name: String, creature: String, personality: String) -> String:
	match personality:
		"desconfiado": return "Então é melhor não sair sozinho, %s." % other_name
		"bem-humorado": return "Desde que não venham bater na minha porta, por mim tudo bem."
		"fofoqueiro": return "Vou perguntar na taverna. Alguém sempre sabe de alguma coisa."
		"curioso": return "Será que vieram das ruínas? Queria saber de onde saíram."
		"reservado": return "Entendi. Vou tomar cuidado."
		_: return "A estrada anda perigosa. Melhor avisar os viajantes."


func _event_closing(npc, other_name: String, creature: String, personality: String) -> String:
	if personality == "fofoqueiro":
		return "Se eu descobrir mais, você vai ser o primeiro a saber, %s." % other_name
	if personality == "bem-humorado":
		return "Que os deuses mantenham essas coisas longe da minha cama."
	if personality == "pratico":
		return "Vou trancar a porta mais cedo hoje."
	return "Vamos ficar atentos, %s." % other_name


func _threat_reply(npc, other_name: String, personality: String) -> String:
	if str(npc.role) == "guarda":
		return "Estamos reforçando as rondas. Evite sair depois do anoitecer."
	if personality == "desconfiado":
		return "Eu sabia que aquela calmaria não ia durar."
	if personality == "bem-humorado":
		return "Ótimo. Era exatamente do que a semana precisava."
	return "Tomara que a guarda consiga manter os portões seguros."


func _threat_closing(npc, other_name: String, personality: String) -> String:
	if personality == "pratico":
		return "Vou terminar minhas tarefas antes de escurecer."
	if personality == "fofoqueiro":
		return "A taverna inteira já deve estar falando disso."
	return "Cuide-se na estrada, %s." % other_name


func _weather_reply(npc, other_name: String, personality: String) -> String:
	if str(npc.role) == "ferreiro":
		return "É verdade. Melhor adiar o transporte de minério até a estrada firmar."
	if str(npc.role) == "curandeira":
		return "As trilhas ficam ruins para colher. Vou me limitar às plantas perto de casa hoje."
	if personality == "bem-humorado":
		return "Então hoje vou evitar as poças fundas e fingir que isso conta como prudência."
	return "Também espero. Com esse barro, qualquer viagem curta vai levar o dobro do tempo."


func _weather_closing(npc, personality: String) -> String:
	if personality == "pratico":
		return "É melhor guardar as coisas antes que molhem."
	if personality == "curioso":
		return "Será que amanhã o céu vai estar limpo?"
	return "Que o tempo melhore logo."


func _family_reply(npc, other_name: String, personality: String) -> String:
	if personality == "desconfiado":
		return "Vou voltar cedo. Não gosto de deixar a casa vazia."
	if personality == "bem-humorado":
		return "Só se você prometer não comer o último pão de novo."
	return "Pode deixar. Vejo você em casa mais tarde."


func _work_opening(first, second, other_name: String, personality: String) -> String:
	if str(first.role) == "ferreiro":
		return "%s, hoje não faltou trabalho na oficina." % other_name
	if str(first.role) == "mercador":
		return "%s, o movimento na loja foi melhor que ontem." % other_name
	if str(first.role) == "curandeira":
		return "%s, muita gente veio procurar remédios hoje." % other_name
	return "%s, o expediente pareceu mais longo que o normal." % other_name


func _work_reply(npc, other_name: String, personality: String) -> String:
	if personality == "bem-humorado":
		return "Pelo menos recebemos por isso. Na maioria dos dias."
	if personality == "fofoqueiro":
		return "E ouvi cada história enquanto trabalhava..."
	if personality == "reservado":
		return "Foi um dia cheio, sim."
	return "Amanhã começa tudo outra vez."


func _work_closing(npc, other_name: String, personality: String) -> String:
	if personality == "pratico":
		return "Vou conferir as ferramentas e fechar tudo."
	if personality == "bem-humorado":
		return "Só paro quando as costas pedem socorro."
	return "Até amanhã, %s." % other_name


func _guard_reply(npc, other_name: String, personality: String) -> String:
	if str(npc.role) == "guarda":
		return "Por enquanto, sim. Mas não confie demais na tranquilidade."
	if personality == "fofoqueiro":
		return "Ouvi dizer que viram rastros perto dos campos."
	if personality == "desconfiado":
		return "Eu não andaria pela estrada depois do pôr do sol."
	return "Tomara que continue assim."


func _generic_opening(first, second, other_name: String, hour: float, personality: String) -> String:
	var style := str(first.get("speech_style"))
	var time_greeting := "Bom dia" if hour >= 6.0 and hour < 12.0 else "Boa tarde" if hour < 18.0 else "Boa noite"
	if hour >= 20.0 or hour < 6.0:
		if style == "formal": return "Ainda na rua a esta hora, %s? Tome cuidado no caminho de volta." % other_name
		if style == "coloquial": return "%s, você não vai para casa, não? Já está tarde." % other_name
		return "%s, já está voltando para casa?" % other_name
	if style == "formal": return "%s, %s. Como vão as coisas?" % [time_greeting, other_name]
	if style == "ironico": return "%s, alguma novidade ou o dia resolveu se comportar?" % other_name
	if style == "supersticioso": return "Dia quieto demais, %s. Espero que isso seja só impressão minha." % other_name
	if style == "observador": return "%s, parece que o movimento mudou hoje. Você notou?" % other_name
	if personality == "curioso": return "%s, aconteceu alguma coisa interessante hoje?" % other_name
	if personality == "fofoqueiro": return "%s, ouviu alguma novidade pela cidade?" % other_name
	if personality == "desconfiado": return "As coisas estão quietas demais por aqui, %s." % other_name
	if personality == "bem-humorado": return "%s, já teve um dia pior que este. Acho." % other_name
	if str(first.role) == "aldeao": return "%s, como vai o trabalho hoje?" % other_name
	return "Como anda o dia, %s?" % other_name


func _generic_reply(npc, other_name: String, personality: String, hour: float) -> String:
	var style := str(npc.get("speech_style"))
	if style == "formal": return "Não tenho do que reclamar. Espero que o mesmo valha para você."
	if style == "ironico": return "Ainda estou de pé, então o dia não venceu. Por enquanto."
	if style == "observador": return "O movimento está mais fraco do que ontem. Vamos ver se continua assim."
	if style == "poetico": return "O dia passa depressa quando a gente está ocupado. Às vezes só percebo quando a luz muda."
	if style == "coloquial": return "Vai levando. Tem dia que rende, tem dia que só acaba."
	if style == "supersticioso": return "Está tudo quieto. Espero que seja um bom sinal."
	if personality == "curioso":
		return "Sempre tem algo acontecendo, se prestar atenção."
	if personality == "bem-humorado":
		return "Melhor agora que parei um pouco para conversar."
	if personality == "desconfiado":
		return "Não tão ruim. Mas prefiro não falar alto demais."
	if personality == "fofoqueiro":
		return "Tenho uma história para contar, mas não aqui no meio da rua."
	if personality == "reservado":
		return "Tudo na mesma. E isso não é ruim."
	if hour >= 20.0 or hour < 6.0:
		return "Vou indo. As ruas ficam diferentes à noite."
	return "Tudo certo por enquanto. E com você?"


func _generic_closing(npc, other_name: String, personality: String) -> String:
	var style := str(npc.get("speech_style"))
	if style == "formal": return "Foi bom conversar com você. Tenha um bom caminho."
	if style == "ironico": return "Vou voltar ao trabalho antes que alguém note que estou de folga. Até mais, %s." % other_name
	if style == "pratico": return "Tenho coisa para terminar. Até mais, %s." % other_name
	if style == "reservado": return "Obrigado pela conversa. Até mais, %s." % other_name
	if personality == "fofoqueiro":
		return "Se descobrir algo novo, me procure."
	if personality == "bem-humorado":
		return "Vou voltar ao trabalho antes que percebam minha falta."
	if personality == "reservado":
		return "Até mais, %s." % other_name
	return "Bom conversar um pouco, %s." % other_name


func _build_guard_rosters(npc_nodes: Array) -> Dictionary:
	var rosters: Dictionary = {}
	for npc in npc_nodes:
		if not is_instance_valid(npc) or str(npc.role) != "guarda":
			continue
		var city_id := str(npc.city_id)
		var roster: Array = rosters.get(city_id, [])
		roster.append(npc)
		rosters[city_id] = roster
	return rosters


func _guard_shift_index(hour: float) -> int:
	# Três turnos: 06–14, 14–22 e 22–06.
	var shifted_hour: float = fposmod(hour - 6.0, 24.0)
	return clampi(int(floor(shifted_hour / GUARD_SHIFT_LENGTH_HOURS)), 0, 2)


func _guard_bucket(npc, hour: float, guard_rosters: Dictionary) -> String:
	var city_id := str(npc.city_id)
	var roster: Array = guard_rosters.get(city_id, [])
	var guard_index: int = roster.find(npc)
	if guard_index < 0 or roster.is_empty():
		return "guard_patrol"
	var shift_count: int = mini(3, maxi(1, int(floor(float(roster.size()) / 2.0))))
	var regional_threat: float = _regional_threat_for_city(city_id)
	# Em crise, mais guardas ficam de serviço simultaneamente; em ameaça crítica,
	# todo o efetivo deixa de seguir a rotação normal de folgas.
	if regional_threat >= 80.0:
		shift_count = 1
	elif regional_threat >= 55.0:
		shift_count = mini(2, maxi(1, int(floor(float(roster.size()) / 2.0))))
	var shift_index: int = _guard_shift_index(hour)
	# Com um guarda, ele cobre todos os horários. Com mais efetivo, os turnos
	# alternam e os que estão de folga voltam para casa.
	if roster.size() > 1 and guard_index % shift_count != shift_index % shift_count:
		return "home"
	var active_count: int = int(ceil(float(roster.size()) / float(shift_count)))
	var duty_rank: int = int(floor(float(guard_index) / float(shift_count)))
	var posts: Array = get_guard_posts_for_city(city_id)
	if posts.is_empty():
		return "guard_patrol"
	var rotation_slot: int = int(floor(fposmod(hour, 24.0) / GUARD_POST_ROTATION_HOURS))
	# Efetivo pequeno alterna entre ronda e posto. Com mais guardas de serviço,
	# parte cobre as entradas e pelo menos um fica em ronda pela cidade.
	if active_count == 1 and rotation_slot % 3 == 2:
		return "guard_patrol"
	if active_count > 1 and duty_rank == active_count - 1:
		return "guard_patrol"
	if duty_rank >= posts.size():
		return "guard_patrol"
	var post_index: int = posmod(duty_rank + rotation_slot, posts.size())
	return "guard_gate_%d" % post_index


func _routine_bucket_for_npc(npc, hour: float, guard_rosters: Dictionary) -> String:
	var role: String = str(npc.role)
	var city_id: String = str(npc.city_id)
	if role == "bruxa":
		return "witch_lair"
	if role == "guarda":
		return _guard_bucket(npc, hour, guard_rosters)
	# Pequenos horários individuais evitam que toda a população forme uma fila
	# simultânea nas portas ao amanhecer ou ao anoitecer. O deslocamento é estável
	# por identidade: o mesmo habitante conserva sua rotina ao longo da sessão.
	var identity_hash: int = abs(str(npc.npc_id).hash())
	var schedule_offset_hours: float = float(posmod(identity_hash, 46)) / 60.0
	var local_hour: float = fposmod(hour + schedule_offset_hours, 24.0)
	var threat: float = _regional_threat_for_city(city_id)
	var night: bool = local_hour >= 21.0 or local_hour < 6.0
	var curfew: bool = (threat >= 55.0 and night) or (threat >= 82.0 and (local_hour >= 19.0 or local_hour < 7.0))
	# Uma viagem já iniciada não é cancelada porque anoiteceu; o ambulante conclui
	# o percurso e passa a usar a estalagem da cidade de chegada.
	if role == "mercador" and str(npc.get("merchant_type")) == "itinerant" and bool(npc.get("merchant_trip_active")):
		return "merchant_travel"
	if role == "mensageiro" and bool(npc.get("messenger_trip_active")):
		return "messenger_travel"
	if curfew:
		return "home"
	if role == "estalajadeiro":
		return "work" if local_hour >= 10.0 or local_hour < 2.0 else "home"
	if role == "mensageiro":
		_ensure_messenger_departure_schedule(npc)
		var messenger_id := str(npc.get("npc_id"))
		var messenger_next := float(_messenger_next_departure_clock.get(messenger_id, INF))
		if local_hour >= 8.0 and local_hour < 17.0 and _world_clock_hours >= messenger_next:
			if _begin_messenger_trip(npc):
				return "messenger_travel"
			_messenger_next_departure_clock[messenger_id] = _world_clock_hours + 6.0
		if local_hour >= 7.0 and local_hour < 18.0:
			return "work"
		return "home"
	if role == "mercador" and str(npc.get("merchant_type")) == "itinerant":
		_ensure_merchant_departure_schedule(npc)
		var next_departure := float(_merchant_next_departure_clock.get(str(npc.get("npc_id")), INF))
		if local_hour >= 8.0 and local_hour < 17.0 and _world_clock_hours >= next_departure:
			if _begin_merchant_trip(npc):
				return "merchant_travel"
			# Cidades pequenas/isoladas: tenta novamente depois, não trava a rotina.
			_merchant_next_departure_clock[str(npc.get("npc_id"))] = _world_clock_hours + 12.0
		if local_hour >= 7.0 and local_hour < 19.0:
			return "merchant_visit"
		return "home"
	var npc_id := str(npc.get("npc_id"))
	var sociability := float(npc.get("sociability"))
	var tavern_roles: Array[String] = ["aldeao", "ferreiro", "curandeira", "mercador", "mensageiro"]
	# Pausa para refeição: alguns moradores vão à estalagem ao meio-dia; a escolha
	# é estável por identidade, então não muda aleatoriamente a cada atualização.
	# Isso cria movimento social diurno sem mandar a cidade inteira almoçar junta.
	if role in tavern_roles and local_hour >= 11.5 and local_hour < 13.5:
		var lunch_roll := posmod(abs((npc_id + "|lunch-routine").hash()), 5)
		if lunch_roll == 0 and sociability >= 0.42 and _select_inn_home(city_id, npc_id + "|lunch-visit") != "":
			return "tavern"
		# Parte dos trabalhadores rurais volta para casa na pausa, em vez de ficar
		# parada na rua; eles retomam o serviço no início da tarde.
		if role == "aldeao" and bool(npc.has_work_position) and lunch_roll in [1, 2]:
			return "home"
	# Aldeões com um local de trabalho (moinho, celeiro, estábulo ou depósito)
	# cumprem expediente de manhã e à tarde. Quem não tem posto continua seguindo
	# uma rotina urbana normal, evitando que qualquer aldeão seja teletransportado
	# para um prédio sem relação com sua vida.
	if role == "aldeao" and bool(npc.has_work_position):
		if (local_hour >= 7.0 and local_hour < 11.5) or (local_hour >= 13.0 and local_hour < 17.5):
			return "work"
	# Uma parcela dos moradores sociáveis frequenta a estalagem à noite. O hábito
	# fica associado à identidade e respeita o toque de recolher acima.
	if role in tavern_roles and local_hour >= 18.0 and local_hour < 22.0:
		var tavern_habit := posmod(abs((npc_id + "|evening-tavern").hash()), 3) == 0
		if tavern_habit and sociability >= 0.40 and _select_inn_home(city_id, npc_id + "|evening-visit") != "":
			return "tavern"
	# Uma parte dos aldeões faz pequenas caminhadas para além da zona urbana durante
	# o dia. O horário depende da identidade, para a cidade não esvaziar de uma vez.
	# Em regiões muito perigosas, eles permanecem dentro da cidade.
	if role == "aldeao" and posmod(identity_hash, 5) == 0 and local_hour >= 8.0 and local_hour < 18.0 and threat < 68.0:
		return "outskirts"
	return _routine_bucket(role, local_hour)


func _refresh_regional_threat_cache() -> void:
	if _world == null or not is_instance_valid(_world) or not _world.has_method("get_regional_threat"):
		return
	for city_key in cities.keys():
		var city_id: String = str(city_key)
		_cached_regional_threats[city_id] = float(_world.call("get_regional_threat", city_id))


func _regional_threat_for_city(city_id: String) -> float:
	if _cached_regional_threats.has(city_id):
		return float(_cached_regional_threats[city_id])
	if _world == null or not is_instance_valid(_world):
		return 0.0
	if not _world.has_method("get_regional_threat"):
		return 0.0
	var threat: float = float(_world.call("get_regional_threat", city_id))
	_cached_regional_threats[city_id] = threat
	return threat


func _give_distant_activity(npc, bucket: String) -> void:
	if bucket == "witch_lair":
		npc.simulate_offscreen(npc.global_position, "witch_lair")
		return
	if bucket == "messenger_travel" and bool(npc.get("messenger_trip_active")):
		# Fora da bolha ativa, o destino lógico acompanha a etapa da rota até o tempo de chegada.
		var target_office_id := str(npc.messenger_target_office_id)
		var target_office: Dictionary = buildings.get(target_office_id, {})
		if not target_office.is_empty():
			var target_city_id := str(target_office.get("city_id", npc.messenger_target_city_id))
			var target_position := _work_position_for(target_city_id, "mensageiro", target_office_id)
			npc.simulate_offscreen(target_position, "messenger_travel")
		else:
			npc.simulate_offscreen(npc.global_position, "messenger_travel")
		return
	if bucket == "merchant_travel" and str(npc.get("merchant_type")) == "itinerant":
		# NPCs fora da bolha ativa concluem a viagem na simulação estratégica.
		# Quando o jogador se aproxima, eles voltam a caminhar fisicamente pela rota.
		_complete_merchant_trip(npc, true)
		return
	if bucket == "merchant_visit" and str(npc.get("merchant_type")) == "itinerant":
		var public_destination := _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id))
		npc.simulate_offscreen(public_destination, "town")
		return
	if bucket == "home":
		npc.simulate_offscreen(npc.home_position, "home")
		return
	if bucket == "work" and npc.has_work_position:
		npc.simulate_offscreen(npc.work_position, "work")
		return
	if bucket == "tavern":
		var tavern_id := _select_inn_home(str(npc.city_id), str(npc.get("npc_id")) + "|evening-visit")
		if tavern_id != "" and buildings.has(tavern_id):
			var tavern_record: Dictionary = buildings[tavern_id]
			if npc.has_method("set_tavern_destination"):
				npc.call("set_tavern_destination", tavern_record)
			var tavern_position := _work_position_for(str(npc.city_id), "estalajadeiro", tavern_id)
			npc.simulate_offscreen(tavern_position, "tavern")
			return
	if bucket.begins_with("guard_gate_"):
		var posts: Array = get_guard_posts_for_city(str(npc.city_id))
		var post_index: int = bucket.trim_prefix("guard_gate_").to_int()
		if post_index >= 0 and post_index < posts.size():
			npc.simulate_offscreen(posts[post_index], "guard_gate")
			return
	if bucket == "outskirts" or (bucket == "guard_patrol" and posmod(abs(str(npc.npc_id).hash()), 3) != 0):
		var rural_destination := _pick_outskirts_position(str(npc.city_id), npc.global_position, str(npc.npc_id), str(npc.role) == "guarda")
		npc.simulate_offscreen(rural_destination, "outskirts")
		return
	var destination := _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id))
	npc.simulate_offscreen(destination, "patrol" if bucket == "guard_patrol" else "town")


func _routine_bucket(role: String, hour: float) -> String:
	var night := hour >= 21.0 or hour < 6.0
	if role == "guarda":
		return "guard_patrol"
	if night:
		return "home"
	# Horários diferentes por profissão, para a cidade não parecer uma linha de
	# montagem: oficina abre cedo, comércio começa um pouco depois e a curandeira
	# encerra o atendimento antes da vida noturna.
	if role == "ferreiro" and hour >= 7.0 and hour < 18.0:
		return "work"
	if role == "mercador" and hour >= 8.0 and hour < 19.0:
		return "work"
	if role == "curandeira" and hour >= 7.0 and hour < 17.0:
		return "work"
	return "town"


func _ensure_messenger_departure_schedule(npc) -> void:
	var npc_id := str(npc.get("npc_id"))
	if npc_id == "" or _messenger_next_departure_clock.has(npc_id):
		return
	var seed := absi((npc_id + "|messenger-departure").hash())
	# Cada posto começa o ciclo em horário diferente; os mensageiros não saem todos juntos.
	_messenger_next_departure_clock[npc_id] = _world_clock_hours + 5.0 + float(posmod(seed, 9))


func _select_messenger_destination_city(npc) -> String:
	# NPC é um CharacterBody3D: use propriedades do script, não Object.get() com fallback.
	var origin_city_id := str(npc.origin_city_id if str(npc.origin_city_id) != "" else npc.city_id)
	var origin_city: Dictionary = cities.get(origin_city_id, {})
	if origin_city.is_empty():
		origin_city_id = str(npc.city_id)
		origin_city = cities.get(origin_city_id, {})
	if origin_city.is_empty():
		return ""
	var choices: Array[Dictionary] = []
	for candidate_id_value in cities.keys():
		var candidate_id := str(candidate_id_value)
		if candidate_id == origin_city_id or _ensure_post_office_id(candidate_id) == "":
			continue
		var candidate: Dictionary = cities[candidate_id]
		choices.append({"id": candidate_id, "distance": _horizontal_distance(origin_city.get("center", Vector3.ZERO), candidate.get("center", Vector3.ZERO))})
	if choices.is_empty():
		return ""
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	var near_limit := mini(4, choices.size())
	var pool: Array[Dictionary] = choices.slice(0, near_limit)
	var trip_number := int(npc.messenger_trips_completed)
	var seed := absi((str(npc.npc_id) + "|messenger-destination|" + str(trip_number)).hash())
	var selected: Dictionary = pool[posmod(seed, pool.size())]
	return str(selected["id"]) if selected.has("id") else ""


func _begin_messenger_trip(npc) -> bool:
	# A chamada get() de Object aceita apenas o nome da propriedade; leia o campo direto.
	if bool(npc.messenger_trip_active):
		return true
	var origin_city_id := str(npc.origin_city_id if str(npc.origin_city_id) != "" else npc.city_id)
	var origin_office_id := str(npc.work_building_id)
	if origin_office_id == "" or not buildings.has(origin_office_id):
		origin_office_id = _ensure_post_office_id(origin_city_id)
	var destination_city_id := _select_messenger_destination_city(npc)
	var destination_office_id := _ensure_post_office_id(destination_city_id) if destination_city_id != "" else ""
	if origin_office_id == "" or destination_office_id == "" or not buildings.has(destination_office_id):
		return false
	var origin: Dictionary = buildings.get(origin_office_id, {})
	var destination: Dictionary = buildings.get(destination_office_id, {})
	if origin.is_empty() or destination.is_empty():
		return false
	npc.messenger_origin_office_id = origin_office_id
	npc.messenger_target_city_id = destination_city_id
	npc.messenger_target_office_id = destination_office_id
	npc.messenger_trip_stage = "outbound"
	npc.messenger_trip_active = true
	var origin_entry: Vector3 = origin.get("entry", npc.global_position)
	var destination_entry: Vector3 = destination.get("entry", npc.global_position)
	npc.messenger_arrival_clock = _world_clock_hours + _messenger_travel_hours(origin_entry, destination_entry)
	npc.messenger_carried_news = _collect_city_news(origin_city_id)
	return true


func _messenger_travel_hours(start: Vector3, finish: Vector3) -> float:
	# Fora da área do jogador, a rota é resolvida pela simulação estratégica sem teletransportes instantâneos.
	return maxf(2.0, _horizontal_distance(start, finish) / 65.0)


func _send_messenger_on_trip(npc) -> void:
	if not bool(npc.get("messenger_trip_active")) and not _begin_messenger_trip(npc):
		npc.life_bucket = "work"
		return
	var office_id := str(npc.get("messenger_target_office_id"))
	if not buildings.has(office_id):
		npc.messenger_trip_active = false
		npc.messenger_trip_stage = ""
		npc.life_bucket = "work"
		return
	var office: Dictionary = buildings[office_id]
	var destination := _work_position_for(str(office.get("city_id", "")), "mensageiro", office_id)
	_send_messenger_route(npc, destination)


func _send_messenger_route(npc, destination: Vector3) -> void:
	var route: Array[Vector3] = []
	var start: Vector3 = npc.work_position if bool(npc.get("is_at_work")) else npc.home_position if bool(npc.get("is_at_home")) else npc.global_position
	var distance := _horizontal_distance(start, destination)
	var steps := clampi(int(ceil(distance / 65.0)), 1, 32)
	for index in range(1, steps):
		var probe := _ground(start.lerp(destination, float(index) / float(steps)))
		probe.y += 0.03
		route.append(probe)
	route.append(destination)
	npc.go_to_route(destination, "messenger_travel", route)
	_log_debug("CORREIOS", "%s partiu levando notícias para %s." % [_person_first_name(npc), str(cities.get(str(npc.get("messenger_target_city_id")), {}).get("name", "outra cidade"))], str(npc.get("city_id")))


func _set_messenger_city(npc, destination_city_id: String) -> void:
	if destination_city_id == "" or not cities.has(destination_city_id):
		return
	var npc_id := str(npc.get("npc_id"))
	var old_city_id := str(npc.get("city_id"))
	if old_city_id != destination_city_id:
		if cities.has(old_city_id):
			var old_city: Dictionary = cities[old_city_id]
			var old_residents: Array = old_city.get("resident_ids", [])
			old_residents.erase(npc_id)
			old_city["resident_ids"] = old_residents
			cities[old_city_id] = old_city
		var destination_city: Dictionary = cities[destination_city_id]
		var destination_residents: Array = destination_city.get("resident_ids", [])
		if not destination_residents.has(npc_id):
			destination_residents.append(npc_id)
		destination_city["resident_ids"] = destination_residents
		cities[destination_city_id] = destination_city
		npc.city_id = destination_city_id
		npc.city_name = str(destination_city.get("name", WORLD_NAMES.settlement_name(destination_city_id)))
		if _active_records.has(npc_id):
			var saved: Dictionary = _active_records[npc_id]
			saved["city_id"] = destination_city_id
			_active_records[npc_id] = saved
		if _previous_records.has(npc_id):
			var previous: Dictionary = _previous_records[npc_id]
			previous["city_id"] = destination_city_id
			_previous_records[npc_id] = previous


func _arrive_messenger_leg(npc, offscreen: bool) -> void:
	if not bool(npc.get("messenger_trip_active")):
		return
	var stage := str(npc.messenger_trip_stage)
	var origin_city_id := str((npc.origin_city_id if str(npc.origin_city_id) != "" else npc.city_id))
	var target_city_id := str(npc.messenger_target_city_id)
	var news_value: Variant = npc.get("messenger_carried_news")
	var news: Array = news_value.duplicate(true) if news_value is Array else []
	if stage == "outbound":
		_set_messenger_city(npc, target_city_id)
		_deliver_city_news(target_city_id, news)
		_log_debug("CORREIOS", "%s entregou %d notícia(s) em %s." % [_person_first_name(npc), news.size(), str(cities.get(target_city_id, {}).get("name", "outro posto"))], target_city_id)
		npc.messenger_carried_news = _collect_city_news(target_city_id)
		npc.messenger_trip_stage = "returning"
		npc.messenger_target_city_id = origin_city_id
		npc.messenger_target_office_id = str(npc.get("messenger_origin_office_id"))
		var origin_office: Dictionary = buildings.get(str(npc.get("messenger_origin_office_id")), {})
		var return_destination: Vector3 = _work_position_for(origin_city_id, "mensageiro", str(npc.get("messenger_origin_office_id")))
		npc.messenger_arrival_clock = _world_clock_hours + _messenger_travel_hours(npc.global_position, return_destination)
		if offscreen:
			npc.simulate_offscreen(return_destination, "messenger_travel")
		else:
			_send_messenger_route(npc, return_destination)
		return
	# Retorno à própria base: novas informações são entregues, e o mensageiro retoma o expediente.
	_set_messenger_city(npc, origin_city_id)
	_deliver_city_news(origin_city_id, news)
	_log_debug("CORREIOS", "%s voltou ao posto com %d notícia(s)." % [_person_first_name(npc), news.size()], origin_city_id)
	npc.messenger_trip_active = false
	npc.messenger_trip_stage = ""
	npc.messenger_target_city_id = ""
	npc.messenger_target_office_id = str(npc.get("messenger_origin_office_id"))
	npc.messenger_trips_completed = int(npc.get("messenger_trips_completed")) + 1
	var seed := absi((str(npc.get("npc_id")) + "|messenger-next|" + str(npc.get("messenger_trips_completed"))).hash())
	_messenger_next_departure_clock[str(npc.get("npc_id"))] = _world_clock_hours + 12.0 + float(posmod(seed, 11))
	npc.life_bucket = ""
	npc.is_at_work = false
	npc.is_at_home = false
	npc.has_target = false
	npc.velocity = Vector3.ZERO
	if offscreen:
		npc.simulate_offscreen(npc.work_position, "work")


func _collect_city_news(city_id: String) -> Array[Dictionary]:
	var gathered: Array[Dictionary] = []
	var seen: Dictionary = {}
	for resident in _current_npc_nodes:
		if not is_instance_valid(resident) or str(resident.get("city_id")) != city_id:
			continue
		var memories_value: Variant = resident.get("known_world_events")
		if not (memories_value is Array):
			continue
		for memory_value in memories_value:
			if not (memory_value is Dictionary):
				continue
			var memory: Dictionary = memory_value
			var memory_key := str(memory.get("id", ""))
			if memory_key == "":
				memory_key = "%s|%s|%s" % [str(memory.get("kind", "event")), str(memory.get("detail", memory.get("text", ""))), str(memory.get("timestamp", memory.get("time", "")))]
			if seen.has(memory_key):
				continue
			seen[memory_key] = true
			gathered.append(memory.duplicate(true))
	# Cada mensageiro carrega um maço curto: chega a informação mais recente, não o histórico inteiro da cidade.
	if gathered.size() > 10:
		gathered = gathered.slice(gathered.size() - 10, gathered.size())
	return gathered


func _deliver_city_news(city_id: String, news: Array) -> void:
	if city_id == "" or news.is_empty():
		return
	for resident in _current_npc_nodes:
		if not is_instance_valid(resident) or str(resident.get("city_id")) != city_id:
			continue
		var current_value: Variant = resident.get("known_world_events")
		if not (current_value is Array):
			continue
		var memories: Array = current_value.duplicate(true)
		var seen: Dictionary = {}
		for existing_value in memories:
			if existing_value is Dictionary:
				var existing: Dictionary = existing_value
				var existing_id := str(existing.get("id", ""))
				if existing_id != "":
					seen[existing_id] = true
				else:
					seen["%s|%s|%s" % [str(existing.get("kind", "event")), str(existing.get("detail", existing.get("text", ""))), str(existing.get("timestamp", existing.get("time", "")))]] = true
		for incoming_value in news:
			if not (incoming_value is Dictionary):
				continue
			var incoming: Dictionary = incoming_value
			var incoming_id := str(incoming.get("id", ""))
			if incoming_id == "":
				incoming_id = "%s|%s|%s" % [str(incoming.get("kind", "event")), str(incoming.get("detail", incoming.get("text", ""))), str(incoming.get("timestamp", incoming.get("time", "")))]
			if seen.has(incoming_id):
				continue
			seen[incoming_id] = true
			memories.append(incoming.duplicate(true))
		while memories.size() > 12:
			memories.pop_front()
		resident.set("known_world_events", memories)


func _ensure_merchant_departure_schedule(npc) -> void:
	var npc_id := str(npc.get("npc_id"))
	if npc_id == "" or _merchant_next_departure_clock.has(npc_id):
		return
	var seed := absi((npc_id + "|departure-clock").hash())
	# Primeira viagem ocorre depois de 18 a 36 horas simuladas; depois, a cada
	# 24 a 42 horas, para que os ambulantes não saiam em massa.
	_merchant_next_departure_clock[npc_id] = _world_clock_hours + 18.0 + float(posmod(seed, 19))


func _select_merchant_destination_city(npc) -> String:
	var current_city_id := str(npc.get("city_id"))
	var previous_city_id := str(npc.get("merchant_last_city_id"))
	var current_city: Dictionary = cities.get(current_city_id, {})
	if current_city.is_empty():
		return ""
	var choices: Array[Dictionary] = []
	for city_id_value in cities.keys():
		var candidate_id := str(city_id_value)
		if candidate_id == current_city_id:
			continue
		var city: Dictionary = cities[candidate_id]
		var distance := _horizontal_distance(current_city.get("center", Vector3.ZERO), city.get("center", Vector3.ZERO))
		var threat := _regional_threat_for_city(candidate_id)
		choices.append({"id": candidate_id, "distance": distance, "threat": threat})
	if choices.is_empty():
		return ""
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a.get("threat", 0.0)) - float(b.get("threat", 0.0))) > 25.0:
			return float(a.get("threat", 0.0)) < float(b.get("threat", 0.0))
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	var filtered: Array[Dictionary] = []
	for choice in choices:
		if str(choice.get("id", "")) != previous_city_id:
			filtered.append(choice)
	if filtered.is_empty():
		filtered = choices
	# Seleciona entre até três destinos relativamente próximos para que as viagens
	# sejam regionais, variadas e não escolham sempre a mesma cidade.
	var limit := mini(3, filtered.size())
	var pool := filtered.slice(0, limit)
	var trip_number := int(npc.get("merchant_trips_completed"))
	var seed := absi((str(npc.get("npc_id")) + "|destination|" + str(trip_number)).hash())
	return str(pool[posmod(seed, pool.size())].get("id", ""))


func _is_inn_in_city(building_id: String, city_id: String) -> bool:
	if not buildings.has(building_id):
		return false
	var record: Dictionary = buildings[building_id]
	return str(record.get("kind", "")) == "inn" and str(record.get("city_id", "")) == city_id


func _select_inn_home(city_id: String, npc_id: String) -> String:
	var city: Dictionary = cities.get(city_id, {})
	var inns: Array[String] = []
	for building_id_value in city.get("building_ids", []):
		var building_id := str(building_id_value)
		if _is_inn_in_city(building_id, city_id):
			inns.append(building_id)
	if inns.is_empty():
		return ""
	inns.sort()
	var index := posmod(absi((npc_id + "|inn-room").hash()), inns.size())
	return inns[index]


func _merchant_lodging_position(inn: Dictionary) -> Vector3:
	var entry: Vector3 = inn.get("entry", inn.get("center", Vector3.ZERO))
	entry.y += 0.03
	return entry


func _begin_merchant_trip(npc) -> bool:
	if bool(npc.get("merchant_trip_active")):
		return true
	var destination_city_id := _select_merchant_destination_city(npc)
	if destination_city_id == "":
		return false
	var destination_inn_id := _select_inn_home(destination_city_id, str(npc.get("npc_id")))
	if not buildings.has(destination_inn_id):
		return false
	var inn: Dictionary = buildings[destination_inn_id]
	npc.merchant_target_city_id = destination_city_id
	npc.merchant_target_inn_id = destination_inn_id
	npc.merchant_trip_active = true
	return true


func _send_itinerant_merchant_on_trip(npc) -> void:
	if not bool(npc.get("merchant_trip_active")) and not _begin_merchant_trip(npc):
		npc.life_bucket = "merchant_visit"
		return
	var destination_inn_id := str(npc.get("merchant_target_inn_id"))
	if not buildings.has(destination_inn_id):
		npc.merchant_trip_active = false
		npc.life_bucket = "merchant_visit"
		return
	var inn: Dictionary = buildings[destination_inn_id]
	var destination := _merchant_lodging_position(inn)
	# Cria pontos de passagem sobre o terreno para que, enquanto o viajante estiver
	# na região ativa, ele percorra a paisagem em vez de saltar visualmente à cidade.
	var route: Array[Vector3] = []
	var start: Vector3 = npc.global_position
	var distance: float = _horizontal_distance(start, destination)
	var steps: int = clampi(int(ceil(distance / 65.0)), 1, 28)
	for index in range(1, steps):
		var t: float = float(index) / float(steps)
		var probe: Vector3 = start.lerp(destination, t)
		probe = _ground(probe)
		probe.y += 0.03
		route.append(probe)
	# Viagens interurbanas usam waypoints regionais; a navegação local do povoado
	# continua sendo usada para as rotinas comuns e para a aproximação final.
	route.append(destination)
	npc.go_to_route(destination, "merchant_travel", route)
	var npc_key := str(npc.get("npc_id"))
	_log_debug("COMÉRCIO", "%s saiu de %s rumo a %s." % [_person_first_name(npc), str(npc.get("city_name")), str(cities.get(str(npc.merchant_target_city_id), {}).get("name", "outro assentamento"))], str(npc.get("city_id")))


func _complete_merchant_trip(npc, offscreen: bool) -> void:
	if not bool(npc.get("merchant_trip_active")):
		return
	var destination_city_id := str(npc.get("merchant_target_city_id"))
	var destination_inn_id := str(npc.get("merchant_target_inn_id"))
	if not cities.has(destination_city_id) or not _is_inn_in_city(destination_inn_id, destination_city_id):
		npc.merchant_trip_active = false
		return
	var old_city_id := str(npc.get("city_id"))
	var destination_city: Dictionary = cities[destination_city_id]
	var inn: Dictionary = buildings[destination_inn_id]
	var old_city: Dictionary = cities.get(old_city_id, {})
	var old_residents: Array = old_city.get("resident_ids", [])
	old_residents.erase(str(npc.get("npc_id")))
	if not old_city.is_empty():
		old_city["resident_ids"] = old_residents
		cities[old_city_id] = old_city
	var new_residents: Array = destination_city.get("resident_ids", [])
	if not new_residents.has(str(npc.get("npc_id"))):
		new_residents.append(str(npc.get("npc_id")))
	destination_city["resident_ids"] = new_residents
	cities[destination_city_id] = destination_city
	npc.merchant_last_city_id = old_city_id
	npc.city_id = destination_city_id
	npc.city_name = str(destination_city.get("name", WORLD_NAMES.settlement_name(destination_city_id)))
	npc.home_id = destination_inn_id
	npc.home_name = str(inn.get("name", "Estalagem"))
	npc.home_position = _merchant_lodging_position(inn)
	npc.home_door_position = inn.get("door_position", npc.home_position)
	npc.home_front_direction = inn.get("front_direction", Vector3.FORWARD)
	npc.home_front_direction.y = 0.0
	if npc.home_front_direction.length_squared() < 0.001:
		npc.home_front_direction = Vector3.FORWARD
	npc.home_front_direction = npc.home_front_direction.normalized()
	npc.merchant_trip_active = false
	npc.merchant_target_city_id = ""
	npc.merchant_target_inn_id = ""
	npc.merchant_trips_completed = int(npc.get("merchant_trips_completed")) + 1
	npc.is_at_home = false
	npc.is_at_work = false
	npc.has_target = false
	npc.target_kind = "merchant_visit"
	npc.target_position = npc.home_position
	npc._route_points.clear()
	npc._route_index = 0
	npc.velocity = Vector3.ZERO
	npc.life_enabled = true
	npc.visible = not offscreen
	npc.collision_layer = 2 if not offscreen else 0
	npc.collision_mask = 1 if not offscreen else 0
	npc.set_physics_process(not offscreen)
	if offscreen:
		var destination := _pick_public_position(destination_city_id, npc.home_position, destination_inn_id)
		npc.simulate_offscreen(destination, "town")
	else:
		# O viajante chega à porta da estalagem, deixa a bagagem e volta a circular.
		npc.global_position = npc.home_position
		npc._activity_timer = randf_range(3.0, 7.0)
	if npc.has_method("configure_world_knowledge"):
		npc.configure_world_knowledge(get_world_knowledge_for_npc(npc))
	var npc_id := str(npc.get("npc_id"))
	_merchant_next_departure_clock[npc_id] = _world_clock_hours + 24.0 + float(posmod(absi((npc_id + "|next-trip|" + str(npc.get("merchant_trips_completed"))).hash()), 19))
	if _active_records.has(npc_id):
		var saved: Dictionary = _active_records[npc_id]
		saved["city_id"] = destination_city_id
		saved["home_id"] = destination_inn_id
		saved["merchant_type"] = "itinerant"
		saved["merchant_last_city_id"] = old_city_id
		saved["merchant_trips_completed"] = int(npc.get("merchant_trips_completed"))
		_active_records[npc_id] = saved
	_log_debug("COMÉRCIO", "%s chegou a %s e ficará hospedado em %s." % [_person_first_name(npc), npc.city_name, npc.home_name], destination_city_id)


func _give_activity(npc, bucket: String) -> void:
	if bucket == "witch_lair":
		npc.has_target = false
		npc.target_kind = "witch_lair"
		npc.velocity = Vector3.ZERO
		return
	if bucket == "messenger_travel" and bool(npc.get("messenger_trip_active")):
		_send_messenger_on_trip(npc)
		return
	if bucket == "merchant_travel" and str(npc.get("merchant_type")) == "itinerant":
		_send_itinerant_merchant_on_trip(npc)
		return
	if bucket == "merchant_visit" and str(npc.get("merchant_type")) == "itinerant":
		_send_npc_to(npc, _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id)), "town")
		return
	if bucket == "home":
		if not bool(npc.is_at_home):
			_send_npc_to(npc, npc.home_position, "home")
		return
	if bucket.begins_with("guard_gate_"):
		var posts: Array = get_guard_posts_for_city(str(npc.city_id))
		var post_index: int = bucket.trim_prefix("guard_gate_").to_int()
		if post_index >= 0 and post_index < posts.size():
			_send_npc_to(npc, posts[post_index], "guard_gate")
		else:
			_send_npc_to(npc, _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id)), "patrol")
		return
	if bucket == "work":
		var work_pos: Vector3 = npc.work_position
		if not npc.has_work_position:
			work_pos = _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id))
			_send_npc_to(npc, work_pos, "town")
		else:
			_send_npc_to(npc, work_pos, "work")
		return
	if bucket == "tavern":
		var city_id := str(npc.city_id)
		var tavern_id := _select_inn_home(city_id, str(npc.get("npc_id")) + "|evening-visit")
		if tavern_id != "" and buildings.has(tavern_id):
			var tavern_record: Dictionary = buildings[tavern_id]
			if bool(npc.get("is_at_tavern")) and str(npc.get("tavern_building_id")) == tavern_id:
				if npc.has_method("refresh_tavern_stay"):
					npc.call("refresh_tavern_stay")
				return
			if npc.has_method("set_tavern_destination"):
				npc.call("set_tavern_destination", tavern_record)
			var tavern_position := _work_position_for(city_id, "estalajadeiro", tavern_id)
			_send_npc_to(npc, tavern_position, "tavern", tavern_id)
		else:
			_send_npc_to(npc, _pick_public_position(city_id, npc.global_position, str(npc.home_id)), "town")
		return
	if bucket == "outskirts":
		_send_npc_to(npc, _pick_outskirts_position(str(npc.city_id), npc.global_position, str(npc.npc_id), str(npc.role) == "guarda"), "outskirts")
		return
	if bucket == "patrol" or bucket == "guard_patrol":
		if bucket == "guard_patrol" and posmod(abs(str(npc.npc_id).hash()), 3) != 0:
			_send_npc_to(npc, _pick_outskirts_position(str(npc.city_id), npc.global_position, str(npc.npc_id), true), "outskirts")
		else:
			_send_npc_to(npc, _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id)), "patrol")
		return
	_send_npc_to(npc, _pick_public_position(str(npc.city_id), npc.global_position, str(npc.home_id)), "town")


func _send_npc_to(npc, destination: Vector3, destination_kind: String, target_building_id: String = "") -> void:
	destination = _spread_destination(npc, destination, destination_kind, target_building_id)
	# Um morador logicamente dentro de casa usa o ponto exterior da porta como
	# origem do cálculo da rota; sua posição real pode estar dentro da geometria.
	var route_start: Vector3 = npc.global_position
	if bool(npc.is_at_home):
		route_start = npc.home_position
	elif bool(npc.get("is_at_work")):
		route_start = npc.work_position
	elif bool(npc.get("is_at_tavern")) and destination_kind != "tavern":
		route_start = npc.get("tavern_entry_position")
	# Reconhece o prédio-alvo também para destinos públicos e locais de trabalho.
	# Antes, somente residências eram tratadas como destino de uma rota: o prédio
	# da loja/oficina continuava bloqueando a última ligação até a entrada e o NPC
	# entrava em um ciclo de desvios em volta da fachada/escada.
	var goal_building_id := target_building_id
	if goal_building_id == "":
		if destination_kind == "home":
			goal_building_id = str(npc.home_id)
		elif destination_kind == "work":
			goal_building_id = str(npc.get("work_building_id"))
		elif destination_kind in ["town", "patrol"]:
			goal_building_id = _building_id_for_entry(str(npc.city_id), destination)
	var route: Array[Vector3] = _find_route(route_start, destination, str(npc.city_id), goal_building_id)
	if route.is_empty() and goal_building_id != "" and buildings.has(goal_building_id):
		# Se o destino fica junto às escadas e o grafo não consegue conectar a rota
		# diretamente, tenta primeiro um ponto de aproximação mais afastado na rua,
		# à frente da construção. O último trecho é então curto e não cruza as escadas
		# lateralmente.
		var goal_building: Dictionary = buildings[goal_building_id]
		var outward: Vector3 = goal_building.get("front_direction", Vector3.FORWARD)
		outward.y = 0.0
		if outward.length_squared() > 0.001:
			outward = outward.normalized()
			for distance_offset in [2.0, 3.0, 4.0, 5.0]:
				var approach: Vector3 = _ground(destination + outward * float(distance_offset))
				approach.y += 0.03
				if _point_overlaps_any_building(str(npc.city_id), approach, 0.25):
					continue
				var approach_route: Array[Vector3] = _find_route(route_start, approach, str(npc.city_id), goal_building_id)
				if not approach_route.is_empty():
					route = approach_route
					route.append(destination)
					break
	if route.is_empty():
		# Último recurso: desloca-se diretamente ao destino. A assistência de degraus
		# do CharacterBody evita ficar em loop quando esse trecho é a escada frontal.
		route.append(destination)
	if npc.has_method("go_to_route"):
		npc.go_to_route(destination, destination_kind, route)
	else:
		npc.go_to(destination, destination_kind)
	var npc_key := str(npc.get("npc_id"))
	if str(_debug_last_activity.get(npc_key, "")) != destination_kind:
		_debug_last_activity[npc_key] = destination_kind
		var activity_labels := {"home": "indo para casa", "work": "indo trabalhar", "town": "passeando pela cidade", "patrol": "patrulhando", "guard_gate": "indo ao posto de guarda", "outskirts": "caminhando pelas estradas fora da cidade", "tavern": "indo à estalagem/taverna"}
		_log_debug("ROTINA", "%s: %s." % [_person_first_name(npc), str(activity_labels.get(destination_kind, destination_kind))], str(npc.city_id))


func _pick_outskirts_position(city_id: String, from_pos: Vector3, npc_id: String, guard_route: bool = false) -> Vector3:
	var city: Dictionary = cities.get(city_id, {})
	var center: Vector3 = city.get("center", from_pos)
	var identity_seed: int = abs((npc_id + "|road|" + str(int(floor(_debug_hour / 2.0)))).hash())
	var base_angle: float = float(posmod(identity_seed, 6283)) / 1000.0
	var min_radius: float = 112.0 if not guard_route else 102.0
	var max_radius: float = 198.0 if not guard_route else 228.0
	for attempt in range(24):
		var angle: float = base_angle + TAU * float(attempt) / 8.0 + randf_range(-0.22, 0.22)
		var radius: float = randf_range(min_radius, max_radius)
		var candidate: Vector3 = _ground(center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		if _horizontal_distance(candidate, center) < 88.0:
			continue
		if _world != null and is_instance_valid(_world):
			if _world.has_method("safe_zone_at") and str(_world.call("safe_zone_at", candidate)) != "":
				continue
			if _world.get("sea_level") != null and candidate.y <= float(_world.get("sea_level")) + 1.0:
				continue
		if _horizontal_distance(candidate, from_pos) < 24.0:
			continue
		return candidate
	# Em mapas com água ou outras cidades em quase todas as direções, prioriza uma
	# posição segura na faixa externa em vez de mandar o NPC para um ponto aleatório.
	var fallback: Vector3 = _ground(center + Vector3(cos(base_angle) * min_radius, 0.0, sin(base_angle) * min_radius))
	return fallback


func _spread_destination(npc, requested: Vector3, destination_kind: String, target_building_id: String = "") -> Vector3:
	# Evita que moradores escolham o mesmo ponto de passeio/patrulha; para
	# balcões, postos e entradas de estalagens cria lugares de espera próximos.
	if destination_kind in ["home", "work"]:
		return requested
	var threshold := 2.8 if destination_kind in ["town", "patrol"] else 2.25
	if _destination_clearance(npc, requested) >= threshold:
		return requested
	var candidates: Array[Vector3] = []
	var city_id := str(npc.city_id)
	if destination_kind in ["town", "patrol"]:
		var city: Dictionary = cities.get(city_id, {})
		for point_value in city.get("public_positions", []):
			var point: Vector3 = point_value
			if _horizontal_distance(point, npc.global_position) < 3.5:
				continue
			if _horizontal_distance(point, requested) < 1.5:
				continue
			candidates.append(point)
	else:
		# Trabalho e postos de guarda continuam junto ao local previsto, mas cada
		# NPC ganha um ponto próprio em volta dele, evitando empilhamento no centro.
		for radius in [1.8, 2.6, 3.4]:
			for angle_index in range(8):
				var angle := TAU * float(angle_index) / 8.0
				var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
				candidates.append(_ground(requested + offset))
	if candidates.is_empty():
		# Assentamentos pequenos podem ter poucos pontos públicos; nesses casos,
		# abre pequenos pontos alternativos em torno do destino em vez de empilhar.
		for radius in [2.6, 3.4, 4.2]:
			for angle_index in range(8):
				var angle := TAU * float(angle_index) / 8.0
				var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
				candidates.append(_ground(requested + offset))
	var best_point := requested
	var best_score := _destination_clearance(npc, requested) - 0.05 * _horizontal_distance(npc.global_position, requested)
	for candidate in candidates:
		# Ao variar o lugar de um trabalhador ou frequentador, não o mande para
		# cima das escadas, para trás da fachada ou para dentro de outro edifício.
		if destination_kind in ["work", "tavern"]:
			var relevant_building_id := target_building_id
			if relevant_building_id == "" and destination_kind == "work":
				relevant_building_id = str(npc.get("work_building_id"))
			if relevant_building_id != "" and not _is_in_front_of_building(relevant_building_id, candidate):
				continue
			if _point_overlaps_any_building(str(npc.city_id), candidate, 0.35):
				continue
		var clearance := _destination_clearance(npc, candidate)
		var travel_cost := _horizontal_distance(npc.global_position, candidate)
		var score := clearance - 0.05 * travel_cost + randf() * 0.12
		if score > best_score:
			best_score = score
			best_point = candidate
	return best_point


func _destination_clearance(npc, candidate: Vector3) -> float:
	var nearest := INF
	for other in _current_npc_nodes:
		if other == npc or not is_instance_valid(other):
			continue
		if str(other.city_id) != str(npc.city_id):
			continue
		if bool(other.is_at_home) or not bool(other.visible):
			continue
		# Pessoas que entram em casa desaparecem após chegar, portanto não precisam
		# reservar permanentemente a entrada como ponto público.
		if bool(other.has_target) and str(other.target_kind) == "home":
			continue
		var other_point: Vector3 = other.target_position if bool(other.has_target) else other.global_position
		nearest = minf(nearest, _horizontal_distance(candidate, other_point))
	return nearest


func _find_route(start: Vector3, destination: Vector3, city_id: String, goal_building_id: String = "") -> Array[Vector3]:
	var direct_distance: float = _horizontal_distance(start, destination)
	if direct_distance <= 1.0 or _route_segment_clear(start, destination, city_id, goal_building_id, destination):
		return [destination]
	var city: Dictionary = cities.get(city_id, {})
	if city.is_empty():
		return [destination]

	# Grafo de visibilidade compacto: começo, destino e cantos das construções
	# próximas ao trajeto. Isso ajuda os NPCs a contornar paredes em vez de tentar
	# andar em linha reta através de uma casa até a porta.
	var nodes: Array[Vector3] = [start, destination]
	for building_value in city.get("building_ids", []):
		var building: Dictionary = buildings.get(str(building_value), {})
		if building.is_empty():
			continue
		var bounds: AABB = building.get("bounds", AABB())
		var center: Vector3 = bounds.get_center()
		if _point_segment_distance_xz(center, start, destination) > ROUTE_CORRIDOR_RADIUS:
			continue
		var x0: float = bounds.position.x - ROUTE_CORNER_OFFSET
		var x1: float = bounds.end.x + ROUTE_CORNER_OFFSET
		var z0: float = bounds.position.z - ROUTE_CORNER_OFFSET
		var z1: float = bounds.end.z + ROUTE_CORNER_OFFSET
		var corner_coords: Array[Vector2] = [Vector2(x0, z0), Vector2(x0, z1), Vector2(x1, z0), Vector2(x1, z1)]
		for coord in corner_coords:
			var candidate: Vector3 = _ground(Vector3(coord.x, start.y, coord.y))
			if _horizontal_distance(candidate, start) < 1.4 or _horizontal_distance(candidate, destination) < 1.4:
				continue
			if _route_node_exists(nodes, candidate):
				continue
			nodes.append(candidate)

	# Entradas de edifícios também servem de pontos de passagem nas ruas.
	for public_value in city.get("public_positions", []):
		var public_point: Vector3 = public_value
		if _point_segment_distance_xz(public_point, start, destination) > ROUTE_CORRIDOR_RADIUS * 0.65:
			continue
		if _horizontal_distance(public_point, start) < 2.0 or _horizontal_distance(public_point, destination) < 1.25:
			continue
		if _route_node_exists(nodes, public_point):
			continue
		nodes.append(public_point)

	var count: int = nodes.size()
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for _i in count:
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0.0
	for _iteration in count:
		var current: int = -1
		var best_distance: float = INF
		for i in count:
			if not visited[i] and distances[i] < best_distance:
				best_distance = distances[i]
				current = i
		if current < 0:
			break
		if current == 1:
			break
		visited[current] = true
		for next_index in count:
			if next_index == current or visited[next_index]:
				continue
			if not _route_segment_clear(nodes[current], nodes[next_index], city_id, goal_building_id, destination):
				continue
			var edge_length: float = _horizontal_distance(nodes[current], nodes[next_index])
			var candidate_distance: float = distances[current] + edge_length
			if candidate_distance < distances[next_index]:
				distances[next_index] = candidate_distance
				previous[next_index] = current

	if previous[1] == -1:
		return []
	var reversed_route: Array[Vector3] = []
	var cursor: int = 1
	while cursor > 0:
		reversed_route.append(nodes[cursor])
		cursor = previous[cursor]
		if cursor < 0:
			return []
	reversed_route.reverse()
	return reversed_route


func _route_node_exists(nodes: Array[Vector3], candidate: Vector3) -> bool:
	for existing in nodes:
		if _horizontal_distance(existing, candidate) < 1.25:
			return true
	return false


func _route_segment_clear(from_point: Vector3, to_point: Vector3, city_id: String, goal_building_id: String = "", goal_position: Vector3 = Vector3.ZERO) -> bool:
	var city: Dictionary = cities.get(city_id, {})
	# A casa de destino deixa de ser obstáculo apenas na aresta que realmente
	# termina (ou começa, no grafo não direcionado) em sua entrada. As demais
	# arestas continuam evitando atravessar edifícios.
	var touches_goal := goal_building_id != "" and (
		_horizontal_distance(from_point, goal_position) < 0.25
		or _horizontal_distance(to_point, goal_position) < 0.25
	)
	var goal_front_approach := false
	if touches_goal and buildings.has(goal_building_id):
		var goal_building: Dictionary = buildings[goal_building_id]
		var outward: Vector3 = goal_building.get("front_direction", Vector3.FORWARD)
		outward.y = 0.0
		if outward.length_squared() > 0.001:
			outward = outward.normalized()
			var approach_point: Vector3 = to_point if _horizontal_distance(from_point, goal_position) < 0.25 else from_point
			var door_point: Vector3 = goal_building.get("door_position", goal_position)
			var approach_offset := Vector3(approach_point.x - door_point.x, 0.0, approach_point.z - door_point.z)
			goal_front_approach = approach_offset.dot(outward) >= -0.1
	for building_value in city.get("building_ids", []):
		var building_id := str(building_value)
		# Só ignora a casa-alvo quando a ligação termina do lado externo da sua
		# fachada. Um nó na parte de trás nunca pode criar uma rota através da casa.
		if goal_front_approach and building_id == goal_building_id:
			continue
		var building: Dictionary = buildings.get(building_id, {})
		if building.is_empty():
			continue
		var bounds: AABB = building.get("bounds", AABB())
		if _segment_intersects_expanded_bounds(from_point, to_point, bounds, ROUTE_BLOCK_MARGIN):
			return false
	return true


func _segment_intersects_expanded_bounds(a: Vector3, b: Vector3, bounds: AABB, margin: float) -> bool:
	# Interseção segmento-retângulo no plano XZ, sem amostragem frame a frame.
	var min_x: float = bounds.position.x - margin
	var max_x: float = bounds.end.x + margin
	var min_z: float = bounds.position.z - margin
	var max_z: float = bounds.end.z + margin
	var low: float = 0.0
	var high: float = 1.0
	var dx: float = b.x - a.x
	if absf(dx) < 0.00001:
		if a.x < min_x or a.x > max_x:
			return false
	else:
		var tx1: float = (min_x - a.x) / dx
		var tx2: float = (max_x - a.x) / dx
		if tx1 > tx2:
			var swap_x: float = tx1
			tx1 = tx2
			tx2 = swap_x
		low = maxf(low, tx1)
		high = minf(high, tx2)
		if low > high:
			return false
	var dz: float = b.z - a.z
	if absf(dz) < 0.00001:
		if a.z < min_z or a.z > max_z:
			return false
	else:
		var tz1: float = (min_z - a.z) / dz
		var tz2: float = (max_z - a.z) / dz
		if tz1 > tz2:
			var swap_z: float = tz1
			tz1 = tz2
			tz2 = swap_z
		low = maxf(low, tz1)
		high = minf(high, tz2)
		if low > high:
			return false
	return high >= 0.0 and low <= 1.0


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _point_segment_distance_xz(point: Vector3, a: Vector3, b: Vector3) -> float:
	var start_2d := Vector2(a.x, a.z)
	var end_2d := Vector2(b.x, b.z)
	var point_2d := Vector2(point.x, point.z)
	var segment := end_2d - start_2d
	if segment.length_squared() <= 0.0001:
		return point_2d.distance_to(start_2d)
	var t: float = clampf((point_2d - start_2d).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point_2d.distance_to(start_2d + segment * t)


func _pick_public_position(city_id: String, from_pos: Vector3, avoid_home_id: String) -> Vector3:
	var city: Dictionary = cities.get(city_id, {})
	var options: Array = city.get("public_positions", [])
	var near: Array[Vector3] = []
	for value in options:
		var point: Vector3 = value
		var distance := Vector2(point.x - from_pos.x, point.z - from_pos.z).length()
		if distance >= 4.5 and distance <= 55.0:
			near.append(point)
	if near.is_empty():
		for value in options:
			near.append(value)
	if near.is_empty():
		return _ground(from_pos + Vector3(3.0, 0.0, 3.0))
	return near[randi_range(0, near.size() - 1)]


func get_city_influence_radii() -> Dictionary:
	# A cidade cobre o conjunto real de edifícios mais uma pequena faixa externa.
	# Isso evita que a ameaça continue sendo atribuída à cidade por centenas de metros.
	var result: Dictionary = {}
	for city_key in cities.keys():
		var city_id: String = str(city_key)
		var city: Dictionary = cities[city_id]
		var center: Vector3 = city.get("center", Vector3.ZERO)
		var farthest: float = 0.0
		for building_value in city.get("building_ids", []):
			var record: Dictionary = buildings.get(str(building_value), {})
			if record.is_empty():
				continue
			var bounds: AABB = record.get("bounds", AABB())
			var corners: Array[Vector2] = [
				Vector2(bounds.position.x, bounds.position.z),
				Vector2(bounds.position.x, bounds.end.z),
				Vector2(bounds.end.x, bounds.position.z),
				Vector2(bounds.end.x, bounds.end.z)
			]
			for corner in corners:
				farthest = maxf(farthest, corner.distance_to(Vector2(center.x, center.z)))
		result[city_id] = maxf(105.0, farthest + CITY_THREAT_MARGIN)
	return result


func get_residents_of_house(house_id: String) -> Array:
	if not houses.has(house_id):
		return []
	var residents: Array = houses[house_id].get("resident_ids", [])
	return residents.duplicate()


func get_residents_of_city(city_id: String) -> Array:
	if not cities.has(city_id):
		return []
	var residents: Array = cities[city_id].get("resident_ids", [])
	return residents.duplicate()


func get_house_record(house_id: String) -> Dictionary:
	return houses.get(house_id, {}).duplicate()


func get_city_record(city_id: String) -> Dictionary:
	return cities.get(city_id, {}).duplicate()


func get_all_buildings() -> Array:
	# Registros de construções físicas derivados dos nomes dos objetos do Blender.
	var result: Array = []
	for building_id in buildings.keys():
		var record: Dictionary = buildings[str(building_id)]
		if not bool(record.get("virtual", false)):
			result.append(record.duplicate())
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return result


func get_city_buildings(city_id: String) -> Array:
	var result: Array = []
	var city: Dictionary = cities.get(city_id, {})
	if city.is_empty():
		return result
	for building_id in city.get("building_ids", []):
		var record: Dictionary = buildings.get(str(building_id), {})
		if not record.is_empty() and not bool(record.get("virtual", false)):
			result.append(record.duplicate())
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


func get_building_record(building_id: String) -> Dictionary:
	return buildings.get(building_id, {}).duplicate()


func get_city_building_counts(city_id: String) -> Dictionary:
	# Inclui todos os tipos presentes no GLB atual; não reduza o assentamento às
	# cinco categorias antigas, porque isso fazia serviços e produção sumirem da simulação.
	var counts := {
		"house": 0, "shop": 0, "workshop": 0, "inn": 0, "tavern": 0, "town_hall": 0,
		"temple": 0, "library": 0, "infirmary": 0, "guard_post": 0, "lookout": 0,
		"depot": 0, "shelter": 0, "stable": 0, "mill": 0, "barn": 0, "well": 0, "ruin": 0
	}
	var city: Dictionary = cities.get(city_id, {})
	for building_id in city.get("building_ids", []):
		var record: Dictionary = buildings.get(str(building_id), {})
		var kind := str(record.get("kind", ""))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
	return counts


func get_population_target(city_id: String) -> int:
	# A capacidade do assentamento considera habitação, comércio, serviços e ofícios.
	var city: Dictionary = cities.get(city_id, {})
	if city.is_empty():
		return 6
	var counts: Dictionary = get_city_building_counts(city_id)
	var house_count: int = int(counts.get("house", 0))
	var commerce_count: int = int(counts.get("shop", 0)) + int(counts.get("inn", 0)) + int(counts.get("tavern", 0))
	var production_count: int = int(counts.get("workshop", 0)) + int(counts.get("mill", 0)) + int(counts.get("barn", 0)) + int(counts.get("stable", 0)) + int(counts.get("depot", 0))
	var public_services: int = int(counts.get("town_hall", 0)) + int(counts.get("temple", 0)) + int(counts.get("library", 0)) + int(counts.get("infirmary", 0)) + int(counts.get("guard_post", 0))
	var target: int = 4 + int(ceil(float(house_count) * 0.30)) + int(ceil(float(commerce_count) * 0.16)) + int(ceil(float(production_count) * 0.12)) + mini(public_services, 3)
	return clampi(target, 6, 24)


func _register_profile(profile: Dictionary) -> void:
	var npc_id := str(profile["id"])
	var city_id := str(profile["city_id"])
	var home_id := str(profile["home_id"])
	var profile_gender := str(profile.get("gender", "male"))
	var profile_age_stage := str(profile.get("age_stage", "adult"))
	var profile_role := str(profile.get("role", "aldeao"))
	var profile_sprite_key := str(profile.get("sprite_key", _sprite_key_for(profile_role, profile_gender, profile_age_stage)))
	var saved_memories: Variant = profile.get("known_world_events", _previous_records.get(npc_id, {}).get("known_world_events", []))
	var memory_records: Array = saved_memories.duplicate(true) if saved_memories is Array else []
	var player_relation_value: Variant = profile.get("player_relationship", _previous_records.get(npc_id, {}).get("player_relationship", {}))
	var saved_player_relation: Dictionary = player_relation_value.duplicate(true) if player_relation_value is Dictionary else {}
	var life_state_value: Variant = profile.get("life_state", _previous_records.get(npc_id, {}).get("life_state", {}))
	var saved_life_state: Dictionary = life_state_value.duplicate(true) if life_state_value is Dictionary else {}
	_active_records[npc_id] = {
		"id": npc_id,
		"person_name": str(profile["person_name"]),
		"gender": profile_gender,
		"age_stage": profile_age_stage,
		"sprite_key": profile_sprite_key,
		"personality": str(profile.get("personality", _personality_for(npc_id))),
		"speech_style": str(profile.get("speech_style", "direto")),
		"personal_interest": str(profile.get("personal_interest", "os costumes locais")),
		"personal_goal": str(profile.get("personal_goal", "aprender algo que ainda não sei")),
		"sociability": float(profile.get("sociability", 0.55)),
		"curiosity": float(profile.get("curiosity", 0.5)),
		"role": str(profile["role"]),
		"merchant_type": str(profile.get("merchant_type", "none")),
		"merchant_last_city_id": str(profile.get("merchant_last_city_id", "")),
		"merchant_trips_completed": int(profile.get("merchant_trips_completed", 0)),
		"messenger_trips_completed": int(profile.get("messenger_trips_completed", 0)),
		"messenger_carried_news": profile.get("messenger_carried_news", []).duplicate(true) if profile.get("messenger_carried_news", []) is Array else [],
		"city_id": city_id,
		"origin_city_id": str(profile["origin_city_id"]),
		"home_id": home_id,
		"work_building_id": str(profile.get("work_building_id", "")),
		"partner_id": str(profile.get("partner_id", _previous_records.get(npc_id, {}).get("partner_id", ""))),
		"age_years": float(profile.get("age_years", 18.0)),
		"birth_world_hours": float(profile.get("birth_world_hours", _world_clock_hours)),
		"mother_id": str(profile.get("mother_id", "")),
		"father_id": str(profile.get("father_id", "")),
		"generation": int(profile.get("generation", 0)),
		"family_surname": str(profile.get("family_surname", "")),
		"family_generated": bool(profile.get("family_generated", false)),
		"is_deceased": bool(profile.get("is_deceased", false)),
		"known_world_events": memory_records,
		"player_relationship": saved_player_relation,
		"life_state": saved_life_state
	}
	_ensure_genealogy_record(profile)
	var work_building_id := str(profile.get("work_building_id", ""))
	if buildings.has(work_building_id):
		var work_record: Dictionary = buildings[work_building_id]
		var current_owner_role := str(work_record.get("owner_role", ""))
		var new_role := str(profile.get("role", ""))
		var new_role_has_priority := new_role == "mercador" and current_owner_role == "curandeira"
		if str(work_record.get("owner_npc_id", "")) == "" or new_role_has_priority:
			work_record["owner_npc_id"] = npc_id
			work_record["owner_name"] = str(profile.get("person_name", ""))
			work_record["owner_role"] = new_role
		buildings[work_building_id] = work_record
	# A bruxa única não é contabilizada como moradora de uma cidade ou de uma casa.
	if profile_role != "bruxa":
		if houses.has(home_id):
			var residents: Array = houses[home_id]["resident_ids"]
			if not residents.has(npc_id):
				residents.append(npc_id)
		if cities.has(city_id):
			var people: Array = cities[city_id]["resident_ids"]
			if not people.has(npc_id):
				people.append(npc_id)


# -----------------------------------------------------------------------------
# Genealogia, uniões e ciclo de vida
# -----------------------------------------------------------------------------

func _surname_from_person_name(person_name: String) -> String:
	var words: PackedStringArray = person_name.strip_edges().split(" ", false)
	if words.size() < 2:
		return ""
	for start_index in range(1, words.size()):
		var candidate := " ".join(words.slice(start_index))
		if SURNAMES.has(candidate):
			return candidate
	return str(words[words.size() - 1])


func _generation_from_parents(mother_id: String, father_id: String) -> int:
	var generation := -1
	for parent_id in [mother_id, father_id]:
		if parent_id == "":
			continue
		var parent: Dictionary = _genealogy.get(parent_id, {})
		if not parent.is_empty():
			generation = maxi(generation, int(parent.get("generation", 0)))
	return generation + 1 if generation >= 0 else 0


func _ensure_genealogy_record(profile: Dictionary) -> void:
	var npc_id := str(profile.get("id", ""))
	if npc_id == "" or bool(profile.get("is_unique_witch", false)):
		return
	var record: Dictionary = _genealogy.get(npc_id, {}).duplicate(true)
	var mother_id := str(profile.get("mother_id", record.get("mother_id", "")))
	var father_id := str(profile.get("father_id", record.get("father_id", "")))
	var children: Array = record.get("children_ids", []).duplicate()
	var spouses: Array = record.get("spouse_ids", []).duplicate()
	var unions: Array = record.get("unions", []).duplicate(true)
	var age_years := float(profile.get("age_years", record.get("age_years", 18.0)))
	var generation := int(profile.get("generation", record.get("generation", _generation_from_parents(mother_id, father_id))))
	record.merge({
		"id": npc_id,
		"name": str(profile.get("person_name", record.get("name", "Habitante desconhecido"))),
		"gender": str(profile.get("gender", record.get("gender", "unknown"))),
		"mother_id": mother_id,
		"father_id": father_id,
		"children_ids": children,
		"spouse_ids": spouses,
		"unions": unions,
		"birth_world_hours": float(profile.get("birth_world_hours", record.get("birth_world_hours", _world_clock_hours - age_years * FAMILY_HOURS_PER_YEAR))),
		"age_years": age_years,
		"generation": generation,
		"family_surname": str(profile.get("family_surname", record.get("family_surname", ""))),
		"city_id": str(profile.get("city_id", record.get("city_id", ""))),
		"is_deceased": bool(profile.get("is_deceased", record.get("is_deceased", false))),
		"death_world_hours": float(record.get("death_world_hours", -1.0)),
		"family_generated": bool(profile.get("family_generated", record.get("family_generated", false)))
	}, true)
	_genealogy[npc_id] = record
	if mother_id != "":
		_ensure_genealogy_stub(mother_id)
		_append_unique(_genealogy[mother_id]["children_ids"], npc_id)
	if father_id != "":
		_ensure_genealogy_stub(father_id)
		_append_unique(_genealogy[father_id]["children_ids"], npc_id)


func _ensure_genealogy_stub(npc_id: String) -> void:
	if npc_id == "" or _genealogy.has(npc_id):
		return
	var previous: Dictionary = _active_records.get(npc_id, _previous_records.get(npc_id, {}))
	_genealogy[npc_id] = {
		"id": npc_id,
		"name": str(previous.get("person_name", "Habitante desconhecido")),
		"gender": str(previous.get("gender", "unknown")),
		"mother_id": str(previous.get("mother_id", "")),
		"father_id": str(previous.get("father_id", "")),
		"children_ids": [],
		"spouse_ids": [],
		"unions": [],
		"birth_world_hours": float(previous.get("birth_world_hours", _world_clock_hours)),
		"age_years": float(previous.get("age_years", 18.0)),
		"generation": int(previous.get("generation", 0)),
		"family_surname": str(previous.get("family_surname", "")),
		"city_id": str(previous.get("city_id", "")),
		"is_deceased": bool(previous.get("is_deceased", false)),
		"death_world_hours": -1.0,
		"family_generated": bool(previous.get("family_generated", false))
	}


func _append_unique(values: Array, value: Variant) -> void:
	if not values.has(value):
		values.append(value)


func _record_family_union(first_id: String, second_id: String, started_at: float = -1.0) -> void:
	if first_id == "" or second_id == "" or first_id == second_id:
		return
	_ensure_genealogy_stub(first_id)
	_ensure_genealogy_stub(second_id)
	var first_record: Dictionary = _genealogy[first_id]
	var second_record: Dictionary = _genealogy[second_id]
	_append_unique(first_record["spouse_ids"], second_id)
	_append_unique(second_record["spouse_ids"], first_id)
	var union_id := "union:%s:%s" % ([first_id, second_id] if first_id < second_id else [second_id, first_id])
	var effective_start := started_at if started_at >= 0.0 else _world_clock_hours
	var first_union_found := false
	for index in range(first_record["unions"].size()):
		var union_value: Variant = first_record["unions"][index]
		if union_value is Dictionary and str(union_value.get("id", "")) == union_id:
			var corrected_union: Dictionary = union_value.duplicate(true)
			corrected_union["partner_id"] = second_id
			first_record["unions"][index] = corrected_union
			first_union_found = true
			break
	if not first_union_found:
		first_record["unions"].append({
			"id": union_id,
			"partner_id": second_id,
			"started_at": effective_start,
			"kind": "union",
			"ended_at": -1.0
		})
	var second_union_found := false
	for index in range(second_record["unions"].size()):
		var union_value: Variant = second_record["unions"][index]
		if union_value is Dictionary and str(union_value.get("id", "")) == union_id:
			var corrected_union: Dictionary = union_value.duplicate(true)
			corrected_union["partner_id"] = first_id
			second_record["unions"][index] = corrected_union
			second_union_found = true
			break
	if not second_union_found:
		second_record["unions"].append({
			"id": union_id,
			"partner_id": first_id,
			"started_at": effective_start,
			"kind": "union",
			"ended_at": -1.0
		})
	_genealogy[first_id] = first_record
	_genealogy[second_id] = second_record
	if not first_union_found and not second_union_found:
		_log_debug("FAMÍLIA", "%s e %s formaram uma união." % [str(first_record.get("name", first_id)), str(second_record.get("name", second_id))], str(first_record.get("city_id", "")))


func get_genealogy_record(npc_id: String) -> Dictionary:
	var value: Variant = _genealogy.get(npc_id, {})
	return value.duplicate(true) if value is Dictionary else {}


func get_family_tree(npc_id: String, generations_up: int = 4, generations_down: int = 4) -> Dictionary:
	if not _genealogy.has(npc_id):
		return {}
	return _build_family_tree_node(npc_id, maxi(0, generations_up), maxi(0, generations_down), {})


func _build_family_tree_node(npc_id: String, up_left: int, down_left: int, visited: Dictionary) -> Dictionary:
	if visited.has(npc_id):
		return {"id": npc_id, "cycle_reference": true}
	var record: Dictionary = _genealogy.get(npc_id, {})
	if record.is_empty():
		return {"id": npc_id, "missing_record": true}
	var next_visited := visited.duplicate()
	next_visited[npc_id] = true
	var node := record.duplicate(true)
	node["parents"] = []
	node["children"] = []
	if up_left > 0:
		for parent_id in [str(record.get("mother_id", "")), str(record.get("father_id", ""))]:
			if parent_id != "":
				node["parents"].append(_build_family_tree_node(parent_id, up_left - 1, 0, next_visited))
	if down_left > 0:
		for child_id_value in record.get("children_ids", []):
			var child_id := str(child_id_value)
			node["children"].append(_build_family_tree_node(child_id, 0, down_left - 1, next_visited))
	return node


func get_family_members_to_spawn(city_id: String) -> Array[Dictionary]:
	var members: Array[Dictionary] = []
	for npc_id_value in _previous_records.keys():
		var npc_id := str(npc_id_value)
		var record: Dictionary = _previous_records[npc_id_value]
		if not bool(record.get("family_generated", false)) or bool(record.get("is_deceased", false)):
			continue
		if str(record.get("city_id", "")) != city_id:
			continue
		members.append(record.duplicate(true))
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return members


func get_genealogy_statistics() -> Dictionary:
	var alive := 0
	var deceased := 0
	var roots := 0
	var unions := 0
	for record_value in _genealogy.values():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if bool(record.get("is_deceased", false)):
			deceased += 1
		else:
			alive += 1
		if str(record.get("mother_id", "")) == "" and str(record.get("father_id", "")) == "":
			roots += 1
		var union_values: Variant = record.get("unions", [])
		if union_values is Array:
			unions += union_values.size()
	return {"people": _genealogy.size(), "alive": alive, "deceased": deceased, "founders": roots, "union_records": int(unions / 2)}


func _process_genealogy_time(npc_nodes: Array) -> void:
	var current_day := floori(_world_clock_hours / 24.0)
	if _last_lifecycle_day < 0:
		_last_lifecycle_day = current_day
		return
	while _last_lifecycle_day < current_day:
		_last_lifecycle_day += 1
		var day_clock := float(_last_lifecycle_day) * 24.0
		_update_family_ages(day_clock, npc_nodes)
		_resolve_due_births(day_clock, npc_nodes)
		if posmod(_last_lifecycle_day, FAMILY_CONCEPTION_INTERVAL_DAYS) == 0:
			_try_family_conceptions(day_clock)


func _update_family_ages(at_clock: float, npc_nodes: Array) -> void:
	for npc_id_value in _genealogy.keys():
		var npc_id := str(npc_id_value)
		var lineage: Dictionary = _genealogy[npc_id]
		if bool(lineage.get("is_deceased", false)):
			continue
		var age := maxf(0.0, (at_clock - float(lineage.get("birth_world_hours", at_clock))) / FAMILY_HOURS_PER_YEAR)
		lineage["age_years"] = age
		var new_stage := "child" if age < 16.0 else "adult"
		var previous_profile: Dictionary = _active_records.get(npc_id, _previous_records.get(npc_id, {}))
		var old_stage := str(previous_profile.get("age_stage", "adult"))
		var old_age := int(floor(float(previous_profile.get("age_years", -1.0))))
		if not previous_profile.is_empty() and (old_stage != new_stage or old_age != int(floor(age))):
			var role := str(previous_profile.get("role", "aldeao"))
			var gender := str(lineage.get("gender", "male"))
			var new_sprite := _sprite_key_for(role, gender, new_stage)
			previous_profile["age_stage"] = new_stage
			previous_profile["age_years"] = age
			previous_profile["sprite_key"] = new_sprite
			if _active_records.has(npc_id):
				_active_records[npc_id] = previous_profile.duplicate(true)
			if _previous_records.has(npc_id):
				_previous_records[npc_id] = previous_profile.duplicate(true)
			for npc in npc_nodes:
				if is_instance_valid(npc) and str(npc.get("npc_id")) == npc_id and npc.has_method("update_age_profile"):
					npc.call("update_age_profile", age, new_stage, new_sprite)
		_genealogy[npc_id] = lineage


func _try_family_conceptions(at_clock: float) -> void:
	var checked_pairs: Dictionary = {}
	for relation_value in _relationships.values():
		if not (relation_value is Dictionary):
			continue
		var relation: Dictionary = relation_value
		if str(relation.get("stage", "")) != "partner":
			continue
		var union_started := float(relation.get("union_started_clock", at_clock))
		if at_clock - union_started < FAMILY_MIN_UNION_HOURS:
			continue
		var first_id := str(relation.get("a", ""))
		var second_id := str(relation.get("b", ""))
		var pair_key := _relationship_key(first_id, second_id)
		if checked_pairs.has(pair_key):
			continue
		checked_pairs[pair_key] = true
		var first: Dictionary = _active_records.get(first_id, _previous_records.get(first_id, {}))
		var second: Dictionary = _active_records.get(second_id, _previous_records.get(second_id, {}))
		if first.is_empty() or second.is_empty():
			continue
		if bool(first.get("is_deceased", false)) or bool(second.get("is_deceased", false)):
			continue
		if str(first.get("gender", "")) == str(second.get("gender", "")):
			continue
		if str(first.get("city_id", "")) != str(second.get("city_id", "")):
			continue
		var mother_id := first_id if str(first.get("gender", "")) == "female" else second_id
		var father_id := second_id if mother_id == first_id else first_id
		var mother: Dictionary = first if mother_id == first_id else second
		var father: Dictionary = second if mother_id == first_id else first
		var mother_age := float(mother.get("age_years", 18.0))
		var father_age := float(father.get("age_years", 18.0))
		if mother_age < FAMILY_MIN_PARENT_AGE or mother_age > FAMILY_MAX_MOTHER_AGE or father_age < FAMILY_MIN_PARENT_AGE:
			continue
		_ensure_genealogy_stub(mother_id)
		_ensure_genealogy_stub(father_id)
		var mother_lineage: Dictionary = _genealogy[mother_id]
		var pregnancy_value: Variant = mother_lineage.get("pregnancy", {})
		if pregnancy_value is Dictionary and not pregnancy_value.is_empty():
			continue
		var children: Array = mother_lineage.get("children_ids", [])
		if children.size() >= FAMILY_MAX_CHILDREN_PER_MOTHER:
			continue
		var home_id := str(mother.get("home_id", ""))
		if home_id == "" or not houses.has(home_id):
			continue
		var residents: Array = houses[home_id].get("resident_ids", [])
		if residents.size() >= FAMILY_MAX_HOUSEHOLD_SIZE:
			continue
		var conception_key := "%s|%s|%d" % [pair_key, str(FAMILY_CONCEPTION_INTERVAL_DAYS), int(floor(at_clock / (24.0 * FAMILY_CONCEPTION_INTERVAL_DAYS)))]
		if not _stable_chance(conception_key, FAMILY_CONCEPTION_CHANCE):
			continue
		mother_lineage["pregnancy"] = {
			"father_id": father_id,
			"conception_world_hours": at_clock,
			"due_world_hours": at_clock + FAMILY_GESTATION_HOURS,
			"city_id": str(mother.get("city_id", "")),
			"home_id": home_id
		}
		_genealogy[mother_id] = mother_lineage
		_log_debug("FAMÍLIA", "%s espera um filho de %s." % [str(mother.get("person_name", mother_id)), str(father.get("person_name", father_id))], str(mother.get("city_id", "")))


func _stable_chance(key: String, chance: float) -> bool:
	var normalized := float(posmod(absi(key.hash()), 100000)) / 100000.0
	return normalized < chance


func _resolve_due_births(at_clock: float, npc_nodes: Array) -> void:
	var mothers := _genealogy.keys().duplicate()
	for mother_id_value in mothers:
		var mother_id := str(mother_id_value)
		var mother_lineage: Dictionary = _genealogy.get(mother_id, {})
		var pregnancy_value: Variant = mother_lineage.get("pregnancy", {})
		if not (pregnancy_value is Dictionary) or pregnancy_value.is_empty():
			continue
		var pregnancy: Dictionary = pregnancy_value
		if float(pregnancy.get("due_world_hours", INF)) > at_clock:
			continue
		var mother: Dictionary = _active_records.get(mother_id, _previous_records.get(mother_id, {}))
		var father_id := str(pregnancy.get("father_id", ""))
		var father: Dictionary = _active_records.get(father_id, _previous_records.get(father_id, {}))
		if mother.is_empty() or father.is_empty() or bool(mother.get("is_deceased", false)):
			mother_lineage.erase("pregnancy")
			_genealogy[mother_id] = mother_lineage
			continue
		_create_family_child(mother_id, father_id, mother, father, float(pregnancy.get("due_world_hours", at_clock)), npc_nodes)
		var updated_mother_lineage: Dictionary = _genealogy.get(mother_id, {})
		updated_mother_lineage.erase("pregnancy")
		_genealogy[mother_id] = updated_mother_lineage


func _create_family_child(mother_id: String, father_id: String, mother: Dictionary, father: Dictionary, birth_clock: float, npc_nodes: Array) -> void:
	var mother_lineage: Dictionary = _genealogy.get(mother_id, {})
	var birth_index := int(mother_lineage.get("birth_count", 0)) + 1
	var child_id := "npc:family:%s:%03d" % [mother_id.replace(":", "_"), birth_index]
	if _genealogy.has(child_id) or _previous_records.has(child_id) or _active_records.has(child_id):
		return
	var gender := "female" if posmod(absi((child_id + "|gender").hash()), 2) == 0 else "male"
	var first_names: Array = FEMALE_FIRST_NAMES if gender == "female" else MALE_FIRST_NAMES
	var name_seed := absi((child_id + "|first-name").hash())
	var first_name := str(first_names[posmod(name_seed, first_names.size())])
	var family_surname := _surname_from_person_name(str(father.get("person_name", "")))
	if family_surname == "":
		family_surname = _surname_from_person_name(str(mother.get("person_name", "")))
	if family_surname == "":
		family_surname = str(SURNAMES[posmod(name_seed, SURNAMES.size())])
	var person_name := "%s %s" % [first_name, family_surname]
	var ordinal := int(cities.get(str(mother.get("city_id", "")), {}).get("resident_ids", []).size())
	var parent_generation := maxi(int(mother_lineage.get("generation", 0)), int(_genealogy.get(father_id, {}).get("generation", 0)))
	var city_id := str(mother.get("city_id", ""))
	var home_id := str(mother.get("home_id", ""))
	var home: Dictionary = houses.get(home_id, {})
	var home_position: Vector3 = home.get("entry", mother.get("home_position", Vector3.ZERO))
	_previous_records[child_id] = {
		"id": child_id,
		"person_name": person_name,
		"gender": gender,
		"age_stage": "child",
		"age_years": 0.0,
		"birth_world_hours": birth_clock,
		"mother_id": mother_id,
		"father_id": father_id,
		"generation": parent_generation + 1,
		"family_surname": family_surname,
		"family_generated": true,
		"is_deceased": false,
		"city_id": city_id,
		"origin_city_id": city_id,
		"home_id": home_id,
		"role": "aldeao",
		"life_state": {
			"city_id": city_id,
			"mode": "home",
			"position": [home_position.x, home_position.y, home_position.z],
			"life_bucket": "home",
			"target_kind": "home",
			"world_clock_hours": birth_clock
		}
	}
	var child_profile := create_profile(child_id, "aldeao", city_id, ordinal, "Aldeão")
	if child_profile.is_empty():
		_previous_records.erase(child_id)
		return
	child_profile["person_name"] = person_name
	child_profile["display_name"] = person_name
	child_profile["age_years"] = 0.0
	child_profile["age_stage"] = "child"
	child_profile["birth_world_hours"] = birth_clock
	child_profile["sprite_key"] = _sprite_key_for("aldeao", gender, "child")
	child_profile["mother_id"] = mother_id
	child_profile["father_id"] = father_id
	child_profile["generation"] = parent_generation + 1
	child_profile["family_surname"] = family_surname
	child_profile["family_generated"] = true
	var child_record: Dictionary = _active_records.get(child_id, {})
	child_record["person_name"] = person_name
	child_record["age_years"] = 0.0
	child_record["age_stage"] = "child"
	child_record["birth_world_hours"] = birth_clock
	child_record["mother_id"] = mother_id
	child_record["father_id"] = father_id
	child_record["generation"] = parent_generation + 1
	child_record["family_surname"] = family_surname
	child_record["family_generated"] = true
	child_record["sprite_key"] = child_profile["sprite_key"]
	_active_records[child_id] = child_record
	_previous_records[child_id] = child_record.duplicate(true)
	_ensure_genealogy_record(child_profile)
	mother_lineage["birth_count"] = birth_index
	_append_unique(mother_lineage["children_ids"], child_id)
	_genealogy[mother_id] = mother_lineage
	var father_lineage: Dictionary = _genealogy.get(father_id, {})
	_append_unique(father_lineage["children_ids"], child_id)
	_genealogy[father_id] = father_lineage
	var spawn_position: Vector3 = home_position
	for parent_node in npc_nodes:
		if is_instance_valid(parent_node) and str(parent_node.get("npc_id")) == mother_id:
			spawn_position = parent_node.global_position if parent_node.is_inside_tree() else home_position
			break
	npc_born.emit(child_profile, spawn_position)
	_log_debug("FAMÍLIA", "Nasceu %s, filho de %s e %s." % [person_name, str(mother.get("person_name", mother_id)), str(father.get("person_name", father_id))], city_id)
	_refresh_household_members(home_id, npc_nodes)


func _refresh_household_members(home_id: String, npc_nodes: Array) -> void:
	if home_id == "":
		return
	var member_ids: Array = []
	var member_names: Array = []
	var home_record: Dictionary = houses.get(home_id, {})
	for member_id_value in home_record.get("resident_ids", []):
		var member_id := str(member_id_value)
		var member_record: Dictionary = _active_records.get(member_id, _previous_records.get(member_id, {}))
		if member_record.is_empty():
			continue
		member_ids.append(member_id)
		member_names.append(str(member_record.get("person_name", member_id)))
	for npc in npc_nodes:
		if is_instance_valid(npc) and str(npc.get("home_id")) == home_id and npc.has_method("set_household_members"):
			npc.call("set_household_members", member_ids, member_names)


func _select_home(city_id: String, ordinal: int) -> String:
	var city: Dictionary = cities[city_id]
	var home_ids: Array = city["house_ids"]
	if home_ids.is_empty():
		_ensure_virtual_homes(city_id)
		home_ids = city["house_ids"]
	if home_ids.is_empty():
		return ""
	var available_home_ids: Array[String] = []
	for home_id_value in home_ids:
		var home_id := str(home_id_value)
		if home_id == reserved_player_home_id or bool(houses.get(home_id, {}).get("is_post_office", false)):
			continue
		available_home_ids.append(home_id)
	# Se não houver outra casa possível, mantém a cidade funcional como contingência.
	if available_home_ids.is_empty():
		for home_id_value in home_ids:
			var fallback_id := str(home_id_value)
			if fallback_id != reserved_player_home_id and not bool(houses.get(fallback_id, {}).get("is_post_office", false)):
				available_home_ids.append(fallback_id)
	if available_home_ids.is_empty():
		for home_id_value in home_ids:
			var fallback_id := str(home_id_value)
			if fallback_id != reserved_player_home_id:
				available_home_ids.append(fallback_id)
	# Os dois primeiros habitantes partilham uma residência; os seguintes usam
	# as demais casas sem ocupar a residência reservada ao jogador.
	var slot := 0 if ordinal <= 1 else ordinal - 1
	return available_home_ids[mini(slot, available_home_ids.size() - 1)]


func _preferred_work_kinds(role: String) -> Array[String]:
	match role:
		"ferreiro": return ["workshop"]
		"mercador": return ["shop"]
		"estalajadeiro": return ["inn"]
		"mensageiro": return ["house"]
		# Curandeiras trabalham em boticas/lojas ou enfermarias; nunca transformam
		# uma estalagem/oficina em local de cura por causa do cargo do proprietário.
		"curandeira": return ["infirmary", "shop"]
		"guarda": return ["guard_post", "lookout", "town_hall"]
		"aldeao": return ["mill", "barn", "stable", "depot", "shelter"]
		_: return []


func _work_position_for(city_id: String, role: String, selected_building_id: String = "") -> Vector3:
	var city: Dictionary = cities.get(city_id, {})
	var choice: Dictionary = buildings.get(selected_building_id, {})
	if choice.is_empty():
		var candidates: Array = []
		var preferred_kinds := _preferred_work_kinds(role)
		for building_id in city.get("building_ids", []):
			var record: Dictionary = buildings.get(str(building_id), {})
			if str(record.get("kind", "")) in preferred_kinds:
				candidates.append(record)
		if candidates.is_empty():
			return Vector3.ZERO
		choice = candidates[0]
	# O destino fica do lado de fora da entrada frontal, não espalhado pela calçada.
	var entry: Vector3 = choice.get("entry", choice.get("center", Vector3.ZERO))
	var facing: Vector3 = choice.get("front_direction", Vector3.FORWARD)
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		facing = Vector3.FORWARD
	facing = facing.normalized()
	var side := Vector3(-facing.z, 0.0, facing.x)
	var candidates: Array[Vector3] = [
		_ground(entry + facing * 3.3),
		_ground(entry + facing * 3.9),
		_ground(entry + facing * 2.8 + side * 1.6),
		_ground(entry + facing * 2.8 - side * 1.6),
		_ground(entry + facing * 3.4 + side * 2.5),
		_ground(entry + facing * 3.4 - side * 2.5)
	]
	var building_id := str(choice.get("id", selected_building_id))
	for work_stand in candidates:
		work_stand.y += 0.03
		if building_id != "" and not _is_in_front_of_building(building_id, work_stand):
			continue
		if _point_overlaps_building_footprint(work_stand, choice, 0.35):
			continue
		if _point_overlaps_any_building(city_id, work_stand, 0.35):
			continue
		return work_stand
	var fallback: Vector3 = _ground(entry + facing * 3.4 + side * 2.0)
	fallback.y += 0.03
	return fallback


func _work_building_id_for(city_id: String, role: String) -> String:
	if role == "mensageiro":
		return _ensure_post_office_id(city_id)
	var city: Dictionary = cities.get(city_id, {})
	if city.is_empty():
		return ""
	var preferred_kinds := _preferred_work_kinds(role)
	if preferred_kinds.is_empty():
		return ""
	var candidates: Array[String] = []
	for building_id_value in city.get("building_ids", []):
		var building_id := str(building_id_value)
		var record: Dictionary = buildings.get(building_id, {})
		if str(record.get("kind", "")) in preferred_kinds:
			candidates.append(building_id)
	# Prioriza estabelecimentos sem trabalhador associado para distribuir os habitantes.
	for candidate_id in candidates:
		var candidate: Dictionary = buildings.get(candidate_id, {})
		if str(candidate.get("owner_npc_id", "")) == "":
			return candidate_id
	# Aldeões excedentes continuam com uma rotina livre em vez de todos serem
	# empilhados no mesmo celeiro/estábulo. Serviços essenciais podem partilhar turno.
	if role == "aldeao":
		return ""
	return candidates[0] if not candidates.is_empty() else ""


func _building_id_for_entry(city_id: String, destination: Vector3) -> String:
	var city: Dictionary = cities.get(city_id, {})
	var nearest_id := ""
	var nearest_distance := 1.6
	for building_value in city.get("building_ids", []):
		var building_id := str(building_value)
		var record: Dictionary = buildings.get(building_id, {})
		if record.is_empty():
			continue
		var distance := _horizontal_distance(destination, record.get("entry", Vector3.ZERO))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = building_id
	return nearest_id


func _is_in_front_of_building(building_id: String, point: Vector3) -> bool:
	var record: Dictionary = buildings.get(building_id, {})
	if record.is_empty():
		return true
	var outward: Vector3 = record.get("front_direction", Vector3.FORWARD)
	outward.y = 0.0
	if outward.length_squared() < 0.001:
		return true
	outward = outward.normalized()
	var door_point: Vector3 = record.get("door_position", record.get("entry", Vector3.ZERO))
	var offset := Vector3(point.x - door_point.x, 0.0, point.z - door_point.z)
	return offset.dot(outward) >= 0.0


func _point_overlaps_any_building(city_id: String, point: Vector3, margin: float = 0.35) -> bool:
	var city: Dictionary = cities.get(city_id, {})
	for building_value in city.get("building_ids", []):
		var record: Dictionary = buildings.get(str(building_value), {})
		if record.is_empty():
			continue
		if _point_overlaps_building_footprint(point, record, margin):
			return true
	return false


func _collect_buildings(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var found := _building_regex.search(str(child.name).to_lower())
			if found != null:
				var city_id := "settlement_%s" % found.get_string(1)
				if cities.has(city_id):
					var building_number := str(int(found.get_string(2))).pad_zeros(3)
					var kind := found.get_string(3)
					var id := "%s/building_%s" % [city_id, building_number]
					var bounds: AABB = child.global_transform * child.get_aabb()
					var city: Dictionary = cities[city_id]
					var record := {
						"id": id,
						"name": _building_display_name(kind, building_number, str(city["name"])),
						"city_id": city_id,
						"kind": kind,
						# Templos e ruínas são marcos do mundo, não salas visitáveis.
						"is_landmark": kind in ["temple", "ruin", "ruins"],
						"supports_interior": kind in ["house", "shop", "workshop", "inn", "town_hall", "library", "infirmary", "guard_post", "lookout", "depot", "shelter", "stable", "mill", "barn"],
						"entry": bounds.get_center(),
						"center": bounds.get_center(),
						"bounds": bounds,
						"front_direction": _building_front_direction(child),
						"front_depth": child.get_aabb().size.z * child.global_transform.basis.z.length() * 0.5,
						"node": child,
						"virtual": false,
						"resident_ids": [],
						"resident_names": []
					}
					buildings[id] = record
					city["building_ids"].append(id)
					if kind == "house":
						houses[id] = record
						city["house_ids"].append(id)
		_collect_buildings(child)


func _finalize_building_entries() -> void:
	# Calcula as entradas depois de conhecer todos os edifícios. Assim, uma porta
	# virtual não é colocada dentro da casa vizinha em ruas mais apertadas.
	for building_id in buildings.keys():
		var record: Dictionary = buildings[building_id]
		var city: Dictionary = cities[str(record["city_id"])]
		var front_direction: Vector3 = record.get("front_direction", Vector3.FORWARD)
		var front_depth: float = float(record.get("front_depth", -1.0))
		var entry := _compute_entry(record["bounds"], city["center"], str(building_id), front_direction, front_depth)
		record["entry"] = entry
		var door_position: Vector3 = record["bounds"].get_center() + front_direction.normalized() * front_depth
		door_position.y = entry.y
		record["door_position"] = door_position
		buildings[building_id] = record
		if houses.has(str(building_id)):
			var house_record: Dictionary = houses[str(building_id)]
			house_record["entry"] = entry
			house_record["door_position"] = door_position
			house_record["front_direction"] = front_direction
			house_record["front_depth"] = front_depth
			houses[str(building_id)] = house_record


func _building_front_direction(building: MeshInstance3D) -> Vector3:
	# Nos modelos atuais do overworld.glb, a fachada/porta está no lado +Z
	# do eixo local exportado pelo Blender. Usar -basis.z colocava as entradas
	# virtuais no lado oposto da construção. Mantemos a orientação transformada
	# pelo GLB para respeitar a rotação individual de cada edifício.
	var direction: Vector3 = building.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return Vector3.BACK
	return direction.normalized()


func _compute_entry(bounds: AABB, city_center: Vector3, own_id: String, front_direction: Vector3 = Vector3.FORWARD, front_depth: float = -1.0) -> Vector3:
	# A entrada simulada fica no lado frontal orientado no Blender. Usa a
	# profundidade local do modelo, não a projeção da AABB mundial: em casas
	# giradas, a projeção pode duplicar a distância e deixar o NPC longe da porta.
	var center: Vector3 = bounds.get_center()
	var direction := Vector3(front_direction.x, 0.0, front_direction.z)
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var projected_half_extent: float = absf(direction.x) * bounds.size.x * 0.5 + absf(direction.z) * bounds.size.z * 0.5
	var depth: float = front_depth if front_depth > 0.0 else projected_half_extent
	var candidate: Vector3 = center + direction * (depth + HOME_ENTRY_MARGIN)
	candidate.y = bounds.position.y + 0.05

	# Se outro edifício estiver bloqueando a saída, afasta o acesso ao longo da
	# mesma fachada até criar espaço suficiente para a cápsula do NPC.
	var own_city_id: String = str(buildings.get(own_id, {}).get("city_id", ""))
	for _attempt in 6:
		var blocked := false
		for other_id in buildings.keys():
			if str(other_id) == own_id:
				continue
			var other: Dictionary = buildings[other_id]
			if str(other.get("city_id", "")) != own_city_id:
				continue
			# Usar a AABB mundial aqui criava falsos bloqueios em edifícios girados;
			# o ponto de entrada era empurrado vários metros para a rua, longe da porta.
			if _point_overlaps_building_footprint(candidate, other, 0.8):
				blocked = true
				break
		if not blocked:
			break
		candidate += direction * 1.25
	var grounded: Vector3 = _ground(candidate)
	if absf(grounded.y - candidate.y) < 4.0:
		candidate.y = grounded.y + 0.03
	return candidate


func _point_overlaps_building_footprint(point: Vector3, building: Dictionary, margin: float) -> bool:
	var node_value: Variant = building.get("node")
	if node_value is MeshInstance3D and is_instance_valid(node_value):
		var mesh_node: MeshInstance3D = node_value as MeshInstance3D
		var local_point: Vector3 = mesh_node.global_transform.affine_inverse() * point
		var local_bounds: AABB = mesh_node.get_aabb()
		return (
			local_point.x >= local_bounds.position.x - margin
			and local_point.x <= local_bounds.end.x + margin
			and local_point.z >= local_bounds.position.z - margin
			and local_point.z <= local_bounds.end.z + margin
		)
	# Fallback para construções virtuais ou sem nó de geometria próprio.
	var bounds: AABB = building.get("bounds", AABB())
	return point.x >= bounds.position.x - margin and point.x <= bounds.end.x + margin and point.z >= bounds.position.z - margin and point.z <= bounds.end.z + margin


func _ensure_virtual_homes(city_id: String) -> void:
	var city: Dictionary = cities[city_id]
	var existing_homes: Array = city["house_ids"]
	if not existing_homes.is_empty():
		return
	var center: Vector3 = city["center"]
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var radius := 9.0 + float(i % 3) * 3.0
		var point := _ground(center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		var id := "%s/virtual_house_%02d" % [city_id, i + 1]
		var record := {
			"id": id,
			"name": "Casa %02d de %s" % [i + 1, str(city["name"])],
			"city_id": city_id,
			"kind": "house",
			"entry": point,
			"center": point,
			"front_direction": (point - center).normalized(),
			"door_position": point - (point - center).normalized() * HOME_ENTRY_MARGIN,
			"front_depth": 0.0,
			"bounds": AABB(point, Vector3.ZERO),
			"node": null,
			"virtual": true,
			"resident_ids": [],
			"resident_names": []
		}
		houses[id] = record
		city["house_ids"].append(id)


func _sort_city_records(city_id: String) -> void:
	var city: Dictionary = cities[city_id]
	var home_ids: Array = city["house_ids"]
	var building_ids: Array = city["building_ids"]
	home_ids.sort()
	building_ids.sort()


func _build_public_points(city_id: String) -> void:
	var city: Dictionary = cities[city_id]
	var points: Array[Vector3] = []
	for building_id in city["building_ids"]:
		var rec: Dictionary = buildings[str(building_id)]
		points.append(rec["entry"])
	for house_id in city["house_ids"]:
		var rec: Dictionary = houses[str(house_id)]
		if not points.has(rec["entry"]):
			points.append(rec["entry"])
	if points.is_empty():
		var center: Vector3 = city["center"]
		for offset in [Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5), Vector3(0, 0, -5)]:
			points.append(_ground(center + offset))
	city["public_positions"] = points


func _build_guard_posts(city_id: String) -> void:
	# O GLB não tem objetos de portão independentes. Criamos quatro postos
	# posicionados no perímetro real dos edifícios, projetados sobre o terreno.
	var city: Dictionary = cities.get(city_id, {})
	if city.is_empty():
		return
	var total := AABB()
	var has_bounds := false
	for building_value in city.get("building_ids", []):
		var record: Dictionary = buildings.get(str(building_value), {})
		if record.is_empty():
			continue
		var building_bounds: AABB = record.get("bounds", AABB())
		if not has_bounds:
			total = building_bounds
			has_bounds = true
		else:
			total = total.merge(building_bounds)
	var center: Vector3 = city.get("center", Vector3.ZERO)
	var candidates: Array[Vector3] = []
	if has_bounds:
		var middle_x: float = (total.position.x + total.end.x) * 0.5
		var middle_z: float = (total.position.z + total.end.z) * 0.5
		candidates.append(Vector3(middle_x, total.position.y, total.position.z - GUARD_GATE_OFFSET))
		candidates.append(Vector3(total.end.x + GUARD_GATE_OFFSET, total.position.y, middle_z))
		candidates.append(Vector3(middle_x, total.position.y, total.end.z + GUARD_GATE_OFFSET))
		candidates.append(Vector3(total.position.x - GUARD_GATE_OFFSET, total.position.y, middle_z))
	else:
		candidates.append(center + Vector3(0, 0, -22))
		candidates.append(center + Vector3(22, 0, 0))
		candidates.append(center + Vector3(0, 0, 22))
		candidates.append(center + Vector3(-22, 0, 0))
	var posts: Array[Vector3] = []
	for candidate in candidates:
		var grounded: Vector3 = _ground(candidate)
		grounded.y += 0.03
		posts.append(grounded)
	city["gate_positions"] = posts
	cities[city_id] = city


func get_guard_posts_for_city(city_id: String) -> Array:
	var city: Dictionary = cities.get(city_id, {})
	var value: Variant = city.get("gate_positions", [])
	if value is Array:
		return value.duplicate()
	return []


func _building_display_name(kind: String, number: String, city_name: String) -> String:
	match kind:
		"house": return "Casa desocupada de %s" % city_name
		"shop": return "Loja de %s" % city_name
		"workshop": return "Oficina de %s" % city_name
		"inn": return "Estalagem de %s" % city_name
		"town_hall": return "Salão comunal de %s" % city_name
		"temple": return "Templo de %s" % city_name
		"library": return "Biblioteca de %s" % city_name
		"infirmary": return "Enfermaria de %s" % city_name
		"guard_post": return "Posto da Guarda de %s" % city_name
		"lookout": return "Mirante de %s" % city_name
		"depot": return "Depósito de %s" % city_name
		"shelter": return "Abrigo de %s" % city_name
		"stable": return "Estábulo de %s" % city_name
		"mill": return "Moinho de %s" % city_name
		"barn": return "Celeiro de %s" % city_name
		"well": return "Poço de %s" % city_name
		"ruin": return "Ruínas de %s" % city_name
		_: return "Edifício de %s" % city_name


func _house_display_name(resident_names: Array, city_name: String) -> String:
	var names: Array[String] = []
	for name_value in resident_names:
		var person_name := str(name_value).strip_edges()
		if person_name != "" and not names.has(person_name):
			names.append(person_name)
	if names.is_empty():
		return "Casa desocupada de %s" % city_name
	if names.size() == 1:
		return "Casa de %s" % names[0]
	if names.size() == 2:
		return "Casa de %s e %s" % [names[0], names[1]]
	return "Casa de %s e família" % names[0]


func _refresh_owned_building_names() -> void:
	for building_id_value in buildings.keys():
		var building_id := str(building_id_value)
		var record: Dictionary = buildings[building_id]
		if bool(record.get("virtual", false)) or str(record.get("kind", "")) == "house":
			continue
		var owner_name := str(record.get("owner_name", ""))
		if owner_name == "":
			continue
		var owner_role := str(record.get("owner_role", ""))
		var kind := str(record.get("kind", ""))
		# O tipo físico da construção sempre tem prioridade sobre a profissão do
		# proprietário. Uma curandeira numa atribuição antiga não pode fazer uma
		# estalagem aparecer como Botica, por exemplo.
		match kind:
			"inn":
				record["name"] = "Estalagem de %s" % owner_name
			"shop":
				record["name"] = "Botica de %s" % owner_name if owner_role == "curandeira" else "Loja de %s" % owner_name
			"infirmary":
				record["name"] = "Botica de %s" % owner_name if owner_role == "curandeira" else "Enfermaria de %s" % owner_name
			"workshop":
				record["name"] = "Ferraria de %s" % owner_name if owner_role == "ferreiro" else "Oficina de %s" % owner_name
			"town_hall":
				pass
		buildings[building_id] = record

func _generate_name(city_id: String, ordinal: int, gender: String = "male", npc_id: String = "") -> String:
	var first_names: Array = FEMALE_FIRST_NAMES if gender == "female" else MALE_FIRST_NAMES
	if first_names.is_empty() or SURNAMES.is_empty():
		return "Habitante de Brumaférrea"
	var identity_key := npc_id if npc_id != "" else "%s|%d|%s" % [city_id, ordinal, gender]
	var first_seed := absi((identity_key + "|nome").hash())
	var surname_seed := absi((identity_key + "|apelido").hash())
	var first_start := posmod(first_seed, first_names.size())
	var surname_start := posmod(surname_seed, SURNAMES.size())
	var used_names: Dictionary = {}
	for records_variant in [_active_records, _previous_records]:
		var records: Dictionary = records_variant
		for existing_id_variant in records.keys():
			var existing_id := str(existing_id_variant)
			if existing_id == npc_id:
				continue
			var existing_name := str(records[existing_id_variant].get("person_name", "")).strip_edges()
			if existing_name != "":
				used_names[existing_name.to_lower()] = true
	# Percorre as combinações de modo determinístico, desviando-se de nomes já usados.
	# Com dezenas de nomes próprios e mais de uma centena de apelidos, o repertório é
	# suficientemente amplo para as populações atuais sem atribuições aleatórias a cada carga.
	var combination_count := first_names.size() * SURNAMES.size()
	for attempt in range(combination_count):
		var first_index := posmod(first_start + int(attempt / SURNAMES.size()), first_names.size())
		var surname_index := posmod(surname_start + attempt, SURNAMES.size())
		var candidate := "%s %s" % [str(first_names[first_index]), str(SURNAMES[surname_index])]
		if not used_names.has(candidate.to_lower()):
			return candidate
	# Último recurso extremamente improvável: mantém a identidade determinística.
	return "%s %s %d" % [str(first_names[first_start]), str(SURNAMES[surname_start]), posmod(first_seed, 999) + 1]


func _is_portuguese_name(person_name: String, gender: String) -> bool:
	var clean_name := person_name.strip_edges()
	if clean_name == "" or gender not in ["male", "female"]:
		return false
	var words: PackedStringArray = clean_name.split(" ", false)
	if words.size() < 2 or _gender_from_name(clean_name) != gender:
		return false
	var surname := " ".join(words.slice(1))
	return SURNAMES.has(surname)


func _gender_for_id(npc_id: String) -> String:
	# Gênero estável por ID, sem sorteios que mudem a cada carregamento.
	var gender_bit := posmod(absi((npc_id + "|gender").hash()), 2)
	return "female" if gender_bit == 1 else "male"


func _gender_from_name(person_name: String) -> String:
	var first_name := person_name.strip_edges().split(" ")[0] if person_name.strip_edges() != "" else ""
	if first_name == "":
		return ""
	if MALE_FIRST_NAMES.has(first_name):
		return "male"
	if FEMALE_FIRST_NAMES.has(first_name):
		return "female"
	return ""


func _occupation_label(role: String, gender: String, fallback_label: String = "") -> String:
	match role:
		"ferreiro": return "Ferreira" if gender == "female" else "Ferreiro"
		"estalajadeiro": return "Estalajadeira" if gender == "female" else "Estalajadeiro"
		"guarda": return "Guarda"
		"mercador": return "Mercadora" if gender == "female" else "Mercador"
		"curandeira": return "Curandeira" if gender == "female" else "Curandeiro"
		"aldeao": return "Aldeã" if gender == "female" else "Aldeão"
		"mensageiro": return "Mensageira" if gender == "female" else "Mensageiro"
		"bruxa": return "Bruxa"
	return fallback_label if fallback_label != "" else role.capitalize()


func _sprite_key_for(role: String, gender: String, age_stage: String = "adult") -> String:
	# Crianças usam sprites próprios; ao completar 16 anos, recebem o sprite adulto da função.
	if age_stage in ["child", "criança", "crianca"]:
		return "girl" if gender == "female" else "boy"
	match role:
		"ferreiro": return "female_blacksmith" if gender == "female" else "blacksmith"
		"estalajadeiro": return "npcfemale" if gender == "female" else "npcmale"
		"guarda": return "female_guard" if gender == "female" else "guard"
		"mercador": return "female_merchant" if gender == "female" else "merchant"
		"curandeira": return "healer" if gender == "female" else "male_healer"
		"mensageiro": return "female_messenger" if gender == "female" else "messenger"
		"bruxa": return "witch"
		"aldeao": return "npcfemale" if gender == "female" else "npcmale"
	return "npcfemale" if gender == "female" else "npcmale"


func _relationship_key(first_id: String, second_id: String) -> String:
	var pair_ids: Array[String] = [first_id, second_id]
	pair_ids.sort()
	return "%s|%s" % [pair_ids[0], pair_ids[1]]


func _relationship_between(first_id: String, second_id: String) -> Dictionary:
	if first_id == "" or second_id == "" or first_id == second_id:
		return {}
	var key := _relationship_key(first_id, second_id)
	var value: Variant = _relationships.get(key, {})
	return value.duplicate(true) if value is Dictionary else {}


func get_relationship(first_id: String, second_id: String) -> Dictionary:
	# API pública para UI futura, árvores genealógicas e diálogos contextuais.
	return _relationship_between(first_id, second_id)


func get_partner_id(npc_id: String) -> String:
	for value in _relationships.values():
		if not (value is Dictionary) or str(value.get("stage", "")) != "partner":
			continue
		if str(value.get("a", "")) == npc_id:
			return str(value.get("b", ""))
		if str(value.get("b", "")) == npc_id:
			return str(value.get("a", ""))
	return ""


func _are_romantic_partners(first, second) -> bool:
	return str(_relationship_between(str(first.npc_id), str(second.npc_id)).get("stage", "")) == "partner"


func _record_social_interaction(first, second, topic: String) -> void:
	var first_id := str(first.npc_id)
	var second_id := str(second.npc_id)
	if first_id == "" or second_id == "" or first_id == second_id:
		return
	var key := _relationship_key(first_id, second_id)
	var relation: Dictionary = _relationships.get(key, {})
	var previous_stage := str(relation.get("stage", ""))
	if relation.is_empty():
		relation = {
			"a": first_id if first_id < second_id else second_id,
			"b": second_id if first_id < second_id else first_id,
			"familiarity": 0.0,
			"affinity": 0.0,
			"romance": 0.0,
			"interactions": 0,
			"stage": "stranger",
			"last_topic": "",
			"topic_counts": {}
		}
	var interaction_count := int(relation.get("interactions", 0)) + 1
	var familiarity := float(relation.get("familiarity", 0.0))
	var affinity := float(relation.get("affinity", 0.0))
	var romance := float(relation.get("romance", 0.0))
	familiarity = minf(100.0, familiarity + (10.0 if interaction_count == 1 else 6.5))
	var affinity_gain := _compatibility_gain(first, second, topic)
	affinity = minf(100.0, affinity + affinity_gain)
	var topics: Dictionary = {}
	var saved_topics: Variant = relation.get("topic_counts", {})
	if saved_topics is Dictionary:
		topics = saved_topics.duplicate(true)
	topics[topic] = int(topics.get(topic, 0)) + 1
	var stage := _relationship_stage(familiarity, affinity)
	if str(relation.get("stage", "")) == "partner":
		stage = "partner"
	elif _romance_eligible(first, second) and interaction_count >= 7 and familiarity >= 45.0 and affinity >= 30.0:
		# Atração cresce aos poucos, apenas depois de vários encontros positivos.
		# Não há namoro automático por proximidade nem no primeiro diálogo.
		romance = minf(100.0, romance + 8.5 + maxf(0.0, affinity_gain - 4.0))
		if romance >= 34.0 and familiarity >= 60.0 and affinity >= 42.0 and randf() < 0.28 and not _npc_has_partner(first_id) and not _npc_has_partner(second_id):
			stage = "partner"
			relation["formed_at_interaction"] = interaction_count
			relation["union_started_clock"] = _world_clock_hours
			relation["partnered"] = true
			_set_partner_profile_field(first_id, second_id)
			_set_partner_profile_field(second_id, first_id)
	else:
		# Romance não avança fora de relações elegíveis; amizade pode, por outro lado,
		# desenvolver-se entre quaisquer habitantes adultos ou não adultos.
		romance = maxf(0.0, romance - 0.5)
	relation["a"] = first_id if first_id < second_id else second_id
	relation["b"] = second_id if first_id < second_id else first_id
	relation["familiarity"] = familiarity
	relation["affinity"] = affinity
	relation["romance"] = romance
	relation["interactions"] = interaction_count
	relation["stage"] = stage
	relation["last_topic"] = topic
	relation["topic_counts"] = topics
	_relationships[key] = relation
	if stage == "partner" and previous_stage != "partner":
		_record_family_union(first_id, second_id, float(relation.get("union_started_clock", _world_clock_hours)))
	if previous_stage != "" and previous_stage != stage:
		_log_debug("RELAÇÃO", "%s e %s: %s → %s (afinidade %.0f, familiaridade %.0f)." % [_person_first_name(first), _person_first_name(second), previous_stage, stage, affinity, familiarity], str(first.city_id))
	# A relação fica atualizada na memória; checkpoint e _exit_tree salvam o
	# grafo social sem causar engasgos a cada conversa ambiente.


func _relationship_stage(familiarity: float, affinity: float) -> String:
	if familiarity < 15.0:
		return "stranger"
	if familiarity >= 65.0 and affinity >= 55.0:
		return "close_friend"
	if familiarity >= 38.0 and affinity >= 32.0:
		return "friend"
	return "acquaintance"


func _compatibility_gain(first, second, topic: String) -> float:
	var gain := 4.0
	if str(first.get("personal_interest")) == str(second.get("personal_interest")):
		gain += 2.2
	if _are_household_members(first, second):
		gain += 0.8
	if _are_coworkers(first, second) and topic == "trabalho":
		gain += 1.0
	if topic == "notícias" and (str(first.personality) == "fofoqueiro" or str(second.personality) == "fofoqueiro"):
		gain += 0.8
	if topic == "história" and (str(first.personality) == "curioso" or str(second.personality) == "curioso"):
		gain += 0.8
	if str(first.personality) == "desconfiado" and str(second.personality) == "desconfiado":
		gain -= 0.8
	return maxf(1.0, gain)


func _romance_eligible(first, second) -> bool:
	if str(first.get("age_stage")) != "adult" or str(second.get("age_stage")) != "adult":
		return false
	if str(first.get("gender")) == str(second.get("gender")):
		return false
	if str(first.get("role")) == "bruxa" or str(second.get("role")) == "bruxa":
		return false
	if _are_close_relatives(str(first.get("npc_id")), str(second.get("npc_id"))):
		return false
	return true


func _ancestor_distances(npc_id: String, max_depth: int = 2) -> Dictionary:
	var distances: Dictionary = {}
	var frontier: Array[Dictionary] = [{"id": npc_id, "depth": 0}]
	while not frontier.is_empty():
		var current: Dictionary = frontier.pop_front()
		var current_id := str(current.get("id", ""))
		var current_depth := int(current.get("depth", 0))
		if current_id == "" or current_depth >= max_depth:
			continue
		var record: Dictionary = _genealogy.get(current_id, {})
		for parent_id_value in [str(record.get("mother_id", "")), str(record.get("father_id", ""))]:
			var parent_id := str(parent_id_value)
			if parent_id == "":
				continue
			var parent_depth := current_depth + 1
			if not distances.has(parent_id) or parent_depth < int(distances[parent_id]):
				distances[parent_id] = parent_depth
				frontier.append({"id": parent_id, "depth": parent_depth})
	return distances


func _are_close_relatives(first_id: String, second_id: String) -> bool:
	if first_id == "" or second_id == "" or first_id == second_id:
		return true
	var first_ancestors := _ancestor_distances(first_id, 2)
	var second_ancestors := _ancestor_distances(second_id, 2)
	if first_ancestors.has(second_id) or second_ancestors.has(first_id):
		return true
	for ancestor_id in first_ancestors.keys():
		if second_ancestors.has(ancestor_id):
			return true
	return false


func _npc_has_partner(npc_id: String) -> bool:
	return get_partner_id(npc_id) != ""


func _set_partner_profile_field(npc_id: String, partner_id: String) -> void:
	if _active_records.has(npc_id):
		var record: Dictionary = _active_records[npc_id]
		record["partner_id"] = partner_id
		_active_records[npc_id] = record
	if _previous_records.has(npc_id):
		var previous: Dictionary = _previous_records[npc_id]
		previous["partner_id"] = partner_id
		_previous_records[npc_id] = previous
	for npc in _current_npc_nodes:
		if is_instance_valid(npc) and str(npc.get("npc_id")) == npc_id:
			npc.set("partner_id", partner_id)


func get_debug_snapshot(player_position: Vector3 = Vector3.ZERO) -> Dictionary:
	var target_city_id := find_nearest_city(player_position)
	var target_city: Dictionary = cities.get(target_city_id, {})
	var activity_counts: Dictionary = {}
	var relationship_counts := {"stranger": 0, "acquaintance": 0, "friend": 0, "close_friend": 0, "partner": 0}
	var nearby_npcs: Array[Dictionary] = []
	var total_known_events := 0
	var active_count := 0
	var visible_count := 0
	var home_count := 0
	var work_count := 0
	var conversation_count := 0
	var messenger_count := 0
	var resident_count := 0
	for npc in _current_npc_nodes:
		if not is_instance_valid(npc):
			continue
		resident_count += 1
		var activity := str(npc.get("target_kind"))
		activity_counts[activity] = int(activity_counts.get(activity, 0)) + 1
		if bool(npc.get("life_enabled")):
			active_count += 1
		if bool(npc.get("visible")):
			visible_count += 1
		if bool(npc.get("is_at_home")):
			home_count += 1
		if bool(npc.get("is_at_work")):
			work_count += 1
		if bool(npc.get("ambient_conversation_locked")):
			conversation_count += 1
		if str(npc.get("role")) == "mensageiro":
			messenger_count += 1
		var memories: Array = npc.get("known_world_events")
		total_known_events += memories.size()
		var distance := _horizontal_distance(npc.global_position, player_position)
		if distance <= 75.0:
			var state := "parado"
			if bool(npc.get("ambient_conversation_locked")):
				state = "conversando"
			elif bool(npc.get("is_at_home")):
				state = "em casa"
			elif bool(npc.get("is_at_work")):
				state = "trabalhando"
			elif bool(npc.get("has_target")):
				state = "a caminho: %s" % activity
			elif not bool(npc.get("life_enabled")):
				state = "simulação distante"
			var memory_summaries: Array[String] = []
			for memory_value in memories.slice(0, 3):
				if memory_value is Dictionary:
					var memory_kind := str(memory_value.get("kind", "acontecimento")).replace("_", " ")
					var memory_detail := str(memory_value.get("detail", ""))
					memory_summaries.append("%s: %s" % [memory_kind, memory_detail])
			nearby_npcs.append({
				"name": _person_first_name(npc),
				"display_name": str(npc.get("display_name")),
				"role": str(npc.get("role")),
				"city": str(npc.get("city_name")),
				"state": state,
				"distance": distance,
				"memories": memories.size(),
				"memory_summaries": memory_summaries,
				"target": activity
			})
	nearby_npcs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	if nearby_npcs.size() > 12:
		nearby_npcs.resize(12)
	for relation_value in _relationships.values():
		if not (relation_value is Dictionary):
			continue
		var stage := str(relation_value.get("stage", "stranger"))
		relationship_counts[stage] = int(relationship_counts.get(stage, 0)) + 1
	var sessions: Array[Dictionary] = []
	for session in _conversation_sessions:
		var participants: Array = session.get("participants", [])
		var lines: Array = session.get("lines", [])
		var speakers: Array = session.get("speakers", [])
		var turn := int(session.get("turn", 0))
		var names: Array[String] = []
		for participant in participants:
			if is_instance_valid(participant):
				names.append(_person_first_name(participant))
		var current_line := ""
		var current_speaker := ""
		if turn >= 0 and turn < lines.size():
			current_line = str(lines[turn])
		if turn >= 0 and turn < speakers.size() and is_instance_valid(speakers[turn]):
			current_speaker = _person_first_name(speakers[turn])
		sessions.append({"participants": names, "topic": str(session.get("topic", "cotidiano")), "speaker": current_speaker, "line": current_line, "turn": turn + 1, "total_turns": lines.size()})
	var city_name := str(target_city.get("name", "fora das cidades"))
	return {
		"clock_hour": _debug_hour,
		"city_name": city_name,
		"city_id": target_city_id,
		"city_count": cities.size(),
		"npc_count": resident_count,
		"active_count": active_count,
		"visible_count": visible_count,
		"home_count": home_count,
		"work_count": work_count,
		"conversation_count": conversation_count,
		"messenger_count": messenger_count,
		"known_event_count": total_known_events,
		"relationship_count": _relationships.size(),
		"relationship_counts": relationship_counts,
		"genealogy": get_genealogy_statistics(),
		"activity_counts": activity_counts,
		"sessions": sessions,
		"nearby_npcs": nearby_npcs,
		"recent_log": _debug_log.duplicate(),
		"news_transport_active": false
	}


func _log_debug(category: String, message: String, city_id: String = "") -> void:
	var hour := posmod(int(floor(_debug_hour)), 24)
	var minute := int(floor((_debug_hour - floor(_debug_hour)) * 60.0))
	var city_name := str(cities.get(city_id, {}).get("name", "")) if city_id != "" else ""
	var entry := "[%02d:%02d] [%s]%s %s" % [hour, minute, category, " [" + city_name + "]" if city_name != "" else "", message]
	_debug_log.append(entry)
	while _debug_log.size() > 60:
		_debug_log.pop_front()


func _load_persistent_records() -> void:
	_previous_records.clear()
	_relationships.clear()
	_genealogy.clear()
	_world_flags.clear()
	_messenger_next_departure_clock.clear()
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_world_clock_hours = maxf(0.0, float(parsed.get("world_clock_hours", 0.0)))
		var entries: Variant = parsed.get("npcs", {})
		if entries is Dictionary:
			_previous_records = entries.duplicate(true)
		var saved_relationships: Variant = parsed.get("relationships", {})
		if saved_relationships is Dictionary:
			_relationships = saved_relationships.duplicate(true)
		var saved_genealogy: Variant = parsed.get("genealogy", {})
		if saved_genealogy is Dictionary:
			_genealogy = saved_genealogy.duplicate(true)
		var saved_departures: Variant = parsed.get("merchant_next_departure_clock", {})
		if saved_departures is Dictionary:
			_merchant_next_departure_clock = saved_departures.duplicate(true)
		var saved_messenger_departures: Variant = parsed.get("messenger_next_departure_clock", {})
		if saved_messenger_departures is Dictionary:
			_messenger_next_departure_clock = saved_messenger_departures.duplicate(true)
		var saved_flags: Variant = parsed.get("world_flags", {})
		if saved_flags is Dictionary:
			_world_flags = saved_flags.duplicate(true)


func _capture_live_npc_state() -> void:
	# Checkpoint leve para que identidade, relações e estado da rotina atravessem
	# o encerramento/recriação da cena. Guardamos arrays numéricos, não Vector3,
	# porque o JSON de salvamento não serializa tipos da engine.
	# Durante _exit_tree(), uma referência ainda pode ser válida, mas já estar fora
	# da árvore. Preservamos a posição salva nesses casos e evitamos global_transform.
	var saved_at := int(Time.get_unix_time_from_system())
	for npc in _current_npc_nodes:
		if not is_instance_valid(npc):
			continue
		var npc_id := str(npc.get("npc_id"))
		if npc_id == "" or not _active_records.has(npc_id):
			continue
		var record: Dictionary = _active_records[npc_id]
		var has_live_transform: bool = npc.is_inside_tree()
		var previous_life_value: Variant = record.get("life_state", {})
		var previous_life: Dictionary = previous_life_value.duplicate(true) if previous_life_value is Dictionary else {}
		var position := Vector3.ZERO
		var mode := str(previous_life.get("mode", "public")) if not has_live_transform else "public"
		if has_live_transform:
			position = npc.global_position
		else:
			var previous_position: Variant = previous_life.get("position", [])
			if previous_position is Array and previous_position.size() >= 3:
				position = Vector3(float(previous_position[0]), float(previous_position[1]), float(previous_position[2]))
			else:
				var fallback_home: Variant = npc.get("home_position")
				if fallback_home is Vector3:
					position = fallback_home
				else:
					position = npc.position
		if has_live_transform and bool(npc.get("is_at_home")):
			# Mantém a coordenada real em que o NPC foi salvo, não o ponto-base
			# da casa: ele pode estar no quintal, na porta ou caminhando perto dela.
			mode = "home"
		elif has_live_transform and bool(npc.get("is_at_work")):
			# Da mesma forma, não substituímos a posição atual pela posição abstrata
			# do trabalho. A rotina poderá continuar a partir do estado salvo.
			mode = "work"
		elif has_live_transform and bool(npc.get("is_interior_present")):
			var visit_value: Variant = npc.get("_tavern_visit_state")
			if visit_value is Dictionary and visit_value.has("position"):
				var visit_position: Variant = visit_value.get("position")
				if visit_position is Vector3:
					position = visit_position
			else:
				# Interiores usam posições temporárias; não gravamos um ponto interno
				# como se fosse coordenada externa do overworld.
				var fallback_home_position: Variant = npc.get("home_position")
				if fallback_home_position is Vector3:
					position = fallback_home_position
				mode = "home"
		if has_live_transform and (bool(npc.get("merchant_trip_active")) or bool(npc.get("messenger_trip_active"))):
			mode = "travel"
		# Se a árvore já foi desmontada, mantém o estado de vida anterior intacto;
		# relações e memórias ainda são copiadas abaixo, mas sem inventar posição nova.
		if has_live_transform or previous_life.is_empty():
			var life_state := {
				"city_id": str(npc.get("city_id")),
				"mode": mode,
				"position": [position.x, position.y, position.z],
				"life_bucket": str(npc.get("life_bucket")),
				"target_kind": str(npc.get("target_kind")),
				"merchant_trip_active": bool(npc.get("merchant_trip_active")),
				"merchant_target_city_id": str(npc.get("merchant_target_city_id")),
				"merchant_target_inn_id": str(npc.get("merchant_target_inn_id")),
				"messenger_trip_active": bool(npc.get("messenger_trip_active")),
				"messenger_trip_stage": str(npc.get("messenger_trip_stage")),
				"messenger_target_city_id": str(npc.get("messenger_target_city_id")),
				"messenger_target_office_id": str(npc.get("messenger_target_office_id")),
				"messenger_origin_office_id": str(npc.get("messenger_origin_office_id")),
				"messenger_arrival_clock": float(npc.get("messenger_arrival_clock")),
				"world_clock_hours": _world_clock_hours,
				"saved_at": saved_at
			}
			record["life_state"] = life_state
		else:
			previous_life["saved_at"] = saved_at
			record["life_state"] = previous_life
		record["city_id"] = str(npc.get("city_id"))
		record["home_id"] = str(npc.get("home_id"))
		record["merchant_type"] = str(npc.get("merchant_type"))
		record["merchant_last_city_id"] = str(npc.get("merchant_last_city_id"))
		record["merchant_trips_completed"] = int(npc.get("merchant_trips_completed"))
		record["messenger_trips_completed"] = int(npc.get("messenger_trips_completed"))
		var carried_news_value: Variant = npc.get("messenger_carried_news")
		if carried_news_value is Array:
			record["messenger_carried_news"] = carried_news_value.duplicate(true)
		var memories_value: Variant = npc.get("known_world_events")
		if memories_value is Array:
			record["known_world_events"] = memories_value.duplicate(true)
		var player_relation_value: Variant = npc.get("player_relationship")
		if player_relation_value is Dictionary:
			record["player_relationship"] = player_relation_value.duplicate(true)
		_active_records[npc_id] = record
		_previous_records[npc_id] = record.duplicate(true)


func _exit_tree() -> void:
	# Guarda a última rotina ao trocar de cena ou fechar o mundo, além do autosave.
	_save_persistent_records()


func _save_persistent_records() -> void:
	_capture_live_npc_state()
	var payload := {
		"version": 8,
		"world_clock_hours": _world_clock_hours,
		"merchant_next_departure_clock": _merchant_next_departure_clock,
		"messenger_next_departure_clock": _messenger_next_departure_clock,
		"world_flags": _world_flags,
		"npcs": _active_records,
		"relationships": _relationships,
		"genealogy": _genealogy
	}
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar os perfis e os relacionamentos dos NPCs.")
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _ground(pos: Vector3) -> Vector3:
	if _world != null and _world.has_method("_ground"):
		return _world.call("_ground", pos)
	return pos

extends Node3D
# Cena principal: gera a cripta inteira (um mapa só, com salas, corredores e relevo),
# a interface, os menus e os itens. Jogador e inimigos são cenas separadas.

const GAME_NAME := "Os Cânticos dos Sete: Brumaférrea"
const PLAYER_SCENE := "res://scenes/player.tscn"
const ENEMY_SCENE := "res://scenes/enemy.tscn"
const OVERWORLD_SCRIPT := "res://scripts/overworld.gd"
const OVERWORLD_SCENE := "res://assets/world/overworld.glb"
const MENU_MOUNTAIN_FOCUS := Vector3(130.2, 101.4, 286.5)
const MENU_CAMERA_ORIGIN := Vector3(148.0, 92.0, 570.0)
const COMPASS_SCRIPT := "res://scripts/compass.gd"
const WORLD_MAP_SCRIPT := "res://scripts/world_map.gd"
const QUEST_JOURNAL_SCRIPT := "res://scripts/quest_journal.gd"
const INVENTORY_SCRIPT := "res://scripts/inventory_screen.gd"
const HOME_STORAGE_SCRIPT := "res://scripts/home_storage.gd"
const HOME_STORAGE_PATH := "user://player_home_storage.json"
const CAMPAIGN_SAVE_PATH := "user://brumaferrea_campaign_save.json"
const NPC_STATE_PATH := "user://npc_society_state.json"
const CAMPAIGN_AUTOSAVE_INTERVAL := 90.0
const DIALOG_SCRIPT := "res://scripts/dialog_box.gd"
const SHOP_SCRIPT := "res://scripts/shop_box.gd"
const QUEST_MANAGER_SCRIPT := preload("res://scripts/procedural_quests.gd")
const GAME_UPDATER_SCRIPT := preload("res://scripts/game_updater.gd")
const RESOURCE_CATALOG := preload("res://scripts/resource_catalog.gd")
const WORLD_NAMES := preload("res://scripts/world_names.gd")
const STATUS_SCRIPT := "res://scripts/hud_status.gd"
const HOTBAR_SCRIPT := "res://scripts/hotbar.gd"
const PAUSE_MENU_SCRIPT := "res://scripts/pause_menu.gd"
const UiFrame := preload("res://scripts/ui_frame.gd")
const MUSIC_PATHS := {
	"menu": "res://assets/sound/music/Main Theme.mp3",
	"morning": "res://assets/sound/music/The Morning.mp3",
	"noon": "res://assets/sound/music/Noon.mp3",
	"nightfall": "res://assets/sound/music/Nightfall.mp3",
	# Variações meteorológicas dos jingles. Os originais são mantidos como fallback.
	"overcast_morning": "res://assets/sound/music/weather_variants/overcast_morning.mp3",
	"overcast_night": "res://assets/sound/music/weather_variants/overcast_night.mp3",
	"rain_morning": "res://assets/sound/music/weather_variants/rain_morning.mp3",
	"rain_night": "res://assets/sound/music/weather_variants/rain_night.mp3",
	"snow_morning": "res://assets/sound/music/weather_variants/snow_morning.mp3",
	"snow_noon": "res://assets/sound/music/weather_variants/snow_noon.mp3",
	"snow_night": "res://assets/sound/music/weather_variants/snow_night.mp3",
	"storm_morning": "res://assets/sound/music/weather_variants/storm_morning.mp3",
	"storm_night": "res://assets/sound/music/weather_variants/storm_night.mp3",
}
const MENU_MUSIC_VOLUME_DB := -9.0
const JINGLE_VOLUME_DB := -6.0
const MORNING_JINGLE_HOUR := 6.0
const NOON_JINGLE_HOUR := 12.0
const NIGHTFALL_JINGLE_HOUR := 18.0
const TOWN_MUSIC_PATHS := [
	"res://assets/music/sound/town/town1.mp3",
	"res://assets/music/sound/town/town2.mp3",
]
const TOWN_MUSIC_VOLUME_DB := -2.0
# Silencia por completo a faixa de cidade enquanto uma vinheta temporal toca.
const TOWN_MUSIC_MUTED_VOLUME_DB := -80.0
const FIRST_TOWN_MUSIC_DELAY_MIN := 75.0
const FIRST_TOWN_MUSIC_DELAY_MAX := 180.0
const NEXT_TOWN_MUSIC_DELAY_MIN := 300.0
const NEXT_TOWN_MUSIC_DELAY_MAX := 540.0
const TRAVEL_MUSIC_PATHS := {
	"day": "res://assets/music/sound/overworld/travelin1.mp3",
	"night": "res://assets/music/sound/overworld/travelinnight.mp3",
}
const TRAVEL_MUSIC_VOLUME_DB := -5.0
const TRAVEL_MUSIC_MUTED_VOLUME_DB := -80.0
const FIRST_TRAVEL_MUSIC_DELAY_MIN := 55.0
const FIRST_TRAVEL_MUSIC_DELAY_MAX := 115.0
const NEXT_TRAVEL_MUSIC_DELAY_MIN := 180.0
const NEXT_TRAVEL_MUSIC_DELAY_MAX := 360.0
const GRID := 60
const CELL := 2.5
const WALL_TOP := 4.5
const WALL_BOTTOM := -3.0
const STEP_H := 1.5
const MAX_CELL_DELTA := 0.42
const ROOM_TARGET := 14

var enemy_types := [
	{"name": "Rato Gigante", "hp": 14, "dmg": 4, "speed": 3.5, "gold": 2, "radius": 0.45, "kind": "rat", "min_ratio": 0.0},
	{"name": "Goblin", "hp": 22, "dmg": 6, "speed": 3.2, "gold": 4, "radius": 0.5, "kind": "goblin", "min_ratio": 0.1},
	{"name": "Morcego", "hp": 10, "dmg": 4, "speed": 4.2, "gold": 2, "radius": 0.35, "kind": "bat", "min_ratio": 0.3, "flying": true, "fly_height": 1.1},
	{"name": "Esqueleto", "hp": 30, "dmg": 8, "speed": 2.5, "gold": 5, "radius": 0.6, "kind": "skel", "min_ratio": 0.2},
	{"name": "Orc", "hp": 50, "dmg": 12, "speed": 2.0, "gold": 10, "radius": 0.75, "kind": "orc", "min_ratio": 0.5},
]
var boss_type := {"name": "Orc Chefe", "hp": 160, "dmg": 16, "speed": 2.2, "gold": 60, "radius": 1.0, "kind": "orc", "boss": true}

var WEAPON_DB := [
	{"id": "fist", "name": "Punhos", "dmg_min": 4, "dmg_max": 7, "reach": 2.2, "arc": 55.0, "cd": 0.34, "model": "fist"},
	{"id": "sword", "name": "Espada Curta", "dmg_min": 8, "dmg_max": 12, "reach": 2.4, "arc": 55.0, "cd": 0.45, "model": "sword"},
	{"id": "dagger", "name": "Adaga", "dmg_min": 4, "dmg_max": 7, "reach": 1.9, "arc": 45.0, "cd": 0.22, "model": "dagger"},
	{"id": "axe", "name": "Machado de Batalha", "dmg_min": 14, "dmg_max": 20, "reach": 2.2, "arc": 70.0, "cd": 0.8, "model": "axe"},
	{"id": "spear", "name": "Lança", "dmg_min": 10, "dmg_max": 14, "reach": 3.2, "arc": 22.0, "cd": 0.6, "model": "spear"}
]
var ARMOR_DB := [
	{"id": "robe", "name": "Roupas de Viajante", "def": 0},
	{"id": "leather", "name": "Armadura de Couro", "def": 2},
	{"id": "mail", "name": "Cota de Malha", "def": 4},
	{"id": "plate", "name": "Armadura de Placas", "def": 7}
]
var SPELL_DB := [
	{"id": "fire", "name": "Bola de Fogo", "cost": 15, "dmg_min": 18, "dmg_max": 26, "range": 14.0, "arc": 5.0, "interval": 0.32, "cast_mode": "repeat", "color": Color(1.0, 0.45, 0.1)},
	{"id": "lightning", "name": "Relâmpago", "cost": 10, "dmg_min": 10, "dmg_max": 14, "range": 18.0, "arc": 3.0, "interval": 0.28, "cast_mode": "repeat", "color": Color(0.5, 0.85, 1.0)},
	{"id": "heal", "name": "Cura Menor", "cost": 20, "heal": 35, "interval": 0.5, "cast_mode": "instant", "color": Color(0.4, 1.0, 0.5)}
]
# Lojas dos NPCs: o que cada um vende e por quanto (mude os preços aqui)
var SHOP_ROLES := {
	"ferreiro": {"title": "Ferreiro", "stock": [
		{"kind": "weapon", "id": "sword", "price": 40},
		{"kind": "weapon", "id": "dagger", "price": 25},
		{"kind": "weapon", "id": "spear", "price": 60},
		{"kind": "weapon", "id": "axe", "price": 80},
		{"kind": "armor", "id": "leather", "price": 35},
		{"kind": "armor", "id": "mail", "price": 90},
		{"kind": "armor", "id": "plate", "price": 200},
	]},
	"curandeira": {"title": "Curandeira", "stock": [
		{"kind": "potion", "price": 10},
		{"kind": "scroll", "id": "heal", "price": 60},
	]},
	"mercador": {"title": "Mercador", "stock": [
		{"kind": "weapon", "id": "sword", "price": 45},
		{"kind": "potion", "price": 12},
		{"kind": "scroll", "id": "lightning", "price": 70},
		{"kind": "scroll", "id": "fire", "price": 90},
	]},
}
var rng := RandomNumberGenerator.new()
var phase := "menu"  # menu, play, pause, dead, won, dialog, shop, map, inventory, quest_log
var kills := 0
var run_seed := 0
var grid := PackedInt32Array()
var heights := PackedFloat32Array()
var rooms: Array = []
var edges: Array = []
var dungeon_root: Node3D = null
var player = null
var overworld = null
var world_environment_node: WorldEnvironment = null
var dungeon_environment: Environment = null
var day_time_hours := 0.0
var _menu_music_player: AudioStreamPlayer = null
var _time_jingle_player: AudioStreamPlayer = null
var _town_song_player: AudioStreamPlayer = null
var _travel_song_player: AudioStreamPlayer = null
var _music_streams: Dictionary = {}
var _town_music_streams: Array[AudioStream] = []
var _travel_music_streams: Dictionary = {}
var _last_observed_world_hour: float = -1.0
# O tempo de cada evento acumula somente enquanto a condição correspondente é válida.
# Reentrar numa cidade ou voltar à estrada não dispara uma trilha imediatamente.
var _town_presence_seconds: float = 0.0
var _town_music_next_at: float = -1.0
var _last_town_music_index: int = -1
var _travel_presence_seconds: float = 0.0
var _travel_music_next_at: float = -1.0
# Estado regional mantido somente em memória durante a sessão, inclusive entre tentativas.
var regional_threat_session_state: Dictionary = {}
# O tempo é regional: cada célula guarda clima, transição e umidade durante a sessão.
var weather_region_session_state: Dictionary = {}
var weather_world_seed: int = 0
# Trilhas de passagem e grama pisoteada preservadas entre tentativas na sessão atual.
var foot_traffic_session_state: Dictionary = {}
var discovered_dungeons_session: Array[String] = []
var moon_phase_index := 4
var moon_phase_noon_count := 0
var player_scene: PackedScene
var enemy_scene: PackedScene
var sprites: Dictionary = {}
var wall_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var ceil_mat: StandardMaterial3D
var pickups: Array = []
var hud_hurt: ColorRect
var hud_msg: Label
var gameplay_hud_root: Control = null
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_btn: Button
var overlay_action: Callable
var overlay_dim: ColorRect
var overlay_center: CenterContainer
var menu_content: Control = null
var menu_camera: Camera3D = null
var menu_landscape_root: Node3D = null
var menu_environment: Environment = null
var menu_elapsed := 0.0
var msg_tween: Tween
var inventory_screen: Control = null
var home_storage_screen: Control = null
var hud_bar: Control
var hotbar = null
var compass = null
var world_map = null
# Marcador definido pelo jogador no mapa aberto (M), também exibido na bússola.
var navigation_marker_active: bool = false
var navigation_marker_position: Vector3 = Vector3.ZERO
var navigation_marker_label: String = ""
var quest_journal: Control = null
var dialog = null
var shop = null
var quest_manager = null
var _talk_npc = null
var hud_zone: Label
var hud_zone_sub: Label
var zone_tween: Tween
var hud_quest_tracker: PanelContainer
var hud_quest_status: Label
var hud_quest_title: Label
var hud_quest_details: Label
var _quest_marker_signature := "__INITIAL_QUEST_MARKER_SYNC__"
var character_name := ""
var character_home_id := ""
var character_home_name := ""
var player_home_building_id := ""
var player_home_building_name := "Casa da cidade natal"
var player_home_storage: Dictionary = {"weapons": [], "armors": [], "potions": 0, "resources": {}}
var _home_storage_records: Dictionary = {}
var _player_home_assignments: Dictionary = {}
var _home_storage_file_loaded := false
var _active_campaign := false
var _new_adventure_pending := false
var _save_initial_when_world_ready := false
var _continue_payload: Dictionary = {}
var _campaign_autosave_timer := 0.0
# Guarda a posição das montarias entre a recriação do overworld e o retorno de criptas.
var _last_horse_state: Array = []
var _pending_horse_restore: Array = []
var _witch_companion: Node3D = null
var _witch_companion_follow_timer := 0.0
var _witch_companion_attack_timer := 1.5
var _witch_companion_heal_timer := 10.0
var _witch_companion_spell_counter := 0
# Postura escolhida pela conversa com a bruxa. A decisão tática é reavaliada
# periodicamente, sem perseguir o jogador cegamente durante um combate.
var _witch_companion_tactic := "adaptive" # adaptive, aggressive, defensive, hold, follow
var _witch_cached_threat: Node3D = null
var overlay_save_btn: Button = null
var pause_layer: CanvasLayer = null
var pause_menu: Control = null
var _continue_menu_button: Button = null
var _game_updater: Node = null
var character_origin := "andarilho"
var character_attributes := {"vigor": 5, "strength": 5, "agility": 5, "arcana": 5}
var _character_creator: Control = null
var _character_creator_layer: CanvasLayer = null
var _character_name_input: LineEdit = null
var _character_home_select: OptionButton = null
var _character_origin_select: OptionButton = null
var _character_origin_description: Label = null
var _character_map_surface: Control = null
var _character_map_viewport: SubViewport = null
var _character_map_world_root: Node3D = null
var _character_map_pin_layer: Control = null
var _character_home_label: Label = null
var _character_city_description: Label = null
var _character_settlements: Array[Dictionary] = []
var _character_homeable_settlement_ids: Dictionary = {}
var _character_home_pin_buttons: Array[Button] = []
var _character_selected_home_index: int = 0
const CHARACTER_MAP_CAMERA_SIZE := 3400.0
func get_settlement_description(settlement_id: String) -> String:
	return WORLD_NAMES.settlement_description(settlement_id)


func _ready() -> void:
	rng.randomize()
	player_scene = load(PLAYER_SCENE)
	enemy_scene = load(ENEMY_SCENE)
	_make_materials()
	_build_environment()
	_build_hud()
	quest_manager = QUEST_MANAGER_SCRIPT.new()
	quest_manager.name = "ProceduralQuests"
	add_child(quest_manager)
	quest_manager.initialize(self)
	_setup_music()
	_show_menu()
	# Verifica atualizações apenas na build exportada para Windows. A verificação
	# fica silenciosa se o endereço do manifesto ainda não foi configurado.
	_game_updater = GAME_UPDATER_SCRIPT.new()
	_game_updater.name = "GameUpdater"
	add_child(_game_updater)
	_game_updater.call_deferred("check_for_update")


func _process(delta: float) -> void:
	if phase == "menu":
		_update_menu_camera(delta)
	_update_music(delta)
	if _active_campaign and phase in ["play", "pause", "dialog", "shop", "map", "inventory", "quest_log", "home_storage"]:
		_campaign_autosave_timer += delta
		if _campaign_autosave_timer >= CAMPAIGN_AUTOSAVE_INTERVAL:
			_campaign_autosave_timer = 0.0
			_save_campaign(false)
	# O menu de pausa fica numa CanvasLayer própria. Se alguma interface secundária
	# o ocultar ou remover acidentalmente, garante que a pausa continue visível.
	if phase == "pause":
		_ensure_pause_menu()
		if is_instance_valid(pause_menu):
			pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
			if not pause_menu.visible:
				pause_menu.call("open")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player == null:
		return
	_update_hud(delta)
	if phase == "play":
		_check_pickups()


func _physics_process(delta: float) -> void:
	# A percepção da bruxa usa consultas físicas de linha de visão; executá-las
	# no ciclo de física evita consultar o espaço 3D durante sua atualização bloqueada.
	if phase == "play" and player != null and is_instance_valid(player):
		_update_witch_companion(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		if _active_campaign and player != null and is_instance_valid(player):
			_save_campaign(true)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _active_campaign:
			_save_campaign(false)
		get_tree().quit()


# ---------- Música de menu e jingles do relógio ----------

func _setup_music() -> void:
	# A música temática só acompanha o menu; as faixas do mundo são eventos pontuais.
	_menu_music_player = AudioStreamPlayer.new()
	_menu_music_player.name = "MenuMusicPlayer"
	_menu_music_player.bus = "Master"
	_menu_music_player.volume_db = MENU_MUSIC_VOLUME_DB
	_menu_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_music_player)

	_time_jingle_player = AudioStreamPlayer.new()
	_time_jingle_player.name = "TimeJinglePlayer"
	_time_jingle_player.bus = "Master"
	_time_jingle_player.volume_db = JINGLE_VOLUME_DB
	_time_jingle_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_time_jingle_player.finished.connect(_on_time_jingle_finished)
	add_child(_time_jingle_player)

	_town_song_player = AudioStreamPlayer.new()
	_town_song_player.name = "TownEventMusicPlayer"
	_town_song_player.bus = "Master"
	_town_song_player.volume_db = TOWN_MUSIC_VOLUME_DB
	_town_song_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_town_song_player)

	_travel_song_player = AudioStreamPlayer.new()
	_travel_song_player.name = "OverworldTravelMusicPlayer"
	_travel_song_player.bus = "Master"
	_travel_song_player.volume_db = TRAVEL_MUSIC_VOLUME_DB
	_travel_song_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_travel_song_player)

	for key in MUSIC_PATHS.keys():
		var stream := load(str(MUSIC_PATHS[key])) as AudioStream
		if stream == null:
			push_warning("Faixa musical não encontrada: %s" % str(MUSIC_PATHS[key]))
			continue
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = str(key) == "menu"
		_music_streams[str(key)] = stream

	for path_value in TOWN_MUSIC_PATHS:
		var town_stream := load(str(path_value)) as AudioStream
		if town_stream == null:
			push_warning("Faixa de cidade não encontrada: %s" % str(path_value))
			continue
		if town_stream is AudioStreamMP3:
			(town_stream as AudioStreamMP3).loop = false
		_town_music_streams.append(town_stream)

	for travel_key in TRAVEL_MUSIC_PATHS.keys():
		var travel_path := str(TRAVEL_MUSIC_PATHS[travel_key])
		var travel_stream := load(travel_path) as AudioStream
		if travel_stream == null:
			push_warning("Faixa de exploração não encontrada: %s" % travel_path)
			continue
		if travel_stream is AudioStreamMP3:
			(travel_stream as AudioStreamMP3).loop = false
		_travel_music_streams[str(travel_key)] = travel_stream

	if _music_streams.has("menu"):
		_menu_music_player.stream = _music_streams["menu"] as AudioStream
		_menu_music_player.play()


func _update_music(delta: float) -> void:
	_update_town_music(delta)
	_update_travel_music(delta)

	# A criação de personagem é uma tela própria e permanece silenciosa até receber
	# sua trilha dedicada. Não deixe o tema do menu ou jingles tocarem por trás dela.
	if phase == "character_creation":
		if _menu_music_player != null and _menu_music_player.playing:
			_menu_music_player.stop()
		if _time_jingle_player != null and _time_jingle_player.playing:
			_time_jingle_player.stop()
		if _town_song_player != null and _town_song_player.playing:
			_town_song_player.stop()
		return

	# O tema principal só toca no menu e não é substituído pelas faixas do mundo.
	if phase == "menu":
		if _time_jingle_player != null and _time_jingle_player.playing:
			_time_jingle_player.stop()
		if _menu_music_player != null and not _menu_music_player.playing and _menu_music_player.stream != null:
			_menu_music_player.play()
		return

	if _menu_music_player != null and _menu_music_player.playing:
		_menu_music_player.stop()

	# Não inicializa o relógio musical até que o overworld tenha sincronizado sua hora.
	if overworld == null or not is_instance_valid(overworld):
		return

	var current_hour := fposmod(float(day_time_hours), 24.0)
	if _last_observed_world_hour < 0.0:
		_last_observed_world_hour = current_hour
		return

	var previous_hour := _last_observed_world_hour
	_last_observed_world_hour = current_hour
	if is_equal_approx(previous_hour, current_hour):
		return

	# Cada jingle é disparado somente quando o relógio cruza o marco correspondente.
	# 06:00 = nascer do sol; 12:00 = meio-dia; 18:00 = pôr do sol/anoitecer.
	if _crossed_world_hour(previous_hour, current_hour, MORNING_JINGLE_HOUR):
		_play_time_jingle(_weather_variant_for_jingle("morning"))
	elif _crossed_world_hour(previous_hour, current_hour, NOON_JINGLE_HOUR):
		_play_time_jingle(_weather_variant_for_jingle("noon"))
	elif _crossed_world_hour(previous_hour, current_hour, NIGHTFALL_JINGLE_HOUR):
		_play_time_jingle(_weather_variant_for_jingle("nightfall"))


func _update_town_music(delta: float) -> void:
	if _town_song_player == null:
		return

	if phase in ["menu", "character_creation", "dead", "won"] or player == null or not is_instance_valid(player) or overworld == null or not is_instance_valid(overworld):
		if _town_song_player.playing:
			_town_song_player.stop()
		_town_song_player.volume_db = TOWN_MUSIC_VOLUME_DB
		return

	var city_zone := ""
	if overworld.has_method("settlement_zone_for_player"):
		city_zone = str(overworld.call("settlement_zone_for_player", player.global_position))
	elif overworld.has_method("safe_zone_at"):
		city_zone = str(overworld.call("safe_zone_at", player.global_position))

	# A zona urbana apenas autoriza um novo disparo e acumula o temporizador.
	# Se a faixa já começou, deixa-a chegar ao fim mesmo que o jogador saia da cidade.
	if city_zone.is_empty():
		return
	if _travel_song_player != null and _travel_song_player.playing:
		return

	# Inventário/mapa/pausa não fazem o relógio de presença avançar; diálogos e lojas
	# contam como permanência na cidade, sem fazer o disparo acontecer na entrada.
	if phase not in ["play", "dialog", "shop"]:
		return

	_town_presence_seconds += maxf(delta, 0.0)
	if _town_music_next_at < 0.0:
		_town_music_next_at = _town_presence_seconds + rng.randf_range(FIRST_TOWN_MUSIC_DELAY_MIN, FIRST_TOWN_MUSIC_DELAY_MAX)
		return

	if _town_presence_seconds < _town_music_next_at:
		return
	if _town_song_player.playing or _town_music_streams.is_empty():
		return
	# Evita disparar a música da cidade por cima de uma vinheta do relógio.
	if _time_jingle_player != null and _time_jingle_player.playing:
		return

	# Sorteia entre as faixas disponíveis, evitando repetir a última quando há opções.
	var available_indices: Array[int] = []
	for candidate_index in range(_town_music_streams.size()):
		if _town_music_streams.size() == 1 or candidate_index != _last_town_music_index:
			available_indices.append(candidate_index)
	if available_indices.is_empty():
		return
	var selected_position := rng.randi_range(0, available_indices.size() - 1)
	var index: int = available_indices[selected_position]
	_last_town_music_index = index
	_town_song_player.stop()
	_town_song_player.stream = _town_music_streams[index]
	_town_song_player.volume_db = TOWN_MUSIC_VOLUME_DB
	_town_song_player.play()
	# O intervalo é medido em segundos acumulados dentro de cidades, não por entrada.
	_town_music_next_at = _town_presence_seconds + rng.randf_range(NEXT_TOWN_MUSIC_DELAY_MIN, NEXT_TOWN_MUSIC_DELAY_MAX)


func _update_travel_music(delta: float) -> void:
	if _travel_song_player == null:
		return

	# Não há trilha de exploração no menu, na criação de personagem, após a morte,
	# nem dentro de criptas. Um tema já iniciado, por outro lado, pode terminar
	# naturalmente durante diálogo ou pausa, como a música de cidade.
	if phase in ["menu", "character_creation", "dead", "won"] or player == null or not is_instance_valid(player) or overworld == null or not is_instance_valid(overworld) or (dungeon_root != null and is_instance_valid(dungeon_root)):
		if _travel_song_player.playing:
			_travel_song_player.stop()
		_travel_song_player.volume_db = TRAVEL_MUSIC_VOLUME_DB
		return

	# Se a faixa começou na estrada, deixa que termine sem sobrepor a música de
	# cidade. Não inicia outra faixa em inventário, mapa ou pausa.
	if _travel_song_player.playing:
		return
	if phase not in ["play", "dialog", "shop"]:
		return

	var city_zone := ""
	if overworld.has_method("settlement_zone_for_player"):
		city_zone = str(overworld.call("settlement_zone_for_player", player.global_position))
	elif overworld.has_method("safe_zone_at"):
		city_zone = str(overworld.call("safe_zone_at", player.global_position))
	if not city_zone.is_empty():
		return

	# Não adianta marcar o próximo evento enquanto outra trilha ou vinheta está
	# tocando: isso evita que a exploração comece imediatamente ao sair da cidade.
	if (_town_song_player != null and _town_song_player.playing) or (_time_jingle_player != null and _time_jingle_player.playing):
		return

	_travel_presence_seconds += maxf(delta, 0.0)
	if _travel_music_next_at < 0.0:
		_travel_music_next_at = _travel_presence_seconds + rng.randf_range(FIRST_TRAVEL_MUSIC_DELAY_MIN, FIRST_TRAVEL_MUSIC_DELAY_MAX)
		return
	if _travel_presence_seconds < _travel_music_next_at:
		return
	if _travel_music_streams.is_empty():
		return

	var current_hour := fposmod(float(day_time_hours), 24.0)
	var travel_key := "day" if current_hour >= 6.0 and current_hour < 18.0 else "night"
	if not _travel_music_streams.has(travel_key):
		return
	_travel_song_player.stop()
	_travel_song_player.stream = _travel_music_streams[travel_key] as AudioStream
	_travel_song_player.volume_db = TRAVEL_MUSIC_VOLUME_DB
	_travel_song_player.play()
	_travel_music_next_at = _travel_presence_seconds + rng.randf_range(NEXT_TRAVEL_MUSIC_DELAY_MIN, NEXT_TRAVEL_MUSIC_DELAY_MAX)


func _on_time_jingle_finished() -> void:
	# As faixas de cidade e exploração voltam ao volume normal depois da vinheta.
	if _town_song_player != null and _town_song_player.playing:
		_town_song_player.volume_db = TOWN_MUSIC_VOLUME_DB
	if _travel_song_player != null and _travel_song_player.playing:
		_travel_song_player.volume_db = TRAVEL_MUSIC_VOLUME_DB


func _crossed_world_hour(previous_hour: float, current_hour: float, target_hour: float) -> bool:
	if current_hour > previous_hour:
		return previous_hour < target_hour and current_hour >= target_hour
	# O relógio passou da meia-noite. Só conta marcos se o intervalo realmente
	# alcançar uma hora-alvo, mesmo quando um frame excepcionalmente grande pula horas.
	if current_hour < previous_hour:
		return target_hour > previous_hour or target_hour <= current_hour
	return false


func _weather_variant_for_jingle(base_key: String) -> String:
	# IDs alinhados ao enum Weather do overworld: 0 limpo, 1 nublado, 2 chuva,
	# 3 tempestade, 4 neve, 5 nevasca. O clima é consultado na posição do jogador
	# no instante em que o marco musical é alcançado, não no início do dia.
	if base_key not in ["morning", "noon", "nightfall"]:
		return base_key
	var weather_id := 0
	if overworld != null and is_instance_valid(overworld):
		if player is Node3D and is_instance_valid(player) and overworld.has_method("get_weather_at_position"):
			weather_id = int(overworld.call("get_weather_at_position", (player as Node3D).global_position))
		else:
			weather_id = int(overworld.get("current_weather"))

	var variant_key := ""
	match weather_id:
		1: # Nublado
			if base_key == "morning":
				variant_key = "overcast_morning"
			elif base_key == "nightfall":
				variant_key = "overcast_night"
		2: # Chuva
			if base_key == "morning":
				variant_key = "rain_morning"
			elif base_key == "nightfall":
				variant_key = "rain_night"
		3: # Tempestade comum
			if base_key == "morning":
				variant_key = "storm_morning"
			elif base_key == "nightfall":
				variant_key = "storm_night"
		4, 5: # Neve e nevasca usam a mesma família de jingles gelados.
			if base_key == "morning":
				variant_key = "snow_morning"
			elif base_key == "noon":
				variant_key = "snow_noon"
			elif base_key == "nightfall":
				variant_key = "snow_night"

	# Não existem, por enquanto, variações de meio-dia para nublado, chuva ou
	# tempestade comum. Nesses casos, mantém o jingle original sem silenciar o marco.
	if variant_key != "" and _music_streams.has(variant_key):
		return variant_key
	return base_key


func _play_time_jingle(key: String) -> void:
	if _time_jingle_player == null or not _music_streams.has(key):
		return
	# As vinhetas não ficam em loop. Se duas mudanças ocorrerem praticamente juntas,
	# a mais recente substitui a anterior em vez de empilhar áudio conflitante.
	_time_jingle_player.stop()
	_time_jingle_player.stream = _music_streams[key] as AudioStream
	_time_jingle_player.volume_db = JINGLE_VOLUME_DB
	if _town_song_player != null and _town_song_player.playing:
		# A vinheta deve ser ouvida sozinha; a faixa urbana continua em silêncio e
		# volta ao volume original quando o jingle termina.
		_town_song_player.volume_db = TOWN_MUSIC_MUTED_VOLUME_DB
	if _travel_song_player != null and _travel_song_player.playing:
		_travel_song_player.volume_db = TRAVEL_MUSIC_MUTED_VOLUME_DB
	_time_jingle_player.play()


# ---------- Menus e fluxo ----------

func start_run() -> void:
	_dispose_menu_landscape()
	run_seed = rng.randi() if run_seed == 0 or _new_adventure_pending else run_seed
	if _continue_payload.is_empty() and not _new_adventure_pending:
		kills = 0
	var created_player := player == null
	if created_player:
		player = player_scene.instantiate()
		player.set("game", self)
		add_child(player)
		player.reset_stats()
	elif _new_adventure_pending:
		player.set("game", self)
		player.reset_stats()
	else:
		# Recomeçar depois da morte/vitória restaura vida e mana, mas mantém o progresso.
		player.set("game", self)
		player.prepare_for_new_attempt()

	if created_player or _new_adventure_pending:
		# Uma campanha nova começa com a ficha da classe escolhida, sem equipamento
		# ou atributos que tenham sobrado de uma campanha anterior.
		player.attributes = {
			"vigor": int(character_attributes.get("vigor", 5)),
			"strength": int(character_attributes.get("strength", 5)),
			"agility": int(character_attributes.get("agility", 5)),
			"arcana": int(character_attributes.get("arcana", 5))
		}
		player.call("_recalculate_derived_stats")
		player.hp = player.max_hp
		player.mana = player.max_mana

	if player != null:
		player.set_meta("character_name", character_name if character_name != "" else "Aventureiro")
		player.set_meta("home_settlement_id", character_home_id)
		player.set_meta("home_settlement_name", character_home_name)
		player.set_meta("character_origin", character_origin)
		player.set_meta("character_attributes", character_attributes.duplicate(true))
	if dungeon_root:
		dungeon_root.free()
		dungeon_root = null
	pickups.clear()
	_resume()
	_open_overworld()


func toggle_pause() -> void:
	if phase == "inventory":
		_resume()
	elif phase == "home_storage":
		close_home_storage()
	elif phase == "play":
		phase = "pause"
		overlay.visible = false
		_ensure_pause_menu()
		if is_instance_valid(pause_menu):
			pause_menu.call("open")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif phase == "pause":
		_resume()


func toggle_inventory() -> void:
	if phase == "play":
		phase = "inventory"
		overlay.visible = false
		if inventory_screen != null:
			inventory_screen.call("open")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif phase == "inventory":
		_resume()


func on_player_died() -> void:
	phase = "dead"
	_show_overlay("Você morreu", "%d inimigos derrotados · %d ouro" % [kills, player.gold], "Tentar de novo", start_run)


func on_enemy_killed(enemy, player_credited: bool = true) -> void:
	var from_overworld: bool = enemy.is_in_group("overworld_enemies")
	var is_city_occupation_actor: bool = enemy.has_meta("city_occupation_actor") and bool(enemy.get_meta("city_occupation_actor", false))
	var death_position: Vector3 = enemy.global_position
	# Mesmo quando um guarda ou morador derrota a criatura, o mundo registra a
	# redução da ameaça e o progresso do cerco. Só o jogador recebe XP, ouro e avisos.
	if from_overworld and overworld != null and is_instance_valid(overworld):
		if overworld.has_method("report_enemy_killed"):
			overworld.report_enemy_killed(death_position, str(enemy.kind))
		if is_city_occupation_actor and overworld.has_method("report_city_invader_killed"):
			overworld.report_city_invader_killed(str(enemy.get_meta("city_id", "")))
	if not player_credited:
		return
	kills += 1
	player.add_gold(enemy.gold_drop)
	var xp_reward := _experience_reward(enemy)
	var level_message: String = player.gain_experience(xp_reward)
	if enemy.is_boss:
		_on_won(xp_reward, level_message)
		return
	var notices: Array[String] = ["%s derrotado! +%d ouro · +%d XP" % [enemy.display_name, enemy.gold_drop, xp_reward]]
	if level_message != "":
		notices.append(level_message)
	if not is_city_occupation_actor and quest_manager != null and quest_manager.has_method("register_kill"):
		var enemy_quest_id: String = str(enemy.get_meta("quest_id", "")) if enemy is Node else ""
		var quest_update: String = quest_manager.register_kill(str(enemy.kind), from_overworld, death_position, enemy_quest_id)
		if quest_update != "":
			notices.append(quest_update)
	var notice_text := ""
	for notice in notices:
		if notice_text != "":
			notice_text += "\n"
		notice_text += notice
	show_msg(notice_text)

func _experience_reward(enemy) -> int:
	if enemy.is_boss:
		return 150
	match str(enemy.kind):
		"rat": return 8
		"bat": return 9
		"goblin": return 14
		"skel": return 16
		"orc": return 24
	return 10


func flash_hurt() -> void:
	hud_hurt.color = Color(0.8, 0.05, 0.05, 0.45)
	create_tween().tween_property(hud_hurt, "color:a", 0.0, 0.45)


func show_msg(text: String) -> void:
	# Mensagens de sistema ficam discretas perto do HUD, sem ocupar o centro da visão.
	hud_msg.text = text
	hud_msg.modulate = Color(1.0, 1.0, 1.0, 0.88)
	if msg_tween:
		msg_tween.kill()
	msg_tween = create_tween()
	msg_tween.tween_interval(1.6)
	msg_tween.tween_property(hud_msg, "modulate:a", 0.0, 0.5)


func show_zone_title(title: String, subtitle: String = "") -> void:
	# Nome do lugar no alto da tela: surge, fica uns segundos e some
	hud_zone.text = title
	hud_zone_sub.text = subtitle.to_upper()
	hud_zone.modulate.a = 0.0
	hud_zone_sub.modulate.a = 0.0
	if zone_tween:
		zone_tween.kill()
	zone_tween = create_tween()
	zone_tween.tween_property(hud_zone, "modulate:a", 1.0, 0.7)
	zone_tween.parallel().tween_property(hud_zone_sub, "modulate:a", 1.0, 0.7)
	zone_tween.tween_interval(2.4)
	zone_tween.tween_property(hud_zone, "modulate:a", 0.0, 1.2)
	zone_tween.parallel().tween_property(hud_zone_sub, "modulate:a", 0.0, 1.2)


func _show_menu() -> void:
	phase = "menu"
	# O menu principal é uma interface separada; nenhum elemento do HUD da
	# campanha deve permanecer visível por trás dele.
	if is_instance_valid(gameplay_hud_root):
		gameplay_hud_root.visible = false
	if _town_song_player != null:
		_town_song_player.stop()
	if _travel_song_player != null:
		_travel_song_player.stop()
	if _time_jingle_player != null:
		_time_jingle_player.stop()
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	_ensure_menu_landscape()
	overlay.visible = true
	overlay_dim.color = Color(0.015, 0.015, 0.018, 0.14)
	overlay_center.visible = false
	menu_content.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_menu_button = menu_content.get_node_or_null("MenuColumn/MenuStack/Actions/ContinueJourney") as Button
	if _continue_menu_button != null:
		_continue_menu_button.disabled = not _has_valid_campaign_save()
	var first_button: Button = null
	if _continue_menu_button != null and not _continue_menu_button.disabled:
		first_button = _continue_menu_button
	else:
		first_button = menu_content.get_node_or_null("MenuColumn/MenuStack/Actions/NewJourney") as Button
	if first_button != null:
		first_button.grab_focus()


func _ensure_menu_landscape() -> void:
	if is_instance_valid(menu_landscape_root):
		return
	var packed_world := load(OVERWORLD_SCENE) as PackedScene
	if packed_world == null:
		push_warning("Não foi possível carregar a paisagem de Brumaférrea para o menu.")
		return

	menu_landscape_root = Node3D.new()
	menu_landscape_root.name = "BrumaferreaMenuLandscape"
	add_child(menu_landscape_root)
	var landscape := packed_world.instantiate() as Node3D
	if landscape != null:
		landscape.name = "ExistingOverworldLandscape"
		menu_landscape_root.add_child(landscape)

	# Luz separada da simulação do mundo: a cena do menu usa somente a paisagem estática.
	var sun := DirectionalLight3D.new()
	sun.name = "MenuSunlight"
	sun.rotation_degrees = Vector3(-32.0, -24.0, 0.0)
	sun.light_color = Color(0.88, 0.84, 0.75)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	menu_landscape_root.add_child(sun)

	menu_environment = Environment.new()
	menu_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.17, 0.21, 0.25)
	sky_material.sky_horizon_color = Color(0.58, 0.57, 0.52)
	sky_material.ground_bottom_color = Color(0.08, 0.085, 0.08)
	sky_material.ground_horizon_color = Color(0.34, 0.34, 0.31)
	sky.sky_material = sky_material
	menu_environment.sky = sky
	menu_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	menu_environment.ambient_light_color = Color(0.58, 0.59, 0.56)
	menu_environment.ambient_light_energy = 0.72
	menu_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	menu_environment.fog_enabled = true
	menu_environment.fog_mode = Environment.FOG_MODE_DEPTH
	menu_environment.fog_light_color = Color(0.48, 0.51, 0.51)
	menu_environment.fog_depth_begin = 75.0
	menu_environment.fog_depth_end = 850.0

	menu_camera = Camera3D.new()
	menu_camera.name = "MountainTitleCamera"
	menu_camera.position = MENU_CAMERA_ORIGIN
	menu_camera.fov = 42.0
	menu_camera.near = 0.1
	menu_camera.far = 3500.0
	menu_camera.environment = menu_environment
	menu_landscape_root.add_child(menu_camera)
	menu_camera.look_at(MENU_MOUNTAIN_FOCUS, Vector3.UP)
	menu_camera.make_current()
	menu_elapsed = 0.0


func _update_menu_camera(delta: float) -> void:
	if not is_instance_valid(menu_camera):
		return
	menu_elapsed += delta
	# Deslocamento cinematográfico mínimo: a montanha permanece como foco, sem uma câmera parada.
	menu_camera.position = MENU_CAMERA_ORIGIN + Vector3(
		sin(menu_elapsed * 0.055) * 7.0,
		sin(menu_elapsed * 0.032) * 1.5,
		cos(menu_elapsed * 0.043) * 4.0
	)
	menu_camera.look_at(MENU_MOUNTAIN_FOCUS, Vector3.UP)


func _dispose_menu_landscape() -> void:
	if is_instance_valid(menu_landscape_root):
		menu_landscape_root.free()
	menu_landscape_root = null
	menu_camera = null
	menu_environment = null


func _on_main_menu_start() -> void:
	_show_character_creator()


func _on_continue_campaign() -> void:
	var saved := _read_json_dictionary(CAMPAIGN_SAVE_PATH)
	if saved.is_empty() or not saved.has("player"):
		_show_menu()
		return
	_continue_payload = saved
	_active_campaign = true
	_new_adventure_pending = false
	_save_initial_when_world_ready = false
	character_name = str(saved.get("character_name", "Aventureiro"))
	character_home_id = str(saved.get("character_home_id", ""))
	character_home_name = str(saved.get("character_home_name", "Brumaférrea"))
	# Migra o nome antigo salvo (em inglês) sem alterar o ID da cidade natal.
	if character_home_id != "":
		character_home_name = WORLD_NAMES.settlement_name(character_home_id)
	character_origin = str(saved.get("character_origin", "andarilho"))
	var attrs_value: Variant = saved.get("character_attributes", {"vigor": 5, "strength": 5, "agility": 5, "arcana": 5})
	character_attributes = attrs_value.duplicate(true) if attrs_value is Dictionary else {"vigor": 5, "strength": 5, "agility": 5, "arcana": 5}
	player_home_building_id = str(saved.get("player_home_building_id", ""))
	player_home_building_name = str(saved.get("player_home_building_name", "Casa da cidade natal"))
	day_time_hours = fposmod(float(saved.get("day_time_hours", 0.0)), 24.0)
	run_seed = int(saved.get("run_seed", 0))
	kills = int(saved.get("kills", 0))
	moon_phase_index = int(saved.get("moon_phase_index", 4))
	moon_phase_noon_count = int(saved.get("moon_phase_noon_count", 0))
	var saved_witch_tactic := str(saved.get("witch_companion_tactic", "adaptive"))
	_witch_companion_tactic = saved_witch_tactic if saved_witch_tactic in ["adaptive", "aggressive", "defensive", "hold", "follow"] else "adaptive"
	var session_value: Variant = _decode_save_value(saved.get("session_state", {}))
	var session: Dictionary = session_value if session_value is Dictionary else {}
	regional_threat_session_state = session.get("regional_threats", {}) if session.get("regional_threats", {}) is Dictionary else {}
	weather_region_session_state = session.get("weather_regions", {}) if session.get("weather_regions", {}) is Dictionary else {}
	weather_world_seed = int(session.get("weather_world_seed", 0))
	foot_traffic_session_state = session.get("foot_traffic", {}) if session.get("foot_traffic", {}) is Dictionary else {}
	discovered_dungeons_session.clear()
	var discovered_value: Variant = session.get("discovered_dungeons", [])
	if discovered_value is Array:
		for dungeon_id in discovered_value:
			discovered_dungeons_session.append(str(dungeon_id))
	# O snapshot da sociedade e o baú são reconstituídos antes de criar o overworld.
	# Assim os NPCs carregam suas memórias e relações da mesma campanha, não de outra.
	_restore_json_snapshot(NPC_STATE_PATH, saved.get("npc_society_snapshot", {}))
	_restore_json_snapshot(HOME_STORAGE_PATH, saved.get("home_storage_snapshot", {}))
	_home_storage_file_loaded = false
	_home_storage_records.clear()
	_player_home_assignments.clear()
	var restored_home_file := _read_json_dictionary(HOME_STORAGE_PATH)
	if not restored_home_file.is_empty():
		var houses_value: Variant = restored_home_file.get("houses", {})
		var assignments_value: Variant = restored_home_file.get("home_assignments", {})
		if houses_value is Dictionary:
			_home_storage_records = houses_value.duplicate(true)
		if assignments_value is Dictionary:
			_player_home_assignments = assignments_value.duplicate(true)
		_home_storage_file_loaded = true
	_dispose_menu_landscape()
	if is_instance_valid(_character_creator_layer):
		_character_creator_layer.queue_free()
	_character_creator_layer = null
	_character_creator = null
	start_run()


func _begin_new_adventure() -> void:
	# Começar outra jornada apaga o slot anterior e os arquivos auxiliares globais.
	# O estado será criado novamente pelo mundo recém-gerado.
	_active_campaign = true
	_new_adventure_pending = true
	_save_initial_when_world_ready = true
	_continue_payload.clear()
	_campaign_autosave_timer = 0.0
	_last_horse_state.clear()
	_pending_horse_restore.clear()
	_witch_companion = null
	_witch_companion_tactic = "adaptive"
	_witch_cached_threat = null
	for path in [CAMPAIGN_SAVE_PATH, NPC_STATE_PATH, HOME_STORAGE_PATH]:
		if FileAccess.file_exists(str(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
	_home_storage_records.clear()
	_player_home_assignments.clear()
	_home_storage_file_loaded = false
	player_home_storage = {"weapons": [], "armors": [], "potions": 0, "resources": {}}
	player_home_building_id = ""
	player_home_building_name = "Casa da cidade natal"
	regional_threat_session_state.clear()
	weather_region_session_state.clear()
	weather_world_seed = 0
	foot_traffic_session_state.clear()
	discovered_dungeons_session.clear()
	day_time_hours = 0.0
	moon_phase_index = 4
	moon_phase_noon_count = 0
	kills = 0
	run_seed = 0
	_last_observed_world_hour = -1.0
	_town_presence_seconds = 0.0
	_town_music_next_at = -1.0
	_last_town_music_index = -1
	_travel_presence_seconds = 0.0
	_travel_music_next_at = -1.0
	navigation_marker_active = false
	navigation_marker_position = Vector3.ZERO
	navigation_marker_label = ""
	_quest_marker_signature = "__INITIAL_QUEST_MARKER_SYNC__"
	if quest_manager != null and is_instance_valid(quest_manager):
		quest_manager.set("quests_by_id", {})
		quest_manager.set("offer_by_npc", {})
		quest_manager.set("offer_generation_by_npc", {})
		quest_manager.set("tracked_quest_id", "")


func _has_valid_campaign_save() -> bool:
	var saved := _read_json_dictionary(CAMPAIGN_SAVE_PATH)
	return not saved.is_empty() and saved.has("player") and saved.has("character_name")


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _restore_json_snapshot(path: String, snapshot_value: Variant) -> void:
	if not (snapshot_value is Dictionary) or snapshot_value.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível restaurar o arquivo da campanha: %s" % path)
		return
	file.store_string(JSON.stringify(snapshot_value, "\t"))


func _encode_save_value(value: Variant) -> Variant:
	if value is Vector3:
		return {"__brumaferrea_type": "Vector3", "v": [value.x, value.y, value.z]}
	if value is Vector2:
		return {"__brumaferrea_type": "Vector2", "v": [value.x, value.y]}
	if value is Color:
		return {"__brumaferrea_type": "Color", "v": [value.r, value.g, value.b, value.a]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value.keys():
			result[str(key)] = _encode_save_value(value[key])
		return result
	if value is Array:
		var result_array: Array = []
		for item in value:
			result_array.append(_encode_save_value(item))
		return result_array
	if value is PackedStringArray or value is PackedInt32Array or value is PackedFloat32Array:
		return Array(value)
	return value


func _decode_save_value(value: Variant) -> Variant:
	if value is Dictionary:
		var kind := str(value.get("__brumaferrea_type", ""))
		var raw: Variant = value.get("v", [])
		if raw is Array:
			match kind:
				"Vector3":
					if raw.size() >= 3: return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
				"Vector2":
					if raw.size() >= 2: return Vector2(float(raw[0]), float(raw[1]))
				"Color":
					if raw.size() >= 4: return Color(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
		var result: Dictionary = {}
		for key in value.keys():
			result[str(key)] = _decode_save_value(value[key])
		return result
	if value is Array:
		var result_array: Array = []
		for item in value:
			result_array.append(_decode_save_value(item))
		return result_array
	return value


func _save_campaign(show_feedback: bool = false) -> bool:
	if not _active_campaign or player == null or not is_instance_valid(player):
		return false
	if overworld != null and is_instance_valid(overworld):
		var society: Variant = overworld.get("_npc_society")
		if society != null and is_instance_valid(society) and society.has_method("save_world_state"):
			society.call("save_world_state")
	if player_home_building_id != "":
		save_player_home_storage()

	var save_position: Vector3 = player.global_position
	if overworld != null and is_instance_valid(overworld) and bool(overworld.get("_inside_building")):
		var return_position: Variant = overworld.get("_interior_return_position")
		if return_position is Vector3:
			save_position = return_position
	var player_state := {
		"level": int(player.level),
		"experience": int(player.experience),
		"attribute_points": int(player.attribute_points),
		"attributes": player.attributes.duplicate(true),
		"proficiencies": player.proficiencies.duplicate(true),
		"hp": float(player.hp),
		"mana": float(player.mana),
		"gold": int(player.gold),
		"potions": int(player.potions),
		"resources": player.resources.duplicate(true),
		"weapons": _encode_save_value(player.weapons),
		"weapon_idx": int(player.weapon_idx),
		"armors": _encode_save_value(player.armors),
		"armor_idx": int(player.armor_idx),
		"spells": _encode_save_value(player.spells),
		"spell_idx": int(player.spell_idx),
		"active_equipment_type": str(player.active_equipment_type),
		"consumable_slots": _encode_save_value(player.consumable_slots),
		"position": [save_position.x, save_position.y, save_position.z],
		"rotation_y": float(player.rotation.y),
		"camera_pitch": float(player.cam.rotation.x) if player.cam != null else 0.0
	}
	var quest_state := {}
	if quest_manager != null and is_instance_valid(quest_manager):
		quest_state = {
			"quests_by_id": _encode_save_value(quest_manager.get("quests_by_id")),
			"offer_by_npc": _encode_save_value(quest_manager.get("offer_by_npc")),
			"offer_generation_by_npc": _encode_save_value(quest_manager.get("offer_generation_by_npc")),
			"tracked_quest_id": str(quest_manager.get("tracked_quest_id"))
		}
	var session_state := {
		"regional_threats": regional_threat_session_state,
		"weather_regions": weather_region_session_state,
		"weather_world_seed": weather_world_seed,
		"foot_traffic": foot_traffic_session_state,
		"discovered_dungeons": discovered_dungeons_session
	}
	var horse_state_to_save: Array = []
	if overworld != null and is_instance_valid(overworld) and overworld.has_method("get_horse_save_state"):
		var horses_value: Variant = overworld.call("get_horse_save_state")
		if horses_value is Array:
			horse_state_to_save = horses_value.duplicate(true)
			_last_horse_state = horse_state_to_save.duplicate(true)
	else:
		horse_state_to_save = _last_horse_state.duplicate(true)
	var witch_state_to_save: Dictionary = {}
	var witch_to_save: Node3D = _find_unique_witch_node()
	if is_instance_valid(witch_to_save):
		var witch_position: Vector3 = witch_to_save.global_position
		witch_state_to_save = {
			"id": str(witch_to_save.get("npc_id")),
			"state": str(witch_to_save.get("witch_state")),
			"position": [witch_position.x, witch_position.y, witch_position.z],
			"rotation_y": float(witch_to_save.rotation.y)
		}
	var payload := {
		"format_version": 1,
		"saved_at": Time.get_datetime_string_from_system(true),
		"character_name": character_name,
		"character_home_id": character_home_id,
		"character_home_name": character_home_name,
		"character_origin": character_origin,
		"character_attributes": character_attributes.duplicate(true),
		"player_home_building_id": player_home_building_id,
		"player_home_building_name": player_home_building_name,
		"day_time_hours": day_time_hours,
		"run_seed": run_seed,
		"kills": kills,
		"moon_phase_index": moon_phase_index,
		"moon_phase_noon_count": moon_phase_noon_count,
		"in_dungeon": dungeon_root != null and is_instance_valid(dungeon_root),
		"player": player_state,
		"horses": horse_state_to_save,
		"witch_companion": witch_state_to_save,
		"witch_companion_tactic": _witch_companion_tactic,
		"quests": quest_state,
		"session_state": _encode_save_value(session_state),
		"npc_society_snapshot": _read_json_dictionary(NPC_STATE_PATH),
		"home_storage_snapshot": _read_json_dictionary(HOME_STORAGE_PATH)
	}
	var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar a campanha.")
		if show_feedback:
			show_msg("Falha ao salvar o jogo.")
		if is_instance_valid(pause_menu) and phase == "pause":
			pause_menu.call("notify_saved", false)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	if file.get_error() != OK:
		push_warning("Ocorreu um erro ao gravar o arquivo da campanha.")
		if show_feedback:
			show_msg("Falha ao gravar o jogo.")
		if is_instance_valid(pause_menu) and phase == "pause":
			pause_menu.call("notify_saved", false)
		return false
	_campaign_autosave_timer = 0.0
	if show_feedback:
		show_msg("Progresso salvo.")
		if phase == "pause" and overlay_body != null:
			overlay_body.text = "Progresso salvo.\n\nVocê também pode salvar durante a aventura com F5."
			if overlay_save_btn != null:
				overlay_save_btn.text = "SALVAR NOVAMENTE"
	if is_instance_valid(pause_menu) and phase == "pause":
		pause_menu.call("notify_saved", true)
	return true


func _normalize_saved_quest_locations(source: Dictionary) -> Dictionary:
	# Atualiza nomes já gravados nas missões sem alterar seus IDs, objetivos ou estado.
	var normalized := source.duplicate(true)
	for quest_key in normalized.keys():
		var quest_value: Variant = normalized[quest_key]
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value.duplicate(true)
		var old_city_name := str(quest.get("city_name", ""))
		var city_id := str(quest.get("city_id", ""))
		if city_id.begins_with("settlement_"):
			var current_city_name := WORLD_NAMES.settlement_name(city_id)
			if old_city_name != "" and old_city_name != current_city_name:
				quest["title"] = str(quest.get("title", "")).replace(old_city_name, current_city_name)
				quest["description"] = str(quest.get("description", "")).replace(old_city_name, current_city_name)
			quest["city_name"] = current_city_name
		var site_id := str(quest.get("site_id", ""))
		if site_id != "" and overworld != null and is_instance_valid(overworld) and overworld.has_method("get_resource_site"):
			var current_site_value: Variant = overworld.call("get_resource_site", site_id)
			var current_site: Dictionary = current_site_value if current_site_value is Dictionary else {}
			var old_site_name := str(quest.get("site_name", ""))
			var current_site_name := str(current_site.get("name", ""))
			if current_site_name != "":
				if old_site_name != "" and old_site_name != current_site_name:
					quest["title"] = str(quest.get("title", "")).replace(old_site_name, current_site_name)
					quest["description"] = str(quest.get("description", "")).replace(old_site_name, current_site_name)
				quest["site_name"] = current_site_name
		normalized[quest_key] = quest
	return normalized


func _find_unique_witch_node() -> Node3D:
	if is_instance_valid(_witch_companion) and bool(_witch_companion.get("is_unique_witch")):
		return _witch_companion
	if overworld != null and is_instance_valid(overworld):
		var npc_values: Variant = overworld.get("npcs")
		if npc_values is Array:
			for npc_value in npc_values:
				if npc_value is Node3D and is_instance_valid(npc_value) and bool(npc_value.get("is_unique_witch")):
					return npc_value
	return null


func _save_from_pause() -> void:
	_save_campaign(true)


func _dispose_overworld_for_dungeon_restore() -> void:
	if overworld != null and is_instance_valid(overworld):
		overworld.free()
	overworld = null


func _apply_loaded_campaign_state() -> void:
	if _continue_payload.is_empty():
		return
	var saved_in_dungeon := bool(_continue_payload.get("in_dungeon", false))
	var loaded_player_position := Vector3.ZERO
	var has_loaded_player_position := false
	var player_data_value: Variant = _decode_save_value(_continue_payload.get("player", {}))
	var player_data: Dictionary = player_data_value if player_data_value is Dictionary else {}
	if player != null and is_instance_valid(player):
		player.level = maxi(1, int(player_data.get("level", 1)))
		player.experience = maxi(0, int(player_data.get("experience", 0)))
		player.attribute_points = maxi(0, int(player_data.get("attribute_points", 0)))
		var saved_attributes: Variant = player_data.get("attributes", character_attributes)
		player.attributes = saved_attributes.duplicate(true) if saved_attributes is Dictionary else character_attributes.duplicate(true)
		var saved_proficiencies: Variant = player_data.get("proficiencies", {})
		player.proficiencies = saved_proficiencies.duplicate(true) if saved_proficiencies is Dictionary else {}
		player.call("_recalculate_derived_stats")
		player.hp = clampf(float(player_data.get("hp", player.max_hp)), 1.0, float(player.max_hp))
		player.mana = clampf(float(player_data.get("mana", player.max_mana)), 0.0, float(player.max_mana))
		player.gold = maxi(0, int(player_data.get("gold", 0)))
		player.potions = maxi(0, int(player_data.get("potions", 0)))
		var saved_resources: Variant = player_data.get("resources", {})
		player.resources = saved_resources.duplicate(true) if saved_resources is Dictionary else {}
		var saved_weapons: Variant = player_data.get("weapons", [])
		player.weapons = saved_weapons.duplicate(true) if saved_weapons is Array else []
		var saved_armors: Variant = player_data.get("armors", [])
		player.armors = saved_armors.duplicate(true) if saved_armors is Array else []
		var saved_spells: Variant = player_data.get("spells", [])
		player.spells = saved_spells.duplicate(true) if saved_spells is Array else []
		var saved_slots: Variant = player_data.get("consumable_slots", ["potion", "", ""])
		player.consumable_slots = saved_slots.duplicate(true) if saved_slots is Array else ["potion", "", ""]
		if player.weapons.is_empty():
			player.weapons = [_db_find(WEAPON_DB, "fist").duplicate(true)]
		if player.armors.is_empty():
			player.armors = [ARMOR_DB[0].duplicate(true)]
		player.weapon_idx = clampi(int(player_data.get("weapon_idx", 0)), 0, player.weapons.size() - 1)
		player.armor_idx = clampi(int(player_data.get("armor_idx", 0)), 0, player.armors.size() - 1)
		player.spell_idx = clampi(int(player_data.get("spell_idx", 0)), 0, maxi(0, player.spells.size() - 1))
		player.active_equipment_type = str(player_data.get("active_equipment_type", "weapon"))
		if player.active_equipment_type == "spell" and player.spells.is_empty():
			player.active_equipment_type = "weapon"
		player.set("_dead", false)
		var position_data: Variant = player_data.get("position", [])
		if position_data is Array and position_data.size() >= 3:
			loaded_player_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
			has_loaded_player_position = true
			player.global_position = loaded_player_position
		player.rotation.y = float(player_data.get("rotation_y", 0.0))
		if player.cam != null:
			player.cam.rotation.x = clampf(float(player_data.get("camera_pitch", 0.0)), deg_to_rad(-80.0), deg_to_rad(80.0))
			player.set("_pitch", player.cam.rotation.x)
		player.velocity = Vector3.ZERO
		if player.active_equipment_type == "spell" and not player.spells.is_empty():
			player.call("_build_weapon_model", "magic")
		elif not player.weapons.is_empty():
			player.call("_build_weapon_model", str(player.weapons[player.weapon_idx].get("model", "sword")))
		else:
			player.call("_build_weapon_model", "fist")
	var saved_horses_value: Variant = _continue_payload.get("horses", [])
	if saved_horses_value is Array:
		_last_horse_state = saved_horses_value.duplicate(true)
		_pending_horse_restore = saved_horses_value.duplicate(true)
		if not saved_in_dungeon and overworld != null and is_instance_valid(overworld) and overworld.has_method("restore_horse_save_state"):
			overworld.call("restore_horse_save_state", _pending_horse_restore)
			_pending_horse_restore.clear()
	var saved_witch_value: Variant = _continue_payload.get("witch_companion", {})
	if saved_witch_value is Dictionary and not saved_witch_value.is_empty():
		var witch_to_restore: Node3D = _find_unique_witch_node()
		if is_instance_valid(witch_to_restore):
			var saved_witch_position: Variant = saved_witch_value.get("position", [])
			if saved_witch_position is Array and saved_witch_position.size() >= 3:
				var restored_witch_position := Vector3(float(saved_witch_position[0]), float(saved_witch_position[1]), float(saved_witch_position[2]))
				if is_finite(restored_witch_position.x) and is_finite(restored_witch_position.y) and is_finite(restored_witch_position.z):
					witch_to_restore.global_position = restored_witch_position
			witch_to_restore.rotation.y = float(saved_witch_value.get("rotation_y", witch_to_restore.rotation.y))
			if str(saved_witch_value.get("state", witch_to_restore.get("witch_state"))) == "allied":
				_witch_companion = witch_to_restore
				if saved_in_dungeon and overworld != null and is_instance_valid(overworld) and witch_to_restore.get_parent() == overworld:
					witch_to_restore.reparent(self, true)
	var quest_value: Variant = _decode_save_value(_continue_payload.get("quests", {}))
	var saved_quests: Dictionary = quest_value if quest_value is Dictionary else {}
	if quest_manager != null and is_instance_valid(quest_manager):
		var quests_value: Variant = saved_quests.get("quests_by_id", {})
		var restored_quests: Dictionary = quests_value.duplicate(true) if quests_value is Dictionary else {}
		quest_manager.set("quests_by_id", _normalize_saved_quest_locations(restored_quests))
		var saved_offers_value: Variant = saved_quests.get("offer_by_npc", {})
		quest_manager.set("offer_by_npc", saved_offers_value.duplicate(true) if saved_offers_value is Dictionary else {})
		var saved_offer_generations_value: Variant = saved_quests.get("offer_generation_by_npc", {})
		quest_manager.set("offer_generation_by_npc", saved_offer_generations_value.duplicate(true) if saved_offer_generations_value is Dictionary else {})
		quest_manager.set("tracked_quest_id", str(saved_quests.get("tracked_quest_id", "")))
	if saved_in_dungeon:
		# A cripta é determinística a partir da seed da campanha: reconstrói a cena
		# e em seguida devolve o jogador à coordenada salva, sem tratá-la como terreno.
		if overworld != null and is_instance_valid(overworld):
			_dispose_overworld_for_dungeon_restore()
		if world_environment_node != null and dungeon_environment != null:
			world_environment_node.environment = dungeon_environment
		if player != null and player.cam != null:
			player.cam.environment = null
		_build_dungeon()
		if has_loaded_player_position and player != null:
			player.global_position = loaded_player_position
			player.velocity = Vector3.ZERO
	elif has_loaded_player_position and player != null:
		player.global_position = loaded_player_position
		player.velocity = Vector3.ZERO
	_continue_payload.clear()
	_last_observed_world_hour = fposmod(day_time_hours, 24.0)
	_campaign_autosave_timer = 0.0


func _show_character_creator() -> void:
	phase = "character_creation"
	if _menu_music_player != null:
		_menu_music_player.stop()
	if _time_jingle_player != null:
		_time_jingle_player.stop()
	if _town_song_player != null:
		_town_song_player.stop()
	if _travel_song_player != null:
		_travel_song_player.stop()
	_dispose_menu_landscape()
	if is_instance_valid(_character_creator_layer):
		_character_creator_layer.free()
	_character_creator_layer = CanvasLayer.new()
	_character_creator_layer.name = "CharacterCreationLayer"
	_character_creator_layer.layer = 100
	add_child(_character_creator_layer)

	_character_creator = Control.new()
	_character_creator.name = "CharacterCreationScreen"
	_character_creator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_character_creator_layer.add_child(_character_creator)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.03, 0.032, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_character_creator.add_child(backdrop)

	var heading := Label.new()
	heading.text = "NOVA JORNADA"
	heading.position = Vector2(36, 22)
	heading.size = Vector2(520, 44)
	heading.add_theme_font_size_override("font_size", 29)
	heading.add_theme_color_override("font_color", Color(0.83, 0.69, 0.43))
	_character_creator.add_child(heading)

	# Ficha discreta à esquerda, sem texto explicando a interface ao jogador.
	var left_panel := PanelContainer.new()
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 36
	left_panel.offset_top = 80
	left_panel.offset_right = 374
	left_panel.offset_bottom = -28
	left_panel.add_theme_stylebox_override("panel", _creator_panel_style(Color(0.075, 0.082, 0.082, 0.98)))
	_character_creator.add_child(left_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	left_panel.add_child(margin)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 9)
	margin.add_child(form)

	form.add_child(_creator_label("NOME"))
	_character_name_input = LineEdit.new()
	_character_name_input.placeholder_text = "Nome do personagem"
	_character_name_input.text = ""
	_character_name_input.max_length = 32
	_character_name_input.custom_minimum_size.y = 38
	form.add_child(_creator_style_input(_character_name_input))

	var origin_title := _creator_label("CLASSE")
	origin_title.add_theme_constant_override("margin_top", 8)
	form.add_child(origin_title)
	_character_origin_select = OptionButton.new()
	_character_origin_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_origin_select.custom_minimum_size.y = 38
	_character_origin_select.add_item("Andarilho")
	_character_origin_select.add_item("Antigo Guarda")
	_character_origin_select.add_item("Aprendiz Arcano")
	_character_origin_select.add_item("Artesão")
	_character_origin_select.item_selected.connect(_on_creator_origin_changed)
	form.add_child(_creator_style_input(_character_origin_select))

	_character_origin_description = Label.new()
	_character_origin_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_character_origin_description.custom_minimum_size.y = 72
	_character_origin_description.add_theme_font_size_override("font_size", 13)
	_character_origin_description.add_theme_color_override("font_color", Color(0.72, 0.71, 0.66))
	form.add_child(_character_origin_description)
	_update_character_origin_description()

	var flexible_space := Control.new()
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(flexible_space)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	form.add_child(actions)
	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size.y = 40
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_close_character_creator)
	actions.add_child(back)
	var begin := Button.new()
	begin.text = "COMEÇAR"
	begin.custom_minimum_size.y = 40
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	begin.pressed.connect(_confirm_character_creation)
	actions.add_child(begin)

	# O mapa ocupa a maior parte da tela. Cada ponto corresponde à posição real
	# de um Settlement_... existente no GLB do overworld.
	var map_panel := PanelContainer.new()
	map_panel.anchor_left = 0.31
	map_panel.anchor_top = 0.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_bottom = 1.0
	map_panel.offset_left = 14
	map_panel.offset_top = 80
	map_panel.offset_right = -36
	map_panel.offset_bottom = -28
	map_panel.add_theme_stylebox_override("panel", _creator_panel_style(Color(0.055, 0.063, 0.064, 0.98)))
	_character_creator.add_child(map_panel)

	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 16)
	map_margin.add_theme_constant_override("margin_right", 16)
	map_margin.add_theme_constant_override("margin_top", 14)
	map_margin.add_theme_constant_override("margin_bottom", 12)
	map_panel.add_child(map_margin)
	var map_column := VBoxContainer.new()
	map_column.add_theme_constant_override("separation", 8)
	map_margin.add_child(map_column)

	var map_heading := Label.new()
	map_heading.text = "BRUMAFÉRREA"
	map_heading.add_theme_font_size_override("font_size", 20)
	map_heading.add_theme_color_override("font_color", Color(0.83, 0.69, 0.43))
	map_column.add_child(map_heading)

	_character_map_surface = Control.new()
	_character_map_surface.name = "SettlementMapSurface"
	_character_map_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_map_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_map_surface.custom_minimum_size = Vector2(440, 340)
	map_column.add_child(_character_map_surface)
	_build_character_map()

	var chosen_row := HBoxContainer.new()
	chosen_row.add_theme_constant_override("separation", 10)
	map_column.add_child(chosen_row)
	var city_caption := Label.new()
	city_caption.text = "CIDADE NATAL"
	city_caption.add_theme_color_override("font_color", Color(0.68, 0.68, 0.63))
	city_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chosen_row.add_child(city_caption)
	_character_home_label = Label.new()
	_character_home_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_home_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_character_home_label.add_theme_font_size_override("font_size", 18)
	_character_home_label.add_theme_color_override("font_color", Color(0.93, 0.82, 0.59))
	chosen_row.add_child(_character_home_label)
	_character_city_description = Label.new()
	_character_city_description.name = "SelectedCityDescription"
	_character_city_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_character_city_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_city_description.custom_minimum_size.y = 50
	_character_city_description.add_theme_font_size_override("font_size", 13)
	_character_city_description.add_theme_color_override("font_color", Color(0.75, 0.75, 0.69))
	map_column.add_child(_character_city_description)
	_select_home_settlement(_character_selected_home_index)

	overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_character_name_input.grab_focus()
	call_deferred("_layout_home_map_pins")


func _creator_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.24, 0.25, 0.23, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _creator_style_input(control: Control) -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.041, 0.042, 1.0)
	style.border_color = Color(0.25, 0.26, 0.24, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	control.add_theme_stylebox_override("normal", style)
	control.add_theme_stylebox_override("focus", style)
	if control is OptionButton:
		control.add_theme_stylebox_override("hover", style)
	return control


func _creator_label(caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.68))
	return label


func _on_creator_origin_changed(_index: int) -> void:
	_update_character_origin_description()


func _update_character_origin_description() -> void:
	if _character_origin_description == null or _character_origin_select == null:
		return
	match _character_origin_select.selected:
		0:
			_character_origin_description.text = "Aprendeu nas estradas e se adapta a qualquer situação. Sem especialização: começa com atributos equilibrados."
		1:
			_character_origin_description.text = "Serviu na guarda e conhece o peso de uma luta. +1 Vigor e +1 Força: mais vida e dano corpo a corpo."
		2:
			_character_origin_description.text = "Estudou com alguém que conhecia os segredos arcanos. +2 Arcana: mais mana e poder nos feitiços."
		3:
			_character_origin_description.text = "Anos de trabalho manual ensinaram precisão e reflexos. +1 Agilidade: maior chance de acerto crítico."
		_:
			_character_origin_description.text = ""


func _build_character_map() -> void:
	_character_settlements.clear()
	_character_home_pin_buttons.clear()
	_character_map_viewport = SubViewport.new()
	_character_map_viewport.name = "CharacterCreationMapViewport"
	_character_map_viewport.size = Vector2i(1000, 700)
	_character_map_viewport.disable_3d = false
	_character_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "MapViewportContainer"
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_map_surface.add_child(viewport_container)
	viewport_container.add_child(_character_map_viewport)

	_character_map_pin_layer = Control.new()
	_character_map_pin_layer.name = "SettlementPins"
	_character_map_pin_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_character_map_pin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_map_surface.add_child(_character_map_pin_layer)

	_character_map_surface.resized.connect(_on_character_map_resized)

	var map_environment := Environment.new()
	map_environment.background_mode = Environment.BG_COLOR
	map_environment.background_color = Color(0.12, 0.14, 0.13)
	map_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	map_environment.ambient_light_color = Color(0.66, 0.68, 0.63)
	map_environment.ambient_light_energy = 0.9

	_character_map_world_root = Node3D.new()
	_character_map_world_root.name = "CharacterCreationMapWorld"
	_character_map_viewport.add_child(_character_map_world_root)
	var packed_world := load(OVERWORLD_SCENE) as PackedScene
	if packed_world != null:
		var world_scene := packed_world.instantiate() as Node3D
		if world_scene != null:
			world_scene.name = "BrumaferreaMapModel"
			_character_map_world_root.add_child(world_scene)
			_character_homeable_settlement_ids.clear()
			_collect_character_homeable_settlements(world_scene)
			_collect_character_settlements(world_scene)

	var sun := DirectionalLight3D.new()
	sun.name = "CharacterMapSun"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	_character_map_world_root.add_child(sun)

	var map_camera := Camera3D.new()
	map_camera.name = "CharacterMapCamera"
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = CHARACTER_MAP_CAMERA_SIZE
	map_camera.position = Vector3(0.0, 2500.0, 0.0)
	map_camera.near = 0.1
	map_camera.far = 5000.0
	map_camera.environment = map_environment
	_character_map_world_root.add_child(map_camera)
	map_camera.look_at(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	map_camera.make_current()

	# Os nomes exibidos vêm do nome legível no GLB; o ID persiste separadamente.
	_character_settlements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	for index in range(_character_settlements.size()):
		var entry: Dictionary = _character_settlements[index]
		var pin := Button.new()
		pin.name = "SettlementPin_%02d" % index
		pin.text = "●"
		pin.tooltip_text = str(entry.get("name", "Cidade"))
		pin.flat = true
		pin.focus_mode = Control.FOCUS_NONE
		pin.custom_minimum_size = Vector2(26, 26)
		pin.add_theme_font_size_override("font_size", 17)
		pin.add_theme_color_override("font_color", Color(0.88, 0.85, 0.74))
		pin.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.45))
		pin.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.32))
		pin.pressed.connect(_on_home_map_pin_pressed.bind(index))
		_character_map_pin_layer.add_child(pin)
		_character_home_pin_buttons.append(pin)

	if _character_settlements.is_empty():
		var warning := Label.new()
		warning.text = "Mapa indisponível"
		warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_character_map_pin_layer.add_child(warning)
	else:
		_select_home_settlement(0)
	call_deferred("_layout_home_map_pins")


func _collect_character_homeable_settlements(node: Node) -> void:
	# Ruínas sem casas não são opções de cidade natal: a seleção garante que
	# todo ponto escolhido tenha uma construção física onde a casa do jogador caiba.
	var building_regex := RegEx.new()
	building_regex.compile("settlement_(\\d+)_building_\\d+_house$")
	var walk: Array[Node] = [node]
	while not walk.is_empty():
		var current: Node = walk.pop_back()
		var matched := building_regex.search(str(current.name).to_lower())
		if matched != null:
			_character_homeable_settlement_ids["settlement_%s" % matched.get_string(1)] = true
		for child in current.get_children():
			walk.append(child)


func _collect_character_settlements(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D:
			var marker_name := str(child.name)
			if marker_name.to_lower().begins_with("settlement_"):
				var marker_regex := RegEx.new()
				marker_regex.compile("(?i)^settlement_(\\d+)(?:[_ ]+(.*))?$")
				var found := marker_regex.search(marker_name)
				if found != null:
					var number := found.get_string(1)
					var marker_id := "settlement_%s" % number
					var title := WORLD_NAMES.settlement_name(marker_name)
					if _character_homeable_settlement_ids.has(marker_id):
						var already_added := false
						for old_entry in _character_settlements:
							if str(old_entry.get("id", "")) == marker_id:
								already_added = true
								break
						if not already_added:
							_character_settlements.append({
								"id": marker_id,
								"name": title if title != "" else "Cidade %s" % number,
								"position": child.global_position,
							})
		_collect_character_settlements(child)


func _on_character_map_resized() -> void:
	if _character_map_viewport != null and is_instance_valid(_character_map_viewport) and _character_map_surface != null:
		var dimensions := _character_map_surface.size
		_character_map_viewport.size = Vector2i(maxi(1, int(dimensions.x)), maxi(1, int(dimensions.y)))
	_layout_home_map_pins()


func _layout_home_map_pins() -> void:
	if _character_map_surface == null or _character_map_pin_layer == null:
		return
	var dimensions := _character_map_surface.size
	if dimensions.x <= 0.0 or dimensions.y <= 0.0:
		return
	for index in range(mini(_character_home_pin_buttons.size(), _character_settlements.size())):
		var pin := _character_home_pin_buttons[index]
		if not is_instance_valid(pin):
			continue
		var position_value: Vector3 = _character_settlements[index].get("position", Vector3.ZERO)
		# A câmera ortográfica usa a mesma escala vertical e horizontal em unidades do mundo;
		# o cálculo acompanha a proporção real do painel, mantendo os pontos alinhados.
		var pixels_per_unit := dimensions.y / CHARACTER_MAP_CAMERA_SIZE
		pin.position = Vector2(
			dimensions.x * 0.5 + position_value.x * pixels_per_unit - pin.size.x * 0.5,
			dimensions.y * 0.5 + position_value.z * pixels_per_unit - pin.size.y * 0.5
		)


func _on_home_map_pin_pressed(index: int) -> void:
	_select_home_settlement(index)


func _select_home_settlement(index: int) -> void:
	if index < 0 or index >= _character_settlements.size():
		return
	_character_selected_home_index = index
	var entry: Dictionary = _character_settlements[index]
	var selected_name := str(entry.get("name", "Brumaférrea"))
	var selected_id := str(entry.get("id", ""))
	if _character_home_label != null:
		_character_home_label.text = selected_name
	if _character_city_description != null:
		_character_city_description.text = get_settlement_description(selected_id)
	for pin_index in range(_character_home_pin_buttons.size()):
		var pin := _character_home_pin_buttons[pin_index]
		if not is_instance_valid(pin):
			continue
		pin.text = "◆" if pin_index == index else "●"
		pin.add_theme_color_override("font_color", Color(1.0, 0.79, 0.38) if pin_index == index else Color(0.84, 0.85, 0.79))

func _close_character_creator() -> void:
	if is_instance_valid(_character_creator_layer):
		_character_creator_layer.queue_free()
	_character_creator_layer = null
	_character_creator = null
	_character_map_surface = null
	_character_map_viewport = null
	_character_map_world_root = null
	_character_map_pin_layer = null
	_character_home_label = null
	_character_city_description = null
	_character_origin_description = null
	_character_home_pin_buttons.clear()
	_character_settlements.clear()
	_character_homeable_settlement_ids.clear()
	_show_menu()


func _confirm_character_creation() -> void:
	character_name = _character_name_input.text.strip_edges()
	if character_name.is_empty():
		character_name = "Aventureiro"
	var home_index := _character_selected_home_index
	if home_index >= 0 and home_index < _character_settlements.size():
		var chosen_home: Dictionary = _character_settlements[home_index]
		character_home_id = str(chosen_home.get("id", ""))
		character_home_name = str(chosen_home.get("name", "Brumaférrea"))
	else:
		character_home_id = ""
		character_home_name = "Brumaférrea"
	var origin_index := _character_origin_select.selected
	var origin_labels := ["andarilho", "antigo_guarda", "aprendiz_arcano", "artesao"]
	character_origin = origin_labels[clampi(origin_index, 0, origin_labels.size() - 1)]
	character_attributes = {"vigor": 5, "strength": 5, "agility": 5, "arcana": 5}
	match character_origin:
		"antigo_guarda":
			character_attributes["strength"] = 6
			character_attributes["vigor"] = 6
		"aprendiz_arcano":
			character_attributes["arcana"] = 7
		"artesao":
			character_attributes["agility"] = 6
	if is_instance_valid(_character_creator_layer):
		_character_creator_layer.queue_free()
	_character_creator_layer = null
	_character_creator = null
	_character_map_surface = null
	_character_map_viewport = null
	_character_map_world_root = null
	_character_map_pin_layer = null
	_character_home_label = null
	_character_city_description = null
	_character_origin_description = null
	_character_home_pin_buttons.clear()
	_character_settlements.clear()
	_begin_new_adventure()
	start_run()


func _on_main_menu_quit() -> void:
	if _active_campaign:
		_save_campaign(false)
	get_tree().quit()


func _resume() -> void:
	phase = "play"
	overlay.visible = false
	if is_instance_valid(gameplay_hud_root):
		gameplay_hud_root.visible = true
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	if inventory_screen != null:
		inventory_screen.visible = false
	if home_storage_screen != null:
		home_storage_screen.visible = false
	if quest_journal != null:
		quest_journal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_overlay(title: String, body: String, btn_text: String, action: Callable) -> void:
	if is_instance_valid(gameplay_hud_root):
		gameplay_hud_root.visible = false
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	if menu_content != null:
		menu_content.visible = false
	if overlay_save_btn != null:
		overlay_save_btn.visible = false
	overlay_center.visible = true
	overlay_dim.color = Color(0.03, 0.02, 0.02, 0.88)
	overlay_title.text = title
	overlay_body.text = body
	overlay_btn.text = btn_text
	overlay_action = action
	overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_overlay_button() -> void:
	if overlay_action.is_valid():
		overlay_action.call()


func _make_main_menu_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(340.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", UiFrame.font())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.88, 0.85, 0.76))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.68))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 0.65, 0.40))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.018, 0.021, 0.02, 0.42)
	normal.border_color = Color(0.47, 0.39, 0.25, 0.62)
	normal.set_border_width_all(1)
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.105, 0.075, 0.78)
	hover.border_color = Color(0.78, 0.63, 0.36, 0.95)
	hover.set_border_width_all(1)
	hover.border_width_left = 4
	hover.content_margin_left = 15.0
	hover.content_margin_right = 18.0
	hover.content_margin_top = 10.0
	hover.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.14, 0.08, 0.85)
	pressed.border_color = Color(0.88, 0.71, 0.4, 1.0)
	pressed.set_border_width_all(1)
	pressed.border_width_left = 4
	pressed.content_margin_left = 15.0
	pressed.content_margin_right = 18.0
	pressed.content_margin_top = 10.0
	pressed.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button


func _on_won(xp_reward: int = 0, level_message: String = "") -> void:
	phase = "won"
	var victory_text := "O Orc Chefe caiu. Você saiu da cripta com %d ouro e %d inimigos derrotados. +%d XP." % [player.gold, kills, xp_reward]
	if level_message != "":
		victory_text += "\n" + level_message
	_show_overlay("Vitória!", victory_text, "Jogar de novo", start_run)


func _check_pickups() -> void:
	var p: Vector3 = player.global_position
	for i in range(pickups.size() - 1, -1, -1):
		var item: Dictionary = pickups[i]
		var node = item["node"]
		if not is_instance_valid(node):
			pickups.remove_at(i)
			continue
		var n: Vector3 = node.global_position
		if Vector2(n.x, n.z).distance_to(Vector2(p.x, p.z)) < 1.2:
			_collect(item)
			node.queue_free()
			pickups.remove_at(i)


func _collect(item: Dictionary) -> void:
	var kind: String = item["kind"]
	if kind == "potion":
		player.add_potion()
		show_msg("Você encontrou uma poção.")
	elif kind == "weapon":
		player.add_weapon(item["item"])
		show_msg("Você encontrou: %s. Abra o inventário (I) para equipar." % item["item"]["name"])
	elif kind == "armor":
		player.add_armor(item["item"])
		show_msg("Você encontrou: %s. Abra o inventário (I) para vestir." % item["item"]["name"])
	elif kind == "scroll":
		var spell: Dictionary = item["item"]
		if player.learn_spell(spell["id"]):
			show_msg("Você aprendeu: %s!" % spell["name"])
		else:
			var g := rng.randi_range(8, 14)
			player.add_gold(g)
			show_msg("Você já conhece %s. +%d ouro" % [spell["name"], g])
	else:
		var g2 := rng.randi_range(5, 12)
		player.add_gold(g2)
		show_msg("+%d ouro" % g2)


# ---------- Mundo aberto ----------

func _open_overworld() -> void:
	if overworld:
		if player != null and is_instance_valid(player) and bool(player.get("is_mounted")) and overworld.has_method("dismount_horse"):
			overworld.call("dismount_horse", true)
		overworld.queue_free()
	overworld = Node3D.new()
	overworld.name = "Overworld"
	overworld.set_script(load(OVERWORLD_SCRIPT))
	add_child(overworld)
	await overworld.open(self)
	if _continue_payload.is_empty() and not _pending_horse_restore.is_empty() and overworld != null and is_instance_valid(overworld) and overworld.has_method("restore_horse_save_state"):
		overworld.call("restore_horse_save_state", _pending_horse_restore)
		_last_horse_state = _pending_horse_restore.duplicate(true)
		_pending_horse_restore.clear()
	var continuing_into_dungeon := not _continue_payload.is_empty() and bool(_continue_payload.get("in_dungeon", false))
	if not _continue_payload.is_empty():
		_apply_loaded_campaign_state()
	if not continuing_into_dungeon:
		_quest_marker_signature = "__INITIAL_QUEST_MARKER_SYNC__"
		_sync_quest_giver_markers()
		show_msg(overworld.map_note if is_instance_valid(overworld) else "A campanha foi restaurada.")
	# Contratos ativos recuperam os alvos apenas quando a cena externa está ativa.
	if not continuing_into_dungeon and quest_manager != null and quest_manager.has_method("restore_active_quest_targets"):
		var restore_message: String = quest_manager.restore_active_quest_targets()
		if restore_message != "":
			show_msg(restore_message)
	if _save_initial_when_world_ready:
		_save_initial_when_world_ready = false
		_new_adventure_pending = false
		_save_campaign(false)


func enter_dungeon() -> void:
	if world_environment_node != null and dungeon_environment != null:
		world_environment_node.environment = dungeon_environment
	if overworld:
		if overworld.has_method("get_horse_save_state"):
			var horse_state_value: Variant = overworld.call("get_horse_save_state")
			if horse_state_value is Array:
				_last_horse_state = horse_state_value.duplicate(true)
				_pending_horse_restore = horse_state_value.duplicate(true)
		# Capture the allied witch before freeing the overworld. A companion is a
		# gameplay actor, not part of the disposable ambient population.
		if not is_instance_valid(_witch_companion):
			var npc_values: Variant = overworld.get("npcs")
			if npc_values is Array:
				for npc_value in npc_values:
					if npc_value is Node3D and is_instance_valid(npc_value) and bool(npc_value.get("is_unique_witch")) and str(npc_value.get("witch_state")) == "allied":
						_witch_companion = npc_value
						break
		if is_instance_valid(_witch_companion) and _witch_companion.get_parent() == overworld:
			_witch_companion.reparent(self, true)
		overworld.queue_free()
		overworld = null
	player.cam.environment = null
	_build_dungeon()
	_resume()
	show_msg("Você desce à cripta. O ar fica mais frio, e alguma coisa pesada se move nas profundezas.")


func try_interact() -> void:
	if phase != "play" or overworld == null or player == null:
		return
	if bool(player.get("is_mounted")):
		if overworld.has_method("dismount_horse"):
			overworld.call("dismount_horse")
		return
	if overworld.has_method("is_inside_generated_interior") and overworld.call("is_inside_generated_interior"):
		if overworld.has_method("is_aiming_at_exit") and bool(overworld.call("is_aiming_at_exit")):
			overworld.call("exit_building")
			return
		# Moradores presentes no interior usam os mesmos NPCs do mundo, portanto
		# continuam com as mesmas árvores de diálogo e opções de missão.
		var interior_hit: Dictionary = overworld.aimed_interactable(player.global_position, 4.0)
		var interior_kind := str(interior_hit.get("kind", ""))
		if interior_kind == "home_bed":
			sleep_in_player_home()
			return
		if interior_kind == "home_storage":
			open_home_storage()
			return
		if interior_kind in ["tavern_counter", "tavern_board"]:
			var active_building: Dictionary = overworld.get("_active_building_record")
			phase = "dialog"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var is_counter := interior_kind == "tavern_counter"
			var speaker := str(active_building.get("name", "Taverna")) if is_counter else "Rumores e notícias"
			dialog.open(speaker, _build_tavern_interaction_tree(is_counter))
			return
		if interior_kind != "npc":
			return
		phase = "dialog"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var interior_npc = interior_hit["node"]
		_talk_npc = interior_npc
		var interior_context: Dictionary = _build_npc_dialogue_context(interior_npc)
		var interior_tree: Dictionary = interior_npc.dialogue(interior_context)
		_record_player_npc_interaction(interior_npc, interior_context)
		if quest_manager != null:
			interior_tree = quest_manager.add_dialogue_options(interior_npc, interior_tree)
		interior_tree = _add_resource_trade_options(interior_npc, interior_tree)
		interior_tree = _organize_npc_interaction_tree(interior_tree)
		dialog.open(_npc_interaction_speaker(interior_npc), interior_tree)
		return
	var hit: Dictionary = overworld.aimed_interactable(player.global_position, 4.0)
	if hit.is_empty():
		return
	if str(hit.get("kind", "")) == "horse":
		if overworld.has_method("mount_horse"):
			overworld.call("mount_horse", hit.get("node"))
		return
	if str(hit.get("kind", "")) == "building":
		if overworld.has_method("enter_building"):
			overworld.call("enter_building", hit.get("record", {}))
		return
	if str(hit.get("kind", "")) == "resource":
		var gathered: Dictionary = overworld.harvest_resource(hit.get("node")) if overworld.has_method("harvest_resource") else {}
		if gathered.is_empty():
			return
		var resource_id: String = str(gathered.get("resource_id", ""))
		var resource_amount: int = int(gathered.get("amount", 1))
		player.add_resource(resource_id, resource_amount)
		var collected_message: String = "Você recolheu %d × %s em %s." % [resource_amount, RESOURCE_CATALOG.display_name(resource_id), str(gathered.get("site_name", "nos arredores"))]
		if quest_manager != null and quest_manager.has_method("register_resource_gathered"):
			var quest_message: String = str(quest_manager.call("register_resource_gathered", resource_id, resource_amount, str(gathered.get("site_id", ""))))
			if quest_message != "":
				collected_message += "\n" + quest_message
		show_msg(collected_message)
		return
	phase = "dialog"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hit["kind"] == "entrance":
		dialog.open("Entrada da cripta", _entrance_tree())
	else:
		var npc = hit["node"]
		_talk_npc = npc
		var npc_context: Dictionary = _build_npc_dialogue_context(npc)
		var npc_tree: Dictionary = npc.dialogue(npc_context)
		_record_player_npc_interaction(npc, npc_context)
		if quest_manager != null:
			npc_tree = quest_manager.add_dialogue_options(npc, npc_tree)
		npc_tree = _add_resource_trade_options(npc, npc_tree)
		npc_tree = _organize_npc_interaction_tree(npc_tree)
		dialog.open(_npc_interaction_speaker(npc), npc_tree)


func _npc_interaction_speaker(npc: Node) -> String:
	var display_name := str(npc.get("display_name"))
	var role := str(npc.get("role"))
	# Os perfis atuais trazem a profissão separada. O fallback mantém saves/instâncias
	# antigas utilizáveis, mas o título nunca é anexado duas vezes ao nome.
	var role_label := str(npc.get("occupation_label")).strip_edges()
	if role_label == "":
		var role_names := {
			"aldeao": "Morador", "guarda": "Guarda", "ferreiro": "Ferreiro",
			"mercador": "Mercador", "curandeira": "Curandeira", "mensageiro": "Mensageiro", "estalajadeiro": "Estalajadeiro",
			"bruxa": "Bruxa", "feiticeira": "Feiticeira", "witch": "Feiticeira"
		}
		role_label = str(role_names.get(role, role.replace("_", " ").capitalize()))
		var gender := str(npc.get("gender"))
		if role == "curandeira" and gender == "male":
			role_label = "Curandeiro"
		elif role == "estalajadeiro" and gender == "female":
			role_label = "Estalajadeira"
		elif role == "aldeao" and gender == "female":
			role_label = "Moradora"
	return display_name if role_label == "" else "%s — %s" % [display_name, role_label]


func _organize_npc_interaction_tree(source_tree: Dictionary) -> Dictionary:
	# Converte as opções geradas pelos sistemas de diálogo, missões e comércio
	# em submenus curtos. As falas continuam dentro dos tópicos, não no menu inicial.
	var tree: Dictionary = source_tree.duplicate(true)
	var start_node: Dictionary = tree.get("start", {})
	var original_options: Array = start_node.get("options", [])
	var groups: Dictionary = {
		"conversar": [],
		"estrategia": [],
		"servicos": [],
		"rumores": [],
		"relacao": [],
		"trabalhos": []
	}
	for top_option_value in original_options:
		if not (top_option_value is Dictionary):
			continue
		var top_option: Dictionary = top_option_value
		var label_lower := str(top_option.get("label", "")).to_lower()
		var next_key := str(top_option.get("next", ""))
		var action := str(top_option.get("action", ""))
		var category := "conversar"
		if next_key == "witch_tactics" or label_lower.contains("estratégia de combate"):
			category = "estrategia"
		elif next_key == "news" or label_lower.contains("notícia") or label_lower.contains("notícias"):
			category = "rumores"
		elif action == "shop" or action.begins_with("resource_sell:") or next_key == "sell_resources":
			category = "servicos"
		elif action.begins_with("quest_") or next_key.begins_with("quest_") or label_lower.contains("trabalho") or label_lower.contains("contrato"):
			category = "trabalhos"
		elif next_key == "personal" or next_key == "household" or next_key == "flirt_opening" or next_key == "witch_flirt":
			category = "relacao"
		groups[category].append(top_option)

	var category_order: Array[String] = ["conversar", "estrategia", "servicos", "rumores", "relacao", "trabalhos"]
	var category_labels := {
		"conversar": "Conversar",
		"estrategia": "Estratégia",
		"servicos": "Serviços",
		"rumores": "Rumores e notícias",
		"relacao": "Relação",
		"trabalhos": "Trabalhos"
	}
	var root_options: Array = []
	for category_id in category_order:
		var category_options: Array = groups[category_id]
		if category_options.is_empty():
			continue
		var category_key := "npc_menu_" + category_id
		for menu_option_value in category_options:
			if not (menu_option_value is Dictionary):
				continue
			var menu_option: Dictionary = menu_option_value
			var target_key := str(menu_option.get("next", ""))
			if target_key == "" or not tree.has(target_key):
				continue
			var target_node_value: Variant = tree[target_key]
			if not (target_node_value is Dictionary):
				continue
			var target_node: Dictionary = target_node_value
			var target_options: Array = target_node.get("options", [])
			for nested_value in target_options:
				if not (nested_value is Dictionary):
					continue
				var nested_option: Dictionary = nested_value
				if str(nested_option.get("next", "")) == "start":
					nested_option["next"] = category_key
			target_node["options"] = target_options
			tree[target_key] = target_node
		category_options.append({"label": "Voltar", "next": "start"})
		tree[category_key] = {"text": str(category_labels[category_id]), "options": category_options}
		root_options.append({"label": str(category_labels[category_id]), "next": category_key})
	tree["start"] = {"text": "", "options": root_options}
	return tree

func assign_player_home(record: Dictionary) -> void:
	# A casa é escolhida entre os edifícios físicos da cidade natal; o ID do GLB
	# permanece estável e também identifica o baú persistente.
	player_home_building_id = str(record.get("id", ""))
	player_home_building_name = "Casa de %s" % (character_name if character_name.strip_edges() != "" else "Aventureiro")
	_load_home_storage_records()
	if not character_home_id.is_empty() and not player_home_building_id.is_empty():
		_player_home_assignments[character_home_id] = player_home_building_id
	var stored: Variant = _home_storage_records.get(player_home_building_id, {})
	if stored is Dictionary:
		player_home_storage = stored.duplicate(true)
	else:
		player_home_storage = {}
	_ensure_home_storage_shape()
	save_player_home_storage()


func get_saved_player_home_building_id(settlement_id: String) -> String:
	_load_home_storage_records()
	return str(_player_home_assignments.get(settlement_id, ""))


func _ensure_home_storage_shape() -> void:
	if not player_home_storage.has("weapons") or not (player_home_storage["weapons"] is Array):
		player_home_storage["weapons"] = []
	if not player_home_storage.has("armors") or not (player_home_storage["armors"] is Array):
		player_home_storage["armors"] = []
	if not player_home_storage.has("potions"):
		player_home_storage["potions"] = 0
	if not player_home_storage.has("resources") or not (player_home_storage["resources"] is Dictionary):
		player_home_storage["resources"] = {}


func _load_home_storage_records() -> void:
	if _home_storage_file_loaded:
		return
	_home_storage_file_loaded = true
	if not FileAccess.file_exists(HOME_STORAGE_PATH):
		return
	var file := FileAccess.open(HOME_STORAGE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Não foi possível abrir o armazenamento da casa do jogador.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var records: Variant = parsed.get("houses", {})
		if records is Dictionary:
			_home_storage_records = records.duplicate(true)
		var assignments: Variant = parsed.get("home_assignments", {})
		if assignments is Dictionary:
			_player_home_assignments = assignments.duplicate(true)


func save_player_home_storage() -> void:
	if player_home_building_id.is_empty():
		return
	_ensure_home_storage_shape()
	_load_home_storage_records()
	_home_storage_records[player_home_building_id] = player_home_storage.duplicate(true)
	if not character_home_id.is_empty():
		_player_home_assignments[character_home_id] = player_home_building_id
	var file := FileAccess.open(HOME_STORAGE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível salvar o baú da casa do jogador.")
		return
	file.store_string(JSON.stringify({"houses": _home_storage_records, "home_assignments": _player_home_assignments}, "\t"))


func open_home_storage() -> void:
	if phase != "play" or home_storage_screen == null or player == null:
		return
	phase = "home_storage"
	overlay.visible = false
	if inventory_screen != null:
		inventory_screen.visible = false
	home_storage_screen.call("open")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_home_storage() -> void:
	if home_storage_screen != null:
		home_storage_screen.visible = false
	if phase == "home_storage":
		_resume()


func sleep_in_player_home() -> void:
	if phase != "play" or overworld == null or player == null:
		return
	var current_hour := fposmod(float(overworld.get("time_of_day_hours")), 24.0)
	var hours_to_dawn := 6.0 - current_hour if current_hour < 6.0 else 30.0 - current_hour
	if hours_to_dawn < 0.1:
		hours_to_dawn = 24.0
	# O relógio salta até o amanhecer; simula a pressão regional durante esse
	# período também, para que dormir não congele ataques já iniciados.
	if overworld.has_method("advance_regional_threats_for_sleep"):
		overworld.call("advance_regional_threats_for_sleep", hours_to_dawn, current_hour)
	day_time_hours = 6.0
	overworld.set("time_of_day_hours", 6.0)
	_last_observed_world_hour = 6.0
	var society: Variant = overworld.get("_npc_society")
	if society is Node and society.has_method("advance_clock_for_sleep"):
		society.call("advance_clock_for_sleep", hours_to_dawn, 6.0)
	if overworld.has_method("_update_day_night"):
		overworld.call("_update_day_night", 0.0)
	player.hp = int(player.get("max_hp"))
	player.mana = float(player.get("max_mana"))
	show_msg("Você descansou até o amanhecer. Vida e mana recuperadas. Passaram-se %.1f horas." % hours_to_dawn)


func _build_npc_dialogue_context(npc: Node) -> Dictionary:
	var context: Dictionary = {
		"hour": float(day_time_hours),
		"weather": 0,
		"regional_threat": 0.0,
		"regional_threat_status": "",
		"player_hp": 1,
		"player_max_hp": 1,
		"player_gold": 0,
		"city_id": str(npc.get("city_id")),
		"city_name": str(npc.get("city_name")),
		"player_name": character_name if character_name != "" else "Aventureiro",
		"player_home_settlement_id": character_home_id,
		"player_home_settlement_name": character_home_name,
		"player_origin": character_origin,
		"player_is_home": str(npc.get("city_id")) == character_home_id and character_home_id != "",
		"player_is_mounted": false,
		"player_wounded": false,
		"player_speed": 0.0,
		"nearby_enemy_count": 0,
		"nearest_enemy_name": "",
		"nearest_enemy_distance": -1.0,
		"witch_companion_tactic": _witch_companion_tactic,
		"event_memory_seconds": 150.0
	}
	if player != null and is_instance_valid(player):
		context["player_hp"] = int(player.get("hp"))
		context["player_max_hp"] = maxi(1, int(player.get("max_hp")))
		context["player_gold"] = int(player.get("gold"))
		context["player_is_mounted"] = bool(player.get("is_mounted"))
		context["player_wounded"] = int(player.get("hp")) < int(player.get("max_hp")) * 0.75
		var current_player_velocity: Variant = player.get("velocity")
		if current_player_velocity is Vector3:
			context["player_speed"] = Vector2(current_player_velocity.x, current_player_velocity.z).length()
	if overworld != null and is_instance_valid(overworld):
		context["hour"] = float(overworld.get("time_of_day_hours"))
		if overworld.has_method("is_inside_generated_interior") and bool(overworld.call("is_inside_generated_interior")):
			var active_building_value: Variant = overworld.get("_active_building_record")
			if active_building_value is Dictionary:
				var active_building: Dictionary = active_building_value
				var inside_id := str(active_building.get("id", ""))
				context["inside_building_id"] = inside_id
				context["inside_building_kind"] = str(active_building.get("kind", ""))
				context["inside_building_name"] = str(active_building.get("name", "esta estalagem"))
				var interior_occupant_count := 0
				for occupant in overworld.npcs:
					if is_instance_valid(occupant) and bool(occupant.get("is_interior_present")) and str(occupant.get("interior_building_id")) == inside_id:
						interior_occupant_count += 1
				context["tavern_occupant_count"] = interior_occupant_count
		context["weather"] = int(overworld.get("current_weather"))
		if npc is Node3D and is_instance_valid(npc) and overworld.has_method("get_weather_at_position"):
			var npc_weather_position: Vector3 = (npc as Node3D).global_position
			context["weather"] = int(overworld.call("get_weather_at_position", npc_weather_position))
			if overworld.has_method("get_weather_intensity_at_position"):
				context["weather_intensity"] = float(overworld.call("get_weather_intensity_at_position", npc_weather_position))
		if overworld.has_method("get_regional_threat"):
			context["regional_threat"] = float(overworld.call("get_regional_threat", str(npc.get("city_id"))))
		if overworld.has_method("get_regional_threat_status"):
			context["regional_threat_status"] = str(overworld.call("get_regional_threat_status", str(npc.get("city_id"))))
		var society: Variant = overworld.get("_npc_society")
		if society != null and is_instance_valid(society):
			if society.has_method("get_conversation_clock"):
				context["conversation_clock"] = float(society.call("get_conversation_clock"))
			if society.has_method("get_world_knowledge_for_npc"):
				context["world_knowledge"] = society.call("get_world_knowledge_for_npc", npc)
		# Cada conversa recebe uma leitura pontual do entorno daquele morador:
		# ameaças próximas, distância, hora, clima e o que o jogador aparenta.
		# Em interiores gerados, não confundimos coordenadas internas com monstros
		# que estejam do lado de fora do edifício.
		var local_enemy_count: int = 0
		var nearest_local_enemy_distance: float = INF
		var nearest_local_enemy_name := ""
		var inside_generated_interior := context.has("inside_building_id")
		if not inside_generated_interior and npc is Node3D and is_instance_valid(npc):
			var observer_position: Vector3 = (npc as Node3D).global_position
			for enemy_value in get_tree().get_nodes_in_group("enemies"):
				if enemy_value == npc or not (enemy_value is Node3D) or not is_instance_valid(enemy_value):
					continue
				var local_enemy: Node3D = enemy_value as Node3D
				if not local_enemy.visible or not local_enemy.has_method("take_hit"):
					continue
				var enemy_hp_value: Variant = local_enemy.get("hp")
				if enemy_hp_value != null and int(enemy_hp_value) <= 0:
					continue
				var local_distance: float = Vector2(local_enemy.global_position.x - observer_position.x, local_enemy.global_position.z - observer_position.z).length()
				if local_distance > 24.0 or absf(local_enemy.global_position.y - observer_position.y) > 6.0:
					continue
				local_enemy_count += 1
				if local_distance < nearest_local_enemy_distance:
					nearest_local_enemy_distance = local_distance
					nearest_local_enemy_name = str(local_enemy.get("display_name"))
		context["nearby_enemy_count"] = local_enemy_count
		context["nearest_enemy_name"] = nearest_local_enemy_name
		context["nearest_enemy_distance"] = nearest_local_enemy_distance if local_enemy_count > 0 else -1.0
		context["local_place_name"] = str(context.get("inside_building_name", npc.get("city_name")))
		context["witch_companion_tactic"] = _witch_companion_tactic
	return context


func _record_player_npc_interaction(npc: Node, context: Dictionary) -> void:
	# O diálogo continua sendo construído pelo próprio NPC; a sociedade registra
	# o encontro para que familiaridade e gratidão sobrevivam ao recarregamento.
	if npc == null or not is_instance_valid(npc) or overworld == null or not is_instance_valid(overworld):
		return
	var society: Variant = overworld.get("_npc_society")
	if society != null and is_instance_valid(society) and society.has_method("record_player_interaction"):
		society.call("record_player_interaction", npc, context)


func _entrance_tree() -> Dictionary:
	return {
		"start": {
			"text": "Degraus úmidos descem para a escuridão. Dizem que o Orc Chefe espera na câmara mais funda.",
			"options": [{"label": "Descer à cripta", "action": "descend"}, {"label": "Agora não", "action": ""}]
		}
	}


func _build_tavern_interaction_tree(show_services: bool) -> Dictionary:
	var tree: Dictionary = {}
	var rumor_texts := _get_local_tavern_rumors()
	var rumor_options: Array = []
	for index in mini(5, rumor_texts.size()):
		var node_id := "tavern_rumor_%d" % index
		tree[node_id] = {"text": rumor_texts[index], "options": [{"label": "Voltar", "next": "rumors" if show_services else "start"}]}
		rumor_options.append({"label": "Ouvir notícia %d" % (index + 1), "next": node_id})
	if rumor_options.is_empty():
		tree["rumors"] = {"text": "Nenhuma notícia recente chegou até aqui.", "options": [{"label": "Voltar", "next": "start"}]}
	else:
		rumor_options.append({"label": "Voltar", "next": "start"})
		tree["rumors"] = {"text": "Rumores que circulam pela região.", "options": rumor_options}
	var root_options: Array = []
	if show_services:
		root_options.append({"label": "Refeição quente · 8 ouro", "action": "tavern_meal"})
		root_options.append({"label": "Bebida local · 4 ouro", "action": "tavern_drink"})
		root_options.append({"label": "Pagar uma rodada · 12 ouro", "action": "tavern_round"})
		root_options.append({"label": "Rumores e notícias", "next": "rumors"})
		root_options.append({"label": "Sair", "action": ""})
		tree["start"] = {"text": "", "options": root_options}
	else:
		for rumor_option in rumor_options:
			if str(rumor_option.get("label", "")) != "Voltar":
				root_options.append(rumor_option.duplicate(true))
		root_options.append({"label": "Fechar", "action": ""})
		tree["start"] = {"text": "", "options": root_options}
	return tree


func _get_local_tavern_rumors() -> Array[String]:
	var result: Array[String] = []
	if overworld == null or not is_instance_valid(overworld):
		return result
	var active_building: Dictionary = overworld.get("_active_building_record")
	var city_id := str(active_building.get("city_id", ""))
	var seen: Dictionary = {}
	var events: Array[Dictionary] = []
	for npc in overworld.npcs:
		if not is_instance_valid(npc) or str(npc.get("city_id")) != city_id:
			continue
		var memories: Variant = npc.get("known_world_events")
		if not (memories is Array):
			continue
		for event_value in memories:
			if not (event_value is Dictionary):
				continue
			var event: Dictionary = event_value
			var event_id := str(event.get("id", ""))
			var event_city := str(event.get("city_id", ""))
			var kind := str(event.get("kind", ""))
			if event_id == "" or seen.has(event_id) or event_city != city_id:
				continue
			if kind not in ["monster_sighting", "monster_defeated", "quest_completed"]:
				continue
			seen[event_id] = true
			events.append(event.duplicate(true))
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0))
	)
	var creature_names := {"rat": "ratos gigantes", "goblin": "goblins", "bat": "morcegos", "skel": "esqueletos", "orc": "orcs"}
	for event in events:
		var kind := str(event.get("kind", ""))
		var detail := str(event.get("detail", ""))
		var place := str(event.get("place_name", ""))
		var where_text := " nas redondezas" if place == "" else " perto de %s" % place
		if kind == "monster_sighting":
			result.append("Avistaram %s%s." % [str(creature_names.get(detail, detail if detail != "" else "criaturas")), where_text])
		elif kind == "monster_defeated":
			result.append("Há notícia de um confronto com %s%s." % [str(creature_names.get(detail, detail if detail != "" else "uma criatura")), where_text])
		elif kind == "quest_completed":
			result.append("Dizem que o trabalho '%s' foi concluído%s." % [detail if detail != "" else "um trabalho", where_text])
		if result.size() >= 5:
			break
	return result


func _buy_tavern_meal() -> void:
	if player == null or not is_instance_valid(player):
		_resume()
		return
	var price: int = 8
	if int(player.get("gold")) < price:
		_resume()
		show_msg("Você não tem ouro suficiente para uma refeição.")
		return
	player.gold -= price
	var previous_hp := int(player.get("hp"))
	player.hp = mini(int(player.get("max_hp")), previous_hp + 25)
	player.mana = minf(float(player.get("max_mana")), float(player.get("mana")) + 10.0)
	var restored := int(player.get("hp")) - previous_hp
	_resume()
	show_msg("Você come uma refeição quente. Recuperou %d de vida e um pouco de mana." % restored)


func _buy_tavern_drink() -> void:
	if player == null or not is_instance_valid(player):
		_resume()
		return
	var price: int = 4
	if int(player.get("gold")) < price:
		_resume()
		show_msg("Você não tem ouro suficiente para uma bebida.")
		return
	player.gold -= price
	var rumors := _get_local_tavern_rumors()
	_resume()
	if rumors.is_empty():
		show_msg("Você compra uma bebida, mas ninguém traz notícias novas.")
	else:
		show_msg("Enquanto bebe, você escuta: %s" % rumors[randi_range(0, rumors.size() - 1)])


func _buy_tavern_round() -> void:
	if player == null or not is_instance_valid(player) or overworld == null:
		_resume()
		return
	var price: int = 12
	if int(player.get("gold")) < price:
		_resume()
		show_msg("Você não tem ouro suficiente para pagar uma rodada.")
		return
	var active_building: Dictionary = overworld.get("_active_building_record")
	var society: Variant = overworld.get("_npc_society")
	player.gold -= price
	var crowd := 0
	if society != null and is_instance_valid(society) and society.has_method("record_player_tavern_round"):
		crowd = int(society.call("record_player_tavern_round", str(active_building.get("city_id", "")), str(active_building.get("name", "taverna")), character_name if character_name != "" else "Aventureiro"))
	if crowd <= 0:
		player.gold += price
		_resume()
		show_msg("Não há ninguém no salão para acompanhar a rodada agora.")
		return
	_resume()
	show_msg("Você pagou uma rodada para %d pessoa(s)." % crowd)


func _show_flirt_response_dialogue(npc: Node, flirt_style: String, reaction: String) -> void:
	if not is_instance_valid(npc) or dialog == null or not is_instance_valid(dialog):
		show_msg(reaction)
		_resume()
		return
	var approach_line := "Gosto da sua companhia. A estrada fica melhor quando você está por perto."
	if flirt_style == "playful":
		approach_line = "Se continuar me olhando assim, vou achar que gosta de mim."
	var response_tree: Dictionary = {
		"start": {
			"speaker": "Você",
			"text": approach_line,
			"options": [{"label": "Ouvir resposta", "next": "reply"}]
		},
		"reply": {
			"speaker": _npc_interaction_speaker(npc),
			"text": reaction,
			"options": [{"label": "Encerrar conversa", "action": ""}]
		}
	}
	phase = "dialog"
	if is_instance_valid(overlay):
		overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialog.open(_npc_interaction_speaker(npc), response_tree)


func _on_dialog_line_shown(speaker_name: String, node_key: String, text: String) -> void:
	if not is_instance_valid(_talk_npc) or not _talk_npc.has_method("remember_spoken_dialogue"):
		return
	# A linha precisa pertencer ao NPC em conversa. Isso ignora a fala do jogador
	# durante o flerte e caixas de diálogo de estalagens/entradas/menus.
	if speaker_name != _npc_interaction_speaker(_talk_npc):
		return
	_talk_npc.call("remember_spoken_dialogue", text, "jogador:" + node_key)


func _on_dialog_closed(action: String) -> void:
	if action == "tavern_meal":
		_buy_tavern_meal()
	elif action == "tavern_drink":
		_buy_tavern_drink()
	elif action == "tavern_round":
		_buy_tavern_round()
	elif action == "descend":
		enter_dungeon()
	elif action == "witch_quest_accept":
		var witch_society: Variant = _talk_npc.get("society") if is_instance_valid(_talk_npc) else null
		if is_instance_valid(_talk_npc) and bool(_talk_npc.get("is_unique_witch")) and witch_society is Node and is_instance_valid(witch_society):
			if witch_society.has_method("get_witch_quest_status") and str(witch_society.call("get_witch_quest_status")) == "not_started":
				witch_society.call("set_witch_quest_status", "active")
				show_msg("A tarefa da bruxa começou: reúna 2 minérios de cobre e 3 ervas medicinais ou silvestres.")
			else:
				show_msg("A tarefa da bruxa já está registrada.")
		else:
			show_msg("Não foi possível registrar a tarefa da bruxa.")
		_resume()
	elif action == "witch_quest_turnin":
		_finish_witch_quest()
	elif action == "witch_ally":
		# Ações antigas de saves anteriores não podem contornar a missão de confiança.
		show_msg("A bruxa não faz alianças sem provas de confiança. Traga o cobre e as ervas que ela pediu.")
		_resume()
	elif action.begins_with("witch_tactic:"):
		_set_witch_companion_tactic(action.trim_prefix("witch_tactic:"))
		_resume()
	elif action == "npc_flirt" or action.begins_with("npc_flirt:"):
		var flirt_style := action.get_slice(":", 1) if action.contains(":") else "gentle"
		var flirt_result := "Não foi possível registrar essa aproximação."
		if is_instance_valid(_talk_npc):
			var relationship_society: Variant = _talk_npc.get("society")
			if relationship_society is Node and is_instance_valid(relationship_society) and relationship_society.has_method("record_player_flirt"):
				flirt_result = str(relationship_society.call("record_player_flirt", _talk_npc))
			_show_flirt_response_dialogue(_talk_npc, flirt_style, flirt_result)
		else:
			show_msg(flirt_result)
			_resume()
	elif action == "shop":
		open_shop(str(_talk_npc.role) if is_instance_valid(_talk_npc) else "")
	elif action.begins_with("quest_accept:"):
		var quest_id := action.trim_prefix("quest_accept:")
		show_msg(quest_manager.accept_quest(quest_id) if quest_manager != null else "O quadro de tarefas não está disponível.")
		_resume()
	elif action.begins_with("quest_turnin:"):
		var quest_id := action.trim_prefix("quest_turnin:")
		show_msg(quest_manager.turn_in_quest(quest_id) if quest_manager != null else "Não foi possível entregar o trabalho.")
		_resume()
	elif action.begins_with("resource_sell:"):
		show_msg(_sell_resource_to_talking_npc(action.trim_prefix("resource_sell:")))
		_resume()
	else:
		_resume()


func _finish_witch_quest() -> void:
	if not is_instance_valid(_talk_npc) or not bool(_talk_npc.get("is_unique_witch")) or player == null or not is_instance_valid(player):
		_resume()
		show_msg("A tarefa não pôde ser entregue agora.")
		return
	var witch_society: Variant = _talk_npc.get("society")
	if not (witch_society is Node) or not is_instance_valid(witch_society) or not witch_society.has_method("get_witch_quest_status"):
		_resume()
		show_msg("A tarefa da bruxa não está disponível.")
		return
	if str(witch_society.call("get_witch_quest_status")) != "active":
		_resume()
		show_msg("Você ainda não aceitou a tarefa da bruxa.")
		return
	var copper := int(player.call("resource_count", "copper_ore"))
	var herb_ids: Array[String] = ["healing_herb", "bitterleaf", "silverleaf"]
	var herb_total := 0
	for herb_id in herb_ids:
		herb_total += int(player.call("resource_count", herb_id))
	if copper < 2 or herb_total < 3:
		_resume()
		show_msg("Ainda faltam materiais: %d/2 minérios de cobre e %d/3 ervas." % [copper, herb_total])
		return
	if not bool(player.call("remove_resource", "copper_ore", 2)):
		_resume()
		show_msg("Não foi possível retirar os minérios do inventário.")
		return
	var herbs_to_remove := 3
	for herb_id in herb_ids:
		if herbs_to_remove <= 0:
			break
		var available := int(player.call("resource_count", herb_id))
		var taken := mini(available, herbs_to_remove)
		if taken > 0:
			player.call("remove_resource", herb_id, taken)
			herbs_to_remove -= taken
	if herbs_to_remove > 0:
		# Salvaguarda contra inventário alterado entre a conferência e a entrega.
		player.call("add_resource", "copper_ore", 2)
		_resume()
		show_msg("A entrega falhou; os minérios foram devolvidos ao inventário.")
		return
	witch_society.call("set_witch_quest_status", "completed")
	witch_society.call("set_witch_state", "allied")
	_talk_npc.set("witch_state", "allied")
	_talk_npc.set("life_enabled", true)
	_talk_npc.set("is_at_home", false)
	_talk_npc.set("visible", true)
	_talk_npc.set("collision_layer", 2)
	_talk_npc.set("collision_mask", 1)
	_talk_npc.set_physics_process(true)
	_talk_npc.remove_from_group("enemies")
	var relation_value: Variant = _talk_npc.get("player_relationship")
	var relation: Dictionary = relation_value.duplicate(true) if relation_value is Dictionary else {}
	relation["familiarity"] = clampf(float(relation.get("familiarity", 0.0)) + 18.0, 0.0, 100.0)
	relation["trust"] = clampf(float(relation.get("trust", 0.0)) + 35.0, -100.0, 100.0)
	relation["affection"] = clampf(float(relation.get("affection", 0.0)) + 15.0, 0.0, 100.0)
	relation["stage"] = "friend"
	_talk_npc.set("player_relationship", relation)
	_witch_companion = _talk_npc as Node3D
	_witch_companion_follow_timer = 0.0
	_witch_companion_attack_timer = 1.3
	_witch_companion_heal_timer = 6.0
	_resume()
	show_msg("A bruxa aceita os materiais. Depois de um longo silêncio, ela guarda as ervas e faz sinal para que você a acompanhe.")


func _set_witch_companion_tactic(tactic: String) -> void:
	var allowed_tactics: Array[String] = ["adaptive", "aggressive", "defensive", "hold", "follow"]
	if not allowed_tactics.has(tactic):
		show_msg("Essa estratégia não é reconhecida.")
		return
	if not is_instance_valid(_witch_companion) and _talk_npc is Node3D and is_instance_valid(_talk_npc) and bool(_talk_npc.get("is_unique_witch")) and str(_talk_npc.get("witch_state")) == "allied":
		_witch_companion = _talk_npc as Node3D
	_witch_companion_tactic = tactic
	_witch_companion_follow_timer = 0.0
	if is_instance_valid(_witch_companion) and tactic == "hold":
		_witch_stop_companion_motion()
	var feedback: String = "A bruxa avaliará as ameaças e escolherá posições por conta própria."
	match tactic:
		"aggressive": feedback = "A bruxa adotará uma postura ofensiva, pressionando inimigos que consiga perceber e mantendo distância mínima para conjurar."
		"defensive": feedback = "A bruxa priorizará ameaças próximas de você, manterá mais espaço e usará a cura mais cedo."
		"hold": feedback = "A bruxa manterá a posição e lançará magias contra ameaças que consiga ver dentro do alcance."
		"follow": feedback = "A bruxa voltará a acompanhá-lo fora de combate; quando houver ameaça, ainda escolherá uma posição para conjurar."
		_: feedback = "A bruxa avaliará a situação e alternará entre apoio, recuo e aproximação conforme a ameaça."
	show_msg(feedback)


func _update_witch_companion(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not is_instance_valid(_witch_companion):
		_witch_companion = null
		if overworld != null and is_instance_valid(overworld):
			var npcs_value: Variant = overworld.get("npcs")
			if npcs_value is Array:
				for npc_value in npcs_value:
					if npc_value is Node3D and is_instance_valid(npc_value) and bool(npc_value.get("is_unique_witch")) and str(npc_value.get("witch_state")) == "allied":
						_witch_companion = npc_value
						break
	if not is_instance_valid(_witch_companion):
		return
	if str(_witch_companion.get("witch_state")) != "allied":
		return
	# Mantém a entidade viva entre o mundo exterior e as criptas.
	if overworld == null:
		if _witch_companion.get_parent() != self:
			_witch_companion.reparent(self, true)
	else:
		if _witch_companion.get_parent() != overworld:
			_witch_companion.reparent(overworld, true)
	var player_mounted: bool = bool(player.get("is_mounted"))
	_witch_companion.visible = not player_mounted
	_witch_companion.life_enabled = true
	_witch_companion.is_at_home = false
	_witch_companion.set_physics_process(true)
	_witch_companion.process_mode = Node.PROCESS_MODE_PAUSABLE
	var player_horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	_witch_companion.companion_move_speed = clampf(maxf(4.1, player_horizontal_speed * 1.16), 4.1, 7.6)

	# Ao montar, ela continua usando o comportamento já existente de acompanhar
	# o cavalo sem aparecer sobre a tela. A percepção e as magias ainda funcionam.
	if player_mounted:
		_witch_companion.collision_layer = 0
		_witch_companion.collision_mask = 0
		var mounted_behind: Vector3 = player.global_transform.basis.z
		mounted_behind.y = 0.0
		if mounted_behind.length_squared() < 0.001:
			mounted_behind = Vector3.BACK
		var mounted_target: Vector3 = player.global_position + mounted_behind.normalized() * 1.45
		if overworld != null and is_instance_valid(overworld) and overworld.has_method("_ground"):
			var mounted_ground: Variant = overworld.call("_ground", mounted_target)
			if mounted_ground is Vector3:
				mounted_target = mounted_ground
			mounted_target.y += 0.08
		else:
			mounted_target.y = player.global_position.y
		_witch_companion.global_position = mounted_target
		_witch_companion.has_target = false
		_witch_companion.velocity = Vector3.ZERO
	else:
		_witch_companion.collision_layer = 2
		_witch_companion.collision_mask = 1
		_witch_companion_follow_timer -= delta
		if _witch_companion_follow_timer <= 0.0:
			_witch_companion_follow_timer = 0.32
			var perception_range: float = 18.0
			match _witch_companion_tactic:
				"aggressive": perception_range = 22.0
				"defensive": perception_range = 17.0
				"hold": perception_range = 13.0
				"follow": perception_range = 18.0
				_: perception_range = 19.0
			_witch_cached_threat = _witch_choose_visible_enemy(perception_range)
			if is_instance_valid(_witch_cached_threat):
				# Durante o combate, a bruxa escolhe uma posição útil em relação ao
				# inimigo e ao jogador. Ela deixa de perseguir a posição do jogador.
				_witch_update_tactical_position(_witch_cached_threat)
			elif _witch_companion_tactic == "hold":
				_witch_stop_companion_motion()
			else:
				_update_witch_follow_position(player_horizontal_speed)

	# A bruxa só tenta atacar inimigos vivos que consegue perceber; a prioridade
	# leva em conta distância, ameaça ao jogador e a postura escolhida.
	_witch_companion_attack_timer -= delta
	if _witch_companion_attack_timer <= 0.0:
		var attack_range: float = 16.0
		match _witch_companion_tactic:
			"aggressive": attack_range = 22.0
			"defensive": attack_range = 15.0
			"hold": attack_range = 13.0
			"follow": attack_range = 17.0
			_: attack_range = 18.0
		var chosen_enemy: Node3D = _witch_choose_visible_enemy(attack_range)
		if is_instance_valid(chosen_enemy):
			_witch_companion_attack_timer = 1.85 if _witch_companion_tactic == "aggressive" else 2.9 if _witch_companion_tactic == "defensive" else 2.45
			_witch_companion_spell_counter = posmod(_witch_companion_spell_counter + 1, 2)
			var spell_damage: int
			var spell_kind := "mist_spear"
			if _witch_companion_spell_counter == 1:
				spell_damage = randi_range(8, 13)
				spell_kind = "ebony_shards"
			else:
				spell_damage = randi_range(13, 18)
			var push_direction: Vector3 = (chosen_enemy.global_position - _witch_companion.global_position).normalized()
			chosen_enemy.call("take_hit", spell_damage, push_direction)
			_spawn_witch_spell_effect(_witch_companion.global_position + Vector3.UP * 1.15, chosen_enemy.global_position + Vector3.UP * 0.8, spell_kind)
			if spell_kind == "ebony_shards":
				for nearby_value in get_tree().get_nodes_in_group("enemies"):
					if not (nearby_value is Node3D) or not is_instance_valid(nearby_value) or nearby_value == chosen_enemy or nearby_value == _witch_companion:
						continue
					var nearby_enemy: Node3D = nearby_value as Node3D
					if not nearby_enemy.has_method("take_hit") or not nearby_enemy.visible:
						continue
					if nearby_enemy.global_position.distance_to(chosen_enemy.global_position) > 3.2 or not _witch_has_clear_sight(nearby_enemy):
						continue
					var shard_direction: Vector3 = (nearby_enemy.global_position - _witch_companion.global_position).normalized()
					nearby_enemy.call("take_hit", maxi(3, int(spell_damage / 2)), shard_direction)
					_spawn_witch_spell_effect(_witch_companion.global_position + Vector3.UP * 1.05, nearby_enemy.global_position + Vector3.UP * 0.8, "ebony_shards")
		else:
			# Sem alvo visível, não queima a magia em inimigos fora de alcance.
			_witch_companion_attack_timer = 0.55

	# A postura defensiva guarda a cura para um limiar mais alto; a agressiva
	# assume mais risco e conserva recursos enquanto o jogador ainda resiste.
	_witch_companion_heal_timer -= delta
	var player_hp: float = float(player.get("hp"))
	var player_max_hp: float = maxf(1.0, float(player.get("max_hp")))
	var heal_threshold: float = 0.62
	if _witch_companion_tactic == "defensive":
		heal_threshold = 0.76
	elif _witch_companion_tactic == "aggressive":
		heal_threshold = 0.52
	if _witch_companion_heal_timer <= 0.0 and player_hp <= player_max_hp * heal_threshold:
		var healed: int = mini(24, int(player_max_hp - player_hp))
		if healed > 0:
			player.hp = mini(int(player_max_hp), int(player_hp) + healed)
			_witch_companion_heal_timer = 15.0 if _witch_companion_tactic == "defensive" else 19.0
			_spawn_witch_spell_effect(_witch_companion.global_position + Vector3.UP * 1.1, player.global_position + Vector3.UP * 0.7, "healing_mist")
			show_msg("A bruxa envolve você em bruma restauradora. +%d de vida." % healed)
	elif _witch_companion_heal_timer <= 0.0:
		_witch_companion_heal_timer = 2.0


func _witch_choose_visible_enemy(max_range: float) -> Node3D:
	if not is_instance_valid(_witch_companion):
		return null
	var best_enemy: Node3D = null
	var best_score: float = INF
	for enemy_value in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_value is Node3D) or not is_instance_valid(enemy_value) or enemy_value == _witch_companion:
			continue
		var enemy: Node3D = enemy_value as Node3D
		if not enemy.visible or not enemy.has_method("take_hit"):
			continue
		var hp_value: Variant = enemy.get("hp")
		if hp_value != null and int(hp_value) <= 0:
			continue
		var vertical_difference: float = absf(enemy.global_position.y - _witch_companion.global_position.y)
		if vertical_difference > 5.5:
			continue
		var witch_distance: float = Vector2(enemy.global_position.x - _witch_companion.global_position.x, enemy.global_position.z - _witch_companion.global_position.z).length()
		var player_distance: float = Vector2(enemy.global_position.x - player.global_position.x, enemy.global_position.z - player.global_position.z).length()
		if witch_distance > max_range or (witch_distance > 13.0 and player_distance > 17.0):
			continue
		if not _witch_has_clear_sight(enemy):
			continue
		var score: float = witch_distance + player_distance * 0.14
		var enemy_target: Variant = enemy.get("_target")
		if enemy_target == player:
			score -= 3.8
		if bool(enemy.get("is_boss")):
			score -= 1.25
		if _witch_companion_tactic == "defensive":
			score -= maxf(0.0, 10.5 - player_distance) * 0.8
		elif _witch_companion_tactic == "aggressive":
			score -= maxf(0.0, 12.0 - witch_distance) * 0.18
		elif _witch_companion_tactic == "hold" and player_distance > 10.0:
			score += 4.0
		if score < best_score:
			best_score = score
			best_enemy = enemy
	return best_enemy


func _witch_has_clear_sight(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(_witch_companion):
		return false
	var world: World3D = _witch_companion.get_world_3d()
	if world == null:
		return true
	var ray_from: Vector3 = _witch_companion.global_position + Vector3.UP * 1.1
	var ray_to: Vector3 = enemy.global_position + Vector3.UP * 0.9
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	var excluded: Array[RID] = [_witch_companion.get_rid()]
	if is_instance_valid(player):
		excluded.append(player.get_rid())
	query.exclude = excluded
	query.collide_with_areas = false
	var sight_hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if sight_hit.is_empty():
		return true
	return sight_hit.get("collider") == enemy


func _witch_update_tactical_position(enemy: Node3D) -> void:
	if not is_instance_valid(_witch_companion) or not is_instance_valid(enemy):
		return
	if _witch_companion_tactic == "hold":
		_witch_stop_companion_motion()
		return
	var to_enemy: Vector3 = enemy.global_position - _witch_companion.global_position
	to_enemy.y = 0.0
	var enemy_distance: float = to_enemy.length()
	var desired_distance: float = 7.0
	match _witch_companion_tactic:
		"aggressive": desired_distance = 4.8
		"defensive": desired_distance = 8.5
		"follow": desired_distance = 6.0
		_: desired_distance = 7.0

	var destination: Vector3 = _witch_companion.global_position
	var should_move: bool = false
	var player_distance: float = Vector2(player.global_position.x - _witch_companion.global_position.x, player.global_position.z - _witch_companion.global_position.z).length()
	if _witch_companion_tactic != "aggressive" and player_distance > 12.0:
		# Se ficou muito distante do jogador, reposiciona-se para apoiá-lo pelo lado
		# oposto à ameaça, sem correr até ocupar o mesmo espaço que ele.
		var player_to_enemy: Vector3 = enemy.global_position - player.global_position
		player_to_enemy.y = 0.0
		if player_to_enemy.length_squared() < 0.001:
			player_to_enemy = Vector3.FORWARD
		player_to_enemy = player_to_enemy.normalized()
		var flank: Vector3 = Vector3(-player_to_enemy.z, 0.0, player_to_enemy.x) * _witch_flank_sign()
		destination = player.global_position - player_to_enemy * 2.0 + flank * 3.5
		should_move = true
	elif enemy_distance < desired_distance - 1.15:
		# Recuo de conjuradora: ganha espaço antes de tentar outra magia.
		var away: Vector3 = -to_enemy.normalized() if enemy_distance > 0.05 else Vector3.BACK
		destination = _witch_companion.global_position + away * minf(5.5, desired_distance - enemy_distance + 1.8)
		should_move = true
	elif enemy_distance > desired_distance + 2.2:
		# Aproxima apenas o necessário e busca um pequeno ângulo lateral para não
		# ficar alinhada com o jogador e o inimigo como se fosse um trem.
		var away_from_enemy: Vector3 = -to_enemy.normalized() if enemy_distance > 0.05 else Vector3.BACK
		var side: Vector3 = Vector3(-away_from_enemy.z, 0.0, away_from_enemy.x) * _witch_flank_sign()
		var flank_distance: float = 2.1 if _witch_companion_tactic == "adaptive" else 1.0
		destination = enemy.global_position + away_from_enemy * desired_distance + side * flank_distance
		should_move = true

	if not should_move:
		_witch_stop_companion_motion()
		return
	_witch_move_companion_to(destination)


func _witch_flank_sign() -> float:
	if not is_instance_valid(_witch_companion):
		return 1.0
	var id_value: Variant = _witch_companion.get("npc_id")
	var identifier: String = str(id_value)
	return -1.0 if abs(identifier.hash()) % 2 == 0 else 1.0


func _witch_move_companion_to(destination: Vector3) -> void:
	if not is_instance_valid(_witch_companion):
		return
	var target: Vector3 = destination
	if overworld != null and is_instance_valid(overworld) and overworld.has_method("_ground"):
		var grounded_target: Variant = overworld.call("_ground", target)
		if grounded_target is Vector3:
			target = grounded_target
		target.y += 0.08
	else:
		target.y = _witch_companion.global_position.y
	var target_distance: float = Vector2(target.x - _witch_companion.global_position.x, target.z - _witch_companion.global_position.z).length()
	if target_distance < 1.2:
		_witch_stop_companion_motion()
		return
	if bool(_witch_companion.get("has_target")) and str(_witch_companion.get("target_kind")) == "witch_companion":
		var previous_target: Variant = _witch_companion.get("target_position")
		if previous_target is Vector3 and Vector2((previous_target as Vector3).x - target.x, (previous_target as Vector3).z - target.z).length() < 1.45:
			return
	_witch_companion.call("go_to_route", target, "witch_companion", [target])


func _witch_stop_companion_motion() -> void:
	if not is_instance_valid(_witch_companion):
		return
	_witch_companion.has_target = false
	_witch_companion.velocity.x = 0.0
	_witch_companion.velocity.z = 0.0


func _update_witch_follow_position(player_speed: float) -> void:
	if not is_instance_valid(_witch_companion) or not is_instance_valid(player):
		return
	var companion_from_player: Vector3 = Vector3(
		_witch_companion.global_position.x - player.global_position.x,
		0.0,
		_witch_companion.global_position.z - player.global_position.z
	)
	var player_distance: float = companion_from_player.length()
	if player_speed < 0.35 and player_distance >= 2.75:
		# Quando o jogador para, a bruxa não acompanha as rotações da câmera.
		_witch_stop_companion_motion()
		return
	var behind: Vector3 = player.global_transform.basis.z
	behind.y = 0.0
	if behind.length_squared() < 0.001:
		behind = Vector3.BACK
	var target: Vector3
	if player_speed < 0.35:
		var away: Vector3 = companion_from_player
		if away.length_squared() < 0.001:
			away = behind
		target = player.global_position + away.normalized() * 3.4
	else:
		target = player.global_position + behind.normalized() * 3.4
	_witch_move_companion_to(target)

func _spawn_witch_spell_effect(origin: Vector3, destination: Vector3, spell_kind: String = "mist_spear") -> void:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09 if spell_kind == "ebony_shards" else 0.16 if spell_kind == "healing_mist" else 0.14
	sphere.height = sphere.radius * 2.0
	effect.mesh = sphere
	var spell_color := Color(0.66, 0.35, 0.92, 0.94)
	if spell_kind == "ebony_shards":
		spell_color = Color(0.30, 0.13, 0.48, 0.96)
	elif spell_kind == "healing_mist":
		spell_color = Color(0.36, 0.92, 0.73, 0.9)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = spell_color
	material.emission_enabled = true
	material.emission = spell_color
	effect.material_override = material
	effect.scale = Vector3(0.7, 1.2, 1.9) if spell_kind == "ebony_shards" else Vector3.ONE * 0.7
	add_child(effect)
	effect.global_position = origin
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "global_position", destination, 0.24)
	tween.tween_property(effect, "scale", Vector3.ONE * 1.3, 0.24)
	tween.tween_property(effect, "transparency", 1.0, 0.24)
	tween.chain().tween_callback(effect.queue_free)


func handle_dialog_key(keycode: int) -> bool:
	return dialog.handle_key(keycode)


func _add_resource_trade_options(npc: Node, source_tree: Dictionary) -> Dictionary:
	var tree: Dictionary = source_tree.duplicate(true)
	if player == null or not is_instance_valid(player) or npc == null or not is_instance_valid(npc):
		return tree
	var buyer_role: String = str(npc.get("role"))
	if buyer_role not in ["ferreiro", "curandeira", "mercador"]:
		return tree
	if buyer_role == "mercador" and npc.has_method("can_trade"):
		if not bool(npc.call("can_trade", _build_npc_dialogue_context(npc))):
			return tree
	var resource_ids: Array = player.resources.keys()
	resource_ids.sort()
	var sell_options: Array = []
	for resource_key in resource_ids:
		var resource_id: String = str(resource_key)
		var total_amount: int = player.resource_count(resource_id)
		var reserved_amount: int = _reserved_resource_count(resource_id)
		var sellable_amount: int = maxi(0, total_amount - reserved_amount)
		var unit_price: int = RESOURCE_CATALOG.sell_price(resource_id, buyer_role)
		if sellable_amount <= 0 or unit_price <= 0:
			continue
		var total_price: int = sellable_amount * unit_price
		sell_options.append({
			"label": "Vender %d × %s · %d ouro" % [sellable_amount, RESOURCE_CATALOG.display_name(resource_id), total_price],
			"action": "resource_sell:%s" % resource_id
		})
	if sell_options.is_empty():
		return tree
	sell_options.append({"label": "Voltar", "next": "start"})
	tree["sell_resources"] = {
		"text": "Posso comprar estes materiais. Os que já estão comprometidos com um trabalho ficam reservados.",
		"options": sell_options
	}
	var start_node: Dictionary = tree.get("start", {})
	var options: Array = start_node.get("options", [])
	options.append({"label": "Vender recursos", "next": "sell_resources"})
	start_node["options"] = options
	tree["start"] = start_node
	return tree


func _reserved_resource_count(resource_id: String) -> int:
	if quest_manager != null and is_instance_valid(quest_manager) and quest_manager.has_method("get_reserved_resource_amount"):
		return int(quest_manager.call("get_reserved_resource_amount", resource_id))
	return 0


func _sell_resource_to_talking_npc(resource_id: String) -> String:
	if player == null or not is_instance_valid(player) or not is_instance_valid(_talk_npc):
		return "Não há ninguém para negociar agora."
	if str(_talk_npc.get("role")) == "mercador" and _talk_npc.has_method("can_trade") and not bool(_talk_npc.call("can_trade", _build_npc_dialogue_context(_talk_npc))):
		return "Este comerciante só atende na loja durante o expediente." if str(_talk_npc.get("merchant_type")) == "resident" else "O mercador não está disponível para negociar agora."
	var buyer_role: String = str(_talk_npc.get("role"))
	var unit_price: int = RESOURCE_CATALOG.sell_price(resource_id, buyer_role)
	var amount: int = maxi(0, player.resource_count(resource_id) - _reserved_resource_count(resource_id))
	if amount <= 0 or unit_price <= 0:
		return "Não tenho material disponível para vender a essa pessoa."
	if not player.remove_resource(resource_id, amount):
		return "Não consegui separar esse material do inventário."
	var earnings: int = amount * unit_price
	player.add_gold(earnings)
	return "Vendi %d × %s por %d ouro." % [amount, RESOURCE_CATALOG.display_name(resource_id), earnings]


# ---------- Loja ----------

func open_shop(role: String) -> void:
	if not SHOP_ROLES.has(role):
		_resume()
		return
	if role == "mercador" and is_instance_valid(_talk_npc) and _talk_npc.has_method("can_trade"):
		if not bool(_talk_npc.call("can_trade", _build_npc_dialogue_context(_talk_npc))):
			_resume()
			show_msg("Este comerciante não está atendendo aqui agora.")
			return
	phase = "shop"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shop.open(self, role, str(SHOP_ROLES[role]["title"]))


func _on_shop_closed() -> void:
	_resume()


func handle_shop_key(keycode: int) -> bool:
	return shop.handle_key(keycode)


func open_quest_log() -> void:
	if phase != "play" or quest_manager == null or quest_journal == null:
		return
	phase = "quest_log"
	overlay.visible = false
	if inventory_screen != null:
		inventory_screen.visible = false
	quest_journal.call("open")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_quest_log() -> void:
	if phase == "quest_log":
		if quest_journal != null:
			quest_journal.visible = false
		_resume()


func _db_find(db: Array, id: String) -> Dictionary:
	for it in db:
		if it["id"] == id:
			return it
	return {}


func shop_rows(role: String) -> Array:
	# Uma linha por item à venda: texto, preço, se já tem e se dá para pagar
	var rows: Array = []
	for entry in SHOP_ROLES[role]["stock"]:
		var label := ""
		var owned := false
		match entry["kind"]:
			"weapon":
				var w: Dictionary = _db_find(WEAPON_DB, entry["id"])
				label = "%s · dano %d a %d" % [w["name"], w["dmg_min"], w["dmg_max"]]
				for x in player.weapons:
					if x["id"] == entry["id"]:
						owned = true
			"armor":
				var a: Dictionary = _db_find(ARMOR_DB, entry["id"])
				label = "%s · defesa %d" % [a["name"], a["def"]]
				for x in player.armors:
					if x["id"] == entry["id"]:
						owned = true
			"scroll":
				var sp: Dictionary = _db_find(SPELL_DB, entry["id"])
				label = "Pergaminho: %s · custo %d mana" % [sp["name"], sp["cost"]]
				for x in player.spells:
					if x["id"] == entry["id"]:
						owned = true
			_:
				label = "Poção de Cura · você tem %d" % player.potions
		rows.append({"label": label, "price": int(entry["price"]), "owned": owned, "can": player.gold >= int(entry["price"])})
	return rows


func shop_buy(role: String, index: int) -> String:
	var stock: Array = SHOP_ROLES[role]["stock"]
	if index < 0 or index >= stock.size():
		return ""
	var entry: Dictionary = stock[index]
	var row: Dictionary = shop_rows(role)[index]
	if row["owned"]:
		return "Você já tem isso."
	if player.gold < int(entry["price"]):
		return "Ouro insuficiente."
	player.gold -= int(entry["price"])
	match entry["kind"]:
		"weapon":
			player.add_weapon(_db_find(WEAPON_DB, entry["id"]))
			if str(entry["id"]) == "sword":
				player.equip_weapon(player.weapons.size() - 1)
				return "Espada Curta comprada e equipada! Teste o sprite com o botão de ataque."
		"armor":
			player.add_armor(_db_find(ARMOR_DB, entry["id"]))
		"scroll":
			player.learn_spell(entry["id"])
		_:
			player.add_potion()
	return "Comprado por %d de ouro." % int(entry["price"])


func open_map() -> void:
	if phase != "play" or overworld == null:
		return
	phase = "map"
	world_map.visible = true
	if world_map.has_method("focus_player_city"):
		world_map.call("focus_player_city")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_map() -> void:
	world_map.visible = false
	_resume()


# ---------- Geração da cripta ----------

func _build_dungeon() -> void:
	if dungeon_root:
		dungeon_root.free()
	dungeon_root = Node3D.new()
	dungeon_root.name = "Dungeon"
	add_child(dungeon_root)
	pickups.clear()
	rng.seed = run_seed
	_generate_dungeon()
	_build_geometry()
	_build_lights()
	_spawn_enemies()
	_spawn_items()
	player.global_position = _room_center_world(0) + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO


func _generate_dungeon() -> void:
	# Tenta primeiro com relevo (rampas); se não der certo depois de muitas tentativas, usa um mapa plano.
	for attempt in 400:
		if _try_layout(attempt > 200):
			return
	push_error("Não consegui gerar a cripta.")


func _try_layout(flat: bool) -> bool:
	grid.resize(GRID * GRID)
	grid.fill(1)
	heights.resize(GRID * GRID)
	heights.fill(0.0)
	rooms.clear()
	edges.clear()

	# Salas de tamanhos variados, sem encostar umas nas outras
	var tries := 0
	while rooms.size() < ROOM_TARGET and tries < 600:
		tries += 1
		var big := rng.randf() < 0.22
		var w := rng.randi_range(9, 12) if big else rng.randi_range(4, 7)
		var h := rng.randi_range(9, 11) if big else rng.randi_range(4, 7)
		var r := Rect2i(rng.randi_range(2, GRID - w - 2), rng.randi_range(2, GRID - h - 2), w, h)
		var clash := false
		for o in rooms:
			if r.grow(2).intersects(o["rect"]):
				clash = true
				break
		if not clash:
			rooms.append({"rect": r, "level": 0, "depth": 0, "boss": false})
	if rooms.size() < 8:
		return false
	for room in rooms:
		_carve_rect(room["rect"])

	var n := rooms.size()
	# Árvore mínima ligando todas as salas: tudo fica alcançável
	var in_tree: Array = [0]
	while in_tree.size() < n:
		var best_d := INF
		var best := Vector2i(-1, -1)
		for a in in_tree:
			for b in n:
				if in_tree.has(b):
					continue
				var d := _room_center(a).distance_to(_room_center(b))
				if d < best_d:
					best_d = d
					best = Vector2i(a, b)
		in_tree.append(best.y)
		edges.append(best)
	# Alguns laços extras para o mapa não virar uma árvore pura
	for i in n:
		for j in range(i + 1, n):
			if _room_center(i).distance_to(_room_center(j)) < 16.0 and not _is_edge(i, j) and rng.randf() < 0.3:
				edges.append(Vector2i(i, j))

	# Corredores em L entre as salas ligadas
	var paths: Array = []
	for k in edges.size():
		var e: Vector2i = edges[k]
		var ca: Vector2i = rooms[e.x]["rect"].get_center()
		var cb: Vector2i = rooms[e.y]["rect"].get_center()
		var path := _l_path(ca, cb, rng.randf() < 0.5)
		for c in path:
			_set_floor(c.x, c.y)
		paths.append(path)

	# Profundidade a partir da entrada (sala 0) e nível de cada sala
	var adj: Array = []
	for i in n:
		adj.append([])
	for e in edges:
		adj[e.x].append(e.y)
		adj[e.y].append(e.x)
	var depth := PackedInt32Array()
	depth.resize(n)
	depth.fill(-1)
	depth[0] = 0
	var queue: Array = [0]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in adj[cur]:
			if depth[nb] != -1:
				continue
			depth[nb] = depth[cur] + 1
			rooms[nb]["depth"] = depth[nb]
			rooms[nb]["level"] = 0 if flat else clampi(int(rooms[cur]["level"]) + rng.randi_range(-1, 1), -1, 2)
			queue.append(nb)

	# Câmara do chefe: a sala mais distante da entrada
	var boss := 0
	for i in n:
		if depth[i] > depth[boss]:
			boss = i
	if depth[boss] < 3:
		return false
	rooms[boss]["boss"] = true

	# Alturas: salas ficam no seu nível; corredores fazem rampa suave entre níveis diferentes
	var assigned := PackedByteArray()
	assigned.resize(GRID * GRID)
	assigned.fill(0)
	for room in rooms:
		var r: Rect2i = room["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				heights[y * GRID + x] = float(room["level"]) * STEP_H
				assigned[y * GRID + x] = 1
	for k in edges.size():
		var e: Vector2i = edges[k]
		var path: Array = paths[k]
		var la := float(rooms[e.x]["level"])
		var lb := float(rooms[e.y]["level"])
		var m := path.size()
		for i in m:
			var c: Vector2i = path[i]
			var idx := c.y * GRID + c.x
			if assigned[idx] == 1:
				continue
			var t := float(i) / float(m - 1)
			heights[idx] = lerpf(la, lb, t) * STEP_H
			assigned[idx] = 1

	# Validação: nenhum degrau alto demais entre células vizinhas (senão o jogador não sobe)
	for y in GRID:
		for x in GRID:
			if not _is_floor(x, y):
				continue
			if _is_floor(x + 1, y) and absf(_h(x + 1, y) - _h(x, y)) > MAX_CELL_DELTA:
				return false
			if _is_floor(x, y + 1) and absf(_h(x, y + 1) - _h(x, y)) > MAX_CELL_DELTA:
				return false
	return true


func _is_edge(i: int, j: int) -> bool:
	for e in edges:
		if (e.x == i and e.y == j) or (e.x == j and e.y == i):
			return true
	return false


func _l_path(a: Vector2i, b: Vector2i, horizontal_first: bool) -> Array:
	var path: Array = []
	var cur := a
	path.append(cur)
	if horizontal_first:
		while cur.x != b.x:
			cur.x += signi(b.x - cur.x)
			path.append(cur)
		while cur.y != b.y:
			cur.y += signi(b.y - cur.y)
			path.append(cur)
	else:
		while cur.y != b.y:
			cur.y += signi(b.y - cur.y)
			path.append(cur)
		while cur.x != b.x:
			cur.x += signi(b.x - cur.x)
			path.append(cur)
	return path


func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_set_floor(x, y)


func _set_floor(x: int, y: int) -> void:
	if x >= 0 and x < GRID and y >= 0 and y < GRID:
		grid[y * GRID + x] = 0


func _is_floor(x: int, y: int) -> bool:
	if x < 0 or x >= GRID or y < 0 or y >= GRID:
		return false
	return grid[y * GRID + x] == 0


func _h(x: int, y: int) -> float:
	return heights[y * GRID + x]


func _room_center(i: int) -> Vector2:
	return Vector2(rooms[i]["rect"].get_center())


func _room_center_world(i: int) -> Vector3:
	var c: Vector2i = rooms[i]["rect"].get_center()
	return _cell_world(c.x, c.y, 0.0)


func _cell_world(x: int, y: int, lift: float) -> Vector3:
	return Vector3((x + 0.5) * CELL, _h(x, y) + lift, (y + 0.5) * CELL)


func _random_cell_in(i: int) -> Vector2i:
	var r: Rect2i = rooms[i]["rect"]
	return r.position + Vector2i(rng.randi_range(0, r.size.x - 1), rng.randi_range(0, r.size.y - 1))


# ---------- Geometria ----------

func _build_geometry() -> void:
	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	floor_st.set_material(floor_mat)
	for y in GRID:
		for x in GRID:
			if not _is_floor(x, y):
				continue
			var x0 := x * CELL
			var x1 := (x + 1) * CELL
			var z0 := y * CELL
			var z1 := (y + 1) * CELL
			var a := Vector3(x0, _corner_h(x, y), z0)
			var b := Vector3(x0, _corner_h(x, y + 1), z1)
			var c := Vector3(x1, _corner_h(x + 1, y + 1), z1)
			var d := Vector3(x1, _corner_h(x + 1, y), z0)
			_tri(floor_st, a, b, c)
			_tri(floor_st, a, c, d)
	_add_collider("Floor", floor_st.commit())

	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	wall_st.set_material(wall_mat)
	for y in GRID:
		for x in GRID:
			if _is_floor(x, y) or not _touches_floor(x, y):
				continue
			var x0 := x * CELL
			var x1 := (x + 1) * CELL
			var z0 := y * CELL
			var z1 := (y + 1) * CELL
			var yb := WALL_BOTTOM
			var yt := WALL_TOP
			_quad(wall_st, Vector3(x0, yt, z0), Vector3(x0, yt, z1), Vector3(x1, yt, z1), Vector3(x1, yt, z0), Vector3.UP)
			if _is_floor(x + 1, y):
				_quad(wall_st, Vector3(x1, yb, z0), Vector3(x1, yb, z1), Vector3(x1, yt, z1), Vector3(x1, yt, z0), Vector3.RIGHT)
			if _is_floor(x - 1, y):
				_quad(wall_st, Vector3(x0, yb, z1), Vector3(x0, yb, z0), Vector3(x0, yt, z0), Vector3(x0, yt, z1), Vector3.LEFT)
			if _is_floor(x, y + 1):
				_quad(wall_st, Vector3(x1, yb, z1), Vector3(x0, yb, z1), Vector3(x0, yt, z1), Vector3(x1, yt, z1), Vector3.BACK)
			if _is_floor(x, y - 1):
				_quad(wall_st, Vector3(x0, yb, z0), Vector3(x1, yb, z0), Vector3(x1, yt, z0), Vector3(x0, yt, z0), Vector3.FORWARD)
	_add_collider("Walls", wall_st.commit())


func _touches_floor(x: int, y: int) -> bool:
	return _is_floor(x + 1, y) or _is_floor(x - 1, y) or _is_floor(x, y + 1) or _is_floor(x, y - 1)


func _corner_h(cx: int, cy: int) -> float:
	# Altura de um canto da malha: média das células de chão encostadas nele
	var total := 0.0
	var count := 0
	for dy in [-1, 0]:
		for dx in [-1, 0]:
			var x: int = cx + dx
			var y: int = cy + dy
			if _is_floor(x, y):
				total += _h(x, y)
				count += 1
	return total / float(count) if count > 0 else 0.0


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x, p.z) * 0.25)
		st.add_vertex(p)


func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	# Desenha um retângulo com a frente virada para n (ordem de vértices corrigida se preciso)
	var pts := [p0, p1, p2, p3]
	if (p1 - p0).cross(p2 - p0).dot(n) < 0.0:
		pts = [p0, p3, p2, p1]
	for idx in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = pts[idx]
		st.set_normal(n)
		var uv := Vector2(p.x + p.z, p.y) * 0.5
		if absf(n.y) > 0.5:
			uv = Vector2(p.x, p.z) * 0.5
		st.set_uv(uv)
		st.add_vertex(p)


func _add_collider(node_name: String, mesh: ArrayMesh) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = shape
	body.add_child(col)
	dungeon_root.add_child(body)


# ---------- Luz, inimigos e itens ----------

func _build_lights() -> void:
	for i in rooms.size():
		var lamp := OmniLight3D.new()
		lamp.position = _room_center_world(i) + Vector3(0, 2.6, 0)
		if rooms[i]["boss"]:
			lamp.light_color = Color(1.0, 0.25, 0.2)
			lamp.light_energy = 1.8
		else:
			lamp.light_color = Color(1.0, 0.72, 0.45)
			lamp.light_energy = 1.1
		lamp.omni_range = 11.0
		lamp.shadow_enabled = false
		dungeon_root.add_child(lamp)


func _spawn_enemies() -> void:
	var holder := Node3D.new()
	holder.name = "Enemies"
	dungeon_root.add_child(holder)
	var max_depth := 1
	for r in rooms:
		max_depth = maxi(max_depth, int(r["depth"]))
	for i in range(1, rooms.size()):
		var room: Dictionary = rooms[i]
		if room["boss"]:
			_spawn_enemy(holder, boss_type, _room_center_world(i))
			continue
		if rng.randf() > 0.7:
			continue
		# Quanto mais fundo, mais orcs e esqueletos
		var ratio := float(room["depth"]) / float(max_depth)
		var pool: Array = []
		for t in enemy_types:
			if ratio >= float(t["min_ratio"]):
				pool.append(t)
		for _k in rng.randi_range(1, 2):
			var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var c := _random_cell_in(i)
			_spawn_enemy(holder, pick, _cell_world(c.x, c.y, 0.0))


func _spawn_enemy(holder: Node3D, t: Dictionary, pos: Vector3) -> void:
	var e = enemy_scene.instantiate()
	holder.add_child(e)
	e.position = pos
	var cfg: Dictionary = t.duplicate()
	cfg["texture"] = sprites[t["kind"]]
	e.setup(cfg, self)


func _spawn_items() -> void:
	var holder := Node3D.new()
	holder.name = "Items"
	dungeon_root.add_child(holder)
	for i in range(1, rooms.size()):
		if rooms[i]["boss"] or rng.randf() > 0.5:
			continue
		var c := _random_cell_in(i)
		var roll := rng.randf()
		if roll < 0.35:
			_spawn_pickup(holder, "potion", null, c)
		elif roll < 0.6:
			_spawn_pickup(holder, "gold", null, c)
		elif roll < 0.8:
			_spawn_pickup(holder, "weapon", WEAPON_DB[rng.randi_range(1, WEAPON_DB.size() - 1)], c)
		else:
			_spawn_pickup(holder, "armor", ARMOR_DB[rng.randi_range(1, ARMOR_DB.size() - 1)], c)
	# Cada magia aparece em um pergaminho em uma sala diferente (sempre)
	var spot_rooms: Array = []
	for i in range(1, rooms.size()):
		if not rooms[i]["boss"]:
			spot_rooms.append(i)
	for k in range(mini(SPELL_DB.size(), spot_rooms.size())):
		var ri: int = spot_rooms[rng.randi_range(0, spot_rooms.size() - 1)]
		spot_rooms.erase(ri)
		_spawn_pickup(holder, "scroll", SPELL_DB[k], _random_cell_in(ri))


func _spawn_pickup(holder: Node3D, kind: String, item, c: Vector2i) -> void:
	var sp := _make_sprite(sprites[kind], 0.02)
	sp.position = _cell_world(c.x, c.y, 0.45)
	holder.add_child(sp)
	var entry := {"node": sp, "kind": kind}
	if item != null:
		entry["item"] = item.duplicate()
	pickups.append(entry)


# ---------- Visual ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.42, 0.33)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.04, 0.03)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 3.0
	env.fog_depth_end = 18.0
	dungeon_environment = env
	world_environment_node = WorldEnvironment.new()
	world_environment_node.name = "WorldEnvironment"
	world_environment_node.environment = dungeon_environment
	add_child(world_environment_node)


func _make_materials() -> void:
	var uv := Vector3.ONE
	wall_mat = _std_mat(_make_texture("wall", 1), Vector3.ONE)
	floor_mat = _std_mat(_make_texture("floor", 2), uv)
	ceil_mat = _std_mat(_make_texture("ceiling", 3), uv)
	for kind in ["rat", "goblin", "bat", "skel", "orc", "npc", "potion", "gold", "weapon", "armor", "scroll", "spell_fire", "spell_lightning", "spell_heal"]:
		sprites[kind] = _make_sprite_texture(kind)
	# Sprites reais de NPCs (se existirem em assets/npcs/)
	var npc_files := {
		"npcmale": "res://assets/npcs/npcmale.png",
		"npcfemale": "res://assets/npcs/npcfemale.png",
		"boy": "res://assets/npcs/boy.png",
		"girl": "res://assets/npcs/girl.png",
		"guard": "res://assets/npcs/guard.png",
		"female_guard": "res://assets/npcs/female_guard.png",
		"healer": "res://assets/npcs/healer.png",
		"male_healer": "res://assets/npcs/male_healer.png",
		"merchant": "res://assets/npcs/merchant.png",
		"female_merchant": "res://assets/npcs/female_merchant.png",
		"blacksmith": "res://assets/npcs/blacksmith.png",
		"female_blacksmith": "res://assets/npcs/female_blacksmith.png",
		"messenger": "res://assets/npcs/messenger.png",
		"female_messenger": "res://assets/npcs/female_messenger.png",
		"witch": "res://assets/npcs/witch.png",
	}
	for key in npc_files:
		if ResourceLoader.exists(npc_files[key]):
			sprites[key] = load(npc_files[key])


func _std_mat(tex: Texture2D, uv: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = uv
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _make_texture(kind: String, tex_seed: int) -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = tex_seed
	noise.frequency = 0.12
	var tint := Color(0.42, 0.38, 0.34)
	if kind == "floor":
		tint = Color(0.30, 0.27, 0.24)
	elif kind == "ceiling":
		tint = Color(0.20, 0.19, 0.19)
	for y in size:
		for x in size:
			var c := tint * (0.85 + noise.get_noise_2d(x, y) * 0.15)
			if kind == "wall":
				var off := 16 if (y / 16) % 2 == 1 else 0
				if y % 16 < 2 or (x + off) % 32 < 2:
					c = Color(0.12, 0.11, 0.10)
			elif kind == "floor":
				if y % 32 < 2 or x % 32 < 2:
					c = Color(0.10, 0.09, 0.08)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_sprite_texture(kind: String) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"rat":
			_ellipse(img, 15.0, 19.0, 10.0, 6.0, Color(0.45, 0.32, 0.25))
			_ellipse(img, 25.0, 17.0, 4.0, 3.5, Color(0.45, 0.32, 0.25))
			_rect(img, 4, 24, 26, 27, Color(0.3, 0.2, 0.15))
			_px(img, 26, 15, Color(1.0, 0.2, 0.2))
		"goblin":
			_ellipse(img, 16.0, 20.0, 7.0, 8.0, Color(0.42, 0.62, 0.28))
			_ellipse(img, 16.0, 11.0, 5.5, 5.0, Color(0.5, 0.72, 0.32))
			_rect(img, 7, 9, 11, 11, Color(0.5, 0.72, 0.32))
			_rect(img, 21, 9, 25, 11, Color(0.5, 0.72, 0.32))
			_px(img, 14, 11, Color(1.0, 0.9, 0.2))
			_px(img, 18, 11, Color(1.0, 0.9, 0.2))
			_rect(img, 13, 27, 15, 31, Color(0.3, 0.2, 0.12))
			_rect(img, 17, 27, 19, 31, Color(0.3, 0.2, 0.12))
			_rect(img, 23, 14, 25, 26, Color(0.5, 0.35, 0.2))
		"bat":
			_ellipse(img, 8.0, 14.0, 7.0, 4.0, Color(0.18, 0.14, 0.22))
			_ellipse(img, 24.0, 14.0, 7.0, 4.0, Color(0.18, 0.14, 0.22))
			_ellipse(img, 16.0, 16.0, 3.5, 5.0, Color(0.28, 0.22, 0.34))
			_px(img, 15, 14, Color(1.0, 0.2, 0.2))
			_px(img, 17, 14, Color(1.0, 0.2, 0.2))
		"skel":
			_rect(img, 12, 12, 20, 24, Color(0.85, 0.82, 0.75))
			_ellipse(img, 16.0, 9.0, 4.5, 4.5, Color(0.9, 0.87, 0.8))
			_px(img, 14, 9, Color(0.05, 0.05, 0.05))
			_px(img, 18, 9, Color(0.05, 0.05, 0.05))
			_rect(img, 12, 24, 14, 31, Color(0.85, 0.82, 0.75))
			_rect(img, 18, 24, 20, 31, Color(0.85, 0.82, 0.75))
		"orc":
			_ellipse(img, 16.0, 17.0, 12.0, 13.0, Color(0.3, 0.5, 0.25))
			_px(img, 11, 22, Color.WHITE)
			_px(img, 21, 22, Color.WHITE)
			_px(img, 12, 13, Color(1.0, 0.2, 0.2))
			_px(img, 20, 13, Color(1.0, 0.2, 0.2))
		"potion":
			_rect(img, 13, 8, 19, 13, Color(0.8, 0.85, 0.9))
			_ellipse(img, 16.0, 20.0, 7.0, 7.0, Color(0.8, 0.1, 0.12))
		"gold":
			_ellipse(img, 16.0, 16.0, 9.0, 9.0, Color(0.95, 0.75, 0.2))
			_ellipse(img, 16.0, 16.0, 5.5, 5.5, Color(0.75, 0.55, 0.1))
		"weapon":
			_rect(img, 14, 6, 17, 24, Color(0.8, 0.82, 0.88))
			_rect(img, 10, 22, 21, 24, Color(0.85, 0.68, 0.3))
			_rect(img, 14, 24, 17, 29, Color(0.4, 0.25, 0.12))
		"armor":
			_rect(img, 8, 8, 24, 26, Color(0.5, 0.52, 0.56))
			_rect(img, 12, 12, 20, 22, Color(0.35, 0.37, 0.4))
			_px(img, 16, 16, Color(0.85, 0.7, 0.3))
		"npc":
			_ellipse(img, 16.0, 8.0, 4.5, 4.5, Color(0.9, 0.75, 0.6))
			_rect(img, 11, 13, 21, 30, Color(0.85, 0.85, 0.85))
			_rect(img, 8, 14, 11, 24, Color(0.85, 0.85, 0.85))
			_rect(img, 21, 14, 24, 24, Color(0.85, 0.85, 0.85))
			_rect(img, 12, 30, 15, 31, Color(0.35, 0.25, 0.15))
			_rect(img, 17, 30, 20, 31, Color(0.35, 0.25, 0.15))
		"spell_fire":
			_ellipse(img, 16.0, 17.0, 12.0, 12.0, Color(1.0, 0.45, 0.1, 0.22))
			_ellipse(img, 16.0, 20.0, 8.0, 9.0, Color(0.95, 0.4, 0.1))
			_ellipse(img, 16.0, 11.0, 4.5, 8.0, Color(0.95, 0.4, 0.1))
			_ellipse(img, 16.0, 22.0, 5.0, 6.0, Color(1.0, 0.75, 0.2))
			_ellipse(img, 16.0, 24.0, 2.5, 3.5, Color(1.0, 0.95, 0.7))
		"spell_lightning":
			_ellipse(img, 16.0, 16.0, 13.0, 13.0, Color(0.25, 0.55, 1.0, 0.3))
			for y in range(3, 17):
				var bx := int(round(22.0 - float(y - 3) * 0.77))
				_rect(img, bx - 3, y, bx + 3, y + 1, Color(0.6, 0.9, 1.0))
			for y in range(16, 29):
				var bx2 := int(round(19.0 - float(y - 16) * 0.62))
				_rect(img, bx2 - 3, y, bx2 + 3, y + 1, Color(0.6, 0.9, 1.0))
		"spell_heal":
			_ellipse(img, 16.0, 16.0, 13.0, 13.0, Color(0.2, 0.6, 0.35, 0.3))
			_rect(img, 13, 6, 19, 26, Color(0.45, 1.0, 0.55))
			_rect(img, 6, 13, 26, 19, Color(0.45, 1.0, 0.55))
			_rect(img, 15, 8, 17, 24, Color(0.85, 1.0, 0.9))
			_rect(img, 8, 15, 24, 17, Color(0.85, 1.0, 0.9))
		"scroll":
			_rect(img, 9, 10, 23, 22, Color(0.92, 0.86, 0.66))
			_rect(img, 8, 9, 10, 23, Color(0.7, 0.55, 0.3))
			_rect(img, 22, 9, 24, 23, Color(0.7, 0.55, 0.3))
			_rect(img, 12, 14, 20, 15, Color(0.4, 0.2, 0.6))
			_rect(img, 12, 18, 20, 19, Color(0.4, 0.2, 0.6))
	return ImageTexture.create_from_image(img)


func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			_px(img, x, y, col)


func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


func _make_sprite(tex: Texture2D, px: float) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.pixel_size = px
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return sp


# ---------- Interface ----------

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# Mantém toda a interface exclusiva da aventura dentro de um único nó.
	# O menu principal continua fora dele, então pode ocultar o HUD inteiro sem
	# esconder os próprios botões do menu.
	gameplay_hud_root = Control.new()
	gameplay_hud_root.name = "GameplayHUD"
	gameplay_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(gameplay_hud_root)

	hud_hurt = ColorRect.new()
	hud_hurt.color = Color(0.8, 0.05, 0.05, 0.0)
	hud_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud_root.add_child(hud_hurt)

	# HUD de status (vida, mana, ouro, poções + mira) e hotbar de magias/itens
	hud_bar = Control.new()
	hud_bar.set_script(load(STATUS_SCRIPT))
	hud_bar.set("game", self)
	hud_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud_root.add_child(hud_bar)

	hotbar = Control.new()
	hotbar.set_script(load(HOTBAR_SCRIPT))
	hotbar.set("game", self)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud_root.add_child(hotbar)

	hud_msg = Label.new()
	hud_msg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_msg.offset_left = 26.0
	hud_msg.offset_right = 560.0
	hud_msg.offset_top = -267.0
	hud_msg.offset_bottom = -203.0
	hud_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_msg.add_theme_font_size_override("font_size", 14)
	hud_msg.add_theme_font_override("font", UiFrame.font())
	hud_msg.add_theme_color_override("font_color", Color(0.82, 0.79, 0.71, 0.94))
	hud_msg.add_theme_color_override("font_outline_color", Color(0.015, 0.013, 0.012, 0.9))
	hud_msg.add_theme_constant_override("outline_size", 3)
	hud_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud_root.add_child(hud_msg)

	# Banner com o nome do lugar (aparece ao entrar numa cidade)
	hud_zone = Label.new()
	hud_zone.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_zone.offset_top = 130
	hud_zone.offset_bottom = 180
	hud_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_zone.add_theme_font_size_override("font_size", 38)
	hud_zone.add_theme_font_override("font", UiFrame.font())
	hud_zone.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	hud_zone.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))
	hud_zone.add_theme_constant_override("outline_size", 8)
	hud_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_zone.modulate.a = 0.0
	gameplay_hud_root.add_child(hud_zone)

	hud_zone_sub = Label.new()
	hud_zone_sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_zone_sub.offset_top = 180
	hud_zone_sub.offset_bottom = 205
	hud_zone_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_zone_sub.add_theme_font_size_override("font_size", 15)
	hud_zone_sub.add_theme_font_override("font", UiFrame.font())
	hud_zone_sub.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	hud_zone_sub.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02))
	hud_zone_sub.add_theme_constant_override("outline_size", 5)
	hud_zone_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_zone_sub.modulate.a = 0.0
	gameplay_hud_root.add_child(hud_zone_sub)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	hud.add_child(overlay)

	overlay_dim = ColorRect.new()
	overlay_dim.name = "OverlayDim"
	overlay_dim.color = Color(0.03, 0.02, 0.02, 0.88)
	overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(overlay_dim)

	overlay_center = CenterContainer.new()
	overlay_center.name = "OverlayCenter"
	overlay_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 20)
	overlay_center.add_child(box)

	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 56)
	overlay_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	box.add_child(overlay_title)

	overlay_body = Label.new()
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_font_size_override("font_size", 20)
	overlay_body.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	box.add_child(overlay_body)

	overlay_btn = Button.new()
	overlay_btn.custom_minimum_size = Vector2(320, 56)
	overlay_btn.focus_mode = Control.FOCUS_NONE
	overlay_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_btn.add_theme_font_size_override("font_size", 24)
	overlay_btn.pressed.connect(_on_overlay_button)
	box.add_child(overlay_btn)

	overlay_save_btn = Button.new()
	overlay_save_btn.name = "SaveCampaignButton"
	overlay_save_btn.text = "SALVAR JOGO"
	overlay_save_btn.custom_minimum_size = Vector2(320, 46)
	overlay_save_btn.focus_mode = Control.FOCUS_NONE
	overlay_save_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_save_btn.add_theme_font_size_override("font_size", 19)
	overlay_save_btn.visible = false
	overlay_save_btn.pressed.connect(_save_from_pause)
	box.add_child(overlay_save_btn)

	# Menu principal: o foco visual é a montanha real da malha de Brumaférrea.
	menu_content = Control.new()
	menu_content.name = "MainMenuContent"
	menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_content.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_content.visible = false
	overlay.add_child(menu_content)

	var menu_fade := TextureRect.new()
	menu_fade.name = "LeftDarkGradient"
	menu_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_fade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	menu_fade.stretch_mode = TextureRect.STRETCH_SCALE
	var menu_gradient := Gradient.new()
	menu_gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	menu_gradient.colors = PackedColorArray([
		Color(0.012, 0.013, 0.012, 0.94),
		Color(0.012, 0.013, 0.012, 0.70),
		Color(0.012, 0.013, 0.012, 0.0)
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = menu_gradient
	gradient_texture.width = 1024
	gradient_texture.height = 2
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 0.0)
	menu_fade.texture = gradient_texture
	menu_content.add_child(menu_fade)

	var menu_center := CenterContainer.new()
	menu_center.name = "MenuColumn"
	menu_center.anchor_left = 0.0
	menu_center.anchor_top = 0.0
	menu_center.anchor_right = 0.43
	menu_center.anchor_bottom = 1.0
	menu_center.offset_left = 28.0
	menu_center.offset_top = 16.0
	menu_center.offset_right = -12.0
	menu_center.offset_bottom = -16.0
	menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_content.add_child(menu_center)

	var menu_stack := VBoxContainer.new()
	menu_stack.name = "MenuStack"
	menu_stack.custom_minimum_size = Vector2(350.0, 0.0)
	menu_stack.add_theme_constant_override("separation", 14)
	menu_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_center.add_child(menu_stack)

	var brand := Label.new()
	brand.name = "FranchiseTitle"
	brand.text = "OS CÂNTICOS DOS SETE"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	brand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brand.add_theme_font_override("font", UiFrame.font())
	brand.add_theme_font_size_override("font_size", 27)
	brand.add_theme_color_override("font_color", Color(0.91, 0.88, 0.78))
	brand.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	brand.add_theme_constant_override("shadow_offset_x", 2)
	brand.add_theme_constant_override("shadow_offset_y", 2)
	menu_stack.add_child(brand)

	var game_title := Label.new()
	game_title.name = "GameTitle"
	game_title.text = "BRUMAFÉRREA"
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	game_title.add_theme_font_override("font", UiFrame.font())
	game_title.add_theme_font_size_override("font_size", 43)
	game_title.add_theme_color_override("font_color", Color(0.78, 0.66, 0.43))
	game_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	game_title.add_theme_constant_override("shadow_offset_x", 2)
	game_title.add_theme_constant_override("shadow_offset_y", 2)
	menu_stack.add_child(game_title)

	var title_rule := ColorRect.new()
	title_rule.name = "TitleRule"
	title_rule.color = Color(0.62, 0.48, 0.27, 0.92)
	title_rule.custom_minimum_size = Vector2(250.0, 2.0)
	title_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_stack.add_child(title_rule)

	var menu_gap := Control.new()
	menu_gap.custom_minimum_size = Vector2(0.0, 12.0)
	menu_stack.add_child(menu_gap)

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 10)
	menu_stack.add_child(actions)

	var continue_journey := _make_main_menu_button("CONTINUAR")
	continue_journey.name = "ContinueJourney"
	continue_journey.pressed.connect(_on_continue_campaign)
	continue_journey.disabled = true
	actions.add_child(continue_journey)

	var new_journey := _make_main_menu_button("NOVA JORNADA")
	new_journey.name = "NewJourney"
	new_journey.pressed.connect(_on_main_menu_start)
	actions.add_child(new_journey)

	var quit_button := _make_main_menu_button("SAIR")
	quit_button.name = "Quit"
	quit_button.pressed.connect(_on_main_menu_quit)
	actions.add_child(quit_button)

	# Inventário/ficha do personagem (I), usando a identidade visual do diário de missões (J).
	inventory_screen = Control.new()
	inventory_screen.name = "InventoryScreen"
	inventory_screen.set_script(load(INVENTORY_SCRIPT))
	inventory_screen.set("game", self)
	inventory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_screen.visible = false
	gameplay_hud_root.add_child(inventory_screen)

	home_storage_screen = Control.new()
	home_storage_screen.name = "PlayerHomeStorageScreen"
	home_storage_screen.set_script(load(HOME_STORAGE_SCRIPT))
	home_storage_screen.set("game", self)
	home_storage_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_storage_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	home_storage_screen.visible = false
	gameplay_hud_root.add_child(home_storage_screen)

	compass = Control.new()
	compass.set_script(load(COMPASS_SCRIPT))
	compass.set("game", self)
	compass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.visible = false
	gameplay_hud_root.add_child(compass)

	world_map = Control.new()
	world_map.set_script(load(WORLD_MAP_SCRIPT))
	world_map.set("game", self)
	world_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_map.mouse_filter = Control.MOUSE_FILTER_STOP
	world_map.visible = false
	gameplay_hud_root.add_child(world_map)


	quest_journal = Control.new()
	quest_journal.set_script(load(QUEST_JOURNAL_SCRIPT))
	quest_journal.set("game", self)
	quest_journal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quest_journal.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_journal.visible = false
	gameplay_hud_root.add_child(quest_journal)

	dialog = PanelContainer.new()
	dialog.set_script(load(DIALOG_SCRIPT))
	dialog.closed.connect(_on_dialog_closed)
	dialog.line_shown.connect(_on_dialog_line_shown)
	gameplay_hud_root.add_child(dialog)

	shop = PanelContainer.new()
	shop.set_script(load(SHOP_SCRIPT))
	shop.closed.connect(_on_shop_closed)
	gameplay_hud_root.add_child(shop)

	# Rastreador de missão como texto puro no meio/direita da tela: sem caixa,
	# fundo ou borda, para não competir visualmente com o mundo.
	hud_quest_tracker = PanelContainer.new()
	hud_quest_tracker.name = "QuestTracker"
	hud_quest_tracker.anchor_left = 1.0
	hud_quest_tracker.anchor_right = 1.0
	hud_quest_tracker.anchor_top = 0.5
	hud_quest_tracker.anchor_bottom = 0.5
	hud_quest_tracker.offset_left = -390.0
	hud_quest_tracker.offset_right = -28.0
	hud_quest_tracker.offset_top = -68.0
	hud_quest_tracker.offset_bottom = 68.0
	hud_quest_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_quest_tracker.visible = false
	var quest_style := StyleBoxEmpty.new()
	hud_quest_tracker.add_theme_stylebox_override("panel", quest_style)
	gameplay_hud_root.add_child(hud_quest_tracker)

	var quest_tracker_box := VBoxContainer.new()
	quest_tracker_box.add_theme_constant_override("separation", 3)
	quest_tracker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_quest_tracker.add_child(quest_tracker_box)

	hud_quest_status = Label.new()
	hud_quest_status.text = "MISSÃO ATIVA"
	hud_quest_status.add_theme_font_size_override("font_size", 12)
	hud_quest_status.add_theme_font_override("font", UiFrame.font())
	hud_quest_status.add_theme_color_override("font_color", Color(0.91, 0.70, 0.34))
	hud_quest_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_quest_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_quest_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker_box.add_child(hud_quest_status)

	hud_quest_title = Label.new()
	hud_quest_title.text = ""
	hud_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_quest_title.add_theme_font_size_override("font_size", 17)
	hud_quest_title.add_theme_font_override("font", UiFrame.font())
	hud_quest_title.add_theme_color_override("font_color", Color(0.94, 0.86, 0.66))
	hud_quest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_quest_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_quest_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker_box.add_child(hud_quest_title)

	hud_quest_details = Label.new()
	hud_quest_details.text = ""
	hud_quest_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_quest_details.add_theme_font_size_override("font_size", 13)
	hud_quest_details.add_theme_font_override("font", UiFrame.font())
	hud_quest_details.add_theme_color_override("font_color", Color(0.75, 0.71, 0.62))
	hud_quest_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_quest_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_quest_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker_box.add_child(hud_quest_details)

	# O menu de pausa usa uma camada independente do HUD: outras interfaces podem
	# ser ocultadas/recriadas sem afetar a visibilidade ou o estado dele.
	_ensure_pause_menu()


func _ensure_pause_menu() -> void:
	if not is_instance_valid(pause_layer):
		pause_layer = CanvasLayer.new()
		pause_layer.name = "PauseMenuLayer"
		pause_layer.layer = 100
		pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pause_layer)
	if not is_instance_valid(pause_menu):
		pause_menu = Control.new()
		pause_menu.name = "PauseMenu"
		pause_menu.set_script(load(PAUSE_MENU_SCRIPT))
		pause_menu.set("game", self)
		pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu.z_index = 0
		pause_menu.z_as_relative = true
		pause_menu.visible = false
		pause_layer.add_child(pause_menu)
	else:
		# Corrige projetos/sessões em que a instância antiga ainda esteja no HUD.
		if pause_menu.get_parent() != pause_layer:
			var old_parent := pause_menu.get_parent()
			if old_parent != null:
				old_parent.remove_child(pause_menu)
			pause_layer.add_child(pause_menu)
		pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu.z_index = 0
		pause_menu.z_as_relative = true


func _update_hud(_delta: float) -> void:
	var ui_open := phase == "dialog" or phase == "map" or phase == "shop" or phase == "quest_log" or phase == "inventory" or phase == "home_storage"
	hud_bar.visible = not ui_open
	hotbar.visible = not ui_open
	compass.visible = phase != "map" and phase != "quest_log" and phase != "inventory" and phase != "home_storage"
	_update_quest_tracker()


func _update_quest_tracker() -> void:
	if not is_instance_valid(hud_quest_tracker):
		return
	var quest: Dictionary = {}
	if quest_manager != null and is_instance_valid(quest_manager) and quest_manager.has_method("get_tracked_quest"):
		quest = quest_manager.get_tracked_quest()
	var status := str(quest.get("status", ""))
	var has_trackable_quest := status == "active" or status == "ready"
	hud_quest_tracker.visible = phase == "play" and has_trackable_quest
	if has_trackable_quest:
		hud_quest_title.text = str(quest.get("title", "Trabalho"))
		if status == "ready":
			hud_quest_status.text = "OBJETIVO CONCLUÍDO"
			hud_quest_status.add_theme_color_override("font_color", Color(0.67, 0.88, 0.46))
			hud_quest_details.text = "Volte ao contratante:\n%s\n%s" % [str(quest.get("giver_name", "o contratante")), str(quest.get("city_name", "a cidade"))]
		else:
			hud_quest_status.text = "MISSÃO EM ANDAMENTO"
			hud_quest_status.add_theme_color_override("font_color", Color(0.91, 0.70, 0.34))
			var target_label := str(quest.get("target_label", "alvos"))
			var progress := int(quest.get("progress", 0))
			var required := int(quest.get("target_count", 1))
			if str(quest.get("quest_type", "hunt")) == "collection":
				hud_quest_details.text = "Reúna %s (%d/%d)\nLocal: %s" % [target_label, progress, required, str(quest.get("site_name", "arredores"))]
			else:
				hud_quest_details.text = "Derrote %s (%d/%d)\nRegião: %s" % [target_label, progress, required, str(quest.get("city_name", "arredores"))]
	_sync_quest_giver_markers()


func _sync_quest_giver_markers() -> void:
	if quest_manager == null or not is_instance_valid(quest_manager):
		return
	var giver_ids: Array[String] = []
	if quest_manager.has_method("get_ready_giver_ids"):
		giver_ids = quest_manager.get_ready_giver_ids()
	var signature := ""
	for giver_id in giver_ids:
		signature += str(giver_id) + "|"
	if signature == _quest_marker_signature:
		return
	_quest_marker_signature = signature
	if overworld != null and is_instance_valid(overworld) and overworld.has_method("sync_quest_giver_markers"):
		overworld.call("sync_quest_giver_markers", giver_ids)

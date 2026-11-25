extends CharacterBody3D
# Jogador em primeira pessoa: arma ou magia equipada ocupa o espaço ativo da mão; consumíveis usam atalhos próprios.

const MAX_HP := 100
const RESOURCE_CATALOG := preload("res://scripts/resource_catalog.gd")
const PLAYER_SFX_PATHS := {
	"woosh": "res://assets/sound/sfx/player/woosh.mp3",
	"hit": "res://assets/sound/sfx/player/hit.mp3",
	"swordhit": "res://assets/sound/sfx/player/swordhit.mp3",
	"daggerhit": "res://assets/sound/sfx/player/daggerhit.mp3",
	"footsteps": "res://assets/sound/sfx/player/footsteps.mp3",
}
# Os arquivos têm níveis de gravação diferentes; estes ganhos compensam isso sem
# normalizar nem alterar os áudios originais. São ajustáveis no próprio script.
const PLAYER_SFX_GAIN_DB := {
	"woosh": 18.0,
	"hit": -9.0,
	"swordhit": 7.0,
	"daggerhit": 11.0,
	# Volume solicitado: manter os passos em 10.0 dB de ganho.
	"footsteps": 10.0,
}
const PLAYER_SFX_VOICE_COUNT := 5
const SPEED := 3.6
const RUN_MULT := 1.67
const MOUNTED_SPEED := 8.5
const MOUNTED_RUN_MULT := 1.45
const MOUNTED_CAMERA_HEIGHT := 2.05
const HORSE_HOOFSTEPS_PATH := "res://assets/sound/sfx/player/horse_steps.ogg"
const HORSE_HOOFSTEPS_VOLUME_DB := -12.0
const HORSE_HOOFSTEPS_FADE_DB_PER_SEC := 260.0
const MOUSE_SENS := 0.002
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const POTION_HEAL := 40
const CAST_COOLDOWN := 0.5
const MANA_REGEN := 3.0
const BASE_MANA := 50.0
const REST_POS := Vector3(0.25, -0.25, -0.45)
const SWING_REST := Vector3(-8, 0, 0)
const WINDUP_ROT := Vector3(-15, -40, 0)
const SLASH_ROT := Vector3(10, 40, 0)
const WINDUP_POS := Vector3(0.1, -0.05, 0.12)
const SLASH_POS := Vector3(-0.05, 0.0, -0.3)

var game = null
var is_mounted := false
var _camera_height_on_foot: float = 1.6
var _mounted_bob_t: float = 0.0
var hp := MAX_HP
var max_hp := MAX_HP
var max_mana := BASE_MANA
var mana := BASE_MANA
var gold := 0
# Progressão RPG de sessão: experiência, níveis e atributos treináveis.
var level := 1
var experience := 0
var attribute_points := 0
var attributes: Dictionary = {"vigor": 5, "strength": 5, "agility": 5, "arcana": 5}
# Proficiência cresce pelo uso real: magias por conjuração válida e armas por acerto.
# Os valores são mantidos durante a sessão e não são apagados ao tentar novamente.
var proficiencies: Dictionary = {}
const PROFICIENCY_THRESHOLDS := [0, 10, 25, 50, 100]
const MAGIC_PROFICIENCY_MULTIPLIERS := [1.0, 1.12, 1.27, 1.47, 1.75]
const WEAPON_PROFICIENCY_MULTIPLIERS := [1.0, 1.04, 1.08, 1.14, 1.22]
const PROFICIENCY_RANK_NAMES := ["Iniciante", "Aprendiz", "Adepto", "Veterano", "Mestre"]
var potions := 2
# Materiais naturais coletados no mundo aberto, por identificador de recurso.
var resources: Dictionary = {}
var weapons: Array = []
var weapon_idx := 0
var armors: Array = []
var armor_idx := 0
var spells: Array = []
var spell_idx := 0
# Uma arma física ou uma magia ocupa o espaço ativo da mão; apenas uma fica equipada por vez.
var active_equipment_type := "weapon" # "weapon" ou "spell"
# Espaços rápidos 1–3 para consumíveis. No momento, apenas poções são utilizáveis.
var consumable_slots: Array = ["potion", "", ""]
var _channel_needs_release := false
var _cast_message_shown_for_hold := false
var _dead := false
var _cooldown := 0.0
var _cast_cd := 0.0
var _jump_req := false
var _pitch := 0.0
var _swing_tween: Tween
# Evita ataques repetidos antes do impacto, mas libera novo golpe assim que o dano já saiu.
var _sprite_attack_hit := false
var _player_sfx_streams: Dictionary = {}
var _player_sfx_voices: Array[AudioStreamPlayer] = []
var _player_sfx_voice_index := 0
var _horse_hoofsteps_player: AudioStreamPlayer
# Passos por distância percorrida, em vez de um timer fixo: a cadência acompanha a velocidade real.
var _footstep_distance: float = 0.0
var _last_footstep_position: Vector3 = Vector3.ZERO
var _bob_t := 0.0
# Balanço procedural do sprite em primeira pessoa; o canto inferior continua ancorado.
var _fist_motion_t := 0.0
var _fist_motion_x := 0.0
var _fist_motion_rotation := 0.0
var weapon_root: Node3D
var fist_layer: CanvasLayer
var fist_sprite: TextureRect # Sprite 2D da arma equipada em primeira pessoa.
var horse_layer: CanvasLayer
var horse_view: TextureRect
var _horse_frame_time: float = 0.0
var _horse_frame_index: int = 0
var overlay_weapon_model := ""
const FIST_SCREEN_SCALE := 4.5
const SWORD_SCREEN_SCALE := 5.0
const FIST_RIGHT_MARGIN := -5.0
const SWORD_RIGHT_MARGIN := -5.0
const FIST_IDLE := "res://assets/player/weapons/fist/fist/0-0.PNG"
const FIST_SWING := [
	"res://assets/player/weapons/fist/fist/2-0.PNG",
	"res://assets/player/weapons/fist/fist/2-1.PNG",
	"res://assets/player/weapons/fist/fist/2-2.PNG",
	"res://assets/player/weapons/fist/fist/2-3.PNG",
	"res://assets/player/weapons/fist/fist/2-4.PNG"
]
const SWORD_IDLE := "res://assets/player/weapons/swords/sword/0-0.PNG"
const SWORD_SWING := [
	"res://assets/player/weapons/swords/sword/1-0.PNG",
	"res://assets/player/weapons/swords/sword/1-1.PNG",
	"res://assets/player/weapons/swords/sword/1-2.PNG",
	"res://assets/player/weapons/swords/sword/1-3.PNG",
	"res://assets/player/weapons/swords/sword/1-4.PNG"
]
# Sprites de primeira pessoa para as outras armas. Escalas independentes para
# poder ajustar cada silhueta sem alterar o tamanho dos punhos ou da espada.
const DAGGER_SCREEN_SCALE := 5.0
const AXE_SCREEN_SCALE := 5.0
const SPEAR_SCREEN_SCALE := 5.0
const DAGGER_RIGHT_MARGIN := -5.0
const AXE_RIGHT_MARGIN := -5.0
const SPEAR_RIGHT_MARGIN := -5.0
const DAGGER_IDLE := "res://assets/player/weapons/dagger/0-0.PNG"
const DAGGER_SWING := [
	"res://assets/player/weapons/dagger/6-0.PNG",
	"res://assets/player/weapons/dagger/6-1.PNG",
	"res://assets/player/weapons/dagger/6-2.PNG",
	"res://assets/player/weapons/dagger/6-3.PNG",
	"res://assets/player/weapons/dagger/6-4.PNG"
]
const AXE_IDLE := "res://assets/player/weapons/axe/0-0.PNG"
const AXE_SWING := [
	"res://assets/player/weapons/axe/2-0.PNG",
	"res://assets/player/weapons/axe/2-1.PNG",
	"res://assets/player/weapons/axe/2-2.PNG",
	"res://assets/player/weapons/axe/2-3.PNG",
	"res://assets/player/weapons/axe/2-4.PNG"
]
const SPEAR_IDLE := "res://assets/player/weapons/spear/0-0.PNG"
const MAGIC_IDLE := "res://assets/player/weapons/magic/0-0.PNG"
const MAGIC_SCREEN_SCALE := 5.0
const MAGIC_RIGHT_MARGIN := -5.0
const SPEAR_SWING := [
	"res://assets/player/weapons/spear/6-0.PNG",
	"res://assets/player/weapons/spear/6-1.PNG",
	"res://assets/player/weapons/spear/6-2.PNG",
	"res://assets/player/weapons/spear/6-3.PNG",
	"res://assets/player/weapons/spear/6-4.PNG"
]

func _weapon_idle_sprite_path(model: String) -> String:
	match model:
		"fist": return FIST_IDLE
		"sword": return SWORD_IDLE
		"dagger": return DAGGER_IDLE
		"axe": return AXE_IDLE
		"spear": return SPEAR_IDLE
		"magic": return MAGIC_IDLE
	return ""


func _weapon_swing_sprite_frames(model: String) -> Array:
	match model:
		"fist": return FIST_SWING
		"sword": return SWORD_SWING
		"dagger": return DAGGER_SWING
		"axe": return AXE_SWING
		"spear": return SPEAR_SWING
	return []


func _has_weapon_sprite_resources(model: String) -> bool:
	var idle_path := _weapon_idle_sprite_path(model)
	if idle_path.is_empty() or not ResourceLoader.exists(idle_path):
		return false
	# A mão de magia é um sprite estático: não exige cinco quadros de ataque.
	if model == "magic":
		return true
	var frames: Array = _weapon_swing_sprite_frames(model)
	if frames.is_empty():
		return false
	for frame_path in frames:
		if not ResourceLoader.exists(str(frame_path)):
			return false
	return true


func _weapon_sprite_scale(model: String) -> float:
	match model:
		"fist": return FIST_SCREEN_SCALE
		"sword": return SWORD_SCREEN_SCALE
		"dagger": return DAGGER_SCREEN_SCALE
		"axe": return AXE_SCREEN_SCALE
		"spear": return SPEAR_SCREEN_SCALE
		"magic": return MAGIC_SCREEN_SCALE
	return SWORD_SCREEN_SCALE


func _weapon_sprite_right_margin(model: String) -> float:
	match model:
		"fist": return FIST_RIGHT_MARGIN
		"sword": return SWORD_RIGHT_MARGIN
		"dagger": return DAGGER_RIGHT_MARGIN
		"axe": return AXE_RIGHT_MARGIN
		"spear": return SPEAR_RIGHT_MARGIN
		"magic": return MAGIC_RIGHT_MARGIN
	return SWORD_RIGHT_MARGIN

@onready var cam: Camera3D = $Camera
@onready var sway: Node3D = $Camera/Sway
@onready var swing: Node3D = $Camera/Sway/Swing


func _ready() -> void:
	add_to_group("player")
	_camera_height_on_foot = cam.position.y
	_setup_player_sfx()
	_setup_horse_hoofsteps()
	_last_footstep_position = global_position
	swing.rotation_degrees = SWING_REST
	weapon_root = Node3D.new()
	swing.add_child(weapon_root)

	# Punhos são uma arma 2D de primeira pessoa: ficam ancorados à viewport,
	# não como um objeto 3D flutuando à frente da câmera.
	fist_layer = CanvasLayer.new()
	fist_layer.name = "FirstPersonSpriteLayer"
	fist_layer.layer = 0
	add_child(fist_layer)
	get_viewport().size_changed.connect(_update_fist_anchor)
	_setup_horse_view()


func _setup_horse_view() -> void:
	# Camada separada: esconder punhos/armas ao montar não pode esconder o cavalo.
	horse_layer = CanvasLayer.new()
	horse_layer.name = "FirstPersonHorseLayer"
	horse_layer.layer = 0
	add_child(horse_layer)
	horse_view = TextureRect.new()
	horse_view.name = "FirstPersonHorseSprite"
	horse_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horse_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	horse_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	horse_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	horse_view.anchor_left = 0.5
	horse_view.anchor_right = 0.5
	horse_view.anchor_top = 1.0
	horse_view.anchor_bottom = 1.0
	horse_view.offset_left = -212.0
	horse_view.offset_right = 212.0
	horse_view.offset_top = -380.0
	horse_view.offset_bottom = 0.0
	horse_view.visible = false
	horse_layer.add_child(horse_view)
	_update_horse_view()


func _update_horse_view() -> void:
	if horse_view == null:
		return
	var playing: bool = game != null and game.phase == "play" and not _dead
	horse_view.visible = playing and is_mounted
	if is_mounted:
		var frame_path: String = "res://assets/player/horse/MRED00I0_frame%d.png" % _horse_frame_index
		# Só troca a textura quando o quadro realmente muda, não a cada tick físico.
		if horse_view.texture == null or horse_view.texture.resource_path != frame_path:
			var frame_texture := load(frame_path) as Texture2D
			if frame_texture != null:
				horse_view.texture = frame_texture

func _setup_horse_hoofsteps() -> void:
	var stream := load(HORSE_HOOFSTEPS_PATH) as AudioStreamOggVorbis
	if stream == null:
		push_warning("Som de cascos do cavalo não encontrado: %s" % HORSE_HOOFSTEPS_PATH)
		return
	# O arquivo foi preparado para fechar o ciclo sem estalo; o loop é contínuo
	# durante o deslocamento e não depende de disparar amostras por temporizador.
	stream.loop = true
	stream.loop_offset = 0.0
	_horse_hoofsteps_player = AudioStreamPlayer.new()
	_horse_hoofsteps_player.name = "HorseHoofstepsLoop"
	_horse_hoofsteps_player.stream = stream
	_horse_hoofsteps_player.bus = "Master"
	_horse_hoofsteps_player.volume_db = -60.0
	_horse_hoofsteps_player.pitch_scale = 1.0
	_horse_hoofsteps_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_horse_hoofsteps_player)


func _update_horse_hoofsteps(delta: float) -> void:
	if _horse_hoofsteps_player == null:
		return
	var actual_velocity: Vector3 = get_real_velocity()
	var horse_speed: float = Vector2(actual_velocity.x, actual_velocity.z).length()
	var should_play: bool = is_mounted and game != null and game.phase == "play" and not _dead and is_on_floor() and horse_speed > 0.35
	if should_play:
		if not _horse_hoofsteps_player.playing:
			_horse_hoofsteps_player.volume_db = -60.0
			_horse_hoofsteps_player.pitch_scale = 1.0
			_horse_hoofsteps_player.play()
		# Trota em velocidade normal e acelera suavemente o ritmo durante o galope.
		var gallop_range: float = maxf(0.1, MOUNTED_SPEED * (MOUNTED_RUN_MULT - 1.0))
		var gallop_ratio: float = clampf((horse_speed - MOUNTED_SPEED) / gallop_range, 0.0, 1.0)
		var target_pitch: float = lerpf(1.0, 2.0, gallop_ratio)
		_horse_hoofsteps_player.pitch_scale = lerpf(_horse_hoofsteps_player.pitch_scale, target_pitch, clampf(delta * 6.0, 0.0, 1.0))
		_horse_hoofsteps_player.volume_db = move_toward(_horse_hoofsteps_player.volume_db, HORSE_HOOFSTEPS_VOLUME_DB, HORSE_HOOFSTEPS_FADE_DB_PER_SEC * delta)
	else:
		# Pequeno fade evita estalos ao parar, desmontar, pausar ou morrer.
		if _horse_hoofsteps_player.playing:
			_horse_hoofsteps_player.volume_db = move_toward(_horse_hoofsteps_player.volume_db, -60.0, HORSE_HOOFSTEPS_FADE_DB_PER_SEC * delta)
			if _horse_hoofsteps_player.volume_db <= -59.5:
				_horse_hoofsteps_player.stop()
				_horse_hoofsteps_player.volume_db = -60.0


func _setup_player_sfx() -> void:
	# Carrega somente os efeitos disponíveis e mantém um pequeno pool para que
	# um impacto não corte outro quando golpes rápidos se sobrepõem.
	for key_variant in PLAYER_SFX_PATHS.keys():
		var key := str(key_variant)
		var stream := load(str(PLAYER_SFX_PATHS[key])) as AudioStream
		if stream == null:
			push_warning("Efeito sonoro do jogador não encontrado: %s" % str(PLAYER_SFX_PATHS[key]))
			continue
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
		_player_sfx_streams[key] = stream
	for i in range(PLAYER_SFX_VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "PlayerSFXVoice%d" % i
		voice.bus = "Master"
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_player_sfx_voices.append(voice)


func _play_player_sfx(key: String, randomize_pitch: bool = true) -> void:
	if not _player_sfx_streams.has(key) or _player_sfx_voices.is_empty():
		return
	var voice: AudioStreamPlayer = null
	var count := _player_sfx_voices.size()
	for offset in range(count):
		var idx := (_player_sfx_voice_index + offset) % count
		if not _player_sfx_voices[idx].playing:
			voice = _player_sfx_voices[idx]
			_player_sfx_voice_index = (idx + 1) % count
			break
	# Se todas as vozes estão ocupadas, reutiliza a mais antiga em round-robin.
	if voice == null:
		voice = _player_sfx_voices[_player_sfx_voice_index]
		_player_sfx_voice_index = (_player_sfx_voice_index + 1) % count
	voice.stop()
	voice.stream = _player_sfx_streams[key] as AudioStream
	voice.volume_db = float(PLAYER_SFX_GAIN_DB.get(key, 0.0))
	voice.pitch_scale = randf_range(0.96, 1.04) if randomize_pitch else 1.0
	voice.play()


func _update_footsteps() -> void:
	# A montaria não reproduz passos humanos; no futuro pode receber áudio próprio de cascos.
	if is_mounted:
		_footstep_distance = 0.0
		_last_footstep_position = global_position
		return
	# Mede o deslocamento real após move_and_slide, para não produzir passos ao
	# empurrar uma parede, mexer o mouse, estar no ar ou abrir menus.
	var current_position: Vector3 = global_position
	var displacement: Vector3 = current_position - _last_footstep_position
	_last_footstep_position = current_position

	if game == null or game.phase != "play" or _dead or not is_on_floor():
		_footstep_distance = 0.0
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.25:
		return

	var traveled: float = Vector2(displacement.x, displacement.z).length()
	# Grandes saltos de posição são teletransportes/cargas, não passos normais.
	if traveled > 0.75:
		_footstep_distance = 0.0
		return
	_footstep_distance += traveled

	var sprinting: bool = horizontal_speed > SPEED * 1.25
	var step_distance: float = 1.95 if sprinting else 1.70
	if _footstep_distance >= step_distance:
		_play_player_sfx("footsteps")
		_footstep_distance -= step_distance


func reset_stats() -> void:
	# A ficha é criada uma vez por sessão. Morte/recomeço preserva nível e inventário.
	level = 1
	experience = 0
	attribute_points = 0
	attributes = {"vigor": 5, "strength": 5, "agility": 5, "arcana": 5}
	proficiencies.clear()
	_recalculate_derived_stats()
	hp = max_hp
	mana = max_mana
	# Saldo inicial de teste para comprar a espada no começo.
	gold = 50
	potions = 2
	resources.clear()
	_dead = false
	_cooldown = 0.0
	_cast_cd = 0.0
	_jump_req = false
	weapons = [game._db_find(game.WEAPON_DB, "fist").duplicate()]
	weapon_idx = 0
	armors = [game.ARMOR_DB[0].duplicate()]
	armor_idx = 0
	spells = []
	spell_idx = 0
	active_equipment_type = "weapon"
	consumable_slots = ["potion", "", ""]
	_channel_needs_release = false
	_cast_message_shown_for_hold = false
	_build_weapon_model(cur_weapon()["model"])


func _recalculate_derived_stats() -> void:
	max_hp = MAX_HP + (level - 1) * 5 + (int(attributes.get("vigor", 5)) - 5) * 8
	max_mana = BASE_MANA + float((level - 1) * 3 + (int(attributes.get("arcana", 5)) - 5) * 8)


func get_xp_to_next_level() -> int:
	return level * 100


func gain_experience(amount: int) -> String:
	if amount <= 0:
		return ""
	experience += amount
	var levels_gained := 0
	while experience >= get_xp_to_next_level():
		experience -= get_xp_to_next_level()
		level += 1
		attribute_points += 2
		_recalculate_derived_stats()
		hp = mini(max_hp, hp + 10)
		mana = minf(max_mana, mana + 8.0)
		levels_gained += 1
	if levels_gained > 0:
		return "NÍVEL %d! +%d pontos de atributo." % [level, levels_gained * 2]
	return ""


func spend_attribute_point(attribute: String) -> bool:
	if attribute_points <= 0 or not attributes.has(attribute):
		return false
	var previous_max_hp := max_hp
	var previous_max_mana := max_mana
	attributes[attribute] = int(attributes[attribute]) + 1
	attribute_points -= 1
	_recalculate_derived_stats()
	# Ganhos em Vigor/Arcana também ampliam os recursos atuais, sem curar o jogador por completo.
	hp = mini(max_hp, hp + maxi(0, max_hp - previous_max_hp))
	mana = minf(max_mana, mana + maxf(0.0, max_mana - previous_max_mana))
	return true


func melee_damage_bonus() -> int:
	return maxi(0, int(attributes.get("strength", 5)) - 5) * 2


func spell_damage_bonus() -> int:
	return maxi(0, int(attributes.get("arcana", 5)) - 5) * 2


func critical_chance() -> float:
	return clampf(0.15 + float(int(attributes.get("agility", 5)) - 5) * 0.02, 0.15, 0.45)


func get_proficiency_value(key: String) -> int:
	return int(proficiencies.get(key, 0))


func get_proficiency_rank(key: String) -> int:
	var value := get_proficiency_value(key)
	var rank := 0
	for i in range(1, PROFICIENCY_THRESHOLDS.size()):
		if value >= int(PROFICIENCY_THRESHOLDS[i]):
			rank = i
	return rank


func get_proficiency_next_threshold(key: String) -> int:
	var rank := get_proficiency_rank(key)
	return int(PROFICIENCY_THRESHOLDS[mini(rank + 1, PROFICIENCY_THRESHOLDS.size() - 1)])


func get_proficiency_multiplier(key: String, is_magic: bool) -> float:
	var rank := get_proficiency_rank(key)
	var multipliers: Array = MAGIC_PROFICIENCY_MULTIPLIERS if is_magic else WEAPON_PROFICIENCY_MULTIPLIERS
	return float(multipliers[clampi(rank, 0, multipliers.size() - 1)])


func get_proficiency_rank_name(rank: int) -> String:
	return str(PROFICIENCY_RANK_NAMES[clampi(rank, 0, PROFICIENCY_RANK_NAMES.size() - 1)])


func get_spell_display_name(spell: Dictionary) -> String:
	var spell_id := str(spell.get("id", ""))
	var base_name := str(spell.get("name", "Magia"))
	var rank := get_proficiency_rank("magic_" + spell_id)
	if rank <= 0:
		return base_name
	var suffix := "Potente"
	match spell_id:
		"fire":
			suffix = ["", "Aprimorada", "Potente", "Superior", "Magistral"][rank]
		"lightning":
			suffix = ["", "Aprimorado", "Potente", "Superior", "Magistral"][rank]
		"heal":
			suffix = ["", "Aprimorada", "Potente", "Superior", "Magistral"][rank]
	return "%s %s" % [base_name, suffix]


func get_weapon_proficiency_key(weapon: Dictionary = {}) -> String:
	var target: Dictionary = weapon if not weapon.is_empty() else cur_weapon()
	return "weapon_" + str(target.get("id", "fist"))


func gain_proficiency(key: String, skill_name: String, is_magic: bool, amount: int = 1) -> String:
	if amount <= 0:
		return ""
	var old_rank := get_proficiency_rank(key)
	proficiencies[key] = mini(100, get_proficiency_value(key) + amount)
	var new_rank := get_proficiency_rank(key)
	if new_rank <= old_rank:
		return ""
	if is_magic:
		var spell := {"id": key.trim_prefix("magic_"), "name": skill_name}
		return "A magia evoluiu: %s!" % get_spell_display_name(spell)
	return "Proficiência em %s aumentou: %s." % [skill_name, get_proficiency_rank_name(new_rank)]


func prepare_for_new_attempt() -> void:
	# Recupera o personagem para uma nova tentativa sem apagar progresso da sessão.
	# Só recursos de combate temporários são restaurados; nível, atributos e equipamento permanecem.
	if is_mounted:
		if game != null and game.get("overworld") != null and is_instance_valid(game.get("overworld")) and game.get("overworld").has_method("dismount_horse"):
			game.get("overworld").call("dismount_horse", true)
		else:
			set_mounted_state(false)
	hp = max_hp
	mana = max_mana
	_dead = false
	_cooldown = 0.0
	_cast_cd = 0.0
	_jump_req = false
	velocity = Vector3.ZERO
	if _swing_tween != null and _swing_tween.is_running():
		_swing_tween.kill()
	if weapons.is_empty():
		weapons.append(game._db_find(game.WEAPON_DB, "fist").duplicate())
	weapon_idx = clampi(weapon_idx, 0, weapons.size() - 1)
	if armors.is_empty():
		armors.append(game.ARMOR_DB[0].duplicate())
	armor_idx = clampi(armor_idx, 0, armors.size() - 1)
	if spells.is_empty():
		spell_idx = 0
		if active_equipment_type == "spell":
			active_equipment_type = "weapon"
	else:
		spell_idx = clampi(spell_idx, 0, spells.size() - 1)
	if active_equipment_type == "spell" and not spells.is_empty():
		_build_weapon_model("magic")
	else:
		active_equipment_type = "weapon"
		_build_weapon_model(str(cur_weapon().get("model", "sword")))


func set_mounted_state(mounted: bool) -> void:
	is_mounted = mounted
	_jump_req = false
	_channel_needs_release = true if mounted else false
	_cast_message_shown_for_hold = false
	if cam != null:
		cam.position.y = MOUNTED_CAMERA_HEIGHT if mounted else _camera_height_on_foot
		# A cavalo, a câmera fica nivelada: não é possível mirar para o céu ou para o chão.
		if mounted:
			_pitch = 0.0
			cam.rotation.x = 0.0
	if mounted:
		velocity.y = 0.0
	_horse_frame_index = 0
	_update_horse_view()


func cur_weapon() -> Dictionary:
	return weapons[weapon_idx]


func cur_armor() -> Dictionary:
	return armors[armor_idx]


func armor_value() -> int:
	return int(cur_armor()["def"])


func current_spell() -> Variant:
	if spells.is_empty():
		return null
	return spells[spell_idx]


# Getters usados pela HUD (hud_status.gd e outros). Mantêm a HUD independente das variáveis internas.
func get_hp() -> int:
	return hp

func get_max_hp() -> int:
	return max_hp

func get_mana() -> float:
	return mana

func get_max_mana() -> float:
	return max_mana

func get_gold() -> int:
	return gold

func get_potions() -> int:
	return potions

# Hotbar: as teclas 1, 2 e 3 são reservadas para consumíveis, nunca para magias.
const CONSUMABLE_HOTBAR_SLOTS := 3

func hotbar_size() -> int:
	return CONSUMABLE_HOTBAR_SLOTS

func hotbar_slot(i: int) -> Dictionary:
	if i < 0 or i >= CONSUMABLE_HOTBAR_SLOTS or i >= consumable_slots.size():
		return {}
	var item_id := str(consumable_slots[i])
	if item_id == "potion":
		return {"type": "potion", "item_id": "potion", "index": i}
	return {}

func assign_consumable_slot(slot_index: int, item_id: String) -> void:
	if slot_index < 0 or slot_index >= CONSUMABLE_HOTBAR_SLOTS:
		return
	while consumable_slots.size() < CONSUMABLE_HOTBAR_SLOTS:
		consumable_slots.append("")
	if item_id == "potion":
		# Um tipo de consumível ocupa apenas um espaço rápido por vez.
		for i in range(consumable_slots.size()):
			if consumable_slots[i] == item_id:
				consumable_slots[i] = ""
		consumable_slots[slot_index] = item_id
	else:
		consumable_slots[slot_index] = ""

func use_consumable_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= consumable_slots.size():
		return
	match str(consumable_slots[slot_index]):
		"potion":
			drink_potion()
		"":
			game.show_msg("Esse espaço de consumível está vazio.")
		_:
			game.show_msg("Esse consumível ainda não pode ser usado.")

func add_gold(n: int) -> void:
	gold += n


func add_resource(resource_id: String, amount: int) -> void:
	if resource_id == "" or amount <= 0 or RESOURCE_CATALOG.definition(resource_id).is_empty():
		return
	resources[resource_id] = int(resources.get(resource_id, 0)) + amount


func resource_count(resource_id: String) -> int:
	return int(resources.get(resource_id, 0))


func remove_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var current: int = resource_count(resource_id)
	if current < amount:
		return false
	var remaining: int = current - amount
	if remaining <= 0:
		resources.erase(resource_id)
	else:
		resources[resource_id] = remaining
	return true


func add_potion() -> void:
	potions += 1


func add_weapon(item: Dictionary) -> void:
	weapons.append(item.duplicate())


func add_armor(item: Dictionary) -> void:
	armors.append(item.duplicate())


func learn_spell(id: String) -> bool:
	for known in spells:
		if known["id"] == id:
			return false
	for s in game.SPELL_DB:
		if s["id"] == id:
			spells.append(s.duplicate())
			return true
	return false


func equip_weapon(i: int) -> void:
	if i < 0 or i >= weapons.size():
		return
	weapon_idx = i
	active_equipment_type = "weapon"
	_channel_needs_release = false
	_cast_message_shown_for_hold = false
	_build_weapon_model(str(cur_weapon().get("model", "fist")))
	game.show_msg("Arma equipada: %s." % cur_weapon()["name"])


func cycle_weapon(step: int) -> void:
	if weapons.size() <= 1:
		game.show_msg("Você só tem uma arma. Ache outras pelo caminho.")
		return
	equip_weapon((weapon_idx + step + weapons.size()) % weapons.size())


func equip_armor(i: int) -> void:
	armor_idx = i
	game.show_msg("Armadura equipada: %s (defesa %d)." % [cur_armor()["name"], armor_value()])


func equip_spell(i: int) -> void:
	if i < 0 or i >= spells.size():
		return
	spell_idx = i
	active_equipment_type = "spell"
	_channel_needs_release = false
	_cast_message_shown_for_hold = false
	_build_weapon_model("magic")
	game.show_msg("Magia equipada: %s." % current_spell()["name"])


# Compatibilidade com chamadas antigas: selecionar uma magia agora equipa o modo mágico.
func set_spell(i: int) -> void:
	equip_spell(i)


func cycle_spell() -> void:
	# As magias são escolhidas e equipadas pelo inventário; não são mais alternadas por tecla.
	if active_equipment_type != "spell" or spells.size() <= 1:
		return
	equip_spell((spell_idx + 1) % spells.size())


func drink_potion() -> void:
	if hp >= max_hp:
		return
	if potions <= 0:
		game.show_msg("Você não tem poções.")
		return
	potions -= 1
	hp = mini(max_hp, hp + POTION_HEAL)
	game.show_msg("Poção bebida. Vida recuperada.")


func take_damage(amount: int) -> void:
	if _dead:
		return
	var taken := maxi(1, amount - armor_value())
	hp = maxi(0, hp - taken)
	game.flash_hurt()
	if hp <= 0:
		_dead = true
		game.on_player_died()


func _physics_process(delta: float) -> void:
	if is_mounted:
		_horse_frame_time += delta
		var horse_speed: float = Vector2(velocity.x, velocity.z).length()
		var frame_interval: float = 0.12 if horse_speed > MOUNTED_SPEED * 1.1 else 0.24
		if horse_speed > 0.15 and _horse_frame_time >= frame_interval:
			_horse_frame_time = 0.0
			_horse_frame_index = (_horse_frame_index + 1) % 4
	_update_horse_view()
	var input := Vector2.ZERO
	var speed: float = MOUNTED_SPEED if is_mounted else SPEED
	if game != null and game.phase == "play" and not _dead:
		if Input.is_key_pressed(KEY_W):
			input.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			input.y += 1.0
		if Input.is_key_pressed(KEY_A):
			input.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			input.x += 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= MOUNTED_RUN_MULT if is_mounted else RUN_MULT
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = JUMP_VELOCITY if _jump_req and not is_mounted else 0.0
	else:
		velocity.y -= GRAVITY * delta
	_jump_req = false
	move_and_slide()
	_update_footsteps()
	_update_horse_hoofsteps(delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_cast_cd = maxf(0.0, _cast_cd - delta)
	var magic_button_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not magic_button_held:
		_channel_needs_release = false
		_cast_message_shown_for_hold = false
	if game != null and game.phase == "play" and not _dead:
		mana = minf(max_mana, mana + MANA_REGEN * delta)
		if not is_mounted and active_equipment_type == "spell" and magic_button_held and not _channel_needs_release and _cast_cd <= 0.0:
			var held_spell: Variant = current_spell()
			if held_spell is Dictionary and str(held_spell.get("cast_mode", "instant")) == "repeat":
				_cast()
	_animate_sway(delta)
	_update_fist_overlay_visibility()
	_animate_fist_locomotion(delta)


func _animate_sway(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_mounted:
		# Pequeno balanço de sela para comunicar o trote/ galope sem exagerar o movimento da câmera.
		var bob_rate: float = 12.0 if hspeed > MOUNTED_SPEED * 1.1 else 8.5
		_mounted_bob_t += delta * (bob_rate if hspeed > 0.15 else 1.4)
		var bob_amount: float = 0.025 if hspeed > 0.15 else 0.006
		cam.position.y = MOUNTED_CAMERA_HEIGHT + sin(_mounted_bob_t) * bob_amount
		sway.position = REST_POS
		return
	var amp := clampf(hspeed / SPEED, 0.0, 1.0)
	_bob_t += delta * (2.5 + 4.5 * amp)
	var offset := Vector3(cos(_bob_t * 0.5) * 0.02, absf(sin(_bob_t)) * -0.025, 0.0)
	sway.position = REST_POS + offset * (0.2 + 0.8 * amp)


func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# A loja precisa receber as teclas antes do tratamento geral de Esc.
		# Caso contrário, Esc chama toggle_pause(), que não faz nada na fase "shop".
		if game.phase == "shop" and game.handle_shop_key(event.keycode):
			get_viewport().set_input_as_handled()
			return
		if game.phase == "dialog" and game.handle_dialog_key(event.keycode):
			return
		if game.phase == "quest_log" and (event.keycode == KEY_J or event.keycode == KEY_ESCAPE):
			game.close_quest_log()
			get_viewport().set_input_as_handled()
			return
		if game.phase == "map" and (event.keycode == KEY_M or event.keycode == KEY_ESCAPE):
			game.close_map()
			return
		if event.keycode == KEY_J and game.phase == "play":
			game.open_quest_log()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M and game.phase == "play":
			game.open_map()
			return
		if event.keycode == KEY_ESCAPE:
			game.toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F and game.phase == "play":
			game.try_interact()
			return
		if event.keycode == KEY_I and (game.phase == "play" or game.phase == "inventory"):
			game.toggle_inventory()
			return
	if game.phase != "play" or _dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		if is_mounted:
			# Mantém a visão horizontal durante a montaria; o mouse continua girando para os lados.
			_pitch = 0.0
			cam.rotation.x = 0.0
		else:
			_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)
			cam.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT and active_equipment_type == "spell":
			_cast()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_jump_req = true
		elif event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			use_consumable_slot(0)
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			use_consumable_slot(1)
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			use_consumable_slot(2)


func _attack() -> void:
	# A primeira implementação da montaria prioriza viagem; combate exige desmontar.
	if is_mounted:
		if game != null and game.phase == "play":
			game.show_msg("Desmonte do cavalo para lutar.")
		return
	# A mão mágica ocupa o mesmo espaço da arma e usa o mesmo comando principal.
	if active_equipment_type == "spell":
		_cast()
		return
	if _cooldown > 0.0 or _dead:
		return
	var model := str(cur_weapon().get("model", ""))
	var using_sprite := fist_sprite != null and overlay_weapon_model == model
	# Não interromper o golpe antes do impacto. Depois de acertar, permitir novo
	# ataque assim que o cooldown da arma terminar, mesmo que a animação esteja
	# concluindo os frames finais; isso evita que a animação trave o ritmo do combate.
	if using_sprite and _swing_tween != null and _swing_tween.is_running() and not _sprite_attack_hit:
		return
	_cooldown = float(cur_weapon()["cd"])
	_play_player_sfx("woosh")
	if using_sprite:
		_animate_sprite_weapon(model)
	else:
		_animate_weapon_swing()


func _animate_weapon_swing() -> void:
	if _swing_tween and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	var t := _swing_tween
	# Recuo: a arma vai para trás e para o lado, com desaceleração suave (só visual)
	t.tween_property(swing, "rotation_degrees", WINDUP_ROT, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(swing, "position", WINDUP_POS, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Corte: acelera e avança; o dano sai aqui, no mesmo instante em que a arma cruza
	t.tween_property(swing, "rotation_degrees", SLASH_ROT, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(swing, "position", SLASH_POS, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(_melee_strike)
	# Recuperação: volta à guarda
	t.tween_property(swing, "rotation_degrees", SWING_REST, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(swing, "position", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_sprite_weapon(model: String) -> void:
	# Um sistema único anima punhos, espada, adaga, machado e lança. O dano acontece
	# no frame intermediário (índice 2 em sequências de cinco frames), não no final.
	var frames: Array = _weapon_swing_sprite_frames(model)
	if frames.is_empty() or fist_sprite == null:
		_animate_weapon_swing()
		return
	_fist_motion_x = 0.0
	_fist_motion_rotation = 0.0
	fist_sprite.rotation_degrees = 0.0
	_update_fist_anchor()
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_sprite_attack_hit = false
	var t := _swing_tween
	var impact_frame_index: int = int(frames.size() / 2)
	for i in range(frames.size()):
		var frame_path: String = str(frames[i])
		t.tween_callback(_set_fist_frame.bind(frame_path))
		if i == impact_frame_index:
			# O impacto é aplicado imediatamente após mostrar o frame intermediário.
			t.tween_callback(_sprite_weapon_impact)
		t.tween_interval(0.10)
	t.tween_callback(_finish_sprite_weapon.bind(model))


func _sprite_weapon_impact() -> void:
	# Marca o golpe como já acertado antes de calcular o dano, evitando duplicação.
	_sprite_attack_hit = true
	_melee_strike()


func _finish_sprite_weapon(model: String) -> void:
	_fist_motion_x = 0.0
	_fist_motion_rotation = 0.0
	if fist_sprite != null:
		fist_sprite.rotation_degrees = 0.0
	_set_fist_frame(_weapon_idle_sprite_path(model))



func _animate_fist_locomotion(delta: float) -> void:
	if fist_sprite == null or not is_instance_valid(fist_sprite):
		return
	# O golpe tem prioridade: não misturar o balanço locomotor com os frames de ataque.
	if _swing_tween != null and _swing_tween.is_running():
		return
	if game == null or game.phase != "play" or _dead:
		_fist_motion_x = 0.0
		_fist_motion_rotation = 0.0
		fist_sprite.rotation_degrees = 0.0
		_update_fist_anchor()
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.15:
		# Repouso: movimento quase imperceptível, sem trocar o frame 0-0.
		_fist_motion_t += delta * 1.5
		_fist_motion_x = sin(_fist_motion_t) * 0.8
		_fist_motion_rotation = sin(_fist_motion_t * 0.8) * 0.35
	else:
		var running := horizontal_speed > SPEED * 1.25
		var frequency := 13.0 if running else 8.5
		var horizontal_amplitude := 7.0 if running else 3.5
		var rotation_amplitude := 2.4 if running else 1.2
		_fist_motion_t += delta * frequency
		_fist_motion_x = sin(_fist_motion_t) * horizontal_amplitude
		_fist_motion_rotation = sin(_fist_motion_t + 0.7) * rotation_amplitude
	fist_sprite.rotation_degrees = _fist_motion_rotation
	_update_fist_anchor()


func _set_fist_frame(path: String) -> void:
	if fist_sprite == null:
		return
	var tex := load(path) as Texture2D
	if tex != null:
		fist_sprite.texture = tex
		_update_fist_anchor()


func _update_fist_anchor() -> void:
	if fist_sprite == null or fist_sprite.texture == null or not is_instance_valid(fist_sprite):
		return
	var texture_size := Vector2(fist_sprite.texture.get_size())
	var sprite_scale: float = _weapon_sprite_scale(overlay_weapon_model)
	var right_margin: float = _weapon_sprite_right_margin(overlay_weapon_model)
	var draw_size := texture_size * sprite_scale
	# Mantém o canto inferior direito fixo mesmo quando os frames têm dimensões
	# diferentes; assim a mão não pula pela tela durante a animação.
	fist_sprite.anchor_left = 1.0
	fist_sprite.anchor_right = 1.0
	fist_sprite.anchor_top = 1.0
	fist_sprite.anchor_bottom = 1.0
	fist_sprite.offset_left = -draw_size.x - right_margin + _fist_motion_x
	fist_sprite.offset_right = -right_margin + _fist_motion_x
	fist_sprite.offset_top = -draw_size.y
	fist_sprite.offset_bottom = 0.0
	fist_sprite.size = draw_size
	# O pivô no canto inferior direito mantém a base encostada à borda durante a rotação.
	fist_sprite.pivot_offset = draw_size
	fist_sprite.rotation_degrees = _fist_motion_rotation


func _update_fist_overlay_visibility() -> void:
	if fist_layer == null:
		return
	var model := "magic" if active_equipment_type == "spell" else (str(cur_weapon().get("model", "")) if not weapons.is_empty() else "")
	var is_sprite_weapon := not overlay_weapon_model.is_empty() and overlay_weapon_model == model and fist_sprite != null
	fist_layer.visible = game != null and game.phase == "play" and not _dead and not is_mounted and is_sprite_weapon


func _melee_strike() -> void:
	if _dead or game == null or game.phase != "play":
		return
	var w: Dictionary = cur_weapon()
	var skill_key := get_weapon_proficiency_key(w)
	# A proficiência usada no golpe é fixada no início; subir de nível durante um
	# mesmo ataque só melhora os ataques seguintes.
	var proficiency_multiplier := get_proficiency_multiplier(skill_key, false)
	var targets_hit := _targets_in(float(w["reach"]), float(w["arc"]))
	if not targets_hit.is_empty():
		var weapon_model := str(w.get("model", ""))
		var impact_sfx := "swordhit" if weapon_model == "sword" else "daggerhit" if weapon_model == "dagger" else "hit"
		# Um som de contacto por golpe, mesmo que o cone atinja várias criaturas.
		_play_player_sfx(impact_sfx)
	for e in targets_hit:
		var base_damage := randi_range(int(w["dmg_min"]), int(w["dmg_max"])) + melee_damage_bonus()
		var dmg := maxi(1, roundi(float(base_damage) * proficiency_multiplier))
		if randf() < critical_chance():
			dmg *= 2
			game.show_msg("Golpe crítico!")
		e.take_hit(dmg, _flat_forward())
		# Acertar uma criatura produz sangue no ponto aproximado do impacto.
		_spawn_impact_particles(e.global_position + Vector3(0.0, 0.75, 0.0), _flat_forward(), true)
		var proficiency_message := gain_proficiency(skill_key, str(w.get("name", "Arma")), false)
		if proficiency_message != "":
			game.show_msg(proficiency_message)
	# Se nenhum ser vivo foi atingido, procura uma superfície sólida à frente.
	# Isso evita poeira aparecer junto com sangue no mesmo golpe.
	if targets_hit.is_empty():
		var origin: Vector3 = cam.global_position
		var direction: Vector3 = -cam.global_transform.basis.z.normalized()
		var end: Vector3 = origin + direction * float(w["reach"])
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider: Object = hit.get("collider")
			# Não emitir poeira caso o raio tenha encontrado um inimigo que não
			# entrou no cone de dano; apenas superfícies do cenário recebem poeira.
			if collider is Node and not (collider as Node).is_in_group("enemies"):
				var hit_pos: Vector3 = hit.get("position", end)
				var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
				_play_player_sfx("hit")
				_spawn_impact_particles(hit_pos, hit_normal, false)


func _spawn_impact_particles(origin: Vector3, normal: Vector3, blood: bool) -> void:
	# Partículas leves feitas de pequenas malhas, sem dependência de assets externos.
	# São visuais temporários e não têm colisão.
	if game == null or not is_instance_valid(game):
		return
	var particle_count := 7 if blood else 9
	var particle_color := Color(0.62, 0.035, 0.045, 1.0) if blood else Color(0.56, 0.48, 0.34, 1.0)
	var base_radius := 0.035 if blood else 0.045
	var surface_normal := normal.normalized()
	if surface_normal.length_squared() < 0.01:
		surface_normal = Vector3.UP
	for i in range(particle_count):
		var particle := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(base_radius * 0.55, base_radius * 1.15)
		mesh.height = mesh.radius * 2.0
		particle.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = particle_color.lightened(randf_range(0.0, 0.12))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particle.material_override = material
		game.add_child(particle)
		particle.global_position = origin + surface_normal * 0.025
		var random_dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.15, 1.0), randf_range(-1.0, 1.0)).normalized()
		if not blood:
			random_dir = (random_dir + surface_normal * 0.9).normalized()
		var travel := randf_range(0.12, 0.38) if blood else randf_range(0.16, 0.48)
		var duration := randf_range(0.22, 0.42) if blood else randf_range(0.28, 0.5)
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", particle.global_position + random_dir * travel, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector3.ZERO, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(particle.queue_free)


func _cast() -> void:
	if is_mounted:
		if game != null and game.phase == "play":
			game.show_msg("Desmonte do cavalo para conjurar magias.")
		return
	if _dead or game == null or game.phase != "play" or active_equipment_type != "spell" or _cast_cd > 0.0:
		return
	var spell = current_spell()
	if spell == null:
		game.show_msg("Equipe uma magia pelo inventário.")
		return
	if mana < float(spell["cost"]):
		game.show_msg("Mana insuficiente.")
		_channel_needs_release = true
		return
	var spell_id := str(spell.get("id", ""))
	var repeat_mode := str(spell.get("cast_mode", "instant")) == "repeat"
	var announce_cast := not repeat_mode or not _cast_message_shown_for_hold
	var skill_key := "magic_" + spell_id
	if spell_id == "heal":
		if hp >= max_hp:
			game.show_msg("Sua vida já está cheia.")
			return
		mana -= float(spell["cost"])
		var heal_prof_message := gain_proficiency(skill_key, str(spell.get("name", "Magia")), true)
		var heal_potency := get_proficiency_multiplier(skill_key, true)
		var heal_restored := roundi(float(spell.get("heal", 0)) * heal_potency)
		hp = mini(max_hp, hp + heal_restored)
		_cast_cd = float(spell.get("interval", CAST_COOLDOWN))
		game.show_msg(heal_prof_message if heal_prof_message != "" else "%s: %d de vida recuperados." % [get_spell_display_name(spell), heal_restored])
		return
	# Magias ofensivas são projéteis livres. Cada conjuração válida treina aquela magia;
	# a proficiência aumenta dano e também a presença visual do projétil.
	mana -= float(spell["cost"])
	_cast_cd = float(spell.get("interval", CAST_COOLDOWN))
	if repeat_mode:
		_cast_message_shown_for_hold = true
	var spell_prof_message := gain_proficiency(skill_key, str(spell.get("name", "Magia")), true)
	var spell_potency := get_proficiency_multiplier(skill_key, true)
	var base_damage := randi_range(int(spell["dmg_min"]), int(spell["dmg_max"])) + spell_damage_bonus()
	var dmg := maxi(1, roundi(float(base_damage) * spell_potency))
	var spell_range: float = float(spell.get("range", 16.0))
	# As magias nascem na posição visual da mão e convergem para o ponto sob a mira.
	# Primeiro usamos a linha central da câmera para descobrir o ponto que o jogador mira;
	# depois calculamos a direção real desde a mão até esse ponto.
	var launch_position: Vector3 = _get_magic_launch_position()
	var aim_point: Vector3 = _get_magic_aim_point(spell_range)
	var direction: Vector3 = (aim_point - launch_position).normalized()
	if direction.length_squared() < 0.001:
		direction = -cam.global_transform.basis.z.normalized()
	var spell_color: Color = spell.get("color", Color(0.8, 0.5, 1.0))
	var proficiency_rank: int = get_proficiency_rank(skill_key)
	if spell_id == "lightning":
		# Relâmpago é um golpe instantâneo em zigue-zague, com ramificações e clarão.
		# Só a linha principal calcula acerto; os ramos são puramente visuais.
		var strike := Node3D.new()
		strike.set_script(load("res://scripts/lightning_strike.gd"))
		game.add_child(strike)
		strike.call("strike", self, launch_position, direction, spell_range, dmg, spell_color, proficiency_rank)
		if spell_prof_message != "" or announce_cast:
			game.show_msg(spell_prof_message if spell_prof_message != "" else "%s lançada." % get_spell_display_name(spell))
		return
	var projectile := Node3D.new()
	projectile.set_script(load("res://scripts/magic_projectile.gd"))
	projectile.set("source_player", self)
	projectile.set("direction", direction)
	projectile.set("max_range", float(spell.get("range", 16.0)))
	projectile.set("damage", dmg)
	projectile.set("color", spell_color)
	projectile.set("spell_id", spell_id)
	projectile.set("proficiency_rank", proficiency_rank)
	projectile.set("speed", 15.0)
	game.add_child(projectile)
	projectile.global_position = launch_position
	if spell_prof_message != "" or announce_cast:
		game.show_msg(spell_prof_message if spell_prof_message != "" else "%s lançada." % get_spell_display_name(spell))


func _get_magic_launch_position() -> Vector3:
	# Aproxima a origem 3D do ponto inferior-direito onde o sprite da mão aparece.
	# Se a arma atual não usa sprite 2D, usa uma posição de mão consistente na viewport.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var hand_screen: Vector2 = Vector2(viewport_size.x * 0.84, viewport_size.y * 0.88)
	if fist_sprite != null and is_instance_valid(fist_sprite) and fist_sprite.size.x > 0.0 and fist_sprite.size.y > 0.0:
		var hand_local_point: Vector2 = Vector2(fist_sprite.size.x * 0.88, fist_sprite.size.y * 0.88)
		hand_screen = fist_sprite.get_global_transform_with_canvas() * hand_local_point
	hand_screen.x = clampf(hand_screen.x, 1.0, viewport_size.x - 1.0)
	hand_screen.y = clampf(hand_screen.y, 1.0, viewport_size.y - 1.0)
	return cam.project_position(hand_screen, 0.72)


func _get_magic_aim_point(max_range: float) -> Vector3:
	# Mira usando o centro da tela; isso permite que o projétil saia da mão,
	# mas ainda alcance o ponto que o jogador está mirando.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center_screen: Vector2 = viewport_size * 0.5
	var ray_origin: Vector3 = cam.project_ray_origin(center_screen)
	var ray_direction: Vector3 = cam.project_ray_normal(center_screen).normalized()
	var aim_point: Vector3 = ray_origin + ray_direction * maxf(0.5, max_range)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, aim_point)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Variant = hit.get("position", aim_point)
		if hit_position is Vector3:
			aim_point = hit_position
	return aim_point


func _find_target(reach: float, arc_deg: float) -> Node3D:
	var origin := cam.global_position
	var best: Node3D = null
	var best_d := 0.0
	for e in _targets_in(reach, arc_deg):
		var d: float = origin.distance_to(e.global_position)
		if best == null or d < best_d:
			best = e
			best_d = d
	return best


func _targets_in(reach: float, arc_deg: float) -> Array:
	# Inimigos em um cone à frente da câmera, dentro do alcance e sem parede no meio
	var out: Array = []
	var flat_fwd := _flat_forward()
	var origin := cam.global_position
	var space := get_world_3d().direct_space_state
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var target: Vector3 = e.global_position + Vector3(0.0, 0.9, 0.0)
		var to_t := target - origin
		var flat := Vector3(to_t.x, 0.0, to_t.z)
		if flat.length() < 0.01 or flat.length() > reach:
			continue
		if rad_to_deg(flat_fwd.angle_to(flat.normalized())) > arc_deg:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, target)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		if r.size() > 0 and r["collider"] != e:
			continue
		out.append(e)
	return out


func _flat_forward() -> Vector3:
	var fwd := -cam.global_transform.basis.z
	return Vector3(fwd.x, 0.0, fwd.z).normalized()


func _tracer(from: Vector3, to: Vector3, col: Color) -> void:
	# Rastro visual da magia: uma barra fina que some em instantes
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, from.distance_to(to))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.mesh = bm
	mi.material_override = m
	game.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


func _build_weapon_model(model: String) -> void:
	if _swing_tween != null and _swing_tween.is_running():
		_swing_tween.kill()
	for c in weapon_root.get_children():
		c.queue_free()
	if fist_sprite != null and is_instance_valid(fist_sprite):
		fist_sprite.queue_free()
	fist_sprite = null
	overlay_weapon_model = ""
	if _has_weapon_sprite_resources(model):
		overlay_weapon_model = model
		fist_sprite = TextureRect.new()
		fist_sprite.name = "FirstPersonWeaponSprite"
		fist_sprite.texture = load(_weapon_idle_sprite_path(model)) as Texture2D
		fist_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fist_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		fist_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fist_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fist_layer.add_child(fist_sprite)
		_update_fist_anchor()
		swing.rotation_degrees = Vector3.ZERO
		swing.position = Vector3.ZERO
		_update_fist_overlay_visibility()
		return
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.78, 0.8, 0.85)
	metal.metallic = 0.9
	metal.roughness = 0.25
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3, 0.18, 0.1)
	leather.roughness = 0.9
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.85, 0.68, 0.3)
	gold_mat.metallic = 0.9
	gold_mat.roughness = 0.35
	match model:
		"dagger":
			_box(weapon_root, Vector3(0, 0, 0.08), Vector3(0.045, 0.045, 0.16), leather)
			_box(weapon_root, Vector3(0, 0, 0), Vector3(0.14, 0.04, 0.05), gold_mat)
			_box(weapon_root, Vector3(0, 0, -0.27), Vector3(0.04, 0.012, 0.5), metal)
		"axe":
			_box(weapon_root, Vector3(0, 0, -0.1), Vector3(0.05, 0.05, 0.7), leather)
			_box(weapon_root, Vector3(0, 0.08, -0.42), Vector3(0.04, 0.22, 0.2), metal)
			_box(weapon_root, Vector3(0, 0, 0.27), Vector3(0.07, 0.07, 0.07), gold_mat)
		"spear":
			_box(weapon_root, Vector3(0, 0, -0.35), Vector3(0.04, 0.04, 1.6), leather)
			_box(weapon_root, Vector3(0, 0, -1.3), Vector3(0.05, 0.05, 0.3), metal)
		_:
			_box(weapon_root, Vector3(0, 0, 0.1), Vector3(0.05, 0.05, 0.22), leather)
			_box(weapon_root, Vector3(0, 0, 0), Vector3(0.24, 0.05, 0.06), gold_mat)
			_box(weapon_root, Vector3(0, 0, 0.23), Vector3(0.07, 0.07, 0.07), gold_mat)
			_box(weapon_root, Vector3(0, 0, -0.55), Vector3(0.05, 0.015, 0.9), metal)
	_update_fist_overlay_visibility()


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

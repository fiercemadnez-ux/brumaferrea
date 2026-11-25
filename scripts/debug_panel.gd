extends Control

const UiFrame := preload("res://scripts/ui_frame.gd")

var game = null
var _button: Button
var _blocker: ColorRect
var _panel: PanelContainer
var _summary: Label
var _live: Label
var _log: Label
var _open := false
var _refresh_timer := 0.0
var _restore_mouse_capture := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_set_open(false)


func _build_ui() -> void:
	_blocker = ColorRect.new()
	_blocker.name = "DebugInputBlocker"
	_blocker.color = Color(0.0, 0.0, 0.0, 0.16)
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	add_child(_blocker)

	_button = Button.new()
	_button.name = "DebugToggleButton"
	_button.text = "DEBUG  [F3]"
	_button.tooltip_text = "Inspecionar rotinas, conversas, memórias e acontecimentos do mundo"
	_button.anchor_left = 1.0
	_button.anchor_right = 1.0
	_button.anchor_top = 0.0
	_button.anchor_bottom = 0.0
	_button.offset_left = -172.0
	_button.offset_right = -18.0
	_button.offset_top = 14.0
	_button.offset_bottom = 48.0
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 15)
	_button.add_theme_color_override("font_color", Color(0.96, 0.85, 0.6))
	_button.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.06, 0.05, 0.92)))
	_button.add_theme_stylebox_override("hover", _button_style(Color(0.19, 0.14, 0.08, 0.98)))
	_button.add_theme_stylebox_override("pressed", _button_style(Color(0.28, 0.19, 0.08, 1.0)))
	_button.pressed.connect(_toggle)
	add_child(_button)

	_panel = PanelContainer.new()
	_panel.name = "DebugWindow"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -650.0
	_panel.offset_right = -18.0
	_panel.offset_top = 58.0
	_panel.offset_bottom = -20.0
	_panel.custom_minimum_size = Vector2(610.0, 470.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.visible = false
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "VEL'MORAH  /  DEBUG DA SIMULAÇÃO"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_font_override("font", UiFrame.font())
	title.add_theme_color_override("font_color", Color(0.94, 0.76, 0.38))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "FECHAR"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.pressed.connect(_toggle)
	header.add_child(close_button)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_font_size_override("font_size", 14)
	_summary.add_theme_color_override("font_color", Color(0.87, 0.84, 0.75))
	outer.add_child(_summary)

	_live = Label.new()
	_live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live.custom_minimum_size = Vector2(0, 94)
	_live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live.add_theme_font_size_override("font_size", 13)
	_live.add_theme_color_override("font_color", Color(0.73, 0.86, 0.76))
	outer.add_child(_live)

	var log_title := Label.new()
	log_title.text = "REGISTRO RECENTE  ·  acontecimentos, rotinas e falas"
	log_title.add_theme_font_size_override("font_size", 13)
	log_title.add_theme_color_override("font_color", Color(0.94, 0.76, 0.38))
	outer.add_child(log_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("font_size", 12)
	_log.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	scroll.add_child(_log)


func _button_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = Color(0.52, 0.39, 0.19, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6.0)
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.032, 0.028, 0.97)
	style.border_color = Color(0.42, 0.32, 0.17, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14.0)
	return style


func _process(delta: float) -> void:
	_button.visible = game != null and (str(game.phase) == "play" or _open)
	if _open and game != null and str(game.phase) != "play":
		_set_open(false, false)
	if not _open:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.35:
		_refresh_timer = 0.0
		_refresh_snapshot()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F3 and game != null and str(game.phase) == "play":
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and _open:
		_set_open(false)
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_set_open(not _open)


func _set_open(value: bool, restore_mouse: bool = true) -> void:
	_open = value
	_blocker.visible = _open
	_panel.visible = _open
	if _open:
		_restore_mouse_capture = game != null and str(game.phase) == "play"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_snapshot()
	else:
		if restore_mouse and _restore_mouse_capture and game != null and str(game.phase) == "play":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_restore_mouse_capture = false


func _refresh_snapshot() -> void:
	if _summary == null or game == null:
		return
	var snapshot: Dictionary = {}
	if game.overworld != null and is_instance_valid(game.overworld) and game.overworld.has_method("get_npc_debug_snapshot"):
		snapshot = game.overworld.get_npc_debug_snapshot()
	if snapshot.is_empty():
		_summary.text = "O mundo ainda não inicializou o sistema de NPCs. Comece uma sessão no mundo aberto."
		_live.text = "Sem dados de simulação."
		_log.text = "Nenhum evento registrado ainda."
		return
	var hour_total := float(snapshot.get("clock_hour", 0.0))
	var hour := posmod(int(floor(hour_total)), 24)
	var minute := int(floor((hour_total - floor(hour_total)) * 60.0))
	var counts: Dictionary = snapshot.get("activity_counts", {})
	var relation_counts: Dictionary = snapshot.get("relationship_counts", {})
	var sessions_for_count: Array = snapshot.get("sessions", [])
	_summary.text = "LOCAL: %s  ·  HORA SIMULADA: %02d:%02d\n" % [str(snapshot.get("city_name", "desconhecido")), hour, minute]
	_summary.text += "NPCs: %d total  |  %d ativos perto do jogador  |  %d visíveis  |  %d em casa  |  %d trabalhando\n" % [int(snapshot.get("npc_count", 0)), int(snapshot.get("active_count", 0)), int(snapshot.get("visible_count", 0)), int(snapshot.get("home_count", 0)), int(snapshot.get("work_count", 0))]
	_summary.text += "CONVERSAS: %d NPCs envolvidos  |  %d sessões em andamento  |  memórias de acontecimentos: %d\n" % [int(snapshot.get("conversation_count", 0)), sessions_for_count.size(), int(snapshot.get("known_event_count", 0))]
	_summary.text += "RELAÇÕES registradas: %d  ·  conhecidos %d  ·  amigos %d  ·  grandes amigos %d  ·  casais %d\n" % [int(snapshot.get("relationship_count", 0)), int(relation_counts.get("acquaintance", 0)), int(relation_counts.get("friend", 0)), int(relation_counts.get("close_friend", 0)), int(relation_counts.get("partner", 0))]
	_summary.text += "ROTINAS: casa %d · trabalho %d · cidade %d · patrulha %d · arredores/estradas %d  |  mensageiros: %d" % [int(counts.get("home", 0)), int(counts.get("work", 0)), int(counts.get("town", 0)), int(counts.get("patrol", 0)), int(counts.get("outskirts", 0)), int(snapshot.get("messenger_count", 0))]
	if not bool(snapshot.get("news_transport_active", false)):
		_summary.text += "\nNOTÍCIAS ENTRE CIDADES: transporte por mensageiros ainda não implementado."

	var live_text := "NPCs PRÓXIMOS (até 75 m)\n"
	var nearby: Array = snapshot.get("nearby_npcs", [])
	if nearby.is_empty():
		live_text += "Nenhum NPC dentro do raio de inspeção."
	else:
		for index in range(mini(nearby.size(), 8)):
			var npc: Dictionary = nearby[index]
			live_text += "• %s — %s — %s — %.0f m — memórias: %d\n" % [str(npc.get("name", "Habitante")), str(npc.get("role", "aldeão")), str(npc.get("state", "desconhecido")), float(npc.get("distance", 0.0)), int(npc.get("memories", 0))]
			var summaries: Array = npc.get("memory_summaries", [])
			for summary in summaries:
				live_text += "    ↳ %s\n" % str(summary)
		if nearby.size() > 8:
			live_text += "  ...e mais %d habitantes próximos.\n" % (nearby.size() - 8)
	var sessions: Array = snapshot.get("sessions", [])
	if not sessions.is_empty():
		live_text += "\nCONVERSAS ATIVAS\n"
		for index in range(mini(sessions.size(), 3)):
			var session: Dictionary = sessions[index]
			var names: Array = session.get("participants", [])
			live_text += "• %s ↔ %s | assunto: %s | turno %d/%d\n" % [str(names[0]) if names.size() > 0 else "?", str(names[1]) if names.size() > 1 else "?", str(session.get("topic", "cotidiano")), int(session.get("turn", 0)), int(session.get("total_turns", 0))]
			live_text += "  %s: %s\n" % [str(session.get("speaker", "")), str(session.get("line", ""))]
		if sessions.size() > 3:
			live_text += "  ...e mais %d conversas em andamento.\n" % (sessions.size() - 3)
	_live.text = live_text

	var entries: Array = snapshot.get("recent_log", [])
	if entries.is_empty():
		_log.text = "Aguardando acontecimentos..."
	else:
		var recent: Array = []
		for i in range(maxi(0, entries.size() - 32), entries.size()):
			recent.append(str(entries[i]))
		_log.text = "\n".join(recent)

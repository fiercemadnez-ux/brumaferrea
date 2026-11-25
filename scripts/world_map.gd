extends Control

const WORLD_NAMES := preload("res://scripts/world_names.gd")
# Mapa interativo de Brumaférrea: navegação livre, seleção de locais e marcador de bússola.

const SETTLE_COL := Color(0.95, 0.85, 0.5)
const CRYPT_COL := Color(0.9, 0.25, 0.25)
const QUEST_COL := Color(1.0, 0.72, 0.20)
const PLAYER_COL := Color(0.4, 0.8, 1.0)
const MARKER_COL := Color(0.35, 1.0, 0.62)
const OUTLINE_COL := Color(0.03, 0.03, 0.03, 0.96)
const MAX_ZOOM := 9.0
const ZOOM_STEP := 1.35
const BUILDING_SHOW_ZOOM := 1.55
const BUILDING_LABEL_ZOOM := 4.2
const HOUSE_SHOW_ZOOM := 6.0
const BUILDING_SYMBOLS := {
	"house": "⌂", "shop": "L", "workshop": "F", "inn": "E", "tavern": "T",
	"town_hall": "C", "temple": "†", "library": "B", "infirmary": "+",
	"guard_post": "G", "lookout": "V", "depot": "D", "shelter": "A",
	"stable": "S", "mill": "M", "barn": "H", "well": "○", "ruin": "×"
}
const BUILDING_KIND_LABELS := {
	"house": "Residência", "shop": "Comércio", "workshop": "Oficina", "inn": "Estalagem", "tavern": "Taverna",
	"town_hall": "Salão comunal", "temple": "Templo", "library": "Biblioteca",
	"infirmary": "Enfermaria", "guard_post": "Posto da guarda", "lookout": "Mirante",
	"depot": "Depósito", "shelter": "Abrigo", "stable": "Estábulo", "mill": "Moinho",
	"barn": "Celeiro", "well": "Poço", "ruin": "Ruína"
}
const KIND_COLORS := {
	"rat": Color(0.6, 0.9, 0.4, 0.72), "goblin": Color(0.3, 0.85, 0.7, 0.72),
	"bat": Color(0.75, 0.5, 0.95, 0.72), "skel": Color(0.85, 0.85, 0.9, 0.72),
	"orc": Color(0.95, 0.5, 0.2, 0.8)
}

var game = null
var zoom_level: float = 1.0
var focus_city_id: String = ""
var _view_center := Vector3.ZERO
var _focus_center := Vector3.ZERO
var _map_rect := Rect2()
var _map_scale: float = 1.0
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_center := Vector3.ZERO
var _drag_moved := false
var _selected_location: Dictionary = {}
var _marker_button_rect := Rect2()
var _clear_marker_button_rect := Rect2()
var _cached_city_buildings: Array = []
var _cached_city_building_id := ""


func focus_player_city() -> void:
	# Abre com foco regional na cidade do jogador; o continente inteiro continua
	# disponível ao afastar o zoom ou arrastar o mapa.
	zoom_level = 2.0
	focus_city_id = ""
	_view_center = Vector3.ZERO
	_focus_center = Vector3.ZERO
	_cached_city_buildings.clear()
	_cached_city_building_id = ""
	_dragging = false
	var ow = game.overworld if game != null else null
	if ow == null:
		return
	var society = ow.get("_npc_society")
	var inside_building: bool = bool(ow.get("_inside_building"))
	var active_building: Dictionary = ow.get("_active_building_record")
	if inside_building and not active_building.is_empty():
		focus_city_id = str(active_building.get("city_id", ""))
	elif society != null and game.player != null and society.has_method("find_nearest_city"):
		focus_city_id = str(society.call("find_nearest_city", game.player.global_position))
	if society != null and focus_city_id != "" and society.cities.has(focus_city_id):
		_focus_center = society.cities[focus_city_id].get("center", ow.map_center)
	else:
		_focus_center = ow.map_center
	_view_center = _focus_center
	_select_location({"type": "city", "id": focus_city_id, "name": _city_name_for_id(ow, focus_city_id), "position": _focus_center, "description": _city_description(focus_city_id)})
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			if _map_rect.has_point(mouse_event.position):
				if zoom_level <= 1.001:
					_view_center = _focus_center
				zoom_level = minf(MAX_ZOOM, zoom_level * ZOOM_STEP)
				accept_event()
				queue_redraw()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			if _map_rect.has_point(mouse_event.position):
				zoom_level = maxf(1.0, zoom_level / ZOOM_STEP)
				if zoom_level <= 1.02:
					zoom_level = 1.0
					var ow = game.overworld if game != null else null
					if ow != null:
						_view_center = ow.map_center
				accept_event()
				queue_redraw()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if _marker_button_rect.has_point(mouse_event.position):
					_set_compass_marker()
					accept_event()
					queue_redraw()
					return
				if _clear_marker_button_rect.has_point(mouse_event.position):
					_clear_compass_marker()
					accept_event()
					queue_redraw()
					return
				if _map_rect.has_point(mouse_event.position):
					_dragging = true
					_drag_start = mouse_event.position
					_drag_center = _view_center
					_drag_moved = false
					accept_event()
					return
			else:
				if _dragging:
					_dragging = false
					if not _drag_moved:
						_select_from_map(mouse_event.position)
					accept_event()
					queue_redraw()
				return
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _drag_start
		if delta.length() > 5.0:
			_drag_moved = true
		var units_per_pixel: float = _world_units_per_pixel()
		_view_center = _drag_center + Vector3(-delta.x * units_per_pixel, 0.0, -delta.y * units_per_pixel)
		_clamp_view_center()
		accept_event()
		queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.018, 0.016, 0.97), true)
	var font := get_theme_default_font()
	draw_string(font, Vector2(24, 42), "MAPA DE BRUMAFÉRREA", HORIZONTAL_ALIGNMENT_LEFT, 440, 27, Color(0.9, 0.75, 0.48))
	draw_string(font, Vector2(size.x - 28, 39), "M / Esc  ·  Fechar", HORIZONTAL_ALIGNMENT_RIGHT, 210, 14, Color(0.65, 0.61, 0.54))
	var ow = game.overworld if game != null else null
	if ow == null or ow.map_texture == null or ow.map_extent <= 0.0:
		draw_string(font, Vector2(24, 100), "Mapa indisponível", HORIZONTAL_ALIGNMENT_LEFT, 300, 20, Color(0.75, 0.7, 0.62))
		return

	_draw_information_panel(ow, font)
	var map_left := 326.0
	var right_margin := 28.0
	var top_margin := 66.0
	var bottom_margin := 48.0
	var available := Vector2(maxf(120.0, size.x - map_left - right_margin), maxf(120.0, size.y - top_margin - bottom_margin))
	var side := minf(available.x, available.y)
	var map_top_left := Vector2(map_left, top_margin) + (available - Vector2(side, side)) * 0.5
	_map_rect = Rect2(map_top_left, Vector2(side, side))
	var texture_size := Vector2(ow.map_texture.get_size())
	var safe_zoom: float = maxf(1.0, zoom_level)
	var source_size := texture_size / safe_zoom
	if safe_zoom <= 1.001:
		_view_center = ow.map_center
	else:
		_clamp_view_center()
	var source_center := Vector2(
		((( _view_center.x - ow.map_center.x) / ow.map_extent) + 0.5) * texture_size.x,
		((( _view_center.z - ow.map_center.z) / ow.map_extent) + 0.5) * texture_size.y
	)
	var source_rect := Rect2(source_center - source_size * 0.5, source_size)
	source_rect.position.x = clampf(source_rect.position.x, 0.0, maxf(0.0, texture_size.x - source_size.x))
	source_rect.position.y = clampf(source_rect.position.y, 0.0, maxf(0.0, texture_size.y - source_size.y))
	var actual_source_center := source_rect.position + source_rect.size * 0.5
	_view_center = Vector3(
		ow.map_center.x + (actual_source_center.x / texture_size.x - 0.5) * ow.map_extent,
		ow.map_center.y,
		ow.map_center.z + (actual_source_center.y / texture_size.y - 0.5) * ow.map_extent
	)
	_map_scale = side / ow.map_extent * safe_zoom
	draw_texture_rect_region(ow.map_texture, _map_rect, source_rect, Color.WHITE, false, true)
	draw_rect(_map_rect, Color(0.45, 0.35, 0.2), false, 2.0)

	# Marcadores sem rótulos sobrepostos; os nomes e detalhes aparecem no painel lateral.
	for st_value in ow.settlement_points:
		var st: Dictionary = st_value
		var point := _to_screen(st.get("pos", Vector3.ZERO), _map_scale, _map_rect)
		if not _map_rect.has_point(point):
			continue
		var chosen := str(_selected_location.get("id", "")) == str(st.get("id", "")) and str(_selected_location.get("type", "")) == "city"
		draw_circle(point, 8.0 if chosen else 6.0, OUTLINE_COL)
		draw_circle(point, 5.5 if chosen else 3.8, Color(1.0, 0.84, 0.45) if chosen else SETTLE_COL)
		if chosen:
			draw_arc(point, 11.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.7), 1.5)

	# Pontos de interesse do modelo (ruínas, marcos, locais especiais) e áreas de coleta.
	var society = ow.get("_npc_society")
	if society != null and society.has_method("get_map_features"):
		for feature_value in society.call("get_map_features"):
			if not (feature_value is Dictionary):
				continue
			var feature: Dictionary = feature_value
			var feature_kind := str(feature.get("kind", "poi"))
			if feature_kind.begins_with("resource_") and safe_zoom < 2.4:
				continue
			var feature_pos: Vector3 = feature.get("position", Vector3.ZERO)
			var feature_screen := _to_screen(feature_pos, _map_scale, _map_rect)
			if not _map_rect.has_point(feature_screen):
				continue
			var is_selected_feature := str(_selected_location.get("id", "")) == str(feature.get("id", ""))
			if feature_kind == "inn":
				# Marcador E dourado identifica a estalagem em qualquer escala do mapa.
				var inn_radius := 7.0 if is_selected_feature else 6.0
				draw_circle(feature_screen, inn_radius + 1.5, OUTLINE_COL)
				draw_circle(feature_screen, inn_radius, Color(0.4, 1.0, 0.65) if is_selected_feature else Color(0.92, 0.70, 0.27))
				draw_string(font, feature_screen + Vector2(-4.5, 4.0), "E", HORIZONTAL_ALIGNMENT_CENTER, 9.0, 11, Color(0.08, 0.06, 0.025))
			else:
				var feature_color := Color(0.72, 0.48, 0.95) if not feature_kind.begins_with("resource_") else Color(0.40, 0.88, 0.65)
				draw_circle(feature_screen, 6.0 if is_selected_feature else 4.5, OUTLINE_COL)
				draw_circle(feature_screen, 4.1 if is_selected_feature else 2.8, Color(0.4, 1.0, 0.65) if is_selected_feature else feature_color)
			if is_selected_feature:
				draw_arc(feature_screen, 9.5 if feature_kind == "inn" else 8.0, 0.0, TAU, 24, Color(0.85, 1.0, 0.86), 1.4)

	if safe_zoom >= BUILDING_SHOW_ZOOM:
		_draw_city_buildings(ow, _map_rect, _map_scale, font, safe_zoom)

	# Criptas descobertas são selecionáveis e aparecem como losangos vermelhos.
	for entrance in ow.entrances:
		if not is_instance_valid(entrance) or not bool(entrance.get_meta("discovered", false)):
			continue
		var p := _to_screen(entrance.global_position, _map_scale, _map_rect)
		if not _map_rect.has_point(p):
			continue
		var diamond := PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0), p + Vector2(0, -8)])
		draw_colored_polygon(PackedVector2Array(diamond.slice(0, 4)), CRYPT_COL)
		draw_polyline(diamond, Color(1.0, 0.88, 0.72), 1.2)

	# Realça a seleção mesmo quando o clique foi num ponto sem ícone próprio.
	if _selected_location.has("position"):
		var selected_map_point: Vector3 = _selected_location.get("position", Vector3.ZERO)
		var selected_map_screen := _to_screen(selected_map_point, _map_scale, _map_rect)
		if _map_rect.has_point(selected_map_screen):
			draw_arc(selected_map_screen, 12.0, 0.0, TAU, 32, Color(0.95, 0.97, 0.85, 0.95), 1.5)

	# Marcador personalizado persistente durante a sessão, sempre visível no mapa.
	if game.navigation_marker_active:
		var marker_point := _to_screen(game.navigation_marker_position, _map_scale, _map_rect)
		if _map_rect.has_point(marker_point):
			_draw_waypoint(marker_point, 12.0, MARKER_COL)

	# Objetivo de missão.
	if game.quest_manager != null:
		var quest: Dictionary = game.quest_manager.get_tracked_quest()
		if not quest.is_empty():
			var quest_pos: Vector3 = quest.get("map_marker_position", Vector3.ZERO)
			var qp := _to_screen(quest_pos, _map_scale, _map_rect)
			if _map_rect.has_point(qp):
				_draw_star(qp, 10.0, QUEST_COL)


	# Posição e direção do jogador.
	var pl = game.player
	if pl != null and not bool(ow.get("_inside_building")):
		var pp := _to_screen(pl.global_position, _map_scale, _map_rect)
		if _map_rect.has_point(pp):
			var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, pl.rotation.y)
			var dir := Vector2(fwd.x, fwd.z).normalized()
			var side_v := Vector2(-dir.y, dir.x)
			var tri := PackedVector2Array([pp + dir * 13.0, pp - dir * 6.5 + side_v * 7.0, pp - dir * 6.5 - side_v * 7.0])
			draw_colored_polygon(tri, PLAYER_COL)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 1.2)

	var n_pos := Vector2(_map_rect.get_center().x - 6.0, _map_rect.position.y + 22.0)
	draw_string(font, n_pos, "N", HORIZONTAL_ALIGNMENT_LEFT, 18.0, 18, Color(1.0, 0.95, 0.75))
	_draw_regional_threat_panel(ow, _map_rect, font)
	draw_string(font, Vector2(_map_rect.position.x, size.y - 17.0), "Arraste para explorar · Roda do mouse para aproximar · Clique num local para ver detalhes", HORIZONTAL_ALIGNMENT_LEFT, _map_rect.size.x, 14, Color(0.7, 0.65, 0.55))


func _draw_information_panel(ow, font: Font) -> void:
	var panel_rect := Rect2(Vector2(18.0, 66.0), Vector2(286.0, maxf(250.0, size.y - 112.0)))
	draw_rect(panel_rect, Color(0.055, 0.05, 0.043, 0.98), true)
	draw_rect(panel_rect, Color(0.38, 0.30, 0.19, 0.98), false, 1.5)
	var x := panel_rect.position.x + 16.0
	var y := panel_rect.position.y + 28.0
	var text_width := panel_rect.size.x - 32.0
	draw_string(font, Vector2(x, y), "LOCAL SELECIONADO", HORIZONTAL_ALIGNMENT_LEFT, text_width, 13, Color(0.72, 0.61, 0.43))
	y += 35.0
	var selected_name := str(_selected_location.get("name", "Brumaférrea"))
	draw_string(font, Vector2(x, y), selected_name, HORIZONTAL_ALIGNMENT_LEFT, text_width, 22, Color(0.95, 0.87, 0.70))
	y += 24.0
	var type_label := str(_selected_location.get("type_label", _type_label(str(_selected_location.get("type", "region")))))
	draw_string(font, Vector2(x, y), type_label, HORIZONTAL_ALIGNMENT_LEFT, text_width, 13, Color(0.67, 0.73, 0.66))
	y += 27.0
	draw_line(Vector2(x, y), Vector2(x + text_width, y), Color(0.30, 0.26, 0.20), 1.0)
	y += 22.0
	var description := str(_selected_location.get("description", "Selecione uma cidade ou um ponto do mapa."))
	var lines := _wrap_text(description, font, text_width, 15)
	for line in lines:
		draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, text_width, 15, Color(0.82, 0.79, 0.71))
		y += 20.0
	if _selected_location.has("position"):
		var pos: Vector3 = _selected_location.get("position", Vector3.ZERO)
		var coords := "Coordenadas: %.0f, %.0f" % [pos.x, pos.z]
		if y < panel_rect.end.y - 72.0:
			y += 16.0
			draw_string(font, Vector2(x, y), coords, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, Color(0.57, 0.54, 0.48))
		var button_y: float = panel_rect.end.y - 66.0
		_marker_button_rect = Rect2(Vector2(x, button_y), Vector2(text_width, 31.0))
		draw_rect(_marker_button_rect, Color(0.15, 0.25, 0.18), true)
		draw_rect(_marker_button_rect, Color(0.36, 0.67, 0.43), false, 1.2)
		draw_string(font, Vector2(x + 9.0, button_y + 20.0), "Marcar na bússola", HORIZONTAL_ALIGNMENT_LEFT, text_width - 18.0, 14, Color(0.75, 1.0, 0.78))
		_clear_marker_button_rect = Rect2(Vector2(x, button_y + 37.0), Vector2(text_width, 24.0))
		if game.navigation_marker_active:
			draw_string(font, Vector2(x + 9.0, button_y + 54.0), "Remover marcador", HORIZONTAL_ALIGNMENT_LEFT, text_width - 18.0, 12, Color(0.78, 0.70, 0.58))
		else:
			_clear_marker_button_rect = Rect2()
	else:
		_marker_button_rect = Rect2()
		_clear_marker_button_rect = Rect2()


func _draw_city_buildings(ow, map_rect: Rect2, scale: float, font: Font, current_zoom: float) -> void:
	var society = ow.get("_npc_society")
	if society == null or not society.has_method("get_city_buildings"):
		return
	var visible_city_id := _nearest_city_id(ow, _view_center)
	if visible_city_id.is_empty():
		visible_city_id = focus_city_id
	if _cached_city_building_id != visible_city_id:
		_cached_city_buildings = society.call("get_city_buildings", visible_city_id)
		_cached_city_building_id = visible_city_id
	for record_value in _cached_city_buildings:
		var record: Dictionary = record_value
		var kind := str(record.get("kind", ""))
		# As estalagens já aparecem pela camada global de pontos de interesse.
		if kind == "inn":
			continue
		if kind == "house" and current_zoom < HOUSE_SHOW_ZOOM:
			continue
		var pos: Vector3 = record.get("entry", record.get("center", Vector3.ZERO))
		var p := _to_screen(pos, scale, map_rect)
		if not map_rect.has_point(p):
			continue
		var symbol: String = str(BUILDING_SYMBOLS.get(kind, "•"))
		var icon_radius := 9.0 if current_zoom >= 3.2 else 7.0
		var selected := str(_selected_location.get("type", "")) == "building" and str(_selected_location.get("id", "")) == str(record.get("id", record.get("name", "")))
		draw_circle(p, icon_radius, Color(0.04, 0.035, 0.025, 0.98))
		draw_arc(p, icon_radius, 0.0, TAU, 24, Color(0.72, 0.57, 0.31) if not selected else Color(0.4, 1.0, 0.65), 1.5)
		draw_string(font, p + Vector2(-5.0, 5.0), symbol, HORIZONTAL_ALIGNMENT_CENTER, 10.0, 14, Color(1.0, 0.83, 0.47))
		if selected:
			draw_arc(p, icon_radius + 4.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.65), 1.5)


func _draw_regional_threat_panel(ow, map_rect: Rect2, font: Font) -> void:
	if game == null or game.player == null or ow == null or not ow.has_method("get_regional_threat_info_at_position"):
		return
	var query_position: Vector3 = game.player.global_position
	if _selected_location.has("position"):
		query_position = _selected_location.get("position", query_position)
	var record: Dictionary = ow.call("get_regional_threat_info_at_position", query_position)
	if record.is_empty():
		return
	var threat: float = clampf(float(record.get("threat", 0.0)), 0.0, 100.0)
	var display_value: int = int(floor(threat / 10.0)) * 10
	var status: String = str(record.get("status", "Tranquila"))
	var siege_state := str(record.get("siege_state", "safe"))
	if bool(record.get("is_city", false)):
		match siege_state:
			"under_attack":
				status = "Sob ataque · %ds" % int(ceil(float(record.get("assault_timer", 0.0))))
			"occupied":
				status = "Tomada · %d invasores" % int(record.get("occupation_remaining", 0))
			"ruins":
				status = "Ruínas libertadas"
	var region_name: String = str(record.get("name", "Região desconhecida"))
	var fill := Color(0.36, 0.72, 0.40)
	if threat >= 80.0:
		fill = Color(0.78, 0.14, 0.12)
	elif threat >= 60.0:
		fill = Color(0.86, 0.31, 0.16)
	elif threat >= 40.0:
		fill = Color(0.88, 0.59, 0.20)
	elif threat >= 20.0:
		fill = Color(0.82, 0.76, 0.32)
	var panel_size := Vector2(255.0, 77.0)
	var panel_pos := Vector2(map_rect.position.x + 12.0, map_rect.position.y + 12.0)
	draw_rect(Rect2(panel_pos, panel_size), Color(0.035, 0.032, 0.027, 0.92), true)
	draw_rect(Rect2(panel_pos, panel_size), Color(0.40, 0.32, 0.20, 0.98), false, 1.0)
	var threat_heading := "ESTADO DA CIDADE" if bool(record.get("is_city", false)) else "AMEAÇA REGIONAL"
	draw_string(font, panel_pos + Vector2(9.0, 17.0), threat_heading, HORIZONTAL_ALIGNMENT_LEFT, 160.0, 11, Color(0.72, 0.61, 0.43))
	draw_string(font, panel_pos + Vector2(panel_size.x - 63.0, 17.0), "%d/100" % display_value, HORIZONTAL_ALIGNMENT_RIGHT, 54.0, 12, fill)
	draw_string(font, panel_pos + Vector2(9.0, 36.0), region_name, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 18.0, 14, Color(0.90, 0.86, 0.75))
	draw_string(font, panel_pos + Vector2(9.0, 53.0), status, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 18.0, 11, fill)
	var bar_rect := Rect2(panel_pos + Vector2(9.0, 61.0), Vector2(panel_size.x - 18.0, 6.0))
	draw_rect(bar_rect, Color(0.12, 0.105, 0.085, 1.0), true)
	if display_value > 0:
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * float(display_value) / 100.0, bar_rect.size.y)), fill, true)


func _select_from_map(screen_pos: Vector2) -> void:
	var ow = game.overworld if game != null else null
	if ow == null:
		return
	var best_distance := 21.0
	var best: Dictionary = {}
	# Edifícios têm prioridade ao ampliar a visão de uma cidade.
	if zoom_level >= BUILDING_SHOW_ZOOM:
		var society = ow.get("_npc_society")
		var visible_city_id := _nearest_city_id(ow, _view_center)
		if visible_city_id.is_empty():
			visible_city_id = focus_city_id
		if society != null and society.has_method("get_city_buildings"):
			if _cached_city_building_id != visible_city_id:
				_cached_city_buildings = society.call("get_city_buildings", visible_city_id)
				_cached_city_building_id = visible_city_id
			for value in _cached_city_buildings:
				var building: Dictionary = value
				var kind := str(building.get("kind", ""))
				# A seleção das estalagens é feita pelo marcador global dedicado.
				if kind == "inn":
					continue
				if kind == "house" and zoom_level < HOUSE_SHOW_ZOOM:
					continue
				var building_pos: Vector3 = building.get("entry", building.get("center", Vector3.ZERO))
				var building_screen := _to_screen(building_pos, _map_scale, _map_rect)
				var building_distance := building_screen.distance_to(screen_pos)
				if building_distance < best_distance:
					best_distance = building_distance
					var building_id := str(building.get("id", building.get("name", "")))
					var building_city_id := str(building.get("city_id", visible_city_id))
					var building_name := str(building.get("name", BUILDING_KIND_LABELS.get(kind, "Local")))
					var building_type_label := str(BUILDING_KIND_LABELS.get(kind, "Local"))
					var building_description := _building_description(kind, building_city_id, ow)
					# A residência do jogador continua sendo uma casa física comum no mundo,
					# mas nunca deve aparecer como desocupada no painel do mapa.
					var is_player_home := kind == "house" and game != null and building_id == str(game.get("player_home_building_id"))
					if is_player_home:
						building_name = str(game.get("player_home_building_name"))
						if building_name.strip_edges().is_empty():
							building_name = "Casa do jogador"
						building_type_label = "Casa do jogador"
						building_description = "Sua casa em %s. Aqui você pode dormir e guardar itens e equipamentos no baú." % _city_name_for_id(ow, building_city_id)
					best = {"type": "building", "id": building_id, "name": building_name, "type_label": building_type_label, "position": building_pos, "city_id": building_city_id, "description": building_description}
	# Cidades são marcadores mais importantes na escala continental.
	for st_value in ow.settlement_points:
		var st: Dictionary = st_value
		var settlement_pos: Vector3 = st.get("pos", Vector3.ZERO)
		var settlement_screen := _to_screen(settlement_pos, _map_scale, _map_rect)
		var settlement_distance := settlement_screen.distance_to(screen_pos)
		if settlement_distance < best_distance:
			best_distance = settlement_distance
			var settlement_city_id := str(st.get("id", ""))
			var settlement_display_name := str(st.get("name", "")).strip_edges()
			if settlement_display_name.is_empty():
				settlement_display_name = WORLD_NAMES.settlement_name(settlement_city_id)
			best = {"type": "city", "id": settlement_city_id, "name": settlement_display_name, "position": settlement_pos, "description": _city_description(settlement_city_id)}
	# Pontos de interesse e locais de coleta também podem ser selecionados.
	var feature_society = ow.get("_npc_society")
	if feature_society != null and feature_society.has_method("get_map_features"):
		for feature_value in feature_society.call("get_map_features"):
			if not (feature_value is Dictionary):
				continue
			var feature: Dictionary = feature_value
			var feature_kind := str(feature.get("kind", "poi"))
			if feature_kind.begins_with("resource_") and zoom_level < 2.4:
				continue
			var feature_pos: Vector3 = feature.get("position", Vector3.ZERO)
			var feature_distance := _to_screen(feature_pos, _map_scale, _map_rect).distance_to(screen_pos)
			if feature_distance < best_distance:
				best_distance = feature_distance
				best = {"type": "poi", "id": str(feature.get("id", "")), "name": str(feature.get("name", "Local de interesse")), "type_label": _feature_type_label(feature_kind), "position": feature_pos, "description": str(feature.get("description", "Um ponto de interesse de Brumaférrea."))}
	# Entrada de cripta descoberta.
	for entrance in ow.entrances:
		if not is_instance_valid(entrance) or not bool(entrance.get_meta("discovered", false)):
			continue
		var crypt_pos: Vector3 = entrance.global_position
		var crypt_distance := _to_screen(crypt_pos, _map_scale, _map_rect).distance_to(screen_pos)
		if crypt_distance < best_distance:
			best_distance = crypt_distance
			best = {"type": "crypt", "id": str(entrance.get_instance_id()), "name": "Entrada de cripta", "type_label": "Cripta", "position": crypt_pos, "description": "Uma entrada subterrânea descoberta durante a exploração."}
	if not best.is_empty():
		_select_location(best)
	else:
		var empty_pos := _screen_to_world(screen_pos)
		var region_desc := "Ponto do mapa selecionado. Você pode marcar esta posição na bússola para usá-la como destino durante a exploração."
		if ow.has_method("get_regional_threat_info_at_position"):
			var threat_info: Dictionary = ow.call("get_regional_threat_info_at_position", empty_pos)
			if not threat_info.is_empty():
				region_desc = "Região: %s. %s. Esta posição pode ser marcada na bússola." % [str(threat_info.get("name", "Brumaférrea")), str(threat_info.get("status", ""))]
		_select_location({"type": "region", "name": "Local selecionado", "type_label": "Região", "position": empty_pos, "description": region_desc})


func _select_location(data: Dictionary) -> void:
	_selected_location = data.duplicate(true)
	var selected_type := str(_selected_location.get("type", ""))
	if selected_type == "city":
		focus_city_id = str(_selected_location.get("id", ""))
		_cached_city_buildings.clear()
		_cached_city_building_id = ""
		_focus_center = _selected_location.get("position", _focus_center)
		if zoom_level > 1.0:
			_view_center = _focus_center
	queue_redraw()


func _set_compass_marker() -> void:
	if game == null or not _selected_location.has("position"):
		return
	game.navigation_marker_position = _selected_location.get("position", Vector3.ZERO)
	game.navigation_marker_label = str(_selected_location.get("name", "Destino"))
	game.navigation_marker_active = true


func _clear_compass_marker() -> void:
	if game == null:
		return
	game.navigation_marker_active = false
	game.navigation_marker_label = ""


func _nearest_city_id(ow, world_position: Vector3) -> String:
	var best_id := ""
	var best_distance := INF
	for value in ow.settlement_points:
		var settlement: Dictionary = value
		var pos: Vector3 = settlement.get("pos", Vector3.ZERO)
		var distance := Vector2(pos.x - world_position.x, pos.z - world_position.z).length()
		if distance < best_distance:
			best_distance = distance
			best_id = str(settlement.get("id", ""))
	return best_id


func _city_name_for_id(ow, city_id: String) -> String:
	if city_id.is_empty():
		return "Brumaférrea"
	for value in ow.settlement_points:
		var st: Dictionary = value
		if str(st.get("id", "")) == city_id:
			var display_name := str(st.get("name", "")).strip_edges()
			return display_name if not display_name.is_empty() else WORLD_NAMES.settlement_name(city_id)
	return WORLD_NAMES.settlement_name(city_id)


func _city_description(city_id: String) -> String:
	if game != null and game.has_method("get_settlement_description"):
		return str(game.call("get_settlement_description", city_id))
	return WORLD_NAMES.settlement_description(city_id)


func _building_description(kind: String, city_id: String, ow) -> String:
	var city_name := _city_name_for_id(ow, city_id)
	var descriptions := {
		"house": "Uma residência nos arredores de %s." % city_name,
		"shop": "Estabelecimento comercial de %s." % city_name,
		"workshop": "Oficina onde são produzidos e reparados artigos." ,
		"inn": "Estalagem para refeições, descanso e hospedagem.",
		"tavern": "Taverna onde moradores e viajantes se encontram para comer, beber e trocar notícias.",
		"town_hall": "Edifício cívico onde se concentram assuntos da comunidade.",
		"temple": "Local de culto dedicado às divindades veneradas na região.",
		"library": "Acervo de livros e registros mantidos pela comunidade.",
		"infirmary": "Local de cuidados para doentes e feridos.",
		"guard_post": "Posto da guarda local.",
		"lookout": "Ponto elevado para observar o terreno e as estradas.",
		"depot": "Armazém para mercadorias e suprimentos.",
		"shelter": "Abrigo para quem precisa se proteger ou passar a noite.",
		"stable": "Estábulo para animais e montarias.",
		"mill": "Moinho usado no processamento de grãos.",
		"barn": "Celeiro para colheitas e ferramentas agrícolas.",
		"well": "Poço comunitário para coleta de água.",
		"ruin": "Restos de uma construção antiga."
	}
	return str(descriptions.get(kind, "Um local de interesse em %s." % city_name))


func _feature_type_label(kind: String) -> String:
	if kind == "inn":
		return "Estalagem"
	if kind.begins_with("resource_herbs"):
		return "Coleta de ervas"
	if kind.begins_with("resource_ore"):
		return "Depósito mineral"
	if kind.begins_with("resource_"):
		return "Área de coleta"
	return "Ponto de interesse"


func _type_label(kind: String) -> String:
	match kind:
		"city":
			return "Assentamento"
		"building":
			return "Edifício"
		"crypt":
			return "Cripta"
		"region":
			return "Região"
	return "Local"


func _wrap_text(text: String, font: Font, max_width: float, font_size: int) -> Array[String]:
	var output: Array[String] = []
	var current := ""
	for word in text.split(" ", false):
		var candidate: String = word if current.is_empty() else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width and not current.is_empty():
			output.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		output.append(current)
	return output


func _world_units_per_pixel() -> float:
	var ow = game.overworld if game != null else null
	if ow == null or _map_rect.size.x <= 0.0:
		return 1.0
	return float(ow.map_extent) / (_map_rect.size.x * maxf(1.0, zoom_level))


func _clamp_view_center() -> void:
	var ow = game.overworld if game != null else null
	if ow == null:
		return
	var half_visible := 0.5 / maxf(1.0, zoom_level)
	var limit := float(ow.map_extent) * (0.5 - half_visible)
	_view_center.x = clampf(_view_center.x, ow.map_center.x - limit, ow.map_center.x + limit)
	_view_center.z = clampf(_view_center.z, ow.map_center.z - limit, ow.map_center.z + limit)


func _screen_to_world(p: Vector2) -> Vector3:
	return Vector3(_view_center.x + (p.x - _map_rect.get_center().x) / _map_scale, _view_center.y, _view_center.z + (p.y - _map_rect.get_center().y) / _map_scale)


func _to_screen(p: Vector3, scale: float, rect: Rect2) -> Vector2:
	return rect.position + rect.size * 0.5 + Vector2((p.x - _view_center.x) * scale, (p.z - _view_center.z) * scale)


func _draw_waypoint(center: Vector2, radius: float, col: Color) -> void:
	draw_circle(center, radius + 4.0, Color(col.r, col.g, col.b, 0.18))
	var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(diamond, col)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0.02, 0.05, 0.03), 1.4)


func _draw_star(center: Vector2, radius: float, col: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.48
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, col)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color.WHITE, 1.2)

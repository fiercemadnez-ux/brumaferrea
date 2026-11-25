extends Control
# Bússola no topo da tela (HUD): moldura com pontas em seta, marca para onde o jogador olha,
# a entrada da cripta (losango vermelho) e as cidades próximas (casinha dourada).

const UiFrame := preload("res://scripts/ui_frame.gd")
const VIS_HALF := 1.8326  # metade do arco visível (105 graus em radianos)
const HOUSE_RANGE := 450.0
const CRYPT_COMPASS_RANGE := 190.0
const QUEST_MARKER_COLOR := Color(1.0, 0.72, 0.20)
const MARKER_COLOR := Color(0.30, 1.0, 0.58)
const LABELS := {0: "N", 3: "NE", 6: "L", 9: "SE", 12: "S", 15: "SO", 18: "O", 21: "NO"}

var game = null


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var s := UiFrame.ui_scale(self)
	var fw := 635.0 * s
	var fh := 63.0 * s
	var r := Rect2(Vector2((size.x - fw) * 0.5, 14.0 * s), Vector2(fw, fh))
	UiFrame.panel(self, r, s, true)
	if game == null or game.player == null:
		return
	var font := UiFrame.font()
	var player = game.player
	var bearing: float = -player.rotation.y
	var cx := r.position.x + r.size.x * 0.5
	var px_per_rad := (r.size.x * 0.5 - 48.0 * s) / VIS_HALF
	var top := r.position.y

	for i in 24:
		var a := deg_to_rad(i * 15.0)
		var off := wrapf(a - bearing + PI, 0.0, TAU) - PI
		if absf(off) > VIS_HALF:
			continue
		var fade := clampf((VIS_HALF - absf(off)) / 0.3, 0.0, 1.0)
		var x := cx + off * px_per_rad
		var major := i % 3 == 0
		var tick := (12.0 if major else 7.0) * s
		draw_line(Vector2(x, top + 57.0 * s), Vector2(x, top + 57.0 * s - tick), Color(0.75, 0.65, 0.48, fade), (2.0 if major else 1.0) * s)
		if LABELS.has(i):
			draw_string(font, Vector2(x - 30.0 * s, top + 26.0 * s), LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, 60.0 * s, int(round(20.0 * s)), Color(0.96, 0.9, 0.75, fade))

	# Ponteiro central
	draw_line(Vector2(cx, top + 31.0 * s), Vector2(cx, top + 58.0 * s), Color(1.0, 0.93, 0.7, 0.95), 2.0 * s)

	var ow = game.overworld
	if ow == null or not is_instance_valid(ow):
		return
	var my := top + 41.0 * s
	for st in ow.settlement_points:
		var sp: Vector3 = st["pos"]
		var dx: float = sp.x - player.global_position.x
		var dz: float = sp.z - player.global_position.z
		if Vector2(dx, dz).length() > HOUSE_RANGE:
			continue
		var f := _fade_for(atan2(dx, -dz), bearing)
		if f > 0.0:
			_house(Vector2(cx + _off(atan2(dx, -dz), bearing) * px_per_rad, my), 7.0 * s, Color(0.96, 0.82, 0.45, f))
	# Criptas: o marcador aparece só quando a entrada está próxima o bastante
	# para ser vista no mundo. O registro no mapa continua exigindo descoberta.
	for e in ow.entrances:
		if not is_instance_valid(e):
			continue
		var d: Vector3 = e.global_position - player.global_position
		var distance: float = Vector2(d.x, d.z).length()
		if distance > CRYPT_COMPASS_RANGE:
			continue
		var target: float = atan2(d.x, -d.z)
		var f2: float = _fade_for(target, bearing)
		if f2 > 0.0:
			UiFrame.diamond(self, Vector2(cx + _off(target, bearing) * px_per_rad, my), 6.0 * s, Color(0.92, 0.22, 0.22, f2))

	# A missão rastreada é a exceção: seu indicador não depende da distância.
	# Se o alvo estiver atrás do jogador/fora do arco da bússola, prendemos a estrela
	# na extremidade correspondente para manter a direção sempre indicada.
	if game.quest_manager != null:
		var quest: Dictionary = game.quest_manager.get_tracked_quest()
		if not quest.is_empty():
			var quest_position: Vector3 = quest.get("map_marker_position", Vector3.ZERO)
			var quest_delta: Vector3 = quest_position - player.global_position
			var quest_distance: float = Vector2(quest_delta.x, quest_delta.z).length()
			var quest_marker_position: Vector2
			if quest_distance <= 8.0:
				# O jogador já chegou ao alvo: estrela no centro da bússola.
				quest_marker_position = Vector2(cx, my)
			else:
				var quest_angle: float = atan2(quest_delta.x, -quest_delta.z)
				var quest_offset: float = _off(quest_angle, bearing)
				var edge_offset: float = VIS_HALF - 0.13
				var marker_offset: float = clampf(quest_offset, -edge_offset, edge_offset)
				quest_marker_position = Vector2(cx + marker_offset * px_per_rad, my)
				if absf(quest_offset) > VIS_HALF:
					_draw_direction_chevron(quest_marker_position, quest_offset > 0.0, 4.0 * s, QUEST_MARKER_COLOR)
			_quest_marker(quest_marker_position, 7.5 * s, QUEST_MARKER_COLOR, s)

	# Marcador manual colocado no mapa com M. Diferente das cidades, ele não
	# desaparece quando fica longe: permanece na direção correta, junto à borda.	
	if bool(game.get("navigation_marker_active")):
		var nav_position: Vector3 = game.get("navigation_marker_position")
		var nav_delta: Vector3 = nav_position - player.global_position
		var nav_distance: float = Vector2(nav_delta.x, nav_delta.z).length()
		var nav_marker_position: Vector2
		if nav_distance <= 8.0:
			nav_marker_position = Vector2(cx, my)
		else:
			var nav_angle: float = atan2(nav_delta.x, -nav_delta.z)
			var nav_offset: float = _off(nav_angle, bearing)
			var nav_edge_offset: float = VIS_HALF - 0.13
			var nav_clamped_offset: float = clampf(nav_offset, -nav_edge_offset, nav_edge_offset)
			nav_marker_position = Vector2(cx + nav_clamped_offset * px_per_rad, my)
			if absf(nav_offset) > VIS_HALF:
				_draw_direction_chevron(nav_marker_position, nav_offset > 0.0, 4.0 * s, MARKER_COLOR)
		_draw_navigation_marker(nav_marker_position, 7.5 * s, MARKER_COLOR, s)


func _quest_marker(c: Vector2, radius: float, col: Color, scale: float) -> void:
	draw_circle(c, radius + 2.5 * scale, Color(col.r, col.g, col.b, 0.25))
	var points := PackedVector2Array()
	for i in range(10):
		var angle: float = -PI * 0.5 + float(i) * PI / 5.0
		var r: float = radius if i % 2 == 0 else radius * 0.48
		points.append(c + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, col)
	var outline_points: PackedVector2Array = points.duplicate()
	outline_points.append(points[0])
	draw_polyline(outline_points, Color(1.0, 0.96, 0.82), maxf(1.0, scale))


func _draw_direction_chevron(c: Vector2, points_right: bool, size: float, col: Color) -> void:
	var direction: float = 1.0 if points_right else -1.0
	var tip := c + Vector2(direction * size, 0.0)
	var upper := c + Vector2(-direction * size * 0.7, -size)
	var lower := c + Vector2(-direction * size * 0.7, size)
	draw_line(upper, tip, col, 2.0)
	draw_line(tip, lower, col, 2.0)


func _off(target: float, bearing: float) -> float:
	return wrapf(target - bearing + PI, 0.0, TAU) - PI


func _fade_for(target: float, bearing: float) -> float:
	return clampf((VIS_HALF - absf(_off(target, bearing))) / 0.3, 0.0, 1.0)


func _house(c: Vector2, sz: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(c.x - sz, c.y), Vector2(c.x, c.y - sz), Vector2(c.x + sz, c.y),
		Vector2(c.x + sz * 0.7, c.y), Vector2(c.x + sz * 0.7, c.y + sz * 0.9),
		Vector2(c.x - sz * 0.7, c.y + sz * 0.9), Vector2(c.x - sz * 0.7, c.y)])
	draw_colored_polygon(pts, col)


func _draw_navigation_marker(c: Vector2, radius: float, col: Color, scale: float) -> void:
	draw_circle(c, radius + 2.5 * scale, Color(col.r, col.g, col.b, 0.20))
	var pts := PackedVector2Array([c + Vector2(0, -radius), c + Vector2(radius, 0), c + Vector2(0, radius), c + Vector2(-radius, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.03, 0.08, 0.04), maxf(1.0, scale))

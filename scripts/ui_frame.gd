extends RefCounted
# Peças visuais compartilhadas do HUD: moldura escura com cantos dourados, barras e fonte com serifa.
# O HUD é desenhado em "pixels de projeto" (a arte de referência tem 940 de altura) vezes a escala ui_scale().

const FONT_PATH := "res://assets/fonts/hud.ttf"  # opcional: ponha uma fonte aqui (ex.: Cinzel) e o HUD passa a usá-la
const HUD_SCALE := 1.0                           # multiplicador geral do tamanho do HUD (0.8 = menor, 1.2 = maior)
const REF_HEIGHT := 940.0
const BG := Color(0.035, 0.03, 0.028, 0.92)
const GOLD := Color(0.6, 0.46, 0.22)
const GOLD_HI := Color(0.9, 0.72, 0.32)
const CREAM := Color(0.93, 0.9, 0.82)

static var _font: Font = null


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
		else:
			var f := SystemFont.new()
			f.font_names = PackedStringArray(["Cinzel", "Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])
			f.font_weight = 700
			_font = f
	return _font


static func ui_scale(ci: Control) -> float:
	return clampf(ci.size.y / REF_HEIGHT, 0.55, 2.5) * HUD_SCALE


static func diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


static func _hexagon(r: Rect2) -> PackedVector2Array:
	var c := r.size.y * 0.5
	var mid := r.position.y + r.size.y * 0.5
	return PackedVector2Array([
		Vector2(r.position.x + c, r.position.y), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, mid),
		Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, mid)])


static func panel(ci: CanvasItem, r: Rect2, s: float, pointed: bool = false) -> void:
	if pointed:
		# Moldura com as pontas laterais em seta (bússola)
		var pts := _hexagon(r)
		ci.draw_colored_polygon(pts, BG)
		var outline := pts.duplicate()
		outline.append(pts[0])
		ci.draw_polyline(outline, GOLD, 2.0 * s)
		var inner := _hexagon(r.grow(-4.0 * s))
		var inner_line := inner.duplicate()
		inner_line.append(inner[0])
		ci.draw_polyline(inner_line, Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 1.0 * s)
		var mid := r.position.y + r.size.y * 0.5
		diamond(ci, Vector2(r.position.x + 13.0 * s, mid), 3.0 * s, GOLD_HI)
		diamond(ci, Vector2(r.end.x - 13.0 * s, mid), 3.0 * s, GOLD_HI)
		return
	ci.draw_rect(r, BG)
	ci.draw_rect(r, GOLD, false, 2.0 * s)
	ci.draw_rect(r.grow(-4.0 * s), Color(GOLD.r, GOLD.g, GOLD.b, 0.4), false, 1.0 * s)
	var arm := 14.0 * s
	var corners := [
		[r.position, Vector2(1, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, -1)],
		[r.end, Vector2(-1, -1)],
	]
	for cn in corners:
		var p: Vector2 = cn[0]
		var d: Vector2 = cn[1]
		ci.draw_line(p, p + Vector2(d.x * arm, 0.0), GOLD_HI, 2.5 * s)
		ci.draw_line(p, p + Vector2(0.0, d.y * arm), GOLD_HI, 2.5 * s)
		diamond(ci, p + d * 7.0 * s, 2.8 * s, GOLD_HI)


static func bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, s: float) -> void:
	ci.draw_rect(r, Color(0.02, 0.02, 0.02, 1.0))
	var inner := r.grow(-1.5 * s)
	var fr := Rect2(inner.position, Vector2(inner.size.x * clampf(frac, 0.0, 1.0), inner.size.y))
	ci.draw_rect(fr, col)
	ci.draw_rect(Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.4)), Color(1, 1, 1, 0.18))
	ci.draw_rect(r, Color(0.35, 0.28, 0.16), false, 1.0 * s)

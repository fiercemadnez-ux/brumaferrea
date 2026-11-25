extends Control
# HUD de status no canto inferior esquerdo (vida, mana, ouro, poções) e a mira no centro da tela.

const UiFrame := preload("res://scripts/ui_frame.gd")

var game = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if game == null or game.player == null:
		return
	var s := UiFrame.ui_scale(self)
	var p = game.player
	var font := UiFrame.font()
	var fs := int(round(20.0 * s))
	var cream := UiFrame.CREAM

	var pos := Vector2(26.0 * s, size.y - (32.0 + 160.0) * s)
	UiFrame.panel(self, Rect2(pos, Vector2(512.0, 160.0) * s), s)

	var x := pos.x + 33.0 * s
	var bw := 448.0 * s
	var max_hp: int = p.get_max_hp()
	draw_string(font, Vector2(x, pos.y + 30.0 * s), "VIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
	draw_string(font, Vector2(x + 84.0 * s, pos.y + 30.0 * s), "%d/%d" % [p.hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
	UiFrame.bar(self, Rect2(x, pos.y + 38.0 * s, bw, 14.0 * s), float(p.hp) / float(max_hp), Color(0.78, 0.1, 0.12), s)

	draw_string(font, Vector2(x, pos.y + 79.0 * s), "MANA", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
	draw_string(font, Vector2(x + 84.0 * s, pos.y + 79.0 * s), "%d/%d" % [int(p.mana), int(p.max_mana)], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
	UiFrame.bar(self, Rect2(x, pos.y + 85.0 * s, bw, 14.0 * s), p.mana / p.max_mana, Color(0.2, 0.4, 0.92), s)

	# Ouro e poções
	var icon := 30.0 * s
	var row := pos.y + 130.0 * s
	draw_texture_rect(game.sprites["gold"], Rect2(Vector2(x - 2.0 * s, row - icon * 0.62), Vector2(icon, icon)), false)
	draw_string(font, Vector2(x + 40.0 * s, row + 7.0 * s), "OURO  %d" % p.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
	draw_texture_rect(game.sprites["potion"], Rect2(Vector2(x + 184.0 * s, row - icon * 0.62), Vector2(icon, icon)), false)
	draw_string(font, Vector2(x + 224.0 * s, row + 7.0 * s), "POÇÕES  %d" % p.potions, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)

	# Mira: cruz fina com vão no meio
	var c := size * 0.5
	var gap := 4.0 * s
	var arm := 8.0 * s
	var lines := [[Vector2(-gap - arm, 0), Vector2(-gap, 0)], [Vector2(gap, 0), Vector2(gap + arm, 0)], [Vector2(0, -gap - arm), Vector2(0, -gap)], [Vector2(0, gap), Vector2(0, gap + arm)]]
	for l in lines:
		draw_line(c + l[0], c + l[1], Color(0, 0, 0, 0.6), 3.5 * s)
	for l in lines:
		draw_line(c + l[0], c + l[1], Color(0.95, 0.97, 1.0, 0.95), 1.6 * s)

extends Control
# Hotbar no canto inferior direito: três espaços rápidos reservados a consumíveis (teclas 1, 2 e 3).

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
	var n: int = p.hotbar_size()
	var slot_w := 74.0
	var slot_h := 88.0
	var gap := 8.0
	var pad := 14.0
	var fw := pad * 2.0 + n * slot_w + (n - 1) * gap
	var fh := 112.0
	var pos := Vector2(size.x - (26.0 + fw) * s, size.y - (32.0 + fh) * s)
	UiFrame.panel(self, Rect2(pos, Vector2(fw, fh) * s), s)

	for i in n:
		var slot: Dictionary = p.hotbar_slot(i)
		var sr := Rect2(pos + Vector2(pad + i * (slot_w + gap), 12.0) * s, Vector2(slot_w, slot_h) * s)
		var tex: Texture2D = null
		var usable := false
		var badge := ""
		if not slot.is_empty() and str(slot.get("type", "")) == "potion":
			tex = game.sprites.get("potion")
			badge = "x%d" % p.potions
			usable = p.potions > 0
		draw_rect(sr, Color(0.07, 0.06, 0.07, 0.95))
		if tex != null:
			var isz := 58.0 * s
			var ir := Rect2(sr.position + Vector2((slot_w * s - isz) * 0.5, 6.0 * s), Vector2(isz, isz))
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, 1.0 if usable else 0.4))
		else:
			draw_string(font, sr.position + Vector2(0, 43.0 * s), "Vazio", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(round(11.0 * s)), Color(0.60, 0.56, 0.48))
		if badge != "":
			var bpos := Vector2(sr.position.x - 4.0 * s, sr.position.y + 60.0 * s)
			draw_string_outline(font, bpos, badge, HORIZONTAL_ALIGNMENT_RIGHT, slot_w * s, int(round(14.0 * s)), int(4.0 * s), Color(0, 0, 0, 0.9))
			draw_string(font, bpos, badge, HORIZONTAL_ALIGNMENT_RIGHT, slot_w * s, int(round(14.0 * s)), UiFrame.CREAM)
		# faixa com o número da tecla
		draw_rect(Rect2(sr.position.x, sr.position.y + 66.0 * s, sr.size.x, 22.0 * s), Color(0.03, 0.025, 0.03, 0.95))
		draw_string(font, Vector2(sr.position.x, sr.position.y + 83.0 * s), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, slot_w * s, int(round(16.0 * s)), UiFrame.CREAM)
		draw_rect(sr, Color(0.4, 0.32, 0.18), false, 1.2 * s)

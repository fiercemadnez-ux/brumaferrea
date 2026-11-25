extends PanelContainer
# Janela de loja (ferreiro, curandeira, mercador). Clique no item ou aperte o número para comprar.
# Esc ou F fecha. Os itens e preços ficam em SHOP_ROLES no game.gd.

signal closed

var game = null
var _role := ""
var _open := false
var _title: Label
var _gold: Label
var _list: VBoxContainer
var _msg: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(780, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.95)
	sb.border_color = Color(0.45, 0.35, 0.2)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	col.add_child(_title)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 20)
	_gold.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	col.add_child(_gold)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	_msg = Label.new()
	_msg.add_theme_font_size_override("font_size", 18)
	_msg.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	col.add_child(_msg)
	var hint := Label.new()
	hint.text = "Clique ou aperte o número para comprar · Esc ou F sai"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.56, 0.5))
	col.add_child(hint)
	visible = false


func open(g, role: String, title: String) -> void:
	game = g
	_role = role
	_title.text = title
	_msg.text = ""
	_open = true
	visible = true
	_refresh()


func handle_key(keycode: int) -> bool:
	if not _open:
		return false
	if keycode == KEY_ESCAPE or keycode == KEY_F:
		_close()
		return true
	if keycode >= KEY_1 and keycode <= KEY_9:
		_buy(keycode - KEY_1)
		return true
	return false


func _refresh() -> void:
	_gold.text = "Seu ouro: %d" % game.player.gold
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var rows: Array = game.shop_rows(_role)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var b := Button.new()
		if r["owned"]:
			b.text = "%d. %s   [já possui]" % [i + 1, r["label"]]
			b.disabled = true
		else:
			b.text = "%d. %s   ·   %d ouro" % [i + 1, r["label"], r["price"]]
			if not r["can"]:
				b.modulate = Color(1, 1, 1, 0.5)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_buy.bind(i))
		_list.add_child(b)


func _buy(i: int) -> void:
	_msg.text = game.shop_buy(_role, i)
	_refresh()


func _close() -> void:
	_open = false
	visible = false
	closed.emit()

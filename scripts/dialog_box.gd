extends PanelContainer
# Janelinha de diálogo embaixo da tela (conversa com NPCs e entrada da cripta).
# Escolha uma opção clicando nela ou apertando o número. Esc ou F fecha.
# Ao fechar, emite "closed" com a ação da opção escolhida ("" = só fechar).

signal closed(action: String)
signal line_shown(speaker_name: String, node_key: String, text: String)

var _speaker: Label
var _text: Label
var _default_speaker := ""
var _opts: VBoxContainer
var _tree: Dictionary = {}
var _current: Dictionary = {}
var _open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -20.0
	custom_minimum_size = Vector2(780, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.94)
	sb.border_color = Color(0.45, 0.35, 0.2)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 24)
	_speaker.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	col.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 20)
	_text.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	col.add_child(_text)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 4)
	col.add_child(_opts)
	visible = false


func is_open() -> bool:
	return _open


func open(speaker_name: String, tree: Dictionary) -> void:
	_tree = tree
	_default_speaker = speaker_name
	_speaker.text = speaker_name
	_open = true
	visible = true
	_show("start")


func handle_key(keycode: int) -> bool:
	if not _open:
		return false
	if keycode == KEY_ESCAPE or keycode == KEY_F:
		_close("")
		return true
	if keycode >= KEY_1 and keycode <= KEY_9:
		_choose(keycode - KEY_1)
		return true
	return false


func _show(key: String) -> void:
	_current = _tree.get(key, {})
	_speaker.text = str(_current.get("speaker", _default_speaker))
	_text.text = str(_current.get("text", ""))
	_text.visible = not _text.text.strip_edges().is_empty()
	if _text.visible:
		line_shown.emit(_speaker.text, key, _text.text)
	for c in _opts.get_children():
		_opts.remove_child(c)
		c.queue_free()
	var opts: Array = _current.get("options", [])
	if opts.is_empty():
		opts = [{"label": "Fechar", "action": ""}]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, str(o["label"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_choose.bind(i))
		_opts.add_child(b)


func _choose(i: int) -> void:
	var opts: Array = _current.get("options", [])
	if opts.is_empty():
		_close("")
		return
	if i < 0 or i >= opts.size():
		return
	var o: Dictionary = opts[i]
	if o.has("next"):
		_show(str(o["next"]))
	else:
		_close(str(o.get("action", "")))


func _close(action: String) -> void:
	_open = false
	visible = false
	closed.emit(action)

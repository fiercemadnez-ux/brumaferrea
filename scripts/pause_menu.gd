extends Control
# Menu de pausa de Brumaférrea: moldura escura, filetes de bronze e tipografia clássica.
# Mantém as ações do jogo e oferece um painel de campanha em vez de despejar a lista de teclas.

const UiFrame := preload("res://scripts/ui_frame.gd")
const BG := Color(0.015, 0.016, 0.015, 0.84)
const PANEL := Color(0.040, 0.037, 0.031, 0.985)
const PANEL_ALT := Color(0.075, 0.065, 0.050, 0.99)
const PANEL_DEEP := Color(0.024, 0.026, 0.024, 0.99)
const GOLD := Color(0.88, 0.68, 0.33)
const GOLD_SOFT := Color(0.59, 0.46, 0.27)
const TEXT := Color(0.91, 0.88, 0.80)
const TEXT_DIM := Color(0.61, 0.58, 0.51)
const GREEN := Color(0.61, 0.77, 0.48)
const RED := Color(0.79, 0.45, 0.37)
const SETTINGS_PATH := "user://brumaferrea_settings.cfg"

var game = null
var _page := "home"
var _page_content: VBoxContainer
var _page_title: Label
var _page_subtitle: Label
var _status_label: Label
var _volume_value: Label
var _volume_slider: HSlider
var _resume_button: Button
var _save_button: Button
var _options_button: Button
var _menu_button: Button
var _last_save_ok := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A camada CanvasLayer já coloca o menu acima do HUD. Evita usar o limite
	# máximo de Z no painel inteiro, que pode achatar a ordem dos controles filhos.
	z_index = 0
	z_as_relative = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_settings()
	_build_ui()
	visible = false


func open() -> void:
	_page = "home"
	_last_save_ok = false
	_refresh_header()
	_render_page()
	visible = true
	_force_menu_draw_order()
	# Um segundo passe após o layout evita que o painel fique sem área desenhável
	# ao reabrir a pausa depois de outra interface.
	call_deferred("_force_menu_draw_order")
	if _resume_button != null:
		_resume_button.grab_focus()


func _force_menu_draw_order() -> void:
	# A camada própria garante a precedência sobre o HUD; dentro dela, o painel
	# recebe Z explícito para nunca ficar atrás do retângulo que escurece a tela.
	z_index = 0
	var dim := get_node_or_null("PauseDim") as ColorRect
	if dim != null:
		dim.z_index = -10
		dim.visible = true
	var center := get_node_or_null("PauseCenter") as CenterContainer
	if center != null:
		center.z_index = 10
		center.visible = true
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.queue_sort()
		var frame := center.get_node_or_null("PauseFrame") as PanelContainer
		if frame != null:
			frame.visible = true


func notify_saved(success: bool) -> void:
	_last_save_ok = success
	if _status_label != null:
		_status_label.text = "PROGRESSO SALVO" if success else "NÃO FOI POSSÍVEL SALVAR"
		_status_label.add_theme_color_override("font_color", GREEN if success else RED)
	if _save_button != null:
		_save_button.text = "PROGRESSO SALVO" if success else "TENTAR SALVAR NOVAMENTE"


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "PauseDim"
	dim.color = BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = -10
	dim.z_as_relative = true
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "PauseCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.z_index = 10
	center.z_as_relative = true
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.name = "PauseFrame"
	frame.custom_minimum_size = Vector2(1080, 604)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD_SOFT, 2, 16))
	center.add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	frame.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	outer.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	header.add_child(title_stack)
	title_stack.add_child(_label("OS CÂNTICOS DOS SETE", 13, TEXT_DIM))
	var title := _label("BRUMAFÉRREA", 30, GOLD)
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.01, 0.8))
	title_stack.add_child(title)

	var header_right := VBoxContainer.new()
	header_right.alignment = BoxContainer.ALIGNMENT_CENTER
	header_right.add_theme_constant_override("separation", 3)
	header.add_child(header_right)
	var pause_stamp := _label("JORNADA INTERROMPIDA", 12, GOLD_SOFT)
	pause_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_right.add_child(pause_stamp)
	var clock_label := _label("KANTHALOS  ·  BRUMAFÉRREA", 12, TEXT_DIM)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_right.add_child(clock_label)

	outer.add_child(_rule())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	outer.add_child(body)

	var nav_panel := PanelContainer.new()
	nav_panel.name = "PauseNavigation"
	nav_panel.custom_minimum_size = Vector2(330, 0)
	nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_DEEP, Color(0.28, 0.22, 0.14, 0.9), 1, 14))
	body.add_child(nav_panel)

	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav_panel.add_child(nav)
	nav.add_child(_label("MENU DE PAUSA", 15, GOLD_SOFT))
	var nav_rule := _rule()
	nav_rule.color = Color(0.34, 0.27, 0.17, 0.8)
	nav.add_child(nav_rule)

	_resume_button = _nav_button("RETOMAR A JORNADA", "CONTINUAR")
	_resume_button.pressed.connect(_resume_game)
	nav.add_child(_resume_button)
	_save_button = _nav_button("SALVAR PROGRESSO", "SALVAR")
	_save_button.pressed.connect(_save_game)
	nav.add_child(_save_button)
	_options_button = _nav_button("OPÇÕES", "AJUSTES")
	_options_button.pressed.connect(_show_options)
	nav.add_child(_options_button)
	_menu_button = _nav_button("VOLTAR AO MENU", "MENU")
	_menu_button.pressed.connect(_ask_return_to_menu)
	nav.add_child(_menu_button)

	var nav_spacer := Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(nav_spacer)
	var key_hint := _label("ESC  ·  RETOMAR", 12, TEXT_DIM)
	key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(key_hint)

	var content_panel := PanelContainer.new()
	content_panel.name = "PauseContent"
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_ALT, Color(0.28, 0.22, 0.14, 0.9), 1, 18))
	body.add_child(content_panel)

	var content_root := VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 8)
	content_panel.add_child(content_root)
	_page_title = _label("REGISTRO DA JORNADA", 19, GOLD)
	content_root.add_child(_page_title)
	_page_subtitle = _label("O estado atual da sua aventura", 12, TEXT_DIM)
	content_root.add_child(_page_subtitle)
	content_root.add_child(_rule())

	_page_content = VBoxContainer.new()
	_page_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_content.add_theme_constant_override("separation", 12)
	content_root.add_child(_page_content)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	outer.add_child(bottom)
	var controls_hint := _label("WASD  MOVER     SHIFT  CORRER     M  MAPA     I  INVENTÁRIO     J  DIÁRIO", 11, TEXT_DIM)
	controls_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(controls_hint)
	_status_label = _label("A PAUSA NÃO AVANÇA O TEMPO", 11, GOLD_SOFT)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_status_label)


func _render_page() -> void:
	if _page_content == null:
		return
	for child in _page_content.get_children():
		_page_content.remove_child(child)
		child.queue_free()
	match _page:
		"options":
			_page_title.text = "OPÇÕES"
			_page_subtitle.text = "Ajustes de áudio e referência rápida de controles"
			_render_options()
		"return_confirm":
			_page_title.text = "RETORNAR AO MENU"
			_page_subtitle.text = "A campanha atual será salva antes de sair"
			_render_return_confirmation()
		_:
			_page_title.text = "REGISTRO DA JORNADA"
			_page_subtitle.text = "O estado atual da sua aventura"
			_render_campaign_summary()
	_refresh_nav_state()


func _render_campaign_summary() -> void:
	var name_text := "Aventureiro"
	var home_text := "Ainda sem cidade natal"
	var level_text := "1"
	var hp_text := "—"
	var mana_text := "—"
	var gold_text := "0"
	var time_text := "00:00"
	if game != null:
		name_text = str(game.get("character_name"))
		if name_text.strip_edges().is_empty():
			name_text = "Aventureiro"
		var home := str(game.get("character_home_name"))
		if not home.strip_edges().is_empty():
			home_text = home
		var hour_float := fposmod(float(game.get("day_time_hours")), 24.0)
		var hour := int(floor(hour_float))
		var minute := int(floor((hour_float - float(hour)) * 60.0))
		time_text = "%02d:%02d" % [hour, minute]
		var p = game.get("player")
		if p != null and is_instance_valid(p):
			level_text = str(p.get("level"))
			hp_text = "%d / %d" % [int(p.get("hp")), int(p.get("max_hp"))]
			mana_text = "%d / %d" % [int(p.get("mana")), int(p.get("max_mana"))]
			gold_text = str(int(p.get("gold")))

	var identity := PanelContainer.new()
	identity.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.043, 0.035, 0.7), Color(0.37, 0.28, 0.17, 0.65), 1, 12))
	_page_content.add_child(identity)
	var id_box := VBoxContainer.new()
	id_box.add_theme_constant_override("separation", 4)
	identity.add_child(id_box)
	id_box.add_child(_label("AVENTUREIRO", 11, TEXT_DIM))
	id_box.add_child(_label(name_text, 22, TEXT))
	var home_label := _label("CIDADE NATAL  ·  %s" % home_text, 12, GOLD_SOFT)
	id_box.add_child(home_label)
	id_box.add_child(_label("HORA LOCAL  ·  %s" % time_text, 12, TEXT_DIM))

	var stats := GridContainer.new()
	stats.columns = 2
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 8)
	_page_content.add_child(stats)
	_add_stat_card(stats, "NÍVEL", level_text, GOLD)
	_add_stat_card(stats, "VIDA", hp_text, Color(0.79, 0.42, 0.36))
	_add_stat_card(stats, "MANA", mana_text, Color(0.48, 0.67, 0.85))
	_add_stat_card(stats, "OURO", gold_text, Color(0.85, 0.69, 0.34))

	var divider := _rule()
	divider.color = Color(0.34, 0.27, 0.17, 0.65)
	_page_content.add_child(divider)
	var reminder := _label("PROGRESSO DA CAMPANHA", 11, GOLD_SOFT)
	_page_content.add_child(reminder)
	var description := _label("O mundo está em suspenso. Retome a jornada quando estiver pronto; salvar registra o personagem, o mundo e a sociedade desta campanha.", 13, TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_content.add_child(description)


func _render_options() -> void:
	var audio_card := PanelContainer.new()
	audio_card.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.043, 0.035, 0.7), Color(0.37, 0.28, 0.17, 0.65), 1, 14))
	_page_content.add_child(audio_card)
	var audio_box := VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 8)
	audio_card.add_child(audio_box)
	audio_box.add_child(_label("ÁUDIO", 14, GOLD_SOFT))
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 10)
	audio_box.add_child(volume_row)
	volume_row.add_child(_label("Volume geral", 14, TEXT))
	_volume_value = _label("100%", 13, GOLD)
	_volume_value.custom_minimum_size.x = 48
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(_volume_value)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.custom_minimum_size.y = 22
	var bus := AudioServer.get_bus_index("Master")
	_volume_slider.value = AudioServer.get_bus_volume_linear(bus) * 100.0 if bus >= 0 else 100.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	audio_box.add_child(_volume_slider)
	var volume_hint := _label("O ajuste é aplicado imediatamente e fica salvo nas próximas sessões.", 11, TEXT_DIM)
	volume_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	audio_box.add_child(volume_hint)

	var keys_card := PanelContainer.new()
	keys_card.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.043, 0.035, 0.7), Color(0.37, 0.28, 0.17, 0.65), 1, 14))
	_page_content.add_child(keys_card)
	var keys_box := VBoxContainer.new()
	keys_box.add_theme_constant_override("separation", 7)
	keys_card.add_child(keys_box)
	keys_box.add_child(_label("CONTROLES", 14, GOLD_SOFT))
	_add_control_line(keys_box, "W A S D", "Mover")
	_add_control_line(keys_box, "ESPAÇO", "Pular")
	_add_control_line(keys_box, "SHIFT", "Correr / galopar")
	_add_control_line(keys_box, "CLIQUE ESQUERDO", "Usar arma ou magia ativa")
	_add_control_line(keys_box, "1 · 2 · 3", "Consumíveis")
	_add_control_line(keys_box, "I  /  J  /  M", "Inventário / diário / mapa")
	_add_control_line(keys_box, "F  /  ESC  /  F5", "Interagir / pausa / salvar")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_content.add_child(spacer)
	var back := _secondary_button("VOLTAR À PAUSA")
	back.pressed.connect(_show_home)
	_page_content.add_child(back)


func _render_return_confirmation() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.043, 0.035, 0.7), Color(0.37, 0.28, 0.17, 0.65), 1, 16))
	_page_content.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(_label("ANTES DE PARTIR", 14, GOLD_SOFT))
	var message := _label("A campanha atual será salva e você retornará à tela de título. O progresso dos NPCs e do mundo acompanha esse salvamento.", 15, TEXT)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var save_exit := _secondary_button("SALVAR E VOLTAR AO MENU")
	save_exit.pressed.connect(_return_to_menu)
	box.add_child(save_exit)
	var cancel := _secondary_button("CANCELAR")
	cancel.pressed.connect(_show_home)
	box.add_child(cancel)


func _add_stat_card(parent: GridContainer, title_text: String, value_text: String, accent: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.034, 0.029, 0.8), Color(0.28, 0.22, 0.14, 0.55), 1, 10))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	box.add_child(_label(title_text, 10, TEXT_DIM))
	box.add_child(_label(value_text, 17, accent))


func _add_control_line(parent: VBoxContainer, key_text: String, action_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var key := _label(key_text, 11, GOLD)
	key.custom_minimum_size.x = 142
	row.add_child(key)
	var action := _label(action_text, 12, TEXT)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(action)


func _refresh_header() -> void:
	if _status_label == null:
		return
	if _last_save_ok:
		_status_label.text = "PROGRESSO SALVO"
		_status_label.add_theme_color_override("font_color", GREEN)
	else:
		_status_label.text = "A PAUSA NÃO AVANÇA O TEMPO"
		_status_label.add_theme_color_override("font_color", GOLD_SOFT)
	if _save_button != null and not _last_save_ok:
		_save_button.text = "SALVAR PROGRESSO"


func _refresh_nav_state() -> void:
	if _options_button == null:
		return
	_options_button.modulate = Color(1.0, 0.88, 0.62) if _page == "options" else Color.WHITE
	_menu_button.modulate = Color(1.0, 0.88, 0.62) if _page == "return_confirm" else Color.WHITE


func _show_home() -> void:
	_page = "home"
	_render_page()


func _show_options() -> void:
	_page = "options"
	_render_page()
	if _volume_slider != null:
		_volume_slider.grab_focus()


func _ask_return_to_menu() -> void:
	_page = "return_confirm"
	_render_page()


func _resume_game() -> void:
	if game != null:
		game.call("_resume")
	visible = false


func _save_game() -> void:
	if game == null:
		return
	var success := bool(game.call("_save_campaign", true))
	notify_saved(success)


func _return_to_menu() -> void:
	if game == null:
		return
	if bool(game.get("_active_campaign")):
		_last_save_ok = bool(game.call("_save_campaign", false))
		if not _last_save_ok:
			notify_saved(false)
			return
	visible = false
	game.call("_show_menu")


func _on_volume_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_linear(bus, maxf(value / 100.0, 0.0001))
	if _volume_value != null:
		_volume_value.text = "%d%%" % int(round(value))
	if _status_label != null:
		_status_label.text = "ÁUDIO AJUSTADO"
		_status_label.add_theme_color_override("font_color", GOLD_SOFT)
	_save_settings(value)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var volume := clampf(float(cfg.get_value("audio", "master_volume", AudioServer.get_bus_volume_linear(maxi(AudioServer.get_bus_index("Master"), 0)) * 100.0)), 0.0, 100.0)
		var bus := AudioServer.get_bus_index("Master")
		if bus >= 0:
			AudioServer.set_bus_volume_linear(bus, maxf(volume / 100.0, 0.0001))


func _save_settings(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", clampf(value, 0.0, 100.0))
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Não foi possível salvar as opções de áudio.")


func _nav_button(caption: String, hint: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 50)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", UiFrame.font())
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.055, 0.050, 0.040, 0.75), Color(0.29, 0.23, 0.15, 0.75), 1, 12))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.15, 0.12, 0.075, 0.95), GOLD_SOFT, 1, 12))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.19, 0.15, 0.09, 0.98), GOLD, 1, 12))
	button.add_theme_stylebox_override("focus", _panel_style(Color(0.15, 0.12, 0.075, 0.95), GOLD_SOFT, 1, 12))
	button.tooltip_text = hint
	return button


func _secondary_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", UiFrame.font())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.055, 0.050, 0.040, 0.75), Color(0.29, 0.23, 0.15, 0.75), 1, 10))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.15, 0.12, 0.075, 0.95), GOLD_SOFT, 1, 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.19, 0.15, 0.09, 0.98), GOLD, 1, 10))
	return button


func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", UiFrame.font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(0.43, 0.33, 0.20, 0.85)
	rule.custom_minimum_size = Vector2(0, 2)
	return rule


func _panel_style(bg: Color, border: Color, border_width: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

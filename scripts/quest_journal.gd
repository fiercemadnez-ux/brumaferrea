extends Control
# Diário de missões com filtros, detalhes, rastreamento e atalho para o mapa.

const BG := Color(0.035, 0.032, 0.028, 0.94)
const PANEL := Color(0.085, 0.073, 0.057, 0.98)
const PANEL_ALT := Color(0.12, 0.10, 0.075, 0.98)
const GOLD := Color(0.90, 0.70, 0.34)
const GOLD_SOFT := Color(0.70, 0.57, 0.34)
const TEXT := Color(0.88, 0.84, 0.74)
const TEXT_DIM := Color(0.57, 0.53, 0.46)
const GREEN := Color(0.57, 0.75, 0.48)
const RED := Color(0.78, 0.42, 0.32)

var game = null
var current_filter := "active"
var selected_quest_id := ""
var list_box: VBoxContainer
var list_count: Label
var detail_title: Label
var detail_status: Label
var detail_giver: Label
var detail_description: Label
var detail_objective: Label
var detail_reward: Label
var detail_tip: Label
var progress_bar: ProgressBar
var track_button: Button
var map_button: Button
var filter_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func open() -> void:
	current_filter = "active"
	selected_quest_id = ""
	visible = true
	_refresh_all()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1080, 610)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD_SOFT, 2, 18))
	center.add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)

	var title := _label("CADERNO DE VIAGEM", 29, GOLD)
	title_stack.add_child(title)
	var subtitle := _label("Recados, trabalhos e assuntos pendentes", 14, TEXT_DIM)
	title_stack.add_child(subtitle)

	var close := _button("FECHAR  [J]", PANEL_ALT, GOLD_SOFT)
	close.custom_minimum_size = Vector2(150, 44)
	close.pressed.connect(_close_journal)
	header.add_child(close)

	var divider := ColorRect.new()
	divider.color = Color(0.42, 0.32, 0.19, 0.85)
	divider.custom_minimum_size.y = 2
	root.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(360, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_ALT, Color(0.25, 0.21, 0.15), 1, 10))
	body.add_child(left_panel)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 9)
	left_panel.add_child(left)

	var list_heading := _label("PEDIDOS", 17, GOLD_SOFT)
	left.add_child(list_heading)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	left.add_child(tabs)
	_add_filter_button(tabs, "Ativas", "active")
	_add_filter_button(tabs, "Disponíveis", "available")
	_add_filter_button(tabs, "Concluídas", "completed")

	list_count = _label("Nenhum pedido", 12, TEXT_DIM)
	left.add_child(list_count)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(list_scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 7)
	list_scroll.add_child(list_box)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.25, 0.21, 0.15), 1, 16))
	body.add_child(right_panel)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	right_panel.add_child(right)

	detail_status = _label("ESCOLHA UM PEDIDO", 12, GOLD_SOFT)
	right.add_child(detail_status)
	detail_title = _label("O que ficou por fazer", 27, GOLD)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_title)
	detail_giver = _label("Selecione um pedido para ver os detalhes.", 14, TEXT_DIM)
	detail_giver.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_giver)

	var detail_divider := ColorRect.new()
	detail_divider.color = Color(0.34, 0.27, 0.17, 0.8)
	detail_divider.custom_minimum_size.y = 1
	right.add_child(detail_divider)

	detail_description = _label("Os pedidos ficam à esquerda. Escolha um para ver o que precisa ser feito.", 17, TEXT)
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_description)

	detail_objective = _label("", 16, TEXT)
	detail_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_objective)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 16
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _panel_style(Color(0.035, 0.03, 0.025), Color(0.24, 0.20, 0.15), 1, 4))
	progress_bar.add_theme_stylebox_override("fill", _panel_style(GREEN, GREEN, 0, 4))
	right.add_child(progress_bar)

	detail_reward = _label("", 16, GOLD_SOFT)
	right.add_child(detail_reward)
	detail_tip = _label("", 12, TEXT_DIM)
	detail_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_tip)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	right.add_child(actions)
	track_button = _button("RASTREAR NO MAPA", Color(0.20, 0.16, 0.10), GOLD)
	track_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_button.pressed.connect(_track_selected_quest)
	actions.add_child(track_button)
	map_button = _button("ABRIR MAPA [M]", Color(0.12, 0.16, 0.15), GREEN)
	map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_button.pressed.connect(_open_map)
	actions.add_child(map_button)

	var footer := _label("J / Esc fecha o diário  ·  Os marcadores de objetivo aparecem no mapa quando uma tarefa é rastreada", 12, TEXT_DIM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)


func _add_filter_button(parent: HBoxContainer, text_value: String, filter_value: String) -> void:
	var button := _button(text_value, PANEL, TEXT_DIM)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 36
	button.pressed.connect(_change_filter.bind(filter_value))
	parent.add_child(button)
	filter_buttons[filter_value] = button


func _refresh_all() -> void:
	_refresh_filter_styles()
	_refresh_list()
	if selected_quest_id != "":
		_refresh_details()
	else:
		var entries: Array = _journal_entries()
		if not entries.is_empty():
			_select_quest(str(entries[0].get("id", "")))
		else:
			_show_empty_details()


func _change_filter(filter_value: String) -> void:
	current_filter = filter_value
	selected_quest_id = ""
	_refresh_all()


func _journal_entries() -> Array:
	if game == null or game.quest_manager == null:
		return []
	return game.quest_manager.get_journal_entries(current_filter)


func _refresh_filter_styles() -> void:
	for filter_value in filter_buttons.keys():
		var button: Button = filter_buttons[filter_value]
		var selected: bool = str(filter_value) == current_filter
		button.add_theme_stylebox_override("normal", _panel_style(Color(0.24, 0.18, 0.10) if selected else PANEL, GOLD if selected else Color(0.25, 0.21, 0.15), 1, 5))
		button.add_theme_color_override("font_color", GOLD if selected else TEXT_DIM)


func _refresh_list() -> void:
	# A seleção pode disparar este refresh a partir do sinal pressed() de um
	# botão que pertence à própria lista. Retire os controles imediatamente,
	# mas adie a destruição até o Godot terminar de emitir o sinal.
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	var entries: Array = _journal_entries()
	if entries.size() == 1:
		list_count.text = "1 anotação"
	else:
		list_count.text = "%d anotações" % entries.size()
	if entries.is_empty():
		var empty_label := _label(_empty_list_message(), 15, TEXT_DIM)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(empty_label)
		return
	for entry in entries:
		var quest: Dictionary = entry
		var id := str(quest.get("id", ""))
		var title_text := str(quest.get("title", "Trabalho desconhecido"))
		var status := str(quest.get("status", ""))
		var state_text := _status_text(status)
		if status == "active" or status == "ready":
			state_text += "  ·  %d/%d" % [int(quest.get("progress", 0)), int(quest.get("target_count", 1))]
		var button := _button(title_text + "\n" + state_text, PANEL_ALT if id != selected_quest_id else Color(0.24, 0.18, 0.10), GOLD if id == selected_quest_id else TEXT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 66)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_select_quest.bind(id))
		list_box.add_child(button)


func _select_quest(quest_id: String) -> void:
	selected_quest_id = quest_id
	_refresh_list()
	_refresh_details()


func _refresh_details() -> void:
	if game == null or game.quest_manager == null:
		_show_empty_details()
		return
	var quest: Dictionary = game.quest_manager.get_quest_record(selected_quest_id)
	map_button.disabled = false
	if quest.is_empty():
		_show_empty_details()
		return
	var status := str(quest.get("status", ""))
	detail_status.text = _status_text(status).to_upper()
	detail_status.add_theme_color_override("font_color", GREEN if status in ["ready", "completed"] else GOLD_SOFT)
	detail_title.text = str(quest.get("title", "Trabalho desconhecido"))
	detail_giver.text = "De %s  ·  %s" % [str(quest.get("giver_name", "Morador")), str(quest.get("city_name", "local desconhecido"))]
	detail_description.text = str(quest.get("description", "Nenhuma descrição disponível."))
	var progress := int(quest.get("progress", 0))
	var required := maxi(1, int(quest.get("target_count", 1)))
	var is_collection: bool = str(quest.get("quest_type", "hunt")) == "collection"
	var target_label: String = str(quest.get("target_label", "inimigos"))
	var site_name: String = str(quest.get("site_name", "local indicado"))
	if status in ["active", "ready", "completed"]:
		if is_collection:
			detail_objective.text = "O QUE FALTA\nReúna %d unidades de %s em %s.\n%d de %d reunidas." % [required, target_label.to_lower(), site_name, progress, required]
		else:
			detail_objective.text = "O QUE FALTA\nDerrote %d %s.\n%d de %d derrotados." % [required, target_label, progress, required]
		progress_bar.max_value = required
		progress_bar.value = progress
		progress_bar.visible = true
	else:
		if is_collection:
			detail_objective.text = "O QUE FALTA\nReúna %d × %s em %s. Aceite o pedido para começar." % [required, target_label, site_name]
		else:
			detail_objective.text = "O QUE FALTA\n" + str(quest.get("target_count", 1)) + " " + target_label + " nos arredores. Aceite o pedido para começar."
		progress_bar.visible = false
	var potion_reward_text := ""
	var reward_potions := int(quest.get("reward_potions", 0))
	if reward_potions > 0:
		potion_reward_text = " · %d poção(ões)" % reward_potions
	detail_reward.text = "PAGAMENTO  ·  %d ouro%s" % [int(quest.get("reward_gold", 0)), potion_reward_text]
	var tracked: Dictionary = game.quest_manager.get_tracked_quest()
	var is_tracked: bool = not tracked.is_empty() and str(tracked.get("id", "")) == selected_quest_id
	if status == "offered":
		track_button.text = "ACEITE O PEDIDO"
		track_button.disabled = true
		if is_collection:
			detail_tip.text = "O marcador leva ao ponto de coleta indicado. Recolha o material nesse local; apenas a quantidade reunida ali contará para o contrato."
		else:
			detail_tip.text = "Ao aceitar, os inimigos aparecem na área marcada. Não é preciso esperar que surjam por conta própria."
	elif status == "completed":
		track_button.text = "PEDIDO CONCLUÍDO"
		track_button.disabled = true
		detail_tip.text = "Não há mais nada a fazer por aqui."
	else:
		track_button.text = "PARAR DE ACOMPANHAR" if is_tracked else "MARCAR NO MAPA"
		track_button.disabled = false
		if is_collection and status == "ready":
			detail_tip.text = "Está com tudo. Volte a quem fez o pedido para acertar o pagamento."
		elif is_collection:
			detail_tip.text = "Os materiais ficam em %s. Depois de reunir a quantidade pedida, volte para receber o pagamento." % site_name
		elif bool(quest.get("requires_quest_targets", false)) and status == "active":
			detail_tip.text = "O grupo desta caçada está na área marcada. Quando terminar, o mapa passa a indicar o caminho de volta."
		else:
			detail_tip.text = "O mapa indica a área da caçada. Quando terminar, marque o caminho de volta para a cidade."


func _show_empty_details() -> void:
	detail_status.text = "SEM REGISTRO"
	detail_status.add_theme_color_override("font_color", TEXT_DIM)
	detail_title.text = "Nada selecionado"
	detail_giver.text = "Fale com alguém da região para encontrar trabalho."
	if current_filter == "available":
		detail_description.text = "Ainda não chegou nenhum pedido. Converse com quem encontrar nas cidades; nem todo mundo precisa de ajuda, mas alguém pode ter um recado."
	elif current_filter == "completed":
		detail_description.text = "O que você já resolveu fica guardado aqui."
	else:
		detail_description.text = "Quando aceitar um pedido, ele aparecerá aqui com o que falta fazer."
	detail_objective.text = ""
	detail_reward.text = ""
	detail_tip.text = ""
	progress_bar.visible = false
	track_button.disabled = true
	track_button.text = "SEM PEDIDO ATIVO"
	map_button.disabled = true


func _empty_list_message() -> String:
	match current_filter:
		"available":
			return "Nenhum pedido por enquanto. Tente conversar com alguém da região."
		"completed":
			return "Ainda não há nada concluído."
		_:
			return "Nenhum pedido em andamento. Procure alguém que precise de ajuda."


func _status_text(status: String) -> String:
	match status:
		"offered":
			return "Oferta disponível"
		"active":
			return "Em andamento"
		"ready":
			return "Objetivo completo · voltar ao contratante"
		"completed":
			return "Concluída"
		_:
			return "Estado desconhecido"


func _track_selected_quest() -> void:
	if game == null or game.quest_manager == null or selected_quest_id == "":
		return
	var tracked: Dictionary = game.quest_manager.get_tracked_quest()
	if not tracked.is_empty() and str(tracked.get("id", "")) == selected_quest_id:
		game.quest_manager.clear_tracked_quest()
		game.show_msg("Rastreamento de missão removido do mapa.")
		_refresh_details()
		return
	if game.quest_manager.set_tracked_quest(selected_quest_id):
		game.show_msg("Objetivo marcado no mapa. Pressione M para consultar o mapa.")
		_refresh_details()


func _open_map() -> void:
	if game == null:
		return
	game.close_quest_log()
	game.open_map()


func _close_journal() -> void:
	if game != null and game.has_method("close_quest_log"):
		game.close_quest_log()


func _button(label_text: String, background: Color, foreground: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _panel_style(background, Color(0.26, 0.22, 0.16), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.20, 0.16, 0.10), GOLD_SOFT, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.15, 0.12, 0.08), GOLD, 1, 5))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.065, 0.06, 0.05), Color(0.18, 0.16, 0.12), 1, 5))
	return button


func _label(label_text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(background: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_content_margin_all(margin)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

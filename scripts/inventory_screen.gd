extends Control
# Inventário/ficha de personagem inspirado no diário de missões (J): moldura escura, ouro e painéis laterais.

const BG := Color(0.035, 0.032, 0.028, 0.94)
const PANEL := Color(0.085, 0.073, 0.057, 0.98)
const PANEL_ALT := Color(0.12, 0.10, 0.075, 0.98)
const GOLD := Color(0.90, 0.70, 0.34)
const GOLD_SOFT := Color(0.70, 0.57, 0.34)
const TEXT := Color(0.88, 0.84, 0.74)
const TEXT_DIM := Color(0.57, 0.53, 0.46)
const GREEN := Color(0.57, 0.75, 0.48)
const BLUE := Color(0.48, 0.68, 0.96)
const UiFrame := preload("res://scripts/ui_frame.gd")
const RESOURCE_CATALOG := preload("res://scripts/resource_catalog.gd")

var game = null
var current_tab := "weapons"
var selected_kind := ""
var selected_index := -1
var selected_attribute := "vigor"
var tab_buttons: Dictionary = {}

var info_line: Label
var xp_bar: ProgressBar
var list_box: VBoxContainer
var list_count: Label
var detail_status: Label
var detail_title: Label
var detail_description: Label
var detail_stats: Label
var action_button: Button
var detail_action_hint: Label
var quick_slot_row: HBoxContainer
var quick_slot_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func open() -> void:
	current_tab = "weapons"
	selected_kind = "weapon"
	selected_index = game.player.weapon_idx if game != null and game.player != null else 0
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
	frame.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD_SOFT, 2, 18, 18))
	center.add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)
	var title := _label("PERSONAGEM & INVENTÁRIO", 28, GOLD)
	title_stack.add_child(title)
	var subtitle := _label("Equipamento, recursos, magia e desenvolvimento", 13, TEXT_DIM)
	title_stack.add_child(subtitle)

	var close := _button("FECHAR  [I]", PANEL_ALT, GOLD_SOFT)
	close.custom_minimum_size = Vector2(150, 44)
	close.pressed.connect(_close_inventory)
	header.add_child(close)

	var divider := ColorRect.new()
	divider.color = Color(0.42, 0.32, 0.19, 0.85)
	divider.custom_minimum_size.y = 2
	root.add_child(divider)

	info_line = _label("NÍVEL 1   VIDA 100/100   MANA 50/50   DEFESA 0   OURO 50", 14, TEXT)
	root.add_child(info_line)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size.y = 10
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", _panel_style(Color(0.035, 0.03, 0.025), Color(0.24, 0.20, 0.15), 1, 4, 1))
	xp_bar.add_theme_stylebox_override("fill", _panel_style(GOLD, GOLD, 0, 4, 1))
	root.add_child(xp_bar)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(370, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_ALT, Color(0.25, 0.21, 0.15), 1, 10, 12))
	body.add_child(left_panel)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left_panel.add_child(left)
	left.add_child(_label("PERTENCES", 16, GOLD_SOFT))

	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	left.add_child(tabs)
	_add_tab(tabs, "Consumíveis", "consumables")
	_add_tab(tabs, "Armas", "weapons")
	_add_tab(tabs, "Armaduras", "armors")
	_add_tab(tabs, "Magias", "spells")
	_add_tab(tabs, "Recursos", "resources")
	_add_tab(tabs, "Atributos", "attributes")
	_add_tab(tabs, "Perícias", "skills")

	list_count = _label("", 12, TEXT_DIM)
	left.add_child(list_count)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(list_box)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.25, 0.21, 0.15), 1, 16, 18))
	body.add_child(right_panel)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	right_panel.add_child(right)
	detail_status = _label("FICHA DO PERSONAGEM", 12, GOLD_SOFT)
	right.add_child(detail_status)
	detail_title = _label("Os Cânticos dos Sete: Brumaférrea", 28, GOLD)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_title)
	detail_description = _label("Selecione um item para ver os detalhes.", 15, TEXT_DIM)
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_description)

	var detail_divider := ColorRect.new()
	detail_divider.color = Color(0.34, 0.27, 0.17, 0.8)
	detail_divider.custom_minimum_size.y = 1
	right.add_child(detail_divider)

	detail_stats = _label("", 16, TEXT)
	detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_stats)

	detail_action_hint = _label("", 12, TEXT_DIM)
	detail_action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(detail_action_hint)
	quick_slot_row = HBoxContainer.new()
	quick_slot_row.add_theme_constant_override("separation", 6)
	quick_slot_row.visible = false
	for slot_index in range(3):
		var quick_button := _button("Atribuir %d" % (slot_index + 1), PANEL_ALT, GOLD_SOFT)
		quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_button.custom_minimum_size.y = 36
		quick_button.add_theme_font_size_override("font_size", 12)
		quick_button.pressed.connect(_assign_selected_consumable_to_slot.bind(slot_index))
		quick_slot_buttons.append(quick_button)
		quick_slot_row.add_child(quick_button)
	right.add_child(quick_slot_row)

	action_button = _button("SELECIONE UMA OPÇÃO", PANEL_ALT, GOLD_SOFT)
	action_button.custom_minimum_size.y = 44
	action_button.pressed.connect(_perform_primary_action)
	right.add_child(action_button)

	var footer := _label("I / Esc fecha o inventário  ·  Equipe armas e magias nesta ficha", 12, TEXT_DIM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)


func _add_tab(parent: Control, text_value: String, tab_value: String) -> void:
	var b := _button(text_value, PANEL, TEXT_DIM)
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(_switch_tab.bind(tab_value))
	parent.add_child(b)
	tab_buttons[tab_value] = b


func _switch_tab(tab_value: String) -> void:
	current_tab = tab_value
	selected_kind = ""
	selected_index = -1
	if game != null and game.player != null:
		match current_tab:
			"consumables":
				selected_kind = "potion"
				selected_index = 0
			"weapons":
				selected_kind = "weapon"
				selected_index = game.player.weapon_idx
			"armors":
				selected_kind = "armor"
				selected_index = game.player.armor_idx
			"resources":
				selected_kind = "gold"
				selected_index = 0
			"spells":
				if not game.player.spells.is_empty():
					selected_kind = "spell"
					selected_index = game.player.spell_idx
			"attributes":
				selected_kind = "attribute"
			"skills":
				selected_kind = "skill"
				selected_index = 0 if not _proficiency_entries().is_empty() else -1
	_refresh_all()


func _refresh_all() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	info_line.text = "NÍVEL %d   XP %d/%d   VIDA %d/%d   MANA %d/%d   DEF %d   OURO %d" % [p.level, p.experience, p.get_xp_to_next_level(), p.hp, p.get_max_hp(), int(p.mana), int(p.get_max_mana()), p.armor_value(), p.gold]
	xp_bar.max_value = maxf(1.0, float(p.get_xp_to_next_level()))
	xp_bar.value = p.experience
	for tab_value in tab_buttons.keys():
		var b: Button = tab_buttons[tab_value]
		var active: bool = str(tab_value) == current_tab
		b.add_theme_stylebox_override("normal", _panel_style(Color(0.24, 0.18, 0.10) if active else PANEL, GOLD if active else Color(0.25, 0.21, 0.15), 1, 5, 4))
		b.add_theme_color_override("font_color", GOLD if active else TEXT_DIM)
	_refresh_list()
	_update_detail()


func _refresh_list() -> void:
	# O refresh pode ser chamado pelo sinal pressed() de um botão da própria lista.
	# Remover do container agora e adiar a destruição evita liberar um Control
	# enquanto ele ainda está emitindo sinais.
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	var p = game.player
	var count := 0
	match current_tab:
		"weapons":
			_add_section("ARMAS")
			for i in p.weapons.size():
				var w: Dictionary = p.weapons[i]
				var equipped: bool = p.active_equipment_type == "weapon" and i == p.weapon_idx
				var mark := "  ·  EQUIPADA" if equipped else ""
				_add_entry("weapon", i, "%s\nDano %d–%d%s" % [w.get("name", "Arma"), int(w.get("dmg_min", 0)), int(w.get("dmg_max", 0)), mark], equipped)
				count += 1
		"armors":
			_add_section("ARMADURAS")
			for i in p.armors.size():
				var a: Dictionary = p.armors[i]
				var equipped_armor: bool = i == p.armor_idx
				var mark_a := "  ·  VESTIDA" if equipped_armor else ""
				_add_entry("armor", i, "%s\nDefesa %d%s" % [a.get("name", "Armadura"), int(a.get("def", 0)), mark_a], equipped_armor)
				count += 1
		"consumables":
			_add_section("CONSUMÍVEIS")
			_add_entry("potion", 0, "Poção de Cura\nQuantidade: %d" % p.potions, false)
			count = 1
			_add_label("Use 1, 2 e 3 para os espaços rápidos. Selecione a poção e atribua-a ao espaço desejado.", TEXT_DIM, 13)
		"resources":
			_add_section("MOEDA")
			_add_entry("gold", 0, "Ouro\n%d moedas" % p.gold, false)
			count = 1
			_add_section("RECURSOS NATURAIS")
			var resource_entries: Array[Dictionary] = _resource_entries()
			if resource_entries.is_empty():
				_add_label("Você ainda não recolheu minérios ou plantas.", TEXT_DIM, 14)
			else:
				for resource_index in resource_entries.size():
					var resource_entry: Dictionary = resource_entries[resource_index]
					var resource_id: String = str(resource_entry.get("id", ""))
					var resource_amount: int = int(resource_entry.get("amount", 0))
					_add_entry("resource", resource_index, "%s\nQuantidade: %d" % [RESOURCE_CATALOG.display_name(resource_id), resource_amount], resource_index == selected_index)
					count += 1
		"spells":
			_add_section("MAGIAS APRENDIDAS")
			if p.spells.is_empty():
				_add_label("Nenhuma magia conhecida. Procure pergaminhos ou visite uma curandeira.", TEXT_DIM, 14)
			else:
				for i in p.spells.size():
					var spell: Dictionary = p.spells[i]
					var equipped_spell: bool = p.active_equipment_type == "spell" and i == p.spell_idx
					var marker := "  ·  EQUIPADA" if equipped_spell else ""
					var spell_key := "magic_" + str(spell.get("id", ""))
					var proficiency: int = p.get_proficiency_value(spell_key)
					_add_entry("spell", i, "%s\nProficiência %d/100%s" % [p.get_spell_display_name(spell), proficiency, marker], equipped_spell)
					count += 1
		"skills":
			var entries := _proficiency_entries()
			var has_magic_section := false
			var has_weapon_section := false
			for i in entries.size():
				var skill: Dictionary = entries[i]
				var is_magic: bool = bool(skill.get("magic", false))
				if is_magic and not has_magic_section:
					_add_section("MAGIA")
					has_magic_section = true
				elif not is_magic and not has_weapon_section:
					_add_section("COMBATE CORPO A CORPO")
					has_weapon_section = true
				var skill_key := str(skill["key"])
				var value: int = p.get_proficiency_value(skill_key)
				var rank: int = p.get_proficiency_rank(skill_key)
				var rank_text: String = p.get_proficiency_rank_name(rank)
				_add_entry("skill", i, "%s\n%s · %d/100" % [_skill_display_name(skill, rank), rank_text, value], i == selected_index)
				count += 1
			if entries.is_empty():
				_add_label("Use magias e acerte inimigos para desenvolver suas proficiências.", TEXT_DIM, 14)
		"attributes":
			_add_section("ATRIBUTOS")
			for stat in ["vigor", "strength", "agility", "arcana"]:
				var selected: bool = str(stat) == selected_attribute
				_add_entry("attribute", -1, "%s\nValor: %d" % [_attribute_name(stat), int(p.attributes.get(stat, 5))], selected, stat)
				count += 1
			_add_label("Pontos disponíveis: %d" % p.attribute_points, GOLD_SOFT, 14)
	list_count.text = "%d registro(s)" % count


func _add_section(text_value: String) -> void:
	var l := _label(text_value, 12, GOLD_SOFT)
	list_box.add_child(l)


func _add_label(text_value: String, col: Color, size_value: int = 15) -> void:
	var l := _label(text_value, size_value, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(l)


func _add_entry(kind: String, index: int, text_value: String, active: bool, attribute: String = "") -> void:
	var b := _button(text_value, Color(0.24, 0.18, 0.10) if active else PANEL_ALT, GOLD if active else TEXT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	if kind == "attribute":
		b.pressed.connect(_select_attribute.bind(attribute))
	else:
		b.pressed.connect(_select_item.bind(kind, index))
	list_box.add_child(b)


func _select_item(kind: String, index: int) -> void:
	selected_kind = kind
	selected_index = index
	_refresh_all()


func _select_attribute(attribute: String) -> void:
	selected_kind = "attribute"
	selected_attribute = attribute
	selected_index = -1
	_refresh_all()


func _update_detail() -> void:
	var p = game.player
	action_button.visible = true
	action_button.disabled = false
	detail_action_hint.text = ""
	quick_slot_row.visible = false
	if selected_kind == "weapon" and selected_index >= 0 and selected_index < p.weapons.size():
		var w: Dictionary = p.weapons[selected_index]
		var equipped: bool = p.active_equipment_type == "weapon" and selected_index == int(p.weapon_idx)
		var weapon_prof_key: String = p.get_weapon_proficiency_key(w)
		var weapon_prof_value: int = p.get_proficiency_value(weapon_prof_key)
		var weapon_prof_rank: int = p.get_proficiency_rank(weapon_prof_key)
		var weapon_multiplier: float = p.get_proficiency_multiplier(weapon_prof_key, false)
		var min_damage := roundi(float(int(w.get("dmg_min", 0)) + p.melee_damage_bonus()) * weapon_multiplier)
		var max_damage := roundi(float(int(w.get("dmg_max", 0)) + p.melee_damage_bonus()) * weapon_multiplier)
		detail_status.text = "EQUIPAMENTO  /  ARMA"
		detail_title.text = str(w.get("name", "Arma"))
		detail_description.text = "Arma corpo a corpo equipada em primeira pessoa. Acertos reais desenvolvem sua proficiência."
		detail_stats.text = "Dano atual: %d–%d\nAlcance: %.1f m\nTempo entre ataques: %.2f s\nForça: %d (bônus +%d)\nProficiência: %d/100 — %s" % [min_damage, max_damage, float(w.get("reach", 0.0)), float(w.get("cd", 0.0)), int(p.attributes.get("strength", 5)), p.melee_damage_bonus(), weapon_prof_value, p.get_proficiency_rank_name(weapon_prof_rank)]
		action_button.text = "ARMA JÁ EQUIPADA" if equipped else "EQUIPAR ARMA"
		action_button.disabled = equipped
	elif selected_kind == "armor" and selected_index >= 0 and selected_index < p.armors.size():
		var armor: Dictionary = p.armors[selected_index]
		var equipped_armor: bool = selected_index == int(p.armor_idx)
		detail_status.text = "EQUIPAMENTO  /  ARMADURA"
		detail_title.text = str(armor.get("name", "Armadura"))
		detail_description.text = "Proteção usada para reduzir o dano recebido dos inimigos."
		detail_stats.text = "Defesa: %d\nDano recebido é reduzido pela defesa da armadura.\n\nO equipamento permanece com você durante a sessão." % int(armor.get("def", 0))
		action_button.text = "ARMADURA JÁ VESTIDA" if equipped_armor else "VESTIR ARMADURA"
		action_button.disabled = equipped_armor
	elif selected_kind == "potion":
		detail_status.text = "ITENS  /  CONSUMÍVEIS"
		detail_title.text = "Poção de Cura"
		detail_description.text = "Um frasco de preparado restaurador para emergências."
		detail_stats.text = "Quantidade: %d\nRecupera até 40 pontos de vida.\n\nAtribua esta poção a um dos três espaços rápidos para usá-la pelas teclas 1, 2 ou 3." % p.potions
		var slot_summary := PackedStringArray()
		for slot_index in range(3):
			var assigned: bool = p.consumable_slots.size() > slot_index and p.consumable_slots[slot_index] == "potion"
			slot_summary.append("%d (%s)" % [slot_index + 1, "Poção" if assigned else "vazio"])
		detail_action_hint.text = "Espaços atuais: %s" % ", ".join(slot_summary)
		quick_slot_row.visible = true
		for slot_index in range(3):
			var assigned: bool = p.consumable_slots.size() > slot_index and p.consumable_slots[slot_index] == "potion"
			if assigned:
				quick_slot_buttons[slot_index].text = "ESPAÇO %d · ATRIBUÍDO" % (slot_index + 1)
			else:
				quick_slot_buttons[slot_index].text = "ATRIBUIR %d" % (slot_index + 1)
		action_button.text = "USAR POÇÃO"
		action_button.disabled = p.potions <= 0 or p.hp >= p.get_max_hp()
	elif selected_kind == "gold":
		detail_status.text = "PERTENCES  /  MOEDA"
		detail_title.text = "Ouro"
		detail_description.text = "Moedas aceitas pelos mercadores de Brumaférrea."
		detail_stats.text = "Você carrega %d moedas.\n\nOuro é obtido em combates, missões e outros achados." % p.gold
		action_button.visible = false
	elif selected_kind == "resource":
		var resource_entries_detail: Array[Dictionary] = _resource_entries()
		if selected_index >= 0 and selected_index < resource_entries_detail.size():
			var resource_entry_detail: Dictionary = resource_entries_detail[selected_index]
			var resource_id_detail: String = str(resource_entry_detail.get("id", ""))
			var resource_record: Dictionary = RESOURCE_CATALOG.definition(resource_id_detail)
			detail_status.text = "PERTENCES  /  RECURSO NATURAL"
			detail_title.text = RESOURCE_CATALOG.display_name(resource_id_detail)
			detail_description.text = str(resource_record.get("description", "Material recolhido durante a exploração."))
			var unit_price: int = RESOURCE_CATALOG.base_price(resource_id_detail)
			detail_stats.text = "Quantidade: %d\nValor de referência: %d ouro por unidade.\n\nFerreiros preferem minérios; curandeiras pagam melhor por plantas medicinais; mercadores compram ambos." % [int(resource_entry_detail.get("amount", 0)), unit_price]
			action_button.visible = false
	elif selected_kind == "spell" and selected_index >= 0 and selected_index < p.spells.size():
		var spell: Dictionary = p.spells[selected_index]
		var active_spell: bool = p.active_equipment_type == "spell" and selected_index == int(p.spell_idx)
		var spell_key := "magic_" + str(spell.get("id", ""))
		var spell_prof_value: int = p.get_proficiency_value(spell_key)
		var spell_rank: int = p.get_proficiency_rank(spell_key)
		var spell_next_target: int = p.get_proficiency_next_threshold(spell_key)
		var spell_potency: float = p.get_proficiency_multiplier(spell_key, true)
		detail_status.text = "MAGIA  /  PROFICIÊNCIA: %s" % p.get_proficiency_rank_name(spell_rank).to_upper()
		detail_title.text = p.get_spell_display_name(spell)
		detail_description.text = "Ao equipar esta magia, ela toma o lugar da arma nas suas mãos. Feitiços ofensivos podem ser mantidos para conjurar repetidamente; cura exige apenas um toque."
		if str(spell.get("id", "")) == "heal":
			detail_stats.text = "Custo: %d mana\nRestauração atual: %d vida\nPotência: +%d%%\nProficiência: %d/100\nPróxima evolução: %s" % [int(spell.get("cost", 0)), roundi(float(spell.get("heal", 0)) * spell_potency), roundi((spell_potency - 1.0) * 100.0), spell_prof_value, "Nível máximo" if spell_rank >= 4 else ("%d/100" % spell_next_target)]
		else:
			var low_damage := roundi(float(int(spell.get("dmg_min", 0)) + p.spell_damage_bonus()) * spell_potency)
			var high_damage := roundi(float(int(spell.get("dmg_max", 0)) + p.spell_damage_bonus()) * spell_potency)
			detail_stats.text = "Custo: %d mana\nDano atual: %d–%d\nPotência: +%d%%\nAlcance máximo: %.0f m\nProficiência: %d/100\nPróxima evolução: %s" % [int(spell.get("cost", 0)), low_damage, high_damage, roundi((spell_potency - 1.0) * 100.0), float(spell.get("range", 0.0)), spell_prof_value, "Nível máximo" if spell_rank >= 4 else ("%d/100" % spell_next_target)]
		action_button.text = "MAGIA JÁ EQUIPADA" if active_spell else "EQUIPAR MAGIA"
		action_button.disabled = active_spell
	elif selected_kind == "skill":
		var entries := _proficiency_entries()
		if selected_index >= 0 and selected_index < entries.size():
			var skill: Dictionary = entries[selected_index]
			var skill_key := str(skill["key"])
			var is_magic: bool = bool(skill.get("magic", false))
			var skill_value: int = p.get_proficiency_value(skill_key)
			var skill_rank: int = p.get_proficiency_rank(skill_key)
			var skill_next_target: int = p.get_proficiency_next_threshold(skill_key)
			var skill_multiplier: float = p.get_proficiency_multiplier(skill_key, is_magic)
			detail_status.text = "PROFICIÊNCIA  /  %s" % p.get_proficiency_rank_name(skill_rank).to_upper()
			detail_title.text = _skill_display_name(skill, skill_rank)
			detail_description.text = "A proficiência cresce através do uso real: conjurar esta magia ou acertar inimigos com esta arma."
			var use_label := "conjurações" if is_magic else "acertos"
			var power_label := "potência mágica" if is_magic else "dano corpo a corpo"
			detail_stats.text = "Proficiência: %d/100 %s\nGrau: %s\nBônus de %s: +%d%%\nPróxima evolução: %s\n\nMarcos: 10, 25, 50 e 100 usos válidos." % [skill_value, use_label, p.get_proficiency_rank_name(skill_rank), power_label, roundi((skill_multiplier - 1.0) * 100.0), "Nível máximo" if skill_rank >= 4 else ("%d/100" % skill_next_target)]
			action_button.visible = false
			detail_action_hint.text = "Não há pontos para distribuir: pratique a habilidade para evoluí-la."
		else:
			detail_status.text = "PROFICIÊNCIAS"
			detail_title.text = "Pratique para evoluir"
			detail_description.text = "Use uma magia aprendida ou acerte inimigos com uma arma."
			detail_stats.text = "Cada habilidade progride separadamente."
			action_button.visible = false
	elif selected_kind == "attribute":
		var stat_value := int(p.attributes.get(selected_attribute, 5))
		detail_status.text = "DESENVOLVIMENTO  /  ATRIBUTOS"
		detail_title.text = _attribute_name(selected_attribute)
		detail_description.text = _attribute_description(selected_attribute)
		detail_stats.text = "Valor atual: %d\nPontos disponíveis: %d\n\n%s" % [stat_value, p.attribute_points, _attribute_effect(selected_attribute)]
		action_button.text = "AUMENTAR ATRIBUTO (+1)"
		action_button.disabled = p.attribute_points <= 0
		detail_action_hint.text = "Ganhe níveis derrotando criaturas para obter pontos de atributo."
	else:
		detail_status.text = "FICHA DO PERSONAGEM"
		detail_title.text = "Nível %d" % p.level
		detail_description.text = "Você está explorando Os Cânticos dos Sete: Brumaférrea. Escolha um item à esquerda ou consulte seus atributos." 
		detail_stats.text = "Experiência: %d / %d\nPontos de atributo: %d\n\nVigor: %d    Força: %d\nAgilidade: %d    Arcana: %d\n\nArma: %s\nArmadura: %s" % [p.experience, p.get_xp_to_next_level(), p.attribute_points, int(p.attributes.get("vigor", 5)), int(p.attributes.get("strength", 5)), int(p.attributes.get("agility", 5)), int(p.attributes.get("arcana", 5)), str(p.cur_weapon().get("name", "Punhos")), str(p.cur_armor().get("name", "Roupas de Viajante"))]
		action_button.text = "ESCOLHA UMA OPÇÃO"
		action_button.disabled = true


func _resource_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game == null or game.player == null:
		return result
	var p = game.player
	var resource_ids: Array = p.resources.keys()
	resource_ids.sort()
	for resource_key in resource_ids:
		var resource_id: String = str(resource_key)
		var amount: int = int(p.resources.get(resource_id, 0))
		if amount > 0:
			result.append({"id": resource_id, "amount": amount})
	return result


func _proficiency_entries() -> Array:
	var entries: Array = []
	var p = game.player
	if p == null:
		return entries
	for spell in p.spells:
		entries.append({"key": "magic_" + str(spell.get("id", "")), "id": str(spell.get("id", "")), "name": str(spell.get("name", "Magia")), "magic": true})
	for weapon in p.weapons:
		entries.append({"key": p.get_weapon_proficiency_key(weapon), "id": str(weapon.get("id", "fist")), "name": str(weapon.get("name", "Arma")), "magic": false})
	return entries


func _skill_display_name(skill: Dictionary, rank: int) -> String:
	var skill_name := str(skill.get("name", "Habilidade"))
	if bool(skill.get("magic", false)):
		return game.player.get_spell_display_name({"id": str(skill.get("id", "")), "name": skill_name})
	if rank <= 0:
		return skill_name
	return "%s — %s" % [skill_name, game.player.get_proficiency_rank_name(rank)]


func _perform_primary_action() -> void:
	var p = game.player
	match selected_kind:
		"weapon":
			if selected_index >= 0 and selected_index < p.weapons.size():
				p.equip_weapon(selected_index)
		"armor":
			if selected_index >= 0 and selected_index < p.armors.size():
				p.equip_armor(selected_index)
		"potion":
			p.drink_potion()
		"spell":
			if selected_index >= 0 and selected_index < p.spells.size():
				p.equip_spell(selected_index)
		"attribute":
			if p.spend_attribute_point(selected_attribute):
				game.show_msg("%s aumentado para %d." % [_attribute_name(selected_attribute), int(p.attributes.get(selected_attribute, 5))])
	_refresh_all()




func _assign_selected_consumable_to_slot(slot_index: int) -> void:
	if selected_kind != "potion" or game == null or game.player == null:
		return
	game.player.assign_consumable_slot(slot_index, "potion")
	game.show_msg("Poção atribuída ao espaço rápido %d." % (slot_index + 1))
	_refresh_all()


func _attribute_name(attribute: String) -> String:
	match attribute:
		"vigor": return "Vigor"
		"strength": return "Força"
		"agility": return "Agilidade"
		"arcana": return "Arcana"
	return attribute.capitalize()


func _attribute_description(attribute: String) -> String:
	match attribute:
		"vigor": return "Resiliência, fôlego e capacidade de suportar ferimentos."
		"strength": return "Poder físico aplicado aos golpes com armas corpo a corpo."
		"agility": return "Precisão e oportunidade para encontrar aberturas em um golpe."
		"arcana": return "Controle dos resquícios mágicos deixados pela criação do mundo."
	return "Atributo do personagem."


func _attribute_effect(attribute: String) -> String:
	match attribute:
		"vigor": return "+8 pontos de vida máxima por ponto de Vigor."
		"strength": return "+2 de dano corpo a corpo por ponto de Força."
		"agility": return "+2% de chance crítica por ponto de Agilidade (máximo de 45%)."
		"arcana": return "+8 de mana máxima e +2 de dano mágico por ponto de Arcana."
	return ""


func _close_inventory() -> void:
	if game != null:
		game.toggle_inventory()


func _label(text_value: String, size_value: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_font_override("font", UiFrame.font())
	l.add_theme_color_override("font_color", col)
	return l


func _button(text_value: String, background: Color, font_color: Color) -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiFrame.font())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_stylebox_override("normal", _panel_style(background, Color(0.25, 0.21, 0.15), 1, 5, 4))
	b.add_theme_stylebox_override("hover", _panel_style(Color(0.20, 0.16, 0.105), GOLD_SOFT, 1, 5, 4))
	b.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.18, 0.10), GOLD, 1, 5, 4))
	b.add_theme_stylebox_override("disabled", _panel_style(Color(0.08, 0.07, 0.055), Color(0.20, 0.17, 0.13), 1, 5, 4))
	return b


func _panel_style(background: Color, border: Color, border_width: int, radius: int, margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

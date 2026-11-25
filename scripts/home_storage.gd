extends Control
# Baú pessoal da casa natal. Transfere equipamentos e itens, salvando cada mudança
# no armazenamento local do jogador para preservar o conteúdo entre sessões.

const UiFrame := preload("res://scripts/ui_frame.gd")
const RESOURCE_CATALOG := preload("res://scripts/resource_catalog.gd")
const BG := Color(0.025, 0.023, 0.020, 0.94)
const PANEL := Color(0.075, 0.065, 0.050, 0.985)
const PANEL_ALT := Color(0.115, 0.095, 0.070, 0.99)
const GOLD := Color(0.86, 0.68, 0.34)
const GOLD_SOFT := Color(0.63, 0.51, 0.32)
const TEXT := Color(0.88, 0.84, 0.75)
const MUTED := Color(0.58, 0.54, 0.46)
const SELECTED := Color(0.28, 0.20, 0.10)

var game = null
var _player_list: VBoxContainer
var _chest_list: VBoxContainer
var _selection_label: Label
var _transfer_button: Button
var _selected_side := ""
var _selected_item: Dictionary = {}
var _empty_hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func open() -> void:
	_selected_side = ""
	_selected_item.clear()
	visible = true
	_refresh_lists()
	_refresh_selection()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = BG
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1000, 560)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD_SOFT, 2, 14, 16))
	center.add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	frame.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_label("BAÚ DA CASA", 26, GOLD))
	var subtitle := _label("Seus pertences ficam guardados aqui mesmo quando você vai embora.", 13, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(subtitle)
	header.add_child(title_stack)
	var close_button := _button("FECHAR  [Esc]", PANEL_ALT, TEXT)
	close_button.custom_minimum_size = Vector2(145, 42)
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	var divider := ColorRect.new()
	divider.color = Color(0.42, 0.32, 0.19, 0.9)
	divider.custom_minimum_size.y = 2
	root.add_child(divider)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	root.add_child(columns)
	_player_list = _build_column(columns, "MOCHILA", "player")
	_chest_list = _build_column(columns, "NO BAÚ", "chest")

	var footer_rule := ColorRect.new()
	footer_rule.color = Color(0.28, 0.23, 0.16, 0.95)
	footer_rule.custom_minimum_size.y = 1
	root.add_child(footer_rule)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	_selection_label = _label("Selecione um item para guardar ou retirar.", 13, MUTED)
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_selection_label)
	_transfer_button = _button("GUARDAR →", SELECTED, GOLD)
	_transfer_button.custom_minimum_size = Vector2(175, 42)
	_transfer_button.disabled = true
	_transfer_button.pressed.connect(_transfer_selected)
	footer.add_child(_transfer_button)


func _build_column(parent: HBoxContainer, heading: String, side: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_ALT, Color(0.24, 0.20, 0.14), 1, 10, 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	content.add_child(_label(heading, 17, GOLD_SOFT))
	var line := ColorRect.new()
	line.color = Color(0.28, 0.23, 0.16, 0.9)
	line.custom_minimum_size.y = 1
	content.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	if side == "player":
		return list
	return list


func _refresh_lists() -> void:
	if not is_instance_valid(_player_list) or not is_instance_valid(_chest_list):
		return
	_clear_children(_player_list)
	_clear_children(_chest_list)
	_add_items_to_list(_player_list, "player")
	_add_items_to_list(_chest_list, "chest")


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _add_items_to_list(list: VBoxContainer, side: String) -> void:
	var descriptors := _collect_items(side)
	if descriptors.is_empty():
		var empty := _label("Vazio", 14, MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 44
		list.add_child(empty)
		return
	for descriptor in descriptors:
		var label_text := str(descriptor.get("label", "Item"))
		var button := _button(label_text, PANEL, TEXT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chosen := side == _selected_side and _same_descriptor(descriptor, _selected_item)
		if chosen:
			button.add_theme_stylebox_override("normal", _panel_style(SELECTED, GOLD_SOFT, 1, 5, 8))
		button.pressed.connect(_select_item.bind(side, descriptor))
		list.add_child(button)


func _collect_items(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game == null or game.player == null:
		return result
	var p = game.player
	var storage: Dictionary = game.player_home_storage
	if side == "player":
		for i in range(p.weapons.size()):
			var weapon: Dictionary = p.weapons[i]
			if str(weapon.get("id", "")) == "fist":
				continue
			var label := str(weapon.get("name", "Arma"))
			if i == int(p.weapon_idx):
				label += "  · equipada"
			result.append({"kind": "weapon", "index": i, "label": label})
		for i in range(p.armors.size()):
			var armor: Dictionary = p.armors[i]
			if str(armor.get("id", "")) == "robe":
				continue
			var label := str(armor.get("name", "Armadura"))
			if i == int(p.armor_idx):
				label += "  · vestida"
			result.append({"kind": "armor", "index": i, "label": label})
		if int(p.potions) > 0:
			result.append({"kind": "potion", "id": "potion", "label": "Poções de cura ×%d" % int(p.potions)})
		var resource_ids: Array = p.resources.keys()
		resource_ids.sort()
		for resource_id_value in resource_ids:
			var resource_id := str(resource_id_value)
			var amount := int(p.resources.get(resource_id, 0))
			if amount > 0:
				result.append({"kind": "resource", "id": resource_id, "label": "%s ×%d" % [RESOURCE_CATALOG.display_name(resource_id), amount]})
	else:
		for i in range(storage.get("weapons", []).size()):
			var weapon: Dictionary = storage["weapons"][i]
			result.append({"kind": "weapon", "index": i, "label": str(weapon.get("name", "Arma"))})
		for i in range(storage.get("armors", []).size()):
			var armor: Dictionary = storage["armors"][i]
			result.append({"kind": "armor", "index": i, "label": str(armor.get("name", "Armadura"))})
		var potion_count := int(storage.get("potions", 0))
		if potion_count > 0:
			result.append({"kind": "potion", "id": "potion", "label": "Poções de cura ×%d" % potion_count})
		var stored_resources: Dictionary = storage.get("resources", {})
		var stored_ids: Array = stored_resources.keys()
		stored_ids.sort()
		for resource_id_value in stored_ids:
			var resource_id := str(resource_id_value)
			var amount := int(stored_resources.get(resource_id, 0))
			if amount > 0:
				result.append({"kind": "resource", "id": resource_id, "label": "%s ×%d" % [RESOURCE_CATALOG.display_name(resource_id), amount]})
	return result


func _select_item(side: String, descriptor: Dictionary) -> void:
	_selected_side = side
	_selected_item = descriptor.duplicate(true)
	_refresh_lists()
	_refresh_selection()


func _same_descriptor(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or str(a.get("kind", "")) != str(b.get("kind", "")):
		return false
	if a.has("index") or b.has("index"):
		return int(a.get("index", -1)) == int(b.get("index", -1))
	return str(a.get("id", "")) == str(b.get("id", ""))


func _refresh_selection() -> void:
	if not is_instance_valid(_selection_label) or not is_instance_valid(_transfer_button):
		return
	if _selected_item.is_empty():
		_selection_label.text = "Selecione um item para guardar ou retirar."
		_transfer_button.disabled = true
		_transfer_button.text = "GUARDAR →"
		return
	var selected_label := str(_selected_item.get("label", "Item"))
	_selection_label.text = selected_label
	_transfer_button.disabled = false
	_transfer_button.text = "GUARDAR →" if _selected_side == "player" else "← RETIRAR"


func _transfer_selected() -> void:
	if game == null or game.player == null or _selected_item.is_empty():
		return
	var p = game.player
	var kind := str(_selected_item.get("kind", ""))
	var index := int(_selected_item.get("index", -1))
	var item_id := str(_selected_item.get("id", ""))
	var storing := _selected_side == "player"
	var storage: Dictionary = game.player_home_storage
	if storing:
		match kind:
			"weapon":
				if index < 0 or index >= p.weapons.size() or str(p.weapons[index].get("id", "")) == "fist":
					return
				var moved_weapon: Dictionary = p.weapons[index].duplicate(true)
				storage["weapons"].append(moved_weapon)
				p.weapons.remove_at(index)
				if index < int(p.weapon_idx):
					p.weapon_idx -= 1
				elif index == int(p.weapon_idx):
					p.weapon_idx = 0
				p.weapon_idx = clampi(int(p.weapon_idx), 0, p.weapons.size() - 1)
				p.call("_build_weapon_model", str(p.cur_weapon().get("model", "fist")))
			"armor":
				if index < 0 or index >= p.armors.size() or str(p.armors[index].get("id", "")) == "robe":
					return
				var moved_armor: Dictionary = p.armors[index].duplicate(true)
				storage["armors"].append(moved_armor)
				p.armors.remove_at(index)
				if index < int(p.armor_idx):
					p.armor_idx -= 1
				elif index == int(p.armor_idx):
					p.armor_idx = 0
				p.armor_idx = clampi(int(p.armor_idx), 0, p.armors.size() - 1)
			"potion":
				var potion_stack := int(p.potions)
				if potion_stack <= 0:
					return
				p.potions = 0
				storage["potions"] = int(storage.get("potions", 0)) + potion_stack
			"resource":
				var resource_stack := int(p.resources.get(item_id, 0))
				if resource_stack <= 0 or not p.remove_resource(item_id, resource_stack):
					return
				var resource_store: Dictionary = storage.get("resources", {})
				resource_store[item_id] = int(resource_store.get(item_id, 0)) + resource_stack
				storage["resources"] = resource_store
	else:
		match kind:
			"weapon":
				if index < 0 or index >= storage["weapons"].size():
					return
				var withdrawn_weapon: Dictionary = storage["weapons"].pop_at(index)
				p.weapons.append(withdrawn_weapon.duplicate(true))
			"armor":
				if index < 0 or index >= storage["armors"].size():
					return
				var withdrawn_armor: Dictionary = storage["armors"].pop_at(index)
				p.armors.append(withdrawn_armor.duplicate(true))
			"potion":
				var withdrawn_potion_stack := int(storage.get("potions", 0))
				if withdrawn_potion_stack <= 0:
					return
				storage["potions"] = 0
				p.potions += withdrawn_potion_stack
			"resource":
				var resource_store: Dictionary = storage.get("resources", {})
				var stored_count := int(resource_store.get(item_id, 0))
				if stored_count <= 0:
					return
				resource_store.erase(item_id)
				storage["resources"] = resource_store
				p.add_resource(item_id, stored_count)
	game.player_home_storage = storage
	game.save_player_home_storage()
	_selected_side = ""
	_selected_item.clear()
	_refresh_lists()
	_refresh_selection()


func _close() -> void:
	if game != null:
		game.close_home_storage()


func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_font_override("font", UiFrame.font())
	label.add_theme_color_override("font_color", color_value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text_value: String, background: Color, color_value: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UiFrame.font())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", color_value)
	button.add_theme_stylebox_override("normal", _panel_style(background, Color(0.27, 0.22, 0.15), 1, 5, 8))
	button.add_theme_stylebox_override("hover", _panel_style(background.lightened(0.12), GOLD_SOFT, 1, 5, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(background.darkened(0.10), GOLD, 1, 5, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(PANEL_ALT, Color(0.19, 0.16, 0.12), 1, 5, 8))
	return button


func _panel_style(background: Color, border_color: Color, border_width: int, radius: int, horizontal_padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

extends Node

const RESOURCE_CATALOG := preload("res://scripts/resource_catalog.gd")

# Tarefas geradas a partir das profissões, do porte dos assentamentos e dos
# tipos de inimigos existentes no jogo. O estado vive na sessão atual; não é
# gravado em disco e continua disponível ao reiniciar uma tentativa.

const MAX_ACTIVE_QUESTS := 5
const REGIONAL_QUEST_THRESHOLD := 42.0
const TARGET_LABELS := {
	"rat": "ratos gigantes",
	"bat": "morcegos",
	"goblin": "goblins",
	"skel": "esqueletos",
	"orc": "orcs"
}
const TARGET_TITLES := {
	"rat": "Ratos demais",
	"bat": "Asas ao anoitecer",
	"goblin": "Goblins na estrada",
	"skel": "Ossos na estrada",
	"orc": "Rastros de saque"
}
const TARGET_TITLE_VARIANTS := {
	"rat": ["Ratos demais", "Roedura e prejuízo", "Praga nos arredores", "Sacos rasgados"],
	"bat": ["Asas ao anoitecer", "Morcegos na passagem", "Ruído no alto", "Morcegos no telhado"],
	"goblin": ["Goblins na estrada", "Uma rota perigosa", "Sinais de saque", "Ninguém quer passar por ali"],
	"skel": ["Ossos na estrada", "Passos entre as ruínas", "Os que não descansam", "Armadura sem dono"],
	"orc": ["Rastros de saque", "Orcs nos arredores", "Carga perdida na estrada", "Uma rota sob ameaça"]
}
const ROLE_TARGETS := {
	"aldeao": ["rat", "goblin", "bat"],
	"guarda": ["goblin", "skel", "orc"],
	"ferreiro": ["goblin", "skel", "orc"],
	"mercador": ["rat", "goblin", "skel"],
	"curandeira": ["rat", "bat", "skel"]
}
const TARGET_REWARD_VALUES := {"rat": 7, "bat": 7, "goblin": 10, "skel": 14, "orc": 18}

var game = null
var rng := RandomNumberGenerator.new()
var quests_by_id: Dictionary = {}
var offer_by_npc: Dictionary = {}
var offer_generation_by_npc: Dictionary = {}
var tracked_quest_id := ""


func initialize(owner_game: Node) -> void:
	game = owner_game
	rng.randomize()


func add_dialogue_options(npc: Node, source_tree: Dictionary) -> Dictionary:
	var tree: Dictionary = source_tree.duplicate(true)
	var quest: Dictionary = _get_or_create_offer(npc)
	if quest.is_empty():
		return tree

	var quest_id := str(quest.get("id", ""))
	var status := str(quest.get("status", "offered"))
	var start_node: Dictionary = tree.get("start", {})
	var options: Array = start_node.get("options", [])

	match status:
		"offered":
			tree["quest_offer"] = {
				"text": "%s\n\n%s\n\n%s" % [str(quest.get("description", "")), _goal_text(quest), _reward_text(quest)],
				"options": [
					{"label": "Aceitar o pedido", "action": "quest_accept:%s" % quest_id},
					{"label": "Agora não", "next": "start"}
				]
			}
			options.append({"label": "Ouvir o pedido", "next": "quest_offer"})
		"active":
			tree["quest_status"] = {
				"text": "%s\n\n%s\nQuem pediu: %s, em %s." % [
					str(quest.get("title", "Trabalho")),
					_goal_text(quest),
					str(quest.get("giver_name", "")),
					str(quest.get("city_name", ""))
				],
				"options": [{"label": "Voltar", "next": "start"}]
			}
			options.append({"label": "Ver andamento (%d/%d)" % [int(quest.get("progress", 0)), int(quest.get("target_count", 1))], "next": "quest_status"})
		"ready":
			tree["quest_turnin"] = {
				"text": "Você cumpriu o combinado.\n\n%s\n\n%s" % [str(quest.get("title", "Trabalho")), _reward_text(quest)],
				"options": [
					{"label": "Concluir e receber pagamento", "action": "quest_turnin:%s" % quest_id},
					{"label": "Mais tarde", "next": "start"}
				]
			}
			options.append({"label": "Acertar o pagamento", "next": "quest_turnin"})
		_:
			pass

	start_node["options"] = options
	tree["start"] = start_node
	return tree


func accept_quest(quest_id: String) -> String:
	if not quests_by_id.has(quest_id):
		return "Esse trabalho já não está disponível."
	var quest: Dictionary = quests_by_id[quest_id]
	if str(quest.get("status", "")) != "offered":
		return "Esse trabalho não pode ser aceito agora."

	var active_count := 0
	for value in quests_by_id.values():
		var status := str(value.get("status", ""))
		if status == "active" or status == "ready":
			active_count += 1
	if active_count >= MAX_ACTIVE_QUESTS:
		return "Você já tem %d trabalhos em andamento. Conclua algum antes de aceitar outro." % MAX_ACTIVE_QUESTS

	var active_overworld: Variant = game.get("overworld") if game != null else null
	if str(quest.get("quest_type", "hunt")) == "collection":
		if active_overworld == null or not is_instance_valid(active_overworld) or not active_overworld.has_method("get_resource_site"):
			return "Não consegui localizar o ponto de coleta agora."
		var collection_site: Dictionary = active_overworld.call("get_resource_site", str(quest.get("site_id", "")))
		if collection_site.is_empty():
			return "Esse ponto de coleta não está disponível neste momento."
		quest["target_position"] = collection_site.get("position", quest.get("target_position", Vector3.ZERO))
		quest["site_name"] = str(collection_site.get("name", quest.get("site_name", "local indicado")))
		quest["status"] = "active"
		quests_by_id[quest_id] = quest
		tracked_quest_id = quest_id
		return "Pedido anotado: %s. Reúna %d unidades de %s em %s. O diário (J) guarda o local." % [str(quest.get("title", "Trabalho")), int(quest.get("target_count", 1)), str(quest.get("target_label", "material")), str(quest.get("site_name", "local indicado"))]

	# Caçadas preparam inimigos no lugar marcado ao aceitar o contrato.
	if active_overworld == null or not is_instance_valid(active_overworld) or not active_overworld.has_method("spawn_quest_targets"):
		return "Não foi possível preparar os alvos agora. Tente novamente quando estiver no mundo aberto."
	var target_position: Vector3 = quest.get("target_position", Vector3.ZERO)
	var target_kind: String = str(quest.get("target_kind", "rat"))
	var target_count: int = int(quest.get("target_count", 1))
	var city_id: String = str(quest.get("city_id", ""))
	var region_only: bool = str(quest.get("quest_type", "hunt")) == "regional_defense"
	# Reserva os pontos de caçada já usados por outros contratos ativos. A nova
	# missão recebe uma área separada mesmo quando o contratante é da mesma cidade.
	var avoid_positions: Array[Vector3] = _reserved_hunt_positions(quest_id)
	var separated_position: Variant = null
	if region_only and active_overworld.has_method("quest_target_position_in_region"):
		separated_position = active_overworld.call("quest_target_position_in_region", city_id, target_kind, avoid_positions)
	elif active_overworld.has_method("quest_target_position"):
		separated_position = active_overworld.call("quest_target_position", city_id, target_kind, avoid_positions)
	if separated_position is Vector3:
		target_position = separated_position
	var spawn_result: Dictionary = active_overworld.call("spawn_quest_targets", quest_id, target_kind, target_count, target_position, city_id, region_only)
	if not bool(spawn_result.get("success", false)):
		return str(spawn_result.get("message", "Não foi possível preparar os alvos deste trabalho."))

	quest["target_position"] = spawn_result.get("position", target_position)
	quest["requires_quest_targets"] = true
	quest["status"] = "active"
	quests_by_id[quest_id] = quest
	# A missão recém-aceita passa a ser o objetivo visível na bússola e no mapa.
	tracked_quest_id = quest_id
	return "Pedido anotado: %s. O marcador indica a região da caçada. %s O diário (J) acompanha o progresso." % [str(quest.get("title", "Trabalho")), _goal_text(quest)]


func restore_active_quest_targets() -> String:
	if game == null or not is_instance_valid(game):
		return ""
	var active_overworld: Variant = game.get("overworld")
	if active_overworld == null or not is_instance_valid(active_overworld) or not active_overworld.has_method("spawn_quest_targets"):
		return ""
	var restored_count: int = 0
	var failed_count: int = 0
	for id_value in quests_by_id.keys():
		var quest_id: String = str(id_value)
		var quest: Dictionary = quests_by_id[quest_id]
		if str(quest.get("status", "")) != "active":
			continue
		if str(quest.get("quest_type", "hunt")) == "collection":
			if active_overworld.has_method("get_resource_site"):
				var restored_site: Dictionary = active_overworld.call("get_resource_site", str(quest.get("site_id", "")))
				if not restored_site.is_empty():
					quest["target_position"] = restored_site.get("position", quest.get("target_position", Vector3.ZERO))
					quest["site_name"] = str(restored_site.get("name", quest.get("site_name", "local indicado")))
					quests_by_id[quest_id] = quest
			continue
		if not bool(quest.get("requires_quest_targets", false)):
			continue
		var remaining: int = maxi(0, int(quest.get("target_count", 1)) - int(quest.get("progress", 0)))
		if remaining <= 0:
			quest["status"] = "ready"
			quests_by_id[quest_id] = quest
			continue
		var target_position: Vector3 = quest.get("target_position", Vector3.ZERO)
		var region_only: bool = str(quest.get("quest_type", "hunt")) == "regional_defense"
		var result: Dictionary = active_overworld.call(
			"spawn_quest_targets",
			quest_id,
			str(quest.get("target_kind", "rat")),
			remaining,
			target_position,
			str(quest.get("city_id", "")),
			region_only
		)
		if bool(result.get("success", false)):
			quest["target_position"] = result.get("position", target_position)
			quests_by_id[quest_id] = quest
			restored_count += int(result.get("spawned", 0))
		else:
			failed_count += 1
	if restored_count <= 0 and failed_count <= 0:
		return ""
	if restored_count > 0 and failed_count == 0:
		return "Os alvos restantes de %d contrato(s) ativo(s) foram preparados novamente." % _count_active_target_quests()
	if failed_count > 0:
		return "Não consegui preparar os alvos de %d pedido(s). Confira o diário antes de tentar de novo." % failed_count
	return ""


func _count_active_target_quests() -> int:
	var count: int = 0
	for quest_value in quests_by_id.values():
		var quest: Dictionary = quest_value
		if str(quest.get("status", "")) == "active" and bool(quest.get("requires_quest_targets", false)):
			count += 1
	return count


func turn_in_quest(quest_id: String) -> String:
	if not quests_by_id.has(quest_id):
		return "Não encontrei esse trabalho no registro."
	var quest: Dictionary = quests_by_id[quest_id]
	if str(quest.get("status", "")) != "ready":
		return "Você ainda não cumpriu esse trabalho."
	if game == null or not is_instance_valid(game):
		return "Não foi possível entregar o trabalho agora."
	var active_player: Variant = game.get("player")
	if active_player == null or not is_instance_valid(active_player):
		return "Não foi possível entregar o trabalho agora."

	if str(quest.get("quest_type", "hunt")) == "collection":
		var required_resource_id: String = str(quest.get("resource_id", ""))
		var required_resource_count: int = int(quest.get("target_count", 1))
		var current_resource_count: int = int(active_player.call("resource_count", required_resource_id)) if active_player.has_method("resource_count") else 0
		if current_resource_count < required_resource_count:
			return "Você precisa trazer %d unidades de %s; no inventário há %d." % [required_resource_count, str(quest.get("target_label", "material")), current_resource_count]
		if not active_player.has_method("remove_resource") or not bool(active_player.call("remove_resource", required_resource_id, required_resource_count)):
			return "Não consegui separar os materiais para a entrega."

	var reward_gold: int = int(quest.get("reward_gold", 0))
	var reward_potions: int = int(quest.get("reward_potions", 0))
	var reward_xp: int = int(quest.get("reward_xp", 0))
	active_player.add_gold(reward_gold)
	for _i in range(reward_potions):
		active_player.add_potion()
	var level_message := ""
	if active_player.has_method("gain_experience"):
		level_message = str(active_player.call("gain_experience", reward_xp))
	if str(quest.get("quest_type", "hunt")) == "regional_defense":
		var active_overworld: Variant = game.get("overworld")
		if active_overworld != null and is_instance_valid(active_overworld) and active_overworld.has_method("resolve_regional_quest"):
			active_overworld.call("resolve_regional_quest", str(quest.get("city_id", "")), int(quest.get("target_count", 1)))
	quest["status"] = "completed"
	quests_by_id[quest_id] = quest
	var quest_world: Variant = game.get("overworld")
	if quest_world != null and is_instance_valid(quest_world) and quest_world.has_method("report_quest_completed"):
		quest_world.call("report_quest_completed", quest)
	if tracked_quest_id == quest_id:
		tracked_quest_id = _next_trackable_quest(quest_id)
	var reward_text := "+%d ouro e +%d XP" % [reward_gold, reward_xp]
	if reward_potions > 0:
		reward_text += " e %d poção(ões) de cura" % reward_potions
	if level_message != "":
		reward_text += " — " + level_message.trim_suffix(".")
	return "Feito: %s. Você recebeu %s." % [str(quest.get("title", "Trabalho")), reward_text]


func register_resource_gathered(resource_id: String, amount: int, site_id: String) -> String:
	if amount <= 0 or resource_id == "" or site_id == "":
		return ""
	var updates: Array[String] = []
	for quest_key in quests_by_id.keys():
		var quest_id: String = str(quest_key)
		var quest: Dictionary = quests_by_id[quest_id]
		if str(quest.get("status", "")) != "active" or str(quest.get("quest_type", "")) != "collection":
			continue
		if str(quest.get("resource_id", "")) != resource_id or str(quest.get("site_id", "")) != site_id:
			continue
		var progress: int = mini(int(quest.get("target_count", 1)), int(quest.get("progress", 0)) + amount)
		var required: int = int(quest.get("target_count", 1))
		quest["progress"] = progress
		if progress >= required:
			quest["status"] = "ready"
			updates.append("Você reuniu os materiais para ‘%s’. Volte a falar com %s." % [str(quest.get("title", "trabalho")), str(quest.get("giver_name", "o contratante"))])
		else:
			updates.append("%s: %d/%d %s." % [str(quest.get("title", "Coleta")), progress, required, str(quest.get("target_label", "materiais"))])
		quests_by_id[quest_id] = quest
	if updates.is_empty():
		return ""
	return "\n".join(updates)


func get_reserved_resource_amount(resource_id: String) -> int:
	var reserved: int = 0
	for quest_value in quests_by_id.values():
		var quest: Dictionary = quest_value
		if str(quest.get("quest_type", "")) != "collection" or str(quest.get("resource_id", "")) != resource_id:
			continue
		var status: String = str(quest.get("status", ""))
		if status == "ready":
			reserved += int(quest.get("target_count", 1))
		elif status == "active":
			reserved += mini(int(quest.get("target_count", 1)), int(quest.get("progress", 0)))
	return reserved


func register_kill(enemy_kind: String, from_overworld: bool, death_position: Vector3 = Vector3.ZERO, enemy_quest_id: String = "") -> String:
	# As caçadas são tarefas de estrada: mortes dentro da cripta não contam,
	# pois o fluxo atual não oferece uma saída da dungeon para voltar ao contratante.
	if not from_overworld:
		return ""
	var updates: Array = []
	var ids: Array = quests_by_id.keys()
	for id_value in ids:
		var quest_id := str(id_value)
		var quest: Dictionary = quests_by_id[quest_id]
		if str(quest.get("status", "")) != "active":
			continue
		if str(quest.get("target_kind", "")) != enemy_kind:
			continue
		# Contratos novos contam apenas os inimigos preparados para aquele contrato,
		# evitando que um rato aleatório do outro lado do mapa conclua a missão.
		if bool(quest.get("requires_quest_targets", false)) and enemy_quest_id != quest_id:
			continue
		if str(quest.get("quest_type", "hunt")) == "regional_defense":
			# Os alvos especiais já foram colocados na região certa. Se perseguirem
			# o jogador para fora da fronteira regional, ainda contam para o contrato.
			var is_prepared_target: bool = bool(quest.get("requires_quest_targets", false)) and enemy_quest_id == quest_id
			if not is_prepared_target:
				var active_overworld: Variant = game.get("overworld") if game != null else null
				if active_overworld == null or not is_instance_valid(active_overworld) or not active_overworld.has_method("is_position_in_city_region"):
					continue
				var city_id: String = str(quest.get("city_id", ""))
				if not bool(active_overworld.call("is_position_in_city_region", death_position, city_id)):
					continue
		var progress: int = int(quest.get("progress", 0)) + 1
		var required: int = int(quest.get("target_count", 1))
		quest["progress"] = progress
		if progress >= required:
			quest["progress"] = required
			quest["status"] = "ready"
			updates.append("Objetivo concluído: %s. Volte a falar com %s." % [str(quest.get("title", "Trabalho")), str(quest.get("giver_name", "o contratante"))])
		else:
			updates.append("%s: %d/%d." % [str(quest.get("title", "Trabalho")), progress, required])
		quests_by_id[quest_id] = quest
	if updates.is_empty():
		return ""
	var summary := str(updates[0])
	if updates.size() > 1:
		summary += " (+%d outras tarefas atualizadas)" % (updates.size() - 1)
	return "Tarefas — " + summary


func journal_text() -> String:
	var lines: Array[String] = []
	var ids: Array = quests_by_id.keys()
	ids.sort()
	var found_active := false
	for id_value in ids:
		var quest: Dictionary = quests_by_id[str(id_value)]
		var status := str(quest.get("status", ""))
		if status != "active" and status != "ready":
			continue
		found_active = true
		if status == "ready":
			lines.append("[CONCLUÍDO] %s" % str(quest.get("title", "Trabalho")))
			lines.append("Volte a falar com %s, em %s, para receber a recompensa." % [str(quest.get("giver_name", "o contratante")), str(quest.get("city_name", "sua cidade"))])
		else:
			lines.append("[EM ANDAMENTO] %s — %d/%d" % [str(quest.get("title", "Trabalho")), int(quest.get("progress", 0)), int(quest.get("target_count", 1))])
			lines.append(_goal_text(quest))
			lines.append("Quem pediu: %s, em %s." % [str(quest.get("giver_name", "")), str(quest.get("city_name", ""))])
		lines.append(_reward_text(quest))
		lines.append("")
	if not found_active:
		lines.append("Você não tem tarefas ativas.")
		lines.append("Converse com guardas, comerciantes, ferreiros, curandeiras e moradores para descobrir trabalhos.")
	lines.append("")
	lines.append("As coletas precisam ser feitas no local indicado. Entregue materiais ou contratos concluídos ao habitante que os ofereceu.")
	return "\n".join(lines)


func _get_or_create_offer(npc: Node) -> Dictionary:
	var npc_id: String = str(npc.get("npc_id"))
	if npc_id == "":
		npc_id = "npc:%s:%s" % [str(npc.get("city_id")), str(npc.get("display_name"))]
	var city_id: String = str(npc.get("city_id"))
	var city_name: String = str(npc.get("city_name"))
	var role: String = str(npc.get("role"))
	var active_overworld: Variant = game.get("overworld") if game != null else null
	var regional_threat: float = 0.0
	var regional_weights: Dictionary = {}
	if active_overworld != null and is_instance_valid(active_overworld):
		if active_overworld.has_method("get_regional_threat"):
			regional_threat = float(active_overworld.call("get_regional_threat", city_id))
		if active_overworld.has_method("get_regional_enemy_weights"):
			regional_weights = active_overworld.call("get_regional_enemy_weights", city_id)
	var region_can_offer_defense: bool = regional_threat >= REGIONAL_QUEST_THRESHOLD and not regional_weights.is_empty()
	if offer_by_npc.has(npc_id):
		var previous_quest_id: String = str(offer_by_npc[npc_id])
		if quests_by_id.has(previous_quest_id):
			var previous_quest: Dictionary = quests_by_id[previous_quest_id]
			var previous_status: String = str(previous_quest.get("status", ""))
			if previous_status in ["active", "ready"] or (previous_status != "completed" and str(previous_quest.get("quest_type", "hunt")) == "regional_defense"):
				return previous_quest
			if previous_status == "offered":
				if not region_can_offer_defense or _has_open_regional_quest(city_id, previous_quest_id):
					return previous_quest
				# Substitui uma oferta ainda não aceita por um contrato urgente quando
				# a região entra em crise. O contrato antigo fica arquivado, não ativo.
				previous_quest["status"] = "superseded"
				quests_by_id[previous_quest_id] = previous_quest

	var tier: int = _city_tier(city_id)
	var possible_targets: Array = _allowed_targets(role, tier)
	if possible_targets.is_empty():
		possible_targets = ["rat", "goblin"]

	var regional_defense: bool = region_can_offer_defense and not _has_open_regional_quest(city_id, "")
	if regional_defense:
		var local_targets: Array = []
		var role_targets: Array = ROLE_TARGETS.get(role, possible_targets)
		for kind_value in role_targets:
			var kind: String = str(kind_value)
			if float(regional_weights.get(kind, 0.0)) > 0.0:
				local_targets.append(kind)
		if local_targets.is_empty():
			for kind_value in regional_weights.keys():
				var kind: String = str(kind_value)
				if TARGET_LABELS.has(kind):
					local_targets.append(kind)
		if not local_targets.is_empty():
			possible_targets = local_targets
		else:
			regional_defense = false

	var collection_target: Dictionary = {}
	if not regional_defense and role in ["ferreiro", "curandeira"] and active_overworld != null and is_instance_valid(active_overworld) and active_overworld.has_method("get_resource_sites_for_resource") and rng.randf() < 0.58:
		var resource_candidates: Array = ["iron_ore", "copper_ore", "silver_ore"] if role == "ferreiro" else ["healing_herb", "bitterleaf", "silverleaf"]
		while not resource_candidates.is_empty():
			var candidate_index: int = rng.randi_range(0, resource_candidates.size() - 1)
			var candidate_resource_id: String = str(resource_candidates.pop_at(candidate_index))
			var candidate_sites: Array = active_overworld.call("get_resource_sites_for_resource", candidate_resource_id, city_id)
			if candidate_sites.is_empty():
				continue
			candidate_sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var position_a: Vector3 = a.get("position", npc.global_position)
				var position_b: Vector3 = b.get("position", npc.global_position)
				return Vector2(position_a.x - npc.global_position.x, position_a.z - npc.global_position.z).length_squared() < Vector2(position_b.x - npc.global_position.x, position_b.z - npc.global_position.z).length_squared()
			)
			collection_target = {"resource_id": candidate_resource_id, "site": candidate_sites[0]}
			break

	var quest_type: String = "regional_defense" if regional_defense else "hunt"
	var target_kind: String = ""
	var target_label: String = ""
	var target_count: int = 1
	var reward_gold: int = 0
	var reward_potions: int = 0
	var reward_xp: int = 0
	var title: String = ""
	var description: String = ""
	var resource_id: String = ""
	var site_id: String = ""
	var site_name: String = ""
	var target_position: Vector3 = npc.global_position

	if not collection_target.is_empty():
		quest_type = "collection"
		resource_id = str(collection_target.get("resource_id", "iron_ore"))
		var chosen_site: Dictionary = collection_target.get("site", {})
		site_id = str(chosen_site.get("id", ""))
		site_name = str(chosen_site.get("name", "local indicado"))
		target_position = chosen_site.get("position", npc.global_position)
		target_label = RESOURCE_CATALOG.display_name(resource_id)
		target_count = rng.randi_range(3, 4)
		var unit_value: int = RESOURCE_CATALOG.base_price(resource_id)
		reward_gold = 24 + unit_value * target_count + tier * 5
		reward_potions = 1 if role == "curandeira" else 0
		reward_xp = 32 + target_count * 8 + tier * 6
		if role == "ferreiro":
			var forge_titles: Array[String] = ["Material para a oficina", "A ferraria está sem estoque", "Uma encomenda atrasada"]
			title = forge_titles[posmod(abs((npc_id + "|forja|" + str(quests_by_id.size())).hash()), forge_titles.size())]
			description = "%d unidades de %s me ajudariam a terminar umas encomendas. Encontrei material em %s. Traga o que conseguir; faço o pagamento quando voltar." % [target_count, target_label.to_lower(), site_name]
		else:
			var herb_titles: Array[String] = ["Folhas para a enfermaria", "Ervas para os próximos dias", "O estoque de remédios"]
			title = herb_titles[posmod(abs((npc_id + "|ervas|" + str(quests_by_id.size())).hash()), herb_titles.size())]
			description = "Meu estoque de %s está acabando. Há plantas em %s; colha %d unidades e traga para mim. Deixe no chão qualquer planta que não reconhecer." % [target_label.to_lower(), site_name, target_count]
	else:
		if regional_defense:
			target_kind = _weighted_target(possible_targets, regional_weights)
		else:
			target_kind = str(possible_targets[rng.randi_range(0, possible_targets.size() - 1)])
		target_label = str(TARGET_LABELS.get(target_kind, target_kind))
		target_count = rng.randi_range(4 + tier, mini(6 + tier, 10)) if regional_defense else rng.randi_range(2 + tier, mini(3 + tier, 6))
		var reward_each: int = int(TARGET_REWARD_VALUES.get(target_kind, 7))
		if regional_defense:
			reward_gold = int((25 + reward_each * target_count + tier * 8) * (1.0 + regional_threat / 180.0))
		else:
			reward_gold = 15 + reward_each * target_count + tier * 5
		reward_potions = 1 if role == "curandeira" else (1 if tier >= 2 and rng.randf() < 0.18 else 0)
		reward_xp = 20 + target_count * 8 + tier * 10 + (20 if regional_defense else 0)
		var base_title: String = _quest_title_for(target_kind, role, npc_id, quests_by_id.size())
		title = _regional_quest_title(role, city_name, npc_id, quests_by_id.size()) if regional_defense else base_title
		description = _description_for(role, target_kind, city_name)
		if regional_defense:
			var status_text: String = "Em alerta"
			if active_overworld != null and is_instance_valid(active_overworld) and active_overworld.has_method("get_regional_threat_status"):
				status_text = str(active_overworld.call("get_regional_threat_status", city_id))
			description = _regional_defense_description(role, target_kind, city_name, status_text, regional_threat)

	var generation: int = int(offer_generation_by_npc.get(npc_id, 0)) + 1
	offer_generation_by_npc[npc_id] = generation
	var quest_id: String = "work:%s:%02d" % [npc_id, generation]
	var giver_name: String = str(npc.get("display_name"))
	var city_position: Vector3 = npc.global_position
	if active_overworld != null and is_instance_valid(active_overworld):
		if quest_type == "collection":
			var current_site: Dictionary = active_overworld.call("get_resource_site", site_id) if active_overworld.has_method("get_resource_site") else {}
			if not current_site.is_empty():
				target_position = current_site.get("position", target_position)
		elif regional_defense and active_overworld.has_method("quest_target_position_in_region"):
			target_position = active_overworld.call("quest_target_position_in_region", city_id, target_kind, _reserved_hunt_positions(""))
		elif active_overworld.has_method("quest_target_position"):
			target_position = active_overworld.call("quest_target_position", city_id, target_kind, _reserved_hunt_positions(""))
		if active_overworld.has_method("quest_city_position"):
			city_position = active_overworld.call("quest_city_position", city_id)
	if giver_name.is_empty():
		giver_name = "Morador"
	var quest: Dictionary = {
		"id": quest_id,
		"giver_id": npc_id,
		"giver_name": giver_name,
		"city_id": city_id,
		"city_name": city_name,
		"role": role,
		"quest_type": quest_type,
		"threat_at_offer": regional_threat,
		"title": title,
		"description": description,
		"target_kind": target_kind,
		"target_label": target_label,
		"resource_id": resource_id,
		"site_id": site_id,
		"site_name": site_name,
		"target_count": target_count,
		"progress": 0,
		"reward_gold": reward_gold,
		"reward_potions": reward_potions,
		"reward_xp": reward_xp,
		"target_position": target_position,
		"city_position": city_position,
		"status": "offered"
	}
	quests_by_id[quest_id] = quest
	offer_by_npc[npc_id] = quest_id
	return quest


func _reserved_hunt_positions(excluded_quest_id: String) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for quest_key in quests_by_id.keys():
		var existing_id: String = str(quest_key)
		if existing_id == excluded_quest_id:
			continue
		var existing: Dictionary = quests_by_id[existing_id]
		if str(existing.get("status", "")) != "active":
			continue
		if str(existing.get("quest_type", "hunt")) == "collection":
			continue
		if not bool(existing.get("requires_quest_targets", false)):
			continue
		var position_value: Variant = existing.get("target_position", Vector3.ZERO)
		if position_value is Vector3 and position_value != Vector3.ZERO:
			positions.append(position_value)
	return positions


func _has_open_regional_quest(city_id: String, excluded_quest_id: String) -> bool:
	for quest_key in quests_by_id.keys():
		var quest_id: String = str(quest_key)
		if quest_id == excluded_quest_id:
			continue
		var quest: Dictionary = quests_by_id[quest_id]
		if str(quest.get("city_id", "")) != city_id:
			continue
		if str(quest.get("quest_type", "hunt")) != "regional_defense":
			continue
		if str(quest.get("status", "")) in ["offered", "active", "ready"]:
			return true
	return false


func _weighted_target(candidates: Array, weights: Dictionary) -> String:
	var total: float = 0.0
	for candidate_value in candidates:
		total += maxf(0.0, float(weights.get(str(candidate_value), 0.0)))
	if total <= 0.0:
		return str(candidates[0]) if not candidates.is_empty() else "rat"
	var choice: float = rng.randf() * total
	for candidate_value in candidates:
		var kind: String = str(candidate_value)
		choice -= maxf(0.0, float(weights.get(kind, 0.0)))
		if choice <= 0.0:
			return kind
	return str(candidates[candidates.size() - 1])


func _regional_defense_description(role: String, kind: String, city_name: String, status_text: String, threat: float) -> String:
	var target: String = str(TARGET_LABELS.get(kind, kind))
	var opening := "A situação perto de %s piorou." % city_name if threat >= 70.0 else "Os relatos de perigo perto de %s estão se acumulando." % city_name
	match role:
		"guarda":
			return "%s A ronda não dá conta de tudo. Ajude a afastar %s dos caminhos usados pelos moradores." % [opening, target]
		"mercador":
			return "%s As caravanas estão evitando esta região. Tire %s da rota, ou logo vai faltar mercadoria nas bancas." % [opening, target]
		"ferreiro":
			return "%s Tenho encomendas paradas porque ninguém quer trazer carga por aqui. Afaste %s dos caminhos perto da cidade." % [opening, target]
		"curandeira":
			return "%s Tenho atendido gente ferida depois de cruzar com %s. Não quero ver a enfermaria cheia por causa da estrada." % [opening, target]
		_:
			return "%s O pessoal já evita sair sem necessidade. Afaste alguns %s dos arredores para que a vida volte ao normal." % [opening, target]

func get_journal_entries(filter_name: String = "active") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in quests_by_id.values():
		var quest: Dictionary = value
		var status := str(quest.get("status", ""))
		var include := false
		match filter_name:
			"available":
				include = status == "offered"
			"completed":
				include = status == "completed"
			_:
				include = status == "active" or status == "ready"
		if include:
			result.append(quest.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return result


func get_quest_record(quest_id: String) -> Dictionary:
	return quests_by_id.get(quest_id, {}).duplicate(true)


func get_ready_giver_ids() -> Array[String]:
	# Cada NPC que ainda precisa receber a entrega fica marcado, mesmo quando
	# não é o contrato atualmente acompanhado no HUD.
	var result: Array[String] = []
	for quest_value in quests_by_id.values():
		var quest: Dictionary = quest_value
		if str(quest.get("status", "")) != "ready":
			continue
		var giver_id := str(quest.get("giver_id", ""))
		if giver_id != "" and not result.has(giver_id):
			result.append(giver_id)
	result.sort()
	return result


func set_tracked_quest(quest_id: String) -> bool:
	if not quests_by_id.has(quest_id):
		return false
	var quest: Dictionary = quests_by_id[quest_id]
	if str(quest.get("status", "")) not in ["active", "ready"]:
		return false
	tracked_quest_id = quest_id
	return true


func clear_tracked_quest() -> void:
	tracked_quest_id = ""


func get_tracked_quest() -> Dictionary:
	if tracked_quest_id == "" or not quests_by_id.has(tracked_quest_id):
		return {}
	var quest: Dictionary = quests_by_id[tracked_quest_id].duplicate(true)
	if str(quest.get("status", "")) == "ready":
		quest["map_marker_position"] = quest.get("city_position", Vector3.ZERO)
		quest["map_marker_label"] = "Voltar ao contratante"
	elif str(quest.get("quest_type", "hunt")) == "collection":
		quest["map_marker_position"] = quest.get("target_position", Vector3.ZERO)
		quest["map_marker_label"] = str(quest.get("site_name", "Ponto de coleta"))
	else:
		quest["map_marker_position"] = quest.get("target_position", Vector3.ZERO)
		quest["map_marker_label"] = "Zona de caça"
	return quest


func _next_trackable_quest(excluded_id: String) -> String:
	for key in quests_by_id.keys():
		var quest: Dictionary = quests_by_id[str(key)]
		if str(key) == excluded_id:
			continue
		if str(quest.get("status", "")) in ["active", "ready"]:
			return str(key)
	return ""


func _city_tier(city_id: String) -> int:
	var house_count := _city_house_count(city_id)
	if house_count <= 5:
		return 0
	if house_count <= 15:
		return 1
	if house_count <= 30:
		return 2
	return 3


func _city_house_count(city_id: String) -> int:
	if game == null:
		return 10
	var active_overworld: Variant = game.get("overworld")
	if active_overworld == null or not is_instance_valid(active_overworld):
		return 10
	var society_value: Variant = active_overworld.get("_npc_society")
	if society_value == null or not is_instance_valid(society_value):
		return 10
	var city_record: Dictionary = society_value.call("get_city_record", city_id)
	var houses: Array = city_record.get("house_ids", [])
	return houses.size()


func _allowed_targets(role: String, tier: int) -> Array:
	var unlocked: Array = ["rat", "bat"]
	if tier >= 1:
		unlocked.append("goblin")
	if tier >= 2:
		unlocked.append("skel")
	if tier >= 3:
		unlocked.append("orc")
	var preferences: Array = ROLE_TARGETS.get(role, ["rat", "goblin", "bat"])
	var result: Array = []
	for kind in preferences:
		if unlocked.has(kind):
			result.append(kind)
	return result if not result.is_empty() else unlocked


func _description_for(role: String, kind: String, city_name: String) -> String:
	var target := str(TARGET_LABELS.get(kind, kind))
	match role:
		"guarda":
			return "Tenho recebido relatos de %s nas estradas perto de %s. Não vou fechar o caminho por causa de boatos, mas quero que alguém confira e reduza o perigo." % [target, city_name]
		"ferreiro":
			return "As entregas estão atrasando porque há %s nos arredores de %s. Afaste alguns deles da rota e consigo voltar a receber material sem pôr os carroceiros em risco." % [target, city_name]
		"mercador":
			return "Os carroceiros que trabalham comigo estão evitando os caminhos perto de %s por causa dos %s. Se ninguém passar por ali, os preços vão subir. Afaste-os da rota e pago o combinado." % [city_name, target]
		"curandeira":
			return "Já tratei ferimentos causados por %s que rondam %s. Não quero que o próximo viajante chegue aqui sangrando por ter tomado o caminho errado. Reduza esse perigo." % [target, city_name]
		_:
			return "O pessoal está evitando os arredores de %s por causa dos %s. Não precisa limpar a região inteira, mas tire alguns do caminho para que as pessoas voltem aos campos e à estrada." % [city_name, target]


func _quest_title_for(kind: String, role: String, npc_id: String, salt: int) -> String:
	var variants_value: Variant = TARGET_TITLE_VARIANTS.get(kind, [str(TARGET_TITLES.get(kind, "Perigo na estrada"))])
	var variants: Array = variants_value if variants_value is Array else [str(TARGET_TITLES.get(kind, "Perigo na estrada"))]
	if variants.is_empty():
		return str(TARGET_TITLES.get(kind, "Perigo na estrada"))
	var index := posmod(abs((npc_id + "|" + role + "|" + str(salt)).hash()), variants.size())
	return str(variants[index])


func _regional_quest_title(role: String, city_name: String, npc_id: String, salt: int) -> String:
	var variants: Array[String] = []
	match role:
		"guarda": variants = ["Ronda reforçada", "Estradas sob vigilância", "Pedido urgente da guarda"]
		"mercador": variants = ["Caravanas paradas", "A rota precisa abrir", "Mercadorias retidas"]
		"ferreiro": variants = ["Cargas que não chegam", "A estrada está fechada", "Entrega atrasada"]
		"curandeira": variants = ["Feridos demais", "Caminhos perigosos", "A enfermaria está cheia"]
		_: variants = ["Dias difíceis em %s" % city_name, "O caminho já não é seguro", "Um pedido dos moradores"]
	if variants.is_empty():
		return "Problemas na região de %s" % city_name
	var index := posmod(abs((npc_id + "|crise|" + str(salt)).hash()), variants.size())
	var title := variants[index]
	if role == "aldeao" and not title.contains(city_name):
		title += " · %s" % city_name
	return title

func _goal_text(quest: Dictionary) -> String:
	if str(quest.get("quest_type", "hunt")) == "collection":
		return "Reúna %d unidades de %s em %s (%d/%d)." % [
			int(quest.get("target_count", 1)),
			str(quest.get("target_label", "material")),
			str(quest.get("site_name", "local indicado")),
			int(quest.get("progress", 0)),
			int(quest.get("target_count", 1))
		]
	var area_word: String = "na região de" if str(quest.get("quest_type", "hunt")) == "regional_defense" else "nos arredores de"
	return "Derrote %d %s %s %s (%d/%d)." % [
		int(quest.get("target_count", 1)),
		str(quest.get("target_label", "monstros")),
		area_word,
		str(quest.get("city_name", "a cidade")),
		int(quest.get("progress", 0)),
		int(quest.get("target_count", 1))
	]


func _reward_text(quest: Dictionary) -> String:
	var result := "Recompensa: %d ouro e %d XP" % [int(quest.get("reward_gold", 0)), int(quest.get("reward_xp", 0))]
	var potions := int(quest.get("reward_potions", 0))
	if potions > 0:
		result += " e %d poção(ões) de cura" % potions
	return result + "."

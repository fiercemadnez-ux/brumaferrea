extends RefCounted

# Catálogo partilhado por coleta, inventário, contratos e comércio.
const DEFINITIONS := {
	"iron_ore": {"name": "Minério de ferro", "category": "mineral", "base_price": 5, "description": "Minério escuro usado para produzir ferramentas, armas e ferragens."},
	"copper_ore": {"name": "Minério de cobre", "category": "mineral", "base_price": 4, "description": "Minério avermelhado, útil para ligas e pequenos componentes."},
	"silver_ore": {"name": "Minério de prata", "category": "mineral", "base_price": 9, "description": "Veios claros e raros, procurados por artesãos e alquimistas."},
	"healing_herb": {"name": "Erva restauradora", "category": "herb", "base_price": 4, "description": "Folhas usadas em preparados simples para tratar ferimentos."},
	"bitterleaf": {"name": "Folha amarga", "category": "herb", "base_price": 6, "description": "Erva de sabor forte, valorizada em misturas medicinais."},
	"silverleaf": {"name": "Folha-prateada", "category": "herb", "base_price": 8, "description": "Planta pálida que cresce em clareiras frescas e sombreadas."}
}

static func definition(resource_id: String) -> Dictionary:
	return DEFINITIONS.get(resource_id, {}).duplicate(true)

static func display_name(resource_id: String) -> String:
	return str(DEFINITIONS.get(resource_id, {}).get("name", resource_id.replace("_", " ").capitalize()))

static func category(resource_id: String) -> String:
	return str(DEFINITIONS.get(resource_id, {}).get("category", "misc"))

static func base_price(resource_id: String) -> int:
	return int(DEFINITIONS.get(resource_id, {}).get("base_price", 1))

static func sell_price(resource_id: String, buyer_role: String) -> int:
	var base: int = base_price(resource_id)
	var item_category: String = category(resource_id)
	match buyer_role:
		"ferreiro":
			return base if item_category == "mineral" else maxi(1, int(floor(float(base) * 0.30)))
		"curandeira":
			return base if item_category == "herb" else maxi(1, int(floor(float(base) * 0.25)))
		"mercador":
			return maxi(1, int(floor(float(base) * 0.65)))
	return 0

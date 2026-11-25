extends Node3D
# Interior procedural compacto. O layout é determinístico pelo ID da construção,
# e cada tipo de edifício recebe móveis coerentes com seu uso.

var building_id: String = ""
var building_name: String = "Edifício"
var building_kind: String = "house"
var room_width: float = 9.0
var room_depth: float = 9.0
const WALL_HEIGHT := 3.1
const WALL_THICKNESS := 0.24
const FLOOR_COLOR := Color(0.27, 0.19, 0.12)
const WALL_COLOR := Color(0.52, 0.43, 0.31)
const WOOD_COLOR := Color(0.30, 0.17, 0.08)
const WOOD_LIGHT := Color(0.43, 0.27, 0.13)
const STONE_COLOR := Color(0.34, 0.32, 0.29)
const CLOTH_COLOR := Color(0.34, 0.20, 0.18)
const INTERIOR_BUILDING_KINDS: Array[String] = [
	"house", "shop", "workshop", "inn", "tavern", "town_hall", "library", "infirmary",
	"guard_post", "lookout", "depot", "shelter", "stable", "mill", "barn"
]


func supports_interior(kind: String) -> bool:
	return kind.to_lower() in INTERIOR_BUILDING_KINDS


func build(record: Dictionary, origin: Vector3) -> Vector3:
	building_id = str(record.get("id", "unknown"))
	building_name = str(record.get("name", "Edifício"))
	building_kind = str(record.get("kind", "house")).to_lower()
	if not supports_interior(building_kind):
		# Proteção extra: um marco nunca deve virar uma sala genérica por engano.
		return Vector3.ZERO
	position = origin
	match building_kind:
		"shop":
			room_width = 11.0
			room_depth = 9.0
		"workshop":
			room_width = 12.0
			room_depth = 10.0
		"inn", "tavern":
			room_width = 14.0
			room_depth = 12.0
		"town_hall":
			room_width = 15.0
			room_depth = 12.0
		"library", "infirmary", "depot", "mill":
			room_width = 12.0
			room_depth = 10.0
		"guard_post", "shelter", "lookout":
			room_width = 10.0 if building_kind != "lookout" else 8.0
			room_depth = 9.0 if building_kind != "lookout" else 8.0
		"stable", "barn":
			room_width = 14.0
			room_depth = 11.0
		_:
			room_width = 9.0
			room_depth = 9.0
	_build_shell()
	_build_furniture()
	_add_indoor_light()
	return Vector3(0.0, 0.04, room_depth * 0.5 - 1.8)


func _build_shell() -> void:
	_add_solid_box("Floor", Vector3(0.0, -0.16, 0.0), Vector3(room_width, 0.32, room_depth), FLOOR_COLOR)
	_add_solid_box("NorthWall", Vector3(0.0, WALL_HEIGHT * 0.5, -room_depth * 0.5), Vector3(room_width, WALL_HEIGHT, WALL_THICKNESS), WALL_COLOR)
	_add_solid_box("WestWall", Vector3(-room_width * 0.5, WALL_HEIGHT * 0.5, 0.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, room_depth), WALL_COLOR)
	_add_solid_box("EastWall", Vector3(room_width * 0.5, WALL_HEIGHT * 0.5, 0.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, room_depth), WALL_COLOR)
	# A parede sul tem uma abertura central de 1,6 m para entrar/sair com facilidade.
	var opening_width := 1.6
	var wall_segment_width := (room_width - opening_width) * 0.5
	var side_offset := (opening_width + wall_segment_width) * 0.5
	_add_solid_box("SouthWallLeft", Vector3(-side_offset, WALL_HEIGHT * 0.5, room_depth * 0.5), Vector3(wall_segment_width, WALL_HEIGHT, WALL_THICKNESS), WALL_COLOR)
	_add_solid_box("SouthWallRight", Vector3(side_offset, WALL_HEIGHT * 0.5, room_depth * 0.5), Vector3(wall_segment_width, WALL_HEIGHT, WALL_THICKNESS), WALL_COLOR)
	_add_solid_box("DoorPostLeft", Vector3(-opening_width * 0.5, 1.35, room_depth * 0.5 - 0.01), Vector3(0.14, 2.7, 0.18), WOOD_COLOR)
	_add_solid_box("DoorPostRight", Vector3(opening_width * 0.5, 1.35, room_depth * 0.5 - 0.01), Vector3(0.14, 2.7, 0.18), WOOD_COLOR)
	_add_solid_box("DoorLintel", Vector3(0.0, 2.82, room_depth * 0.5 - 0.01), Vector3(opening_width + 0.2, 0.18, 0.20), WOOD_COLOR)
	# Porta fechada preenche a abertura e bloqueia a passagem física. Só pode ser
	# usada para sair quando o jogador aponta a mira diretamente para ela.
	var exit_door := _add_solid_box("ExitDoor", Vector3(0.0, 1.30, room_depth * 0.5 - 0.13), Vector3(opening_width - 0.16, 2.60, 0.14), Color(0.22, 0.105, 0.045))
	exit_door.set_meta("interaction_target", "interior_exit")
	var knob := MeshInstance3D.new()
	knob.name = "DoorHandle"
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.075
	knob_mesh.height = 0.15
	knob.mesh = knob_mesh
	knob.position = Vector3(0.43, 0.0, -0.085)
	var knob_material := StandardMaterial3D.new()
	knob_material.albedo_color = Color(0.72, 0.53, 0.20)
	knob_material.metallic = 0.55
	knob_material.roughness = 0.32
	knob.material_override = knob_material
	exit_door.add_child(knob)
	_add_solid_box("Ceiling", Vector3(0.0, WALL_HEIGHT + 0.06, 0.0), Vector3(room_width, 0.18, room_depth), Color(0.22, 0.18, 0.13))
	# Vigas de madeira, visuais e com colisão para evitar que atravessáveis pareçam sólidos.
	_add_solid_box("BeamNorth", Vector3(0.0, WALL_HEIGHT - 0.22, -room_depth * 0.5 + 0.16), Vector3(room_width - 0.3, 0.18, 0.18), WOOD_COLOR)
	_add_solid_box("BeamWest", Vector3(-room_width * 0.5 + 0.16, WALL_HEIGHT - 0.22, 0.0), Vector3(0.18, 0.18, room_depth - 0.3), WOOD_COLOR)
	_add_solid_box("BeamEast", Vector3(room_width * 0.5 - 0.16, WALL_HEIGHT - 0.22, 0.0), Vector3(0.18, 0.18, room_depth - 0.3), WOOD_COLOR)


func _build_furniture() -> void:
	var variant: int = abs(hash(building_id)) % 4
	match building_kind:
		"shop": _build_shop(variant)
		"workshop": _build_workshop(variant)
		"inn": _build_inn(variant)
		"tavern": _build_tavern(variant)
		"town_hall": _build_town_hall(variant)
		"library": _build_library(variant)
		"infirmary": _build_infirmary(variant)
		"guard_post": _build_guard_post(variant)
		"lookout": _build_lookout(variant)
		"depot": _build_depot(variant)
		"shelter": _build_shelter(variant)
		"stable": _build_stable(variant)
		"mill": _build_mill(variant)
		"barn": _build_barn(variant)
		_: _build_house(variant)


func _build_house(variant: int) -> void:
	var bed_x := -2.3 if variant % 2 == 0 else 2.3
	var bed_frame := _add_solid_box("BedFrame", Vector3(bed_x, 0.27, -2.3), Vector3(2.2, 0.5, 1.25), WOOD_COLOR)
	bed_frame.set_meta("interaction_target", "home_bed")
	var mattress := _add_solid_box("BedMattress", Vector3(bed_x, 0.58, -2.3), Vector3(2.0, 0.18, 1.08), CLOTH_COLOR)
	mattress.set_meta("interaction_target", "home_bed")
	_add_solid_box("BedPillow", Vector3(bed_x, 0.72, -2.68), Vector3(0.62, 0.12, 0.52), Color(0.70, 0.62, 0.47))
	var table_x := -1.9 if variant % 2 == 1 else 1.9
	_add_table("KitchenTable", Vector3(table_x, 0.62, 1.0), Vector2(1.5, 1.2))
	_add_solid_box("ChairSeat", Vector3(table_x + 0.1, 0.35, 2.0), Vector3(0.65, 0.16, 0.65), WOOD_LIGHT)
	_add_solid_box("ChairBack", Vector3(table_x + 0.1, 0.82, 2.28), Vector3(0.65, 0.85, 0.14), WOOD_COLOR)
	var storage_chest := _add_solid_box("StorageChest", Vector3(-room_width * 0.5 + 1.0, 0.42, -0.2), Vector3(1.1, 0.75, 0.8), WOOD_COLOR)
	storage_chest.set_meta("interaction_target", "home_storage")
	_add_solid_box("HearthStone", Vector3(room_width * 0.5 - 0.85, 0.48, -2.2), Vector3(0.9, 0.95, 1.1), STONE_COLOR)
	_add_solid_box("HearthOpening", Vector3(room_width * 0.5 - 0.85, 0.34, -1.60), Vector3(0.46, 0.38, 0.04), Color(0.10, 0.055, 0.025))


func _build_shop(variant: int) -> void:
	_add_solid_box("ShopCounter", Vector3(0.0, 0.58, -1.45), Vector3(room_width * 0.57, 1.15, 0.72), WOOD_COLOR)
	_add_solid_box("CounterTop", Vector3(0.0, 1.18, -1.45), Vector3(room_width * 0.61, 0.12, 0.86), WOOD_LIGHT)
	_add_shelf("ShelfWest", Vector3(-room_width * 0.5 + 0.65, 0.0, -1.0), Vector2(0.72, 2.9))
	_add_shelf("ShelfEast", Vector3(room_width * 0.5 - 0.65, 0.0, -1.0), Vector2(0.72, 2.9))
	_add_solid_box("GoodsCrateA", Vector3(-2.5, 0.38, 2.0), Vector3(0.85, 0.75, 0.85), WOOD_LIGHT)
	_add_solid_box("GoodsCrateB", Vector3(2.4, 0.35, -3.0 if variant % 2 == 0 else 2.0), Vector3(0.72, 0.7, 0.72), WOOD_COLOR)


func _build_workshop(variant: int) -> void:
	_add_solid_box("Workbench", Vector3(-1.6, 0.63, -2.0), Vector3(3.0, 1.2, 1.0), WOOD_COLOR)
	_add_solid_box("AnvilBase", Vector3(2.4, 0.35, -0.8), Vector3(0.75, 0.7, 0.7), STONE_COLOR)
	_add_solid_box("AnvilHead", Vector3(2.4, 0.78, -0.8), Vector3(1.0, 0.24, 0.46), Color(0.20, 0.22, 0.23))
	_add_solid_box("FurnaceBase", Vector3(-room_width * 0.5 + 1.1, 0.72, -3.0), Vector3(1.4, 1.45, 1.4), STONE_COLOR)
	_add_solid_box("FurnaceMouth", Vector3(-room_width * 0.5 + 1.1, 0.48, -2.25), Vector3(0.55, 0.50, 0.04), Color(0.9, 0.25, 0.045))
	_add_solid_box("ToolRack", Vector3(3.8, 1.6, -3.8 if variant % 2 == 0 else 2.8), Vector3(1.8, 0.18, 0.22), WOOD_LIGHT)
	_add_solid_box("OreCrate", Vector3(-2.8, 0.38, 2.6), Vector3(0.85, 0.75, 0.85), WOOD_COLOR)


func _build_inn(variant: int) -> void:
	var inn_bar := _add_solid_box("InnBar", Vector3(0.0, 0.58, -4.0), Vector3(room_width * 0.62, 1.15, 0.85), WOOD_COLOR)
	inn_bar.set_meta("interaction_target", "tavern_counter")
	var inn_bar_top := _add_solid_box("InnBarTop", Vector3(0.0, 1.18, -4.0), Vector3(room_width * 0.65, 0.12, 0.95), WOOD_LIGHT)
	inn_bar_top.set_meta("interaction_target", "tavern_counter")
	for i in range(3):
		var x := -4.0 + float(i) * 4.0
		var z := 0.1 if (i + variant) % 2 == 0 else 1.6
		_add_table("InnTable%d" % i, Vector3(x, 0.62, z), Vector2(1.7, 1.4))
		_add_solid_box("InnBench%dA" % i, Vector3(x, 0.30, z + 1.12), Vector3(1.6, 0.16, 0.42), WOOD_LIGHT)
		_add_solid_box("InnBench%dB" % i, Vector3(x, 0.30, z - 1.12), Vector3(1.6, 0.16, 0.42), WOOD_LIGHT)
	_add_solid_box("AleBarrel", Vector3(room_width * 0.5 - 1.1, 0.56, -2.7), Vector3(0.85, 1.1, 0.85), WOOD_COLOR)
	var inn_board := _add_solid_box("TavernNoticeBoard", Vector3(-room_width * 0.5 + 0.22, 1.75, -0.2), Vector3(0.12, 1.45, 2.1), WOOD_COLOR)
	inn_board.rotation.y = PI * 0.5
	inn_board.set_meta("interaction_target", "tavern_board")


func _build_tavern(variant: int) -> void:
	# A taverna é um espaço social, não uma cópia da hospedaria: balcão amplo,
	# mesas comunitárias, bancos e um quadro para notícias locais.
	var counter := _add_solid_box("TavernCounter", Vector3(0.0, 0.58, -4.1), Vector3(room_width * 0.66, 1.15, 0.9), WOOD_COLOR)
	counter.set_meta("interaction_target", "tavern_counter")
	var counter_top := _add_solid_box("TavernCounterTop", Vector3(0.0, 1.2, -4.1), Vector3(room_width * 0.69, 0.13, 1.0), WOOD_LIGHT)
	counter_top.set_meta("interaction_target", "tavern_counter")
	for i in range(3):
		var x := -4.0 + float(i) * 4.0
		var z := -0.35 if i % 2 == variant % 2 else 1.25
		_add_table("CommunityTable%d" % i, Vector3(x, 0.62, z), Vector2(1.75, 1.4))
		_add_solid_box("CommunityBench%dA" % i, Vector3(x, 0.30, z + 1.13), Vector3(1.65, 0.16, 0.42), WOOD_LIGHT)
		_add_solid_box("CommunityBench%dB" % i, Vector3(x, 0.30, z - 1.13), Vector3(1.65, 0.16, 0.42), WOOD_LIGHT)
	_add_solid_box("TavernBarrelA", Vector3(-5.2, 0.56, -2.5), Vector3(0.78, 1.1, 0.78), WOOD_COLOR)
	_add_solid_box("TavernBarrelB", Vector3(5.2, 0.56, -2.3), Vector3(0.78, 1.1, 0.78), WOOD_COLOR)
	var board := _add_solid_box("TavernNoticeBoard", Vector3(0.0, 1.75, -room_depth * 0.5 + 0.22), Vector3(2.25, 1.45, 0.12), WOOD_COLOR)
	board.set_meta("interaction_target", "tavern_board")
	_add_solid_box("TavernHearth", Vector3(-room_width * 0.5 + 0.8, 0.65, -1.6), Vector3(1.05, 1.25, 1.2), STONE_COLOR)
	_add_solid_box("TavernHearthGlow", Vector3(-room_width * 0.5 + 0.8, 0.34, -0.96), Vector3(0.5, 0.38, 0.05), Color(0.9, 0.28, 0.06))


func _build_town_hall(variant: int) -> void:
	_add_table("CouncilTable", Vector3(0.0, 0.68, -1.2), Vector2(3.8, 1.6))
	for i in range(3):
		var x := -4.0 + float(i) * 4.0
		_add_solid_box("BenchFront%d" % i, Vector3(x, 0.30, 1.1), Vector3(2.3, 0.18, 0.48), WOOD_LIGHT)
		_add_solid_box("BenchBack%d" % i, Vector3(x, 0.30, -3.3), Vector3(2.3, 0.18, 0.48), WOOD_LIGHT)
	_add_solid_box("NoticeBoard", Vector3(0.0, 1.65, -room_depth * 0.5 + 0.18), Vector3(2.2, 1.4, 0.16), WOOD_COLOR)
	_add_solid_box("StorageChest", Vector3(-room_width * 0.5 + 1.0, 0.40, -2.5 if variant % 2 == 0 else 2.5), Vector3(1.0, 0.75, 0.8), WOOD_COLOR)



func _build_library(variant: int) -> void:
	_add_shelf("LibraryShelfWest", Vector3(-room_width * 0.5 + 0.55, 0.0, -1.0), Vector2(0.9, 2.8))
	_add_shelf("LibraryShelfEast", Vector3(room_width * 0.5 - 0.55, 0.0, -1.0), Vector2(0.9, 2.8))
	_add_shelf("LibraryShelfNorth", Vector3(0.0, 0.0, -room_depth * 0.5 + 0.6), Vector2(0.9, 2.5))
	_add_table("ReadingTable", Vector3(0.0, 0.62, 1.0), Vector2(2.4, 1.4))
	_add_solid_box("ArchiveChest", Vector3(room_width * 0.5 - 1.1, 0.42, 2.8), Vector3(0.95, 0.78, 0.75), WOOD_COLOR)


func _build_infirmary(variant: int) -> void:
	for i in range(3):
		var x := -3.4 + float(i) * 3.4
		_add_solid_box("InfirmaryBedFrame%d" % i, Vector3(x, 0.24, -1.3), Vector3(2.3, 0.42, 1.15), WOOD_COLOR)
		_add_solid_box("InfirmaryMattress%d" % i, Vector3(x, 0.49, -1.3), Vector3(2.15, 0.14, 1.02), Color(0.64, 0.60, 0.49))
		_add_solid_box("InfirmaryPillow%d" % i, Vector3(x, 0.60, -1.65), Vector3(0.65, 0.10, 0.35), Color(0.78, 0.73, 0.62))
	_add_shelf("MedicineShelf", Vector3(-room_width * 0.5 + 0.55, 0.0, 1.8), Vector2(0.75, 2.3))
	_add_table("TreatmentTable", Vector3(2.2, 0.62, 2.2), Vector2(1.6, 1.2))


func _build_guard_post(variant: int) -> void:
	_add_table("GuardTable", Vector3(0.0, 0.62, -1.4), Vector2(2.4, 1.3))
	_add_solid_box("GuardMapBoard", Vector3(0.0, 1.6, -room_depth * 0.5 + 0.2), Vector3(2.4, 1.5, 0.15), WOOD_COLOR)
	_add_solid_box("WeaponRack", Vector3(-room_width * 0.5 + 0.65, 1.55, 0.0), Vector3(0.28, 2.4, 2.4), WOOD_LIGHT)
	_add_solid_box("GuardSupplyChest", Vector3(2.8, 0.40, 2.5), Vector3(1.0, 0.75, 0.75), WOOD_COLOR)


func _build_lookout(variant: int) -> void:
	_add_table("LookoutChartTable", Vector3(0.0, 0.62, -0.9), Vector2(2.1, 1.1))
	_add_solid_box("LookoutSignalBoard", Vector3(0.0, 1.55, -room_depth * 0.5 + 0.18), Vector3(2.0, 1.25, 0.14), WOOD_COLOR)
	_add_solid_box("LookoutBench", Vector3(1.6, 0.32, 2.2), Vector3(2.0, 0.18, 0.48), WOOD_LIGHT)


func _build_depot(variant: int) -> void:
	for row in range(2):
		for col in range(3):
			var x := -3.5 + float(col) * 3.5
			var z := -2.8 + float(row) * 4.5
			_add_solid_box("DepotCrate_%d_%d" % [row, col], Vector3(x, 0.48, z), Vector3(1.35, 0.92, 1.25), WOOD_COLOR if (row + col) % 2 == 0 else WOOD_LIGHT)
	_add_shelf("DepotToolRack", Vector3(-room_width * 0.5 + 0.6, 0.0, 0.2), Vector2(0.8, 2.5))


func _build_shelter(variant: int) -> void:
	_add_solid_box("ShelterBenchWest", Vector3(-2.5, 0.32, -1.8), Vector3(3.0, 0.18, 0.48), WOOD_LIGHT)
	_add_solid_box("ShelterBenchEast", Vector3(2.5, 0.32, -1.8), Vector3(3.0, 0.18, 0.48), WOOD_LIGHT)
	_add_solid_box("ShelterHearth", Vector3(0.0, 0.28, -room_depth * 0.5 + 1.2), Vector3(1.6, 0.55, 1.1), STONE_COLOR)
	_add_solid_box("ShelterSupplyChest", Vector3(2.6, 0.38, 2.2), Vector3(0.9, 0.72, 0.7), WOOD_COLOR)


func _build_stable(variant: int) -> void:
	for stall in range(3):
		var z := -3.0 + float(stall) * 3.1
		_add_solid_box("StableDivider%d" % stall, Vector3(-1.1, 0.85, z), Vector3(0.12, 1.7, 2.5), WOOD_COLOR)
		_add_solid_box("StableHay%d" % stall, Vector3(-3.3, 0.45, z), Vector3(1.0, 0.8, 0.9), Color(0.55, 0.43, 0.20))
	_add_solid_box("StableTrough", Vector3(3.2, 0.35, 0.4), Vector3(2.6, 0.6, 0.75), WOOD_LIGHT)


func _build_mill(variant: int) -> void:
	_add_solid_box("MillWorkPlatform", Vector3(0.0, 0.30, -1.0), Vector3(3.0, 0.6, 2.4), STONE_COLOR)
	_add_solid_box("MillGrindingStone", Vector3(0.0, 0.80, -1.0), Vector3(1.5, 0.35, 1.5), Color(0.42, 0.40, 0.35))
	for i in range(3):
		_add_solid_box("FlourSack%d" % i, Vector3(-3.4 + float(i) * 2.5, 0.42, 2.4), Vector3(0.85, 0.82, 0.72), Color(0.59, 0.49, 0.32))
	_add_table("MillSortingTable", Vector3(3.6, 0.62, -2.7), Vector2(1.5, 1.1))


func _build_barn(variant: int) -> void:
	for i in range(4):
		var x := -3.6 + float(i % 2) * 6.4
		var z := -2.5 + float(i / 2) * 4.2
		_add_solid_box("HayBale%d" % i, Vector3(x, 0.45, z), Vector3(1.6, 0.9, 1.25), Color(0.56, 0.43, 0.20))
	_add_solid_box("BarnToolCrate", Vector3(4.7, 0.4, 0.0), Vector3(0.85, 0.75, 0.75), WOOD_COLOR)



func _add_table(label: String, center: Vector3, footprint: Vector2) -> void:
	var top_center := Vector3(center.x, 0.78, center.z)
	var leg_center_y := 0.38
	_add_solid_box(label + "Top", top_center, Vector3(footprint.x, 0.14, footprint.y), WOOD_LIGHT)
	var leg_x := footprint.x * 0.5 - 0.12
	var leg_z := footprint.y * 0.5 - 0.12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_solid_box(label + "Leg", Vector3(center.x + sx * leg_x, leg_center_y, center.z + sz * leg_z), Vector3(0.14, 0.76, 0.14), WOOD_COLOR)


func _add_shelf(label: String, base: Vector3, dimensions: Vector2) -> void:
	_add_solid_box(label + "Back", base + Vector3(0.0, dimensions.y * 0.5, 0.0), Vector3(dimensions.x, dimensions.y, 0.16), WOOD_COLOR)
	for level in range(3):
		var y := 0.45 + float(level) * 0.9
		_add_solid_box(label + "Plank", base + Vector3(0.0, y, 0.12), Vector3(dimensions.x + 0.12, 0.12, 0.54), WOOD_LIGHT)


func _add_indoor_light() -> void:
	var light := OmniLight3D.new()
	light.name = "WarmInteriorLight"
	light.position = Vector3(0.0, WALL_HEIGHT - 0.35, 0.0)
	light.light_color = Color(1.0, 0.76, 0.48)
	light.light_energy = 1.55
	light.omni_range = maxf(room_width, room_depth) * 1.7
	light.shadow_enabled = false
	add_child(light)


func _add_solid_box(label: String, center: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	add_child(body)
	return body

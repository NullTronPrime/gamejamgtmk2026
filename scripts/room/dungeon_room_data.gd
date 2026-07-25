class_name DungeonRoomData
extends Resource

enum RoomType { START, PUZZLE, TREASURE, COMBAT, EXIT }

@export var room_type: RoomType = RoomType.START
@export var width: int = 20
@export var height: int = 14
@export var theme: String = "cave"

@export var floor_y: int = 12
@export var ceiling_y: int = 0

@export var spawn_x: int = 2
@export var spawn_y: int = 11

@export var walls: Array[Vector2i] = []
@export var platforms: Array[Vector2i] = []
@export var blocks: Array[Dictionary] = []
@export var pickups: Array[Dictionary] = []
@export var doors: Array[Dictionary] = []

func to_str() -> String:
	return "<DungeonRoom %s %dx%d>" % [RoomType.keys()[room_type], width, height]

static func generate_procedural(type: RoomType, rng: RandomNumberGenerator) -> DungeonRoomData:
	var room := DungeonRoomData.new()
	room.room_type = type
	room.theme = RoomTheme.keys()[rng.randi_range(0, RoomTheme.size() - 1)].to_lower()

	if type == RoomType.START:
		room.spawn_x = 2

	var pillar_count := rng.randi_range(2, 4)
	for i in pillar_count:
		var px := rng.randi_range(3, room.width - 4)
		var py := rng.randi_range(room.height - 6, room.height - 3)
		room.walls.append(Vector2i(px, py))
		room.walls.append(Vector2i(px + 1, py))

	var plat_count := rng.randi_range(1, 3)
	for i in plat_count:
		var px := rng.randi_range(2, room.width - 5)
		var py := rng.randi_range(room.height - 7, room.height - 4)
		for w in rng.randi_range(3, 5):
			if px + w < room.width - 1:
				room.platforms.append(Vector2i(px + w, py))

	var block_count := rng.randi_range(1, 3)
	for i in block_count:
		var px := rng.randi_range(2, room.width - 3)
		var py := room.floor_y - 1
		if abs(px - room.spawn_x) < 3:
			continue
		room.blocks.append({ "x": px, "y": py, "mass": rng.randf_range(1.0, 4.0) })

	if type == RoomType.PUZZLE or type == RoomType.TREASURE:
		for item_id in ["bottle_empty", "liquid_blue"]:
			var px := rng.randi_range(3, room.width - 4)
			var py := room.floor_y - 1
			room.pickups.append({ "id": item_id, "x": px, "y": py })

	return room

enum RoomTheme { CAVE, RUIN, LAB }
const THEME_NAMES := ["cave", "ruin", "lab"]

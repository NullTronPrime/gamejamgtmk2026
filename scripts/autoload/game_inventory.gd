extends Node

const COLS := 5
const ROWS := 2
const SLOT_SIZE := 52
const GAP := 4
const PAD := 16

var items: Array[Dictionary] = []

var selected_item: String = "":
	set(value):
		if selected_item != value:
			selected_item = value
			selected_changed.emit(value)

signal inventory_changed
signal inventory_opened
signal inventory_closed
signal selected_changed(item_id: String)

static func item_data() -> Dictionary:
	return {
		"bottle_empty": { "name": "Empty Bottle", "icon": Color(0.2, 0.7, 0.2) },
		"liquid_blue": { "name": "Blue Liquid", "icon": Color(0.2, 0.3, 0.9) },
		"potion_filled": { "name": "Filled Potion", "icon": Color(0.3, 0.8, 0.6) },
		"arrow": { "name": "Arrow", "icon": Color(0.6, 0.5, 0.3) },
		"milk_bowl": { "name": "Bowl of Milk", "icon": Color(0.9, 0.85, 0.7) },
		"egg": { "name": "Egg", "icon": Color(0.95, 0.8, 0.6) },
		"torn_cape": { "name": "Torn Cape", "icon": Color(0.4, 0.15, 0.15) },
		"dagger": { "name": "Dagger", "icon": Color(0.5, 0.5, 0.5) },
		"lion_skull": { "name": "Lion Skull", "icon": Color(0.8, 0.75, 0.6) },
		"lion_torso": { "name": "Lion Torso", "icon": Color(0.75, 0.7, 0.55) },
		"key": { "name": "Key", "icon": Color(0.8, 0.7, 0.2) },
		"flower_bunch": { "name": "Bunch of Flowers", "icon": Color(0.9, 0.3, 0.5), "icon_texture": preload("res://assets/art/items/allflowersbunched.jpg") },
		"berry": { "name": "Berry", "icon": Color(0.8, 0.1, 0.1) },
		"letter_shaktinath": { "name": "Shaktinath's Letter", "icon": Color(0.9, 0.8, 0.5) },
		"snake_scales": { "name": "Snake Scales", "icon": Color(0.2, 0.6, 0.3) },
		"lion_neck": { "name": "Lion Neck Bone", "icon": Color(0.75, 0.7, 0.55) },
		"lion_arms": { "name": "Lion Arms", "icon": Color(0.7, 0.65, 0.5) },
		"lion_legs": { "name": "Lion Legs", "icon": Color(0.7, 0.65, 0.5) },
		"lion_tail": { "name": "Lion Tail", "icon": Color(0.8, 0.75, 0.6) },
		"skeleton_neck": { "name": "Lion Neck Bone", "icon": Color(0.75, 0.7, 0.55), "icon_texture": preload("res://assets/art/skeleton/icon_neck.png") },
		"skeleton_skull": { "name": "Lion Skull", "icon": Color(0.8, 0.75, 0.6), "icon_texture": preload("res://assets/art/skeleton/icon_skull.png") },
		"skeleton_arms": { "name": "Lion Front Legs", "icon": Color(0.7, 0.65, 0.5), "icon_texture": preload("res://assets/art/skeleton/icon_arms.png") },
		"skeleton_ribs": { "name": "Lion Ribcage", "icon": Color(0.78, 0.73, 0.6), "icon_texture": preload("res://assets/art/skeleton/icon_ribs.png") },
		"skeleton_legs": { "name": "Lion Back Legs", "icon": Color(0.7, 0.65, 0.5), "icon_texture": preload("res://assets/art/skeleton/icon_legs.png") },
		"skeleton_tail": { "name": "Lion Tail", "icon": Color(0.82, 0.77, 0.65), "icon_texture": preload("res://assets/art/skeleton/icon_tail.png") },
		"life_potion": { "name": "Potion of Life", "icon": Color(0.2, 0.8, 0.9), "icon_texture": preload("res://assets/art/rooms/lifebottle.png") }
	}

func add_item(item_id: String) -> bool:
	for i in items.size():
		if items[i]["id"] == item_id:
			items[i]["qty"] = int(items[i]["qty"]) + 1
			inventory_changed.emit()
			return true
	if items.size() < COLS * ROWS:
		items.append({ "id": item_id, "qty": 1 })
		inventory_changed.emit()
		return true
	return false

func has_item(item_id: String) -> bool:
	for entry in items:
		if entry["id"] == item_id:
			return true
	return false

func remove_item(item_id: String) -> bool:
	for i in items.size():
		if items[i]["id"] == item_id:
			var qty: int = int(items[i]["qty"]) - 1
			if qty <= 0:
				items.remove_at(i)
				if selected_item == item_id:
					selected_item = ""
			else:
				items[i]["qty"] = qty
			inventory_changed.emit()
			return true
	return false

func clear() -> void:
	items.clear()
	selected_item = ""
	inventory_changed.emit()

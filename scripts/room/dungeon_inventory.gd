class_name DungeonInventory
extends Control

const COLS := 5
const ROWS := 2
const SLOT_SIZE := 52
const GAP := 4
const PAD := 16

var items: Array[Dictionary] = []
var _open := false

static func item_data() -> Dictionary:
	return {
		"bottle_empty": { "name": "Empty Bottle", "icon": Color(0.2, 0.7, 0.2) },
		"liquid_blue": { "name": "Blue Liquid", "icon": Color(0.2, 0.3, 0.9) },
		"potion_filled": { "name": "Filled Potion", "icon": Color(0.3, 0.8, 0.6) }
	}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS

func toggle() -> void:
	_open = not _open
	visible = _open
	mouse_filter = Control.MOUSE_FILTER_STOP if _open else Control.MOUSE_FILTER_PASS
	if _open:
		queue_redraw()

func add_item(item_id: String) -> bool:
	for i in items.size():
		if items[i]["id"] == item_id:
			items[i]["qty"] = int(items[i]["qty"]) + 1
			if _open:
				queue_redraw()
			return true
	if items.size() < COLS * ROWS:
		items.append({ "id": item_id, "qty": 1 })
		if _open:
			queue_redraw()
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
			else:
				items[i]["qty"] = qty
			if _open:
				queue_redraw()
			return true
	return false

func _draw() -> void:
	var pw: int = COLS * (SLOT_SIZE + GAP) + PAD * 2
	var ph: int = ROWS * (SLOT_SIZE + GAP) + PAD * 2 + 20
	var ox: float = (size.x - pw) / 2.0
	var oy: float = (size.y - ph) / 2.0

	var bg := Rect2(ox, oy, pw, ph)
	draw_rect(bg, Color(0.08, 0.08, 0.12, 0.92))
	draw_rect(bg, Color(0.3, 0.3, 0.4), false, 2)

	draw_string(ThemeDB.fallback_font, Vector2(ox + PAD, oy + 14), "INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, pw - PAD * 2, 12, Color(0.7, 0.7, 0.9))

	var data: Dictionary = item_data()
	var start_y: float = oy + 28.0

	if items.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(ox + pw / 2.0 - 36, start_y + 30),
			"(empty)", HORIZONTAL_ALIGNMENT_LEFT, 72, 11, Color(0.4, 0.4, 0.5))

	for i in COLS * ROWS:
		var col: int = i % COLS
		var row: int = i / COLS
		var sx: float = ox + PAD + col * (SLOT_SIZE + GAP)
		var sy: float = start_y + row * (SLOT_SIZE + GAP)
		var slot := Rect2(sx, sy, SLOT_SIZE, SLOT_SIZE)

		draw_rect(slot, Color(0.18, 0.18, 0.22))
		draw_rect(slot, Color(0.4, 0.4, 0.5), false, 1)

		if i < items.size():
			var entry: Dictionary = items[i]
			var id: String = entry["id"]
			if data.has(id):
				var d: Dictionary = data[id]
				var icon_rect := Rect2(sx + 4, sy + 4, SLOT_SIZE - 8, SLOT_SIZE - 8)
				draw_rect(icon_rect, d["icon"])

				var label: String = d["name"] if int(entry["qty"]) <= 1 else "%s x%d" % [d["name"], entry["qty"]]
				draw_string(ThemeDB.fallback_font, Vector2(sx + 3, sy + SLOT_SIZE - 3), label,
					HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE - 6, 8, Color.WHITE)

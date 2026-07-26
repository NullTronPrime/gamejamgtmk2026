class_name DungeonInventory
extends Control

var _open := false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameInventory.inventory_changed.connect(_on_inventory_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _open:
		queue_redraw()

func toggle() -> void:
	_open = not _open
	visible = _open
	mouse_filter = Control.MOUSE_FILTER_STOP if _open else Control.MOUSE_FILTER_PASS
	if _open:
		queue_redraw()
		queue_redraw.call_deferred()

func _on_inventory_changed() -> void:
	if _open:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var items = GameInventory.items
		var local_pos = (event as InputEventMouseButton).position
		var pw = GameInventory.COLS * (GameInventory.SLOT_SIZE + GameInventory.GAP) + GameInventory.PAD * 2
		var ph = GameInventory.ROWS * (GameInventory.SLOT_SIZE + GameInventory.GAP) + GameInventory.PAD * 2 + 20
		var ox = (size.x - pw) / 2.0
		var oy = (size.y - ph) / 2.0
		var start_y = oy + 28.0

		for i in items.size():
			var col = i % GameInventory.COLS
			var row = i / GameInventory.COLS
			var sx = ox + GameInventory.PAD + col * (GameInventory.SLOT_SIZE + GameInventory.GAP)
			var sy = start_y + row * (GameInventory.SLOT_SIZE + GameInventory.GAP)
			var slot = Rect2(sx, sy, GameInventory.SLOT_SIZE, GameInventory.SLOT_SIZE)
			if slot.has_point(local_pos):
				var id = items[i]["id"]
				if GameInventory.selected_item == id:
					GameInventory.selected_item = ""
				else:
					GameInventory.selected_item = id
				accept_event()
				queue_redraw()
				return

func _draw() -> void:
	var items = GameInventory.items
	var data = GameInventory.item_data()
	var pw = GameInventory.COLS * (GameInventory.SLOT_SIZE + GameInventory.GAP) + GameInventory.PAD * 2
	var ph = GameInventory.ROWS * (GameInventory.SLOT_SIZE + GameInventory.GAP) + GameInventory.PAD * 2 + 20
	var ox = (size.x - pw) / 2.0
	var oy = (size.y - ph) / 2.0

	var bg = Rect2(ox, oy, pw, ph)
	draw_rect(bg, Color(0.08, 0.08, 0.12, 0.92))
	draw_rect(bg, Color(0.3, 0.3, 0.4), false, 2)

	draw_string(ThemeDB.fallback_font, Vector2(ox + GameInventory.PAD, oy + 14), "INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, pw - GameInventory.PAD * 2, 12, Color(0.7, 0.7, 0.9))

	var start_y = oy + 28.0

	if items.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(ox + pw / 2.0 - 36, start_y + 30),
			"(empty)", HORIZONTAL_ALIGNMENT_LEFT, 72, 11, Color(0.4, 0.4, 0.5))

	for i in GameInventory.COLS * GameInventory.ROWS:
		var col = i % GameInventory.COLS
		var row = i / GameInventory.COLS
		var sx = ox + GameInventory.PAD + col * (GameInventory.SLOT_SIZE + GameInventory.GAP)
		var sy = start_y + row * (GameInventory.SLOT_SIZE + GameInventory.GAP)
		var slot = Rect2(sx, sy, GameInventory.SLOT_SIZE, GameInventory.SLOT_SIZE)
		var is_selected = i < items.size() and items[i]["id"] == GameInventory.selected_item

		if is_selected:
			draw_rect(Rect2(sx - 2, sy - 2, GameInventory.SLOT_SIZE + 4, GameInventory.SLOT_SIZE + 4), Color(0.8, 0.8, 1.0), false, 3)
			draw_rect(slot, Color(0.25, 0.25, 0.32))
		else:
			draw_rect(slot, Color(0.18, 0.18, 0.22))
		draw_rect(slot, Color(0.4, 0.4, 0.5), false, 1)

		if i < items.size():
			var entry = items[i]
			var id = entry["id"]
			if data.has(id):
				var d = data[id]
				var icon_rect = Rect2(sx + 4, sy + 4, GameInventory.SLOT_SIZE - 8, GameInventory.SLOT_SIZE - 8)
				if d.has("icon_texture") and d["icon_texture"]:
					draw_texture_rect(d["icon_texture"], icon_rect, false)
				else:
					draw_rect(icon_rect, d["icon"])
				var label = d["name"] if int(entry["qty"]) <= 1 else "%s x%d" % [d["name"], entry["qty"]]
				draw_string(ThemeDB.fallback_font, Vector2(sx + 3, sy + GameInventory.SLOT_SIZE - 3), label,
					HORIZONTAL_ALIGNMENT_LEFT, GameInventory.SLOT_SIZE - 6, 8, Color.WHITE)

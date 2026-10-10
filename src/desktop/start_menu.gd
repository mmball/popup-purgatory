class_name StartMenu
extends Control
## The Start menu doubles as the build menu. Items list buildings with their
## current price; the last item ends the run.

signal building_chosen(id: String)
signal shutdown_requested

const WIDTH := 300
const ITEM_H := 28
const BAND_W := 24

var _items: Array[Button] = []
var _run: RunState
var _village: Village


class MenuItem extends Button:
	var caption := ""
	var detail := ""
	var swatch := Color.TRANSPARENT
	var hotkey := ""

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var hover := is_hovered() and not disabled
		if hover:
			draw_rect(Rect2(Vector2.ZERO, size), Win98.SELECT)
		var fg := Win98.WHITE if hover else (Win98.GRAY_DARK if disabled else Win98.BLACK)
		if swatch.a > 0.0:
			draw_rect(Rect2(6, (size.y - 16) * 0.5, 16, 16), swatch)
			draw_rect(Rect2(6, (size.y - 16) * 0.5, 16, 16), Win98.BLACK, false, 1.0)
		if hotkey != "":
			Win98.draw_text(self, Vector2(28, (size.y - 13) * 0.5), hotkey, fg, 11)
		Win98.draw_text(self, Vector2(44, (size.y - 15) * 0.5), caption, fg, 13)
		if detail != "":
			var ts := Win98.text_size(detail, 11)
			Win98.draw_text(self, Vector2(size.x - ts.x - 8, (size.y - ts.y) * 0.5), detail, fg, 11)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var y := 4
	for i in range(BuildingCatalog.ORDER.size()):
		var id: String = BuildingCatalog.ORDER[i]
		var def := BuildingCatalog.get_def(id)
		var item := MenuItem.new()
		item.caption = str(def["name"])
		item.swatch = def["color"]
		item.hotkey = str(i + 1)
		item.tooltip_text = str(def["desc"])
		item.position = Vector2(BAND_W + 2, y)
		item.size = Vector2(WIDTH - BAND_W - 4, ITEM_H)
		item.pressed.connect(func() -> void: building_chosen.emit(id))
		add_child(item)
		_items.append(item)
		y += ITEM_H
	y += 8
	var shutdown := MenuItem.new()
	shutdown.caption = "Shut Down..."
	shutdown.position = Vector2(BAND_W + 2, y)
	shutdown.size = Vector2(WIDTH - BAND_W - 4, ITEM_H)
	shutdown.pressed.connect(func() -> void: shutdown_requested.emit())
	add_child(shutdown)
	y += ITEM_H + 4
	size = Vector2(WIDTH, y)
	custom_minimum_size = size


func refresh(run: RunState, village: Village) -> void:
	_run = run
	_village = village
	for i in range(BuildingCatalog.ORDER.size()):
		var id: String = BuildingCatalog.ORDER[i]
		var owned := village.count(id)
		var maxed := owned >= BuildingCatalog.max_count(id)
		var item: MenuItem = _items[i]
		if maxed:
			item.detail = "MAX (%d)" % owned
		else:
			item.detail = "%d B   x%d" % [BuildingCatalog.cost(id, owned), owned]
		item.disabled = maxed
		item.queue_redraw()


func _draw() -> void:
	Win98.draw_bevel(self, Rect2(Vector2.ZERO, size), false)
	# vertical brand band
	draw_rect(Rect2(3, 3, BAND_W - 3, size.y - 6), Win98.TITLE_A)
	draw_set_transform(Vector2(5, size.y - 10), -PI / 2, Vector2.ONE)
	Win98.draw_text(self, Vector2.ZERO, "Popup Purgatory 98", Win98.GRAY, 14)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# separator above Shut Down
	var sep_y := 4 + BuildingCatalog.ORDER.size() * ITEM_H + 3
	draw_rect(Rect2(BAND_W + 4, sep_y, size.x - BAND_W - 8, 1), Win98.GRAY_DARK)
	draw_rect(Rect2(BAND_W + 4, sep_y + 1, size.x - BAND_W - 8, 1), Win98.WHITE)

class_name DesktopIcon
extends Control
## A wallpaper icon with a label. Click to select, double-click to activate.

signal activated

var label := "Icon"
var kind := "computer"
var selected := false

# Recycle Bin state (ignored by the other kinds). The empty bin draws exactly as before.
var bin_items := 0:          ## crumpled sheets sticking out, one per item
	set(v):
		bin_items = v
		queue_redraw()
var emptying := 0.0:         ## 0..1 progress of "Empty Recycle Bin"; a bar shows while > 0
	set(v):
		emptying = v
		queue_redraw()
var highlight := false:      ## a window is being dragged over the icon
	set(v):
		highlight = v
		queue_redraw()


func _init(p_label: String, p_kind: String) -> void:
	label = p_label
	kind = p_kind
	custom_minimum_size = Vector2(76, 60)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			activated.emit()
		selected = true
		queue_redraw()


func deselect() -> void:
	selected = false
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	match kind:
		"computer":
			draw_rect(Rect2(cx - 14, 4, 28, 20), Color("e0dcc8"))
			draw_rect(Rect2(cx - 11, 7, 22, 13), Win98.TITLE_A)
			draw_rect(Rect2(cx - 8, 24, 16, 3), Color("a8a494"))
			draw_rect(Rect2(cx - 14, 27, 28, 5), Color("e0dcc8"))
		"bin":
			draw_rect(Rect2(cx - 10, 8, 20, 24), Color("d8d8d8"))
			draw_rect(Rect2(cx - 12, 5, 24, 4), Color("a0a0a0"))
			for i in range(3):
				draw_rect(Rect2(cx - 7 + i * 6, 12, 2, 16), Color("909090"))
			_draw_bin_extras(cx)
		"imps":
			draw_circle(Vector2(cx, 20), 12, Color("8b2fc9"))
			draw_polygon(PackedVector2Array([Vector2(cx - 9, 13), Vector2(cx - 12, 2), Vector2(cx - 3, 10)]), PackedColorArray([Color("6a1f9c")]))
			draw_polygon(PackedVector2Array([Vector2(cx + 9, 13), Vector2(cx + 12, 2), Vector2(cx + 3, 10)]), PackedColorArray([Color("6a1f9c")]))
			draw_circle(Vector2(cx - 4, 18), 3, Color.WHITE)
			draw_circle(Vector2(cx + 4, 18), 3, Color.WHITE)
			draw_circle(Vector2(cx - 4, 18), 1.4, Color.BLACK)
			draw_circle(Vector2(cx + 4, 18), 1.4, Color.BLACK)
	var ts := Win98.text_size(label, 11)
	var tp := Vector2(cx - ts.x * 0.5, 36)
	if selected:
		draw_rect(Rect2(tp - Vector2(2, 1), ts + Vector2(4, 2)), Win98.SELECT)
	else:
		Win98.draw_text(self, tp + Vector2(1, 1), label, Color.BLACK, 11)
	Win98.draw_text(self, tp, label, Color.WHITE, 11)


## Everything the bin draws beyond its empty state: paper per item, the count,
## the emptying bar and the drop-target tint. Draws nothing when all are off.
func _draw_bin_extras(cx: float) -> void:
	for i in range(mini(bin_items, RunState.BIN_CAPACITY)):
		var x := cx - 9.0 + i * 7.0
		var y := 1.0 + (i % 2) * 2.0
		var sheet := PackedVector2Array([Vector2(x, y + 2), Vector2(x + 3, y), Vector2(x + 6, y + 1),
			Vector2(x + 7, y + 4), Vector2(x + 5, y + 7), Vector2(x + 1, y + 6)])
		draw_polygon(sheet, PackedColorArray([Color("f4f4ec")]))
		var outline := sheet.duplicate()
		outline.append(sheet[0])
		draw_polyline(outline, Color("8c8c84"), 1.0)
		draw_line(Vector2(x + 2, y + 3), Vector2(x + 5, y + 4), Color("b8b8b0"), 1.0)
	if bin_items > 0:
		var count := "%d/%d" % [bin_items, RunState.BIN_CAPACITY]
		Win98.draw_text(self, Vector2(cx + 14, 23), count, Color.BLACK, 9)
		Win98.draw_text(self, Vector2(cx + 13, 22), count, Color.WHITE, 9)
	if emptying > 0.0:
		var bar := Rect2(cx - 14, 52, 28, 4)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(emptying, 0.0, 1.0), bar.size.y - 2)), Color("7CFC00"))
	if highlight:
		draw_rect(Rect2(cx - 16, 2, 32, 32), Color(Win98.SELECT, 0.45))

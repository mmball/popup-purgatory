class_name DesktopIcon
extends Control
## A wallpaper icon with a label. Click to select, double-click to activate.

signal activated

var label := "Icon"
var kind := "computer"
var selected := false


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

class_name WindowFrame
extends Control
## A Win98 window: bevelled frame, gradient title bar, X button, drag-to-move,
## click-to-raise. Pop-ups and dialogs both extend this.

signal close_requested
signal raised

const TITLE_H := 18
const BORDER := 3

var window_title := "Window":
	set(v):
		window_title = v
		if title_bar:
			title_bar.queue_redraw()
var closable := true:
	set(v):
		closable = v
		if close_button:
			close_button.visible = v
var draggable := true
var close_button_size := 16
var icon_color := Win98.TITLE_B
var drag_bounds := Rect2()   ## when non-empty, the window stays inside this rect

var title_bar: Control
var close_button: Win98Button
var content: MarginContainer

var _dragging := false
var _drag_offset := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(300, 200)

	title_bar = Control.new()
	title_bar.name = "TitleBar"
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.draw.connect(_draw_title_bar)
	title_bar.gui_input.connect(_on_title_input)
	add_child(title_bar)

	close_button = Win98Button.new("", Vector2(16, 14))
	close_button.name = "CloseButton"
	close_button.extra_draw = _draw_x_glyph
	close_button.pressed.connect(_on_close_pressed)
	add_child(close_button)

	content = MarginContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		content.add_theme_constant_override(side, 6)
	add_child(content)

	resized.connect(_layout)
	_layout()


func set_window_size(s: Vector2) -> void:
	custom_minimum_size = s
	size = s
	_layout()


func set_close_button_size(px: int) -> void:
	close_button_size = px
	_layout()


func title_height() -> int:
	return maxi(TITLE_H, close_button_size + 2)


func _layout() -> void:
	var th := title_height()
	title_bar.position = Vector2(BORDER, BORDER)
	title_bar.size = Vector2(size.x - BORDER * 2, th)
	var bs := Vector2(close_button_size, close_button_size - 2)
	close_button.custom_minimum_size = bs
	close_button.size = bs
	close_button.position = Vector2(size.x - BORDER - 2 - bs.x, BORDER + (th - bs.y) * 0.5)
	content.position = Vector2(BORDER, BORDER + th + 1)
	content.size = Vector2(size.x - BORDER * 2, size.y - BORDER * 2 - th - 1)
	queue_redraw()
	title_bar.queue_redraw()


func _draw() -> void:
	Win98.draw_bevel(self, Rect2(Vector2.ZERO, size), false)


func _draw_title_bar() -> void:
	var tb := title_bar
	tb.draw_texture_rect(Win98.title_gradient(true), Rect2(Vector2.ZERO, tb.size), false)
	# tiny app icon
	var th := title_height()
	var icon_rect := Rect2(Vector2(3, (th - 12) * 0.5), Vector2(12, 12))
	tb.draw_rect(icon_rect, icon_color)
	tb.draw_rect(icon_rect, Win98.WHITE, false, 1.0)
	var ts := Win98.text_size(window_title, 12)
	Win98.draw_text(tb, Vector2(19, floorf((th - ts.y) * 0.5)), window_title, Win98.WHITE, 12, tb.size.x - 19 - close_button_size - 6)


func _draw_x_glyph(btn: Control, off: Vector2) -> void:
	var c := btn.size * 0.5 + off
	var r := minf(btn.size.x, btn.size.y) * 0.25
	var col := Win98.GRAY_DARK if btn.disabled else Win98.BLACK
	btn.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 2.0)
	btn.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 2.0)


func _on_close_pressed() -> void:
	if closable and not close_button.disabled:
		close_requested.emit()


func raise() -> void:
	move_to_front()
	raised.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		raise()


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				raise()
				if draggable:
					_dragging = true
					_drag_offset = get_global_mouse_position() - global_position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var target := get_global_mouse_position() - _drag_offset
		if drag_bounds.size != Vector2.ZERO:
			target.x = clampf(target.x, drag_bounds.position.x, drag_bounds.end.x - size.x)
			target.y = clampf(target.y, drag_bounds.position.y, drag_bounds.end.y - size.y)
		global_position = target.round()


## Centers this window inside its parent control.
func center_in_parent() -> void:
	var p := get_parent()
	if p is Control:
		position = ((p.size - size) * 0.5).round()

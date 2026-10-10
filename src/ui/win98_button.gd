class_name Win98Button
extends Button
## A push button that draws its own bevel and caption. Godot's Button draws its
## theme before a script's _draw() runs, so the stock text would end up under
## our bevel; instead we keep `text` empty and draw `label` ourselves.

var label := "":
	set(v):
		label = v
		queue_redraw()
var font_size := Win98.FONT_SIZE
var bold_border := false          ## thicker outer border, used for default buttons
var extra_draw: Callable          ## optional (button, offset) -> void for icons


func _init(p_label: String = "", p_min_size: Vector2 = Vector2(75, 23)) -> void:
	label = p_label
	custom_minimum_size = p_min_size
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, empty)


func _draw() -> void:
	var mode := get_draw_mode()
	var pressed := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var rect := Rect2(Vector2.ZERO, size)
	if bold_border:
		draw_rect(rect, Win98.BLACK)
		rect = rect.grow(-1)
	Win98.draw_bevel(self, rect, pressed)
	var off := Vector2(1, 1) if pressed else Vector2.ZERO
	if label != "":
		var ts := Win98.text_size(label, font_size)
		var pos := Vector2(floorf((size.x - ts.x) * 0.5), floorf((size.y - ts.y) * 0.5)) + off
		if disabled:
			Win98.draw_text(self, pos + Vector2(1, 1), label, Win98.WHITE, font_size)
			Win98.draw_text(self, pos, label, Win98.GRAY_DARK, font_size)
		else:
			Win98.draw_text(self, pos, label, Win98.BLACK, font_size)
	if extra_draw.is_valid():
		extra_draw.call(self, off)

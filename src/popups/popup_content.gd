class_name PopupContent
extends VBoxContainer
## Base for the body of a pop-up. Subclasses build their UI in `build()` and
## emit `completed` when the player did what the window asked, or `misclick`
## when they fell for a trap (the desktop decides the punishment).

signal completed
signal misclick(kind: String)

var popup: WindowFrame
var rng: RandomNumberGenerator
var run: RunState   ## read-only access to modifiers (consent manager etc.)


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS


func build() -> void:
	pass


func make_label(text: String, font_size: int = Win98.FONT_SIZE, color: Color = Win98.BLACK, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func make_button(text: String, min_size: Vector2 = Vector2(90, 23)) -> Win98Button:
	var b := Win98Button.new(text, min_size)
	return b


func make_row(alignment: int = BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = alignment
	h.add_theme_constant_override("separation", 8)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(h)
	return h


func make_spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func make_link(text: String, font_size: int = 10) -> LinkButton:
	var lb := LinkButton.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.focus_mode = Control.FOCUS_NONE
	return lb


func make_check(text: String, checked: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = checked
	cb.focus_mode = Control.FOCUS_NONE
	return cb

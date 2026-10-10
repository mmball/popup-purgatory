class_name Win98
extends RefCounted
## Palette, theme, and the bevel drawing primitives that make everything look
## like 1998. All chrome is drawn procedurally; there are no image assets.

const DESKTOP := Color("008080")
const GRAY := Color("c0c0c0")
const GRAY_DARK := Color("808080")
const GRAY_LIGHT := Color("dfdfdf")
const WHITE := Color.WHITE
const BLACK := Color.BLACK
const TITLE_A := Color("000080")
const TITLE_B := Color("1084d0")
const TITLE_INACTIVE_A := Color("808080")
const TITLE_INACTIVE_B := Color("b5b5b5")
const BSOD_BLUE := Color("0000aa")
const LINK := Color("0000ff")
const SELECT := Color("000080")
const FONT_SIZE := 13

static var _title_gradient: GradientTexture2D
static var _inactive_gradient: GradientTexture2D


static func font() -> Font:
	return ThemeDB.fallback_font


## Draws a raised (or sunken) 3D panel in the classic two-tone bevel.
static func draw_bevel(ci: CanvasItem, rect: Rect2, sunken: bool = false, fill: Color = GRAY) -> void:
	var outer_tl := GRAY_DARK if sunken else WHITE
	var outer_br := WHITE if sunken else BLACK
	var inner_tl := BLACK if sunken else GRAY_LIGHT
	var inner_br := GRAY_LIGHT if sunken else GRAY_DARK
	ci.draw_rect(rect, fill)
	_edge(ci, rect, 0, outer_tl, outer_br)
	_edge(ci, rect.grow(-1), 0, inner_tl, inner_br)


## Draws a 1px two-tone frame (used for separators, field borders).
static func draw_field_border(ci: CanvasItem, rect: Rect2) -> void:
	_edge(ci, rect, 0, GRAY_DARK, WHITE)
	_edge(ci, rect.grow(-1), 0, BLACK, GRAY_LIGHT)


static func _edge(ci: CanvasItem, rect: Rect2, _unused: int, tl: Color, br: Color) -> void:
	var p := rect.position
	var s := rect.size
	ci.draw_rect(Rect2(p, Vector2(s.x, 1)), tl)                       # top
	ci.draw_rect(Rect2(p, Vector2(1, s.y)), tl)                       # left
	ci.draw_rect(Rect2(p + Vector2(0, s.y - 1), Vector2(s.x, 1)), br)  # bottom
	ci.draw_rect(Rect2(p + Vector2(s.x - 1, 0), Vector2(1, s.y)), br)  # right


static func title_gradient(active: bool = true) -> GradientTexture2D:
	if active:
		if _title_gradient == null:
			_title_gradient = _make_gradient(TITLE_A, TITLE_B)
		return _title_gradient
	if _inactive_gradient == null:
		_inactive_gradient = _make_gradient(TITLE_INACTIVE_A, TITLE_INACTIVE_B)
	return _inactive_gradient


static func _make_gradient(a: Color, b: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 1
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	return tex


## Draws text with its top-left corner at `pos` (draw_string wants a baseline).
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, color: Color = BLACK, size: int = FONT_SIZE, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font()
	ci.draw_string(f, pos + Vector2(0, f.get_ascent(size)), text, align, width, size, color)


static func text_size(text: String, size: int = FONT_SIZE) -> Vector2:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


## Theme applied at the root so stock controls (Label, CheckBox, LineEdit,
## ProgressBar, LinkButton) pick up the palette.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE

	t.set_color("font_color", "Label", BLACK)

	for cls in ["CheckBox", "CheckButton", "Button"]:
		t.set_color("font_color", cls, BLACK)
		t.set_color("font_hover_color", cls, BLACK)
		t.set_color("font_pressed_color", cls, BLACK)
		t.set_color("font_hover_pressed_color", cls, BLACK)
		t.set_color("font_focus_color", cls, BLACK)
		t.set_color("font_disabled_color", cls, GRAY_DARK)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			t.set_stylebox(st, cls, empty)

	t.set_color("font_color", "LinkButton", LINK)
	t.set_color("font_hover_color", "LinkButton", Color("8000ff"))
	t.set_color("font_pressed_color", "LinkButton", Color("ff0000"))
	t.set_color("font_focus_color", "LinkButton", LINK)
	t.set_stylebox("focus", "LinkButton", StyleBoxEmpty.new())

	var field := StyleBoxFlat.new()
	field.bg_color = WHITE
	field.border_color = GRAY_DARK
	field.set_border_width_all(1)
	field.border_width_left = 2
	field.border_width_top = 2
	field.content_margin_left = 4
	field.content_margin_right = 4
	field.content_margin_top = 2
	field.content_margin_bottom = 2
	t.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate()
	field_focus.border_color = BLACK
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", BLACK)
	t.set_color("font_placeholder_color", "LineEdit", GRAY_DARK)
	t.set_color("caret_color", "LineEdit", BLACK)
	t.set_color("selection_color", "LineEdit", Color(SELECT, 0.6))

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = WHITE
	bar_bg.border_color = GRAY_DARK
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = TITLE_A
	bar_fill.content_margin_left = 2
	bar_fill.content_margin_right = 2
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", BLACK)

	var panel := StyleBoxFlat.new()
	panel.bg_color = GRAY
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	return t

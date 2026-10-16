class_name TaskManager
extends WindowFrame
## Ctrl+Shift+Esc. Lists the open pop-ups, biggest RAM first; End Task closes
## the selected one instantly (locked X or not) for its dismiss reward, a few
## times per use. Imps keep working while it is open.

signal end_task_requested(popup: PopupBase)

const REFRESH_EVERY := 0.5

var ends_left := 0
var _layer: Control
var _list: ItemList
var _ends_label: Label
var _end_button: Win98Button
var _rows: Array[PopupBase] = []
var _refresh_t := 0.0


func _init(layer: Control, ends: int) -> void:
	super()
	_layer = layer
	ends_left = ends
	window_title = "Windows Task Manager"
	icon_color = Color("2f7fc9")
	set_window_size(Vector2(380, 270))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	content.add_child(box)
	var head := Label.new()
	head.text = "Applications: not responding"
	head.add_theme_font_size_override("font_size", 12)
	box.add_child(head)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 150)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 12)
	_list.focus_mode = Control.FOCUS_NONE
	# Win98 list box: white sunken field, black text, navy selection bar.
	var field := StyleBoxFlat.new()
	field.bg_color = Win98.WHITE
	field.border_color = Win98.GRAY_DARK
	field.set_border_width_all(1)
	field.set_content_margin_all(3)
	_list.add_theme_stylebox_override("panel", field)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Win98.SELECT
	_list.add_theme_stylebox_override("selected", sel)
	_list.add_theme_stylebox_override("selected_focus", sel)
	_list.add_theme_stylebox_override("hovered", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("hovered_selected", sel)
	_list.add_theme_stylebox_override("hovered_selected_focus", sel)
	_list.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	_list.add_theme_color_override("font_color", Win98.BLACK)
	_list.add_theme_color_override("font_hovered_color", Win98.BLACK)
	_list.add_theme_color_override("font_selected_color", Win98.WHITE)
	_list.add_theme_color_override("font_hovered_selected_color", Win98.WHITE)
	box.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_ends_label = Label.new()
	_ends_label.add_theme_font_size_override("font_size", 12)
	_ends_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ends_label)
	_end_button = Win98Button.new("End Task")
	_end_button.bold_border = true
	_end_button.pressed.connect(end_selected)
	row.add_child(_end_button)
	var close := Win98Button.new("Close")
	close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close)
	refresh()


func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t >= REFRESH_EVERY:
		_refresh_t = 0.0
		refresh()


## Rebuilds the rows from the pop-up layer, keeping the selection on the same
## window when it still exists, else on the first (biggest) row.
func refresh() -> void:
	var sel := _list.get_selected_items()
	var keep: PopupBase = _rows[sel[0]] if sel.size() > 0 and sel[0] < _rows.size() else null
	_rows.clear()
	_list.clear()
	for c: Node in _layer.get_children():
		if c is PopupBase and not (c as PopupBase).is_closing:
			_rows.append(c)
	# Biggest RAM first, then oldest, then left-to-right: a total order, so the
	# default pick is the same on every seeded run.
	_rows.sort_custom(func(a: PopupBase, b: PopupBase) -> bool:
		if a.ram_cost != b.ram_cost:
			return a.ram_cost > b.ram_cost
		if a.total_age != b.total_age:
			return a.total_age > b.total_age
		return a.position.x < b.position.x)
	var select := 0
	for i in range(_rows.size()):
		var p := _rows[i]
		_list.add_item("%3d RAM   %5.1f s   %s" % [p.ram_cost, p.total_age, p.window_title])
		if p == keep:
			select = i
	if _rows.size() > 0:
		_list.select(select)
	_ends_label.text = "End Task uses left: %d" % ends_left
	_end_button.disabled = ends_left <= 0 or _rows.is_empty()


## Ends the selected window (the first row when nothing is selected).
func end_selected() -> void:
	if ends_left <= 0:
		return
	var sel := _list.get_selected_items()
	var idx := sel[0] if sel.size() > 0 else 0
	if idx >= _rows.size():
		return
	var p := _rows[idx]
	if not is_instance_valid(p) or p.is_closing:
		refresh()
		return
	ends_left -= 1
	end_task_requested.emit(p)
	refresh()
	if ends_left <= 0:
		close_requested.emit()

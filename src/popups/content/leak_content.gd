extends PopupContent
## Memory leak. Its RAM cost grows every few seconds (handled by Desktop) until
## you run the three-step cleanup. Dismissing pays nothing: the leak just
## stops. It targets builds that stack RAM instead of closing windows.

var _steps := ["Locate leak", "Free handles", "Compact heap"]
var _done := 0
var _status: Label
var _button: Win98Button
var _bar: ProgressBar


func build() -> void:
	make_label("popups.exe is leaking memory. Its footprint grows every few seconds until cleaned up.", 12)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.max_value = _steps.size()
	add_child(_bar)
	_status = make_label("Step 1 of 3: " + _steps[0], 11)
	make_spacer()
	var row := make_row()
	_button = make_button(_steps[0], Vector2(130, 24))
	_button.bold_border = true
	_button.pressed.connect(_advance)
	row.add_child(_button)


func _advance() -> void:
	_done += 1
	_bar.value = _done
	if _done >= _steps.size():
		completed.emit()
		return
	_status.text = "Step %d of 3: %s" % [_done + 1, _steps[_done]]
	_button.label = _steps[_done]

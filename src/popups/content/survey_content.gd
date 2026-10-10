extends PopupContent
## Pick a rating, then submit.

var _submit: Win98Button
var _group := ButtonGroup.new()


func build() -> void:
	make_label("How would you rate your experience with Popup Purgatory 98?", 12)
	var row := make_row()
	for i in range(1, 6):
		var cb := make_check(str(i), false)
		cb.button_group = _group
		cb.toggled.connect(func(_on: bool) -> void: _submit.disabled = _group.get_pressed_button() == null)
		row.add_child(cb)
	make_label("1 = never again, 5 = would be interrupted again", 10, Win98.GRAY_DARK, true)
	make_spacer()
	var buttons := make_row()
	_submit = make_button("Submit")
	_submit.disabled = true
	_submit.bold_border = true
	_submit.pressed.connect(func() -> void:
		if _group.get_pressed_button() != null:
			completed.emit())
	buttons.add_child(_submit)

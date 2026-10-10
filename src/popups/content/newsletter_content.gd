extends PopupContent
## Three pre-checked boxes. Continue with any left checked and you get spam.

var _checks: Array[CheckBox] = []


func build() -> void:
	make_label("Join our newsletter! Just confirm your preferences:", 12)
	for label: String in ["Daily deals (hourly)", "Partner offers", "Share my address book"]:
		var cb := make_check(label, true)
		_checks.append(cb)
		add_child(cb)
	make_spacer()
	var row := make_row()
	var cont := make_button("Continue")
	cont.bold_border = true
	cont.pressed.connect(func() -> void:
		for cb: CheckBox in _checks:
			if cb.button_pressed:
				misclick.emit("subscribed")
				break
		completed.emit())
	row.add_child(cont)

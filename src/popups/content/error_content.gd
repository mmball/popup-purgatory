extends PopupContent
## A plain error box. Cheap to complete; multiplies if ignored.

const CODES := ["0x0000F00D", "0xC0FFEE", "0xBADF00D", "0xDEADBEEF", "0x0E_0028:C0011E36"]


func build() -> void:
	var row := make_row(BoxContainer.ALIGNMENT_BEGIN)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.draw.connect(func() -> void:
		icon.draw_circle(Vector2(16, 16), 15, Color("d00000"))
		icon.draw_line(Vector2(9, 9), Vector2(23, 23), Color.WHITE, 3.0)
		icon.draw_line(Vector2(9, 23), Vector2(23, 9), Color.WHITE, 3.0))
	row.add_child(icon)
	var code: String = CODES[rng.randi_range(0, CODES.size() - 1)]
	var l := Label.new()
	l.text = "This program has performed an illegal operation and will be shut down.\n\nError %s" % code
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	make_spacer()
	var buttons := make_row()
	var ok := make_button("OK")
	ok.bold_border = true
	ok.pressed.connect(func() -> void: completed.emit())
	buttons.add_child(ok)

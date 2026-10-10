class_name ConfirmDialog
extends WindowFrame
## Yes/No question in a small window.

signal answered(yes: bool)


func _init(title: String = "Confirm", message: String = "Are you sure?") -> void:
	super()
	window_title = title
	set_window_size(Vector2(330, 130))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	content.add_child(box)
	var l := Label.new()
	l.text = message
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var yes := Win98Button.new("Yes")
	yes.bold_border = true
	yes.pressed.connect(func() -> void: answered.emit(true))
	row.add_child(yes)
	var no := Win98Button.new("No")
	no.pressed.connect(func() -> void: answered.emit(false))
	row.add_child(no)
	close_requested.connect(func() -> void: answered.emit(false))

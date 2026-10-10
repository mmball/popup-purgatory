extends PopupContent
## "Install now" ties up the window for a few seconds; "Remind me later" brings
## it straight back.

const INSTALL_TIME := 3.0

var _bar: ProgressBar
var _installing := false
var _progress := 0.0
var _status: Label


func build() -> void:
	make_label("A new version of Popup Purgatory is available (v98.1).", 12)
	_status = make_label("Install now? Your work will be saved. Probably.", 12)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.visible = false
	add_child(_bar)
	make_spacer()
	var row := make_row()
	var install := make_button("Install")
	install.bold_border = true
	install.pressed.connect(func() -> void:
		_installing = true
		_bar.visible = true
		_status.text = "Installing..."
		row.visible = false)
	row.add_child(install)
	var later := make_button("Remind me later", Vector2(110, 23))
	later.pressed.connect(func() -> void: misclick.emit("remind"))
	row.add_child(later)


func _process(delta: float) -> void:
	if not _installing:
		return
	_progress += delta / INSTALL_TIME
	_bar.value = _progress * 100.0
	if _progress >= 1.0:
		_installing = false
		completed.emit()

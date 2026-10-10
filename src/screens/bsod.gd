class_name BsodScreen
extends Control
## The run summary, as a blue screen of death.

const ACCEPT_DELAY := 0.8

var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _t >= ACCEPT_DELAY and event is InputEventMouseButton and event.pressed:
		Game.go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _t >= ACCEPT_DELAY and event is InputEventKey and event.pressed:
		Game.go_to_menu()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Win98.BSOD_BLUE)
	var run: RunState = Game.last_run
	var lines: Array[String] = []
	var shutdown := run != null and run.crash_reason == "SHUTDOWN"
	if shutdown:
		lines.append("It is now safe to turn off your computer.")
		lines.append("")
		lines.append("(You shut the machine down yourself. The pop-ups will remember.)")
	else:
		lines.append("A fatal exception 0E has occurred at 0028:C0011E36 in VXD POPUPS(01) + 00010E36.")
		lines.append("The current run will be terminated.")
		lines.append("")
		lines.append("* System resources exhausted: too many windows were open for too long.")
	lines.append("")
	if run != null:
		lines.append("  Wave reached ........ %d" % run.wave)
		lines.append("  Bytes earned ........ %d" % run.score)
		lines.append("  Pop-ups closed ...... %d  (%d completed, %d dismissed)" % [run.popups_closed, run.popups_completed, run.popups_closed - run.popups_completed])
		lines.append("  Closed by you ....... %d" % run.player_closes)
		lines.append("  Closed by imps ...... %d" % run.imp_closes)
		lines.append("  Imps hired .......... %d" % run.imps_hired)
		lines.append("  Buildings built ..... %d" % run.buildings_built)
		lines.append("  Time at the desk .... %d:%02d" % [int(run.elapsed) / 60, int(run.elapsed) % 60])
		var meta: MetaSave = Game.meta
		if meta != null and run.score > 0 and run.score >= meta.high_score:
			lines.append("")
			lines.append("  NEW HIGH SCORE")
	lines.append("")
	lines.append("Press any key to continue" + (" _" if fmod(_t, 1.0) < 0.5 else ""))

	var y := 120.0
	var cx := size.x * 0.5
	var ts := Win98.text_size(" POPUP PURGATORY ", 16)
	draw_rect(Rect2(cx - ts.x * 0.5, y - 2, ts.x, ts.y + 4), Win98.GRAY)
	Win98.draw_text(self, Vector2(cx - ts.x * 0.5, y), " POPUP PURGATORY ", Win98.BSOD_BLUE, 16)
	y += 50
	for line in lines:
		Win98.draw_text(self, Vector2(160, y), line, Win98.WHITE, 15)
		y += 24

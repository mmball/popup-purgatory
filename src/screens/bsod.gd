class_name BsodScreen
extends Control
## The run summary, as a blue screen of death.

const ACCEPT_DELAY := 0.8
const TYPE_SPEED := 180.0  ## characters per second when the screen types itself out

var _t := 0.0
var _typed := 0.0
var _last_tick := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var run: RunState = Game.last_run
	if run != null and run.won and run.crash_reason == "CLOCKED_OUT":
		Sfx.play("shutdown", 1.0, 0.0, 0.0)


func _process(delta: float) -> void:
	_t += delta
	_typed += delta * (TYPE_SPEED if Juice.enabled else 100000.0)
	var tick := int(_typed / 40.0)
	if Juice.enabled and tick != _last_tick and _typed < 2000.0:
		_last_tick = tick
		Sfx.play("typewriter", 1.0, -10.0, 0.2)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _t >= ACCEPT_DELAY and event is InputEventMouseButton and event.pressed:
		Game.go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _t >= ACCEPT_DELAY and event is InputEventKey and event.pressed:
		Game.go_to_menu()


func _draw() -> void:
	var run: RunState = Game.last_run
	var won := run != null and run.won and run.crash_reason == "CLOCKED_OUT"
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK if won else Win98.BSOD_BLUE)
	var fg := Color("ffa500") if won else Win98.WHITE
	var lines: Array[String] = []
	var shutdown := run != null and run.crash_reason == "SHUTDOWN"
	if won:
		lines.append("It's now safe to turn off your computer.")
		lines.append("")
		lines.append("You clocked out at 5:00 PM on Service Pack %d. The pop-ups will be back tomorrow." % run.tier)
		if run.tier < Ladder.max_tier():
			lines.append("Service Pack %d is now available from the main menu." % (run.tier + 1))
	elif shutdown:
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
		lines.append("  Best streak ......... %d" % run.best_streak)
		if run.overtime:
			lines.append("  Banked at 5 PM ...... %d  (+%d in overtime, half counts: %d)" % [run.banked_score, run.score - run.banked_score, run.final_score()])
		lines.append("  Time at the desk .... %d:%02d" % [int(run.elapsed) / 60, int(run.elapsed) % 60])
		lines.append("  Run seed ............ %d" % run.seed)
		var meta: MetaSave = Game.meta
		if meta != null and run.final_score() > 0 and run.final_score() >= meta.high_score:
			lines.append("")
			lines.append("  NEW HIGH SCORE")
		for a: String in Game.last_earned:
			var ach: Dictionary = MetaSave.ACHIEVEMENTS[a]
			lines.append("")
			lines.append("  UNLOCKED: %s. Added to the pool: %s" % [ach["name"], ach["adds"]])
	lines.append("")
	lines.append("Press any key to continue" + (" _" if fmod(_t, 1.0) < 0.5 else ""))

	var y := 120.0
	var cx := size.x * 0.5
	var title := " POPUP PURGATORY " if not won else " CLOCKED OUT "
	var ts := Win98.text_size(title, 16)
	if won:
		Win98.draw_text(self, Vector2(cx - ts.x * 0.5, y), title, fg, 16)
	else:
		draw_rect(Rect2(cx - ts.x * 0.5, y - 2, ts.x, ts.y + 4), Win98.GRAY)
		Win98.draw_text(self, Vector2(cx - ts.x * 0.5, y), title, Win98.BSOD_BLUE, 16)
	y += 50
	var budget := int(_typed)
	for line: String in lines:
		if budget <= 0:
			break
		var shown := line.substr(0, mini(line.length(), budget))
		budget -= line.length() + 1
		Win98.draw_text(self, Vector2(160, y), shown, fg, 15)
		y += 24

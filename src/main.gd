extends Control
## Root node. Swaps screens on request and hosts the screenshot dev tool.

var current: Node


func _ready() -> void:
	theme = Win98.build_theme()
	Game.screen_requested.connect(show_screen)
	var dev: Dictionary = Game.dev
	match str(dev.get("screen", "menu")):
		"desktop":
			Game.start_run()
		"bsod":
			Game.last_run = RunState.new()
			Game.last_run.crash_reason = "OUT_OF_MEMORY"
			show_screen("bsod")
		_:
			show_screen("menu")
	if dev.has("autoplay"):
		add_child(Autoplay.new())
	if dev.has("screenshot"):
		_schedule_screenshots(str(dev["screenshot"]), float(dev.get("delay", "2.0")), int(dev.get("shots", "1")))


func show_screen(id: String) -> void:
	if current != null:
		current.queue_free()
		current = null
	match id:
		"menu":
			current = MainMenu.new()
		"desktop":
			current = Desktop.new()
		"bsod":
			current = BsodScreen.new()
		_:
			push_error("Unknown screen: " + id)
			return
	add_child(current)


## Saves `shots` screenshots, `delay` seconds apart, then quits. With more than
## one shot the index is inserted before the extension (desk_1.png, desk_2.png).
func _schedule_screenshots(path: String, delay: float, shots: int) -> void:
	for i in range(shots):
		await get_tree().create_timer(delay).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var out := path
		if shots > 1:
			out = "%s_%d.%s" % [path.get_basename(), i + 1, path.get_extension()]
		var err := img.save_png(out)
		print("screenshot: %s (%s)" % [out, error_string(err)])
	get_tree().quit()

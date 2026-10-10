extends SceneTree
## Pixel comparison for screenshot regression, no external dependencies.
## Usage: godot --headless -s tools/compare_images.gd -- <actual.png> <baseline.png> [tolerance_pct] [diff_out.png]
## Prints "diff=<pct>" and exits 0 when the mismatching-pixel share is within tolerance.

const CHANNEL_TOLERANCE := 8  ## per-channel 0-255 slack before a pixel counts as different


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: compare_images.gd -- actual.png baseline.png [tolerance_pct] [diff.png]")
		quit(2)
		return
	var tolerance := float(args[2]) if args.size() > 2 else 2.0
	var diff_path := args[3] if args.size() > 3 else ""
	var a := Image.load_from_file(args[0])
	var b := Image.load_from_file(args[1])
	if a == null or b == null:
		printerr("could not load %s or %s" % [args[0], args[1]])
		quit(2)
		return
	if a.get_size() != b.get_size():
		printerr("size mismatch: %s vs %s" % [a.get_size(), b.get_size()])
		quit(1)
		return
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var w := a.get_width()
	var h := a.get_height()
	var diff: Image = null
	if diff_path != "":
		diff = Image.create(w, h, false, Image.FORMAT_RGB8)
	var mismatched := 0
	for y in range(h):
		for x in range(w):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var same := absi(pa.r8 - pb.r8) <= CHANNEL_TOLERANCE and absi(pa.g8 - pb.g8) <= CHANNEL_TOLERANCE and absi(pa.b8 - pb.b8) <= CHANNEL_TOLERANCE
			if not same:
				mismatched += 1
			if diff != null:
				diff.set_pixel(x, y, Color(1, 0, 0) if not same else pb.darkened(0.6))
	var pct := 100.0 * float(mismatched) / float(w * h)
	print("diff=%.3f%% mismatched=%d of %d tolerance=%.2f%%" % [pct, mismatched, w * h, tolerance])
	if diff != null and pct > tolerance:
		diff.save_png(diff_path)
		print("diff image: " + diff_path)
	quit(0 if pct <= tolerance else 1)

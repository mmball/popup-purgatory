extends SceneTree
## Headless test runner: godot --headless --path . -s tests/run_tests.gd
## Discovers tests/test_*.gd, runs every test_* method, exits non-zero on failure.

const TEST_DIR := "res://tests/"


func _init() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR + file)
		if script == null:
			print("FAIL  %s: could not load" % file)
			failed += 1
			total += 1
			continue
		var inst: TestCase = script.new()
		for m: Dictionary in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			inst.failures.clear()
			inst.call(name)
			if inst.failures.is_empty():
				print("ok    %s::%s" % [file, name])
			else:
				failed += 1
				print("FAIL  %s::%s" % [file, name])
				for f: String in inst.failures:
					print("        - " + f)
	print("")
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)

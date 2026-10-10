extends SceneTree
## Headless test runner: godot --headless --path . -s tests/run_tests.gd [-- --junit=path.xml]
## Discovers tests/test_*.gd, runs every test_* method, exits non-zero on failure.
## With --junit=path it also writes a JUnit XML report for CI annotations.

const TEST_DIR := "res://tests/"

var _cases: Array[Dictionary] = []


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
			var t0 := Time.get_ticks_usec()
			inst.call(name)
			var secs := float(Time.get_ticks_usec() - t0) / 1_000_000.0
			_cases.append({"file": file, "name": name, "failures": inst.failures.duplicate(), "time": secs})
			if inst.failures.is_empty():
				print("ok    %s::%s" % [file, name])
			else:
				failed += 1
				print("FAIL  %s::%s" % [file, name])
				for f: String in inst.failures:
					print("        - " + f)
	print("")
	print("%d tests, %d failed" % [total, failed])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--junit="):
			_write_junit(arg.substr(8), total, failed)
	quit(1 if failed > 0 else 0)


func _write_junit(path: String, total: int, failed: int) -> void:
	var lines: Array[String] = []
	lines.append('<?xml version="1.0" encoding="UTF-8"?>')
	lines.append('<testsuite name="popup-purgatory" tests="%d" failures="%d">' % [total, failed])
	for c: Dictionary in _cases:
		var cls: String = str(c["file"]).get_basename()
		lines.append('  <testcase classname="%s" name="%s" time="%.4f">' % [cls, c["name"], c["time"]])
		for f: String in c["failures"]:
			lines.append('    <failure message="%s"/>' % f.xml_escape(true))
		lines.append('  </testcase>')
	lines.append('</testsuite>')
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		push_warning("could not write JUnit report to " + path)
		return
	fa.store_string("\n".join(lines) + "\n")
	fa.close()
	print("junit: " + path)

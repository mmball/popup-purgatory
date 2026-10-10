extends TestCase


func test_rows_accumulate_with_sequence_and_fields() -> void:
	var t := Telemetry.new()
	t.event("run_start", 0.0, 1, {"seed": 5})
	t.event("popup_closed", 3.456, 1, {"type": "ad", "completed": true})
	t.event("popup_closed", 4.0, 1, {"type": "error", "completed": false})
	assert_eq(t.rows.size(), 3, "three rows")
	assert_eq(t.rows[0]["seq"], 0, "seq starts at 0")
	assert_eq(t.rows[2]["seq"], 2, "seq increments")
	assert_near(t.rows[1]["t"], 3.46, 0.001, "time snapped to 0.01")
	assert_eq(t.rows[1]["type"], "ad", "fields merged")
	assert_eq(t.count("popup_closed"), 2, "count by name")
	assert_eq(t.of("run_start")[0]["seed"], 5, "filter by name")


func test_sink_writes_jsonl() -> void:
	var path := "user://test_telemetry_%d.jsonl" % Time.get_ticks_usec()
	var t := Telemetry.new()
	assert_true(t.open_sink(path), "opened")
	t.event("a", 1.0, 1, {"x": 1})
	t.event("b", 2.0, 2)
	t.close()
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "file exists")
	var lines: Array[String] = []
	while not f.eof_reached():
		var l := f.get_line()
		if l != "":
			lines.append(l)
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(lines.size(), 2, "two lines")
	var parsed: Variant = JSON.parse_string(lines[0])
	assert_true(parsed is Dictionary, "valid json")
	assert_eq(parsed["ev"], "a", "event name round-trips")
	assert_eq(int(parsed["x"]), 1, "field round-trips")

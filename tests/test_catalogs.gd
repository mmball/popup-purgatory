extends TestCase


func test_building_costs_grow() -> void:
	for id: String in BuildingCatalog.DEFS.keys():
		assert_eq(BuildingCatalog.cost(id, 0), int(BuildingCatalog.DEFS[id]["cost"]), id + " base cost")
		assert_gt(BuildingCatalog.cost(id, 1), BuildingCatalog.cost(id, 0), id + " grows")
		assert_gt(BuildingCatalog.max_count(id), 0, id + " max")
	assert_eq(BuildingCatalog.ORDER.size(), BuildingCatalog.DEFS.size(), "every building is in the menu order")
	for id: String in BuildingCatalog.ORDER:
		assert_true(BuildingCatalog.DEFS.has(id), "ordered id exists: " + id)


func test_upgrade_roll_is_distinct_and_respects_max() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var run := RunState.new()
	for i in range(50):
		var picks := UpgradeCatalog.roll(rng, run, 3)
		assert_eq(picks.size(), 3, "three picks")
		var ids := {}
		for p: Dictionary in picks:
			ids[p["id"]] = true
		assert_eq(ids.size(), 3, "distinct picks")
	UpgradeCatalog.apply("antivirus_patch", run)
	assert_false("antivirus_patch" in UpgradeCatalog.eligible(run), "max 1 respected")
	assert_false(run.timeouts_multiply, "antivirus applied")


func test_upgrade_effects() -> void:
	var run := RunState.new()
	var ram := run.ram_max
	UpgradeCatalog.apply("more_ram", run)
	assert_eq(run.ram_max, ram + 24, "ram")
	assert_eq(UpgradeCatalog.apply("free_imp", run), "spawn_imp", "imp effect tag")
	assert_eq(UpgradeCatalog.apply("bigger_x", run), "resize_x", "x effect tag")
	assert_eq(run.close_button_size, RunState.BASE_CLOSE_BUTTON + 8, "x size")
	UpgradeCatalog.apply("bytes_now", run)
	assert_eq(run.bytes, 40, "bytes now")
	UpgradeCatalog.apply("quick_hands", run)
	assert_lt(run.imp_work_mult, 1.0, "work faster")


func test_meta_save_round_trip() -> void:
	var m := MetaSave.new()
	var run := RunState.new()
	run.add_bytes(120)
	run.wave = 4
	m.record_run(run)
	assert_eq(m.high_score, 120, "high score")
	assert_eq(m.bank, 120, "bank")
	assert_true(m.can_buy("starter_hut"), "affordable")
	assert_true(m.buy("starter_hut"), "bought")
	assert_false(m.buy("starter_hut"), "no double buy")
	assert_eq(m.bank, 60, "bank after buy")
	var path := "user://test_meta_roundtrip.json"
	assert_true(m.save_to_disk(path), "saved")
	var m2 := MetaSave.new()
	assert_true(m2.load_from_disk(path), "loaded")
	assert_eq(m2.to_dict(), m.to_dict(), "round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var fresh := RunState.new()
	m2.apply_to_run(fresh)
	assert_eq(fresh.starting_buildings, ["hut"] as Array[String], "perk applied")

extends TestCase


func test_defaults_unchanged_without_overrides() -> void:
	Tuning.clear()
	assert_eq(RunState.new().ram_max, RunState.BASE_RAM, "base ram")
	assert_eq(BuildingCatalog.cost("hut", 0), 20, "hut cost")
	assert_eq(PopupCatalog.get_def("ad")["ram_cost"], 8, "ad ram")
	assert_near(SpawnSchedule.base_interval(1), SpawnSchedule.FIRST_WAVE_INTERVAL, 0.0001, "interval")


func test_overrides_apply_and_clear() -> void:
	Tuning.load_from_string("run.base_ram=150, building.hut.cost=10,popup.ad.ram_cost=3,spawn.first_interval=5,building.cost_growth=0")
	assert_eq(RunState.new().ram_max, 150, "ram override")
	assert_eq(BuildingCatalog.cost("hut", 0), 10, "hut override")
	assert_eq(BuildingCatalog.cost("hut", 3), 10, "growth override")
	assert_eq(PopupCatalog.get_def("ad")["ram_cost"], 3, "popup override")
	assert_near(SpawnSchedule.base_interval(1), 5.0, 0.0001, "spawn override")
	assert_eq(PopupCatalog.get_def("error")["ram_cost"], 6, "untouched type keeps default")
	Tuning.clear()
	assert_eq(RunState.new().ram_max, RunState.BASE_RAM, "cleared")


func test_malformed_overrides_are_ignored() -> void:
	Tuning.load_from_string("nonsense,run.base_ram=abc,=5")
	assert_eq(Tuning.overrides.size(), 0, "nothing accepted")
	Tuning.clear()

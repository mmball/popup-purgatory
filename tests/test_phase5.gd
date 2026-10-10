extends TestCase
## Workday structure, ladder, sideways unlocks.


func _fresh() -> RunState:
	Tuning.clear()
	return RunState.new()


func test_workday_is_eight_waves_of_about_ten_minutes() -> void:
	var total := 0.0
	for w in range(1, RunState.WORKDAY_WAVES + 1):
		total += RunState.wave_duration(w)
	assert_ge(total, 480.0, "at least 8 minutes of play")
	assert_le(total, 720.0, "at most 12 minutes of play")
	var run := _fresh()
	run.start_wave(RunState.WORKDAY_WAVES)
	assert_false(run.workday_over(), "not over at the start of the last hour")
	run.tick(RunState.wave_duration(RunState.WORKDAY_WAVES) + 1.0)
	assert_true(run.workday_over(), "over when the last hour ends")
	run.begin_break()
	run.clock_out()
	assert_true(run.won, "won")
	run.start_overtime()
	assert_true(run.overtime, "overtime")
	assert_eq(run.wave, RunState.WORKDAY_WAVES + 1, "overtime continues the waves")
	assert_false(run.workday_over(), "overtime never 'ends the day' again")


func test_clock_runs_nine_to_five() -> void:
	var run := _fresh()
	run.start_wave(1)
	assert_eq(run.clock()["hour"], 9, "starts at 9")
	run.tick(RunState.wave_duration(1) * 0.5)
	assert_ge(run.clock()["minute"], 28, "about half past")
	assert_le(run.clock()["minute"], 31, "about half past")
	run.start_wave(RunState.WORKDAY_WAVES)
	assert_eq(run.clock()["hour"], 16, "last hour is 4 PM")


func test_ladder_stacks_modifiers() -> void:
	var r0 := _fresh()
	Ladder.apply(0, r0)
	assert_eq(r0.ram_max, RunState.BASE_RAM, "tier 0 untouched")
	var r2 := _fresh()
	Ladder.apply(2, r2)
	assert_lt(r2.interval_mult, 1.0, "SP1 faster spawns carried into SP2")
	assert_eq(r2.ram_max, RunState.BASE_RAM - 20, "SP2 less RAM")
	var r6 := _fresh()
	Ladder.apply(6, r6)
	assert_eq(r6.timeout_multiplier, 2, "SP3 double multiply")
	assert_near(r6.building_cost_mult, 1.25, 0.0001, "SP4 cost")
	assert_near(r6.overload_grace(), 2.0, 0.0001, "SP6 grace")
	assert_eq(r6.tier, 6, "tier recorded")
	assert_eq(BuildingCatalog.cost("hut", 0, r6.building_cost_mult), 25, "cost multiplier applies")


func test_unlocked_content_is_gated() -> void:
	var base := PopupCatalog.available_on_wave(10)
	assert_false("cookie" in base, "cookie needs an achievement")
	assert_false("chat" in base, "chat needs an achievement")
	assert_false("leak" in base, "leak needs an achievement")
	assert_true("virus" in base, "base types stay")
	var pool := PopupCatalog.available_on_wave(10, ["clock_out", "hundred_closed", "dojo_built"] as Array[String])
	assert_true("cookie" in pool and "chat" in pool and "leak" in pool, "all three unlocked")
	assert_eq(BuildingCatalog.available([]).size(), 7, "seven base buildings")
	assert_true("helpdesk" in BuildingCatalog.available(["hundred_closed"] as Array[String]), "help desk unlocks")
	var run := _fresh()
	assert_false("consent_manager" in UpgradeCatalog.eligible(run), "locked upgrade not offered")
	run.unlocked_upgrades = ["clock_out"]
	assert_true("consent_manager" in UpgradeCatalog.eligible(run), "unlocked upgrade offered")


func test_schedule_never_picks_locked_types() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var s := SpawnSchedule.new(rng)
	for i in range(500):
		var t := s.pick_type(8)
		assert_false(t in ["cookie", "chat", "leak"], "locked type picked: " + t)
	var seen := {}
	for i in range(2000):
		seen[s.pick_type(8, ["clock_out", "hundred_closed", "dojo_built"] as Array[String])] = true
	assert_true(seen.has("cookie") and seen.has("chat") and seen.has("leak"), "unlocked types appear")
	var muted := {}
	for i in range(2000):
		muted[s.pick_type(8, ["hundred_closed"] as Array[String], {"chat": 0.0})] = true
	assert_false(muted.has("chat"), "zero weight silences a type")


func test_meta_achievements_and_tiers() -> void:
	var m := MetaSave.new()
	var lost := _fresh()
	lost.popups_closed = 60
	assert_eq(m.record_run(lost), [] as Array[String], "nothing earned on a loss with 60 closes")
	assert_eq(m.max_tier_unlocked, 0, "no tier unlocked")
	var win := _fresh()
	win.popups_closed = 50
	win.buildings_list.append("dojo")
	win.won = true
	win.tier = 0
	var earned := m.record_run(win)
	assert_true("clock_out" in earned, "clock out earned")
	assert_true("hundred_closed" in earned, "100 closed across runs")
	assert_true("dojo_built" in earned, "dojo earned")
	assert_false("sp2_win" in earned, "SP2 win needs tier 2")
	assert_eq(m.max_tier_unlocked, 1, "SP1 unlocked by a win")
	assert_eq(m.wins, 1, "wins counted")
	var again := m.record_run(win)
	assert_eq(again, [] as Array[String], "achievements earn once")
	var fresh := _fresh()
	m.apply_to_run(fresh)
	assert_true("clock_out" in fresh.unlocked_popups, "pools carry the achievements")
	var d := m.to_dict()
	var m2 := MetaSave.new()
	m2.from_dict(d)
	assert_eq(m2.achievements, m.achievements, "achievements round-trip")
	assert_eq(m2.max_tier_unlocked, 1, "tier round-trips")


func test_new_popups_are_well_formed() -> void:
	for id: String in ["cookie", "chat", "leak"]:
		var d := PopupCatalog.get_def(id)
		assert_true(ResourceLoader.exists(str(d["content"])), id + " content exists")
		assert_gt(int(d["complete_reward"]), int(d["dismiss_reward"]), id + " completion pays more")
	assert_eq(int(PopupCatalog.get_def("leak")["dismiss_reward"]), 0, "leak pays nothing for X")
	assert_eq(int(PopupCatalog.get_def("cookie")["on_dismiss"]["count"]), 2, "cookie punishes X")
	assert_true(bool(PopupCatalog.get_def("chat")["imp_proof"]), "chat dodges imps")

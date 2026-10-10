extends TestCase


func test_rewards_prefer_completion() -> void:
	var run := RunState.new()
	for id: String in PopupCatalog.ids():
		var def := PopupCatalog.get_def(id)
		assert_gt(run.reward_for(def, true), run.reward_for(def, false), id)


func test_multipliers_round_and_floor_at_one() -> void:
	var run := RunState.new()
	var def := PopupCatalog.get_def("ad")
	run.dismiss_mult = 2.0
	assert_eq(run.reward_for(def, false), 2, "dismiss x2")
	run.complete_mult = 1.5
	assert_eq(run.reward_for(def, true), 6, "complete x1.5")
	run.dismiss_mult = 0.1
	assert_eq(run.reward_for(def, false), 1, "never below 1")


func test_bytes_and_score_diverge_on_spend() -> void:
	var run := RunState.new()
	run.add_bytes(50)
	assert_true(run.spend(30), "can spend")
	assert_false(run.spend(30), "cannot overspend")
	assert_eq(run.bytes, 20, "bytes")
	assert_eq(run.score, 50, "score unchanged by spending")


func test_ram_accounting() -> void:
	var run := RunState.new()
	var def := PopupCatalog.get_def("captcha")
	var cost := run.popup_cost(def)
	assert_eq(cost, 12, "base cost")
	run.ram_cost_reduction = 20
	assert_eq(run.popup_cost(def), 1, "cost floors at 1")
	run.popup_opened(cost)
	run.popup_opened(cost)
	assert_eq(run.ram_used, 24, "two open")
	run.popup_closed(cost, true, false)
	assert_eq(run.ram_used, 12, "one closed")
	assert_eq(run.popups_completed, 1, "completed count")
	assert_eq(run.player_closes, 1, "player close count")


func test_overload_crashes_after_grace() -> void:
	var run := RunState.new()
	run.start_wave(1)
	var crashes: Array[String] = []
	run.crashed.connect(func(r: String) -> void: crashes.append(r))
	run.popup_opened(run.ram_max + 1)
	run.tick(RunState.OVERLOAD_GRACE - 0.5)
	assert_true(run.overloaded, "overloaded flag")
	assert_false(run.crashed_flag, "not yet crashed")
	run.tick(1.0)
	assert_true(run.crashed_flag, "crashed after grace")
	assert_eq(crashes.size(), 1, "crash signal once")
	run.tick(5.0)
	assert_eq(crashes.size(), 1, "crash signal not repeated")


func test_overload_recovers_when_ram_freed() -> void:
	var run := RunState.new()
	run.start_wave(1)
	run.popup_opened(run.ram_max + 1)
	run.tick(1.0)
	run.popup_closed(run.ram_max + 1, false, false)
	run.tick(0.1)
	assert_false(run.overloaded, "recovered")
	assert_eq(run.overload_timer, 0.0, "timer reset")
	run.popup_opened(run.ram_max + 1)
	run.tick(RunState.OVERLOAD_GRACE - 0.1)
	assert_false(run.crashed_flag, "grace restarts from zero")


func test_wave_clock_and_break() -> void:
	var run := RunState.new()
	run.start_wave(1)
	assert_near(run.wave_time_left, RunState.wave_duration(1), 0.001, "duration")
	run.tick(RunState.wave_duration(1) + 1.0)
	assert_true(run.wave_finished(), "finished")
	run.begin_break()
	assert_false(run.wave_finished(), "not finished during break")
	run.popup_opened(run.ram_max * 2)
	run.tick(10.0)
	assert_false(run.crashed_flag, "no crash during break")
	run.end_break()
	assert_eq(run.wave, 2, "next wave")
	assert_false(run.in_break, "break over")
	assert_gt(RunState.wave_duration(5), RunState.wave_duration(1), "later waves longer")

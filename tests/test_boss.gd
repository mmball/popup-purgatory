extends TestCase
## Bosses (docs/FEATURES.md item 9): the Service Pack install holds the wave
## clock, pays on a win, and happens at noon and 4 PM only.


func _run() -> RunState:
	var run := RunState.new()
	run.seed = 1
	run.start_wave(1)
	return run


func test_boss_waves_are_noon_and_four() -> void:
	assert_true(RunState.is_boss_wave(4), "wave 4 is 12 PM")
	assert_true(RunState.is_boss_wave(8), "wave 8 is 4 PM")
	for w: int in [1, 2, 3, 5, 6, 7, 9, 10]:
		assert_false(RunState.is_boss_wave(w), "wave %d has no boss" % w)


func test_boss_holds_the_wave_clock_but_not_the_rest() -> void:
	var run := _run()
	run.use_ability("task_manager")
	var left := run.wave_time_left
	run.start_boss()
	assert_true(run.boss_active)
	run.tick(5.0)
	assert_eq(run.wave_time_left, left, "wave clock waits for the installer")
	assert_eq(run.ability_cooldown_left("task_manager"), 40.0, "cooldowns still tick")
	assert_eq(run.elapsed, 5.0, "elapsed still counts")
	run.ram_used = run.ram_max + 1
	run.tick(run.overload_grace() + 0.1)
	assert_true(run.crashed_flag, "an overload during the boss still crashes")


func test_winning_pays_and_resumes() -> void:
	var run := _run()
	run.start_boss()
	var reward := run.end_boss(true)
	assert_eq(reward, 60, "base reward")
	assert_eq(run.bytes, 60, "paid into bytes")
	assert_eq(run.score, 60, "and score")
	assert_eq(run.bosses_won, 1)
	assert_false(run.boss_active)
	var left := run.wave_time_left
	run.tick(1.0)
	assert_eq(run.wave_time_left, left - 1.0, "clock runs again")


func test_losing_pays_nothing() -> void:
	var run := _run()
	run.start_boss()
	assert_eq(run.end_boss(false), 0)
	assert_eq(run.bytes, 0)
	assert_eq(run.bosses_failed, 1)
	assert_true(run.summary().has("bosses_won"), "summary carries the tally")


func test_boss_reward_is_tunable() -> void:
	Tuning.load_from_string("boss.reward=100")
	var run := _run()
	run.start_boss()
	assert_eq(run.end_boss(true), 100, "Tuning boss.reward")
	Tuning.clear()

extends TestCase
## Streaks, overtime terms, imp experience, dojo slot accounting.


func test_streak_builds_caps_and_resets() -> void:
	Tuning.clear()
	var run := RunState.new()
	var def := PopupCatalog.get_def("survey")  # complete 5
	assert_eq(run.reward_for(def, true, true), 5, "no streak yet")
	for i in range(5):
		run.note_manual_close(true)
	assert_near(run.streak_mult(), 1.5, 0.0001, "capped at +50%")
	assert_eq(run.reward_for(def, true, true), 8, "5 * 1.5 rounded")
	run.note_manual_close(true)
	assert_near(run.streak_mult(), 1.5, 0.0001, "still capped")
	assert_eq(run.reward_for(def, true, false), 5, "imp completions get no streak")
	assert_eq(run.reward_for(def, false, true), 1, "manual dismiss gets no streak")
	run.note_manual_close(false)
	assert_eq(run.streak, 0, "X resets")
	assert_eq(run.best_streak, 6, "best remembered")


func test_overtime_pay_banking_and_spawn_step() -> void:
	Tuning.clear()
	var run := RunState.new()
	run.start_wave(RunState.WORKDAY_WAVES)
	run.add_bytes(100)
	run.begin_break()
	run.clock_out()
	assert_eq(run.banked_score, 100, "banked at 5 PM")
	run.start_overtime()
	assert_eq(run.overtime_hours(), 1, "first overtime hour")
	var def := PopupCatalog.get_def("error")  # complete 2
	assert_eq(run.reward_for(def, true), 3, "2 * 1.5")
	run.add_bytes(40)
	run.crash_reason = "OUT_OF_MEMORY"
	assert_eq(run.final_score(), 120, "banked + half of overtime earnings")
	run.crash_reason = "SHUTDOWN"
	assert_eq(run.final_score(), 140, "a voluntary shutdown keeps everything")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var a := SpawnSchedule.new(rng)
	rng.seed = 4
	var b := SpawnSchedule.new(rng)
	var x := a.next_interval(9, 1.0, 0)
	rng.seed = 4
	var y := b.next_interval(9, 1.0, 2)
	assert_near(y, x * 0.81, 0.0001, "two overtime hours tighten by 0.9^2")


func test_final_score_without_overtime_is_score() -> void:
	var run := RunState.new()
	run.add_bytes(55)
	run.crash_reason = "OUT_OF_MEMORY"
	assert_eq(run.final_score(), 55, "no overtime, no banking")
	var m := MetaSave.new()
	run.overtime = true
	run.banked_score = 40
	m.record_run(run)
	assert_eq(m.high_score, 47, "meta records the final score (40 + 15/2)")


func test_imp_experience() -> void:
	var imp := Imp.new()
	assert_near(imp.xp_mult(), 1.0, 0.0001, "rookie")
	imp.closes = 5
	assert_near(imp.xp_mult(), 1.1, 0.0001, "+2% per close")
	imp.closes = 40
	assert_near(imp.xp_mult(), 1.3, 0.0001, "capped at +30%")
	assert_true(imp.is_veteran(), "veteran at 10")
	imp.free()


func test_dojo_slots_and_trainee_choice() -> void:
	var dojo := Building.new("dojo")
	assert_true(dojo.has_free_slot(), "fresh dojo")
	dojo.graduates = Building.DOJO_SLOTS
	assert_false(dojo.has_free_slot(), "full dojo")
	dojo.graduates = 0
	var mgr := ImpManager.new()
	var near := Imp.new()
	near.position = Vector2(10, 0)
	var far := Imp.new()
	far.position = Vector2(500, 0)
	var trained := Imp.new()
	trained.position = Vector2(0, 0)
	trained.trained = true
	mgr.imps = [near, far, trained]
	assert_eq(mgr.pick_trainee(Vector2.ZERO), near, "nearest untrained idle imp")
	near.state = Imp.State.WORK
	assert_eq(mgr.pick_trainee(Vector2.ZERO), far, "working imps are skipped")
	far.state = Imp.State.TRAIN
	assert_eq(mgr.pick_trainee(Vector2.ZERO), null, "nobody left")
	for n: Node in [near, far, trained, dojo, mgr]:
		n.free()

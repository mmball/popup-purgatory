extends TestCase
## Abilities (docs/FEATURES.md item 5): cooldowns, the once-an-hour
## Ctrl+Alt+Del freeze and its reset, and the two upgrades that shape them.


func _run() -> RunState:
	var run := RunState.new()
	run.seed = 1
	run.start_wave(1)
	return run


func test_alt_f4_has_no_cooldown() -> void:
	var run := _run()
	assert_true(run.ability_ready("alt_f4"), "ready at start")
	assert_true(run.use_ability("alt_f4"))
	assert_true(run.ability_ready("alt_f4"), "still ready: no cooldown")
	assert_eq(int(run.abilities_used["alt_f4"]), 1, "counted")


func test_task_manager_cooldown_ticks_down_during_waves_only() -> void:
	var run := _run()
	assert_true(run.use_ability("task_manager"))
	assert_false(run.ability_ready("task_manager"), "on cooldown")
	assert_eq(run.ability_cooldown_left("task_manager"), 45.0, "full cooldown")
	assert_false(run.use_ability("task_manager"), "cannot double-use")
	run.tick(10.0)
	assert_eq(run.ability_cooldown_left("task_manager"), 35.0, "ticks with the wave clock")
	run.begin_break()
	run.tick(100.0)
	assert_eq(run.ability_cooldown_left("task_manager"), 35.0, "breaks do not tick cooldowns")
	assert_false(run.ability_ready("task_manager"), "nothing is ready in a break")
	run.end_break()
	run.tick(35.0)
	assert_true(run.ability_ready("task_manager"), "ready again")


func test_keyboard_shortcuts_shorten_the_cooldown() -> void:
	var run := _run()
	UpgradeCatalog.apply("keyboard_shortcuts", run)
	assert_eq(run.ability_cooldown("task_manager"), 33.75, "25% shorter")
	UpgradeCatalog.apply("keyboard_shortcuts", run)
	assert_true(absf(run.ability_cooldown("task_manager") - 25.3125) < 0.001, "stacks multiplicatively")
	assert_eq(run.ability_cooldown("alt_f4"), 0.0, "zero stays zero")


func test_admin_rights_raise_task_manager_ends() -> void:
	var run := _run()
	assert_eq(run.task_manager_ends, 3, "default three ends")
	UpgradeCatalog.apply("admin_rights", run)
	assert_eq(run.task_manager_ends, 5, "five with Admin Rights")


func test_ctrl_alt_del_once_per_hour_and_freezes_the_clock() -> void:
	var run := _run()
	var before := run.wave_time_left
	assert_true(run.use_ability("ctrl_alt_del"))
	assert_true(run.frozen, "frozen while held")
	assert_false(run.ability_ready("ctrl_alt_del"), "spent for this hour")
	run.tick(3.0)
	assert_eq(run.wave_time_left, before, "wave clock holds while frozen")
	assert_eq(run.freeze_time, 3.0, "hold time accumulates")
	assert_false(run.crashed_flag, "3 s is safe")
	run.end_freeze()
	assert_false(run.frozen)
	run.tick(1.0)
	assert_eq(run.wave_time_left, before - 1.0, "clock runs again")
	assert_false(run.ability_ready("ctrl_alt_del"), "still spent this hour")
	run.begin_break()
	run.end_break()
	assert_true(run.ability_ready("ctrl_alt_del"), "a new hour grants it again")


func test_holding_ctrl_alt_del_too_long_resets_the_machine() -> void:
	var run := _run()
	run.ram_used = run.ram_max + 10  # overloaded: the freeze must hold the overload timer too
	assert_true(run.use_ability("ctrl_alt_del"))
	run.tick(4.9)
	assert_false(run.crashed_flag, "4.9 s is still safe")
	assert_eq(run.overload_timer, 0.0, "overload timer holds during the freeze")
	run.tick(0.2)
	assert_true(run.crashed_flag, "past 5 s the box resets")
	assert_eq(run.crash_reason, "RESET")
	assert_false(run.frozen, "freeze ends with the crash")
	assert_true(run.summary()["abilities"].has("ctrl_alt_del"), "summary carries ability use")

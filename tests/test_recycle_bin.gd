extends TestCase
## Recycle Bin accounting on the pure RunState: capacity, RAM, no reward, emptying.


func test_capacity_and_room() -> void:
	Tuning.clear()
	var run := RunState.new()
	assert_eq(RunState.BIN_CAPACITY, 3, "three items")
	assert_eq(run.bin_items, 0, "starts empty")
	assert_true(run.bin_has_room(), "room when empty")
	for i in range(RunState.BIN_CAPACITY):
		assert_true(run.bin_has_room(), "room before item %d" % (i + 1))
		run.recycle_popup(1)
	assert_eq(run.bin_items, RunState.BIN_CAPACITY, "full")
	assert_false(run.bin_has_room(), "a fourth cannot be dropped")


func test_recycle_frees_ram_without_reward_or_close_count() -> void:
	Tuning.clear()
	var run := RunState.new()
	var def := PopupCatalog.get_def("cookie")
	var cost := run.popup_cost(def)
	run.popup_opened(cost)
	run.popup_opened(cost)
	run.add_bytes(10)
	run.note_manual_close(true)
	run.note_manual_close(true)
	var ram_before := run.ram_used
	run.recycle_popup(cost)
	assert_eq(run.ram_used, ram_before - cost, "RAM freed like a close")
	assert_eq(run.popups_recycled, 1, "counted as recycled")
	assert_eq(run.popups_closed, 0, "not closed")
	assert_eq(run.popups_completed, 0, "not completed")
	assert_eq(run.player_closes, 0, "not a player close")
	assert_eq(run.imp_closes, 0, "not an imp close")
	assert_eq(run.bytes, 10, "no bytes")
	assert_eq(run.score, 10, "no score")
	assert_eq(run.streak, 2, "streak untouched")
	run.recycle_popup(100)
	assert_eq(run.ram_used, 0, "RAM never goes negative")


func test_empty_bin_resets_items_but_keeps_the_tally() -> void:
	Tuning.clear()
	var run := RunState.new()
	run.recycle_popup(4)
	run.recycle_popup(4)
	run.empty_bin()
	assert_eq(run.bin_items, 0, "emptied")
	assert_eq(run.popups_recycled, 2, "tally survives emptying")
	assert_true(run.bin_has_room(), "room again")
	for i in range(RunState.BIN_CAPACITY):
		run.recycle_popup(1)
	assert_false(run.bin_has_room(), "fills again after emptying")


func test_summary_carries_bin_fields() -> void:
	Tuning.clear()
	var run := RunState.new()
	run.recycle_popup(2)
	var s := run.summary()
	assert_eq(s["bin_items"], 1, "bin_items in summary")
	assert_eq(s["popups_recycled"], 1, "popups_recycled in summary")
	assert_eq(s["closed"], 0, "closed untouched by recycling")

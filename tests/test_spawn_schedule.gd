extends TestCase


func _seeded(seed: int) -> SpawnSchedule:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return SpawnSchedule.new(rng)


func test_base_interval_shrinks_with_floor() -> void:
	var prev := INF
	for w in range(1, 30):
		var iv := SpawnSchedule.base_interval(w)
		assert_le(iv, prev, "wave %d not slower than wave %d" % [w, w - 1])
		assert_ge(iv, SpawnSchedule.MIN_INTERVAL, "floor")
		prev = iv
	assert_eq(SpawnSchedule.base_interval(50), SpawnSchedule.MIN_INTERVAL, "hits floor")


func test_interval_mult_slows_spawns() -> void:
	var a := _seeded(7)
	var b := _seeded(7)
	var x := a.next_interval(3, 1.0)
	var y := b.next_interval(3, 1.5)
	assert_near(y, x * 1.5, 0.0001, "same seed scales linearly")


func test_type_unlock_by_wave() -> void:
	var s := _seeded(1)
	for i in range(200):
		var t := s.pick_type(1)
		assert_le(int(PopupCatalog.DEFS[t]["min_wave"]), 1, "wave 1 picked locked type " + t)
	var seen := {}
	for i in range(2000):
		seen[s.pick_type(10)] = true
	assert_eq(seen.size(), PopupCatalog.DEFS.size(), "every type appears by wave 10")


func test_deterministic_with_seed() -> void:
	var a := _seeded(42)
	var b := _seeded(42)
	for i in range(20):
		assert_eq(a.pick_type(6), b.pick_type(6), "pick %d" % i)
		assert_near(a.next_interval(6), b.next_interval(6), 0.0, "interval %d" % i)


func test_catalog_is_well_formed() -> void:
	for id: String in PopupCatalog.ids():
		var d := PopupCatalog.get_def(id)
		assert_eq(d["id"], id, "id round-trip")
		assert_true(ResourceLoader.exists(str(d["content"])), "content script exists for " + id)
		var script: Variant = load(str(d["content"]))
		assert_true(script != null, "content script loads for " + id)
		assert_gt(int(d["ram_cost"]), 0, id + " ram cost")
		assert_gt(float(d["weight"]), 0.0, id + " weight")
		assert_true(d["size"] is Vector2, id + " size")
	assert_gt(PopupCatalog.available_on_wave(1).size(), 1, "wave 1 has variety")

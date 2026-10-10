extends TestCase


func _cands() -> Array:
	return [
		{"id": "a", "pos": Vector2(0, 0), "age": 0.0},
		{"id": "b", "pos": Vector2(100, 0), "age": 0.0},
		{"id": "c", "pos": Vector2(500, 0), "age": 30.0},
	]


func test_no_double_claims() -> void:
	var ta := TargetAssigner.new()
	var first: Variant = ta.claim(_cands(), "imp1", Vector2.ZERO)
	var second: Variant = ta.claim(_cands(), "imp2", Vector2.ZERO)
	var third: Variant = ta.claim(_cands(), "imp3", Vector2.ZERO)
	var fourth: Variant = ta.claim(_cands(), "imp4", Vector2.ZERO)
	assert_ne(first, second, "distinct 1/2")
	assert_ne(second, third, "distinct 2/3")
	assert_ne(first, third, "distinct 1/3")
	assert_eq(fourth, null, "nothing left")
	assert_eq(ta.claim_count(), 3, "three claims")


func test_prefers_old_over_near() -> void:
	var ta := TargetAssigner.new()
	assert_eq(ta.claim(_cands(), "imp1", Vector2.ZERO), "c", "old far popup wins")


func test_prefers_near_when_ages_equal() -> void:
	var ta := TargetAssigner.new()
	var cands := [
		{"id": "far", "pos": Vector2(900, 0), "age": 1.0},
		{"id": "near", "pos": Vector2(10, 0), "age": 1.0},
	]
	assert_eq(ta.claim(cands, "imp1", Vector2.ZERO), "near", "near wins")


func test_reclaim_by_same_claimant_is_allowed() -> void:
	var ta := TargetAssigner.new()
	var cands := [{"id": "only", "pos": Vector2.ZERO, "age": 0.0}]
	assert_eq(ta.claim(cands, "imp1", Vector2.ZERO), "only")
	assert_eq(ta.claim(cands, "imp1", Vector2.ZERO), "only", "same imp may re-claim")
	assert_eq(ta.claim(cands, "imp2", Vector2.ZERO), null, "other imp blocked")


func test_release() -> void:
	var ta := TargetAssigner.new()
	var cands := [{"id": "only", "pos": Vector2.ZERO, "age": 0.0}]
	ta.claim(cands, "imp1", Vector2.ZERO)
	ta.release_claimant("imp1")
	assert_false(ta.is_claimed("only"), "released by claimant")
	ta.claim(cands, "imp2", Vector2.ZERO)
	ta.release("only")
	assert_false(ta.is_claimed("only"), "released by target")
	assert_eq(ta.claimant_of("only"), null, "no claimant")

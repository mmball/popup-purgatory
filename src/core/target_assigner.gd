class_name TargetAssigner
extends RefCounted
## Hands pop-ups out to imps so no two imps chase the same window.
## Works on plain dictionaries ({id, pos, age}) so it can be tested without nodes.

const AGE_WEIGHT := 25.0      ## score per second of age (older pop-ups are more urgent)
const DISTANCE_WEIGHT := 0.5  ## score lost per pixel of distance

var _claims := {}   ## target id -> claimant id


## Pick the best unclaimed candidate for the claimant at `from`. Returns the
## candidate id, or null when nothing is available.
func claim(candidates: Array, claimant_id: Variant, from: Vector2) -> Variant:
	var best_id: Variant = null
	var best_score := -INF
	for c: Dictionary in candidates:
		var id: Variant = c["id"]
		if _claims.has(id) and _claims[id] != claimant_id:
			continue
		var pos: Vector2 = c["pos"]
		var age: float = float(c.get("age", 0.0))
		var score := age * AGE_WEIGHT - from.distance_to(pos) * DISTANCE_WEIGHT
		if score > best_score:
			best_score = score
			best_id = id
	if best_id != null:
		_claims[best_id] = claimant_id
	return best_id


func release(target_id: Variant) -> void:
	_claims.erase(target_id)


func release_claimant(claimant_id: Variant) -> void:
	for id: Variant in _claims.keys():
		if _claims[id] == claimant_id:
			_claims.erase(id)


func is_claimed(target_id: Variant) -> bool:
	return _claims.has(target_id)


func claimant_of(target_id: Variant) -> Variant:
	return _claims.get(target_id)


func claim_count() -> int:
	return _claims.size()

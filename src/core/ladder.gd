class_name Ladder
extends RefCounted
## Opt-in difficulty tiers ("Service Packs"). Tier 0 is the base game. Each tier
## stacks its modifier on top of all lower tiers. Winning a run on tier n
## unlocks tier n+1 (MetaSave tracks it).

const TIERS: Array[Dictionary] = [
	{"id": 0, "name": "Service Pack 0", "desc": "The game as shipped."},
	{"id": 1, "name": "Service Pack 1", "desc": "Pop-ups spawn 15% faster."},
	{"id": 2, "name": "Service Pack 2", "desc": "Start with 20 less RAM."},
	{"id": 3, "name": "Service Pack 3", "desc": "Timed-out pop-ups multiply twice."},
	{"id": 4, "name": "Service Pack 4", "desc": "Buildings cost 25% more."},
	{"id": 5, "name": "Service Pack 5", "desc": "Imps work 25% slower."},
	{"id": 6, "name": "Service Pack 6", "desc": "Crash grace is 2 seconds instead of 3."},
]


static func max_tier() -> int:
	return TIERS.size() - 1


static func get_def(tier: int) -> Dictionary:
	assert(tier >= 0 and tier <= max_tier(), "Unknown tier %d" % tier)
	return TIERS[tier]


## Applies every modifier from tier 1 up to `tier` to a fresh run.
static func apply(tier: int, run: RunState) -> void:
	run.tier = clampi(tier, 0, max_tier())
	for t in range(1, run.tier + 1):
		match t:
			1:
				run.interval_mult *= 1.0 / 1.15
			2:
				run.set_ram_max(run.ram_max - 20)
			3:
				run.timeout_multiplier = 2
			4:
				run.building_cost_mult *= 1.25
			5:
				run.imp_work_mult *= 1.25
			6:
				run.overload_grace_override = 2.0

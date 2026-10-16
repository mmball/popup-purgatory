class_name ImpManager
extends Node
## Owns the imps, hands out pop-up targets, and runs dojo training: a dojo with
## a free slot pulls the nearest idle untrained imp homed within its radius, who
## walks in, trains for Imp.TRAIN_TIME and comes out trained. Also fires imps
## when their hut is sold and answers the local coffee-cart speed question.

signal training_started(imp: Imp, dojo: Node2D)
signal imp_trained(imp: Imp, dojo: Node2D)

var run: RunState
var rng: RandomNumberGenerator
var layer: Node2D         ## imps are added here
var popup_layer: Control  ## pop-ups are read from here
var village: Village      ## set by Desktop; null in unit tests (no local effects then)
var assigner := TargetAssigner.new()
var imps: Array[Imp] = []
var dojos: Array[Node2D] = []

const COLORS := [Color("8b2fc9"), Color("c93a2f"), Color("2f7fc9"), Color("2fa85a"), Color("d97f1f")]
const COFFEE_SPEED := 1.25   ## per cart in range of the imp's hut (carts stack)


func setup(p_run: RunState, p_rng: RandomNumberGenerator, p_layer: Node2D, p_popup_layer: Control) -> void:
	run = p_run
	rng = p_rng
	layer = p_layer
	popup_layer = p_popup_layer


func spawn_imp(home: Vector2, home_cell: Vector2i = Vector2i(-1, -1)) -> Imp:
	var imp := Imp.new()
	imp.manager = self
	imp.run = run
	imp.rng = rng
	imp.home = home
	imp.home_cell = home_cell
	imp.position = home
	imp.body_color = COLORS[imps.size() % COLORS.size()]
	layer.add_child(imp)
	imps.append(imp)
	run.imps_hired += 1
	return imp


## Coffee carts are local: one factor per cart within radius of the imp's hut.
func speed_mult_for(imp: Imp) -> float:
	if village == null:
		return 1.0
	return pow(Tuning.num("building.coffee.speed", COFFEE_SPEED), float(village.carts_in_range(imp.home_cell)))


func add_dojo(b: Node2D) -> void:
	dojos.append(b)


## The dojo was demolished: forget it and let any trainee back out untrained.
func remove_dojo(b: Node2D) -> void:
	dojos.erase(b)
	var t: Variant = b.get("trainee")  # Building.trainee is an untyped Node slot
	if t is Imp:
		(t as Imp).abort_training()


## The hut at `from` moved to `to`: its imps follow.
func rehome(from: Vector2i, to: Vector2i, new_home: Vector2) -> void:
	for imp: Imp in imps:
		if imp.home_cell == from:
			imp.home_cell = to
			imp.home = new_home


func _process(_delta: float) -> void:
	_assign_training()


## Pairs each dojo with a free slot to the nearest eligible idle untrained imp.
func _assign_training() -> void:
	for d: Node2D in dojos:
		if not is_instance_valid(d) or not bool(d.call("has_free_slot")):
			continue
		var pick := pick_trainee(d)
		if pick != null:
			pick.start_training(d)
			training_started.emit(pick, d)


## The nearest imp that is untrained, not training, working or leaving, and
## whose hut is within the dojo's radius (strays with no hut always qualify).
func pick_trainee(dojo: Node2D) -> Imp:
	var dojo_cell: Vector2i = dojo.get("cell")
	var radius := BuildingCatalog.radius("dojo")
	var best: Imp = null
	var best_d := INF
	for imp: Imp in imps:
		if imp.trained or imp.state == Imp.State.TRAIN or imp.state == Imp.State.WORK or imp.state == Imp.State.LEAVE:
			continue
		if imp.home_cell.x >= 0 and Village.cell_distance(imp.home_cell, dojo_cell) > radius:
			continue
		var dist := dojo.position.distance_to(imp.position)
		if dist < best_d:
			best_d = dist
			best = imp
	return best


func on_imp_trained(imp: Imp, dojo: Node2D) -> void:
	imp_trained.emit(imp, dojo)


## Fires the imp that lives in the hut at `cell` (the least valuable one if
## several), falling back to the least valuable stray. Null when nobody is left.
func fire_from_hut(cell: Vector2i) -> Imp:
	var pick := _least_valuable(cell)
	if pick == null:
		pick = _least_valuable(Vector2i(-1, -1))
	if pick == null:
		return null
	fire_imp(pick)
	return pick


## Removes `imp` from the roster and sends it walking off the desk.
func fire_imp(imp: Imp) -> void:
	imps.erase(imp)
	assigner.release_claimant(imp.get_instance_id())
	imp.leave()


## Untrained before trained, then fewest closes, among imps homed at `cell`.
func _least_valuable(cell: Vector2i) -> Imp:
	var best: Imp = null
	for imp: Imp in imps:
		if imp.home_cell != cell or imp.state == Imp.State.LEAVE:
			continue
		if best == null or _value(imp) < _value(best):
			best = imp
	return best


func _value(imp: Imp) -> int:
	return (1000 if imp.trained else 0) + imp.closes


## A fired imp walked off the edge (idempotent; fire_imp already removed it).
func on_imp_left(imp: Imp) -> void:
	imps.erase(imp)


func training_slots() -> int:
	var n := 0
	for d: Node2D in dojos:
		if is_instance_valid(d):
			n += Building.DOJO_SLOTS
	return n


func count_trained() -> int:
	var n := 0
	for imp: Imp in imps:
		if imp.trained:
			n += 1
	return n


func live_popups() -> Array[PopupBase]:
	var out: Array[PopupBase] = []
	for c: Node in popup_layer.get_children():
		if c is PopupBase and not c.is_closing:
			out.append(c)
	return out


func request_target(imp: Imp) -> PopupBase:
	if imp.state == Imp.State.LEAVE:
		return null
	var candidates: Array = []
	for p: PopupBase in live_popups():
		if p.imp_cooldown > 0.0:
			continue  # it just hopped away from an imp; leave it alone for a while
		if p.dismiss_spawns() > 0 and not imp.trained:
			continue  # untrained imps would X it and spawn more (cookie banners)
		candidates.append({"id": p.get_instance_id(), "pos": p.imp_close_point(), "age": p.age})
	var id: Variant = assigner.claim(candidates, imp.get_instance_id(), imp.position)
	if id == null:
		return null
	var obj := instance_from_id(id)
	return obj as PopupBase


func release(imp: Imp) -> void:
	assigner.release_claimant(imp.get_instance_id())


func on_popup_closed(popup: PopupBase) -> void:
	assigner.release(popup.get_instance_id())

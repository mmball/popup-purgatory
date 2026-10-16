class_name ImpManager
extends Node
## Owns the imps, hands out pop-up targets, and runs dojo training: a dojo with
## a free slot pulls the nearest idle untrained imp, who walks in, trains for
## Imp.TRAIN_TIME and comes out trained.

signal training_started(imp: Imp, dojo: Node2D)
signal imp_trained(imp: Imp, dojo: Node2D)

var run: RunState
var rng: RandomNumberGenerator
var layer: Node2D         ## imps are added here
var popup_layer: Control  ## pop-ups are read from here
var assigner := TargetAssigner.new()
var imps: Array[Imp] = []
var dojos: Array[Node2D] = []

const COLORS := [Color("8b2fc9"), Color("c93a2f"), Color("2f7fc9"), Color("2fa85a"), Color("d97f1f")]


func setup(p_run: RunState, p_rng: RandomNumberGenerator, p_layer: Node2D, p_popup_layer: Control) -> void:
	run = p_run
	rng = p_rng
	layer = p_layer
	popup_layer = p_popup_layer


func spawn_imp(home: Vector2) -> Imp:
	var imp := Imp.new()
	imp.manager = self
	imp.run = run
	imp.rng = rng
	imp.home = home
	imp.position = home
	imp.body_color = COLORS[imps.size() % COLORS.size()]
	layer.add_child(imp)
	imps.append(imp)
	run.imps_hired += 1
	return imp


func add_dojo(b: Node2D) -> void:
	dojos.append(b)


func _process(_delta: float) -> void:
	_assign_training()


## Pairs each dojo with a free slot to the nearest idle untrained imp.
func _assign_training() -> void:
	for d: Node2D in dojos:
		if not is_instance_valid(d) or not bool(d.call("has_free_slot")):
			continue
		var pick := pick_trainee(d.position)
		if pick != null:
			pick.start_training(d)
			training_started.emit(pick, d)


## The nearest imp that is untrained and not already training or working.
func pick_trainee(from: Vector2) -> Imp:
	var best: Imp = null
	var best_d := INF
	for imp: Imp in imps:
		if imp.trained or imp.state == Imp.State.TRAIN or imp.state == Imp.State.WORK:
			continue
		var dist := from.distance_to(imp.position)
		if dist < best_d:
			best_d = dist
			best = imp
	return best


func on_imp_trained(imp: Imp, dojo: Node2D) -> void:
	imp_trained.emit(imp, dojo)


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

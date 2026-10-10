class_name ImpManager
extends Node
## Owns the imps, hands out pop-up targets, and applies training slots.

var run: RunState
var rng: RandomNumberGenerator
var layer: Node2D         ## imps are added here
var popup_layer: Control  ## pop-ups are read from here
var assigner := TargetAssigner.new()
var imps: Array[Imp] = []
var training_slots := 0

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
	_apply_training()
	return imp


func add_training_slots(n: int) -> void:
	training_slots += n
	_apply_training()


func count_trained() -> int:
	var n := 0
	for imp: Imp in imps:
		if imp.trained:
			n += 1
	return n


func _apply_training() -> void:
	for imp: Imp in imps:
		if count_trained() >= training_slots:
			return
		if not imp.trained:
			imp.trained = true


func live_popups() -> Array[PopupBase]:
	var out: Array[PopupBase] = []
	for c: Node in popup_layer.get_children():
		if c is PopupBase and not c.is_closing:
			out.append(c)
	return out


func request_target(imp: Imp) -> PopupBase:
	var candidates: Array = []
	for p: PopupBase in live_popups():
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

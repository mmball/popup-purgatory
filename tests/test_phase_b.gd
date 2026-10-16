extends TestCase
## Phase B: demolish refunds, building radii and the village's radius queries,
## and firewall no-spawn zones in the spawner.


func test_cell_distance_is_chebyshev() -> void:
	assert_eq(Village.cell_distance(Vector2i(0, 0), Vector2i(0, 0)), 0, "same cell")
	assert_eq(Village.cell_distance(Vector2i(0, 0), Vector2i(3, 0)), 3, "along x")
	assert_eq(Village.cell_distance(Vector2i(0, 0), Vector2i(0, -4)), 4, "along y, negative")
	assert_eq(Village.cell_distance(Vector2i(2, 2), Vector2i(5, 4)), 3, "diagonal takes the max")
	assert_eq(Village.cell_distance(Vector2i(5, 4), Vector2i(2, 2)), 3, "symmetric")


func test_refund_halves_and_floors() -> void:
	assert_eq(BuildingCatalog.refund(70, false), 35, "half")
	assert_eq(BuildingCatalog.refund(70, true), 52, "three quarters, floored")
	assert_eq(BuildingCatalog.refund(45, false), 22, "half of odd, floored")
	assert_eq(BuildingCatalog.refund(35, true), 26, "26.25 floors")
	assert_eq(BuildingCatalog.refund(0, true), 0, "nothing paid, nothing back")


func test_radius_per_building() -> void:
	assert_eq(BuildingCatalog.radius("dojo"), 2, "dojo")
	assert_eq(BuildingCatalog.radius("coffee"), 2, "coffee")
	assert_eq(BuildingCatalog.radius("firewall"), 3, "firewall")
	assert_eq(BuildingCatalog.radius("hut"), 0, "hut is global")


func test_position_allowed_against_zones() -> void:
	var zones: Array[Dictionary] = [{"center": Vector2(100, 100), "radius": 50.0}]
	var none: Array[Dictionary] = []
	assert_true(PopupSpawner.position_allowed(Rect2(120, 120, 50, 50), none), "no zones: anything goes")
	assert_true(PopupSpawner.position_allowed(Rect2(200, 200, 50, 50), zones), "clear of the zone")
	assert_false(PopupSpawner.position_allowed(Rect2(120, 120, 50, 50), zones), "corner inside the zone")
	assert_false(PopupSpawner.position_allowed(Rect2(60, 60, 80, 80), zones), "window swallows the centre")
	assert_true(PopupSpawner.position_allowed(Rect2(150, 80, 40, 40), zones), "touching the edge only")
	assert_false(PopupSpawner.position_allowed(Rect2(149, 80, 40, 40), zones), "one pixel in")


func test_push_outside_leaves_the_zone() -> void:
	var zones: Array[Dictionary] = [{"center": Vector2(300, 300), "radius": 100.0}, {"center": Vector2(900, 300), "radius": 50.0}]
	assert_eq(PopupSpawner.push_outside(Rect2(600, 600, 40, 40), zones), Vector2(600, 600), "no overlap: unchanged")
	for r: Rect2 in [Rect2(320, 250, 60, 40), Rect2(200, 350, 90, 60), Rect2(280, 280, 40, 40), Rect2(880, 290, 30, 30)]:
		var p := PopupSpawner.push_outside(r, zones)
		assert_true(PopupSpawner.position_allowed(Rect2(p, r.size), zones), "pushed clear: " + str(r))
		assert_lt(p.distance_to(r.position), 300.0, "pushed only as far as needed: " + str(r))


func test_pick_position_draws_the_same_without_firewalls() -> void:
	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	var spawner := PopupSpawner.new()
	spawner.layer = layer
	spawner.rng = RandomNumberGenerator.new()
	spawner.rng.seed = 11
	var got := spawner._pick_position(Vector2(200, 150), null)
	var near := spawner._pick_position(Vector2(200, 150), Vector2(500, 300))
	# the reference draws exactly what the pre-firewall code drew: two per spawn
	var ref := RandomNumberGenerator.new()
	ref.seed = 11
	var want := Vector2(ref.randf_range(8, 1280 - 200 - 8), ref.randf_range(8, 720 - 150 - 8)).round()
	var want_near := (Vector2(500, 300) + Vector2(ref.randf_range(-60, 60), ref.randf_range(-40, 40))).round()
	assert_eq(got, want, "first candidate taken, same draws")
	assert_eq(near, want_near, "near spawn, same draws")
	assert_eq(spawner.rng.state, ref.state, "no extra rng draws without zones")
	spawner.free()
	layer.free()


func test_pick_position_avoids_firewalls() -> void:
	var layer := Control.new()
	layer.size = Vector2(1280, 720)
	var village := Village.new()
	village.add_building("firewall", Vector2i(10, 5), 70)
	var zones := village.firewall_zones()
	var spawner := PopupSpawner.new()
	spawner.layer = layer
	spawner.village = village
	spawner.rng = RandomNumberGenerator.new()
	spawner.rng.seed = 5
	var size := Vector2(200, 150)
	for i in range(60):
		var p := spawner._pick_position(size, null)
		assert_true(PopupSpawner.position_allowed(Rect2(p, size), zones), "spawn %d clear of the firewall: %s" % [i, str(p)])
		assert_true(p.x >= PopupSpawner.MARGIN and p.y >= PopupSpawner.MARGIN, "spawn %d inside the layer" % i)
	# a spawn clustered on the firewall itself gets pushed out too
	for i in range(20):
		var p := spawner._pick_position(size, village.cell_center(Vector2i(10, 5)))
		assert_true(PopupSpawner.position_allowed(Rect2(p, size), zones), "near-spawn %d clear of the firewall: %s" % [i, str(p)])
	spawner.free()
	village.free()
	layer.free()


func test_village_radius_queries() -> void:
	var v := Village.new()
	var hut_cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 6), Vector2i(15, 2)]
	for c: Vector2i in hut_cells:
		var hut := v.add_building("hut", c, 20)
		assert_eq(hut.cell, c, "hut remembers its cell")
		assert_eq(hut.price_paid, 20, "hut remembers its price")
	var cart := v.add_building("coffee", Vector2i(6, 6), 40)
	assert_eq(cart.cell, Vector2i(6, 6), "cart cell")
	assert_eq(v.count("hut"), 4, "four huts")
	assert_eq(v.buildings_within(Vector2i(6, 6), 2, "hut").size(), 3, "three huts within 2 of the cart")
	assert_eq(v.buildings_within(Vector2i(6, 6), 2).size(), 4, "including the cart itself")
	assert_eq(v.buildings_within(Vector2i(6, 6), 0).size(), 1, "radius 0 is the cell itself")
	assert_eq(v.buildings_within(Vector2i(15, 2), 1, "coffee").size(), 0, "no cart near the far hut")
	assert_eq(v.carts_in_range(Vector2i(5, 5)), 1, "near hut has one cart")
	assert_eq(v.carts_in_range(Vector2i(15, 2)), 0, "far hut has none")
	assert_eq(v.carts_in_range(Vector2i(-1, -1)), 0, "stray imps get none")
	assert_eq(v.firewall_zones().size(), 0, "no firewalls yet")
	v.add_building("firewall", Vector2i(12, 8), 70)
	var zones := v.firewall_zones()
	assert_eq(zones.size(), 1, "one zone per firewall")
	assert_eq(zones[0]["center"], v.cell_center(Vector2i(12, 8)), "zone sits on the cell centre")
	assert_eq(float(zones[0]["radius"]), 3.0 * Village.CELL, "zone radius in pixels")
	v.free()


func test_village_suggests_cells() -> void:
	var v := Village.new()
	for c: Vector2i in [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 6)]:
		v.add_building("hut", c, 20)
	v.add_building("hut", Vector2i(16, 1), 20)
	var cart_cell := v.suggest_cell("coffee")
	assert_true(v.cell_free(cart_cell), "suggested cart cell is free")
	assert_eq(v.buildings_within(cart_cell, 2, "hut").size(), 3, "cart covers the cluster of three")
	var fw := v.suggest_cell("firewall")
	assert_true(v.in_bounds(fw), "firewall suggestion in bounds")
	assert_true(v.cell_free(fw), "firewall suggestion free")
	var hut := v.suggest_cell("hut")
	assert_true(v.cell_free(hut), "hut suggestion free")
	assert_ge(v.buildings_within(hut, 1).size(), 1, "hut goes next to something")
	v.free()


func test_village_move_and_remove() -> void:
	var v := Village.new()
	var hut := v.add_building("hut", Vector2i(3, 3), 20)
	assert_false(v.move_building(Vector2i(3, 3), Vector2i(0, 0)), "cannot move onto a reserved cell")
	assert_false(v.move_building(Vector2i(9, 9), Vector2i(4, 4)), "nothing to move")
	assert_true(v.move_building(Vector2i(3, 3), Vector2i(4, 4)), "moved")
	assert_eq(hut.cell, Vector2i(4, 4), "building knows its new cell")
	assert_true(v.cell_free(Vector2i(3, 3)), "old cell freed")
	assert_eq(v.buildings.get(Vector2i(4, 4)), hut, "dict follows the move")
	assert_eq(hut.position, v.cell_center(Vector2i(4, 4)) + Vector2(0, 8), "drawn at the new cell")
	assert_eq(v.remove_building(Vector2i(3, 3)), null, "removing an empty cell returns null")
	var removed := v.remove_building(Vector2i(4, 4))
	assert_eq(removed, hut, "remove returns the node")
	assert_true(v.cell_free(Vector2i(4, 4)), "cell freed")
	assert_eq(v.count("hut"), 0, "no huts left")
	assert_eq(removed.get_parent(), null, "detached from the village")
	removed.free()  # remove_building queued it; freeing now keeps the runner leak-free
	v.free()

extends SceneTree

func _init() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var world:Node = load("res://scene/world.tscn").instantiate()
	root.add_child(world)
	for i in 120:
		await process_frame

	var voronoi:Node2D = world.get_node("world_map/VoronoiDivision")
	var points:Array[Vector2]
	for id in voronoi.indexes:
		var posi:Vector2 = voronoi.polar2eulur(voronoi.polar_points.entity_find(id))
		posi += voronoi.polar2eulur(Vector2(
			voronoi.radii.entity_find(id),
			voronoi.angulur.entity_find(id)))
		points.append(voronoi.to_global(posi))

	var polygons:Array[PackedVector2Array] = voronoi.get_voronoi_polygons(points)
	var invalid:int = 0
	var full_screen:int = 0
	for polygon in polygons:
		if polygon.size() < 3:
			invalid += 1
			continue
		var local_polygon := PackedVector2Array()
		for point in polygon:
			local_polygon.append(voronoi.to_local(point))
		if Geometry2D.triangulate_polygon(local_polygon).is_empty():
			invalid += 1
		var rect := Rect2(local_polygon[0], Vector2.ZERO)
		for point in local_polygon:
			rect = rect.expand(point)
		if rect.size.x > 1100.0 and rect.size.y > 600.0:
			full_screen += 1

	print("probe points=", points.size(), "polygons=", polygons.size(),
		"invalid=", invalid, "full_screen=", full_screen)
	quit()

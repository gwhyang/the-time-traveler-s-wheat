extends Node2D
class_name VoronoiDivision

const EPSILON:float = 0.000001

func get_voronoi_polygons(points:Array[Vector2]) -> Array[PackedVector2Array]:
	var polygons:Array[PackedVector2Array] = []
	polygons.resize(points.size())
	if points.is_empty():
		return polygons

	var canvas_transform := get_viewport().get_canvas_transform()
	var viewport_to_global := canvas_transform.affine_inverse()
	var screen := get_viewport_rect()
	var screen_points:Array[Vector2] = []
	for point in points:
		screen_points.append(canvas_transform * point)

	var margin:float = maxf(maxf(screen.size.x, screen.size.y), 1.0)
	var working_min := screen.position
	var working_max := screen.end
	for point in screen_points:
		working_min.x = minf(working_min.x, point.x)
		working_min.y = minf(working_min.y, point.y)
		working_max.x = maxf(working_max.x, point.x)
		working_max.y = maxf(working_max.y, point.y)
	working_min -= Vector2.ONE * margin
	working_max += Vector2.ONE * margin
	var working_polygon := PackedVector2Array([
		working_min,
		Vector2(working_max.x, working_min.y),
		working_max,
		Vector2(working_min.x, working_max.y),
	])

	var point_lengths := PackedFloat32Array()
	point_lengths.resize(points.size())
	for i in points.size():
		point_lengths[i] = screen_points[i].length_squared()

	for i in points.size():
		var polygon := working_polygon.duplicate()
		for j in points.size():
			if i == j:
				continue

			var normal := screen_points[j] - screen_points[i]
			if normal.length_squared() <= EPSILON:
				continue
			var boundary := (point_lengths[j] - point_lengths[i]) * 0.5
			polygon = _clip_polygon(polygon, normal, boundary)
			if polygon.is_empty():
				break

		polygon = _clip_to_screen(polygon, screen)
		var global_polygon := PackedVector2Array()
		for point in polygon:
			global_polygon.append(viewport_to_global * point)
		polygons[i] = global_polygon

	return polygons


func _clip_to_screen(polygon:PackedVector2Array, screen:Rect2) -> PackedVector2Array:
	polygon = _clip_polygon(polygon, Vector2.LEFT, -screen.position.x)
	polygon = _clip_polygon(polygon, Vector2.RIGHT, screen.end.x)
	polygon = _clip_polygon(polygon, Vector2.UP, -screen.position.y)
	return _clip_polygon(polygon, Vector2.DOWN, screen.end.y)


func _clip_polygon(
	polygon:PackedVector2Array,
	normal:Vector2,
	boundary:float
) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	if polygon.is_empty():
		return clipped

	var previous := polygon[-1]
	var previous_inside:bool = previous.dot(normal) <= boundary + EPSILON
	for current in polygon:
		var current_inside:bool = current.dot(normal) <= boundary + EPSILON
		if current_inside != previous_inside:
			var edge := current - previous
			var denominator := edge.dot(normal)
			if not is_zero_approx(denominator):
				var amount := (boundary - previous.dot(normal)) / denominator
				clipped.append(previous.lerp(current, amount))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_inside = current_inside

	return clipped

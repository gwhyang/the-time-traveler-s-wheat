extends Node2D

@onready var voronoi_point_emmitor: VoronoiEmitor = %VoronoiPointEmmitor
func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var polygons:= voronoi_point_emmitor.polygons
	var indexes:= voronoi_point_emmitor.indexes
	for i in mini(indexes.size(),polygons.size()):
		var id := indexes[i]
		if voronoi_point_emmitor.render_target[id] != VoronoiEmitor.RenderTarget.OVERRIDER:
			continue
		if polygons[i].is_empty():
			continue
		var local_polygon := PackedVector2Array()
		for point in polygons[i]:
			local_polygon.append(to_local(point))
		draw_colored_polygon(local_polygon,voronoi_point_emmitor.color.entity_find(id))

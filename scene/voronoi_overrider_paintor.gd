extends Node2D

@onready var voronoi_point_emmitor: VoronoiEmitor = %VoronoiPointEmmitor
func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var polygons:= voronoi_point_emmitor.polygons
	var colors:= voronoi_point_emmitor.color
	var indexes:= voronoi_point_emmitor.indexes
	for i in mini(indexes.size(),voronoi_point_emmitor.change_index):
		if polygons[-i-1].is_empty():
			continue
		var local_polygon := PackedVector2Array()
		for point in polygons[-i-1]:
			local_polygon.append(to_local(point))
		draw_colored_polygon(polygons[-1-i],colors.entity_find(indexes[-1-i]))

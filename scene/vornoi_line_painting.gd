extends Node2D

@onready var voronoi_point_emmitor: VoronoiEmitor = %VoronoiPointEmmitor

@export_group("outline")
@export var outline_color:Color = Color.WHITE
@export_range(0.0, 100.0, 0.1) var outline_width:float = 1.0
@export var outline_antialiased:bool = true

func _process(_delta:float) -> void:
	queue_redraw()

func _draw() -> void:
	var polygons := voronoi_point_emmitor.polygons
	var indexes := voronoi_point_emmitor.indexes
	var count := mini(indexes.size(),polygons.size())

	for i in count:
		var id := indexes[i]
		if voronoi_point_emmitor.render_target[id] != VoronoiEmitor.RenderTarget.BACKGROUND:
			continue
		if polygons[i].size() < 2:
			continue

		var outline := PackedVector2Array()
		for point in polygons[i]:
			outline.append(to_local(point))
		outline.append(outline[0])
		draw_polyline(outline,outline_color,outline_width,outline_antialiased)

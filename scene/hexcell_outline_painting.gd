extends Node2D

@onready var color_division: Node = get_node("../../background_medium/color_division")

@export_group("outline")
@export var outline_color: Color = Color.WHITE
@export_range(0.0, 100.0, 0.1) var outline_width: float = 1.0
@export var outline_antialiased: bool = true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var polygons: Array = color_division.get("polygons")
	if polygons == null:
		return

	for polygon: PackedVector2Array in polygons:
		if polygon.size() < 2:
			continue

		var outline := PackedVector2Array()
		for point in polygon:
			outline.append(to_local(color_division.to_global(point)))
		outline.append(outline[0])
		draw_polyline(outline, outline_color, outline_width, outline_antialiased)

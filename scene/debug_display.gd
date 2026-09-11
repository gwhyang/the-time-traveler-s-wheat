extends Node2D

@onready var world_map: HexMap = %world_map



func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for point in world_map.edge_points:
		draw_circle(world_map.to_global(world_map.map_to_local(point)),3,Color.RED)
	for point in world_map.inner_points:
		draw_circle(world_map.to_global(world_map.map_to_local(point)),3,Color.BLUE)
	for point in world_map.new_points:
		draw_circle(world_map.to_global(world_map.map_to_local(point)),3,Color.AQUA)

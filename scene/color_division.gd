extends Node2D

@onready var world_map: GameMap = %world_map

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_background_overrides(world_map.posi_backgroud_override)

func draw_hex_cells(cells:Array, color:Color) -> void:
	var player_global_posi:Vector2 = world_map.player.position
	for cell in cells:
		var points := PackedVector2Array()
		for point in world_map.get_hex_cell_points(cell):
			points.append(to_local(world_map.to_global(point)-player_global_posi))
		draw_colored_polygon(points, color)

func draw_background_overrides(overrides:Dictionary[Vector2i,Game.BackGround]) -> void:
	var cells_by_background:Dictionary[int,Array] = {}
	for cell:Vector2i in overrides:
		var background := int(overrides[cell])
		if background == Game.BackGround.NONE:
			continue
		if not cells_by_background.has(background):
			cells_by_background[background] = []
		cells_by_background[background].append(cell)

	for background:int in cells_by_background:
		draw_hex_cells(
			cells_by_background[background],
			Color((background - 1.0) / 6.0, 0.0, 0.0)
		)

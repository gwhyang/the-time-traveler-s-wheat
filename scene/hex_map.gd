extends TileMapLayer

## 只让摄像机视野内的六边形世界保持稳定。
## 格子离开卸载缓冲区后会被删除；再次进入时使用新的 generation 生成。

@export var hex_radius: float = 42.0
@export var world_seed: int = 20260909
@export_range(0.0, 1.0, 0.01) var point_spawn_chance: float = 0.9
@export_range(0.0, 1.0, 0.01) var edge_spawn_chance: float = 0.6
@export var load_margin: float = 100.0
@export var unload_margin: float = 220.0

const SQRT_3 := 1.7320508075688772
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]
const FORWARD_EDGE_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
]

var _loaded_cells: Dictionary = {}
var _generation_by_cell: Dictionary = {}
var _last_camera_rect := Rect2()


func _ready() -> void:
	set_process(true)
	_refresh_visible_world(true)


func _process(_delta: float) -> void:
	_refresh_visible_world(false)


func axial_to_local(cell: Vector2i) -> Vector2:
	# 尖顶六边形；q、r 两个坐标基底夹角为 60°。
	return Vector2(
		hex_radius * SQRT_3 * (cell.x + cell.y * 0.5),
		hex_radius * 1.5 * cell.y
	)


func local_to_axial(point: Vector2) -> Vector2i:
	var q := (SQRT_3 / 3.0 * point.x - point.y / 3.0) / hex_radius
	var r := (2.0 / 3.0 * point.y) / hex_radius
	return _cube_round(q, r)


func can_travel(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not _loaded_cells.has(from_cell) or not _loaded_cells.has(to_cell):
		return false
	if not _point_exists(from_cell) or not _point_exists(to_cell):
		return false
	if not AXIAL_DIRECTIONS.has(to_cell - from_cell):
		return false
	return _edge_is_open(from_cell, to_cell)


func get_loaded_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _loaded_cells:
		result.append(cell)
	return result


func _refresh_visible_world(force: bool) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewport_size := get_viewport_rect().size / camera.zoom
	var camera_center := to_local(camera.get_screen_center_position())
	var visible_rect := Rect2(camera_center - viewport_size * 0.5, viewport_size)
	if not force and visible_rect.position.distance_squared_to(_last_camera_rect.position) < 64.0:
		return
	_last_camera_rect = visible_rect

	var load_rect := visible_rect.grow(load_margin)
	var keep_rect := visible_rect.grow(unload_margin)
	var candidates := _cells_covering_rect(load_rect)
	for cell in candidates:
		if not _loaded_cells.has(cell):
			_loaded_cells[cell] = true

	var cells_to_remove: Array[Vector2i] = []
	for cell: Vector2i in _loaded_cells:
		if not keep_rect.has_point(axial_to_local(cell)):
			cells_to_remove.append(cell)
	for cell in cells_to_remove:
		_loaded_cells.erase(cell)
		_generation_by_cell[cell] = int(_generation_by_cell.get(cell, 0)) + 1

	queue_redraw()


func _cells_covering_rect(rect: Rect2) -> Array[Vector2i]:
	var center_cell := local_to_axial(rect.get_center())
	var reach := int(ceil(maxf(rect.size.x, rect.size.y) / (hex_radius * 1.5))) + 3
	var result: Array[Vector2i] = []
	for q in range(center_cell.x - reach, center_cell.x + reach + 1):
		for r in range(center_cell.y - reach, center_cell.y + reach + 1):
			var cell := Vector2i(q, r)
			if rect.has_point(axial_to_local(cell)):
				result.append(cell)
	return result


func _draw() -> void:
	# 先画格子，再画通路，最后画节点，保证通路清晰可见。
	for cell: Vector2i in _loaded_cells:
		var center := axial_to_local(cell)
		var polygon := PackedVector2Array()
		for corner in range(6):
			var angle := deg_to_rad(60.0 * corner - 30.0)
			polygon.append(center + Vector2(cos(angle), sin(angle)) * (hex_radius - 2.0))
		var shade := 0.11 + 0.035 * float(_cell_value(cell, 91) % 4)
		draw_colored_polygon(polygon, Color(shade, shade + 0.035, shade + 0.055, 1.0))
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color(0.3, 0.38, 0.43), 1.5, true)

	for cell: Vector2i in _loaded_cells:
		if not _point_exists(cell):
			continue
		for direction in FORWARD_EDGE_DIRECTIONS:
			var neighbor := cell + direction
			if _loaded_cells.has(neighbor) and _point_exists(neighbor) and _edge_is_open(cell, neighbor):
				draw_line(axial_to_local(cell), axial_to_local(neighbor), Color(0.35, 0.9, 0.68), 5.0, true)

	for cell: Vector2i in _loaded_cells:
		if not _point_exists(cell):
			continue
		var center := axial_to_local(cell)
		draw_circle(center, 9.0, Color(0.92, 0.95, 1.0))
		draw_circle(center, 5.0, Color(0.18, 0.52, 0.78))


func _edge_is_open(a: Vector2i, b: Vector2i) -> bool:
	# 无向边只生成一次。边的结果包含两端当前 generation，任一端被卸载后都可改变。
	var first := a
	var second := b
	if _cell_less(b, a):
		first = b
		second = a
	var first_generation := int(_generation_by_cell.get(first, 0))
	var second_generation := int(_generation_by_cell.get(second, 0))
	var value := _mix_hash(world_seed, first.x, first.y, second.x, second.y, first_generation, second_generation)
	return float(value % 10000) / 10000.0 < edge_spawn_chance


func _point_exists(cell: Vector2i) -> bool:
	var value := _cell_value(cell, 173)
	return float(value % 10000) / 10000.0 < point_spawn_chance


func _cell_value(cell: Vector2i, salt: int) -> int:
	return _mix_hash(world_seed, cell.x, cell.y, int(_generation_by_cell.get(cell, 0)), salt, 0, 0)


func _mix_hash(a: int, b: int, c: int, d: int, e: int, f: int, g: int) -> int:
	var value := hash([a, b, c, d, e, f, g])
	return absi(value)


func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


func _cube_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx := roundi(x)
	var ry := roundi(y)
	var rz := roundi(z)
	var x_diff := absf(rx - x)
	var y_diff := absf(ry - y)
	var z_diff := absf(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(rx, rz)

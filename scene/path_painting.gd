extends Node2D
#line_pice_count   虚线数量
#dash_ratio        每段中实线所占比例
#line_width        线宽
#noise1_x/y_scale  平滑噪声的横纵偏移幅度
#noise1_frequency  平滑噪声频率，越小越平滑
#noise2_x/y_scale  随机抖动幅度
#noise1_seed       Perlin 噪声种子
#noise2_seed       随机噪声种子
@export_group("line properties")
@export var line_color:Color = Color(0.35, 0.9, 0.68, 1.0)
@export_range(0.5, 20.0, 0.5) var line_width:float = 3.0
@export_range(1, 64, 1) var line_pice_count:int = 6
@export_range(0.05, 0.95, 0.05) var dash_ratio:float = 0.55
@export var antialiased:bool = true

@export_group("noise properties")
@export var noise1_x_scale:float = 13
@export var noise1_y_scale:float = 13
@export var noise2_x_scale:float = 5
@export var noise2_y_scale:float = 5
@export_range(0.001, 0.2, 0.001) var noise1_frequency:float = 0.035
@export var noise1_seed:int = 20260912
@export var noise2_seed:int = 20260912

@onready var world_map: HexMap = %world_map

# 根据worldmap中储存的边来生成虚线点组，渲染前根据点组的原始坐标，生成一个新的应用噪音后的点组，依据这个画虚线以有一些手绘的歪歪扭扭的效果
# 暂定noise1 x y 都是 平滑的柏林噪声，noise2是随机噪声
# 不要删除、改动这些说明语句

var _original_point_groups:Array[PackedVector2Array] = []
var _delet_edges:Array[Vector4i] = []
var _last_edge_signature:int = 0
var _has_edge_signature:bool = false

var _noise1_x := FastNoiseLite.new()
var _noise1_y := FastNoiseLite.new()


func _ready() -> void:
	_configure_noise()
	world_map.player_moved.connect(_on_player_moved)
	_refresh_original_point_groups()
	queue_redraw()


func _process(_delta:float) -> void:
	if not is_instance_valid(world_map):
		return
	var redraw := _refresh_original_point_groups()
	if _remove_out_of_view_delet_edges():
		redraw = true
	if redraw:
		queue_redraw()


func _on_player_moved() -> void:
	for edge:Vector4i in world_map.delet_edges:
		if not _delet_edges.has(edge):
			_delet_edges.append(edge)
	queue_redraw()


func _configure_noise() -> void:
	_noise1_x.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise1_x.frequency = maxf(noise1_frequency, 0.001)
	_noise1_x.seed = noise1_seed

	_noise1_y.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise1_y.frequency = maxf(noise1_frequency, 0.001)
	_noise1_y.seed = noise1_seed + 1


func _refresh_original_point_groups() -> bool:
	if not is_instance_valid(world_map):
		return false

	var signature_data:Array = [line_pice_count]
	for edge:Vector4i in world_map.edges:
		signature_data.append(edge)
	var edge_signature:int = hash(signature_data)
	if _has_edge_signature and edge_signature == _last_edge_signature:
		return false

	_last_edge_signature = edge_signature
	_has_edge_signature = true
	_original_point_groups.clear()

	var dash_count := maxi(line_pice_count, 1)
	for edge:Vector4i in world_map.edges:
		_original_point_groups.append(_make_original_point_group(edge, dash_count * 2))

	return true


func _make_original_point_group(edge:Vector4i, point_count:int) -> PackedVector2Array:
	var edge_points:Array[Vector2i] = world_map.get_edge_points(edge)
	var from_point := _cell_to_local(edge_points[0])
	var to_point := _cell_to_local(edge_points[1])
	var point_group := PackedVector2Array()

	for point_index in range(point_count + 1):
		var amount := float(point_index) / float(point_count)
		point_group.append(from_point.lerp(to_point, amount))

	return point_group


func _cell_to_local(cell:Vector2i) -> Vector2:
	var map_local_point := world_map.map_to_local(cell)
	return to_local(world_map.to_global(map_local_point))


func _remove_out_of_view_delet_edges() -> bool:
	var camera_rect := world_map.get_camera_rect()
	var removed := false
	for i in range(_delet_edges.size() - 1, -1, -1):
		var edge_points:Array[Vector2i] = world_map.get_edge_points(_delet_edges[i])
		var first_point := world_map.map_to_local(edge_points[0])
		var second_point := world_map.map_to_local(edge_points[1])
		if not camera_rect.has_point(first_point) and not camera_rect.has_point(second_point):
			_delet_edges.remove_at(i)
			removed = true
	return removed


func _draw() -> void:
	for original_points:PackedVector2Array in _original_point_groups:
		var noisy_points := _make_noisy_points(original_points)
		_draw_dashed_polyline(noisy_points)

	var point_count := maxi(line_pice_count, 1) * 2
	for edge:Vector4i in _delet_edges:
		var original_points := _make_original_point_group(edge, point_count)
		_draw_dashed_polyline(_make_noisy_points(original_points))
	
	# 显示可到达的格点
	for neighbor in world_map.hex_neibghbors:
		var cell := world_map.get_neighbor_cell(world_map.player_cell,neighbor)
		if world_map.can_player_move_to(cell):
			draw_circle(world_map.to_global(world_map.map_to_local(cell)),10,Color.GREEN_YELLOW)


func _make_noisy_points(original_points:PackedVector2Array) -> PackedVector2Array:
	var noisy_points := PackedVector2Array()
	if original_points.size() < 2:
		return noisy_points

	var edge_seed := hash([
		noise2_seed,
		original_points[0],
		original_points[original_points.size() - 1],
	])

	for point_index in original_points.size():
		var point := original_points[point_index]
		var amount := float(point_index) / float(original_points.size() - 1)
		# 端点保持原始坐标，避免路径和两端的地图节点错开。
		var endpoint_falloff := sin(amount * PI)

		var smooth_offset := Vector2(
			_noise1_x.get_noise_2d(point.x, point.y) * noise1_x_scale,
			_noise1_y.get_noise_2d(point.x, point.y) * noise1_y_scale
		)
		var random_offset := Vector2(
			_hash_to_signed_unit(edge_seed, point_index, 0) * noise2_x_scale,
			_hash_to_signed_unit(edge_seed, point_index, 1) * noise2_y_scale
		)

		noisy_points.append(point + (smooth_offset + random_offset) * endpoint_falloff)

	return noisy_points


func _hash_to_signed_unit(edge_seed:int, point_index:int, axis:int) -> float:
	var value := absi(hash([edge_seed, point_index, axis]))
	return float(value % 10000) / 5000.0 - 1.0


func _draw_dashed_polyline(points:PackedVector2Array) -> void:
	if points.size() < 2:
		return

	var dash_count := maxi(line_pice_count, 1)
	var dash_ratio_clamped := clampf(dash_ratio, 0.05, 0.95)
	var interval_count := points.size() - 1

	for dash_index in dash_count:
		var interval_start := dash_index * 2
		if interval_start >= interval_count:
			break
		var interval_end := interval_start + 1
		var from_point := points[interval_start]
		var to_point := points[interval_end]
		var dash_end := from_point.lerp(to_point, dash_ratio_clamped)
		draw_line(from_point, dash_end, line_color, line_width, antialiased)

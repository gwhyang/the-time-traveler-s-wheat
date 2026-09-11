extends TileMapLayer
class_name HexMap



## 场景上演出的数据

func _input(event: InputEvent) -> void:
	if Game.disable_move:return
	if event.is_action_released("move"):
		var desti:= local_to_map(to_local(get_global_mouse_position()))
		if desti == player_cell:return
		player_move_to(desti)


func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var points:Array[Vector2i]
	for e:Vector4i in edges:
		points = get_edge_points(e)
		draw_line(to_global(map_to_local(points[0])),to_global(map_to_local(points[1])), Color(0.35, 0.9, 0.68), 5.0, true)
	for point in edge_points:
		draw_circle(to_global(map_to_local(point)),3,Color.RED)
	for point in inner_points:
		draw_circle(to_global(map_to_local(point)),3,Color.BLUE)
	for point in new_points:
		draw_circle(to_global(map_to_local(point)),3,Color.AQUA)
		

#region npc生成
func gen_at(cell:Vector2i,scene:PackedScene,appointed_parent:Node = self)->Node2D:
	if not scene:
		return
	var node := scene.instantiate()
	if node is Node2D:
		spawn_at(cell,node,appointed_parent)
		return node
	return null

func spawn_at(cell:Vector2i,node:Node2D,appointed_parent:Node = self):
	appointed_parent.add_child(node)
	node.global_position = to_global(map_to_local(cell))


#endregion

#region 移动，地图通路生成
const hex_neibghbors:Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]
@export_range(0.0, 1.0, 0.01) var edge_spawn_chance: float = 0.4
@export var player:Node2D
var player_cell:Vector2i

# 1. 直接生成边，然后根据边渲染点
# 2. 生成时候不是直接每个边单独判断是否生成，而是在搜友的边中按照期望随机选取几个生成。其中也按照名额分配给：1. 与玩家相连的边 2，与NPC相连的边（至少一个） 3. 与已有边相连的边，剩下来的就真的随机抽取

# 地图生成时，先根据摄像头找出来边界，每次移动也改变边界，并且根据边界判断是那些边应该重新生成
var edged_points:Dictionary[Vector2i,bool]
var edges:Array[Vector4i]
var inner_points:Array[Vector2i]
var delet_points:Array[Vector2i]
var new_points:Array[Vector2i]
var edge_points:Array[Vector2i]

func player_move_to(desti:Vector2i):
	move_to(player,desti)
	player_cell = desti
	var post_inner_cell:Array[Vector2i] = inner_points.duplicate()
	
	refresh_inner_and_edges(get_camera_rect())
	new_points = []
	delet_points = []
	new_points = inner_points.filter(func(c): return not post_inner_cell.has(c))
	delet_points = post_inner_cell.filter(func(c): return not inner_points.has(c))
	process_new_point_edge()
	process_delet_point_edge()
	after_player_move()

func after_player_move():
	pass

func move_to(node:Node2D,desti:Vector2i):
	node.position = map_to_local(desti)


func refresh_inner_and_edges(global_view_rect:Rect2):
	var next_edges:Dictionary[Vector2i,bool]
	var neighbor_cell:Vector2i
	
	next_edges[player_cell]=true
	inner_points = []
	
	while not next_edges.is_empty():
		edge_points = next_edges.keys()
		next_edges={}
		for point in edge_points:
			for neighbor in hex_neibghbors:
				neighbor_cell = get_neighbor_cell(point,neighbor)
				if inner_points.has(neighbor_cell): continue
				if edge_points.has(neighbor_cell):continue
				if not global_view_rect.has_point(to_global(map_to_local(neighbor_cell))):continue
				next_edges[neighbor_cell]=true
		inner_points.append_array(edge_points)
	
	next_edges ={}
	for point in edge_points:
		for neighbor in hex_neibghbors:
			neighbor_cell = get_neighbor_cell(point,neighbor)
			if inner_points.has(neighbor_cell): continue
			if edge_points.has(neighbor_cell):continue
			next_edges[neighbor_cell]=true
	edge_points = next_edges.keys()

## 处理点和边的新增
func process_new_point_edge():
	var new_edges:Dictionary
	var new_edge_arr:Array
	var neighbor_cell:Vector2i
	var current_edge:Vector4i
	var rng:=RandomNumberGenerator.new()
	var target_count:int
	var weights:PackedFloat32Array
	var index:int = 0
	var edge_ps:Array[Vector2i]
	for point in new_points:
		for neighbor in hex_neibghbors:
			neighbor_cell = get_neighbor_cell(point,neighbor)
			if inner_points.has(neighbor_cell) and not new_points.has(neighbor_cell):continue
			current_edge = point_to_edge(point,neighbor_cell)
			new_edges[current_edge] = true
	new_edge_arr = new_edges.keys().duplicate() as Array[Vector4i]
	
	weights = gen_edge_weights(new_edge_arr)
	target_count = floori(new_edge_arr.size()*edge_spawn_chance)
	
	for i in target_count:
		index = rng.rand_weighted(weights)
		edges.append(new_edge_arr[index])
		edge_ps = get_edge_points(new_edge_arr[index])
		edged_points[edge_ps[0]] = true
		edged_points[edge_ps[1]] = true
		
		new_edge_arr.remove_at(index)
		weights.remove_at(index)

## 处理点和边的消除
func process_delet_point_edge():
	var point_pair:Array
	edged_points={}
	print("e",edges)
	print("i",inner_points)
	for i in range(edges.size()-1,-1,-1):
		point_pair = get_edge_points(edges[i])
		if (inner_points.has(point_pair[0]) or inner_points.has(point_pair[1])): 
			edged_points[point_pair[0]] = true
			edged_points[point_pair[1]] = true
			continue
		edges.remove_at(i)

func gen_edge_weights(new_edge_arr:Array)->PackedFloat32Array:
	var result:PackedFloat32Array
	result.resize(new_edge_arr.size())
	result.fill(1)
	return result

func get_camera_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(0,0,0,0)
	var viewport_size := get_viewport_rect().size / camera.zoom
	var camera_center := map_to_local(player_cell)
	var visible_rect := Rect2(camera_center - viewport_size * 0.5, viewport_size)
	return visible_rect

func get_edge_points(pair:Vector4i)->Array[Vector2i]:
	return [Vector2i(pair.x,pair.y),Vector2i(pair.z,pair.w)]

func point_to_edge(p1:Vector2i,p2:Vector2i)->Vector4i:
	var change:bool = false
	if p1.x == p2.x:
		if p1.y > p2.y:
			change = true
	else:
		if p2.x > p1.x:
			change = true
	if change:
		return Vector4i(p2.x,p2.y,p1.x,p1.y)
	else:
		return Vector4i(p1.x,p1.y,p2.x,p2.y)

#endregion

#region ecs

var max_id:int = 0
var entity_size:int = 0
var entity:Array[int]
var free_list:Array[int]
var sparse_entity:PackedInt32Array
func create_entity():
	var id:int
	if not free_list.is_empty():
		id = free_list.pop_back()
		sparse_entity[id] = entity_size
		
		entity_size+=1
		entity.append(id)
		return id
	id= max_id
	max_id+=1
	sparse_entity.append(entity_size)
	
	entity_size+=1
	entity.append(id)
	return id
	
func free_entity(id:int):
	if has_entity(id):return
	var last_id:int = entity[-1]
	sparse_entity[last_id] = sparse_entity[id]
	entity[sparse_entity[id]] = last_id
	
	entity.pop_back()
	entity_size-=1
	free_list.append(id)
	custom_free_method(id)

func has_entity(id:int)->bool:
	if id >= max_id:return false
	return entity[sparse_entity[id]] == id

func custom_free_method(id:int):
	pass

class Component:
	var dense:Array[int] = []
	var sparse:PackedInt32Array = []
	var values:Array = []
	var sparse_size:int = 0
	
	func entity_find(id:int)->Variant:
		if not has_entity(id):return null
		return values[sparse[id]]
	
	func has_entity(id:int)->bool:
		if id >= sparse_size:
			return false
		var dense_id:= sparse[id]
		if dense_id >= dense.size():
			return false
		return dense[sparse[id]] == id
	
	func entity_add(id:int,value:Variant):
		if sparse_size <= id:
			sparse_size = id+1
			sparse.resize(sparse_size)
		sparse[id] = dense.size()
		dense.append(id)
		values.append(value)
	
	func entity_free(id:int):
		var dense_index0:int = sparse[id]
		var last_id:int = dense[-1]
		
		sparse[last_id] =dense_index0
		dense[dense_index0] = dense[-1]
		values[dense_index0] = values[-1]
		
		dense.pop_back()
		values.pop_back()
	
	func value_id_all(value:Variant)->PackedInt32Array:
		var res:PackedInt32Array
		for i in dense.size():
			if values[i] == value:
				res.append(dense[i])
		return res
	
	func value_id_first(value:Variant)->int:
		for i in dense.size():
			if values[i] == value:
				return dense[i]
		return -1

#endregion

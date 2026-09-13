extends HexMap
class_name GameMap
enum {normal,preending}
@export_range(0.0, 1.0, 0.01) var npc_spawn_chance: float = 0.4
@export var dialgues:Array[TileResource]


const C_1 = preload("uid://b23ktyi5u0b3k")

var timeline_component:Component = Component.new()
var posi_component:Component = Component.new()
var sprite_component:Component = Component.new()
var hint_component:Component = Component.new()
var index_component:Component =Component.new()
var posi_backgroud_override:Dictionary[Vector2i,Game.BackGround]

var entity_to_free:Array[int]

var presnting_stage:int = normal
@export_group("edge spawn weights")
@export_range(0.0, 1.0, 0.01) var connect_weight:float = 0.2
@export_range(0.0, 1.0, 0.01) var player_fetch_weight:float = 0.15
@export_range(0.0, 1.0, 0.01) var npc_fetch_weight:float = 0.1


func _ready() -> void:
	player.global_position = to_global(map_to_local(Vector2i.ZERO))
	refresh_inner_and_edges(get_camera_rect())
	
	# 写固定的地图
	var fin_point:=Vector2i.ZERO
	var teching_dialgues:Array[int] = [1,2,3,4]
	#teching_dialgues.clear()
	while inner_points.has(fin_point) or not teching_dialgues.is_empty():
		fin_point+= Vector2i.RIGHT
		edges.append(point_to_edge(fin_point,fin_point-Vector2i.RIGHT))
		if not teching_dialgues.is_empty():
			apply_dialgue_at(teching_dialgues.pop_front(),fin_point)
	
	

func _input(event: InputEvent) -> void:
	if !Game.game_mode==Game.GameMode.WALK:return
	if event.is_action_released("move"):
		var desti:= local_to_map(to_local(get_global_mouse_position()))
		#if not can_player_move_to(desti):return
		if desti == player_cell:return
		player_move_to(desti)

func _process(delta: float) -> void:
	queue_redraw()
	process_background_overrides()
	if move_tween:
		if move_tween.is_running():
			return
	var id :=posi_component.value_id_first(player_cell)
	if id>=0:
		if timeline_component.has_entity(id):
			Dialogic.start(timeline_component.entity_find(id))
			timeline_component.entity_free(id)
		if hint_component.has_entity(id):
			var node:= hint_component.entity_free(id) as Node
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
		if index_component.has_entity(id):
			Game.scene_flag |= 1<< index_component.entity_free(id)

func after_player_move():
	print("hints ",hint_component.dense)
	print("free list ",free_list)
	# spawn npc
	var points := new_points.duplicate()
	var target_count := floori(points.size() *npc_spawn_chance)
	if randf() < npc_spawn_chance-target_count:
		target_count+=1
	var id:int
	
	points.shuffle()
	var i :int = 0
	while i < target_count:
		if i >= points.size():break
		var cp :Vector2i= points[i]
		if posi_component.value_id_first(cp)>=0:
			i+=1
			target_count+=1
			continue
		apply_dialgue_at(pick_object(),cp)
		i+=1
	
	# add delet queue
	print("delet points ",delet_points)
	print("player cell",player_cell)
	for cell in delet_points:
		id = posi_component.value_id_first(cell)
		if id<0:continue
		#delet_points.append(id)
		print("free posi",cell)
		print("free id ",id)
		free_entity(id)

func pick_object()->int:
	var index:int = 0
	while index < dialgues.size():
		if (Game.scene_flag & (1<<index)) ==0 :
			return index
		index+=1
	return -1

func custom_free_method(id:int):
	var components:Array[Component] = [
		timeline_component,
		posi_component,
		sprite_component,
		hint_component,
		index_component]
	var value:Variant
	#print(id," is freed")
	for c in components:
		if not c.has_entity(id):continue
		value= c.entity_free(id)
		print(id)
		if value is Node:
			var node:= value as Node
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
			#print("free2 ",id)
			print(id," at ",c.dense)

func apply_dialgue_at(index:int,posi:Vector2i)->int:
	if index <0:return -1
	var id =apply_tile_resource(dialgues[index],posi)
	index_component.entity_add(id,index)
	return id

func apply_tile_resource(res:TileResource,cell:Vector2i)->int:
	var sprite:= Sprite2D.new()
	var hint:Node = gen_at(cell,res.hint)
	
	if not hint:
		printerr("qwhoqw")
		return -1
	var id = create_entity()

	if res.background == Game.BackGround.NONE:
		posi_backgroud_override.erase(cell)
	else:
		posi_backgroud_override[cell] = res.background
		
	timeline_component.entity_add(id,res.tileline_name)
	posi_component.entity_add(id,cell)
	sprite_component.entity_add(id,sprite)
	hint_component.entity_add(id,hint)
	
	sprite.texture = res.sprite
	spawn_at(cell,sprite)
	sprite.position+=res.sprite_offset
	return id

func process_background_overrides() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewport_size := get_viewport_rect().size / camera.zoom
	var camera_rect := Rect2(to_local(camera.get_screen_center_position()) - viewport_size * 0.5, viewport_size)
	var camera_polygon := PackedVector2Array([
		camera_rect.position,
		Vector2(camera_rect.end.x, camera_rect.position.y),
		camera_rect.end,
		Vector2(camera_rect.position.x, camera_rect.end.y),
	])

	for cell:Vector2i in posi_backgroud_override.keys():
		if Geometry2D.intersect_polygons(get_hex_cell_points(cell), camera_polygon).is_empty():
			posi_backgroud_override.erase(cell)

func get_hex_cell_points(cell:Vector2i) -> PackedVector2Array:
	var half_size := Vector2(tile_set.tile_size) * 0.5
	var center := map_to_local(cell)
	return PackedVector2Array([
		center + Vector2(0.0, -half_size.y),
		center + Vector2(half_size.x, -half_size.y * 0.5),
		center + Vector2(half_size.x, half_size.y * 0.5),
		center + Vector2(0.0, half_size.y),
		center + Vector2(-half_size.x, half_size.y * 0.5),
		center + Vector2(-half_size.x, -half_size.y * 0.5),
	])

func gen_edge_weights(new_edge_arr:Array)->PackedFloat32Array:
	var result:PackedFloat32Array
	result.resize(new_edge_arr.size())
	result.fill(1)
	print("new edge size: ",new_edge_arr.size())
	var points:Array[Vector2i]
	for i in new_edge_arr.size():
		points = get_edge_points(new_edge_arr[i])
		for p in points:
			if p in edged_points: result[i] += connect_weight
			for cell:Vector2i in posi_component.values:
				if points_graph_distance(cell,p)>0:
					result[i]+= npc_fetch_weight
			if points_graph_distance(player_cell,p)>0:
				result[i]+=player_fetch_weight
	return result

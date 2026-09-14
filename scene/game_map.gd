extends HexMap
class_name GameMap
enum {normal,preending,end}
@export_range(0.0, 1.0, 0.01) var npc_spawn_chance: float = 0.4
@export var dialgues:Array[TileResource]
@export var end_presenting_dialgues:Array[TileResource]

const C_1 = preload("uid://b23ktyi5u0b3k")

var timeline_component:Component = Component.new()
var posi_component:Component = Component.new()
var sprite_component:Component = Component.new()
var hint_component:Component = Component.new()
var index_component:Component =Component.new()
var background_component:Component =Component.new()
var posi_backgroud_override:Dictionary[Vector2i,Game.BackGround]

var entity_to_free:Array[int]

var end_special_id:int = -1
var end_special_move_tween:Tween

var presnting_stage:int = normal
var boss_waiting:bool = false
@export_group("edge spawn weights")
@export_range(0.0, 1.0, 0.01) var connect_weight:float = 0.2
@export_range(0.0, 1.0, 0.01) var player_fetch_weight:float = 0.15
@export_range(0.0, 1.0, 0.01) var npc_fetch_weight:float = 0.1

func _ready() -> void:
	Dialogic.timeline_ended.connect(Game.change_back_ground.bind(0))
	
	
	player.global_position = to_global(map_to_local(Vector2i.ZERO))
	refresh_inner_and_edges(get_camera_rect())
	
	# 写固定的地图
	var fin_point:=Vector2i.ZERO
	var teching_dialgues:Array[int] #= [1,2,3,4]
	#teching_dialgues.clear()
	while inner_points.has(fin_point) or not teching_dialgues.is_empty():
		fin_point+= Vector2i.RIGHT
		edges.append(point_to_edge(fin_point,fin_point-Vector2i.RIGHT))
		if not teching_dialgues.is_empty():
			apply_dialgue_at(teching_dialgues.pop_front(),fin_point)
	
	

func _input(event: InputEvent) -> void:
	if !Game.game_mode==Game.GameMode.WALK:return
	if boss_waiting:return
	if event.is_action_released("move"):
		var desti:= local_to_map(to_local(get_global_mouse_position()))
		if not can_player_move_to(desti):return
		if desti == player_cell:return
		player_move_to(desti)

func _process(delta: float) -> void:
	
	queue_redraw()
	process_background_overrides()
	if boss_waiting:
		return
	if move_tween and move_tween.is_running():
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
			Game.scene_flag |= 1 << index_component.entity_free(id)
			
		if background_component.has_entity(id):
			Game.change_back_ground(background_component.entity_free(id))
		if (Game.scene_flag & 1 << (dialgues.size()-1))>0:
			presnting_stage = preending
		if (Game.scene_flag & 1 << (dialgues.size()-1+end_presenting_dialgues.size()-1))>0:
			presnting_stage = end
		
		if id == end_special_id:
			boss_waiting = true
			await Dialogic.timeline_ended
			boss_waiting = false
			var dirs:int = hex_neibghbors.pick_random()
			if dirs<3: dirs = hex_neibghbors.pick_random()
			apply_dialgue_at(pick_object(),get_neighbor_cell(player_cell,dirs))
		
		
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
	if not presnting_stage == preending:
		while i < target_count:
			if i >= points.size():break
			var cp :Vector2i= points[i]
			if posi_component.value_id_first(cp)>=0:
				i+=1
				target_count+=1
				continue
			apply_dialgue_at(pick_object(),cp)
			i+=1
	elif end_special_id<0 and not points.is_empty():
		end_special_id = apply_dialgue_at(pick_object(),points[i])
	
	# add delet queue
	for cell in delet_points:
		id = posi_component.value_id_first(cell)
		if id<0:continue
		#delet_points.append(id)
		if id == end_special_id:
			apply_dialgue_at(pick_object(),move_toward1(cell,player_cell))
			continue
		free_entity(id)
 
func move_toward1(from:Vector2i,to:Vector2i)->Vector2i:
	var dir:= Vector2(to-from)
	dir = dir.normalized() * tile_set.tile_size.length()*0.5
	return local_to_map(map_to_local(from)+dir)

func pick_object()->int:
	var index:int = 0
	var size:int = dialgues.size()
	if presnting_stage == preending:
		size+= end_presenting_dialgues.size()
	while index < size:
		if (Game.scene_flag & (1<<index)) ==0 :
			print("Game.scene_flag ",String.num_int64(Game.scene_flag,2))
			print("index ",index)
			return index
		index+=1
	return -1

func custom_free_method(id:int):
	var components:Array[Component] = [
		timeline_component,
		posi_component,
		sprite_component,
		hint_component,
		index_component,
		background_component]
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
	if presnting_stage == preending:
		var end_index := index-dialgues.size()
		if end_index < 0 or end_index >= end_presenting_dialgues.size():
			return -1
		var id := apply_tile_resource(end_presenting_dialgues[end_index],posi)
		if id < 0:
			return -1
		if end_special_id<0:
			index_component.entity_add(id,index)
		elif index_component.has_entity(id):
			index_component.entity_set(id,index)
		else :
			index_component.entity_add(id,index)
		return id
	var id =apply_tile_resource(dialgues[index],posi)
	if id < 0:
		return -1
	index_component.entity_add(id,index)
	return id

func apply_tile_resource(res:TileResource,cell:Vector2i)->int:
	var hint:Node = gen_at(cell,res.hint)
	if presnting_stage == preending and (end_special_id >=0):
		if not posi_component.has_entity(end_special_id) or not sprite_component.has_entity(end_special_id):
			if is_instance_valid(hint):
				hint.queue_free()
			return -1

		var old_cell:Vector2i = posi_component.entity_find(end_special_id)
		if old_cell != cell:
			posi_backgroud_override.erase(old_cell)
		if res.background == Game.BackGround.NONE:
			posi_backgroud_override.erase(cell)
		else:
			posi_backgroud_override[cell] = res.background

		if timeline_component.has_entity(end_special_id):
			timeline_component.entity_set(end_special_id,res.tileline_name)
		else:
			timeline_component.entity_add(end_special_id,res.tileline_name)
		posi_component.entity_set(end_special_id,cell)

		if hint_component.has_entity(end_special_id):
			var old_hint := hint_component.entity_find(end_special_id) as Node
			hint_component.entity_set(end_special_id,hint)
			if is_instance_valid(old_hint) and not old_hint.is_queued_for_deletion():
				old_hint.queue_free()
		else:
			hint_component.entity_add(end_special_id,hint)

		if background_component.has_entity(end_special_id):
			background_component.entity_set(end_special_id,res.background)
		else:
			background_component.entity_add(end_special_id,res.background)

		move_end_special_to(sprite_component.entity_find(end_special_id),cell,res.sprite_offset)
		return end_special_id
		
		
	var sprite:= Sprite2D.new()
	
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
	background_component.entity_add(id,res.background)
	
	sprite.texture = res.sprite
	spawn_at(cell,sprite)
	sprite.position+=res.sprite_offset
	return id

func move_end_special_to(node:Node2D,desti:Vector2i,offset:Vector2):
	if end_special_move_tween and end_special_move_tween.is_running():
		end_special_move_tween.kill()
	end_special_move_tween = create_tween()
	end_special_move_tween.tween_property(
		node,
		"position",
		map_to_local(desti) + offset,
		move_duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

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

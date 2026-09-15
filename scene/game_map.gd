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
var ending:bool = false

@export_group("ending")
@export var end_dilgue:String
@export var player_charactor_scene:PackedScene = preload("res://scene/charactor_scene/kai.tscn")
@export var charlotte_charactor_scene:PackedScene = preload("res://scene/charactor_scene/charoltte.tscn")
@export var charlotte_offset:Vector2 = Vector2(72.0, 0.0)
var ending_charactors:Array[Charactor] = []
@export_group("edge spawn weights")
@export_range(0.0, 1.0, 0.01) var connect_weight:float = 0.2
@export_range(0.0, 1.0, 0.01) var player_fetch_weight:float = 0.15
@export_range(0.0, 1.0, 0.01) var npc_fetch_weight:float = 0.1
@onready var voronoi_point_emmitor: VoronoiEmitor = %VoronoiPointEmmitor
@onready var path_painting: Node2D = $"../anti_color/path_painting"

func _ready() -> void:
	Dialogic.timeline_ended.connect(Game.change_back_ground.bind(0))
	
	
	player.global_position = to_global(map_to_local(Vector2i.ZERO))
	refresh_inner_and_edges(get_camera_rect())
	
	# 写固定的地图
	var fin_point:=Vector2i.ZERO
	var teching_dialgues:Array[int] = [1,2,3,4]
	teching_dialgues.clear()
	while inner_points.has(fin_point) or not teching_dialgues.is_empty():
		fin_point+= Vector2i.RIGHT
		edges.append(point_to_edge(fin_point,fin_point-Vector2i.RIGHT))
		if not teching_dialgues.is_empty():
			apply_dialgue_at(teching_dialgues.pop_front(),fin_point)
	
## 结尾演出：铺出玩家与夏洛特的人物场景，注册到对话气泡布局，
## 再启动结尾 timeline。注册后气泡会指向对应角色的 dialogue_anchor。
func end_game() -> void:
	if ending:
		return
	ending = true
	presnting_stage = end
	spawn_ending_charactors()
	voronoi_point_emmitor.force_background = true
	path_painting.hide()
	# register_character 是文本气泡布局（textp 样式）提供的。
	# 必须先切样式并等布局 ready 再 start：否则 Dialogic 会在布局 ready 时
	# 清状态，随后第一个文本事件用 change_style(base_style="") 回落到默认样式
	# （project.godot 的 layout/default_style 指向不存在的路径），
	# 布局会被换成内置 VisualNovel 布局，气泡注册随之失效。
	Dialogic.Styles.change_style("textp")
	await get_tree().process_frame

	var laylout:= Dialogic.start(end_dilgue)
	if not laylout:
		printerr("end_game: 无法启动 timeline ",end_dilgue)
		return
	if ending_charactors.size() < 2:
		printerr("end_game: 人物场景缺失，无法注册角色")
		return
	if not laylout.has_method("register_character"):
		printerr("end_game: 当前对话布局不支持 register_character（需要 textp 气泡样式）")
		return
	# Dialogic 的文本气泡布局 API：register_character(角色, 气泡指向的节点)
	laylout.register_character("kai",ending_charactors[0].dialogue_anchor)
	laylout.register_character("charlotte",ending_charactors[1].dialogue_anchor)
	# 结尾 timeline 里说话的是 young_chroltte（童年夏洛蒂），
	# 名字对不上就不会把气泡挂到夏洛特身上，这里一起注册。
	laylout.register_character("young_chroltte",ending_charactors[1].dialogue_anchor)

## 在玩家当前位置铺出两个人物场景（玩家位与偏移位），并隐藏地图上的玩家标记
func spawn_ending_charactors() -> void:
	_hide_player_marker()
	ending_charactors.clear()
	var player_posi := player.global_position
	var player_charactor := spawn_charactor(player_charactor_scene,player_posi)
	if player_charactor:
		ending_charactors.append(player_charactor)
	var charlotte_charactor := spawn_charactor(charlotte_charactor_scene,player_posi+charlotte_offset)
	if charlotte_charactor:
		ending_charactors.append(charlotte_charactor)

## 只隐藏玩家身上的可见标记（贴图/调试显示），保留 Camera2D，
## 否则摄像机会随节点一起失效导致画面停住。
func _hide_player_marker() -> void:
	if player == null:
		return
	for child in player.get_children():
		if child is Camera2D:
			continue
		if child is CanvasItem:
			child.visible = false

func spawn_charactor(scene:PackedScene,posi:Vector2)->Charactor:
	if scene == null:
		printerr("spawn_charactor: scene is null")
		return null
	var charactor := scene.instantiate() as Charactor
	if charactor == null:
		printerr("spawn_charactor: scene root is not Charactor")
		return null
	add_child(charactor)
	charactor.global_position = posi
	return charactor

func _input(event: InputEvent) -> void:
	if ending:return
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
	if ending:
		return
	if boss_waiting:
		return
	if move_tween and move_tween.is_running():
		return
	var id :=posi_component.value_id_first(player_cell)
	if id>=0:
		var dialogue_started:bool = false
		var dialogue_index:int = -1
		if timeline_component.has_entity(id):
			Dialogic.start(timeline_component.entity_find(id))
			timeline_component.entity_free(id)
			dialogue_started = true
		if hint_component.has_entity(id):
			var node:= hint_component.entity_free(id) as Node
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()

		if index_component.has_entity(id):
			dialogue_index = index_component.entity_find(id)
			if presnting_stage == preending:
				print("Game.scene_flag ",String.num_int64(Game.scene_flag,2))
				print("index ",dialogue_index)
			Game.scene_flag |= 1 << index_component.entity_free(id)
			
		if background_component.has_entity(id):
			Game.change_back_ground(background_component.entity_free(id))
		# 没有 end_presenting_dialgues 时不存在 boss，preending 永不触发。
		if not end_presenting_dialgues.is_empty()\
				and (Game.scene_flag & 1 << (dialgues.size()-1))>0:
			presnting_stage = preending

		# 没有启动对话就没什么要等的（否则 timeline_ended 永远不来，
		# boss_waiting 卡死会导致无法移动）。
		if not dialogue_started:
			return

		# 全序列最后一段的下标：普通序列 dialgues.size() 段之后，
		# 还有 end 序列 n 段，所以最后一段是 dialgues.size()-1+n。
		# end_presenting_dialgues 为空时它就退化为最后一段普通对话。
		# 这一段播完直接进入结尾演出（end_game），不再挪窝。
		if dialogue_index == dialgues.size() + end_presenting_dialgues.size() - 1:
			boss_waiting = true
			await Dialogic.timeline_ended
			boss_waiting = false
			end_game()
			return

		# 其余 end 对话播完后，boss 挪到玩家相邻的随机格并换下一段。
		if id == end_special_id:
			boss_waiting = true
			await Dialogic.timeline_ended
			boss_waiting = false
			var dirs:int = hex_neibghbors.pick_random()
			if dirs<3: dirs = hex_neibghbors.pick_random()
			relocate_end_special(get_neighbor_cell(player_cell,dirs),dialogue_index)
		
		
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
		# 最后一段对话是结尾演出（end_game）的触发点，整图同时只保留
		# 一份；否则它会像普通对话一样在每个刷怪点重复出现。
		var last_index := dialgues.size()-1
		var ending_exists:bool = index_component.values.has(last_index)
		while i < target_count:
			if i >= points.size():break
			var cp :Vector2i= points[i]
			if posi_component.value_id_first(cp)>=0:
				i+=1
				target_count+=1
				continue
			var picked:int = pick_object()
			if picked == last_index and ending_exists:
				break
			apply_dialgue_at(picked,cp)
			if picked == last_index:
				ending_exists = true
			i+=1
	elif end_special_id<0 and not points.is_empty():
		end_special_id = apply_dialgue_at(pick_object(),points[i])
	
	# add delet queue
	for cell in delet_points:
		id = posi_component.value_id_first(cell)
		if id<0:continue
		#delet_points.append(id)
		if id == end_special_id:
			var boss_index:int = -1
			if index_component.has_entity(id):
				boss_index = index_component.entity_find(id)
			relocate_end_special(move_toward1(cell,player_cell),boss_index)
			continue
		free_entity(id)

## 把 end special 挪到 desti，并换上下一段 end 对话；end 对话
## 都放完时复用 fallback_index 对应的那段，保证还能再次对话。
func relocate_end_special(desti:Vector2i,fallback_index:int)->void:
	var next_index:int = fallback_index
	if presnting_stage == preending:
		var picked:int = pick_object()
		if picked >= dialgues.size():
			next_index = picked
	if next_index < dialgues.size() or next_index >= dialgues.size()+end_presenting_dialgues.size():
		printerr("relocate_end_special: no valid end dialogue index ",next_index)
		return
	if apply_end_special(end_presenting_dialgues[next_index-dialgues.size()],desti) < 0:
		printerr("relocate_end_special: apply failed at ",desti)
		return
	if index_component.has_entity(end_special_id):
		index_component.entity_set(end_special_id,next_index)
	else:
		index_component.entity_add(end_special_id,next_index)
 
func move_toward1(from:Vector2i,to:Vector2i)->Vector2i:
	var dir:= Vector2(to-from)
	dir = dir.normalized() * tile_set.tile_size.length()*0.5
	return local_to_map(map_to_local(from)+dir)

func pick_object()->int:
	var index:int = 0
	var size:int = dialgues.size()
	if presnting_stage == preending:
		# preending 只能挑 end_presenting 区间的对话，普通对话区间
		# 的下标会让 apply_dialgue_at 返回 -1，boss 会留在原地。
		index = dialgues.size()
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

## 把已有的 end special 实体迁移到 cell 并套用 res 的对话/贴图/背景。
## 不依赖 presnting_stage，专供 boss 循环挪窝使用。
func apply_end_special(res:TileResource,cell:Vector2i)->int:
	if end_special_id < 0:
		return -1
	if not posi_component.has_entity(end_special_id) or not sprite_component.has_entity(end_special_id):
		return -1

	var hint:Node = gen_at(cell,res.hint)
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

func apply_tile_resource(res:TileResource,cell:Vector2i)->int:
	if presnting_stage == preending and (end_special_id >=0):
		return apply_end_special(res,cell)
	var hint:Node = gen_at(cell,res.hint)

	if res.sprite == null:
		printerr("apply_tile_resource: sprite scene is null")
		return -1
	var sprite := res.sprite.instantiate() as Node2D
	if sprite == null:
		printerr("apply_tile_resource: sprite scene root is not Node2D")
		return -1

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

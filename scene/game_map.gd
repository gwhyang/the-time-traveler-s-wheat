extends HexMap
@export_range(0.0, 1.0, 0.01) var npc_spawn_chance: float = 0.4


const C_1 = preload("uid://b23ktyi5u0b3k")

var timeline_component:Component = Component.new()
var posi_component:Component = Component.new()
var sprite_component:Component = Component.new()
var hint_component:Component = Component.new()

var entity_to_free:Array[int]


func _process(delta: float) -> void:
	queue_redraw()
	var id :=posi_component.value_id_first(player_cell)
	if id>=0:
		if timeline_component.has_entity(id):
			Dialogic.start(timeline_component.entity_find(id))
			timeline_component.entity_free(id)
		if hint_component.has_entity(id):
			print(id)
			var node:= hint_component.entity_free(id) as Node
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
			print(id," at ",hint_component.dense)

func after_player_move():
	print("hints ",hint_component.dense)
	print("free list ",free_list)
	# spawn npc
	var points := new_points.duplicate()
	var target_count := floori(points.size() *npc_spawn_chance)
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
		apply_tile_resource(C_1,cp)
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

func custom_free_method(id:int):
	var components:Array[Component] = [
		timeline_component,
		posi_component,
		sprite_component,
		hint_component]
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


func apply_tile_resource(res:TileResource,cell:Vector2i):
	var sprite:= Sprite2D.new()
	var hint:Node = gen_at(cell,res.hint)
	
	if not hint:
		printerr("qwhoqw")
		return
	var id = create_entity()
		
	timeline_component.entity_add(id,res.tileline_name)
	posi_component.entity_add(id,cell)
	sprite_component.entity_add(id,sprite)
	hint_component.entity_add(id,hint)
	
	sprite.texture = res.sprite
	spawn_at(cell,sprite)
	sprite.position+=res.sprite_offset

extends HexMap
@export_range(0.0, 1.0, 0.01) var npc_spawn_chance: float = 0.4


const C_1 = preload("uid://b23ktyi5u0b3k")

var timeline_component:Component = Component.new()
var posi_component:Component = Component.new()
var sprite_component:Component = Component.new()
var hint_component:Component = Component.new()



func _process(delta: float) -> void:
	queue_redraw()
	var id :=posi_component.value_id_first(player_cell)
	if id>=0:
		if timeline_component.has_entity(id):
			Game.disable_move = true
			Dialogic.start(timeline_component.entity_find(id))
			timeline_component.entity_free(id)
		if hint_component.has_entity(id):
			var node:= hint_component.entity_find(id) as Node
			node.queue_free()
			hint_component.entity_free(id)

func after_player_move():
	# spawn npc
	var points := new_points.duplicate()
	var target_count := floori(points.size() *npc_spawn_chance)
	points.shuffle()
	for i in target_count:
		apply_tile_resource(C_1,points[i])
	
	


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

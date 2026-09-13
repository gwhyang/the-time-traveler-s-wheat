extends VoronoiDivision
class_name VoronoiEmitor

const sceen_dot_index:float = 100.0*6*6*0.2/3.5
const min_count:int = 40
enum RenderTarget { BACKGROUND, OVERRIDER }

@export var angular_speed_range:Vector2
@export var radius_range:Vector2
@export var move_speed:Vector2
@export var create_interval:float = 0.5
@export var create_count_range:Vector2i = Vector2i(2,5)
var seted_color:int = 0
var create_count_down:float = 0
var indexes:Array[int]
var render_target:Dictionary[int,int]
var polar_points:Component = Component.new()
var radii:Component = Component.new()
var angulur:Component = Component.new()
var color:Component = Component.new()
var angulur_speed:Component = Component.new()
var polygons:Array[PackedVector2Array]

var slice:float
var max_point_count:int

func _ready() -> void:
	Game.background_changed.connect(func(c:int):seted_color=c)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	queue_redraw()
	max_point_count = sceen_dot_index/create_interval/(move_speed.x*move_speed.x)*0.5*(create_count_range.x+create_count_range.y)
	max_point_count = maxi(max_point_count,min_count)
	#print(sceen_dot_index)
	#print(max_point_count)
	create_count_down -= delta
	if create_count_down <= 0:
		create_count_down = create_interval
		var create_count:= randi_range(create_count_range.x,create_count_range.y)
		var diff:float = TAU*randf()
		slice = TAU/create_count
		for i in create_count:
			indexes.append(add_point(0.02,diff+i*slice))
	deal_points(delta)
	
	
func deal_points(delta:float):
	var count:int = maxi(indexes.size() - max_point_count, 0)
	for i in count:
		free_entity(indexes.pop_front())
	for id in indexes:
		polar_points.entity_set(id,polar_points.entity_find(id)+move_speed*delta)
		angulur.entity_set(id,angulur.entity_find(id)+angulur_speed.entity_find(id)*delta)

func _draw() -> void:
	var points:Array[Vector2] = []
	var posi:Vector2
	var polar_posi:Vector2
	for i in indexes:
		polar_posi=polar_points.entity_find(i)
		polar_posi.x*=polar_posi.x
		#if i%2==0:
			#polar_posi.y = -polar_posi.y
		posi = polar2eulur(polar_posi)+polar2eulur(
			Vector2(radii.entity_find(i),angulur.entity_find(i)))
		points.append(to_global(posi))
		
	polygons= get_voronoi_polygons(points)
	for i in indexes.size():
		var id := indexes[i]
		if render_target[id] != RenderTarget.BACKGROUND or polygons[i].is_empty():
			continue
		var local_polygon := PackedVector2Array()
		for point in polygons[i]:
			local_polygon.append(to_local(point))
		draw_colored_polygon(local_polygon,color.entity_find(id))

func add_point(l:float,theta:float)->int:
	var id:= create_entity()
	render_target[id] = RenderTarget.BACKGROUND if seted_color == 0 else RenderTarget.OVERRIDER
	polar_points.entity_add(id,Vector2(l,theta))
	radii.entity_add(id,randf_range(radius_range.x,radius_range.y))
	angulur.entity_add(id,randf_range(angular_speed_range.x,angular_speed_range.y))
	if seted_color == 0:
		color.entity_add(id,Color(randi_range(0,5)/6.0,0,0))
	else:
		color.entity_add(id,Color((seted_color-1)/6.0,0,0))
	angulur_speed.entity_add(id,randf_range(angular_speed_range.x,angular_speed_range.y))
	return id

func polar2eulur(polar:Vector2)->Vector2:
	return Vector2(polar.x*cos(polar.y),polar.x*sin(polar.y))


#region ecs

var max_id:int = 0
var entity_size:int = 0
var entity:Array[int]
var free_list:Array[int]
var sparse_entity:PackedInt32Array
func create_entity()->int:
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
	if not has_entity(id):return
	var last_id:int = entity[-1]
	sparse_entity[last_id] = sparse_entity[id]
	entity[sparse_entity[id]] = last_id
	
	entity.pop_back()
	entity_size-=1
	free_list.append(id)
	render_target.erase(id)
	custom_free_method(id)

func has_entity(id:int)->bool:
	if id >= max_id:return false
	return entity[sparse_entity[id]] == id

func custom_free_method(id:int):
	polar_points.entity_free(id)
	radii.entity_free(id)
	angulur.entity_free(id)
	color.entity_free(id)
	angulur_speed.entity_free(id)

class Component:
	var dense:Array[int] = []
	var sparse:PackedInt32Array = []
	var values:Array = []
	var sparse_size:int = 0
	
	func entity_find(id:int)->Variant:
		if not has_entity(id):return null
		return values[sparse[id]]
	
	func entity_set(id:int,value:Variant):
		if not has_entity(id):return
		values[sparse[id]] = value
		
	
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
	
	func entity_free(id:int)->Variant:
		if not has_entity(id):
			return null
		var dense_index0:int = sparse[id]
		var last_id:int = dense[-1]
		var freed_value:Variant = values[dense_index0]
		
		sparse[last_id] =dense_index0
		dense[dense_index0] = dense[-1]
		values[dense_index0] = values[-1]
		
		dense.pop_back()
		values.pop_back()
		return freed_value
	
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


func _on_button_2_pressed() -> void:
	seted_color = 0


func _on_button_pressed() -> void:
	seted_color = randi_range(1, 6)

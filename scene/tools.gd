extends Node
@export var view_ports:Array[SubViewport]

@export var sync_cameras:Array[Camera2D]
@onready var camera_2d: Camera2D = %Camera2D
@onready var street: TextureRect = $"../backgrounds/street"
@onready var street1: TextureRect = $"../backgrounds2/street"
@onready var timer: Timer = $Timer
const street_rain = preload("uid://b1g113gxitkm2")
const street_normal = preload("uid://brrmm2x7vtdbg")

func _ready() -> void:
	get_viewport().size_changed.connect(sync_viewport_size)
	sync_viewport_size()
	Game.street_rian.connect(func(c:bool):
		if c:
			street.texture = street_rain
			street1.texture = street_rain
		else:
			street.texture = street_normal
			street1.texture = street_normal
		)
	Game.game_end.connect(timer.start)
	
	
func _process(delta: float) -> void:
	for camera in sync_cameras:
		camera.global_position = camera_2d.global_position

func sync_viewport_size() -> void:
	var viewport_size:Vector2i = get_viewport().size
	for view_port in view_ports:
		if view_port.size!=viewport_size:
			view_port.size = viewport_size
			

func random_background():
	Game.change_back_ground(randi_range(1,6))
	
	
	
	

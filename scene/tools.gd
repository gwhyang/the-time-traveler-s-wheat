extends Node
@export var view_ports:Array[SubViewport]

@export var sync_cameras:Array[Camera2D]
@onready var camera_2d: Camera2D = %Camera2D

func _ready() -> void:
	get_viewport().size_changed.connect(sync_viewport_size)
	sync_viewport_size()

func _process(delta: float) -> void:
	for camera in sync_cameras:
		camera.global_position = camera_2d.global_position

func sync_viewport_size() -> void:
	var viewport_size:Vector2i = get_viewport().size
	for view_port in view_ports:
		if view_port.size!=viewport_size:
			view_port.size = viewport_size
			

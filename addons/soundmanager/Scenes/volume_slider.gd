extends HSlider
class_name VolumeSlider
@export var bus:StringName = "Master"
@onready var bus_index:int = AudioServer.get_bus_index(bus)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	value = AudioServer.get_bus_volume_linear(bus_index)
	value_changed.connect(_on_value_changed)

func _on_value_changed(v:float) -> void:
	AudioServer.set_bus_volume_linear(bus_index,value)

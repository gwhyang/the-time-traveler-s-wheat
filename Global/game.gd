extends Node
enum GameMode{WALK,DIALOGUE}
enum BackGround{NONE,HOME,STREET,CLASSROOM,CORRIDOR,LAKE,LAB}
var game_mode:GameMode=GameMode.WALK
var scene_flag:int = 1
func _ready() -> void:
	Dialogic.timeline_started.connect(on_timeline_start)
	Dialogic.timeline_ended.connect(on_timeline_end)

func on_timeline_start():
	game_mode = GameMode.DIALOGUE
	
func on_timeline_end():
	game_mode = GameMode.WALK

extends Node
enum GameMode{WALK,DIALOGUE}
var game_mode:GameMode=GameMode.WALK

func _ready() -> void:
	Dialogic.timeline_started.connect(on_timeline_start)
	Dialogic.timeline_ended.connect(on_timeline_end)

func on_timeline_start():
	game_mode = GameMode.DIALOGUE
	
func on_timeline_end():
	game_mode = GameMode.WALK

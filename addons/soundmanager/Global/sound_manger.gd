extends Node
@export var fade_out_time:float = 5
@export var fade_in_time:float = 4
@export var bgm_wait_timer:float = 2

@onready var sfx:Node = $SFX
@onready var music:Node = $Music

var sfx_dict :={}
#var music_dict :={}

var music_play_list:Array[AudioStreamPlayer]

var is_background_playing:bool
var current_player:AudioStreamPlayer
var fade_out_tween:Tween
var fade_in_tween:Tween

signal music_finished

 #Called when the node enters the scene tree for the first time.
func _ready():
	for child in sfx.get_children():
		if child is AudioStreamPlayer:
			sfx_dict[child.name.to_lower()] = child
	
	#for child in music.get_children():
		#if child is AudioStreamPlayer:
			#child.finished.connect(on_music_finished)
	#
	#is_background_playing = true
	#on_music_finished()

	
func sfx_play(SFXname:String) -> void :
	var sound_name := SFXname.to_lower()
	var player = sfx_dict.get(sound_name) as AudioStreamPlayer
	if player: player.play()
	else: printerr(SFXname," is not included in SFX")

func music_play(music_name:String) -> void:
	print("music: ",music_name)
	if fade_out_tween and fade_out_tween.is_running():
		fade_out_tween.kill()
	if current_player:
		var post_player := current_player
		fade_out_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		fade_out_tween.tween_property(post_player,"volume_linear",0,fade_out_time)
		fade_out_tween.finished.connect(func():
			post_player.stop()
			post_player.volume_linear = 1
			)
	await get_tree().create_timer(bgm_wait_timer)
	current_player = music.get_node(music_name) as AudioStreamPlayer
	if current_player: 
		current_player.volume_linear = 0
		current_player.play()
		fade_in_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		fade_in_tween.tween_property(current_player,"volume_linear",1,fade_in_time)
	else: printerr(music_name," is not included in SFX")

#func play_music_random(index_list:Array[int]) -> void:
	#var random_array = range(index_list.size())
	#random_array.shuffle()
	#is_background_playing = true
	#for i:int in random_array:
		#if music.get_children()[index_list[i]] is AudioStreamPlayer:
			#music.get_children()[index_list[i]].play()
			#await music.get_children()[index_list[i]].finished
	#is_background_playing = false
#
#func get_random_music_list() -> Array[AudioStreamPlayer]:
	#var result:Array[AudioStreamPlayer]
	#for child in music.get_children():
		#if child is AudioStreamPlayer:
			#result.append(child)
	#return result
#
#func on_music_finished()->void:
	#if not is_background_playing:
		#return
	#if music_play_list.is_empty():
		#music_play_list = get_random_music_list()
		#music_play_list.shuffle()
	#var audio = music_play_list.pop_back() as AudioStreamPlayer
	#audio.play()

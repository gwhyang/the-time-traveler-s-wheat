extends Node2D

@export var move_speed: float = 360.0


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	position += direction.normalized() * move_speed * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.72, 0.22))
	draw_circle(Vector2.ZERO, 8.0, Color(0.22, 0.12, 0.04))
	draw_line(Vector2(0, -20), Vector2(0, -34), Color(1.0, 0.72, 0.22), 4.0, true)

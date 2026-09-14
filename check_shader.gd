extends SceneTree

func _initialize() -> void:
	var shader: Shader = load("res://scripts/voronoi_edge_outline.gdshader")
	if shader == null:
		push_error("shader load failed")
	else:
		print("SHADER_OK code=", shader.get_rid().is_valid() if shader.get_rid() != null else "?")
	quit(0)

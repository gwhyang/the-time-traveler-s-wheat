shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float white_threshold : hint_range(0.0, 1.0) = 0.95;

void fragment() {
	vec4 sampled_color = texture(TEXTURE, UV);
	float white = step(white_threshold, min(sampled_color.r, min(sampled_color.g, sampled_color.b)));
	if (white < 0.5 || sampled_color.a <= 0.0) {
		discard;
	}

	vec4 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0);
	COLOR = vec4(1.0 - screen_color.rgb, sampled_color.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}

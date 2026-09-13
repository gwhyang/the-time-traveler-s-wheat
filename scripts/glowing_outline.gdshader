shader_type canvas_item;
render_mode unshaded;

const int DIRECTION_COUNT = 8;
const int GLOW_SAMPLE_COUNT = 8;
const float FULL_CIRCLE = 6.2831853;

uniform vec4 boundary_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float boundary_width : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float glow_radius : hint_range(0.0, 32.0, 0.1) = 8.0;
uniform float glow_opacity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float glow_falloff : hint_range(0.1, 4.0, 0.1) = 2.0;

void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	float center_mask = smoothstep(alpha_threshold, 1.0, center_alpha);
	float boundary_mask = center_mask;
	float glow_mask = 0.0;

	for (int direction = 0; direction < DIRECTION_COUNT; direction++) {
		float angle = FULL_CIRCLE * float(direction) / float(DIRECTION_COUNT);
		vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * boundary_width;
		boundary_mask = max(boundary_mask, smoothstep(alpha_threshold, 1.0, texture(TEXTURE, UV + offset).a));
	}

	float outside_mask = 1.0 - boundary_mask;
	for (int sample_index = 1; sample_index <= GLOW_SAMPLE_COUNT; sample_index++) {
		float sample_distance = glow_radius * float(sample_index) / float(GLOW_SAMPLE_COUNT);
		float weight = pow(1.0 - float(sample_index) / float(GLOW_SAMPLE_COUNT), glow_falloff);
		for (int direction = 0; direction < DIRECTION_COUNT; direction++) {
			float angle = FULL_CIRCLE * float(direction) / float(DIRECTION_COUNT);
			vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * sample_distance;
			float sampled_mask = smoothstep(alpha_threshold, 1.0, texture(TEXTURE, UV + offset).a);
			glow_mask = max(glow_mask, sampled_mask * weight);
		}
	}
	glow_mask *= outside_mask;

	float boundary_alpha = boundary_mask * boundary_color.a;
	float halo_alpha = glow_mask * glow_opacity * glow_color.a;
	float output_alpha = boundary_alpha + halo_alpha * (1.0 - boundary_alpha);
	if (output_alpha <= 0.001) {
		discard;
	}

	vec3 output_color = (
		boundary_color.rgb * boundary_alpha
		+ glow_color.rgb * halo_alpha * (1.0 - boundary_alpha)
	) / output_alpha;
	COLOR = vec4(output_color, output_alpha);
}

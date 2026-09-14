shader_type canvas_item;
render_mode unshaded;

const int DIRECTION_COUNT = 8;
const int GLOW_SAMPLE_COUNT = 12;
const float FULL_CIRCLE = 6.2831853;

uniform sampler2D source_texture;
uniform vec4 boundary_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float edge_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float boundary_width : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float glow_radius : hint_range(0.0, 32.0, 0.1) = 8.0;
uniform float glow_opacity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float glow_falloff : hint_range(0.1, 4.0, 0.1) = 2.0;

float alpha_mask(vec2 uv) {
	return smoothstep(alpha_threshold, 1.0, texture(source_texture, uv).a);
}

// Detect a change between the current pixel and its neighborhood.
float edge_test(vec2 uv, vec2 texel_size) {
	float center = alpha_mask(uv);
	float edge = 0.0;

	for (int direction = 0; direction < DIRECTION_COUNT; direction++) {
		float angle = FULL_CIRCLE * float(direction) / float(DIRECTION_COUNT);
		vec2 offset = vec2(cos(angle), sin(angle))
			* texel_size
			* boundary_width;
		edge = max(edge, abs(center - alpha_mask(uv + offset)));
	}

	return smoothstep(edge_threshold, 1.0, edge);
}

void fragment() {
	vec2 texel_size = TEXTURE_PIXEL_SIZE;
	float center_mask = alpha_mask(UV);
	float glow_mask = 0.0;

	for (int sample_index = 1; sample_index <= GLOW_SAMPLE_COUNT; sample_index++) {
		float distance_ratio = float(sample_index) / float(GLOW_SAMPLE_COUNT);
		float sample_distance = glow_radius * distance_ratio;
		float weight = pow(max(0.0, 1.0 - distance_ratio), glow_falloff);

		for (int direction = 0; direction < DIRECTION_COUNT; direction++) {
			float angle = FULL_CIRCLE * float(direction) / float(DIRECTION_COUNT);
			vec2 offset = vec2(cos(angle), sin(angle)) * texel_size * sample_distance;
			float sampled_edge = edge_test(UV + offset, texel_size);
			glow_mask = max(glow_mask, sampled_edge * weight);
		}
	}

	// Keep the source line as the opaque dark boundary and keep the halo outside it.
	float boundary_alpha = center_mask * boundary_color.a;
	glow_mask *= 1.0 - center_mask;
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

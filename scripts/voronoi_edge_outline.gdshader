// Overlay outline + glow for the voronoi background, modeled on glowing_outline.gdshader.
// Only the boundary line and the translucent halo are drawn; the
// rendering underneath (cell colors) is left untouched, so this material
// sits on a full-rect node above the voronoi background. Edge detection
// compares neighboring cell colors of source_texture instead of alpha.
//
// source_texture: the voronoi background rendering. Attach the material
// to a node that displays the same texture (Sprite2D / TextureRect), so
// TEXTURE_PIXEL_SIZE matches.
// Note: two adjacent cells sharing the same encoded color are invisible
// to color-based edge detection.
shader_type canvas_item;
render_mode unshaded;

const int DIRECTION_COUNT = 8;
const int GLOW_SAMPLE_COUNT = 12;
const float FULL_CIRCLE = 6.2831853;

uniform sampler2D source_texture;
uniform vec4 boundary_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_threshold : hint_range(0.0, 1.0, 0.001) = 0.02;
uniform float edge_softness : hint_range(0.0, 1.0, 0.001) = 0.05;
uniform float boundary_width : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float glow_radius : hint_range(0.0, 32.0, 0.1) = 8.0;
uniform float glow_opacity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float glow_falloff : hint_range(0.1, 4.0, 0.1) = 2.0;

// Detect a change between the current pixel's cell color and its
// neighborhood (color-difference edge test instead of alpha).
float edge_test(vec2 uv, vec2 texel_size) {
	vec4 center = texture(source_texture, uv);
	float edge = 0.0;

	for (int direction = 0; direction < DIRECTION_COUNT; direction++) {
		float angle = FULL_CIRCLE * float(direction) / float(DIRECTION_COUNT);
		vec2 offset = vec2(cos(angle), sin(angle))
			* texel_size
			* boundary_width;
		float difference = length(texture(source_texture, uv + offset) - center);
		edge = max(edge, smoothstep(edge_threshold, edge_threshold + edge_softness, difference));
	}

	return edge;
}

void fragment() {
	vec2 texel_size = TEXTURE_PIXEL_SIZE;
	float boundary = edge_test(UV, texel_size);
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

	// Overlay-only output: the cell colors underneath stay untouched, so
	// keep the halo off the boundary line and blend the halo on top of it.
	glow_mask *= 1.0 - boundary;
	float boundary_alpha = boundary * boundary_color.a;
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

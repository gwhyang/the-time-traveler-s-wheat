// Screen-space outline for the voronoi background.
// Unlike vornoi_line_painting.gd, which draws polylines from the cell
// polygons directly, this shader reads the already-drawn screen and
// detects edges by comparing each pixel with its neighborhood, so it
// needs no geometry data at all.
//
// Usage:
//   Put this material on a full-rect node (ColorRect / TextureRect)
//   that is drawn AFTER the voronoi background in the scene tree.
//
// Note:
//   Edge detection relies on neighboring cells having different colors.
//   voronoi_background.gd encodes cell colors as Color(i / 6, 0, 0), so
//   two adjacent cells may accidentally share a color and their shared
//   border will be invisible to this shader. If that matters, encode a
//   unique per-cell id into more channels (e.g. also use g/b) instead.
shader_type canvas_item;
render_mode unshaded;

const int DIRECTION_COUNT = 8;
const int MAX_RING_COUNT = 8;
const float FULL_CIRCLE = 6.2831853;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float outline_width : hint_range(0.0, 8.0, 0.1) = 1.0;
uniform float edge_threshold : hint_range(0.0, 1.0, 0.001) = 0.02;
uniform float edge_softness : hint_range(0.0, 1.0, 0.001) = 0.05;
uniform float outline_opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

// A pixel is on an edge when any sampled neighbor differs enough from
// the center color. Nearest filtering keeps the encoded cell colors
// from being blended before the comparison.
float edge_test(vec2 uv, vec2 texel_size) {
	vec4 center = texture(screen_texture, uv);
	float ring_count = clamp(ceil(outline_width), 1.0, float(MAX_RING_COUNT));
	float edge = 0.0;

	for (int ring = 1; ring <= MAX_RING_COUNT; ring++) {
		float ring_distance = float(ring);
		if (ring_distance > ring_count) {
			break;
		}
		for (int direction = 0; direction < DIRECTION_COUNT; direction++) {
			float angle = FULL_CIRCLE * float(direction) / float(DIRECTION_COUNT);
			vec2 offset = vec2(cos(angle), sin(angle)) * texel_size * ring_distance;
			float difference = length(texture(screen_texture, uv + offset) - center);
			edge = max(edge, smoothstep(edge_threshold, edge_threshold + edge_softness, difference));
		}
	}

	return edge;
}

void fragment() {
	float edge = edge_test(UV, SCREEN_PIXEL_SIZE);
	float outline_alpha = edge * outline_color.a * outline_opacity;
	if (outline_alpha <= 0.001) {
		discard;
	}
	COLOR = vec4(outline_color.rgb, outline_alpha);
}

shader_type canvas_item;

uniform sampler2D based_on;
uniform vec4 match_color = vec4(1);
uniform float tolerance:hint_range(0.0, .30, 0.001) = 0.1;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	if(length(texture(based_on,UV) - match_color)>tolerance){
		discard;
	}
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}

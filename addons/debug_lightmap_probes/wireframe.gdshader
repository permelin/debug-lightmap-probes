shader_type spatial;
render_mode unshaded, wireframe, cull_disabled, depth_draw_never;

uniform vec3 albedo: source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = albedo;
}


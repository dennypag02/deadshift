shader_type canvas_item;
render_mode unshaded;
uniform float outline_texels = 6.0;
uniform vec4 outline_color : source_color = vec4(0.055, 0.048, 0.035, 1.0);
varying vec4 actor_modulate;
void vertex() {
	actor_modulate = COLOR;
	VERTEX += sign(VERTEX) * outline_texels;
}
void fragment() {
	vec2 uv = (UV - vec2(0.5)) * (vec2(1.0) + 2.0 * outline_texels * TEXTURE_PIXEL_SIZE) + vec2(0.5);
	vec2 d = TEXTURE_PIXEL_SIZE * outline_texels;
	vec4 original = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	float a = original.a;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) a = 0.0;
	float ring = 0.0;
	float inside = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 at = uv + vec2(float(x), float(y)) * d;
			float v = texture(TEXTURE, clamp(at, vec2(0.0), vec2(1.0))).a;
			if (any(lessThan(at, vec2(0.0))) || any(greaterThan(at, vec2(1.0)))) v = 0.0;
			ring = max(ring, v);
			inside = min(inside, v);
		}
	}
	float fringe = (1.0 - inside) * step(0.80, min(original.r, min(original.g, original.b)));
	vec3 body = mix(original.rgb, outline_color.rgb, fringe);
	COLOR = vec4(mix(outline_color.rgb, body, a), max(a, ring * outline_color.a)) * actor_modulate;
}

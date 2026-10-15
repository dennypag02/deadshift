shader_type canvas_item;
render_mode unshaded;
varying vec4 rect_uv;
varying vec4 tint;
void vertex() {
	rect_uv = INSTANCE_CUSTOM;
	tint = COLOR;
}
void fragment() {
	COLOR = texture(TEXTURE, rect_uv.xy + UV * rect_uv.zw) * tint;
}

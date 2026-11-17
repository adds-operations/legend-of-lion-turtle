shader_type canvas_item;
render_mode unshaded;

uniform vec4 spirit_color : source_color = vec4(0.70, 0.62, 1.0, 1.0);
uniform float body_opacity : hint_range(0.0, 1.0) = 0.48;

void fragment() {
    vec4 shaded = COLOR;
    float luminance = dot(shaded.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 tint = spirit_color.rgb * mix(0.55, 1.2, luminance);
    COLOR = vec4(mix(shaded.rgb, tint, 0.78), shaded.a * body_opacity);
}

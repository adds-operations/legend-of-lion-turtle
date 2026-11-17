shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 center = vec2(0.0);
uniform vec2 radii = vec2(90.0, 55.0);
uniform float phase = 0.0;
uniform bool ellipse_fade = true;
varying vec2 arena_pixel;

void vertex() {
    arena_pixel = VERTEX;
}

void fragment() {
    vec2 pixel = floor(arena_pixel / 2.0) * 2.0;
    vec2 p = (pixel - center) / radii;
    float edge = ellipse_fade ? 1.0 - smoothstep(0.72, 0.92, length(p)) : 0.75;
    vec2 tile = floor(pixel / vec2(36.0, 19.0));
    float seed = fract(sin(dot(tile, vec2(13.93, 73.31))) * 43758.5453);
    vec2 local = mod(pixel, vec2(36.0, 19.0));
    float travel = 5.0 + mod(TIME * 5.0 + seed * 14.0, 15.0);
    float line_x = step(travel, local.x) * (1.0 - step(travel + 7.0 + seed * 6.0, local.x));
    float line_y = step(2.0 + 9.0 * seed, local.y) * (1.0 - step(4.0 + 9.0 * seed, local.y));
    float shimmer = pow(0.5 + 0.5 * sin(TIME * 1.8 + seed * 23.0 + phase), 2.0);
    COLOR = vec4(0.71, 0.91, 0.95, line_x * line_y * edge * shimmer * 0.23);
}

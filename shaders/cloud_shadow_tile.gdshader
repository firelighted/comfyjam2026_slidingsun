shader_type canvas_item;
// Credit to H29 on GodotShaders.com
// https://godotshaders.com/shader/draws-a-rounded-rectangle-with-animated-distorted-edges/

uniform float height: hint_range(0.0, 0.5, 0.01) = 0.0;//Rectangle height
uniform float width: hint_range(0.0, 0.5, 0.01) = 0.0;//Rectangle width
uniform float radius: hint_range(0.0, 0.5, 0.01) = 0.0;//Rectangle corner radius
uniform float speed: hint_range(0.0, 1.0, 0.01) = 0.0;//Distortion speed
uniform float edge_source: hint_range(0.0, 1.0, 0.01) = 0.0;//Distortion strength
uniform vec4 edge_color : source_color;//Edge color
uniform vec4 inner_color : source_color;//Inner color
uniform float shadow_distance: hint_range(0.0, 0.5, 0.01) = 0.05;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // gray + alpha
uniform float shadow_angle: hint_range(0.0, 6.28318, 0.01) = 0.0; // radians

uniform sampler2D noise;


//Signed distance function for rounded rectangle
float sd_round_rect(vec2 p, vec2 s, float r)
{
    vec2 q = abs(p) - s + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
    vec2 uv = UV;
    float noise_r = texture(noise, fract(TIME * speed + uv)).r;
    float d = sd_round_rect(uv - 0.5, vec2(width, height), radius);

    float m = step(d - noise_r * 0.1, 0.0);
    float m2 = step(d - noise_r * 0.1 - 0.05, 0.0);
    float m3 = m2 - m;

    vec4 edge = m3 * edge_color;
    vec4 inner = m * inner_color;
    vec4 top = mix(edge, inner, inner.a);

    // Compute 2D shadow offset from angle and distance
    vec2 shadow_offset = vec2(cos(shadow_angle), sin(shadow_angle)) * shadow_distance;

    // Sample SDF and noise at the shifted UV so the shadow appears at the offset
    vec2 uv_shadow = uv - shadow_offset; // subtract so shape at uv_shadow casts shadow at uv
    float noise_r_shadow = texture(noise, fract(TIME * speed + uv_shadow)).r;
    float d_shadow = sd_round_rect(uv_shadow - 0.5, vec2(width, height), radius);

    // Shadow exists where the shape would be at the shadow position
    float shadow_mask = step(d_shadow - noise_r_shadow * 0.1, 0.0);

    // Only show shadow where original is transparent
    float shadow_only = shadow_mask * (1.0 - m);

    vec4 shadow = shadow_only * shadow_color;

    // Composite: shadow below the drawn pixels
    COLOR = mix(shadow, top, clamp(top.a, 0.0, 1.0));
}

shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Opaque, stylized river water. The previous shader animated high-frequency sine waves
// along UV.y, creating bright cross-river zebra stripes. These are elongated flow lanes
// that run along UV.y and drift downstream instead. Geometry remains still; only normals
// and subtle albedo variation animate, avoiding the gelatin-ribbon look.
uniform vec4 deep_water_color : source_color = vec4(0.015, 0.075, 0.125, 1.0);
uniform vec4 current_color : source_color = vec4(0.045, 0.185, 0.245, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.105, 0.285, 0.345, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0, 0.01) = 0.85; // approximate metres per second
uniform float flow_streaks : hint_range(0.5, 5.0, 0.1) = 2.4;
uniform float ripple_strength : hint_range(0.0, 0.12, 0.005) = 0.025;
uniform float normal_strength : hint_range(0.0, 0.08, 0.001) = 0.008;
uniform float roughness_value : hint_range(0.45, 1.0, 0.01) = 0.72;
uniform float specular_strength : hint_range(0.0, 0.25, 0.01) = 0.12;
uniform float flow_uv_meters : hint_range(1.0, 40.0, 0.5) = 7.5;

const float WATER_TAU = 6.28318530718;

float flow_height(vec2 uv, float time_value) {
    // UV.y grows with distance downstream. Move the field in the same direction,
    // while changing mainly across UV.x so the visual marks are long streamlines,
    // not periodic bright bars running across the entire river.
    float along = uv.y - time_value * flow_speed / max(flow_uv_meters, 0.001);
    float long_phase = along * WATER_TAU * 0.075;
    float meander = sin(long_phase + sin(long_phase * 0.43) * 0.38);
    float lanes = max(flow_streaks, 0.5);
    float broad = sin(WATER_TAU * (uv.x * (lanes * 0.72) + meander * 0.105));
    float medium = sin(WATER_TAU * (uv.x * (lanes * 1.65) + meander * 0.20 + sin(long_phase * 0.63) * 0.025));
    float fine = sin(WATER_TAU * (uv.x * (lanes * 2.65) + meander * 0.28 + sin(long_phase * 1.13) * 0.018));
    return broad * 0.58 + medium * 0.29 + fine * 0.13;
}

void fragment() {
    float flow = flow_height(UV, TIME);
    float fine = flow_height(UV * vec2(1.12, 0.82) + vec2(0.13, 0.0), TIME * 1.13);

    // Derive a gently perturbed normal from the same continuous flow field. Lower
    // amplitude and higher roughness deliberately avoid metallic, sharp specular stripes.
    float du = 0.004;
    float dhdu = (flow_height(UV + vec2(du, 0.0), TIME) - flow_height(UV - vec2(du, 0.0), TIME)) / (2.0 * du);
    float dhdv = (flow_height(UV + vec2(0.0, du), TIME) - flow_height(UV - vec2(0.0, du), TIME)) / (2.0 * du);
    vec2 uv_dx = dFdx(UV);
    vec2 uv_dy = dFdy(UV);
    float determinant = uv_dx.x * uv_dy.y - uv_dx.y * uv_dy.x;
    if (abs(determinant) > 0.00001) {
        vec3 p_dx = dFdx(VERTEX);
        vec3 p_dy = dFdy(VERTEX);
        vec3 tangent = normalize((p_dx * uv_dy.y - p_dy * uv_dx.y) / determinant);
        vec3 bitangent = normalize((p_dy * uv_dx.x - p_dx * uv_dy.x) / determinant);
        vec3 base_normal = normalize(NORMAL);
        NORMAL = normalize(base_normal - tangent * dhdu * normal_strength - bitangent * dhdv * normal_strength);
    }

    float bands = clamp(0.48 + flow * ripple_strength + fine * 0.018, 0.28, 0.70);
    vec3 base = mix(deep_water_color.rgb, current_color.rgb, bands);
    float soft_glint = smoothstep(0.45, 0.92, flow) * 0.045;
    ALBEDO = mix(base, ripple_color.rgb, soft_glint);
    ROUGHNESS = roughness_value;
    SPECULAR = specular_strength;
    METALLIC = 0.0;
    // ALPHA remains unset: fully opaque water for Godot 4.6.
}

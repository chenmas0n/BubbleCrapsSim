shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Maximum number of active ripples
const int MAX_RIPPLES = 16;

// Ripple data: xy = position, z = time, w = intensity
uniform vec4 ripple_data[MAX_RIPPLES];
uniform int active_ripple_count = 0;

// Glow pulse parameters
uniform float pulse_speed = 5.0;
uniform float pulse_max_radius = 4.0;
uniform float pulse_width = 1.2;  // Wider for smoother rings
uniform vec4 pulse_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);  // Cyan glow
uniform float glow_intensity = 3.0;

// Floor appearance
uniform float floor_alpha : hint_range(0.0, 1.0) = 0.15;
uniform vec4 floor_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    ALBEDO = texture(texture_albedo, UV).rgb * floor_tint.rgb;
    
    float total_glow = 0.0;
    
    // Calculate glow from each active pulse
    for (int i = 0; i < MAX_RIPPLES; i++) {
        if (i >= active_ripple_count) break;
        
        vec2 pulse_pos = ripple_data[i].xy;
        float pulse_time = ripple_data[i].z;
        float intensity = ripple_data[i].w;
        
        // Calculate distance from pulse center
        float dist = length(world_pos.xz - pulse_pos);
        
        // Calculate expanding ring position
        float ring_pos = pulse_time * pulse_speed;
        float dist_to_ring = abs(dist - ring_pos);
        
        // Smooth ring pulse with gentle falloff
        if (dist_to_ring < pulse_width && ring_pos < pulse_max_radius) {
            // Smoother ring edge using smoothstep
            float ring_strength = smoothstep(pulse_width, 0.0, dist_to_ring);
            
            // Quadratic fade as ring expands (starts bright, fades smoothly)
            float expansion_progress = ring_pos / pulse_max_radius;
            float expansion_fade = 1.0 - (expansion_progress * expansion_progress);
            
            // Gentle pulse breathing effect
            float pulse_breath = 0.7 + 0.3 * sin(pulse_time * 8.0);
            
            float glow = ring_strength * expansion_fade * intensity * pulse_breath;
            total_glow += glow;
        }
        
        // Bright center hotspot that fades quickly
        float center_radius = pulse_max_radius * 0.4;
        if (dist < center_radius && ring_pos < center_radius) {
            // Smooth circular gradient from center
            float center_fade = smoothstep(center_radius, 0.0, dist);
            
            // Fade out quickly as time progresses
            float time_fade = 1.0 - smoothstep(0.0, center_radius / pulse_speed, pulse_time);
            
            float center_glow = center_fade * time_fade * intensity;
            total_glow += center_glow * 0.8;
        }
    }
    
    total_glow = clamp(total_glow, 0.0, 1.0);
    
    // Smooth blend with base color
    ALBEDO = mix(ALBEDO, pulse_color.rgb, total_glow * 0.5);
    
    // Strong emission for glow with smooth falloff
    EMISSION = pulse_color.rgb * total_glow * glow_intensity;
    
    // Alpha increases where glows are
    ALPHA = floor_alpha + (total_glow * 0.85);
}
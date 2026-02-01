shader_type canvas_item;

// Screen Distortion Shader - Heat haze, shockwave, noise distortion
// Apply to full-screen ColorRect for post-processing

// Screen texture sampler (Godot 4 method)
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

group_uniforms Noise_Distortion;
uniform bool enable_noise_distort = true;
uniform float noise_strength : hint_range(0.0, 0.1) = 0.01;
uniform float noise_scale : hint_range(1.0, 50.0) = 10.0;
uniform float noise_speed : hint_range(0.0, 5.0) = 0.5;

group_uniforms Shockwave;
uniform bool enable_shockwave = false;
uniform vec2 shockwave_center = vec2(0.5, 0.5);
uniform float shockwave_radius : hint_range(0.0, 2.0) = 0.0;
uniform float shockwave_width : hint_range(0.01, 0.3) = 0.1;
uniform float shockwave_strength : hint_range(0.0, 0.2) = 0.05;
uniform float shockwave_falloff : hint_range(0.1, 5.0) = 2.0;

group_uniforms Heat_Haze;
uniform bool enable_heat_haze = false;
uniform float heat_strength : hint_range(0.0, 0.05) = 0.01;
uniform float heat_speed : hint_range(0.0, 10.0) = 3.0;
uniform float heat_frequency : hint_range(1.0, 50.0) = 20.0;

group_uniforms Chromatic;
uniform bool enable_chromatic = false;
uniform float chromatic_strength : hint_range(0.0, 0.02) = 0.005;

// Value noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 distort_offset = vec2(0.0);
	
	// Noise-based distortion
	if (enable_noise_distort) {
		vec2 noise_uv = uv * noise_scale + TIME * noise_speed;
		float n1 = noise(noise_uv);
		float n2 = noise(noise_uv + vec2(100.0, 100.0));
		distort_offset += (vec2(n1, n2) - 0.5) * noise_strength;
	}
	
	// Heat haze effect
	if (enable_heat_haze) {
		float heat_wave = sin(uv.y * heat_frequency + TIME * heat_speed);
		heat_wave *= sin(uv.y * heat_frequency * 0.7 + TIME * heat_speed * 1.3);
		distort_offset.x += heat_wave * heat_strength;
	}
	
	// Shockwave effect
	if (enable_shockwave && shockwave_radius > 0.0) {
		vec2 dir = uv - shockwave_center;
		float dist = length(dir);
		
		// Ring mask
		float ring = smoothstep(shockwave_radius - shockwave_width, shockwave_radius, dist);
		ring *= 1.0 - smoothstep(shockwave_radius, shockwave_radius + shockwave_width, dist);
		
		// Falloff with distance
		float falloff = 1.0 / (1.0 + dist * shockwave_falloff);
		
		// Apply distortion along direction from center
		vec2 shock_dir = normalize(dir + 0.0001);
		distort_offset += shock_dir * ring * shockwave_strength * falloff;
	}
	
	// Sample screen with distortion
	vec4 final_color;
	
	if (enable_chromatic) {
		// Chromatic aberration - sample RGB channels with slight offset
		vec2 chrom_offset = distort_offset * chromatic_strength / max(noise_strength, 0.001);
		float r = texture(screen_texture, uv + distort_offset + chrom_offset).r;
		float g = texture(screen_texture, uv + distort_offset).g;
		float b = texture(screen_texture, uv + distort_offset - chrom_offset).b;
		final_color = vec4(r, g, b, 1.0);
	} else {
		final_color = texture(screen_texture, uv + distort_offset);
	}
	
	COLOR = final_color;
}

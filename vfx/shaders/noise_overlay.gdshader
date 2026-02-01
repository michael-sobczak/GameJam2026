shader_type canvas_item;

// Noise Overlay Shader - Animated procedural noise with gradient coloring
// Use on ColorRect or Sprite2D for background/overlay effects

group_uniforms Colors;
uniform vec4 color_a : source_color = vec4(0.1, 0.8, 0.9, 1.0); // Teal
uniform vec4 color_b : source_color = vec4(0.6, 0.2, 0.8, 1.0); // Purple
uniform vec4 color_c : source_color = vec4(0.9, 0.3, 0.6, 1.0); // Pink
uniform bool use_three_colors = true;

group_uniforms Noise;
uniform float noise_scale : hint_range(1.0, 50.0) = 10.0;
uniform float speed : hint_range(0.0, 5.0) = 0.5;
uniform float contrast : hint_range(0.1, 3.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

group_uniforms Dissolve;
uniform bool output_dissolve_mask = false;
uniform float dissolve_edge_width : hint_range(0.0, 0.5) = 0.1;

// Simple hash function for value noise
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise with smooth interpolation
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	
	// Smooth interpolation
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	// Four corners
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Layered noise (FBM-lite, 3 octaves for performance)
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (int i = 0; i < 3; i++) {
		value += amplitude * value_noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	
	return value;
}

void fragment() {
	vec2 uv = UV * noise_scale;
	float t = TIME * speed;
	
	// Animated noise - offset over time
	float n = fbm(uv + vec2(t * 0.3, t * 0.2));
	float n2 = fbm(uv * 1.5 - vec2(t * 0.2, t * 0.4));
	
	// Combine noise layers
	float noise_val = (n + n2) * 0.5;
	
	// Apply contrast
	noise_val = pow(noise_val, 1.0 / contrast);
	noise_val = clamp(noise_val, 0.0, 1.0);
	
	// Color gradient
	vec4 final_color;
	if (use_three_colors) {
		// Three-color gradient
		if (noise_val < 0.5) {
			final_color = mix(color_a, color_b, noise_val * 2.0);
		} else {
			final_color = mix(color_b, color_c, (noise_val - 0.5) * 2.0);
		}
	} else {
		// Two-color gradient
		final_color = mix(color_a, color_b, noise_val);
	}
	
	// Dissolve mask output mode
	if (output_dissolve_mask) {
		float edge = smoothstep(0.5 - dissolve_edge_width, 0.5, noise_val) 
		           - smoothstep(0.5, 0.5 + dissolve_edge_width, noise_val);
		COLOR = vec4(vec3(noise_val), edge + noise_val);
	} else {
		COLOR = vec4(final_color.rgb, final_color.a * opacity);
	}
}

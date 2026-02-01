shader_type canvas_item;

// Text Wave Shader - Wobble distortion + color cycling for Label/RichTextLabel
// Creates animated wave effect with optional rainbow cycling and dissolve edge

group_uniforms Wave;
uniform float wave_intensity : hint_range(0.0, 20.0) = 3.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wave_frequency : hint_range(0.1, 20.0) = 4.0;
uniform bool vertical_wave = true;
uniform bool horizontal_wave = false;

group_uniforms ColorCycle;
uniform bool enable_rainbow = false;
uniform float rainbow_speed : hint_range(0.0, 5.0) = 1.0;
uniform float rainbow_saturation : hint_range(0.0, 1.0) = 0.8;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

group_uniforms Dissolve;
uniform bool enable_dissolve = false;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_edge_width : hint_range(0.01, 0.3) = 0.1;
uniform vec4 dissolve_edge_color : source_color = vec4(0.9, 0.3, 0.6, 1.0);

// Simple hash for dissolve noise
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

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * wave_speed;
	
	// Calculate wave offset
	vec2 wave_offset = vec2(0.0);
	
	if (vertical_wave) {
		wave_offset.y = sin(uv.x * wave_frequency + t) * wave_intensity * TEXTURE_PIXEL_SIZE.y;
	}
	if (horizontal_wave) {
		wave_offset.x = sin(uv.y * wave_frequency + t * 1.3) * wave_intensity * TEXTURE_PIXEL_SIZE.x;
	}
	
	// Sample texture with wave offset
	vec4 tex = texture(TEXTURE, uv + wave_offset);
	
	// Color calculation
	vec3 final_color;
	if (enable_rainbow) {
		float hue = fract(uv.x * 0.5 + TIME * rainbow_speed);
		vec3 rainbow = hsv2rgb(vec3(hue, rainbow_saturation, 1.0));
		final_color = rainbow * tex.rgb;
	} else {
		final_color = base_color.rgb * tex.rgb;
	}
	
	// Dissolve effect
	float alpha = tex.a;
	if (enable_dissolve) {
		float noise_val = noise(uv * 10.0);
		float dissolve_threshold = dissolve_progress;
		
		// Edge glow
		float edge = smoothstep(dissolve_threshold - dissolve_edge_width, dissolve_threshold, noise_val);
		float inner = smoothstep(dissolve_threshold, dissolve_threshold + dissolve_edge_width, noise_val);
		
		// Mix edge color
		float edge_factor = edge - inner;
		final_color = mix(final_color, dissolve_edge_color.rgb, edge_factor * 2.0);
		
		// Apply dissolve
		alpha *= inner;
	}
	
	COLOR = vec4(final_color, alpha * base_color.a);
}

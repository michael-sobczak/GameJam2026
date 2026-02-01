shader_type canvas_item;

// Remove Background Shader
// Makes white/light backgrounds transparent, useful for JPEGs without alpha

group_uniforms Background_Removal;
uniform float threshold : hint_range(0.0, 1.0) = 0.85; // Brightness threshold for transparency
uniform float softness : hint_range(0.0, 0.5) = 0.15; // Soft edge for smoother cutout
uniform bool invert = false; // If true, keeps light areas instead of dark

group_uniforms Color_Adjust;
uniform float saturation_boost : hint_range(0.0, 2.0) = 1.2; // Boost colors slightly
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Optional color tint

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Calculate brightness (luminance)
	float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	
	// Calculate alpha based on brightness
	float alpha;
	if (invert) {
		// Keep bright areas
		alpha = smoothstep(threshold - softness, threshold + softness, brightness);
	} else {
		// Remove bright areas (white background)
		alpha = 1.0 - smoothstep(threshold - softness, threshold + softness, brightness);
	}
	
	// Boost saturation to make colors pop
	vec3 gray = vec3(brightness);
	vec3 saturated = mix(gray, tex.rgb, saturation_boost);
	
	// Apply tint
	vec3 final_color = saturated * tint.rgb;
	
	COLOR = vec4(final_color, alpha * tex.a * tint.a);
}

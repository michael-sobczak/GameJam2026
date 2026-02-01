shader_type canvas_item;

// SDF Shapes Shader - Procedural circle, ring, rounded rect for UI/HUD
// Use on ColorRect for reticles, shields, panels, target indicators

group_uniforms Shape;
uniform int shape_type : hint_range(0, 2) = 0; // 0=circle, 1=ring, 2=rounded_rect
uniform float size : hint_range(0.1, 1.0) = 0.4;
uniform float ring_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.1; // For rounded rect
uniform vec2 rect_size = vec2(0.6, 0.3); // For rounded rect

group_uniforms Style;
uniform vec4 fill_color : source_color = vec4(0.1, 0.8, 0.9, 0.3);
uniform vec4 outline_color : source_color = vec4(0.1, 0.8, 0.9, 1.0);
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform float edge_softness : hint_range(0.001, 0.1) = 0.01;

group_uniforms Animation;
uniform bool enable_pulse = true;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_intensity : hint_range(0.0, 0.2) = 0.05;
uniform float rotation_speed : hint_range(-5.0, 5.0) = 0.0;

group_uniforms Extras;
uniform bool show_crosshair = false;
uniform float crosshair_thickness : hint_range(0.001, 0.05) = 0.01;
uniform float crosshair_length : hint_range(0.05, 0.5) = 0.15;
uniform bool show_radar_lines = false;
uniform int radar_segments : hint_range(2, 12) = 4;

// SDF for circle
float sdf_circle(vec2 p, float r) {
	return length(p) - r;
}

// SDF for rounded rectangle
float sdf_rounded_rect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// SDF for ring
float sdf_ring(vec2 p, float r, float thickness) {
	return abs(length(p) - r) - thickness;
}

// Rotation matrix
mat2 rotate2d(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
	// Center UV and apply aspect ratio correction
	vec2 uv = UV - 0.5;
	
	// Apply rotation
	if (rotation_speed != 0.0) {
		uv = rotate2d(TIME * rotation_speed) * uv;
	}
	
	// Pulse animation
	float pulse = 0.0;
	if (enable_pulse) {
		pulse = sin(TIME * pulse_speed) * pulse_intensity;
	}
	
	float animated_size = size + pulse;
	
	// Calculate SDF based on shape type
	float d;
	if (shape_type == 0) {
		// Filled circle
		d = sdf_circle(uv, animated_size);
	} else if (shape_type == 1) {
		// Ring
		d = sdf_ring(uv, animated_size, ring_thickness);
	} else {
		// Rounded rectangle
		d = sdf_rounded_rect(uv, rect_size * 0.5 + pulse, corner_radius);
	}
	
	// Calculate fill and outline
	float fill_mask = 1.0 - smoothstep(-edge_softness, edge_softness, d);
	float outline_mask = 1.0 - smoothstep(-edge_softness, edge_softness, abs(d) - outline_width);
	
	// Combine colors
	vec4 color = vec4(0.0);
	
	// Fill (only for non-ring shapes or as background)
	if (shape_type != 1) {
		color = mix(color, fill_color, fill_mask * fill_color.a);
	}
	
	// Outline
	color = mix(color, outline_color, outline_mask);
	
	// Crosshair overlay
	if (show_crosshair) {
		float ch_h = step(abs(uv.y), crosshair_thickness) * step(abs(uv.x), crosshair_length);
		float ch_v = step(abs(uv.x), crosshair_thickness) * step(abs(uv.y), crosshair_length);
		float ch = max(ch_h, ch_v);
		// Gap in center
		float gap = 1.0 - step(length(uv), animated_size * 0.3);
		ch *= gap;
		color = mix(color, outline_color, ch);
	}
	
	// Radar lines overlay
	if (show_radar_lines) {
		float angle = atan(uv.y, uv.x);
		float segment = 3.14159 / float(radar_segments);
		float line = abs(mod(angle + 0.001, segment) - segment * 0.5);
		float radar_mask = 1.0 - smoothstep(0.0, 0.02, line);
		radar_mask *= step(length(uv), animated_size);
		color = mix(color, outline_color * 0.5, radar_mask * 0.5);
	}
	
	COLOR = color;
}

shader_type canvas_item;

// Glitch Text Shader - Position jitter, scanline slices, RGB split
// Apply to Label or RichTextLabel for cyberpunk/digital effects

group_uniforms Glitch;
uniform bool enable_glitch = true;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float glitch_frequency : hint_range(0.1, 10.0) = 2.0;
uniform float glitch_block_size : hint_range(0.01, 0.2) = 0.05;

group_uniforms Position_Jitter;
uniform bool enable_jitter = true;
uniform float jitter_amount : hint_range(0.0, 20.0) = 5.0;

group_uniforms Scanlines;
uniform bool enable_scanlines = true;
uniform float scanline_count : hint_range(5.0, 100.0) = 30.0;
uniform float scanline_offset_max : hint_range(0.0, 0.1) = 0.02;

group_uniforms RGB_Split;
uniform bool enable_rgb_split = true;
uniform float rgb_split_amount : hint_range(0.0, 10.0) = 3.0;

group_uniforms Colors;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glitch_color_1 : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform vec4 glitch_color_2 : source_color = vec4(0.0, 1.0, 0.8, 1.0);

// Random functions
float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Stepped time for glitch timing
float glitch_time() {
	return floor(TIME * glitch_frequency * 10.0) * 0.1;
}

// Check if currently in a glitch moment
float is_glitching() {
	float gt = glitch_time();
	float glitch_chance = hash(gt * 13.37);
	return step(1.0 - glitch_intensity * 0.3, glitch_chance);
}

void fragment() {
	vec2 uv = UV;
	float glitch_active = enable_glitch ? is_glitching() : 0.0;
	
	// Position jitter
	vec2 jitter_offset = vec2(0.0);
	if (enable_jitter && glitch_active > 0.5) {
		float jt = glitch_time();
		jitter_offset.x = (hash(jt * 7.0) - 0.5) * jitter_amount * TEXTURE_PIXEL_SIZE.x * glitch_intensity;
		jitter_offset.y = (hash(jt * 11.0) - 0.5) * jitter_amount * TEXTURE_PIXEL_SIZE.y * glitch_intensity * 0.5;
	}
	
	// Scanline slice offset
	vec2 scanline_offset = vec2(0.0);
	if (enable_scanlines && glitch_active > 0.5) {
		float line_index = floor(uv.y * scanline_count);
		float line_hash = hash(line_index + glitch_time() * 100.0);
		
		// Only offset some lines
		if (line_hash > 0.7) {
			scanline_offset.x = (hash(line_index * 3.0 + glitch_time()) - 0.5) * scanline_offset_max * glitch_intensity;
		}
	}
	
	// Final UV with offsets
	vec2 final_uv = uv + jitter_offset + scanline_offset;
	
	// RGB split sampling
	vec4 final_color;
	if (enable_rgb_split && glitch_active > 0.5) {
		float split = rgb_split_amount * TEXTURE_PIXEL_SIZE.x * glitch_intensity;
		float r = texture(TEXTURE, final_uv + vec2(split, 0.0)).r;
		float g = texture(TEXTURE, final_uv).g;
		float b = texture(TEXTURE, final_uv - vec2(split, 0.0)).b;
		float a = texture(TEXTURE, final_uv).a;
		final_color = vec4(r, g, b, a);
	} else {
		final_color = texture(TEXTURE, final_uv);
	}
	
	// Apply base color
	final_color.rgb *= base_color.rgb;
	
	// Random color flash during glitch
	if (glitch_active > 0.5) {
		float color_flash = hash(glitch_time() * 17.0);
		if (color_flash > 0.9) {
			final_color.rgb = mix(final_color.rgb, glitch_color_1.rgb, 0.3 * glitch_intensity);
		} else if (color_flash > 0.8) {
			final_color.rgb = mix(final_color.rgb, glitch_color_2.rgb, 0.3 * glitch_intensity);
		}
	}
	
	// Block corruption effect
	if (enable_glitch && glitch_active > 0.5) {
		vec2 block_uv = floor(uv / glitch_block_size) * glitch_block_size;
		float block_hash = hash2(block_uv + glitch_time());
		if (block_hash > 0.95) {
			// Corrupt this block
			final_color.rgb = mix(final_color.rgb, vec3(hash(block_hash * 7.0)), 0.5 * glitch_intensity);
		}
	}
	
	COLOR = final_color;
}

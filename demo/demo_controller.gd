class_name DemoController
extends Control

## Demo Controller - VFX Pack Demo Scene Manager
## Controls all effects, handles input, manages palette

# Node references (set via Scene Unique Names)
@onready var noise_overlay: ColorRect = %NoiseOverlay
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var glitch_label: Label = %GlitchLabel
@onready var reticle: ColorRect = %Reticle
@onready var panel_frame: ColorRect = %PanelFrame
@onready var screen_distort: ColorRect = %ScreenDistort
@onready var impact_particles: GPUParticles2D = %ImpactParticles
@onready var glitch_controller: TextGlitchController = %GlitchController

# Toggle buttons
@onready var toggle_noise_btn: Button = %ToggleNoise
@onready var toggle_distort_btn: Button = %ToggleDistort
@onready var toggle_particles_btn: Button = %ToggleParticles
@onready var toggle_text_btn: Button = %ToggleTextEffects
@onready var toggle_glitch_btn: Button = %ToggleGlitch
@onready var toggle_sdf_btn: Button = %ToggleSDF

# State
var noise_enabled: bool = true
var distort_enabled: bool = true
var text_effects_enabled: bool = true
var glitch_enabled: bool = true
var sdf_enabled: bool = true

# Palette colors (teal/purple/pink theme)
const PALETTE := {
	"teal": Color(0.1, 0.8, 0.9),
	"purple": Color(0.6, 0.2, 0.8),
	"pink": Color(0.9, 0.3, 0.6),
	"dark": Color(0.05, 0.05, 0.1),
}


func _ready() -> void:
	# Connect button signals
	if toggle_noise_btn:
		toggle_noise_btn.pressed.connect(_on_toggle_noise)
	if toggle_distort_btn:
		toggle_distort_btn.pressed.connect(_on_toggle_distort)
	if toggle_particles_btn:
		toggle_particles_btn.pressed.connect(_on_trigger_particles)
	if toggle_text_btn:
		toggle_text_btn.pressed.connect(_on_toggle_text_effects)
	if toggle_glitch_btn:
		toggle_glitch_btn.pressed.connect(_on_toggle_glitch)
	if toggle_sdf_btn:
		toggle_sdf_btn.pressed.connect(_on_toggle_sdf)
	
	# Apply initial palette
	_apply_palette()
	
	# Print controls
	print("=== VFX Pack Demo Controls ===")
	print("1 - Toggle Noise Overlay")
	print("2 - Toggle Screen Distortion")
	print("3 - Toggle Text Effects (Wave)")
	print("4 - Toggle Glitch Text")
	print("5 - Toggle SDF Shapes")
	print("Space - Trigger Particles")
	print("Click - Shockwave at mouse position")
	print("==============================")


func _input(event: InputEvent) -> void:
	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				_on_toggle_noise()
			KEY_2:
				_on_toggle_distort()
			KEY_3:
				_on_toggle_text_effects()
			KEY_4:
				_on_toggle_glitch()
			KEY_5:
				_on_toggle_sdf()
			KEY_SPACE:
				_on_trigger_particles()
			KEY_ESCAPE:
				get_tree().quit()
	
	# Mouse click for shockwave
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_trigger_shockwave_at_mouse()


func _on_toggle_noise() -> void:
	noise_enabled = not noise_enabled
	if noise_overlay:
		noise_overlay.visible = noise_enabled
	_update_button_text(toggle_noise_btn, "Noise", noise_enabled)
	print("Noise: ", "ON" if noise_enabled else "OFF")


func _on_toggle_distort() -> void:
	distort_enabled = not distort_enabled
	if screen_distort:
		var controller := screen_distort as ScreenDistortController
		if controller:
			controller.set_all_distortion(distort_enabled)
		else:
			screen_distort.visible = distort_enabled
	_update_button_text(toggle_distort_btn, "Distort", distort_enabled)
	print("Distortion: ", "ON" if distort_enabled else "OFF")


func _on_toggle_text_effects() -> void:
	text_effects_enabled = not text_effects_enabled
	
	# Toggle wave shader on labels
	if title_label and title_label.material is ShaderMaterial:
		var mat := title_label.material as ShaderMaterial
		mat.set_shader_parameter(&"wave_intensity", 3.0 if text_effects_enabled else 0.0)
	
	if subtitle_label and subtitle_label.material is ShaderMaterial:
		var mat := subtitle_label.material as ShaderMaterial
		mat.set_shader_parameter(&"wave_intensity", 2.0 if text_effects_enabled else 0.0)
		mat.set_shader_parameter(&"enable_rainbow", text_effects_enabled)
	
	_update_button_text(toggle_text_btn, "TextFX", text_effects_enabled)
	print("Text Effects: ", "ON" if text_effects_enabled else "OFF")


func _on_toggle_glitch() -> void:
	glitch_enabled = not glitch_enabled
	if glitch_controller:
		glitch_controller.set_glitch_enabled(glitch_enabled)
		glitch_controller.set_auto_glitch(glitch_enabled)
	_update_button_text(toggle_glitch_btn, "Glitch", glitch_enabled)
	print("Glitch: ", "ON" if glitch_enabled else "OFF")


func _on_toggle_sdf() -> void:
	sdf_enabled = not sdf_enabled
	if reticle:
		reticle.visible = sdf_enabled
	if panel_frame:
		panel_frame.visible = sdf_enabled
	_update_button_text(toggle_sdf_btn, "SDF", sdf_enabled)
	print("SDF Shapes: ", "ON" if sdf_enabled else "OFF")


func _on_trigger_particles() -> void:
	if impact_particles:
		# Emit at center of screen
		var center := get_viewport_rect().size / 2.0
		impact_particles.global_position = center
		if impact_particles.has_method(&"emit_burst"):
			impact_particles.emit_burst()
		else:
			impact_particles.restart()
			impact_particles.emitting = true
	print("Particles triggered!")


func _trigger_shockwave_at_mouse() -> void:
	if screen_distort and distort_enabled:
		var controller := screen_distort as ScreenDistortController
		if controller:
			controller.trigger_shockwave_at_mouse()
		else:
			# Manual shockwave if not using controller
			var mat := screen_distort.material as ShaderMaterial
			if mat:
				var mouse_pos := get_viewport().get_mouse_position()
				var viewport_size := get_viewport_rect().size
				var uv := mouse_pos / viewport_size
				mat.set_shader_parameter(&"shockwave_center", uv)
				mat.set_shader_parameter(&"enable_shockwave", true)
				mat.set_shader_parameter(&"shockwave_radius", 0.0)
				
				# Animate radius
				var tween := create_tween()
				tween.tween_method(func(r: float): mat.set_shader_parameter(&"shockwave_radius", r), 0.0, 1.5, 0.5)
				tween.tween_callback(func(): mat.set_shader_parameter(&"enable_shockwave", false))


func _update_button_text(btn: Button, name: String, enabled: bool) -> void:
	if btn:
		btn.text = "%s: %s" % [name, "ON" if enabled else "OFF"]


func _apply_palette() -> void:
	# Apply consistent palette across all effects
	
	# Noise overlay
	if noise_overlay and noise_overlay.material is ShaderMaterial:
		var mat := noise_overlay.material as ShaderMaterial
		mat.set_shader_parameter(&"color_a", PALETTE.teal)
		mat.set_shader_parameter(&"color_b", PALETTE.purple)
		mat.set_shader_parameter(&"color_c", PALETTE.pink)
	
	# Impact particles
	if impact_particles and impact_particles.has_method(&"set_colors"):
		impact_particles.set_colors(PALETTE.teal, Color(PALETTE.pink.r, PALETTE.pink.g, PALETTE.pink.b, 0.0))
	
	# SDF shapes
	if reticle and reticle.material is ShaderMaterial:
		var mat := reticle.material as ShaderMaterial
		mat.set_shader_parameter(&"outline_color", PALETTE.teal)
		mat.set_shader_parameter(&"fill_color", Color(PALETTE.teal.r, PALETTE.teal.g, PALETTE.teal.b, 0.2))
	
	if panel_frame and panel_frame.material is ShaderMaterial:
		var mat := panel_frame.material as ShaderMaterial
		mat.set_shader_parameter(&"outline_color", PALETTE.purple)
		mat.set_shader_parameter(&"fill_color", Color(PALETTE.purple.r, PALETTE.purple.g, PALETTE.purple.b, 0.1))
	
	# Glitch text
	if glitch_controller:
		glitch_controller.set_glitch_colors(PALETTE.pink, PALETTE.teal)


## Update palette colors globally
func set_palette_color(key: String, color: Color) -> void:
	# This would update the palette and re-apply
	# Useful for theme switching
	pass


## Trigger a coordinated effect burst (particles + shockwave)
func trigger_combo_effect(position: Vector2) -> void:
	# Particles
	if impact_particles:
		impact_particles.global_position = position
		if impact_particles.has_method(&"emit_burst"):
			impact_particles.emit_burst()
	
	# Shockwave
	if screen_distort and distort_enabled:
		var controller := screen_distort as ScreenDistortController
		if controller:
			controller.trigger_shockwave_screen(position)

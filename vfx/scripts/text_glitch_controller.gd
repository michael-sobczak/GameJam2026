class_name TextGlitchController
extends Control

## Text Glitch Controller
## Manages glitch effect on Label/RichTextLabel with the text_glitch shader
## Can be used as parent controller or attached directly to text node

signal glitch_triggered

@export_group("Target")
@export var target_label: Control ## The Label or RichTextLabel to affect

@export_group("Glitch Settings")
@export var glitch_enabled: bool = true
@export var glitch_intensity: float = 0.5
@export var glitch_frequency: float = 2.0

@export_group("Auto Glitch")
@export var auto_glitch: bool = false
@export var auto_glitch_interval_min: float = 2.0
@export var auto_glitch_interval_max: float = 5.0
@export var auto_glitch_duration: float = 0.3

var _material: ShaderMaterial
var _auto_timer: float = 0.0
var _next_auto_time: float = 0.0
var _glitch_end_time: float = 0.0
var _is_auto_glitching: bool = false


func _ready() -> void:
	# Auto-find target if not set
	if target_label == null:
		# Find first Label child
		for child in get_children():
			if child is Label or child is RichTextLabel:
				target_label = child
				break
	
	if target_label == null:
		push_warning("TextGlitchController: No target label found")
		return
	
	# Get material
	if target_label.material is ShaderMaterial:
		_material = target_label.material
	else:
		push_warning("TextGlitchController: Target label needs ShaderMaterial with text_glitch shader")
		return
	
	# Apply initial settings
	_update_shader_params()
	
	# Initialize auto glitch timer
	if auto_glitch:
		_schedule_next_auto_glitch()


func _process(delta: float) -> void:
	if not auto_glitch or _material == null:
		return
	
	_auto_timer += delta
	
	# Check if we should trigger auto glitch
	if _auto_timer >= _next_auto_time and not _is_auto_glitching:
		_start_auto_glitch()
	
	# Check if auto glitch should end
	if _is_auto_glitching and _auto_timer >= _glitch_end_time:
		_end_auto_glitch()


func _update_shader_params() -> void:
	if _material == null:
		return
	
	_material.set_shader_parameter(&"enable_glitch", glitch_enabled)
	_material.set_shader_parameter(&"glitch_intensity", glitch_intensity)
	_material.set_shader_parameter(&"glitch_frequency", glitch_frequency)


func _schedule_next_auto_glitch() -> void:
	_next_auto_time = _auto_timer + randf_range(auto_glitch_interval_min, auto_glitch_interval_max)


func _start_auto_glitch() -> void:
	_is_auto_glitching = true
	set_glitch_enabled(true)
	_glitch_end_time = _auto_timer + auto_glitch_duration
	glitch_triggered.emit()


func _end_auto_glitch() -> void:
	_is_auto_glitching = false
	set_glitch_enabled(false)
	_schedule_next_auto_glitch()


## Enable or disable the glitch effect
func set_glitch_enabled(enabled: bool) -> void:
	glitch_enabled = enabled
	if _material:
		_material.set_shader_parameter(&"enable_glitch", enabled)


## Set glitch intensity (0-1)
func set_glitch_intensity(intensity: float) -> void:
	glitch_intensity = clampf(intensity, 0.0, 1.0)
	if _material:
		_material.set_shader_parameter(&"glitch_intensity", glitch_intensity)


## Set glitch frequency
func set_glitch_frequency(freq: float) -> void:
	glitch_frequency = freq
	if _material:
		_material.set_shader_parameter(&"glitch_frequency", glitch_frequency)


## Trigger a one-shot glitch effect
func trigger_glitch(duration: float = 0.3) -> void:
	if _material == null:
		return
	
	glitch_triggered.emit()
	
	# Enable glitch
	set_glitch_enabled(true)
	
	# Create tween to disable after duration
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(set_glitch_enabled.bind(false))


## Set RGB split enabled
func set_rgb_split(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"enable_rgb_split", enabled)


## Set scanlines enabled
func set_scanlines(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"enable_scanlines", enabled)


## Set position jitter enabled
func set_jitter(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"enable_jitter", enabled)


## Set glitch colors
func set_glitch_colors(color1: Color, color2: Color) -> void:
	if _material:
		_material.set_shader_parameter(&"glitch_color_1", color1)
		_material.set_shader_parameter(&"glitch_color_2", color2)


## Enable auto-glitch mode
func set_auto_glitch(enabled: bool) -> void:
	auto_glitch = enabled
	if enabled:
		_schedule_next_auto_glitch()
	else:
		_is_auto_glitching = false
		set_glitch_enabled(false)

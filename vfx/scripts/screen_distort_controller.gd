class_name ScreenDistortController
extends ColorRect

## Screen Distortion Controller
## Manages full-screen distortion effects including shockwave triggers
## Attach to a full-screen ColorRect with the screen_distort shader

signal shockwave_started
signal shockwave_finished

@export_group("Shockwave Animation")
@export var shockwave_duration: float = 0.5
@export var shockwave_max_radius: float = 1.5
@export var shockwave_curve: Curve

@export_group("Heat Haze")
@export var heat_haze_enabled: bool = false

@export_group("Noise Distortion")
@export var noise_distort_enabled: bool = true

var _shockwave_tween: Tween
var _material: ShaderMaterial


func _ready() -> void:
	# Get or create shader material
	if material is ShaderMaterial:
		_material = material
	else:
		push_warning("ScreenDistortController requires a ShaderMaterial with screen_distort shader")
		return
	
	# Apply initial settings
	_update_shader_params()
	
	# Create default curve if not set
	if shockwave_curve == null:
		shockwave_curve = Curve.new()
		shockwave_curve.add_point(Vector2(0.0, 0.0))
		shockwave_curve.add_point(Vector2(0.3, 1.0))
		shockwave_curve.add_point(Vector2(1.0, 1.0))


func _update_shader_params() -> void:
	if _material == null:
		return
	
	_material.set_shader_parameter(&"enable_heat_haze", heat_haze_enabled)
	_material.set_shader_parameter(&"enable_noise_distort", noise_distort_enabled)


## Trigger a shockwave effect at the given screen position (0-1 UV coordinates)
func trigger_shockwave_uv(center_uv: Vector2) -> void:
	if _material == null:
		return
	
	# Cancel any existing shockwave
	if _shockwave_tween and _shockwave_tween.is_valid():
		_shockwave_tween.kill()
	
	# Enable shockwave
	_material.set_shader_parameter(&"enable_shockwave", true)
	_material.set_shader_parameter(&"shockwave_center", center_uv)
	_material.set_shader_parameter(&"shockwave_radius", 0.0)
	
	shockwave_started.emit()
	
	# Animate radius
	_shockwave_tween = create_tween()
	_shockwave_tween.tween_method(_update_shockwave_radius, 0.0, 1.0, shockwave_duration)
	_shockwave_tween.tween_callback(_finish_shockwave)


## Trigger shockwave at screen pixel position
func trigger_shockwave_screen(screen_pos: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var uv := screen_pos / viewport_size
	trigger_shockwave_uv(uv)


## Trigger shockwave at mouse position
func trigger_shockwave_at_mouse() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	trigger_shockwave_screen(mouse_pos)


## Trigger shockwave at world position (converts to screen UV)
func trigger_shockwave_world(world_pos: Vector2, camera: Camera2D = null) -> void:
	if camera == null:
		# Try to find camera
		camera = get_viewport().get_camera_2d()
	
	if camera:
		var screen_pos := camera.get_viewport().get_screen_transform() * camera.get_global_transform().affine_inverse() * world_pos
		trigger_shockwave_screen(screen_pos)
	else:
		# Fallback to center
		trigger_shockwave_uv(Vector2(0.5, 0.5))


func _update_shockwave_radius(progress: float) -> void:
	var curve_value := shockwave_curve.sample(progress) if shockwave_curve else progress
	var radius := curve_value * shockwave_max_radius
	_material.set_shader_parameter(&"shockwave_radius", radius)


func _finish_shockwave() -> void:
	_material.set_shader_parameter(&"enable_shockwave", false)
	_material.set_shader_parameter(&"shockwave_radius", 0.0)
	shockwave_finished.emit()


## Enable/disable heat haze effect
func set_heat_haze(enabled: bool) -> void:
	heat_haze_enabled = enabled
	if _material:
		_material.set_shader_parameter(&"enable_heat_haze", enabled)


## Enable/disable noise distortion
func set_noise_distort(enabled: bool) -> void:
	noise_distort_enabled = enabled
	if _material:
		_material.set_shader_parameter(&"enable_noise_distort", enabled)


## Set distortion strength
func set_noise_strength(strength: float) -> void:
	if _material:
		_material.set_shader_parameter(&"noise_strength", strength)


## Enable/disable chromatic aberration
func set_chromatic(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"enable_chromatic", enabled)


## Toggle all distortion effects
func set_all_distortion(enabled: bool) -> void:
	set_noise_distort(enabled)
	set_heat_haze(false) # Heat haze usually off by default
	set_chromatic(enabled)

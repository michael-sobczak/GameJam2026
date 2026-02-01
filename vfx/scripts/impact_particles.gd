@tool
class_name ImpactParticles
extends GPUParticles2D

## Impact/Burst Particles Controller
## Procedural particle bursts for hits, magic effects, explosions
## Call emit_burst() to trigger a one-shot particle burst

signal burst_started
signal burst_finished

@export_group("Burst Settings")
@export var burst_amount: int = 20
@export var burst_lifetime: float = 0.5
@export var burst_speed_min: float = 100.0
@export var burst_speed_max: float = 300.0

@export_group("Colors")
@export var color_start: Color = Color(0.1, 0.9, 0.95, 1.0) # Teal
@export var color_end: Color = Color(0.9, 0.3, 0.6, 0.0) # Pink fading

@export_group("Size")
@export var size_start: float = 8.0
@export var size_end: float = 2.0

@export_group("Spread")
@export var spread_angle: float = 360.0 # Full circle
@export var direction: Vector2 = Vector2.UP

var _burst_timer: float = 0.0
var _is_bursting: bool = false


func _ready() -> void:
	# Configure as one-shot burst
	emitting = false
	one_shot = true
	explosiveness = 1.0
	amount = burst_amount
	lifetime = burst_lifetime
	
	# Create procedural material if not set
	if process_material == null:
		_setup_particle_material()


func _process(delta: float) -> void:
	if _is_bursting:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_is_bursting = false
			burst_finished.emit()


func _setup_particle_material() -> void:
	var mat := ParticleProcessMaterial.new()
	
	# Direction and spread
	mat.direction = Vector3(direction.x, direction.y, 0.0)
	mat.spread = spread_angle / 2.0
	
	# Speed
	mat.initial_velocity_min = burst_speed_min
	mat.initial_velocity_max = burst_speed_max
	
	# Gravity (none for magic-style bursts)
	mat.gravity = Vector3.ZERO
	
	# Damping to slow particles
	mat.damping_min = 50.0
	mat.damping_max = 100.0
	
	# Scale over lifetime
	mat.scale_min = size_start / 8.0
	mat.scale_max = size_start / 8.0
	
	# Scale curve
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, size_end / size_start))
	var scale_curve_tex := CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	# Color gradient
	var gradient := Gradient.new()
	gradient.set_color(0, color_start)
	gradient.add_point(1.0, color_end)
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	
	# Emission shape (point)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	
	process_material = mat
	
	# Create simple procedural texture for particle
	_setup_particle_texture()


func _setup_particle_texture() -> void:
	# Create a simple radial gradient texture for the particle
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	
	for x in range(32):
		for y in range(32):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - (dist / 16.0), 0.0, 1.0)
			alpha = alpha * alpha # Softer falloff
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	
	var tex := ImageTexture.create_from_image(img)
	texture = tex


## Emit a burst of particles at the current position
func emit_burst() -> void:
	# Update material with current settings
	if process_material is ParticleProcessMaterial:
		var mat := process_material as ParticleProcessMaterial
		mat.initial_velocity_min = burst_speed_min
		mat.initial_velocity_max = burst_speed_max
		mat.spread = spread_angle / 2.0
		mat.direction = Vector3(direction.x, direction.y, 0.0)
	
	amount = burst_amount
	lifetime = burst_lifetime
	
	# Restart emission
	restart()
	emitting = true
	
	_is_bursting = true
	_burst_timer = burst_lifetime
	burst_started.emit()


## Emit burst at a specific position
func emit_burst_at(pos: Vector2) -> void:
	global_position = pos
	emit_burst()


## Update color gradient
func set_colors(start: Color, end: Color) -> void:
	color_start = start
	color_end = end
	
	if process_material is ParticleProcessMaterial:
		var mat := process_material as ParticleProcessMaterial
		var gradient := Gradient.new()
		gradient.set_color(0, color_start)
		gradient.add_point(1.0, color_end)
		var gradient_tex := GradientTexture1D.new()
		gradient_tex.gradient = gradient
		mat.color_ramp = gradient_tex

@tool
class_name TreasureParticles
extends Node2D

## Treasure Fountain Particles
## Creates a fountain of gold and silver particles when treasure is collected.
## Call emit_burst() to trigger the particle burst.

signal burst_started
signal burst_finished

@export_group("Burst Settings")
@export var burst_amount: int = 30
@export var burst_lifetime: float = 1.2
@export var burst_speed_min: float = 180.0
@export var burst_speed_max: float = 320.0

@export_group("Colors")
@export var gold_color: Color = Color(1.0, 0.84, 0.0, 1.0) # Gold
@export var silver_color: Color = Color(0.75, 0.75, 0.8, 1.0) # Silver

@export_group("Size")
@export var size_start: float = 10.0
@export var size_end: float = 4.0

@export_group("Fountain")
@export var spread_angle: float = 60.0 # Narrower for fountain effect
@export var gravity: float = 400.0 # Particles arc back down
@export var auto_free: bool = true ## Free the node after burst completes

var _gold_particles: GPUParticles2D
var _silver_particles: GPUParticles2D
var _burst_timer: float = 0.0
var _is_bursting: bool = false


func _ready() -> void:
	_setup_gold_particles()
	_setup_silver_particles()


func _process(delta: float) -> void:
	if _is_bursting:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_is_bursting = false
			burst_finished.emit()
			if auto_free:
				queue_free()


func _setup_gold_particles() -> void:
	_gold_particles = GPUParticles2D.new()
	_gold_particles.emitting = false
	_gold_particles.one_shot = true
	_gold_particles.explosiveness = 0.9
	_gold_particles.amount = burst_amount
	_gold_particles.lifetime = burst_lifetime
	
	var mat := _create_particle_material(gold_color, Color(1.0, 0.65, 0.0, 0.0))
	_gold_particles.process_material = mat
	_gold_particles.texture = _create_particle_texture()
	
	add_child(_gold_particles)


func _setup_silver_particles() -> void:
	_silver_particles = GPUParticles2D.new()
	_silver_particles.emitting = false
	_silver_particles.one_shot = true
	_silver_particles.explosiveness = 0.9
	_silver_particles.amount = burst_amount
	_silver_particles.lifetime = burst_lifetime
	
	var mat := _create_particle_material(silver_color, Color(0.9, 0.9, 0.95, 0.0))
	_silver_particles.process_material = mat
	_silver_particles.texture = _create_particle_texture()
	
	add_child(_silver_particles)


func _create_particle_material(color_start: Color, color_end: Color) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	
	# Direction - upward fountain
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = spread_angle / 2.0
	
	# Speed with variation
	mat.initial_velocity_min = burst_speed_min
	mat.initial_velocity_max = burst_speed_max
	
	# Gravity - makes particles arc back down
	mat.gravity = Vector3(0.0, gravity, 0.0)
	
	# Add some damping
	mat.damping_min = 20.0
	mat.damping_max = 40.0
	
	# Scale over lifetime
	mat.scale_min = size_start / 8.0
	mat.scale_max = size_start / 8.0
	
	# Scale curve - shrink over time
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.8))
	scale_curve.add_point(Vector2(1.0, size_end / size_start))
	var scale_curve_tex := CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	# Color gradient
	var gradient := Gradient.new()
	gradient.set_color(0, color_start)
	gradient.add_point(0.6, Color(color_start.r, color_start.g, color_start.b, 0.8))
	gradient.add_point(1.0, color_end)
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	
	# Emission shape - small sphere for variation
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	
	# Add some angular velocity for sparkle effect
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	
	return mat


func _create_particle_texture() -> ImageTexture:
	# Create a simple radial gradient texture for the particle (sparkle shape)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	
	for x in range(32):
		for y in range(32):
			var dist := Vector2(x, y).distance_to(center)
			var alpha := clampf(1.0 - (dist / 16.0), 0.0, 1.0)
			# Sharper falloff for sparkle look
			alpha = pow(alpha, 1.5)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	
	return ImageTexture.create_from_image(img)


## Emit a burst of treasure particles at the current position
func emit_burst() -> void:
	if _gold_particles:
		_gold_particles.restart()
		_gold_particles.emitting = true
	
	if _silver_particles:
		_silver_particles.restart()
		_silver_particles.emitting = true
	
	_is_bursting = true
	_burst_timer = burst_lifetime + 0.2 # Small buffer
	burst_started.emit()


## Emit burst at a specific position
func emit_burst_at(pos: Vector2) -> void:
	global_position = pos
	emit_burst()

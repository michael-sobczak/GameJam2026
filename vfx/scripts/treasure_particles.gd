@tool
class_name TreasureParticles
extends Node2D

## Treasure Fountain Particles
## Creates a fountain of gold and silver particles when treasure is collected.
## Call emit_burst() to trigger the particle burst.

signal burst_started
signal burst_finished

@export_group("Burst Settings")
@export var burst_amount: int = 50 ## Particles per emitter per burst
@export var burst_lifetime: float = 1.2
@export var burst_speed_min: float = 180.0
@export var burst_speed_max: float = 320.0

@export_group("Multi-Burst")
@export var burst_count: int = 3 ## Number of burst rounds
@export var burst_interval: float = 0.15 ## Time between bursts

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

var _gold_emitters: Array[GPUParticles2D] = []
var _silver_emitters: Array[GPUParticles2D] = []
var _burst_timer: float = 0.0
var _is_bursting: bool = false
var _bursts_remaining: int = 0
var _next_burst_timer: float = 0.0


func _ready() -> void:
	# Create emitters for each burst round
	for i in range(burst_count):
		_create_gold_emitter()
		_create_silver_emitter()


func _process(delta: float) -> void:
	# Handle firing subsequent bursts
	if _bursts_remaining > 0:
		_next_burst_timer -= delta
		if _next_burst_timer <= 0.0:
			_fire_next_burst()
	
	# Handle cleanup after all particles finish
	if _is_bursting:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_is_bursting = false
			burst_finished.emit()
			if auto_free:
				queue_free()


func _create_gold_emitter() -> GPUParticles2D:
	var emitter := GPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.amount = burst_amount
	emitter.lifetime = burst_lifetime
	
	var mat := _create_particle_material(gold_color, Color(1.0, 0.65, 0.0, 0.0))
	emitter.process_material = mat
	emitter.texture = _create_particle_texture()
	
	add_child(emitter)
	_gold_emitters.append(emitter)
	return emitter


func _create_silver_emitter() -> GPUParticles2D:
	var emitter := GPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.amount = burst_amount
	emitter.lifetime = burst_lifetime
	
	var mat := _create_particle_material(silver_color, Color(0.9, 0.9, 0.95, 0.0))
	emitter.process_material = mat
	emitter.texture = _create_particle_texture()
	
	add_child(emitter)
	_silver_emitters.append(emitter)
	return emitter


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


var _current_burst_index: int = 0

## Emit a burst of treasure particles at the current position
func emit_burst() -> void:
	_current_burst_index = 0
	_bursts_remaining = burst_count
	
	# Fire first burst immediately
	_fire_next_burst()
	
	_is_bursting = true
	# Total time: all bursts + last burst lifetime + buffer
	_burst_timer = (burst_count - 1) * burst_interval + burst_lifetime + 0.3
	burst_started.emit()


func _fire_next_burst() -> void:
	if _current_burst_index >= burst_count:
		return
	
	# Fire the emitters for this burst round
	if _current_burst_index < _gold_emitters.size():
		var gold_emitter := _gold_emitters[_current_burst_index]
		gold_emitter.restart()
		gold_emitter.emitting = true
	
	if _current_burst_index < _silver_emitters.size():
		var silver_emitter := _silver_emitters[_current_burst_index]
		silver_emitter.restart()
		silver_emitter.emitting = true
	
	_current_burst_index += 1
	_bursts_remaining -= 1
	_next_burst_timer = burst_interval


## Emit burst at a specific position
func emit_burst_at(pos: Vector2) -> void:
	global_position = pos
	emit_burst()

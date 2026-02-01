## Stationary laser turret entity with configurable firing behavior.
## Can detect player via vision cone and fire laser beams.
@tool
class_name LaserTurretEntity
extends Node2D

signal laser_fired
signal player_detected(player: Node2D)
signal player_lost(player: Node2D)

## Firing behavior modes for the turret.
enum FiringBehavior {
	ON_DETECTION, ## Only fires when a player is detected in the vision cone.
	CONTINUOUS,   ## Fires constantly regardless of detection.
	PULSE,        ## Pulses the beam 50% of the time (on/off cycle).
}

@export_group("Firing Settings")
@export var firing_behavior: FiringBehavior = FiringBehavior.ON_DETECTION ## How the turret fires.
@export var laser_range: float = 500.0 ## Maximum range of the laser beam in pixels.
@export var laser_damage: int = 1 ## Damage dealt by the laser per hit.
@export var pulse_duration: float = 1.0 ## Duration of on/off cycle for PULSE mode (seconds).

@export_group("Rotation Settings")
@export var rotation_speed: float = 0.0 ## Rotation speed in degrees per second. 0 = stationary.
@export var rotation_direction: int = 1 ## 1 = clockwise, -1 = counter-clockwise.

@export_group("Vision Settings")
@export var vision_range: float = 400.0 ## Range of the vision cone in pixels.
@export var fov_degrees: float = 45.0 ## Field of view in degrees.

@export_group("Visual Settings")
@export var laser_color: Color = Color(1.0, 0.2, 0.2, 0.9) ## Color of the laser beam.
@export var laser_width: float = 4.0 ## Base width of the laser beam.
@export var wave_amplitude: float = 0.6 ## How much the width varies along the beam (0-1, fraction of base width).
@export var wave_frequency: float = 4.0 ## Number of wave cycles along the beam length.
@export var wave_speed: float = 3.0 ## How fast the wave travels along the beam.

@export_group("Muzzle Settings")
@export var muzzle_offset: float = 16.0 ## Distance from center to muzzle tip in local X direction.

@export_group("Destruction Settings")
@export var time_to_destroy: float = 0.5 ## Seconds of continuous reflection needed to destroy the turret.

const LASER_IMPACT_PARTICLES_SCENE: PackedScene = preload("res://vfx/scenes/LaserImpactParticles.tscn")
const REFLECTION_TICK_SFX: AudioStream = preload("res://Kenny Audio Pack/Audio/tick_001.ogg")
const EXPLOSION_SFX: AudioStream = preload("res://DownloadedAssets/explosion.mp3")

@onready var vision_sensor: VisionConeSensor = $VisionConeSensor
@onready var laser_line: Line2D = $LaserLine
@onready var laser_raycast: RayCast2D = $LaserRaycast

var _impact_particles: LaserImpactParticles = null
var _current_facing: Vector2 = Vector2.RIGHT
var _is_firing: bool = false
var _pulse_timer: float = 0.0
var _pulse_on: bool = true
var _detected_target: Node2D = null
var _wave_time: float = 0.0 ## Time accumulator for traveling wave effect.
var _has_triggered_defeat: bool = false ## Prevents multiple defeat triggers.
var _width_curve: Curve ## Curve for varying beam width along its length.
var _is_disabled: bool = false ## True when turret has been destroyed by reflected laser.
var _reflection_audio: AudioStreamPlayer2D = null ## Looping tick sound during reflection.
var _is_reflecting: bool = false ## True while player is actively reflecting the laser.
var _reflection_time: float = 0.0 ## Accumulated time laser has been reflecting back at turret.
var _explosion_particles: GPUParticles2D = null ## Explosion effect when turret is destroyed.


func _notification(what: int) -> void:
	# Update facing when transform changes (works in both editor and game)
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_current_facing = Vector2.RIGHT.rotated(rotation)


func _ready():
	# Enable transform change notifications so _notification catches rotation changes
	set_notify_transform(true)
	
	# Derive initial facing from the node's rotation (RIGHT is angle 0 in local space)
	_current_facing = Vector2.RIGHT.rotated(rotation)
	
	# Skip game-only setup in editor
	if Engine.is_editor_hint():
		return
	
	# Setup vision cone sensor
	if vision_sensor:
		# Create cone profile with exported settings
		var profile = ConeProfile.new()
		profile.range_px = vision_range
		profile.fov_degrees = fov_degrees
		profile.origin_offset = Vector2.ZERO
		vision_sensor.cone_profile = profile
		# Use local RIGHT direction; VisionConeSensor accounts for global_rotation
		vision_sensor.set_facing(Vector2.RIGHT)
		
		# Connect signals
		vision_sensor.target_seen.connect(_on_target_seen)
		vision_sensor.target_lost.connect(_on_target_lost)
	
	# Setup laser line visual
	if laser_line:
		laser_line.default_color = laser_color
		laser_line.width = laser_width
		laser_line.visible = false
	
	# Setup laser raycast for hit detection
	if laser_raycast:
		laser_raycast.target_position = Vector2(laser_range, 0)
		laser_raycast.enabled = true
	
	# Create impact particles (add to parent so they don't rotate with turret)
	_impact_particles = LASER_IMPACT_PARTICLES_SCENE.instantiate() as LaserImpactParticles
	if _impact_particles:
		# Add to parent (level/world) so particles don't rotate with turret
		call_deferred("_add_particles_to_parent")
	
	# Create looping audio player for reflection tick sound
	_reflection_audio = AudioStreamPlayer2D.new()
	_reflection_audio.stream = REFLECTION_TICK_SFX
	_reflection_audio.bus = &"SFX"
	_reflection_audio.max_distance = 500.0
	add_child(_reflection_audio)
	# Connect finished signal to loop the sound
	_reflection_audio.finished.connect(_on_reflection_audio_finished)
	
	# Set initial vision facing
	_update_vision_facing()


func _process(delta: float):
	# Skip game logic in editor
	if Engine.is_editor_hint():
		return
	
	# Update wave time for traveling wave effect
	_wave_time += delta * wave_speed
	
	# Handle rotation (rotate the whole node)
	if rotation_speed > 0.0:
		var rotation_delta = deg_to_rad(rotation_speed * rotation_direction) * delta
		rotation += rotation_delta
		_current_facing = Vector2.RIGHT.rotated(rotation)
		_update_vision_facing()
	
	# Handle pulse mode timing
	if firing_behavior == FiringBehavior.PULSE:
		_pulse_timer += delta
		if _pulse_timer >= pulse_duration:
			_pulse_timer = 0.0
			_pulse_on = not _pulse_on
	
	# Determine if we should fire
	var should_fire = _should_fire()
	
	if should_fire != _is_firing:
		_is_firing = should_fire
		if _is_firing:
			_start_firing()
		else:
			_stop_firing()
	
	# Update laser visuals and damage if firing
	if _is_firing:
		_update_laser(delta)


## Check if the turret should be firing based on current behavior mode.
func _should_fire() -> bool:
	# Disabled turrets never fire
	if _is_disabled:
		return false
	
	match firing_behavior:
		FiringBehavior.ON_DETECTION:
			return _detected_target != null
		FiringBehavior.CONTINUOUS:
			return true
		FiringBehavior.PULSE:
			return _pulse_on
	return false


## Start firing the laser.
func _start_firing():
	if laser_line:
		laser_line.visible = true
	laser_fired.emit()


## Stop firing the laser.
func _stop_firing():
	if laser_line:
		laser_line.visible = false
	# Stop impact particles
	if _impact_particles:
		_impact_particles.stop_emission()
	# Stop reflection sound
	_stop_reflection_sound()


## Add impact particles to parent node (called deferred).
func _add_particles_to_parent() -> void:
	if _impact_particles and get_parent():
		get_parent().add_child(_impact_particles)
		_impact_particles.set_spark_color(laser_color)


## Update laser beam visual and check for hits.
func _update_laser(delta: float):
	if not laser_raycast or not laser_line:
		return
	
	# Set base width
	laser_line.width = laser_width
	
	# Muzzle offset in local coordinates (tip of turret is in +X direction in local space)
	var muzzle_local := Vector2(muzzle_offset, 0)
	
	# Set raycast to start from muzzle position
	laser_raycast.position = muzzle_local
	laser_raycast.target_position = Vector2(laser_range, 0)
	laser_raycast.force_raycast_update()
	
	# Get the end point of the laser (in local coordinates, relative to node origin)
	var laser_end: Vector2
	var has_collision := laser_raycast.is_colliding()
	
	if has_collision:
		# Convert collision point to local space (relative to node origin, not raycast)
		laser_end = to_local(laser_raycast.get_collision_point())
		var collision_point_global := laser_raycast.get_collision_point()
		
		# Check if we hit a player (vision_target group)
		var collider = laser_raycast.get_collider()
		var player_has_reflection := false
		
		if collider and collider.is_in_group(&"vision_target"):
			# Check if player has reflection mask active
			player_has_reflection = _check_player_reflection(collider)
			
			if player_has_reflection:
				# Player reflects laser - show particles at player and don't defeat
				if _impact_particles:
					_impact_particles.set_impact_position(collision_point_global)
					_impact_particles.set_spray_direction(-_current_facing)
					_impact_particles.start_emission()
				
				# Show glowing aura on player matching laser color
				_show_player_reflection_glow(collider, laser_color)
				
				# Start reflection tick sound loop
				_start_reflection_sound()
				
				# Accumulate reflection time and check if turret should be destroyed
				_check_reflected_laser_hit(delta)
			else:
				# No reflection - stop effects, reset timer, and trigger defeat
				_stop_reflection_sound()
				_reset_reflection_time()
				_hide_player_reflection_glow(collider)
				if _impact_particles:
					_impact_particles.set_impact_position(collision_point_global)
					_impact_particles.set_spray_direction(-_current_facing)
					_impact_particles.start_emission()
				_trigger_player_defeat(collider)
		else:
			# Hit a surface (not player) - show impact particles, stop reflection effects
			_stop_reflection_sound()
			_reset_reflection_time()
			_hide_all_player_reflection_glows()
			if _impact_particles:
				_impact_particles.set_impact_position(collision_point_global)
				# Spray direction is opposite of laser direction (sparks fly back)
				_impact_particles.set_spray_direction(-_current_facing)
				_impact_particles.start_emission()
			
			if collider and collider.has_method("take_damage"):
				collider.take_damage(laser_damage)
	else:
		# No collision - laser extends to full range from muzzle
		laser_end = muzzle_local + Vector2(laser_range, 0)
		# Stop particles and reflection effects when no collision
		_stop_reflection_sound()
		_reset_reflection_time()
		_hide_all_player_reflection_glows()
		if _impact_particles:
			_impact_particles.stop_emission()
	
	# Update Line2D points (starts at muzzle, ends at collision or max range)
	laser_line.clear_points()
	laser_line.add_point(muzzle_local)
	laser_line.add_point(laser_end)

	# Create traveling wave width curve
	_update_width_curve()


## Update the width curve to create a traveling wave effect along the beam.
func _update_width_curve() -> void:
	if not laser_line:
		return
	
	# Create or reuse curve
	if not _width_curve:
		_width_curve = Curve.new()
		_width_curve.bake_resolution = 32
		laser_line.width_curve = _width_curve
	
	# Clear existing points
	_width_curve.clear_points()
	
	# Generate wave pattern along the beam
	# Sample points along the curve (0.0 to 1.0 represents beam length)
	const NUM_POINTS := 16
	for i in range(NUM_POINTS + 1):
		var t := float(i) / float(NUM_POINTS)  # Position along beam (0 to 1)
		
		# Create traveling sine wave
		# Phase shifts with time to create movement, frequency controls wave count
		var phase := t * wave_frequency * TAU - _wave_time * TAU
		var wave_value := sin(phase)
		
		# Map sine (-1 to 1) to width multiplier (1 - amplitude to 1 + amplitude)
		# This creates thicker and thinner sections along the beam
		var width_multiplier := 1.0 + (wave_value * wave_amplitude)
		width_multiplier = max(0.3, width_multiplier)  # Ensure minimum visibility
		
		# Add point to curve (x = position along beam, y = width multiplier)
		_width_curve.add_point(Vector2(t, width_multiplier))


## Check if a player node has reflection mask active.
func _check_player_reflection(player_node: Node2D) -> bool:
	if not player_node:
		return false
	
	# Try to get MaskEffectManager from the player
	var mask_manager: MaskEffectManager = player_node.get_node_or_null("MaskEffectManager") as MaskEffectManager
	if mask_manager and mask_manager.reflection_active:
		return true
	
	return false


## Start the looping tick sound for laser reflection.
func _start_reflection_sound() -> void:
	if _is_reflecting:
		return  # Already playing
	_is_reflecting = true
	if _reflection_audio and not _reflection_audio.playing:
		_reflection_audio.play()


## Stop the looping tick sound for laser reflection.
func _stop_reflection_sound() -> void:
	if not _is_reflecting:
		return
	_is_reflecting = false
	if _reflection_audio:
		_reflection_audio.stop()


## Callback to loop the reflection tick sound.
func _on_reflection_audio_finished() -> void:
	if _is_reflecting and _reflection_audio:
		_reflection_audio.play()


## Show reflection glow on a player node.
func _show_player_reflection_glow(player_node: Node2D, color: Color) -> void:
	if not player_node:
		return
	var mask_manager: MaskEffectManager = player_node.get_node_or_null("MaskEffectManager") as MaskEffectManager
	if mask_manager:
		mask_manager.show_reflection_glow(color)


## Hide reflection glow on a player node.
func _hide_player_reflection_glow(player_node: Node2D) -> void:
	if not player_node:
		return
	var mask_manager: MaskEffectManager = player_node.get_node_or_null("MaskEffectManager") as MaskEffectManager
	if mask_manager:
		mask_manager.hide_reflection_glow()


## Hide reflection glow on all players (used when laser stops hitting player).
func _hide_all_player_reflection_glows() -> void:
	var players = get_tree().get_nodes_in_group(&"player")
	for player in players:
		_hide_player_reflection_glow(player)


## Check if the reflected laser hits the turret back and accumulate destruction time.
## Called each frame while laser is being reflected.
func _check_reflected_laser_hit(delta: float) -> void:
	# The laser is being reflected by the player, which means it bounces back toward the turret
	# Accumulate reflection time
	_reflection_time += delta
	
	# Check if enough time has passed to destroy the turret
	if _reflection_time >= time_to_destroy and not _is_disabled:
		_disable_turret()


## Reset the reflection time accumulator (called when reflection stops).
func _reset_reflection_time() -> void:
	_reflection_time = 0.0


## Permanently disable the turret (destroyed by reflected laser).
func _disable_turret() -> void:
	if _is_disabled:
		return
	_is_disabled = true
	
	# Stop firing
	_stop_firing()
	_stop_reflection_sound()
	_reset_reflection_time()
	_hide_all_player_reflection_glows()
	
	# Play explosion sound
	AudioManager.play_stream(EXPLOSION_SFX)
	
	# Create and trigger explosion particle effect
	_create_explosion_particles()
	
	# Turn turret dark gray
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
	
	# Also gray out any other visual children (except particles)
	for child in get_children():
		if child is CanvasItem and child != _impact_particles and child != _explosion_particles:
			(child as CanvasItem).modulate = Color(0.3, 0.3, 0.3, 1.0)
	
	# Emit signal so level knows turret was destroyed
	player_detected.emit(null)  # Reusing signal with null to indicate destruction
	
	print("LaserTurret: Destroyed by reflected laser!")


## Create and trigger explosion particle effect at the turret's position.
func _create_explosion_particles() -> void:
	_explosion_particles = GPUParticles2D.new()
	_explosion_particles.name = "ExplosionParticles"
	_explosion_particles.emitting = false
	_explosion_particles.amount = 30
	_explosion_particles.lifetime = 0.8
	_explosion_particles.one_shot = true
	_explosion_particles.explosiveness = 1.0
	_explosion_particles.z_index = 20  # Render above turret
	
	# Create particle material
	var mat := ParticleProcessMaterial.new()
	
	# Direction - explode outward in all directions
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	
	# Speed
	mat.initial_velocity_min = 100.0
	mat.initial_velocity_max = 250.0
	
	# Gravity - slight downward pull
	mat.gravity = Vector3(0, 200.0, 0)
	
	# Damping
	mat.damping_min = 50.0
	mat.damping_max = 100.0
	
	# Scale
	mat.scale_min = 0.8
	mat.scale_max = 1.5
	
	# Scale curve - shrink over lifetime
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_curve_tex := CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	mat.scale_curve = scale_curve_tex
	
	# Color gradient - orange to red to dark fade
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.2, 1.0))  # Bright yellow-orange
	gradient.add_point(0.2, Color(1.0, 0.5, 0.1, 1.0))  # Orange
	gradient.add_point(0.5, Color(0.9, 0.2, 0.1, 0.9))  # Red-orange
	gradient.add_point(0.8, Color(0.4, 0.1, 0.05, 0.6))  # Dark red
	gradient.add_point(1.0, Color(0.2, 0.05, 0.02, 0.0))  # Fade out
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	
	# Emission shape - small sphere at center
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	
	_explosion_particles.process_material = mat
	
	# Create glowing particle texture
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	for x in range(32):
		for y in range(32):
			var dist := Vector2(x, y).distance_to(center)
			var core := clampf(1.0 - (dist / 8.0), 0.0, 1.0)
			var glow := clampf(1.0 - (dist / 16.0), 0.0, 1.0)
			glow = glow * glow
			var brightness := maxf(core, glow * 0.6)
			var alpha := clampf(1.0 - (dist / 16.0), 0.0, 1.0)
			img.set_pixel(x, y, Color(brightness, brightness, brightness, alpha))
	_explosion_particles.texture = ImageTexture.create_from_image(img)
	
	add_child(_explosion_particles)
	
	# Start explosion
	_explosion_particles.restart()
	_explosion_particles.emitting = true


## Trigger player defeat when hit by laser (same as being caught by guard).
func _trigger_player_defeat(player_node: Node2D) -> void:
	# Only trigger once
	if _has_triggered_defeat:
		return
	_has_triggered_defeat = true
	
	# Emit signal for external listeners
	player_detected.emit(player_node)
	
	# Find the current level and call its defeat handler
	var level: Level = _find_level()
	if level and level.has_method("_on_guard_spotted_player"):
		level._on_guard_spotted_player(player_node)
	else:
		# Fallback: try to find defeat mechanism through tree
		push_warning("LaserTurret: Could not find Level node to trigger defeat")


## Find the Level node in the scene tree.
func _find_level() -> Level:
	var node: Node = self
	while node:
		if node is Level:
			return node as Level
		node = node.get_parent()
	# Try finding via tree root
	var root = get_tree().current_scene
	if root is Level:
		return root as Level
	return null


## Update the vision cone facing direction.
func _update_vision_facing():
	# Vision sensor uses local RIGHT direction since node rotation handles orientation
	if vision_sensor:
		vision_sensor.set_facing(Vector2.RIGHT)


## Handle target detection.
func _on_target_seen(target: Node2D):
	_detected_target = target
	player_detected.emit(target)


## Handle target lost.
func _on_target_lost(target: Node2D):
	if _detected_target == target:
		_detected_target = null
		player_lost.emit(target)


## Get the current facing direction.
func get_facing() -> Vector2:
	return _current_facing


## Set the facing direction manually (rotates the node).
func set_facing(direction: Vector2):
	if direction != Vector2.ZERO:
		_current_facing = direction.normalized()
		rotation = _current_facing.angle()
		_update_vision_facing()


func _exit_tree() -> void:
	# Clean up impact particles when turret is removed
	if _impact_particles and is_instance_valid(_impact_particles):
		_impact_particles.queue_free()
		_impact_particles = null

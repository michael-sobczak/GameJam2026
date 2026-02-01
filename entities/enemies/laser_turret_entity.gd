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
@export var laser_width: float = 4.0 ## Width of the laser beam.

@onready var vision_sensor: VisionConeSensor = $VisionConeSensor
@onready var laser_line: Line2D = $LaserLine
@onready var laser_raycast: RayCast2D = $LaserRaycast

var _current_facing: Vector2 = Vector2.RIGHT
var _is_firing: bool = false
var _pulse_timer: float = 0.0
var _pulse_on: bool = true
var _detected_target: Node2D = null


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
	
	# Set initial vision facing
	_update_vision_facing()


func _process(delta: float):
	# Skip game logic in editor
	if Engine.is_editor_hint():
		return
	
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
		_update_laser()


## Check if the turret should be firing based on current behavior mode.
func _should_fire() -> bool:
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


## Update laser beam visual and check for hits.
func _update_laser():
	if not laser_raycast or not laser_line:
		return
	
	# Raycast points in local RIGHT direction; node rotation handles orientation
	laser_raycast.target_position = Vector2(laser_range, 0)
	laser_raycast.force_raycast_update()
	
	# Get the end point of the laser (in local coordinates)
	var laser_end: Vector2
	if laser_raycast.is_colliding():
		laser_end = to_local(laser_raycast.get_collision_point())
		
		# Check if we hit something that can take damage
		var collider = laser_raycast.get_collider()
		if collider and collider.has_method("take_damage"):
			collider.take_damage(laser_damage)
		elif collider and collider.is_in_group(&"vision_target"):
			# Try to find HurtBox on the collider or parent
			var hurtbox = _find_hurtbox(collider)
			if hurtbox and hurtbox.has_method("_on_area_entered"):
				# Emit damage through HurtBox system if available
				pass  # HurtBox handles damage through area detection
	else:
		laser_end = Vector2(laser_range, 0)
	
	# Update Line2D points
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(laser_end)


## Find a HurtBox on the given node or its parent.
func _find_hurtbox(node: Node) -> Node:
	if node.has_node("HurtBox"):
		return node.get_node("HurtBox")
	if node.get_parent() and node.get_parent().has_node("HurtBox"):
		return node.get_parent().get_node("HurtBox")
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

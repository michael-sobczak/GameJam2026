## Component that detects targets within a cone-shaped vision field.
## Uses distance, angle, and line-of-sight checks to determine visibility.
## Shares cone parameters with FlashlightCone via ConeProfile resource.
class_name VisionConeSensor
extends Node2D

signal target_seen(target: Node2D)
signal target_lost(target: Node2D)

@export_group("Settings")
@export var enabled: bool = true ## Whether vision detection is active.
@export var scan_rate_hz: float = 10.0 ## How many times per second to scan for targets.
@export var target_group: StringName = &"vision_target" ## Group name for detectable targets.
@export var los_blocking_collision_mask: int = 1 ## Physics layers that block line of sight (typically walls).

@export_group("Cone Profile")
@export var cone_profile: ConeProfile ## Shared cone parameters (range, FOV, etc).

var visible_targets: Array[Node2D] = []
var _scan_timer: Timer
var _current_facing: Vector2 = Vector2.DOWN

func _ready():
	if not cone_profile:
		# Create default profile if none provided
		cone_profile = ConeProfile.new()
		cone_profile.range_px = 300.0
		cone_profile.fov_degrees = 60.0
	
	_setup_scan_timer()

func _setup_scan_timer():
	_scan_timer = Timer.new()
	_scan_timer.wait_time = 1.0 / scan_rate_hz
	_scan_timer.timeout.connect(_scan_for_targets)
	_scan_timer.autostart = true
	add_child(_scan_timer)

## Update the facing direction for vision cone orientation.
## @param direction: Normalized direction vector (e.g., from CharacterEntity.facing)
func set_facing(direction: Vector2):
	if direction != Vector2.ZERO:
		_current_facing = direction.normalized()

## Check if a target is visible within the vision cone.
## @param target: The target node to check.
## @return: true if target is visible (within range, FOV, and line of sight).
func can_see(target: Node2D) -> bool:
	if not enabled or not target or not cone_profile:
		return false
	
	# Get target position (assume it's a Node2D or has global_position)
	var target_pos: Vector2
	if target is Node2D:
		target_pos = target.global_position
	else:
		return false
	
	var origin_pos = global_position + cone_profile.origin_offset
	
	# Distance check
	var distance = origin_pos.distance_to(target_pos)
	if distance > cone_profile.range_px:
		return false
	
	# Angle check
	var direction_to_target = origin_pos.direction_to(target_pos)
	var angle_to_target = direction_to_target.angle()
	var facing_angle = _current_facing.angle()
	
	var angle_diff = abs(angle_to_target - facing_angle)
	# Normalize angle difference to [-PI, PI]
	if angle_diff > PI:
		angle_diff = 2 * PI - angle_diff
	
	var half_fov_rad = deg_to_rad(cone_profile.fov_degrees / 2.0)
	if angle_diff > half_fov_rad:
		return false
	
	# Line of sight check
	if not _check_line_of_sight(origin_pos, target_pos):
		return false
	
	return true

## Perform a raycast to check if there's a clear line of sight.
## @param from: Starting position.
## @param to: Target position.
## @return: true if line of sight is clear (no walls blocking).
func _check_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = los_blocking_collision_mask
	query.exclude = []  # Could exclude self if needed
	
	var result = space_state.intersect_ray(query)
	
	# If we hit something, check if it's the target or a wall
	if result:
		# Check if we hit the target (within small threshold)
		var hit_pos: Vector2 = result.position
		var distance_to_target = hit_pos.distance_to(to)
		if distance_to_target < 5.0:  # Small threshold for target collision
			return true
		# Otherwise, something blocked the view
		return false
	
	# No collision means clear line of sight
	return true

## Scan for all targets in the vision cone.
func _scan_for_targets():
	if not enabled:
		return
	
	var current_visible = []
	var targets = get_tree().get_nodes_in_group(target_group)
	
	for target in targets:
		if target == get_parent():  # Don't detect self
			continue
		
		if can_see(target):
			current_visible.append(target)
			if not visible_targets.has(target):
				# Newly detected target
				visible_targets.append(target)
				target_seen.emit(target)
	
	# Check for lost targets
	for target in visible_targets.duplicate():
		if not current_visible.has(target):
			visible_targets.erase(target)
			target_lost.emit(target)
	
	visible_targets = current_visible

## Get all currently visible targets.
## @return: Array of visible Node2D targets.
func get_visible_targets() -> Array[Node2D]:
	return visible_targets.duplicate()

## Enable or disable vision detection.
func set_enabled(value: bool):
	enabled = value
	if _scan_timer:
		_scan_timer.paused = not enabled

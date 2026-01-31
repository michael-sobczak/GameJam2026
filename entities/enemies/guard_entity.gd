## Guard entity that uses perception (FOV + LOS) and navigation to patrol, chase, and investigate.
## Extends CharacterEntity with guard-specific behavior.
class_name GuardEntity
extends CharacterEntity

signal target_spotted(target: Node2D)
signal target_lost(target: Node2D)

@export_group("Guard Settings")
@export var chase_speed: float = 200.0 ## Speed when chasing target.
@export var patrol_speed: float = 100.0 ## Speed when patrolling.
@export var forget_time: float = 3.0 ## Time after losing LOS before giving up chase.
@export var investigate_time: float = 2.0 ## Time to linger at last seen position.

@export_group("Patrol")
@export var patrol_points: Array[NodePath] = [] ## Array of NodePaths to patrol waypoints.
@export var pause_at_waypoint: float = 1.0 ## Seconds to wait at each patrol point.
@export var patrol_loop: bool = true ## If true, loops patrol; if false, ping-pongs.

@export_group("Home Position")
@export var home_position: Vector2 ## Position to return to after investigation.
@export var home_facing: Vector2 = Vector2.DOWN ## Direction to face when at home.

@onready var perception: VisionConeSensor = $Perception
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var alert_indicator: AlertIndicator = $AlertIndicator

var current_target: Node2D = null
var last_seen_position: Vector2 = Vector2.ZERO
var forget_timer: float = 0.0
var is_chasing: bool = false

func _ready():
	super._ready()
	if not home_position:
		home_position = global_position
	
	# Auto-build patrol path from Marker2D children if patrol_points is empty
	# Defer to ensure all children (including Marker2D nodes added in scene) are ready
	if patrol_points.is_empty():
		call_deferred("_build_patrol_path_from_markers")
	
	# Setup perception cone profile if not set
	if perception:
		if not perception.cone_profile:
			# Create default cone profile
			var profile = ConeProfile.new()
			profile.range_px = 300.0
			profile.fov_degrees = 90.0
			profile.origin_offset = Vector2(0, -10)
			perception.cone_profile = profile
		
		# Connect perception signals
		perception.target_seen.connect(_on_target_seen)
		perception.target_lost.connect(_on_target_lost)
		perception.set_facing(facing)
	
	# Connect facing changes to perception
	direction_changed.connect(_on_facing_changed)
	
	# Setup navigation agent
	if navigation_agent:
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = 4.0
		# Wait for NavigationServer to be ready (requires NavigationRegion2D in level)
		call_deferred("_setup_navigation")

func _setup_navigation():
	# Wait for NavigationServer to be ready
	# NOTE: Level must have a NavigationRegion2D with a navigation mesh for guards to pathfind
	await get_tree().physics_frame
	await NavigationServer2D.map_changed
	
	# Wait an additional frame to ensure navigation agent is fully initialized
	await get_tree().physics_frame
	
	if navigation_agent:
		# Set agent position to current position
		NavigationServer2D.agent_set_position(navigation_agent.get_rid(), global_position)
		navigation_agent.target_position = global_position
		
		print("Guard '%s': Navigation setup complete. Agent map: %s" % [name, NavigationServer2D.agent_get_map(navigation_agent.get_rid())])
		
		# If we have patrol points, start patrolling now that navigation is ready
		if not patrol_points.is_empty():
			_start_patrol_if_has_points()

func _process(delta):
	super._process(delta)
	
	# Update perception facing
	if perception and update_facing_with_movement:
		perception.set_facing(facing)
	
	# Update forget timer (handled by ChaseState, but keep for backup)
	if is_chasing and current_target:
		if perception and perception.can_see(current_target):
			forget_timer = 0.0
		else:
			forget_timer += delta
			# Note: ChaseState handles the actual transition

func _on_facing_changed(direction: Vector2):
	if perception:
		perception.set_facing(direction)

func _on_target_seen(target: Node2D):
	if not current_target:
		current_target = target
		last_seen_position = target.global_position
		is_chasing = true
		forget_timer = 0.0
		target_spotted.emit(target)
		
		# Play alert sound
		AudioManager.play_sfx("guard_alert")
		
		# Show alert indicator
		if alert_indicator:
			alert_indicator.show_indicator()
	elif current_target == target:
		# Update last seen position
		last_seen_position = target.global_position

func _on_target_lost(target: Node2D):
	if current_target == target:
		current_target = null
		is_chasing = false
		target_lost.emit(target)
		
		# Hide alert indicator
		if alert_indicator:
			alert_indicator.hide_indicator()

## Automatically builds patrol path from Marker2D children nodes.
## Finds all Marker2D children and adds them to patrol_points as a loop.
## Called deferred to ensure all children are added to the scene tree.
func _build_patrol_path_from_markers():
	var markers: Array[Marker2D] = []
	
	# Find all Marker2D children
	for child in get_children():
		if child is Marker2D:
			markers.append(child as Marker2D)
	
	# If we found markers, build patrol path
	if not markers.is_empty():
		# Convert markers to NodePaths and add to patrol_points
		patrol_points.clear()
		for marker in markers:
			var path = get_path_to(marker)
			patrol_points.append(path)
			print("Guard '%s': Added patrol point '%s' at position %s" % [name, marker.name, marker.global_position])
		
		# Ensure patrol loops endlessly
		patrol_loop = true
		print("Guard '%s': Built patrol path from %d Marker2D children (patrol_loop=%s)" % [name, markers.size(), patrol_loop])
		
		# Note: Patrol will start after navigation is set up (in _setup_navigation)
	else:
		print("Guard '%s': No Marker2D children found for patrol path" % name)

## Starts patrol mode if guard has patrol points.
## Called deferred to ensure state machine is ready.
func _start_patrol_if_has_points():
	if patrol_points.is_empty():
		print("Guard '%s': _start_patrol_if_has_points called but patrol_points is empty" % name)
		return
	
	print("Guard '%s': Starting patrol with %d patrol points" % [name, patrol_points.size()])
	
	var guard_states = get_node_or_null("GuardStates")
	if not guard_states:
		push_error("Guard '%s': GuardStates node not found" % name)
		return
	
	if not guard_states is StateMachine:
		push_error("Guard '%s': GuardStates is not a StateMachine" % name)
		return
	
	var patrol_state = guard_states.get_node_or_null("patrol")
	if not patrol_state:
		push_error("Guard '%s': Patrol state not found in GuardStates" % name)
		return
	
	print("Guard '%s': Enabling patrol state" % name)
	guard_states.enable_state(patrol_state)

## Get the current patrol point positions.
func get_patrol_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for path in patrol_points:
		var node = get_node_or_null(path)
		if node and node is Node2D:
			positions.append(node.global_position)
		else:
			print("Guard '%s': Warning - Could not resolve patrol point NodePath: %s" % [name, path])
	return positions

## Set navigation target position.
func set_navigation_target(pos: Vector2):
	if navigation_agent:
		# Update agent position before setting target
		NavigationServer2D.agent_set_position(navigation_agent.get_rid(), global_position)
		navigation_agent.target_position = pos
		print("Guard '%s': Set navigation target to: %s" % [name, pos])

## Check if navigation has reached target.
func is_navigation_finished() -> bool:
	if navigation_agent:
		return navigation_agent.is_navigation_finished()
	return true

## Get next path position for navigation.
func get_next_path_position() -> Vector2:
	if navigation_agent:
		return navigation_agent.get_next_path_position()
	return global_position

## Set guard speed based on state.
func set_guard_speed(speed_type: String):
	match speed_type:
		"chase":
			max_speed = chase_speed
		"patrol":
			max_speed = patrol_speed
		_:
			max_speed = patrol_speed

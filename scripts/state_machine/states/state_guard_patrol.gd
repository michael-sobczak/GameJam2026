## Guard state: Patrols between waypoints.
## Transitions to ChaseState when target is spotted.
class_name StateGuardPatrol
extends StateEntity

@export var pause_at_waypoint: float = 1.0 ## Seconds to wait at each waypoint.

var _patrol_positions: Array[Vector2] = []
var _current_patrol_index: int = 0
var _patrol_direction: int = 1 ## 1 for forward, -1 for backward (ping-pong)
var _waiting_at_waypoint: bool = false
var _wait_timer: float = 0.0

func enter():
	super.enter()
	if not entity or not entity is GuardEntity:
		print("StateGuardPatrol: enter() - entity is not GuardEntity")
		return
	
	var guard = entity as GuardEntity
	guard.set_guard_speed("patrol")
	
	# Connect to guard signals for transitions
	if not guard.target_spotted.is_connected(_on_target_spotted):
		guard.target_spotted.connect(_on_target_spotted)
	
	# Get patrol positions
	_patrol_positions = guard.get_patrol_positions()
	print("StateGuardPatrol: enter() - Found %d patrol positions" % _patrol_positions.size())
	
	# If no patrol points, use home position
	if _patrol_positions.is_empty():
		_patrol_positions.append(guard.home_position)
		print("StateGuardPatrol: No patrol points, using home position: %s" % guard.home_position)
	
	_current_patrol_index = 0
	_patrol_direction = 1
	_waiting_at_waypoint = false
	_wait_timer = 0.0
	
	# Start moving to first patrol point
	if not _patrol_positions.is_empty():
		var target_pos = _patrol_positions[_current_patrol_index]
		print("StateGuardPatrol: Setting navigation target to patrol point %d: %s" % [_current_patrol_index, target_pos])
		print("StateGuardPatrol: Guard current position: %s" % guard.global_position)
		if guard.navigation_agent:
			var agent_map = NavigationServer2D.agent_get_map(guard.navigation_agent.get_rid())
			print("StateGuardPatrol: NavigationAgent map: %s, current target: %s" % [agent_map, guard.navigation_agent.target_position])
		guard.set_navigation_target(target_pos)

func _on_target_spotted(_target: Node2D):
	# Transition to chase state
	var chase_state = get_parent().get_node_or_null("chase")
	if chase_state:
		chase_state.enable()
	else:
		complete()

func physics_update(delta):
	super.physics_update(delta)
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	
	# Check for target spotted
	if guard.current_target:
		complete()
		return
	
	# Handle waiting at waypoint
	if _waiting_at_waypoint:
		_wait_timer += delta
		if _wait_timer >= pause_at_waypoint:
			_waiting_at_waypoint = false
			_wait_timer = 0.0
			_move_to_next_patrol_point(guard)
		return
	
	# Check navigation state
	if not guard.navigation_agent:
		print("StateGuardPatrol: Warning - Guard has no navigation_agent")
		return
	
	# Update navigation agent position to match guard position
	NavigationServer2D.agent_set_position(guard.navigation_agent.get_rid(), guard.global_position)
	
	var next_pos = guard.get_next_path_position()
	var current_pos = guard.global_position
	var target_pos = _patrol_positions[_current_patrol_index] if _current_patrol_index < _patrol_positions.size() else current_pos
	var distance_to_target = current_pos.distance_to(target_pos)
	
	# Check if reached current patrol point (within threshold)
	if distance_to_target < guard.navigation_agent.target_desired_distance:
		_waiting_at_waypoint = true
		guard.stop()
		# print("StateGuardPatrol: Reached patrol point %d (distance: %s)" % [_current_patrol_index, distance_to_target])
		return
	
	# Check if navigation has a valid path
	# If next_pos equals current_pos, navigation might not have calculated path yet
	if next_pos == current_pos:
		# Navigation path not ready - try setting target again
		if _current_patrol_index >= 0 and _current_patrol_index < _patrol_positions.size():
			guard.set_navigation_target(_patrol_positions[_current_patrol_index])
		return
	
	# Move towards next path position
	guard.move_towards(next_pos)

func _move_to_next_patrol_point(guard: GuardEntity):
	if _patrol_positions.is_empty():
		return
	
	# Update patrol index
	if guard.patrol_loop:
		# Loop mode
		_current_patrol_index = (_current_patrol_index + 1) % _patrol_positions.size()
	else:
		# Ping-pong mode
		_current_patrol_index += _patrol_direction
		if _current_patrol_index >= _patrol_positions.size():
			_current_patrol_index = _patrol_positions.size() - 2
			_patrol_direction = -1
		elif _current_patrol_index < 0:
			_current_patrol_index = 1
			_patrol_direction = 1
	
	# Set navigation target
	if _current_patrol_index >= 0 and _current_patrol_index < _patrol_positions.size():
		guard.set_navigation_target(_patrol_positions[_current_patrol_index])

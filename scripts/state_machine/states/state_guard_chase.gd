## Guard state: Chases the target using navigation.
## Transitions to InvestigateState when target is lost for forget_time.
class_name StateGuardChase
extends StateEntity

@export var target_update_rate_hz: float = 10.0 ## How often to update navigation target (times per second).

var _update_timer: float = 0.0
var _update_interval: float

func enter():
	super.enter()
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	guard.set_guard_speed("chase")
	_update_interval = 1.0 / target_update_rate_hz
	_update_timer = 0.0
	
	# Connect to guard signals for transitions
	if not guard.target_lost.is_connected(_on_target_lost):
		guard.target_lost.connect(_on_target_lost)
	
	# Immediately set target
	if guard.current_target:
		guard.set_navigation_target(guard.current_target.global_position)

func _on_target_lost(_target: Node2D):
	# Transition to investigate state
	var investigate_state = get_parent().get_node_or_null("investigate")
	if investigate_state:
		investigate_state.enable()
	else:
		complete()

func physics_update(delta):
	super.physics_update(delta)
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	
	# Check if target lost
	if not guard.current_target:
		# Transition to investigate
		var investigate_state = get_parent().get_node_or_null("investigate")
		if investigate_state:
			investigate_state.enable()
		return
	
	# Check forget timer (target lost LOS for too long)
	if guard.forget_timer >= guard.forget_time:
		# Transition to investigate
		var investigate_state = get_parent().get_node_or_null("investigate")
		if investigate_state:
			investigate_state.enable()
		return
	
	# Update navigation target at throttled rate
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		if is_instance_valid(guard.current_target):
			guard.set_navigation_target(guard.current_target.global_position)
			guard.last_seen_position = guard.current_target.global_position
	
	# Move towards target
	if not guard.is_navigation_finished():
		var next_pos = guard.get_next_path_position()
		guard.move_towards(next_pos)
	elif is_instance_valid(guard.current_target):
		var target_pos = guard.current_target.global_position
		var dist = guard.global_position.distance_to(target_pos)
		var stop_distance: float = guard.navigation_agent.target_desired_distance if guard.navigation_agent else 4.0
		if dist <= stop_distance:
			# Close enough: stop so we don't run into the player (keeps "run around in front" feel)
			guard.stop()
		else:
			# Path not ready yet or target moved: move towards target
			guard.move_towards(target_pos)
	else:
		guard.stop()

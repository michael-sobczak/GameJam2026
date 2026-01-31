## Guard state: Moves to last seen position and searches.
## Transitions to ChaseState if target spotted, or ReturnState after investigate_time.
class_name StateGuardInvestigate
extends StateEntity

@export var investigate_time: float = 2.0 ## Time to linger at last seen position.

var _investigate_timer: float = 0.0
var _has_reached_position: bool = false

func enter():
	super.enter()
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	guard.set_guard_speed("patrol")
	_investigate_timer = 0.0
	_has_reached_position = false
	
	# Connect to guard signals for transitions
	if not guard.target_spotted.is_connected(_on_target_spotted):
		guard.target_spotted.connect(_on_target_spotted)
	
	# Move to last seen position
	if guard.last_seen_position != Vector2.ZERO:
		guard.set_navigation_target(guard.last_seen_position)
	else:
		# No last seen position, skip investigation
		complete()

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
	
	# Check if target spotted again
	if guard.current_target:
		complete()
		return
	
	# Check if reached investigation position
	if not _has_reached_position:
		if guard.is_navigation_finished():
			_has_reached_position = true
			guard.stop()
			# Face the direction we came from (towards where target might be)
			var direction = guard.global_position.direction_to(guard.last_seen_position)
			if direction != Vector2.ZERO:
				guard.facing = direction
		else:
			# Move towards investigation position
			var next_pos = guard.get_next_path_position()
			guard.move_towards(next_pos)
	else:
		# Wait and scan
		_investigate_timer += delta
		if _investigate_timer >= investigate_time:
			# Transition to return state
			var return_state = get_parent().get_node_or_null("return")
			if return_state:
				return_state.enable()
			else:
				complete()

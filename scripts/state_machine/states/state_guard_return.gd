## Guard state: Returns to home position or nearest patrol point.
## Transitions to SentryState or PatrolState on arrival.
class_name StateGuardReturn
extends StateEntity

func enter():
	super.enter()
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	guard.set_guard_speed("patrol")
	
	# Connect to guard signals for transitions
	if not guard.target_spotted.is_connected(_on_target_spotted):
		guard.target_spotted.connect(_on_target_spotted)
	
	# Return to home position
	guard.set_navigation_target(guard.home_position)

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
	
	# Check if reached home
	if guard.is_navigation_finished():
		guard.stop()
		guard.facing = guard.home_facing
		# Transition back to sentry or patrol
		var sentry_state = get_parent().get_node_or_null("sentry")
		if sentry_state:
			sentry_state.enable()
		else:
			complete()
		return
	
	# Move towards home
	var next_pos = guard.get_next_path_position()
	guard.move_towards(next_pos)

## Guard state: Stationary sentry that scans for targets.
## Transitions to ChaseState when target is spotted.
class_name StateGuardSentry
extends StateEntity

@export var scan_rotation_speed: float = 0.0 ## Degrees per second to rotate while scanning (0 = no rotation).
@export var transition_to_patrol: State ## Optional: transition to patrol state if set.

var _rotation_timer: float = 0.0
var _scan_direction: float = 0.0
var _sequence_index: int = 0
var _sequence_timer: float = 0.0

func enter():
	super.enter()
	if entity and entity is GuardEntity:
		var guard = entity as GuardEntity
		guard.set_guard_speed("patrol")
		guard.stop()
		_rotation_timer = 0.0
		_sequence_index = 0
		_sequence_timer = 0.0
		# If guard has a sentry sequence, face first direction; else use home_facing
		if _has_sentry_sequence(guard):
			guard.facing = guard.sentry_sequence_directions[0].normalized()
			_scan_direction = guard.facing.angle()
		elif guard.home_facing != Vector2.ZERO:
			guard.facing = guard.home_facing
			_scan_direction = guard.facing.angle()
		
		# Connect to guard signals for transitions
		if not guard.target_spotted.is_connected(_on_target_spotted):
			guard.target_spotted.connect(_on_target_spotted)

func _on_target_spotted(_target: Node2D):
	# Transition to chase state
	var chase_state = get_parent().get_node_or_null("chase")
	if chase_state:
		chase_state.enable()
	else:
		complete()

func _has_sentry_sequence(guard: GuardEntity) -> bool:
	var dirs = guard.sentry_sequence_directions
	var durs = guard.sentry_sequence_durations
	return dirs.size() > 0 and durs.size() == dirs.size()

func update(delta):
	super.update(delta)
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	
	# Sentry sequence: face direction[0] for duration[0], then direction[1] for duration[1], etc.; loop
	if _has_sentry_sequence(guard):
		var dirs = guard.sentry_sequence_directions
		var durs = guard.sentry_sequence_durations
		var dir_vec = dirs[_sequence_index]
		if dir_vec != Vector2.ZERO:
			guard.facing = dir_vec.normalized()
			# Force animation to update this frame (entity _process runs before state machine)
			if guard.has_method("_update_animation"):
				guard._update_animation()
		_sequence_timer += delta
		if _sequence_timer >= durs[_sequence_index]:
			_sequence_timer = 0.0
			_sequence_index = (_sequence_index + 1) % dirs.size()
		return
	
	# Optional continuous rotation (use guard's per-instance value if set, else state's export)
	var speed: float = guard.sentry_scan_rotation_speed if guard.sentry_scan_rotation_speed > 0.0 else scan_rotation_speed
	if speed > 0.0:
		_rotation_timer += delta
		var angle = _scan_direction + deg_to_rad(speed) * _rotation_timer
		guard.facing = Vector2.from_angle(angle)
		if guard.has_method("_update_animation"):
			guard._update_animation()
	
	# Check for target spotted (backup check)
	if guard.current_target:
		complete()

## Guard state: Stationary sentry that scans for targets.
## Transitions to ChaseState when target is spotted.
class_name StateGuardSentry
extends StateEntity

@export var scan_rotation_speed: float = 0.0 ## Degrees per second to rotate while scanning (0 = no rotation).
@export var transition_to_patrol: State ## Optional: transition to patrol state if set.

var _rotation_timer: float = 0.0
var _scan_direction: float = 0.0

func enter():
	super.enter()
	if entity and entity is GuardEntity:
		var guard = entity as GuardEntity
		guard.set_guard_speed("patrol")
		guard.stop()
		# Face home direction
		if guard.home_facing != Vector2.ZERO:
			guard.facing = guard.home_facing
		_rotation_timer = 0.0
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

func update(delta):
	super.update(delta)
	if not entity or not entity is GuardEntity:
		return
	
	var guard = entity as GuardEntity
	
	# Optional rotation scanning
	if scan_rotation_speed > 0.0:
		_rotation_timer += delta
		var angle = _scan_direction + deg_to_rad(scan_rotation_speed) * _rotation_timer
		guard.facing = Vector2.from_angle(angle)
	
	# Check for target spotted (backup check)
	if guard.current_target:
		complete()

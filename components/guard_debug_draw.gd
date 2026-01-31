## Debug drawing component for Guard entities.
## Draws FOV cone, LOS rays, and navigation path.
class_name GuardDebugDraw
extends Node2D

@export var enabled: bool = false ## Whether to draw debug visuals.
@export var draw_fov_cone: bool = true ## Draw the FOV cone polygon.
@export var draw_los_rays: bool = true ## Draw line-of-sight rays to targets.
@export var draw_nav_path: bool = true ## Draw navigation path.

@export var cone_color: Color = Color(1.0, 1.0, 0.0, 0.3) ## FOV cone fill color.
@export var cone_outline_color: Color = Color(1.0, 1.0, 0.0, 0.8) ## FOV cone outline color.
@export var los_clear_color: Color = Color(0.0, 1.0, 0.0, 0.5) ## LOS ray color when clear.
@export var los_blocked_color: Color = Color(1.0, 0.0, 0.0, 0.5) ## LOS ray color when blocked.
@export var nav_path_color: Color = Color(0.0, 0.5, 1.0, 0.8) ## Navigation path color.

var guard: GuardEntity
var perception: VisionConeSensor
var navigation_agent: NavigationAgent2D

func _ready():
	guard = get_parent() as GuardEntity
	if guard:
		perception = guard.get_node_or_null("Perception") as VisionConeSensor
		navigation_agent = guard.get_node_or_null("NavigationAgent2D") as NavigationAgent2D

func _draw():
	if not enabled or not guard:
		return
	
	# Draw FOV cone
	if draw_fov_cone and perception and perception.cone_profile:
		_draw_fov_cone()
	
	# Draw LOS rays
	if draw_los_rays and perception:
		_draw_los_rays()
	
	# Draw navigation path
	if draw_nav_path and navigation_agent:
		_draw_nav_path()

func _draw_fov_cone():
	if not perception.cone_profile:
		return
	
	var profile = perception.cone_profile
	var origin = perception.global_position - guard.global_position + profile.origin_offset
	var facing_angle = guard.facing.angle()
	var half_fov = deg_to_rad(profile.fov_degrees / 2.0)
	var range_dist = profile.range_px
	
	# Calculate cone points
	var points: PackedVector2Array = []
	points.append(origin)
	
	# Left edge
	var left_angle = facing_angle - half_fov
	points.append(origin + Vector2.from_angle(left_angle) * range_dist)
	
	# Right edge
	var right_angle = facing_angle + half_fov
	points.append(origin + Vector2.from_angle(right_angle) * range_dist)
	
	# Draw filled cone
	draw_colored_polygon(points, cone_color)
	
	# Draw outline
	draw_polyline(points, cone_outline_color, 2.0, true)

func _draw_los_rays():
	if not perception:
		return
	
	var visible_targets = perception.get_visible_targets()
	var origin = perception.global_position - guard.global_position
	if perception.cone_profile:
		origin += perception.cone_profile.origin_offset
	
	for target in visible_targets:
		if not is_instance_valid(target):
			continue
		
		var target_pos = target.global_position - guard.global_position
		var can_see = perception.can_see(target)
		var color = los_clear_color if can_see else los_blocked_color
		draw_line(origin, target_pos, color, 2.0)

func _draw_nav_path():
	if not navigation_agent or navigation_agent.is_navigation_finished():
		return
	
	var current_path = navigation_agent.get_current_navigation_path()
	if current_path.size() < 2:
		return
	
	# Convert to local coordinates
	var local_path: PackedVector2Array = []
	for point in current_path:
		local_path.append(point - guard.global_position)
	
	draw_polyline(local_path, nav_path_color, 3.0)

func _process(_delta):
	if enabled:
		queue_redraw()

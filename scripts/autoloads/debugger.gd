extends Node

var start_screen: NodePath = "res://scenes/menus/start_screen.tscn"

const GUARD_SCENE_PATH = "res://entities/enemies/guard.tscn"
var guard_scene: PackedScene = null

var night_vision_enabled: bool = false
var night_vision_overlay: CanvasLayer = null
var original_darkness_color: Color = Color(0.05, 0.05, 0.05, 1)  # Store original darkness color
var ambient_darkness_node: CanvasModulate = null  # Reference to the darkness node

var vision_cones_visible: bool = false ## Dev toggle for enemy vision cone visibility.

func _ready():
	# Always enable debugger for testing (comment out if you want debug-only)
	# if not OS.is_debug_build():
	# 	set_process_unhandled_key_input(false)
	# 	print("DEBUGGER DISABLED.")
	# 	return
	
	print("DEBUGGER ENABLED - Press G to spawn guard, N for night vision, C to toggle vision cones")
	
	# Preload guard scene
	guard_scene = load(GUARD_SCENE_PATH) as PackedScene
	if not guard_scene:
		push_error("Failed to load guard scene: %s" % GUARD_SCENE_PATH)
		print("ERROR: Failed to load guard scene from: %s" % GUARD_SCENE_PATH)
	else:
		print("DEBUG: Guard scene loaded successfully from: %s" % GUARD_SCENE_PATH)

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				DataManager.save_game()
			KEY_F2:
				var current_level = Globals.get_current_level()
				SceneManager.swap_scenes(start_screen, get_tree().root, current_level, Const.TRANSITION.FADE_TO_BLACK)
			KEY_CTRL:
				_set_player_ghost()
			KEY_TAB:
				_toggle_screen_view()
			KEY_0:
				_reset_player_velocity()
			KEY_3:
				_restore_player_health()
			KEY_5:
				_stop_all_enemies()
			KEY_G:
				print("DEBUG: G key pressed - spawning guard...")
				_spawn_guard_at_cursor()
			KEY_N:
				_toggle_night_vision()
			KEY_C:
				_toggle_vision_cones()

## Disables/enables players CollisionShape2D, allowing them to pass through anything.
func _set_player_ghost():
	for player in Globals.get_players():
		var coll: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
		if coll:
			coll.disabled = !coll.disabled

func _toggle_screen_view():
	for player: PlayerEntity in Globals.get_players():
		player.visible = !player.visible
		player.health_controller.hp_bar.visible = player.visible

## Fully restore players health.
func _restore_player_health():
	for player: PlayerEntity in Globals.get_players():
		player.health_controller.change_hp(player.health_controller.max_hp - player.health_controller.hp)

## Set players velocity to zero.
func _reset_player_velocity():
	for player in Globals.get_players():
		player.velocity = Vector2.ZERO

## Disables/enables the process of all enemies in the scene.
func _stop_all_enemies():
	var enemies = get_tree().get_nodes_in_group(Const.GROUP.ENEMY)
	for enemy in enemies:
		if enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED

## Spawns a guard at the mouse cursor position in world space.
func _spawn_guard_at_cursor():
	print("DEBUG: _spawn_guard_at_cursor called")
	
	if not guard_scene:
		print("ERROR: Guard scene not loaded from path: %s" % GUARD_SCENE_PATH)
		push_error("Guard scene not loaded")
		return
	
	print("DEBUG: Guard scene loaded successfully")
	
	# Get current level
	var current_level = Globals.get_current_level()
	if not current_level:
		print("ERROR: No current level found. Make sure you're in a level scene with GROUP.LEVEL")
		push_error("No current level found")
		return
	
	print("DEBUG: Current level found: %s" % current_level.name)
	
	# Get camera to convert screen to world coordinates
	var camera = get_viewport().get_camera_2d()
	if not camera:
		print("ERROR: No camera found in viewport")
		push_error("No camera found")
		return
	
	print("DEBUG: Camera found: %s" % camera.name)
	
	# Get mouse position in world space
	var mouse_screen_pos = get_viewport().get_mouse_position()
	var world_pos = camera.get_global_mouse_position()
	
	print("DEBUG: Mouse screen pos: %s, World pos: %s" % [mouse_screen_pos, world_pos])
	
	# Instantiate guard
	var guard = guard_scene.instantiate()
	if not guard:
		print("ERROR: Failed to instantiate guard")
		push_error("Failed to instantiate guard")
		return
	
	print("DEBUG: Guard instantiated: %s" % guard.name)
	
	guard.global_position = world_pos
	guard.name = "Guard_%d" % Time.get_ticks_msec()
	
	# Configure guard for patrol mode (randomly walk around)
	if guard.has_method("set_guard_speed"):
		guard.set_guard_speed("patrol")
		print("DEBUG: Set guard speed to patrol")
	else:
		print("WARNING: Guard doesn't have set_guard_speed method")
	
	# Set home position to spawn location
	# Check if property exists by checking if it's a GuardEntity
	if guard is GuardEntity:
		guard.home_position = world_pos
		print("DEBUG: Set home position to %s" % world_pos)
	else:
		print("WARNING: Guard is not a GuardEntity instance")
	
	# Set initial state to patrol if available (after adding to scene tree)
	# We need to wait for the guard to be added to the tree first
	call_deferred("_configure_guard_patrol", guard)
	
	# Add to level scene
	current_level.add_child(guard)
	print("DEBUG: Guard added to level scene")
	
	print("SUCCESS: Spawned guard '%s' at world position: %s (patrol mode)" % [guard.name, world_pos])

func _configure_guard_patrol(guard: Node):
	# Configure guard to start in patrol mode
	await get_tree().process_frame  # Wait for guard to be fully initialized
	var guard_states = guard.get_node_or_null("GuardStates")
	if guard_states and guard_states is StateMachine:
		var patrol_state = guard_states.get_node_or_null("patrol")
		if patrol_state:
			# Use enable_state to properly transition
			guard_states.enable_state(patrol_state)

## Toggles night vision mode (removes darkness and applies green tint overlay).
func _toggle_night_vision():
	night_vision_enabled = not night_vision_enabled
	
	if night_vision_enabled:
		_enable_night_vision()
	else:
		_disable_night_vision()

func _enable_night_vision():
	if night_vision_overlay:
		return  # Already enabled
	
	# Find and brighten the AmbientDarkness node to remove darkness
	var current_level = Globals.get_current_level()
	if current_level:
		ambient_darkness_node = current_level.get_node_or_null("AmbientDarkness") as CanvasModulate
		if ambient_darkness_node:
			# Store original darkness color
			original_darkness_color = ambient_darkness_node.color
			# Set to white to remove all darkness
			ambient_darkness_node.color = Color.WHITE
	
	# Create overlay layer
	night_vision_overlay = CanvasLayer.new()
	night_vision_overlay.name = "NightVisionOverlay"
	
	# Add ColorRect overlay for green tint effect
	var color_rect = ColorRect.new()
	color_rect.name = "GreenTint"
	color_rect.color = Color(0.1, 0.6, 0.1, 0.3)  # Green tint with transparency
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_vision_overlay.add_child(color_rect)
	
	# Add to root so it affects everything
	get_tree().root.add_child(night_vision_overlay)
	
	print("Night vision enabled")

func _disable_night_vision():
	if night_vision_overlay:
		night_vision_overlay.queue_free()
		night_vision_overlay = null
	
	# Restore original darkness
	if ambient_darkness_node:
		ambient_darkness_node.color = original_darkness_color
		ambient_darkness_node = null
	
	print("Night vision disabled")

## Toggles visibility of enemy vision cones (semi-transparent red).
func _toggle_vision_cones():
	vision_cones_visible = not vision_cones_visible
	print("Vision cones %s" % ("visible" if vision_cones_visible else "hidden"))

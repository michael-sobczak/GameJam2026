@tool
extends Node2D
class_name Level

@export_tool_button("Clear Tilemap Layers", "Callable") var clear_action = clear_tilemap_layers

@onready var tilemap_layers: Node2D = %Layers
@onready var darkness: CanvasModulate = %AmbientDarkness
@onready var level_complete_overlay: CanvasLayer = get_node_or_null("LevelCompleteOverlay")
@onready var defeat_overlay: CanvasLayer = get_node_or_null("DefeatOverlay")

var destination_name: String ## Used when moving between levels to get the right destination position for the player in the loaded level.
var player_id: int ## Used when moving between levels to save the player facing direction.

## Path to the scene to load when the goal is reached. Set per-level in the inspector (e.g. level1 → level2).
@export_file("*.tscn") var next_level := ""

## Mask types the player can have on this level. Empty = all masks. Use "night_vision" and/or "disguise". E.g. level 3 = ["night_vision"] only.
@export var allowed_mask_types: Array[String] = []

## Starting usages per allowed mask when inventory is initialized.
@export var usages_per_mask: int = 3  # default

@export var darkness_modulation: Color = Color(0.05, 0.05, 0.05, 1.0)

## Camera zoom at level start. Use 4 for first level, 2.5 after completing a level.
@export var initial_camera_zoom: float = 4.0

## Intro text settings
@export_group("Intro Text")
@export var show_intro_text: bool = false ## Show intro text when level starts
@export var intro_message: String = "FIND THE TREASURE\nDON'T GET CAUGHT"
@export var intro_fade_duration: float = 5.0

var _intro_text: LevelIntroText

const SIREN_STREAM: AudioStream = preload("res://DownloadedAssets/Siren-Sound.mp3")
const IMPACT_PARTICLES_SCENE: PackedScene = preload("res://vfx/scenes/ImpactParticles.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/menus/pause_menu.tscn")
const GUARD_SCENE: PackedScene = preload("res://entities/enemies/guard.tscn")
const GOAL_PARTICLE_WAIT_AFTER_BURST: float = 0.6
const DEFEAT_GUARD_COUNT: int = 4 ## Number of guards to spawn around player when caught.
const DEFEAT_GUARD_RADIUS: float = 80.0 ## Distance from player where guards spawn.
var _defeat_siren_player: AudioStreamPlayer = null
var _defeat_siren_play_count: int = 0
var _defeat_siren_stopping: bool = false

func _ready():
	if not Engine.is_editor_hint():
		darkness.color = darkness_modulation

	# Ensure NavigationRegion2D exists for guard pathfinding
	var nav_region: NavigationRegion2D = get_node_or_null("NavigationRegion2D")
	if not nav_region:
		nav_region = NavigationRegion2D.new()
		nav_region.name = "NavigationRegion2D"
		add_child(nav_region)
		move_child(nav_region, 0)  # Move to top of scene tree

	# Set up navigation polygon: only auto-generate the rectangle if none is set (so you can use a custom shape in the editor).
	await get_tree().process_frame
	if not nav_region.navigation_polygon or nav_region.navigation_polygon.get_outline_count() == 0:
		_setup_navigation_polygons(nav_region)
	else:
		nav_region.bake_navigation_polygon()

	# Connect all guards' target_spotted so we can trigger defeat
	_connect_guards()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var open_pause := Input.is_action_just_pressed(&"pause") or Input.is_action_just_pressed(&"ui_cancel")
	if not open_pause:
		return
	if _defeated:
		return
	if level_complete_overlay and level_complete_overlay.visible:
		return
	# Only open pause if no menus are open
	if get_tree().get_first_node_in_group(PauseMenu.PAUSE_MENU_GROUP):
		return
	if Globals.settings_menu != null:
		return
	var menu: PauseMenu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	get_tree().root.add_child(menu)

func init_scene():
	DataManager.load_level_data()


## Called by SceneManager after level is fully loaded and transition complete
func start_scene() -> void:
	var cam: Camera2D = get_node_or_null("GameCamera2D") as Camera2D
	if cam:
		cam.zoom = Vector2(initial_camera_zoom, initial_camera_zoom)
	if darkness:
		darkness.color = darkness_modulation
	if show_intro_text:
		_show_intro_text()

##internal - Used by SceneManager to pass data between levels.
func get_data():
	var data = {}
	if destination_name:
		data.destination_name = destination_name
	if player_id:
		data.player_id = player_id
	return data

##internal - Used by SceneManager to get data from the outgoing level.
func receive_data(data: Dictionary) -> void:
	var next_dest: Variant = data.get("destination_name")
	if next_dest:
		destination_name = next_dest
	var next_player_id: Variant = data.get("player_id")
	if next_player_id != null:
		player_id = next_player_id

## Sets up navigation polygons for NavigationRegion2D based on tilemap layers.
## Creates navigation polygons for all walkable tiles (non-wall tiles).
func _setup_navigation_polygons(nav_region: NavigationRegion2D):
	if not nav_region:
		return

	# Wait for tilemaps to fully initialize
	await get_tree().process_frame

	# Get all tilemap layers
	var tilemap_layers_list: Array[TileMapLayer] = []
	for child in tilemap_layers.get_children():
		if child is TileMapLayer:
			tilemap_layers_list.append(child)

	if tilemap_layers_list.is_empty():
		print("Level: No tilemap layers found for navigation setup")
		return

	# Find terrain layer (walkable floor)
	var terrain_layer: TileMapLayer = null
	for layer in tilemap_layers_list:
		if layer.name == "terrain" or layer.name == "terrain2":
			terrain_layer = layer
			break

	if not terrain_layer:
		print("Level: No terrain layer found, using first tilemap layer")
		terrain_layer = tilemap_layers_list[0]

	# Get tile size
	var tile_size = 32
	var tileset = terrain_layer.tile_set
	if tileset:
		tile_size = tileset.tile_size.x

	# Get used cells from terrain layer
	var used_cells = terrain_layer.get_used_cells()
	if used_cells.is_empty():
		print("Level: No tiles found in terrain layer")
		return

	# Find bounds
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for cell_pos in used_cells:
		var cell_v2i = cell_pos as Vector2i
		min_x = min(min_x, cell_v2i.x)
		max_x = max(max_x, cell_v2i.x)
		min_y = min(min_y, cell_v2i.y)
		max_y = max(max_y, cell_v2i.y)

	# Create a simple navigation polygon covering all walkable tiles
	# This creates one large rectangle - for more precise navigation, you'd want
	# to exclude wall tiles, but this will work for basic pathfinding
	var nav_polygon = NavigationPolygon.new()
	var outline = PackedVector2Array([
		Vector2(min_x * tile_size, min_y * tile_size),
		Vector2((max_x + 1) * tile_size, min_y * tile_size),
		Vector2((max_x + 1) * tile_size, (max_y + 1) * tile_size),
		Vector2(min_x * tile_size, (max_y + 1) * tile_size)
	])

	nav_polygon.add_outline(outline)
	nav_region.navigation_polygon = nav_polygon
	nav_region.bake_navigation_polygon()

	print("Level: Created navigation mesh covering %d tiles (bounds: %s to %s)" % [used_cells.size(), Vector2i(min_x, min_y), Vector2i(max_x, max_y)])

func clear_tilemap_layers():
	for node in tilemap_layers.get_children():
		if node is TileMapLayer:
			node.clear()


func end_level() -> void:
	print("reached end of level")
	if next_level.is_empty():
		return
	SceneManager.swap_scenes(next_level, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)


const GOAL_ZOOM_TARGET: float = 1.7
const GOAL_ZOOM_DURATION: float = 0.8

func _on_goal_reached(art_global_pos: Vector2 = Vector2.ZERO) -> void:
	# 0) Play pickup sound, stop player and guards
	AudioManager.play_sfx("treasure_pickup")
	_stop_player_and_guards()
	# 1) Restore light to the whole map
	if darkness:
		darkness.color = Color.WHITE
	# 2) Brief particle burst at the art
	var particles: ImpactParticles = IMPACT_PARTICLES_SCENE.instantiate() as ImpactParticles
	add_child(particles)
	particles.global_position = art_global_pos
	particles.emit_burst()
	await particles.burst_finished
	await get_tree().create_timer(GOAL_PARTICLE_WAIT_AFTER_BURST).timeout
	particles.queue_free()
	# 3) Zoom out from nominal zoom to a wider view
	var cam: Camera2D = get_node_or_null("GameCamera2D") as Camera2D
	if cam:
		var tween := create_tween()
		tween.tween_property(cam, "zoom", Vector2(GOAL_ZOOM_TARGET, GOAL_ZOOM_TARGET), GOAL_ZOOM_DURATION)
		await tween.finished
	await get_tree().create_timer(1.0).timeout
	# 4) Then go to next level
	if level_complete_overlay:
		level_complete_overlay.visible = true
		await get_tree().create_timer(1.0).timeout
	end_level()

var _defeated := false

## Stop player movement and disable guard state machines so they stop walking (e.g. on win).
func _stop_player_and_guards() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerEntity:
			var player: PlayerEntity = node as PlayerEntity
			player.input_enabled = false
			player.stop()
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	for child in entities.get_children():
		if child is GuardEntity:
			var guard: GuardEntity = child as GuardEntity
			guard.stop()
			var sm: StateMachine = guard.get_node_or_null("GuardStates") as StateMachine
			if sm:
				sm.disabled = true

func _connect_guards() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	for child in entities.get_children():
		if child is GuardEntity:
			(child as GuardEntity).target_spotted.connect(_on_guard_spotted_player)

func _on_guard_spotted_player(_target: Node2D) -> void:
	if _defeated:
		return
	_defeated = true

	# Disable player input and movement
	var player_pos := Vector2.ZERO
	var players = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is PlayerEntity:
			var player: PlayerEntity = node as PlayerEntity
			player.input_enabled = false
			player.stop()
			player_pos = player.global_position

	# Spawn cosmetic guards surrounding the player
	_spawn_defeat_guards(player_pos)

	# Turn lights on!
	if darkness:
		darkness.color = Color.WHITE

	# Show defeat overlay
	if defeat_overlay:
		defeat_overlay.visible = true
		var try_again_btn: Button = defeat_overlay.get_node_or_null("CenterContainer/VBoxContainer/TryAgain")
		if try_again_btn:
			try_again_btn.grab_focus()

	# End night vision / disguise immediately so the effect doesn't linger
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerEntity:
			var mem: MaskEffectManager = (node as PlayerEntity).get_node_or_null("MaskEffectManager") as MaskEffectManager
			if mem:
				mem.clear_effects_for_defeat()

	# Siren loops up to 4 times; stopped when Try Again or level exits
	_start_defeat_siren()


## Spawn cosmetic guards in a circle around the player when caught.
func _spawn_defeat_guards(player_pos: Vector2) -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		entities = self  # Fallback to level root

	for i in range(DEFEAT_GUARD_COUNT):
		# Calculate position in a circle around player
		var angle := (TAU / DEFEAT_GUARD_COUNT) * i
		var offset := Vector2(cos(angle), sin(angle)) * DEFEAT_GUARD_RADIUS
		var spawn_pos := player_pos + offset

		# Instantiate guard
		var guard: GuardEntity = GUARD_SCENE.instantiate() as GuardEntity
		guard.global_position = spawn_pos

		# Disable AI - just a cosmetic guard
		var sm: StateMachine = guard.get_node_or_null("GuardStates") as StateMachine
		if sm:
			sm.disabled = true

		# Face toward the player initially
		var dir_to_player := (player_pos - spawn_pos).normalized()
		guard.facing = dir_to_player

		# Add to scene
		entities.add_child(guard)

		# Stop movement immediately after adding to tree
		guard.stop()

		# Show alert indicator (exclamation mark) - keep it visible indefinitely
		var alert: AlertIndicator = guard.get_node_or_null("AlertIndicator") as AlertIndicator
		if alert:
			alert.show_duration = 0.0  # Don't auto-hide
			alert.show_indicator()

		# Start spinning animation - each guard spins at a slightly different speed
		var spin_speed := 2.0 + randf() * 1.0  # 2-3 rotations per second
		var spin_direction := 1.0 if i % 2 == 0 else -1.0  # Alternate spin directions
		_start_guard_spin(guard, spin_speed * spin_direction)


## Start a continuous spinning animation for a cosmetic guard.
func _start_guard_spin(guard: GuardEntity, rotations_per_second: float) -> void:
	var spin_tween := create_tween()
	spin_tween.set_loops()  # Infinite loop

	# Rotate through 4 directions over time
	var directions := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
	if rotations_per_second < 0:
		directions.reverse()
		rotations_per_second = abs(rotations_per_second)

	var time_per_direction := 1.0 / (rotations_per_second * 4.0)

	for dir in directions:
		spin_tween.tween_callback(func(): guard.facing = dir)
		spin_tween.tween_interval(time_per_direction)

func _on_defeat_try_again_pressed() -> void:
	_stop_defeat_siren()
	SceneManager.swap_scenes("res://scenes/menus/community_service_screen.tscn", get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)


func _show_intro_text() -> void:
	# Create intro text overlay
	_intro_text = LevelIntroText.new()
	_intro_text.intro_text = intro_message
	_intro_text.fade_duration = intro_fade_duration
	_intro_text.font_size = 48
	add_child(_intro_text)

	# Show intro (player can move immediately)
	_intro_text.show_intro()
	_intro_text.intro_finished.connect(_on_intro_finished)


func _on_intro_finished() -> void:
	# Clean up intro text
	if _intro_text:
		_intro_text.queue_free()
		_intro_text = null


func _start_defeat_siren() -> void:
	if _defeat_siren_player == null:
		_defeat_siren_player = AudioStreamPlayer.new()
		_defeat_siren_player.name = "DefeatSiren"
		_defeat_siren_player.bus = &"SFX"
		add_child(_defeat_siren_player)
		_defeat_siren_player.finished.connect(_on_defeat_siren_finished)
	_defeat_siren_stopping = false
	_defeat_siren_play_count = 1
	_defeat_siren_player.stream = SIREN_STREAM
	_defeat_siren_player.play()


func _on_defeat_siren_finished() -> void:
	if _defeat_siren_stopping or not _defeat_siren_player:
		return
	if _defeat_siren_play_count < 4:
		_defeat_siren_play_count += 1
		_defeat_siren_player.play()
	else:
		_stop_defeat_siren()


func _stop_defeat_siren() -> void:
	_defeat_siren_stopping = true
	if _defeat_siren_player:
		_defeat_siren_player.stop()


func _exit_tree() -> void:
	_stop_defeat_siren()

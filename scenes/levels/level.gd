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

@export var darkness_modulation: Color = Color(0.05, 0.05, 0.05, 1.0)

## Intro text settings
@export_group("Intro Text")
@export var show_intro_text: bool = false ## Show intro text when level starts
@export var intro_message: String = "FIND THE TREASURE\nDON'T GET CAUGHT"
@export var intro_fade_duration: float = 5.0

var _intro_text: LevelIntroText

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

	# Wait for tilemaps to be ready, then set up navigation polygons
	await get_tree().process_frame
	_setup_navigation_polygons(nav_region)

	# Connect all guards' target_spotted so we can trigger defeat
	_connect_guards()

	# Connect Try Again button in code so it works when defeat overlay is shown
	if defeat_overlay:
		var try_again_btn: Button = defeat_overlay.get_node_or_null("CenterContainer/VBoxContainer/TryAgain")
		if try_again_btn:
			try_again_btn.pressed.connect(_on_defeat_try_again_pressed)

func init_scene():
	DataManager.load_level_data()


## Called by SceneManager after level is fully loaded and transition complete
func start_scene() -> void:
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


func _on_goal_reached() -> void:
	if level_complete_overlay:
		level_complete_overlay.visible = true
		await get_tree().create_timer(1.0).timeout
	end_level()

var _defeated := false

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
	var players = get_tree().get_nodes_in_group("player")
	for node in players:
		if node is PlayerEntity:
			var player: PlayerEntity = node as PlayerEntity
			player.input_enabled = false
			player.stop()

	# Show defeat overlay (level and guard keep running in background)
	if defeat_overlay:
		defeat_overlay.visible = true
		var try_again_btn: Button = defeat_overlay.get_node_or_null("CenterContainer/VBoxContainer/TryAgain")
		if try_again_btn:
			try_again_btn.grab_focus()

func _on_defeat_try_again_pressed() -> void:
	var current_scene := get_tree().current_scene
	var scene_path := current_scene.scene_file_path if current_scene else ""
	if scene_path.is_empty():
		scene_path = "res://scenes/menus/start_screen.tscn"
	SceneManager.swap_scenes(scene_path, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)


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

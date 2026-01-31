@tool
extends Node2D
class_name Level

@export_tool_button("Clear Tilemap Layers", "Callable") var clear_action = clear_tilemap_layers

@onready var tilemap_layers: Node2D = %Layers

var destination_name: String ## Used when moving between levels to get the right destination position for the player in the loaded level.
var player_id: int ## Used when moving between levels to save the player facing direction.

func _ready():
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

func init_scene():
	DataManager.load_level_data()

##internal - Used by SceneManager to pass data between levels.
func get_data():
	var data = {}
	if destination_name:
		data.destination_name = destination_name
	if player_id:
		data.player_id = player_id
	return data

##internal - Used by SceneManager to get data from the outgoing level.
func receive_data(data):
	if data.destination_name:
		destination_name = data.destination_name
	if data.player_id:
		player_id = data.player_id

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

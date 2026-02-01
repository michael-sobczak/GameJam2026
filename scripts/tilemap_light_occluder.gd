## Generates LightOccluder2D polygons from a TileMapLayer.
## Attach this script to any TileMapLayer that should block light.
## Occluders are generated from tiles that have physics shapes defined.
class_name TileMapLightOccluder
extends TileMapLayer

## The light mask for the generated occluders (matches PointLight2D shadow_item_cull_mask).
@export var occluder_light_mask: int = 1

var _occluder_container: Node2D

func _ready() -> void:
	# Create container for occluder nodes
	_occluder_container = Node2D.new()
	_occluder_container.name = "LightOccluders"
	add_child(_occluder_container)
	
	# Generate occluders from tile data
	_generate_occluders()
	
	# Regenerate if tilemap changes (e.g., during editing or dynamic levels)
	changed.connect(_on_tilemap_changed)


func _generate_occluders() -> void:
	# Clear existing occluders
	for child in _occluder_container.get_children():
		child.queue_free()
	
	var ts: TileSet = tile_set
	if not ts:
		return
	
	# Get all used cells
	var used_cells := get_used_cells()
	var tile_size := ts.tile_size
	
	for cell_pos in used_cells:
		var tile_data := get_cell_tile_data(cell_pos)
		if not tile_data:
			continue
		
		# Check if tile has physics polygon (we use physics shapes to define occluders)
		var physics_count := tile_data.get_collision_polygons_count(0)
		if physics_count == 0:
			continue
		
		# Create occluder for each physics polygon
		for poly_idx in range(physics_count):
			var polygon := tile_data.get_collision_polygon_points(0, poly_idx)
			if polygon.size() < 3:
				continue
			
			# Create the occluder polygon resource
			var occluder_polygon := OccluderPolygon2D.new()
			occluder_polygon.polygon = polygon
			
			# Create the LightOccluder2D node
			var occluder := LightOccluder2D.new()
			occluder.occluder = occluder_polygon
			occluder.occluder_light_mask = occluder_light_mask
			
			# Position at the cell's world position
			occluder.position = map_to_local(cell_pos)
			
			_occluder_container.add_child(occluder)


func _on_tilemap_changed() -> void:
	# Debounce regeneration to avoid excessive calls
	if not is_inside_tree():
		return
	call_deferred("_generate_occluders")

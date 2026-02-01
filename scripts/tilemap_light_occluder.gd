## Generates LightOccluder2D polygons from a TileMapLayer.
## Attach this script to any TileMapLayer that should block light.
## Occluders are generated from tiles that have physics shapes defined.
class_name TileMapLightOccluder
extends TileMapLayer

## The light mask for the generated occluders (matches PointLight2D shadow_item_cull_mask).
@export var occluder_light_mask: int = 1
## How many pixels to shrink occluders inward from ALL edges. Creates a small central
## occluder that blocks light from passing through while allowing walls to be illuminated.
## Higher values = more wall surface illuminated. For 32px tiles, 12-14 works well.
@export_range(0.0, 15.0, 0.5) var occluder_inset: float = 12.0

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

	# Get all used cells that have physics (wall tiles)
	var wall_cells: Array[Vector2i] = []
	for cell_pos in get_used_cells():
		var tile_data := get_cell_tile_data(cell_pos)
		if tile_data and tile_data.get_collision_polygons_count(0) > 0:
			wall_cells.append(cell_pos)

	if wall_cells.is_empty():
		return

	# Group wall cells into connected regions
	var regions := _find_connected_regions(wall_cells)
	var tile_size := ts.tile_size

	# Create one merged occluder per region
	for region in regions:
		var merged_polygon := _create_region_boundary(region, tile_size)
		if merged_polygon.size() < 3:
			continue

		# Shrink the merged polygon inward
		var shrunk_polygon := _shrink_polygon_uniform(merged_polygon, occluder_inset)
		if shrunk_polygon.size() < 3:
			continue

		# Create the occluder polygon resource
		var occluder_polygon := OccluderPolygon2D.new()
		occluder_polygon.polygon = shrunk_polygon

		# Create the LightOccluder2D node
		var occluder := LightOccluder2D.new()
		occluder.occluder = occluder_polygon
		occluder.occluder_light_mask = occluder_light_mask

		_occluder_container.add_child(occluder)


func _on_tilemap_changed() -> void:
	# Debounce regeneration to avoid excessive calls
	if not is_inside_tree():
		return
	call_deferred("_generate_occluders")


## Find connected regions of wall cells using flood fill.
func _find_connected_regions(cells: Array[Vector2i]) -> Array[Array]:
	var cell_set := {}
	for cell in cells:
		cell_set[cell] = true

	var visited := {}
	var regions: Array[Array] = []

	for cell in cells:
		if visited.has(cell):
			continue

		# Flood fill to find connected region
		var region: Array[Vector2i] = []
		var queue: Array[Vector2i] = [cell]

		while not queue.is_empty():
			var current := queue.pop_front()
			if visited.has(current):
				continue
			if not cell_set.has(current):
				continue

			visited[current] = true
			region.append(current)

			# Check 4-connected neighbors
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor := current + offset
				if cell_set.has(neighbor) and not visited.has(neighbor):
					queue.append(neighbor)

		if not region.is_empty():
			regions.append(region)

	return regions


## Create a boundary polygon for a connected region of cells.
## Uses marching squares-like approach to trace the outer boundary.
func _create_region_boundary(region: Array[Vector2i], tile_size: Vector2i) -> PackedVector2Array:
	if region.is_empty():
		return PackedVector2Array()

	var half_w := tile_size.x / 2.0
	var half_h := tile_size.y / 2.0

	# Build a set for fast lookup
	var region_set := {}
	for cell in region:
		region_set[cell] = true

	# Collect all boundary edges (edges between wall and non-wall)
	var edges: Array[Array] = []  # Each edge is [start_point, end_point]

	for cell in region:
		var world_pos := map_to_local(cell)

		# Check each of the 4 edges
		# Top edge
		if not region_set.has(cell + Vector2i(0, -1)):
			edges.append([
				Vector2(world_pos.x - half_w, world_pos.y - half_h),
				Vector2(world_pos.x + half_w, world_pos.y - half_h)
			])
		# Bottom edge
		if not region_set.has(cell + Vector2i(0, 1)):
			edges.append([
				Vector2(world_pos.x + half_w, world_pos.y + half_h),
				Vector2(world_pos.x - half_w, world_pos.y + half_h)
			])
		# Left edge
		if not region_set.has(cell + Vector2i(-1, 0)):
			edges.append([
				Vector2(world_pos.x - half_w, world_pos.y + half_h),
				Vector2(world_pos.x - half_w, world_pos.y - half_h)
			])
		# Right edge
		if not region_set.has(cell + Vector2i(1, 0)):
			edges.append([
				Vector2(world_pos.x + half_w, world_pos.y - half_h),
				Vector2(world_pos.x + half_w, world_pos.y + half_h)
			])

	if edges.is_empty():
		return PackedVector2Array()

	# Chain edges into a polygon by matching endpoints
	return _chain_edges_to_polygon(edges)


## Chain boundary edges into a closed polygon.
func _chain_edges_to_polygon(edges: Array[Array]) -> PackedVector2Array:
	if edges.is_empty():
		return PackedVector2Array()

	# Build a map from start points to edges
	var edge_map := {}
	for edge in edges:
		var start: Vector2 = edge[0]
		var key := _point_key(start)
		if not edge_map.has(key):
			edge_map[key] = []
		edge_map[key].append(edge)

	# Start from first edge and chain
	var result := PackedVector2Array()
	var current_edge: Array = edges[0]
	var used := {}
	used[edges.find(current_edge)] = true

	result.append(current_edge[0])
	var current_end: Vector2 = current_edge[1]

	for _i in range(edges.size()):
		var key := _point_key(current_end)
		if not edge_map.has(key):
			break

		var found := false
		for edge in edge_map[key]:
			var idx := edges.find(edge)
			if used.has(idx):
				continue

			used[idx] = true
			result.append(edge[0])
			current_end = edge[1]
			found = true
			break

		if not found:
			break

	return result


## Create a string key for a point (for dictionary lookup).
func _point_key(point: Vector2) -> String:
	# Round to avoid floating point issues
	return "%d,%d" % [roundi(point.x), roundi(point.y)]


## Shrink all polygon edges uniformly inward toward the centroid.
## Creates a smaller central occluder that blocks light passage while allowing
## most of the wall surface to be illuminated.
func _shrink_polygon_uniform(polygon: PackedVector2Array, inset: float) -> PackedVector2Array:
	if inset <= 0.0 or polygon.size() < 3:
		return polygon

	# Calculate centroid
	var centroid := Vector2.ZERO
	for point in polygon:
		centroid += point
	centroid /= polygon.size()

	# Move each vertex toward the centroid by inset amount
	var result := PackedVector2Array()
	for point in polygon:
		var to_center := centroid - point
		var dist := to_center.length()
		if dist > inset:
			var new_point := point + to_center.normalized() * inset
			result.append(new_point)
		else:
			# Vertex is closer than inset, move to near-center (polygon may collapse)
			result.append(centroid)

	return result

## Utility class for generating simple icon textures programmatically.
class_name IconGenerator

## Creates a simple colored square icon.
static func create_square_icon(size: int, color: Color) -> AtlasTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	var texture = ImageTexture.create_from_image(image)
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, size, size)
	return atlas

## Creates a simple colored circle icon.
static func create_circle_icon(size: int, color: Color) -> AtlasTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0 - 2
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)
	
	var texture = ImageTexture.create_from_image(image)
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, size, size)
	return atlas

## Creates a simple mask-shaped icon (rounded rectangle with eye holes).
static func create_mask_icon(size: int, color: Color) -> AtlasTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw rounded rectangle mask shape
	var margin = 4
	var corner_radius = 6
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var in_bounds = (x >= margin and x < size - margin and 
			                y >= margin and y < size - margin)
			
			if in_bounds:
				# Check if in corner (rounded)
				var corner_dist = 0.0
				if x < margin + corner_radius and y < margin + corner_radius:
					corner_dist = pos.distance_to(Vector2(margin + corner_radius, margin + corner_radius))
				elif x >= size - margin - corner_radius and y < margin + corner_radius:
					corner_dist = pos.distance_to(Vector2(size - margin - corner_radius, margin + corner_radius))
				elif x < margin + corner_radius and y >= size - margin - corner_radius:
					corner_dist = pos.distance_to(Vector2(margin + corner_radius, size - margin - corner_radius))
				elif x >= size - margin - corner_radius and y >= size - margin - corner_radius:
					corner_dist = pos.distance_to(Vector2(size - margin - corner_radius, size - margin - corner_radius))
				
				if corner_dist == 0.0 or corner_dist <= corner_radius:
					image.set_pixel(x, y, color)
	
	# Add eye holes (two circles)
	var eye_y = size / 2.0
	var eye_radius = 3
	var left_eye_x = size / 3.0
	var right_eye_x = 2 * size / 3.0
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist_left = pos.distance_to(Vector2(left_eye_x, eye_y))
			var dist_right = pos.distance_to(Vector2(right_eye_x, eye_y))
			if dist_left <= eye_radius or dist_right <= eye_radius:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	var texture = ImageTexture.create_from_image(image)
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, size, size)
	return atlas

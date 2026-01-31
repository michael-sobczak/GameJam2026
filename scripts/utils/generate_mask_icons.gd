@tool
extends EditorScript

## Tool script to generate simple mask item icons.
## Run this script from Scripts > Run Script in the Godot editor.

func _run():
	print("Generating mask item icons...")
	
	# Generate Night Vision Mask icon (green circle)
	var night_vision_icon = _create_circle_icon(32, Color(0.0, 1.0, 0.4, 1.0))
	_save_texture(night_vision_icon, "res://items/night_vision_mask_icon.png")
	
	# Generate Disguise icon (purple rounded square)
	var disguise_icon = _create_rounded_square_icon(32, Color(0.6, 0.2, 0.8, 1.0))
	_save_texture(disguise_icon, "res://items/disguise_icon.png")
	
	print("Icons generated successfully!")

func _create_circle_icon(size: int, color: Color) -> Image:
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
	
	return image

func _create_rounded_square_icon(size: int, color: Color) -> Image:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var margin = 4
	var corner_radius = 6
	
	for y in range(size):
		for x in range(size):
			var in_bounds = (x >= margin and x < size - margin and 
			                y >= margin and y < size - margin)
			
			if in_bounds:
				# Check corners for rounded effect
				var in_corner = false
				var corner_pos = Vector2.ZERO
				
				if x < margin + corner_radius and y < margin + corner_radius:
					corner_pos = Vector2(margin + corner_radius, margin + corner_radius)
					in_corner = true
				elif x >= size - margin - corner_radius and y < margin + corner_radius:
					corner_pos = Vector2(size - margin - corner_radius, margin + corner_radius)
					in_corner = true
				elif x < margin + corner_radius and y >= size - margin - corner_radius:
					corner_pos = Vector2(margin + corner_radius, size - margin - corner_radius)
					in_corner = true
				elif x >= size - margin - corner_radius and y >= size - margin - corner_radius:
					corner_pos = Vector2(size - margin - corner_radius, size - margin - corner_radius)
					in_corner = true
				
				if not in_corner or Vector2(x, y).distance_to(corner_pos) <= corner_radius:
					image.set_pixel(x, y, color)
	
	return image

func _save_texture(image: Image, path: String):
	image.save_png(path)
	print("Saved: %s" % path)

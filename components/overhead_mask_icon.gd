## Overhead mask icon with ambient glow effect for visibility in dark areas.
extends TextureRect

var _glow_light: PointLight2D = null

func _ready() -> void:
	_create_glow_light()


## Create a PointLight2D that provides a faint ambient yellow glow.
func _create_glow_light() -> void:
	_glow_light = PointLight2D.new()
	_glow_light.name = "AmbientGlow"
	_glow_light.color = Color(1.0, 0.9, 0.4, 1.0)  # Warm yellow
	_glow_light.energy = 0.4  # Faint glow
	_glow_light.texture_scale = 0.5  # Keep glow localized to mask area
	_glow_light.blend_mode = Light2D.BLEND_MODE_ADD
	_glow_light.shadow_enabled = false
	_glow_light.range_layer_min = -1  # Only affect nearby layers
	_glow_light.range_layer_max = 1
	_glow_light.texture = _create_glow_texture()
	
	# Position at center of the TextureRect
	_glow_light.position = size / 2.0
	
	add_child(_glow_light)


## Create a radial gradient texture for the localized glow effect.
func _create_glow_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	
	for x in range(64):
		for y in range(64):
			var dist := Vector2(x, y).distance_to(center)
			# Sharp radial falloff - concentrated near center
			var alpha := clampf(1.0 - (dist / 32.0), 0.0, 1.0)
			alpha = pow(alpha, 5.0)  # Quintic falloff for very sharp edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	
	return ImageTexture.create_from_image(img)

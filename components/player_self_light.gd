## Small circular light (~50px radius) at player so they can see themselves in the dark.
class_name PlayerSelfLight
extends Node2D

const RADIUS_PX: int = 50

@export var energy: float = 1.2
@export var color: Color = Color(1.0, 0.98, 0.9, 1.0)

@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	if not light:
		return
	light.texture = _create_circle_texture()
	light.texture_scale = 1.0
	light.energy = energy
	light.color = color
	light.shadow_enabled = false

func _create_circle_texture() -> Texture2D:
	var size := RADIUS_PX * 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := size / 2.0
	var max_dist := float(RADIUS_PX)
	for y in size:
		for x in size:
			var dx := x - center
			var dy := y - center
			var dist := sqrt(dx * dx + dy * dy)
			if dist > max_dist:
				continue
			var t := dist / max_dist
			var alpha := 1.0 - pow(t, 1.2)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

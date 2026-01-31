## Component that provides a cone-shaped light source (flashlight).
## Uses PointLight2D with a cone texture to create directional lighting.
## Can be attached to any character to provide a rotating flashlight effect.
class_name FlashlightCone
extends Node2D

signal aim_changed(angle: float)

@export_group("Settings")
@export var enabled: bool = true ## Whether the flashlight is currently active.
@export var energy: float = 1.5 ## Light energy/intensity.
@export var color: Color = Color(1.0, 0.95, 0.8, 1.0) ## Light color (warm white default).
@export var local_offset: Vector2 = Vector2(0, -10) ## Offset from parent where light originates.

@export_group("Cone Profile")
@export var cone_profile: ConeProfile ## Shared cone parameters (range, FOV, etc).

@onready var light: PointLight2D = $PointLight2D

var _current_aim_angle: float = 0.0

func _ready():
	if not cone_profile:
		# Create default profile if none provided
		cone_profile = ConeProfile.new()
		cone_profile.range_px = 300.0
		cone_profile.fov_degrees = 60.0
	
	position = local_offset
	_setup_light()

func _setup_light():
	if not light:
		return
	
	light.enabled = enabled
	light.energy = energy
	light.color = color
	light.texture_scale = cone_profile.range_px / 100.0  # Scale based on range
	
	# Create or update cone texture
	_update_cone_texture()

func _update_cone_texture():
	if not light or not cone_profile:
		return
	
	# Create a simple cone texture if none exists
	if not light.texture:
		light.texture = _create_cone_texture()

func _create_cone_texture() -> Texture2D:
	# Create a simple cone/wedge texture programmatically
	# The texture will be square, with the cone pointing downward (top-down game convention)
	var size = int(cone_profile.range_px)
	if size < 64:
		size = 64  # Minimum size for quality
	
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center_x = size / 2.0
	var center_y = size / 2.0
	var half_fov_rad = deg_to_rad(cone_profile.fov_degrees / 2.0)
	var max_dist = size / 2.0
	
	# Draw cone shape pointing downward (toward positive Y in screen space)
	for y in range(size):
		for x in range(size):
			var dx = x - center_x
			var dy = y - center_y
			var dist = sqrt(dx * dx + dy * dy)
			
			if dist > max_dist:
				continue
			
			# Calculate angle from center (0 = right, PI/2 = down, -PI/2 = up)
			var angle = atan2(dy, dx)
			
			# Check if within FOV (cone points down, so center angle is PI/2)
			var center_angle = PI / 2.0  # Downward direction
			var angle_diff = abs(angle - center_angle)
			
			# Normalize angle difference to [0, PI]
			if angle_diff > PI:
				angle_diff = 2 * PI - angle_diff
			
			if angle_diff <= half_fov_rad:
				# Fade from center to edge with smooth falloff
				var normalized_dist = dist / max_dist
				var alpha = 1.0 - normalized_dist
				alpha = pow(alpha, 1.2)  # Smooth falloff curve
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	
	var texture = ImageTexture.create_from_image(image)
	return texture

## Set the aim direction using a Vector2 direction.
## @param direction: Normalized direction vector (e.g., from CharacterEntity.facing)
func set_aim_direction(direction: Vector2):
	if direction == Vector2.ZERO:
		return
	var angle = direction.angle()
	set_aim_angle(angle)

## Set the aim angle in radians.
## @param angle: Angle in radians (0 = right, PI/2 = down, -PI/2 = up)
func set_aim_angle(angle: float):
	_current_aim_angle = angle
	rotation = angle + (PI / 2.0)  # Adjust so 0 points down (top-down convention)
	aim_changed.emit(angle)

## Enable or disable the flashlight.
func set_enabled(value: bool):
	enabled = value
	if light:
		light.enabled = enabled

## Update cone profile and refresh visual.
func update_profile(new_profile: ConeProfile):
	cone_profile = new_profile
	if light:
		_setup_light()

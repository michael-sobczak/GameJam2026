class_name FallingMasks
extends Control

## Falling Masks Effect
## Spawns mask images that fall from top to bottom of screen continuously

const REMOVE_BG_SHADER := preload("res://vfx/shaders/remove_background.gdshader")

@export_group("Masks")
@export var mask_textures: Array[Texture2D] = []
@export var mask_count: int = 12 ## Number of masks on screen at once

@export_group("Movement")
@export var fall_speed_min: float = 50.0
@export var fall_speed_max: float = 150.0
@export var sway_amount: float = 30.0 ## Horizontal sway amplitude
@export var sway_speed: float = 2.0
@export var rotation_speed_max: float = 0.5 ## Max rotation speed in radians/sec

@export_group("Appearance")
@export var scale_min: float = 0.15
@export var scale_max: float = 0.35
@export var opacity_min: float = 0.3
@export var opacity_max: float = 0.6

@export_group("Background Removal")
@export var remove_background: bool = true ## Remove white background from JPEGs
@export var bg_threshold: float = 0.85 ## Brightness threshold for transparency
@export var bg_softness: float = 0.15 ## Soft edge for smoother cutout

# Internal
var _masks: Array[TextureRect] = []
var _mask_data: Array[Dictionary] = [] # Stores velocity, sway phase, etc.


func _ready() -> void:
	# Wait a frame to get correct size
	await get_tree().process_frame
	_spawn_initial_masks()


func _process(delta: float) -> void:
	var screen_height := size.y
	var screen_width := size.x
	
	for i in range(_masks.size()):
		var mask := _masks[i]
		var data := _mask_data[i]
		
		# Update position
		var fall_speed: float = data.fall_speed
		var sway_phase: float = data.sway_phase
		var rot_speed: float = data.rotation_speed
		
		# Vertical fall
		mask.position.y += fall_speed * delta
		
		# Horizontal sway
		sway_phase += sway_speed * delta
		data.sway_phase = sway_phase
		mask.position.x = data.base_x + sin(sway_phase) * sway_amount
		
		# Rotation
		mask.rotation += rot_speed * delta
		
		# Check if off screen (with margin for mask size)
		if mask.position.y > screen_height + 100:
			_respawn_mask(i, screen_width)


func _spawn_initial_masks() -> void:
	if mask_textures.is_empty():
		push_warning("FallingMasks: No mask textures assigned")
		return
	
	var screen_width := size.x
	var screen_height := size.y
	
	for i in range(mask_count):
		var mask := TextureRect.new()
		mask.texture = mask_textures[randi() % mask_textures.size()]
		mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Apply background removal shader
		if remove_background:
			var mat := ShaderMaterial.new()
			mat.shader = REMOVE_BG_SHADER
			mat.set_shader_parameter(&"threshold", bg_threshold)
			mat.set_shader_parameter(&"softness", bg_softness)
			mask.material = mat
		
		# Random scale
		var s := randf_range(scale_min, scale_max)
		mask.custom_minimum_size = Vector2(150, 150) * s
		mask.size = mask.custom_minimum_size
		
		# Random opacity
		mask.modulate.a = randf_range(opacity_min, opacity_max)
		
		# Random position (spread across screen height initially)
		var start_x := randf_range(0, screen_width)
		var start_y := randf_range(-screen_height, screen_height) # Spread vertically
		mask.position = Vector2(start_x - mask.size.x / 2, start_y)
		
		# Random rotation
		mask.rotation = randf_range(0, TAU)
		mask.pivot_offset = mask.size / 2
		
		# Store movement data
		var data := {
			"fall_speed": randf_range(fall_speed_min, fall_speed_max),
			"sway_phase": randf_range(0, TAU),
			"base_x": start_x - mask.size.x / 2,
			"rotation_speed": randf_range(-rotation_speed_max, rotation_speed_max)
		}
		
		add_child(mask)
		_masks.append(mask)
		_mask_data.append(data)


func _respawn_mask(index: int, screen_width: float) -> void:
	var mask := _masks[index]
	var data := _mask_data[index]
	
	# New random texture
	mask.texture = mask_textures[randi() % mask_textures.size()]
	
	# New random scale
	var s := randf_range(scale_min, scale_max)
	mask.custom_minimum_size = Vector2(150, 150) * s
	mask.size = mask.custom_minimum_size
	mask.pivot_offset = mask.size / 2
	
	# New random opacity
	mask.modulate.a = randf_range(opacity_min, opacity_max)
	
	# Reset to top with new random X
	var start_x := randf_range(0, screen_width)
	mask.position = Vector2(start_x - mask.size.x / 2, -mask.size.y - randf_range(0, 100))
	
	# New random rotation
	mask.rotation = randf_range(0, TAU)
	
	# New movement data
	data.fall_speed = randf_range(fall_speed_min, fall_speed_max)
	data.sway_phase = randf_range(0, TAU)
	data.base_x = start_x - mask.size.x / 2
	data.rotation_speed = randf_range(-rotation_speed_max, rotation_speed_max)

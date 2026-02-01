## Manages mask item effects (night vision, disguise, etc.)
class_name MaskEffectManager
extends Node

signal night_vision_started(duration: float)
signal night_vision_ended
signal disguise_started(duration: float)
signal disguise_ended

var night_vision_active: bool = false
var disguise_active: bool = false
var night_vision_overlay: CanvasLayer = null
var ambient_darkness_node: CanvasModulate = null
var original_darkness_color: Color = Color.BLACK
var active_mask_texture: Texture2D = null
var _night_vision_deactivate_sound: AudioStream = null
var _disguise_deactivate_sound: AudioStream = null

@onready var mask_sprite: Sprite2D = get_parent().get_node_or_null("MaskSprite")

## Apply night vision effect for specified duration.
func apply_night_vision(duration: float, mask_tex: Texture2D = null, activate_sfx: AudioStream = null, deactivate_sfx: AudioStream = null):
	if night_vision_active:
		return  # Already active
	
	night_vision_active = true
	night_vision_started.emit(duration)
	_night_vision_deactivate_sound = deactivate_sfx
	
	# Play custom sound if provided, otherwise fall back to default
	if activate_sfx:
		AudioManager.play_stream(activate_sfx)
	else:
		AudioManager.play_sfx("night_vision_on")
	
	# Show mask on player's head
	_show_mask_sprite(mask_tex)
	
	# Find and brighten the AmbientDarkness node
	var current_level = Globals.get_current_level()
	if current_level:
		ambient_darkness_node = current_level.get_node_or_null("AmbientDarkness") as CanvasModulate
		if ambient_darkness_node:
			original_darkness_color = ambient_darkness_node.color
			ambient_darkness_node.color = Color.WHITE
	
	# Create overlay layer with green tint
	night_vision_overlay = CanvasLayer.new()
	night_vision_overlay.name = "NightVisionOverlay"
	
	var canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "NightVisionModulate"
	canvas_modulate.color = Color(1.3, 1.4, 1.3, 1.0)  # Green tint + brightness boost
	night_vision_overlay.add_child(canvas_modulate)
	
	var color_rect = ColorRect.new()
	color_rect.name = "GreenTint"
	color_rect.color = Color(0.1, 0.6, 0.1, 0.3)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_vision_overlay.add_child(color_rect)
	
	get_tree().root.add_child(night_vision_overlay)
	
	# Wait for duration then remove
	await get_tree().create_timer(duration).timeout
	_remove_night_vision()

## Remove night vision effect.
func _remove_night_vision():
	if not night_vision_active:
		return
	
	night_vision_active = false
	night_vision_ended.emit()
	
	# Play custom deactivate sound if set, otherwise fall back to default
	if _night_vision_deactivate_sound:
		AudioManager.play_stream(_night_vision_deactivate_sound)
		_night_vision_deactivate_sound = null
	else:
		AudioManager.play_sfx("night_vision_off")
	
	if night_vision_overlay:
		night_vision_overlay.queue_free()
		night_vision_overlay = null
	
	if ambient_darkness_node:
		ambient_darkness_node.color = original_darkness_color
		ambient_darkness_node = null
	
	# Hide mask sprite
	_hide_mask_sprite()

## Apply disguise effect for specified duration.
func apply_disguise(duration: float, mask_tex: Texture2D = null, activate_sfx: AudioStream = null, deactivate_sfx: AudioStream = null):
	if disguise_active:
		return  # Already active
	
	disguise_active = true
	disguise_started.emit(duration)
	_disguise_deactivate_sound = deactivate_sfx
	
	# Play custom sound if provided, otherwise fall back to default
	if activate_sfx:
		AudioManager.play_stream(activate_sfx)
	else:
		AudioManager.play_sfx("disguise_on")
	
	# Show mask on player's head
	_show_mask_sprite(mask_tex)
	
	# Remove player from vision_target group so guards can't see them
	var players = Globals.get_players()
	for player in players:
		if player is PlayerEntity:
			player.remove_from_group(&"vision_target")
	
	# Wait for duration then remove
	await get_tree().create_timer(duration).timeout
	_remove_disguise()

## Remove disguise effect.
func _remove_disguise():
	if not disguise_active:
		return
	
	disguise_active = false
	disguise_ended.emit()
	
	# Play custom deactivate sound if set, otherwise fall back to default
	if _disguise_deactivate_sound:
		AudioManager.play_stream(_disguise_deactivate_sound)
		_disguise_deactivate_sound = null
	else:
		AudioManager.play_sfx("disguise_off")
	
	# Re-add player to vision_target group
	var players = Globals.get_players()
	for player in players:
		if player is PlayerEntity:
			player.add_to_group(&"vision_target")
	
	# Hide mask sprite
	_hide_mask_sprite()

## Show the mask sprite on the player's head.
func _show_mask_sprite(texture: Texture2D):
	if not mask_sprite:
		mask_sprite = get_parent().get_node_or_null("MaskSprite")
	
	if mask_sprite and texture:
		active_mask_texture = texture
		mask_sprite.texture = texture
		mask_sprite.visible = true

## Hide the mask sprite.
func _hide_mask_sprite():
	if mask_sprite:
		mask_sprite.visible = false
		mask_sprite.texture = null
	active_mask_texture = null
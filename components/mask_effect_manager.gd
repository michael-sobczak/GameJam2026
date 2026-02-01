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

## Remove night vision effect. Pass silent=true to skip sounds/signals (e.g. on level transition).
func _remove_night_vision(silent: bool = false) -> void:
	if not night_vision_active:
		return
	
	night_vision_active = false
	if not silent:
		night_vision_ended.emit()
		if _night_vision_deactivate_sound:
			AudioManager.play_stream(_night_vision_deactivate_sound)
		else:
			AudioManager.play_sfx("night_vision_off")
	_night_vision_deactivate_sound = null
	
	if night_vision_overlay:
		night_vision_overlay.queue_free()
		night_vision_overlay = null
	
	if is_instance_valid(ambient_darkness_node):
		# Don't restore darkness if lose screen is up (level already set lights on)
		var level: Node = ambient_darkness_node.get_parent()
		var defeat_overlay: CanvasLayer = level.get_node_or_null("DefeatOverlay") if level else null
		if not defeat_overlay or not defeat_overlay.visible:
			ambient_darkness_node.color = original_darkness_color
	ambient_darkness_node = null
	
	_hide_mask_sprite()

## Clear night vision and disguise immediately (e.g. when caught). Silent, no sounds/signals.
func clear_effects_for_defeat() -> void:
	_remove_night_vision(true)
	_remove_disguise(true)

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

## Remove disguise effect. Pass silent=true to skip sounds/signals (e.g. on level transition).
func _remove_disguise(silent: bool = false) -> void:
	if not disguise_active:
		return
	
	disguise_active = false
	if not silent:
		disguise_ended.emit()
		if _disguise_deactivate_sound:
			AudioManager.play_stream(_disguise_deactivate_sound)
		else:
			AudioManager.play_sfx("disguise_off")
	_disguise_deactivate_sound = null
	
	# Re-add player to vision_target group
	var players = Globals.get_players()
	for player in players:
		if is_instance_valid(player) and player is PlayerEntity:
			player.add_to_group(&"vision_target")
	
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

## Clean up root-level effects when this node is removed (e.g. level transition). Reuses removal logic without sounds/signals.
func _exit_tree() -> void:
	_remove_night_vision(true)
	_remove_disguise(true)
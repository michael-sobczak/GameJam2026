## Manages mask item effects (night vision, disguise, etc.)
class_name MaskEffectManager
extends Node

signal night_vision_started(duration: float)
signal night_vision_ended
signal disguise_started(duration: float)
signal disguise_ended
signal reflection_started(duration: float)
signal reflection_ended
signal active_mask_changed(texture: Texture2D, mask_name: String)

var night_vision_active: bool = false
var disguise_active: bool = false
var reflection_active: bool = false
var night_vision_overlay: CanvasLayer = null
var ambient_darkness_node: CanvasModulate = null
var original_darkness_color: Color = Color.BLACK
var active_mask_texture: Texture2D = null
var active_mask_name: String = ""
var _night_vision_deactivate_sound: AudioStream = null
var _disguise_deactivate_sound: AudioStream = null
var _reflection_deactivate_sound: AudioStream = null
var _reflection_overlay: CanvasLayer = null
var _reflection_glow: PointLight2D = null ## Glow effect when actively reflecting a laser.
var _glow_tween: Tween = null ## Tween for pulsing glow effect.

## True if night vision can be applied (not already active).
func can_apply_night_vision() -> bool:
	return not night_vision_active

## True if disguise can be applied (not already active).
func can_apply_disguise() -> bool:
	return not disguise_active

## True if reflection can be applied (not already active).
func can_apply_reflection() -> bool:
	return not reflection_active

## Apply night vision effect for specified duration.
func apply_night_vision(duration: float, mask_tex: Texture2D = null, activate_sfx: AudioStream = null, deactivate_sfx: AudioStream = null, mask_name: String = ""):
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

	# Show mask on player's head and notify HUD
	active_mask_name = mask_name
	_show_mask_sprite(mask_tex)
	active_mask_changed.emit(active_mask_texture, active_mask_name)

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

	_clear_active_mask_and_emit()

## Clear all mask effects immediately (e.g. when caught). Silent, no sounds/signals.
func clear_effects_for_defeat() -> void:
	_remove_night_vision(true)
	_remove_disguise(true)
	_remove_reflection(true)

## Apply disguise effect for specified duration.
func apply_disguise(duration: float, mask_tex: Texture2D = null, activate_sfx: AudioStream = null, deactivate_sfx: AudioStream = null, mask_name: String = ""):
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

	# Show mask on player's head and notify HUD
	active_mask_name = mask_name
	_show_mask_sprite(mask_tex)
	active_mask_changed.emit(active_mask_texture, active_mask_name)

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

	_clear_active_mask_and_emit()

## Apply reflection effect for specified duration. Reflects lasers that hit the player.
func apply_reflection(duration: float, mask_tex: Texture2D = null, activate_sfx: AudioStream = null, deactivate_sfx: AudioStream = null, mask_name: String = ""):
	if reflection_active:
		return  # Already active

	reflection_active = true
	reflection_started.emit(duration)
	_reflection_deactivate_sound = deactivate_sfx

	# Play custom sound if provided, otherwise fall back to default
	if activate_sfx:
		AudioManager.play_stream(activate_sfx)
	else:
		AudioManager.play_sfx("reflection_on")

	# Show mask on player's head and notify HUD
	active_mask_name = mask_name
	_show_mask_sprite(mask_tex)
	active_mask_changed.emit(active_mask_texture, active_mask_name)

	# Create overlay with reflective shimmer effect
	_reflection_overlay = CanvasLayer.new()
	_reflection_overlay.name = "ReflectionOverlay"

	var color_rect = ColorRect.new()
	color_rect.name = "ReflectiveTint"
	color_rect.color = Color(0.6, 0.8, 1.0, 0.15)  # Light blue shimmer
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reflection_overlay.add_child(color_rect)

	get_tree().root.add_child(_reflection_overlay)

	# Wait for duration then remove
	await get_tree().create_timer(duration).timeout
	_remove_reflection()

## Remove reflection effect. Pass silent=true to skip sounds/signals (e.g. on level transition).
func _remove_reflection(silent: bool = false) -> void:
	if not reflection_active:
		return

	reflection_active = false
	if not silent:
		reflection_ended.emit()
		if _reflection_deactivate_sound:
			AudioManager.play_stream(_reflection_deactivate_sound)
		else:
			AudioManager.play_sfx("reflection_off")
	_reflection_deactivate_sound = null

	if _reflection_overlay:
		_reflection_overlay.queue_free()
		_reflection_overlay = null

	# Also remove any active glow
	hide_reflection_glow()

	_clear_active_mask_and_emit()


## Show a glowing aura around the player when actively reflecting a laser.
## Call this when a laser is being reflected. Color should match the laser.
func show_reflection_glow(laser_color: Color) -> void:
	var parent := get_parent()
	if not parent:
		return

	# Create glow if not exists
	if not _reflection_glow:
		_reflection_glow = PointLight2D.new()
		_reflection_glow.name = "ReflectionGlow"
		_reflection_glow.blend_mode = Light2D.BLEND_MODE_ADD
		_reflection_glow.shadow_enabled = false
		_reflection_glow.texture_scale = 2.0
		_reflection_glow.energy = 0.8

		# Create a radial gradient texture for soft glow
		_reflection_glow.texture = _create_glow_texture()

		parent.add_child(_reflection_glow)

	# Update color to match laser
	_reflection_glow.color = laser_color
	_reflection_glow.visible = true

	# Start pulsing animation if not already running
	if not _glow_tween or not _glow_tween.is_valid():
		_start_glow_pulse()


## Hide the reflection glow aura.
func hide_reflection_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null

	if _reflection_glow:
		_reflection_glow.visible = false


## Create a radial gradient texture for the glow effect.
func _create_glow_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)

	for x in range(64):
		for y in range(64):
			var dist := Vector2(x, y).distance_to(center)
			# Soft radial falloff
			var alpha := clampf(1.0 - (dist / 32.0), 0.0, 1.0)
			alpha = alpha * alpha * alpha  # Cubic falloff for softer edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)


## Start pulsing animation for the glow.
func _start_glow_pulse() -> void:
	if not _reflection_glow:
		return

	_glow_tween = create_tween()
	_glow_tween.set_loops()  # Infinite loop
	_glow_tween.tween_property(_reflection_glow, "energy", 1.2, 0.3).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(_reflection_glow, "energy", 0.6, 0.3).set_ease(Tween.EASE_IN_OUT)

## Set active mask texture for HUD/floating icon; on-head sprite is no longer shown.
func _show_mask_sprite(texture: Texture2D):
	if texture:
		active_mask_texture = texture

## Clear active mask (no on-head sprite to hide).
func _hide_mask_sprite():
	active_mask_texture = null

func _clear_active_mask_and_emit() -> void:
	_hide_mask_sprite()
	active_mask_name = ""
	active_mask_changed.emit(null, "")

## Clean up root-level effects when this node is removed (e.g. level transition). Reuses removal logic without sounds/signals.
func _exit_tree() -> void:
	_remove_night_vision(true)
	_remove_disguise(true)
	_remove_reflection(true)
	hide_reflection_glow()
	if _reflection_glow:
		_reflection_glow.queue_free()
		_reflection_glow = null
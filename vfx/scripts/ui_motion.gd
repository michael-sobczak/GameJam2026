@tool
class_name UIMotion
extends Control

## Procedural UI Motion Script
## Adds hover wobble, idle breathing, and click punch effects
## Attach to any Control node (Button, Panel, etc.)

signal punch_started
signal punch_finished

@export_group("Idle Breathing")
@export var enable_breathing: bool = true
@export var breathing_scale_amount: float = 0.02
@export var breathing_speed: float = 2.0

@export_group("Hover Wobble")
@export var enable_hover_wobble: bool = true
@export var wobble_rotation_amount: float = 3.0 # Degrees
@export var wobble_offset_amount: float = 2.0 # Pixels
@export var wobble_speed: float = 8.0

@export_group("Click Punch")
@export var enable_click_punch: bool = true
@export var punch_scale: float = 0.9
@export var punch_duration: float = 0.15
@export var punch_curve: Curve

@export_group("Settings")
@export var use_noise: bool = false # Use noise instead of sine
@export var randomize_phase: bool = true

var _base_position: Vector2
var _base_rotation: float
var _base_scale: Vector2
var _is_hovered: bool = false
var _phase_offset: float = 0.0
var _punch_tween: Tween
var _is_punching: bool = false
var _time: float = 0.0


func _ready() -> void:
	# Store initial transform
	_base_position = position
	_base_rotation = rotation
	_base_scale = scale
	
	# Random phase offset
	if randomize_phase:
		_phase_offset = randf() * TAU
	
	# Connect signals for mouse interaction
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect to gui_input for click detection
	gui_input.connect(_on_gui_input)
	
	# Create default punch curve if not set
	if punch_curve == null:
		punch_curve = Curve.new()
		punch_curve.add_point(Vector2(0.0, 1.0))
		punch_curve.add_point(Vector2(0.3, 0.0))
		punch_curve.add_point(Vector2(0.6, 0.3))
		punch_curve.add_point(Vector2(1.0, 1.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not enable_breathing:
		return
	
	_time += delta
	
	if _is_punching:
		return # Let tween handle transform during punch
	
	var target_scale := _base_scale
	var target_rotation := _base_rotation
	var target_position := _base_position
	
	# Idle breathing
	if enable_breathing:
		var breath := _get_wave(_time * breathing_speed + _phase_offset)
		var breath_scale := 1.0 + breath * breathing_scale_amount
		target_scale = _base_scale * breath_scale
	
	# Hover wobble
	if enable_hover_wobble and _is_hovered:
		var wobble_t := _time * wobble_speed + _phase_offset
		
		# Rotation wobble
		var rot_wobble := _get_wave(wobble_t) * deg_to_rad(wobble_rotation_amount)
		target_rotation = _base_rotation + rot_wobble
		
		# Position wobble (offset)
		var pos_wobble_x := _get_wave(wobble_t * 1.3) * wobble_offset_amount
		var pos_wobble_y := _get_wave(wobble_t * 0.7 + 1.0) * wobble_offset_amount
		target_position = _base_position + Vector2(pos_wobble_x, pos_wobble_y)
	
	# Apply transforms
	scale = target_scale
	rotation = target_rotation
	position = target_position


func _get_wave(t: float) -> float:
	if use_noise:
		# Simple deterministic noise-like function
		return sin(t) * 0.5 + sin(t * 2.3) * 0.3 + sin(t * 4.7) * 0.2
	else:
		return sin(t)


func _on_mouse_entered() -> void:
	_is_hovered = true


func _on_mouse_exited() -> void:
	_is_hovered = false
	# Reset to base transform smoothly
	if not _is_punching:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "rotation", _base_rotation, 0.1)
		tween.parallel().tween_property(self, "position", _base_position, 0.1)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			trigger_punch()


## Trigger the punch animation manually
func trigger_punch() -> void:
	if not enable_click_punch or _is_punching:
		return
	
	_is_punching = true
	punch_started.emit()
	
	# Cancel any existing tween
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	
	_punch_tween = create_tween()
	_punch_tween.tween_method(_update_punch, 0.0, 1.0, punch_duration)
	_punch_tween.tween_callback(_finish_punch)


func _update_punch(progress: float) -> void:
	var curve_value := punch_curve.sample(progress) if punch_curve else (1.0 - sin(progress * PI))
	var punch_lerp := 1.0 - (1.0 - punch_scale) * (1.0 - curve_value)
	scale = _base_scale * punch_lerp


func _finish_punch() -> void:
	_is_punching = false
	scale = _base_scale
	punch_finished.emit()


## Reset to base transform immediately
func reset_transform() -> void:
	position = _base_position
	rotation = _base_rotation
	scale = _base_scale
	_is_hovered = false
	_is_punching = false


## Update base position (call after moving the control)
func update_base_position(new_pos: Vector2) -> void:
	_base_position = new_pos
	position = new_pos


## Set all motion effects enabled/disabled
func set_motion_enabled(enabled: bool) -> void:
	enable_breathing = enabled
	enable_hover_wobble = enabled
	enable_click_punch = enabled
	if not enabled:
		reset_transform()

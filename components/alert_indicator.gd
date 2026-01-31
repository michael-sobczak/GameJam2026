## Visual indicator that appears above an entity when alerted (e.g., exclamation mark when guard spots player).
class_name AlertIndicator
extends Node2D

@export var show_duration: float = 2.0 ## How long to show the indicator (0 = show until manually hidden).
@export var offset: Vector2 = Vector2(0, -70) ## Offset from entity center where indicator appears (negative Y = above).
@export var bounce_animation: bool = true ## Whether to animate with a bounce effect.

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

var _show_timer: float = 0.0
var _is_showing: bool = false
var _initial_scale: Vector2 = Vector2.ONE

func _ready():
	# Create label if it doesn't exist
	if not has_node("Label"):
		label = Label.new()
		label.name = "Label"
		label.text = "!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
	else:
		label = $Label
	
	# Position offset
	position = offset
	
	# Hide by default
	visible = false
	_initial_scale = scale

func _process(delta):
	if _is_showing:
		# Handle auto-hide timer
		if show_duration > 0.0:
			_show_timer -= delta
			if _show_timer <= 0.0:
				hide_indicator()
		
		# Bounce animation
		if bounce_animation:
			var bounce = sin(Time.get_ticks_msec() / 50.0) * 0.1 + 1.0
			scale = _initial_scale * bounce

## Show the alert indicator.
func show_indicator():
	_is_showing = true
	visible = true
	_show_timer = show_duration
	scale = Vector2.ZERO
	
	# Pop-in animation
	if bounce_animation:
		var tween = create_tween()
		tween.tween_property(self, "scale", _initial_scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Hide the alert indicator.
func hide_indicator():
	_is_showing = false
	
	# Pop-out animation
	if bounce_animation:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
		await tween.finished
	
	visible = false

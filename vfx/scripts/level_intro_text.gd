class_name LevelIntroText
extends CanvasLayer

## Level Intro Text - Shows large text that fades out when a level starts
## Add as child of Level scene and call show_intro()

signal intro_finished

@export var intro_text: String = "FIND THE TREASURE\nDON'T GET CAUGHT\nUse your power up masks to help!"
@export var fade_duration: float = 5.0
@export var hold_duration: float = 1.0 ## Time to hold before starting fade
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var font_size: int = 48

var _label: Label
var _shadow: Label
var _background: ColorRect
var _tween: Tween


func _ready() -> void:
	# Create background overlay
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.7)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	
	# Create container for centering
	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	
	# Create shadow label (offset slightly)
	_shadow = Label.new()
	_shadow.text = intro_text
	_shadow.add_theme_font_size_override("font_size", font_size)
	_shadow.add_theme_color_override("font_color", shadow_color)
	_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shadow.position = Vector2(3, 3)
	container.add_child(_shadow)
	
	# Create main label
	_label = Label.new()
	_label.text = intro_text
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", text_color)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(_label)
	
	# Start hidden
	visible = false


## Show the intro text with fade animation
func show_intro() -> void:
	visible = true
	_label.modulate.a = 1.0
	_shadow.modulate.a = 1.0
	_background.modulate.a = 1.0
	
	# Cancel any existing animation
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_parallel(false)
	
	# Hold for a moment
	_tween.tween_interval(hold_duration)
	
	# Fade out all elements
	_tween.set_parallel(true)
	_tween.tween_property(_label, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN)
	_tween.tween_property(_shadow, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN)
	_tween.tween_property(_background, "modulate:a", 0.0, fade_duration * 0.7).set_ease(Tween.EASE_IN)
	
	# Hide and emit signal when done
	_tween.set_parallel(false)
	_tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	visible = false
	intro_finished.emit()


## Update the intro text
func set_text(new_text: String) -> void:
	intro_text = new_text
	if _label:
		_label.text = new_text
	if _shadow:
		_shadow.text = new_text

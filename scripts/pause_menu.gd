class_name PauseMenu extends CanvasLayer

## In-game pause overlay. Pauses tree on enter, unpauses on exit. ESC or Resume closes.

const PAUSE_MENU_GROUP := "pause_menu"

@onready var resume_button: Button = %ResumeButton as Button
@onready var settings_button: Button = %SettingsButton as Button
@onready var quit_button: Button = %QuitButton as Button

func _ready() -> void:
	add_to_group(PAUSE_MENU_GROUP)
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	if resume_button:
		resume_button.grab_focus()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause") or Input.is_action_just_pressed(&"ui_cancel"):
		_close()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			get_tree().paused = true
		NOTIFICATION_EXIT_TREE:
			get_tree().paused = false


func _close() -> void:
	queue_free()


func _on_resume_pressed() -> void:
	AudioManager.play_sfx("inventory_select")
	_close()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("inventory_select")
	_close()
	Globals.open_settings_menu()


func _on_quit_pressed() -> void:
	AudioManager.play_sfx("inventory_select")
	_close()
	var level: Level = get_tree().get_first_node_in_group(Const.GROUP.LEVEL) as Level
	var scene_to_unload: Node = level if level else get_tree().current_scene
	SceneManager.swap_scenes("res://scenes/menus/start_screen.tscn", get_tree().root, scene_to_unload, Const.TRANSITION.FADE_TO_BLACK)

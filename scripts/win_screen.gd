extends Control

const START_SCREEN_PATH := "res://scenes/menus/start_screen.tscn"

@onready var exit_button: Button = %Exit

func _ready() -> void:
	exit_button.grab_focus()

func _on_exit_button_up() -> void:
	SceneManager.swap_scenes(START_SCREEN_PATH, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)

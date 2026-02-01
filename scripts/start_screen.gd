class_name StartScreen extends Control

const LEVEL_NAME_FORMAT := "Level %s"

@export_file("*.tscn") var level_files: Array[String] = []

var user_prefs: UserPrefs

@onready var level_container: Control = %Buttons
@onready var continue_button: Button = %Continue
@onready var quit_button: Button = %Quit


func _ready() -> void:
	user_prefs = UserPrefs.load_or_create()
	_create_level_buttons()
	_check_continue()

## Creates buttons for each level file found.
func _create_level_buttons():
	if not level_container:
		push_error("LevelContainer not found in start screen")
		return

	# Get button styles from existing buttons (Continue button has the styles)
	# Use get_theme_stylebox to get the effective style (including overrides)
	var normal_style: StyleBox = null
	var hover_style: StyleBox = null
	if continue_button:
		normal_style = continue_button.get_theme_stylebox("normal", "Button")
		hover_style = continue_button.get_theme_stylebox("hover", "Button")
		# Duplicate styles so each button has its own instance
		if normal_style:
			normal_style = normal_style.duplicate()
		if hover_style:
			hover_style = hover_style.duplicate()

	# Clear existing level buttons (but keep Continue, Settings, Quit)
	for child in level_container.get_children():
		if child.name.begins_with("Level_"):
			child.queue_free()

	# Create a button for each level
	for ii in range(level_files.size()):
		var level_path = level_files[ii]
		var button = Button.new()
		var level_name = LEVEL_NAME_FORMAT % (ii + 1)
		# Format level name nicely (e.g., "level1" -> "Level 1", "playground_01" -> "Playground 01")
		button.text = level_name
		button.name = "level::%s" % level_path.get_file().get_basename()
		button.custom_minimum_size = Vector2(300, 75)
		button.add_theme_font_size_override("font_size", 20)

		# Apply same styles as other buttons
		if normal_style:
			button.add_theme_stylebox_override("normal", normal_style)
		if hover_style:
			button.add_theme_stylebox_override("hover", hover_style)

		# Connect button signal
		button.pressed.connect(_on_level_selected.bind(level_path))

		# Add to container (before Continue button)
		var continue_idx = level_container.get_child_count()
		for i in range(level_container.get_child_count()):
			if level_container.get_child(i).name == "Continue":
				continue_idx = i
				break
		level_container.add_child(button)
		level_container.move_child(button, continue_idx)

## Called when a level button is pressed.
func _on_level_selected(level_path: String):
	DataManager.reset_file_data()
	SceneManager.swap_scenes(level_path, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)

func _check_continue():
	if SaveFileManager.save_file_exists():
		continue_button.visible = true
		# Focus first level button if available, otherwise continue
		if level_container and level_container.get_child_count() > 0:
			var first_level_button = null
			for child in level_container.get_children():
				if child.name.begins_with("Level_"):
					first_level_button = child
					break
			if first_level_button:
				first_level_button.grab_focus()
			else:
				continue_button.grab_focus()
		else:
			continue_button.grab_focus()
	else:
		# Focus first level button if available
		if level_container and level_container.get_child_count() > 0:
			var first_level_button = null
			for child in level_container.get_children():
				if child.name.begins_with("Level_"):
					first_level_button = child
					break
			if first_level_button:
				first_level_button.grab_focus()

func _on_continue_button_up() -> void:
	DataManager.load_file_data()
	var level_to_load = DataManager.get_file_data().game_data.level
	SceneManager.swap_scenes(level_to_load, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)

func _on_settings_button_up() -> void:
	Globals.open_settings_menu()

func _on_quit_button_up() -> void:
	get_tree().quit()

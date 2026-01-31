class_name StartScreen extends Control

@export_file("*.tscn") var start_level = "" ## The level from which the game starts when starting a new game (deprecated, use level selection).

var user_prefs: UserPrefs

@onready var level_container: GridContainer = %GridContainer
@onready var continue_button: Button = %Continue
@onready var quit_button: Button = %Quit
@onready var version_num: Label = %VersionNum

var level_files: Array[String] = []

func _ready() -> void:
	var version = ProjectSettings.get_setting("application/config/version")
	version_num.text = "v%s" % version
	user_prefs = UserPrefs.load_or_create()
	_find_level_files()
	_create_level_buttons()
	_check_continue()
	quit_button.visible = OS.get_name() != "Web"

## Finds all level scene files in the scenes/levels/ directory.
func _find_level_files():
	var levels_dir = "res://scenes/levels/"
	var dir = DirAccess.open(levels_dir)
	
	if not dir:
		push_error("Could not open levels directory: %s" % levels_dir)
		return
	
	# Files to exclude (base scenes, scripts, temp files)
	var exclude_names = ["Level.tscn", "level.gd", "level.gd.uid"]
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Only include .tscn files that aren't excluded
		if file_name.ends_with(".tscn") and file_name not in exclude_names and not file_name.ends_with(".tmp"):
			var full_path = levels_dir + file_name
			level_files.append(full_path)
		
		file_name = dir.get_next()
	
	# Sort levels by name for consistent ordering
	level_files.sort()
	
	print("Found %d level files: %s" % [level_files.size(), level_files])

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
	for level_path in level_files:
		var button = Button.new()
		var level_name = level_path.get_file().get_basename()
		# Format level name nicely (e.g., "level1" -> "Level 1", "playground_01" -> "Playground 01")
		level_name = level_name.replace("_", " ").capitalize()
		button.text = level_name
		button.name = "Level_" + level_path.get_file().get_basename()
		button.custom_minimum_size = Vector2(150, 40)
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
